# Agent Progress Report

Estado operativo del pipeline multi-distro para Xiaomi Mi A3 (laurel_sprout / SM6125).
Actualizado: 2026-08-27 (tras run 33088213880 / 33088227815).

## Kernel (base compartida)
- Linux mainline `v7.1` = `b3f94b2b3f3e51ab880a51fc6510e1dafba654ed`, 4 parches (`patches/kernel/0001..0004`).
- `dirty=false`; kernelrelease actual: `7.1.0-postmarketos-sm6125-00001-g150df066f552`
  (patched_commit `150df066f552835ff5dbb5a167528491ab2bd332`, 1519 módulos).
- Builds más recientes verifican `manifest.json` con `"dirty": false`.

## Workflows por distro
| Workflow | Estado | Notas |
|---|---|---|
| 00-quality | green en push | automático |
| 05 Arch Linux ARM | corriendo fix DNS | ver bloqueada "Arch DNS" |
| 06 NixOS | corriendo fix emulación | ver bloqueada "NixOS platform mismatch" |
| 07 matrix | con `extra-platforms` | ver mejoras |
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
3. **NixOS closure completa**: todavía no confirmada; flake presenta 54 derivaciones
   a construir. Si vuelve a fallar, revisar `nixos-diagnostic` (log completo ya sin tail).
4. **pmOS rootfs**: bloqueado por falta de `device-xiaomi-laurel` y
   `linux-postmarketos-qcom-sm6125` en pmaports upstream. Plantillas en
   `pmaports-template/` listas para contribuir.
5. **flake.lock**: commiteado como `nixos/flake.lock` (nixpkgs `56c02bc`, nixos-unstable).

## Decisiones de arquitectura
- Kernel compartido: reusable-build-kernel + artefacto `kernel-debug`; los rootfs/builds
  de distros consumen el mismo artefacto (sin rebuilds redundantes).
- 07 build-distros: matrix `[archlinux, nixos] x [console, phosh]` + job `pmos-console`
  informativo + job `collect`.
- NixOS: flake en `nixos/` (cd nixos), `users.allowNoPasswordLogin = true` (evita
  aserción de lock-out), fallback a salida mínima (kernel + initramfs + boot.img) si la
  closure completa falla.

## Pendiente
- Confirmar green real de Arch (paquetes base instalados) y NixOS (closure completa).
- Cablear `kernelPackages` del device NixOS al kernel 7.1.0 parcheado (hoy usa `linux_6_12`).
- Variantes phosh; `reports/cross-distro-validation.md` + `reports/artifact-index.json`.
- Prerelease con artefactos validados; instrucciones de prueba física.