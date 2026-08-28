# Plan: perfeccionar NixOS + Phosh (gnome) para laurel_sprout

Decisión (2026-08-27): **perfeccionar primero la variante NixOS `gnome` (Phosh)**.
KDE (Plasma Mobile) y Arch quedan en el matrix pero SIN prioridad; Arch está
parkeado (ver §5). Se elige Phosh porque:

- Módulo nixpkgs **oficial y mantenido** (`services.xserver.desktopManager.phosh`),
  ya presente en la rev fijada `56c02bc` (nixos-unstable).
- Misma config que el ejemplo PinePhone de la wiki NixOS y mobile-nixos.
- Reutiliza GNOME core (mutter, gnome-settings-daemon, portals) que ya están
  cacheados para aarch64 → closure pequeña y fiable.

## Referencias
- `nixos/modules/services/x11/desktop-managers/phosh.nix` @56c02bc (259 líneas,
  leído completo): opciones `enable/package/user/group/phocConfig`; auto-config:
  systemd phosh.service en tty1 (PAMName=login), xdg.portal (+phosh/gnome/gtk),
  `pkgs.stevia` (OSK) + `i18n.inputMethod.type="ibus" waylandFrontend=true`,
  `programs.feedbackd.enable`, `services.gnome.core-shell/core-os-services.enable`,
  `displayManager.sessionPackages=[phosh]`, phocConfig default `outputs.DSI-1.scale=2`.
- Wiki NixOS "PinePhone": usar `user`+`group` y `phocConfig.xwayland="immediate"`.
- uninsane.org (mobile-nixos PinePhone): `QT_QPA_PLATFORM=wayland` para apps Qt.
- mobile-nixos (mobile.nixos.org/devices/pine64-pinephone.html): patrón de disco
  completo con root + u-boot; aquí usamos fastboot/boot.img (sin u-boot).

## Brechas actuales (verificado en repo)
1. `build-nixos-rootfs.sh`: construye la closure (`nix build ...toplevel`) pero
   **no ensambla ningún sistema NixOS en una imagen**: solo copia kernel/dtb/
   modules + flake y hace un boot.img con el initramfs de diagnóstico. El
   dispositivo nunca llega al `/nix/store` del sistema.
2. `initramfs/init`: initramfs 100% diagnóstico (no monta root, no hace handoff
   a NixOS).
3. `gnome.nix`: repite paquetes que el módulo phosh ya mete (phosh, phoc,
   gnome-session), incluye cosas fuera de lugar para un teléfono
   (networkmanagerapplet) y le faltan piezas de sesión (grupos, dconf,
   QT_QPA_PLATFORM).
4. Loop de validación caro: cada `07`/`06` reconstruye el kernel (~50 min).

## Fases

### Fase 1 — Config `gnome.nix` afinada (rápido, sin builds)
- Podar: phosh, phoc, gnome-session, adwaita-icon-theme (ya van por el módulo /
  core-shell). quitar `networkmanagerapplet`.
- Añadir: `programs.dconf.enable = true`; grupos `feedbackd` al usuario
  (haptics) y `dialout`; `environment.sessionVariables.QT_QPA_PLATFORM="wayland"`;
  mantener `PHOSH_SCALE/GDK_SCALE=2` y `phocConfig.xwayland="immediate"`.
- Notebook: afinación on-device de salvadas de escala por output real de DSI
  (`cat /sys/class/drm/card0-*/status`, probar DSI-1/DSI-2/Virtual-*).

### Fase 2 — Loop de validación barato (sin kernel → minutos)
- `nixos-eval.yml` (workflow_dispatch + pull_request rutas Nix): instalar Nix +
  verificar flake.lock versionado/pinned + `nix flake metadata/show/check
  --no-build` + hostPlatform==aarch64-linux + `toplevel.drvPath` (console y
  gnome) no vacíos y distintos + reporte MD/JSON. ~2-4 min. Sin builds ni kernel,
  sin caché (reproducible por lockfile), contents: read.
