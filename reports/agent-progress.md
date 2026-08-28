# Agent Progress Report

Estado operativo del pipeline multi-distro para Xiaomi Mi A3 (laurel_sprout / SM6125).
Actualizado: 2026-08-28 (plan NixOS+Phosh; Arch parkeado).

## Kernel (base compartida)
- Linux mainline `v7.1` = `b3f94b2b3f3e51ab880a51fc6510e1dafba654ed`, 4 parches (`patches/kernel/0001..0004`).
- `dirty=false`; kernelrelease actual: `7.1.0-postmarketos-sm6125-00001-g150df066f552`
  (patched_commit `150df066f552835ff5dbb5a167528491ab2bd332`, 1519 módulos).
- Builds más recientes verifican `manifest.json` con `"dirty": false`.

## Workflows por distro
| Workflow | Estado | Notas |
|---|---|---|
| 00-quality | green en push | automático |
| 05 Arch Linux ARM | variantes console/gnome/kde | fix DNS commiteado, validando |
| 06 NixOS | variantes console/gnome/kde | fix emulación commiteado, validando |
| 07 matrix | `[archlinux,nixos] x [console,gnome,kde]` | kernel compartido + `extra-platforms` |
| 04 pmOS (console/phosh) | placeholder informativo | pmOS bloqueado por pmaports |

## Bloqueadas / fixes recientes
1. **Arch DNS (chroot)**: el rootfs ArchLinuxARM trae `/etc/resolv.conf` como symlink
   a `/run/systemd/resolve/stub-resolv.conf` (inexistente en el chroot). `sudo rm -f` +
   archivo plano con public resolvers (`1.1.1.1` / `8.8.8.8`). Además:
   `pacman --disable-sandbox` (falta Landlock en kernel del runner) y verificación de
   base system (bash/pacman/systemctl) para no producir imágenes vacías.
2. **NixOS platform mismatch**: nix-daemon rechazaba derivaciones `aarch64-linux` en
   runner `x86_64-linux` con `Cannot build ... Reason: platform mismatch`. Fix:
   `extra-platforms = aarch64-linux` en `extra-conf` del `nix-installer-action`
   (06 y 07). Se mantiene binfmt/qemu de apt (`qemu-user-static binfmt-support
   crossbuild-essential-arm64`) y `update-binfmts --enable qemu-aarch64`.
3. **NixOS closure completa**: root cause encontrado y corregido. El device module usaba
   `linux_6_12.override { structuredExtraConfig = {...} }` (derivación NO cacheada que nix
   compila emulada); su `generate-config.pl` fallaba con `Error in reading or end of file.`
   (exit 255, `linux-config-6.12.104.drv`, nixpkgs#59914/#521048). Fix (8bca017): usar
   `pkgs.linuxPackages_6_12` stock (LTS, en caché para aarch64). El kernel real de arranque
   sigue siendo el compartido 7.1.0 (artefacto `kernel-debug` → boot.img).
4. **pmOS rootfs**: bloqueado por falta de `device-xiaomi-laurel` y
   `linux-postmarketos-qcom-sm6125` en pmaports upstream. Plantillas en
   `pmaports-template/` listas para contribuir.
5. **flake.lock**: commiteado como `nixos/flake.lock` (nixpkgs `56c02bc`, nixos-unstable).
6. **Arch packages inexistentes (027123a)**: `networkmanager-wifi`, `dmesg`,
   `usb-modeswitch` y `firmware-ath10k` no existen en ALARM aarch64/extra (verificado
   contra `extra.db`/`core.db` del mirror); `ath10k` va en `linux-firmware` (ya listado).
   Eliminados del `console-packages.txt`; ahora `pacman -S` no falla con "target not found".

## Decisiones de arquitectura
- Kernel compartido: reusable-build-kernel + artefacto `kernel-debug`; los rootfs/builds
  de distros consumen el mismo artefacto (sin rebuilds redundantes).
- 07 build-distros: matrix `[archlinux, nixos] x [console, gnome, kde]` + job `pmos-console`
  informativo + job `collect`.
- Variantes: **console** (mínimo/SSH), **gnome** (Phosh, GNOME móvil) y **kde**
  (Plasma Mobile). Arch usa listas de paquetes en `configs/archlinux/*-packages.txt`;
  NixOS usa configs en `nixos/configurations/*.nix` y el módulo casero
  `nixos/modules/plasma-mobile.nix` (plasma6 + `kdePackages.plasma-mobile` +
  plasma-login-manager; nixpkgs aún no tiene módulo oficial, nixpkgs#432702).
- NixOS: flake en `nixos/` (cd nixos), `users.allowNoPasswordLogin = true` (evita
  aserción de lock-out), fallback a salida mínima (kernel + initramfs + boot.img) si la
  closure completa falla.

## Pendiente
- **Foco actual: NixOS + Phosh (gnome)** — plan detallado en
  `reports/plan-nixos-phosh.md`. Decisión: perfeccionar la variante gnome (Phosh)
  con NixOS primero; KDE y Arch quedan sin prioridad.
- **Arch parkeado**: pacman en chroot QEMU no completa `check_space` (necesita
  /proc montado; el runner GH no permite montarlo; self-bind b24812d y /etc/mtab
  5059f64 no resuelven: `could not open file: /etc/mtab` → aborta commit). Todos
  los jobs archlinux fallan en 3 matrices. Candidato a probar luego: pacman nativo
  x86_64 con `RootDir` apuntando al rootfs aarch64 (reference 7Ji, evita QEMU).
- NixOS matrix confirmado verde: console/gnome/kde 3/3 SUCCESS en 33093698708,
  33104029709, 33108497125.
- `reports/cross-distro-validation.md` + `reports/artifact-index.json`.
- Instrucciones de prueba física (fastboot + rootfs) tras Fase 4 del plan.
- Pendiente menor: el `pkgs` con `crossSystem` en `nixos/flake.nix` (líneas 11-14) es
  código muerto (nixosSystem usa su propio pkgs vía `system`); limpiar.