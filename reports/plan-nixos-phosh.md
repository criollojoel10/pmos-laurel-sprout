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
- Nuevo workflow `nixos-eval.yml` (workflow_dispatch, input `variant`):
  instalar Nix + `nix flake check ./nixos` + `nix eval --raw
  .#nixosConfigurations.laurel-<v>.config.system.build.toplevel.drvPath`.
  ~3-5 min. Este es el loop de iteración; el build completo solo al cerrar.

### Fase 3 — Boot real del sistema NixOS (el cambio grueso)
- `build-nixos-rootfs.sh`:
  a. tras `nix build ... --no-link --print-out-paths`, guardar `OUT`.
  b. si la closure existe: crear imagen ext4 `-L NIXOS_ROOT`, montaria en loop
     y copiar la closure al `/nix/store` destino (`nix-store --dump`/`cp -a` de
     los store paths + toplevel) + `/nix/var/nix/db` opcional; verificar
     `<root>/nix/store/...-nixos-system-laurel-gnome/init`.
     Si NO hay closure → NOTA explícita y seguir con salida mínima (no fakear).
  c. cmdline de boot.img = `root=LABEL=NIXOS_ROOT init=<OUT>/init
     console=... androidboot.hardware=...` (patrón NixOS `init=`; el stage-1
     re-exec el init señalado tras montar /lib/modules; nuestro propio
     initramfs monta root por label y pivota).
  d. `initramfs/init`: modo arranque real (var `NIXOS_BOOT=1`): montar `/proc
     /sys /dev`, `mount LABEL=NIXOS_ROOT /mnt` (+ `-o ro`?), bind `/mnt/nix`
     o pivot_root a `/mnt`, y `exec <OUT>/init`. Mantener el modo diagnóstico
     por defecto (sin NIXOS_BOOT no cambia).
  e. artefacto extra: `nixos-gnome-ext4.img.xz` + SHA256SUMS + manifest ya
     existentes. Verificación post: `bin/systemctl` y `init` presentes en el
     img montado.
- Nix test (stretch): nixos-test VM aarch64 TCG para smoke de phosh.service.

### Fase 4 — Validación final
- 06-build-nixos (workflow_dispatch `build_variant=gnome`) → kernel + closure +
  imagen. Chequear jobs verdes + artefactos (`boot.img`, `ext4.img.xz`) +
  generar `reports/cross-distro-validation.md`.
- Instrucciones de prueba física (fastboot + flasheo rootfs) en reports.

### Fase 5 — Arch (parkeado, documentado)
- Bloqueante actual (verificado 3 runs): pacman dentro del chroot QEMU no puede
  completar `check_space` (necesita /proc montado en el chroot; el runner GH no
  permite montarlo; self-bind + /etc/mtab no resuelven: open de `/etc/mtab`
  → `/proc/self/mounts` inexistente → aborta en commit).
- Candidato (referencia 7Ji: cross-bootstrap-arch.html): ejecutar **pacman nativo
  x86_64** (pacman-static) con `RootDir=<rootfs aarch64>`, `Architecture =
  aarch64` en config → evita QEMU por completo en instalación. Post-install
  hooks se re-ejecutan en chroot QEMU a demanda.
- Retomar tras cerrar NixOS gnome.

## Qué NO hacemos ahora
- No reconstruir kernel por iteración (Fase 2 lo evita).
- No tocar plasma-mobile.nix / kde.nix (siguen en matrix, sin cambios).
- No tocar 07 matrix (igual que hoy).