# DECISION-0012 — Reproducción del port histórico (pmbootstrap 1.52.0 + pmaports @7aaee51a)

- Estado: **Aceptado** (en ejecución, FASE 3)
- Fecha: 2026-08-07
- Relacionada: DECISION-0008 (superada en parte por esta).

## Contexto

- `fastboot boot` (prueba no destructiva, FASE E) está bloqueado por el
  bootloader de esta unidad: `FAILED remote: 'unknown command'`
  (`FASTBOOT_BOOT_COMMAND_UNSUPPORTED`). Solo hay vía persistente de arranque
  escribiendo `boot_<slot>`/`system_<slot>`/`vbmeta_<slot>` (slot inactivo b).
- El port postmarketOS histórico de `xiaomi-laurel` (dic 2022) está en pmaports
  @`7aaee51a` (MR 3727). Los repos binarios del canal v22.12 (Alpine v3.17)
  siguen disponibles en `mirror.postmarketos.org/postmarketos/v22.12/`.
- Antes de escribir nada en el dispositivo (FASE 8) es necesario **reproducir
  con fidelidad el flujo de 2022** (kernel, boot.img header v0, rootfs MBR)
  y contrastarlo con las hipótesis H2/H3/H5 del boot (dtbo borrado, vbmeta
  flags=2, slot b).

## Decisión

Reproducir el port histórico en CI con herramientas y fuentes congeladas:

- pmbootstrap **1.52.0** (tarball, SHA-256 fijado) — equivalente funcional al
  1.50.0 del dry-run (flasher idéntico para este deviceinfo).
- pmaports **@`7aaee51a`** (rama master, 2022-12-14, MR 3727) clonado con
  `--filter=blob:none` y checkout del SHA (sin fetch de SHA suelto).
- Canal `edge` redirigido a los repos binarios **v22.12** (Alpine v3.17) vía
  `config/pmos-historical-channels.cfg`.
- Kernel `linux-postmarketos-qcom-sm6125` 6.1 @`77de535b` compilado con
  `pmb:cross-native` (nativo x86_64 + gcc-aarch64, sin qemu) desde el APKBUILD
  congelado.
- Salida: `xiaomi-laurel.img` (MBR: p1 /boot ext2, p2 / ext4), boot.img header
  v0 y vbmeta flags=2, con manifest y SHA-256 auditables.

## Consecuencias

- Workflows: `09-reproduce-historical-boot` (variantes boot v0) y
  `10-build-historical-rootfs` (rootfs + export + validación MBR/particiones).
- El rootfs completo se destinará al **slot b** (`fastboot flash system_b`,
  secuencia EX3 de `reports/historical-flash-instructions.md`), dejando el
  slot a intacto como punto de retorno.
- DECISION-0008 (APKBUILD preliminar propio) queda superada como base del
  proyecto: la línea principal de validación es la reproducción histórica.
- El kernel mainline v7.1 + parches downstream (workflows 02/03) continúa como
  línea de desarrollo propia, pero su prueba física está supeditada a FASE 8.

## Limitaciones conocidas

- El repo binario v22.12 actual difiere del estado de dic 2022 (bumps de
  seguridad, p. ej. `musl-aarch64` r5 vs r4 del árbol congelado). La
  reproducción es funcional, no bit-por-bit.
- `gcc-aarch64` del árbol congelado es r5, pero sus subpaquetes (p. ej. `g++`)
  pinnean `libstdc++=12.2.1_git20220924-r5` y Alpine v3.17 actual solo
  proporciona r4: el r5 es ininstalable. El workflow aplica un workaround
  local que revierte el árbol a `pkgrel=4`, consistente con el repo binario
  v22.12, para que pmbootstrap use el cross-compiler binario r4 y no lo
  recompile.
- No hay garantía de que el port de 2022 arranque en esta unidad: es una
  reproducción para validar hipótesis, no una afirmación de funcionamiento.

## Aprendizajes operativos (runs 31252993573 y siguientes)

- `pmbootstrap install` de 1.52.0 intenta fijar la clave del usuario `pmos`
  de forma **interactiva en bucle infinito** cuando el stdin no aporta la
  contraseña (`Failed to set the password. Try it one more time.`), colgando
  el job hasta el timeout (run 31252993573). Fix: pasar `--password` en la
  invocación (usa `chpasswd`, no interactivo).
- `deviceinfo_rootfs_image_sector_size=4096` (eMMC 4Kn del laurel_sprout)
  hace que pmbootstrap use `losetup -b 4096` y que parted escriba el MBR con
  LBA en sectores de 4096 bytes. La validación de particiones debe leer ese
  valor del deviceinfo congelado y usar `dd bs=$SECTOR`, no `bs=512` (el
  desfase 8x rompería e2fsck).
- `simg2img` y `img2simg` los provee el paquete Alpine `android-tools`, que
  pmbootstrap instala en el chroot nativo automáticamente cuando
  `deviceinfo_flash_sparse=true`.
