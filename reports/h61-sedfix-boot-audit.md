# Auditoría boot sedfix (initramfs con sed y applets completos)

Run: 31330115568 (workflow 09, build_kernels=false, kernel_run_id=31147870090)
Artefacto: `historical-boot-images-sedfix` (descargado a `local-private/h61-sedfix/`)
Fecha: 2026-08-09
Estado: `boot-untested` (pendiente prueba física EX3 en slot b)

## Objetivo

Verificar que la única diferencia entre las imágenes v0 (con panic EX3) y las
sedfix es el ramdisk (initramfs), y que el nuevo initramfs contiene todos los
applets REQUIRED (incluido `sed`, la causa raíz, y `awk`, que el audit antiguo
reportaba falsamente como faltante).

## Artefactos

| Archivo | Tamaño | SHA-256 |
|---|---|---|
| boot-laurel-kernel-6.1-historical-v0-sedfix.img | 10,469,376 | `d2c8145d…9cc9596` |
| boot-laurel-kernel-7.1-v0-appenddtb-sedfix.img | 21,581,824 | `1b311cd7…76b4e959` |
| vbmeta-historical-flags2.img | 4,096 | `fe1f4b55…351f4ca2` |
| initramfs.cpio.gz | 1,208,589 | `a951d20f…c3fa1081` |

## Kernel 6.1 byte-idéntico al v0

Extracción independiente (Python, header v0, page 4096) comparando con
`local-private/workflow-09-artifacts/boot-out/boot-laurel-kernel-6.1-historical-v0.img`:

| Payload | v0 | sedfix | ¿Igual? |
|---|---|---|---|
| kernel (Image.gz+DTB) | `97b4bff0…98ac022a` | `97b4bff0…98ac022a` | SÍ (byte-idéntico) |
| ramdisk | 1,202,868 B | 1,208,589 B | NO (esperado) |

cmdline `clk_ignore_unused`, header v0, page 4096, kernel_size 9,252,106 sin
cambios. El boot 7.1 también conserva su kernel (`console=ttyMSM0,115200n8
clk_ignore_unus…`), solo cambia el ramdisk.

## vbmeta

`vbmeta-historical-flags2.img` SHA-256 `fe1f4b55…351f4ca2` coincide con el
estado persistente de `vbmeta_b` del dispositivo. NO se reflashea vbmeta en la
próxima iteración (solo `boot_b`).

## Initramfs sedfix

Verificación del workflow (`initramfs-verification.md`): PASS en todos los
puntos (gzip, cpio newc, shebang `#!/bin/busybox sh`, sin `set -e`,
`INITRAMFS_REACHED`, sin operaciones destructivas, busybox aarch64 estático).

Applets instalados según `busybox-applets.txt`: **407** (el audit antiguo con
`find -maxdepth 1` subcontaba 164 porque no veía enlaces a profundidad 2).

Todos los REQUIRED presentes:

`sh cat sed grep awk mount umount mkdir mknod sleep dmesg uptime ls cp sync
switch_root tr wc setsid` → OK (incluido `awk`, que estaba en `usr/bin/awk`,
profundidad 2, invisible para el find anterior).

Enlaces en `usr/bin/`: 182. En `usr/sbin/`: 60 (antes invisibles para la
auditoría).

## Lecciones

1. `make install` y la generación manual de enlaces dependen del mismo
   `busybox.links`; el fallo "falta awk" del run 31328942346 fue un **falso
   negativo de la auditoría** (`find bin sbin usr -maxdepth 1`), no una falta
   del applet: awk sí se compilaba e instalaba en `/usr/bin/awk`.
2. La auditoría correcta verifica cada ruta de `busybox.links` como enlace en
   el árbol y deriva `applets.txt` del propio `busybox.links` (no depende de la
   profundidad del find).
3. Se mantienen además las garantías estructurales del fix: CONFIG_* de cada
   applet REQUIRED forzados a `y` en `.config` antes de `silentoldconfig`, y
   validación de REQUIRED contra `busybox.links` (fuente de verdad del
   compilado) antes de crear enlaces.

## Pendiente

Prueba física EX3 en slot b: flashear SOLO `boot_b` con
`boot-laurel-kernel-6.1-historical-v0-sedfix.img` y confirmar
`INITRAMFS_REACHED` + rescue shell (criterio `INITRAMFS_6_1_SHELL_ACTIVE`).