- **Fallo descubierto y corregido** (a9055c9): la eval reveló errores de
  evaluación que el build pesado 06/07 enmascaraba — su paso `nix build` falla
  "blando" (`if ! nix build; then ...`) y el job reportaba SUCCESS aunque la
  closure jamás se construyera. Atributos inexistentes en 56c02bc:
  `qt6-wayland` → `qt6Packages.qtwayland`; `eglinfo`, `glmark2-es2-wayland` → NO
  existen → eliminado/`glmark2`. console.nix: opción gdm renombrada. Consecuencia:
  **el cierre NixOS NUNCA ha sido realmente construido/validado en CI**; la
  Fase 3 debe validar la closure completa desde cero.

### Fase 3 — Boot real del sistema NixOS (el cambio grueso)

Subfases incrementales en commits separados (implementar de forma independiente,
validar tras cada una):

#### 3A. Exportar la closure
- ✅ IMPLEMENTADA (commits `22d8b17`, `07b607f`, `b62a3a1`, `ec5fcaa`, `13da40a`,
  `a2b825c`, `b76d1ef`). Workflow `.github/workflows/nixos-build-console.yml` +
  `scripts/export-nixos-closure.sh`.
- Build REAL del toplevel (`nix build ./nixos#nixosConfigurations.laurel-console
  .config.system.build.toplevel --out-link result-console --print-build-logs`),
  fail-closed (sin fallback blando; regresión `scripts/check-no-soft-fallback.sh`
  en 00-quality y validate-local). Inventario de invalidated runs:
  `reports/nixos-build-invalidation-log.md`.
- Verificación: `nix store verify` de los 663 paths OK; `init` ejecutable;
  drvPath/systemPath/hostPlatform registrados (run `33135793761`);
  `reports/nixos-closure-validation.md`.
- Export reproducible: requisitos ordenados → `nix-store --export | zstd -T0 -19`
  → `artifacts/nixos-console/nixos-laurel-console-closure.nar.zst`; SHA256
  `6b969088…faae7a`; integridad verificada (zstd -t, stream `nix-archive-1`).
  `independently-imported=false` (documentado, sin store aislado).
- Fixes de reliability en el camino: módulos en `availableKernelModules` para
  linux 6.12 (`phy_qcom_qmp*`, `ufs_qcom`, `dwc3` — los nombres viejos ya no
  existen y rompían el `modules-shrunk` del initrd).

#### 3B. Construir el árbol rootfs — ✅ GREEN (run `33204219827`)
- Job `assemble-rootfs-tree` en `nixos-build-console.yml` +
  `scripts/build-nixos-rootfs-tree.sh`: re-importa el export en un store limpio de
  runner (`zstd -dc nar | nix-store --import`; ojo: pasar el fichero comprimido
  directo falla), verifica 663 paths 1:1 vs closure-paths.txt, copia a
  `rootfs-tree/{nix/store,etc,init}`, valida fail-closed (init y systemctl
  ejecutables ARM64 vía `readlink -f` — en NixOS systemctl NO vive en
  `<toplevel>/bin`, se resuelve dentro del árbol) y genera `validation.json`.
  Se sube `.tar.zst` (461 MB) porque upload-artifact rechaza nombres con `:`
  (p.ej. `ModemManager/fcc-unlock…/03f0:4e1d`).
- Arbol: 663 paths, 2.2 GB; `independently-imported=true` (re-import REAL).

