# Agent Progress Report

Estado operativo del pipeline multi-distro para Xiaomi Mi A3 (laurel_sprout / SM6125).
Actualizado: 2026-08-28 (NixOS+Phosh: Fase 1 y 2 verdes; Arch parkeado).

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
  aserción de lock-out). Contrato fail-closed (3A): si la closure completa falla,
  el build NixOS es un ERROR (exit≠0), no se produce salida mínima "éxito".

## Aviso importante (2026-08-28)
- El "NixOS 3/3 SUCCESS" anterior en 06/07 era un **falso positivo**: el step
  `nix build` de esos workflows cae en un fallback *blando* (`if ! nix build;
  then NOTE...`) sin `exit 1`, así que el job salía green aunque la closure
  NixOS **nunca se construía**. La nueva `nixos-eval.yml` lo destapó.
- También salieron a la luz atributos inexistentes que jamás se habrían
  detectado con el flujo anterior (corregidos en a9055c9, ver Fase 2).

## Pendiente
- **Foco actual: NixOS + Phosh (gnome)** — plan detallado en
  `reports/plan-nixos-phosh.md`. Decisión: perfeccionar la variante gnome (Phosh)
  con NixOS primero; KDE y Arch quedan sin prioridad.
- Fase 1 (config Phosh) ✅ `df6d1a6` — 00-quality green.
- Fase 2 (nixos-eval.yml) ✅ `378c01f` + fix `a9055c9` — run 33133393490 green,
  `nixos-eval-report` verificado (aarch64-linux, drvPaths distintos console/gnome).
- Fase 3A (build real fail-closed) ✅ EN VERDE:
  - 3A.1 ✅ `22d8b17` (fail-closed: build-nixos-rootfs.sh, 06/07 gates, regresión
    check-no-soft-fallback.sh, invalidation-log).
  - 3A.2–3A.5 ✅ `07b607f`+ (`nixos-build-console.yml` + `export-nixos-closure.sh`):
    run `33135793761` GREEN — closure laurel-console realmente construida,
    verificada (`nix store verify` OK, 663 paths, hostPlatform aarch64-linux,
    drvPath) y exportada reproducible (`nixos-laurel-console-closure.nar.zst`,
    SHA256 `6b969088…`; integridad OK). Fixes de módulos 6.12 en `b62a3a1`,
    `ec5fcaa`, `13da40a` (phy_qcom_qmp*/ufs_qcom/dwc3).
  - 3A.6/3A.9 ✅ CERRADOS: el re-import REAL en store de runner 3B confirmó
    `independently-imported=true` (run `33204219827`, `validation.json`; evidencia
    en `nixos-closure-validation.md`). 3A.7 ✅ secret scan limpio.
  - 3A.10 REVISADO: `gh pr edit 15 --body-file reports/pr-body.md` OK (body
    documenta Fase 3A). PR #15 sigue MERGED — GitHub NO permite reabrir PRs
    merged y, tras FF de `agent/multi-distro-mainline` → main (sin reescribir,
    quedó == main), no hay commits diferenciales para una PR draft nueva.
    Resolución: #15 queda como histórico documentado; el tracking de Fase 3 va
    en `reports/` + commitis de `main`.
  - 3A.11/3A.12 ✅ criterios de salida auditados (`nixos-closure-validation.md`);
    datos disponibles → 3B lanzado.
- Fase 3B ✅ GREEN (run `33204219827`): `build-nixos-rootfs-tree.sh` +
  job `assemble-rootfs-tree`; re-import real (663 paths 1:1), init/systemctl
  ARM64 verificadas, `validation.json` (independently-imported=true),
  `rootfs-tree.tar.zst` (461 MB, 162 751 entradas) + `validation.json` subidos.
  Fixes en camino: toplevel derivado de closure-paths (no `find` en store del
  daemon), systemctl resuelto vía readlink, jq key entre comillas, artefacto
  empacado en tar.zst (upload-artifact rechaza `:`).
- Fase 3C ✅ GREEN (run `33207764923`): `build-nixos-rootfs-image.sh` + job
  `create-rootfs-image`; imagen `nixos-rootfs.img` (~2.43 GiB) label `NIXOS_ROOT`
  (uuid `87bf6242-…`), `e2fsck -f` exit 0, remontada con 663/663 store paths,
  sha256 local == CI (`b8e61fc2…`). Fixes en el camino: `-i 4096` inodes,
  e2fsck por exit code, `find` (SC2012).
- Fase 3D ✅ GREEN (run `33240188674`): `build-nixos-initramfs.sh` +
  `assemble-boot-image.sh` — initramfs (init ARM64 estático + busybox aarch64 +
  módulos kernel v7.1, 1 995 paths) + boot.img **con `Image.gz`** (Image RAW 56.3
  MiB excede partición 64 MiB), Header v2, 37 818 368 B. Causa raíz de fallos
  previos: GNU cpio lista SIN `./` → greps tolerantes `(^|/)init$`/`(^|/)busybox$`;
  `grep -c '/lib/modules/'`→0 con `set -e` (ahora `grep -cE 'lib/modules' || true`
  + aserción MOD_COUNT>0); scripts sin `+x` (commit `0ddd15f`, 100755).
- Fase 3E ✅ GREEN (run `33240188674`): `validate-nixos-boot.sh` + job
  `package-release` — magic ANDROID!, payloads (Image.gz/ramdisk/dtb v17),
  kernelrelease kernel==módulos `7.1.0-postmarketos-sm6125-00001-g8eab428f49a7`,
  ARM64, secret scan limpio, SHA256SUMS/artifact-index,
  `nixos-console-release-validation`. Robustez: mktemp, find recursivo
  (upload-artifact v4 anida rutas absolutas), guards `|| true` en `| head` bajo
  pipefail. Boot sha256 `66ae73a3…`.
- **Fase 3 COMPLETA** (3A–3E verdes, run `33240188674`, commit `7b8d7ad`);
  preparada para test físico console.
- **Arch parkeado** (redacción oficial): *"Current builder fails because pacman
  check_space expects /proc inside the target environment; alternative
  RootDir/native pacman approach requires a separate design and CI validation."*
  Sin afirmar que /proc es imposible de montar en todos los runners GH.
- `reports/cross-distro-validation.md` + `reports/artifact-index.json`.
- Instrucciones de prueba física (fastboot + rootfs): en `reports/physical-test-laurel-nixos.md`.
- Pendiente menor: el `pkgs` con `crossSystem` en `nixos/flake.nix` (líneas 11-14) es
  código muerto (nixosSystem usa su propio pkgs vía `system`); limpiar.