#### 3C. Crear y verificar ext4 NIXOS_ROOT — ✅ GREEN (run `33207764923`)
- Job `create-rootfs-image` + `scripts/build-nixos-rootfs-image.sh`: extrae
  `rootfs-tree.tar.zst`, imagen raw `nixos-rootfs.img` (~2.43 GiB) con
  `mkfs.ext4 -F -i 4096 -L NIXOS_ROOT -d rootfs-tree` (poblada directo; sin
  montaje root para crearla), `e2fsck -f` exit 0 (criterio real; "1ª pasada
  tras -d" es normal), label y UUID via `tune2fs -l`, re-montado loop,ro
  (663/663 paths + init), sha256.
- Fixes en el camino: `-i 4096` (inodes suficientes para ~162k ficheros),
  e2fsck por código de salida (no grep), `find` en vez de `ls`.
- Artefacto: `nixos-console-rootfs-image`/`image-validation.json`; sha256 local ==
  CI. `imageSha256=b8e61fc2…` `uuid=87bf6242-3f0b-458c-8bbb-e0be1ad48d0e`.

#### 3D. Integrar initramfs y stage-1 — ✅ INVESTIGACIÓN COMPLETADA (ver abajo)
- Confirmado documentalmente (fuentes nixpkgs `stage-1-init.sh`/`stage-2-init.sh`,
  master): el mecanismo es un initramfs (stage-1, shell) que procesa `/proc/cmdline`
  (`init=` → stage2Init; `root=` → /dev/root), monta el root y hace
  `exec switch_root /mnt-root <stage2Init>`. NO basta un `init=` a secas: el
  initramfs es el QUE monta root y entrega /proc,/sys,/dev,/run movidos.
- `initramfs/init` propio (modo boot real): montar pseudo-fs, cargar módulos
  UFS/DWC3 (nombres 6.12 ya en `availableKernelModules`), localizar y montar
  `LABEL=NIXOS_ROOT`, `mount --move` de /proc,/sys,/dev,/run, y
  `exec switch_root /mnt-root /nix/store/<hash>-nixos-system-…/init` (el applet
  `switch_root` de busybox; stage-2 luego re-monta / rw, bind de /nix/store con
  opciones, corre `activate` y `exec systemd`). Shell de recuperación en
  fallo + logging console ttyMSM0.
- Kernel v7.1 (compartido) via `reusable-build-kernel.yml` MISM del run
  (patrón de `07-build-distros`), NO rebuild por iteración de rootfs. UFS y ext4
  vienen de los módulos del kernel 7.1 en el initramfs (no del initrd de NixOS
  para 6.12, que es de otro kernel).
- Criterios: init existente y ejecutable (ARM64, i.e. no loader x86-trampoline);
  initramfs extraíble; boot.img extraíble; sin secretos.

#### 3E. Validar rootfs y boot image
- Validar la imagen completa (kernelrelease y módulos coherentes con el kernel
  7.1.0 compartido; arquitectura ARM64 del init/initramfs), generar
  SHA256SUMS/manifest y subir artefactos. hardware tested=false.

#### Investigación de arranque NixOS (requisito para 3D) — ✅ COMPLETADA
Fuentes: `nixos/modules/system/boot/stage-1-init.sh` y `stage-2-init.sh`
(nixpkgs master, GitHub). Hallazgos:
- stage-1 es un script shell ran como PID1 en un initramfs; `@extraUtils@`
  (busybox+bash+switch_root+applets) vive en el propio initramfs. Procesa
  `/proc/cmdline` (tras montar /proc): `init=*` → `stage2Init` (default `/init`);
  `root=LABEL=X`/`root=UUID=…` → symlink `/dev/root`; `root=<ruta>` firewall
  directo. `console=*` elige el TTY del shell de recuperación.
- Carga módulos de `boot.initrd.kernelModules`/`availableKernelModules` con
  modprobe desde extraUtils ANTES de udev; crea nodos vía systemd-udevd.
- Monta root desde `fsInfo` (generado del `fileSystems."/".device`), encadenando
  `mountFS` en `/mnt-root`; `waitDevice` reintenta (loop 20s) si falta el nodo.
- `switch_root`: `mkdir -p $targetRoot/{proc,sys,dev,run}`; `mount --move` de
  /proc /sys /dev /run a `$targetRoot`; después
  `exec env -i $(type -P switch_root) "$targetRoot" "$stage2Init"`. O sea el
  tool `switch_root` (util-linux o busybox) prototipo es imprescindible y los
  pseudo-fs se MUEVEN (no re-montan) al root real.
- `stage2Init` en real NixOS lo pasa el bootloader: cmdline del boot entry
  `init=/nix/store/<hash>-nixos-system-<ver>/init` → ese `init` es el stage-2.
- stage-2 (`<toplevel>/init`): `if [ ! -e /proc/1 ]` re-monta pseudo-fs si no
  hay stage-1; remonta `/` rw; bind de `/nix/store` con opciones
  (`ro,nosuid,nodev` por defecto) — el store DEBE estar en la raíz; corre
  `$systemConfig/activate`; `ln -sfn "$systemConfig" /run/booted-system`;
  `exec systemd "$@"`. Además necesita `/etc` (existe en el root NIXOS_ROOT/…).
- Implicaciones para laurel: nuestro init propio DELIVERA stage-2 SÓLO con
  (1) root montado en /mnt-root, (2) /nix/store presente en la raíz (el árbol 3B
  YA lo tiene), (3) pseudo-fs movidos, (4) `/etc` del sistema (árbol 3B), (5)
  cmdline `init=<toplevel>/init`. No hace falta el initrd NixOS completo; el
  initramfs propio (busybox ARM64 estático + módulos 7.1 del kernel compartido)
  lo habilita.
- Nombres de módulos para 6.12 del root (el plan viejo decía `ufshcd-qcom`/
  `phy_qcom_ufs`; con linux-mainline 6.12.x los nombres correctos son
  `ufs_qcom`, `phy_qcom_qmp_ufs`, `dwc3`, `dwc3_qcom` — ya aplicados en
  `nixos/devices/laurel-sprout/default.nix`).
- Shell de recuperación y logging: stage-1 usa `console=` de cmdline para el TTY
  del shell interactivo (`fail`); nuestro init usa `console=ttyMSM0,115200n8`
  (default ya en assemble-boot-image.sh) + tee a /dev/kmsg.

#### Criterios de aceptación Fase 3
- [ ] closure completa construida (no salida mínima);
- [ ] referencias verificadas (closure del toplevel exportada/check-size);
- [ ] rootfs montable;
- [ ] `e2fsck -f` limpio;
- [ ] label `NIXOS_ROOT` confirmada;
- [ ] init existente y ejecutable (ARM64 ELF, no trampoline x86);
- [ ] arquitectura ARM64 (file init), kernelrelease y módulos coincidentes con
  7.1.0;
- [ ] initramfs extraíble (cpio.gz válido);
- [ ] boot.img extraíble (magic ANDROID!, payloads correctos);
- [ ] ningún secreto en imágenes/reportes;
- [ ] hardware tested=false (documentado, no probado en dispositivo).

### Fase 4 — Validación final
- 06-build-nixos (workflow_dispatch `build_variant=gnome`) → kernel + closure +
  imagen. Chequear jobs verdes + artefactos (`boot.img`, `ext4.img.xz`) +
  generar `reports/cross-distro-validation.md`.
- Instrucciones de prueba física (fastboot + flasheo rootfs) en reports.

### Fase 5 — Arch (parkeado, documentado)
- Bloqueante actual (verificado 3 runs):
  *"Current builder fails because pacman check_space expects /proc inside the
  target environment; alternative RootDir/native pacman approach requires a
  separate design and CI validation."*
  Sin afirmar que /proc es imposible de montar en todos los runners GH (no
  demostrado).
- Candidato (referencia 7Ji: cross-bootstrap-arch.html): ejecutar **pacman nativo
  x86_64** (pacman-static) con `RootDir=<rootfs aarch64>`, `Architecture =
  aarch64` en config → evita QEMU por completo en instalación. Post-install
  hooks se re-ejecutan en chroot QEMU a demanda.
- Retomar tras cerrar NixOS gnome.

## Qué NO hacemos ahora
- No reconstruir kernel por iteración (Fase 2 lo evita).
- No tocar plasma-mobile.nix / kde.nix (siguen en matrix, sin cambios).
- No tocar 07 matrix (igual que hoy).