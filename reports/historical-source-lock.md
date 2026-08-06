# Reporte R1 — Congelación de fuentes del port histórico xiaomi-laurel

Fecha de congelación: 2026-08-05. Estado: verificado contra upstream (API
GitLab + git ls-remote). Ninguna escritura sobre el dispositivo.

## Resumen de conclusiones

El port `xiaomi-laurel` fue archivado en pmaports el 2026-07-31 (commit
`ddf655bb`, MR 9179). La receta publicada en la wiki (captura 20240121085749,
última edición 13 nov 2023) corresponde al estado del device package y kernel
del **14 dic 2022** (MR 3727). Se congelan esos commits exactos.

## Commits congelados

| Fuente | Repositorio | Commit / ref | Fecha | Estado |
|---|---|---|---|---|
| device-xiaomi-laurel (deviceinfo + APKBUILD) | pmaports | `a27a7ce7373a6e2125a2c3125370e40d04bf65df` (MR 3727, "add missing deviceinfo parameters") | 2022-12-14 | verificada |
| linux-postmarketos-qcom-sm6125 (kernel 6.1) | pmaports APKBUILD @7aaee51a | kernel commit `77de535b8dbd8f483b5802c8937cb714bab5b485` | 2022-12-14 (APKBUILD), kernel 2022-12-13 | verificada |
| Kernel sm6125-mainline v6.1 | gitlab.com/sm6125-mainline/linux | `77de535b8dbd8f483b5802c8937cb714bab5b485` (HEAD de develop; tag `v6.1-sm6125` = `d191a936`) | 2022-12-13T17:49:07-03:00 | verificada (ls-remote + API) |
| pmbootstrap | pmbootstrap | tag `1.50.0` (2022-11-20) — contemporáneo al port | 2022-11-20 | verificada-url |
| boot-deploy | pmaports main/boot-deploy @7aaee51a | `0.6.1` | 2022 | verificada |
| mkbootimg (C fork) | osm0sis/mkbootimg | `2021.08.06` | 2021-08-06 | verificada |
| postmarketos-mkinitfs | pmaports main @7aaee51a | `1.5.1-r3` | 2022 | verificada |

## Nota sobre el commit del kernel

El commit **`77de535b`** es el HEAD de la rama `develop` del repo
`sm6125-mainline/linux` y coincide con el fijado por el APKBUILD
`linux-postmarketos-qcom-sm6125` **pkgver=6.1** (commit `7aaee51a`, MR 3727,
2022-12-14). Este es el kernel de la receta publicada en la wiki.

- Tag `v6.1-sm6125` → `d191a93642ad2583cc7ba7c3d758fdb99bf99ed1` (mensaje: Linux
  v6.1-sm6125, UFS support). Es la etiqueta de release; `77de535b` es el HEAD de
  develop (posteriores cambios).
- La versión previa (deviceinfo a27a7ce, kernel package a27a7ce `fe3f5008`
  2022-12-10, pkgver=6.0) usaba el commit `cb1a531d` (6.0). No es la receta final.

## Receta histórica (flujo de instalación)

```
$ pmbootstrap init
$ pmbootstrap install
# fastboot erase dtbo          (prompt root)
$ pmbootstrap flasher flash_vbmeta
$ pmbootstrap flasher flash_rootfs
$ pmbootstrap flasher flash_kernel
# fastboot reboot              (prompt root)
```

### Comandos reales que pmbootstrap 1.50.0 genera (del código `pmb.config.flashers["fastboot"]`)

| Acción | Comandos generados | Partición | Archivo |
|---|---|---|---|
| flash_rootfs | `fastboot flash $PARTITION_SYSTEM $IMAGE` | **system** (default; deviceinfo no define `flash_fastboot_partition_system`) | `/home/pmos/rootfs/xiaomi-laurel.img` |
| flash_kernel | `fastboot flash $PARTITION_KERNEL $BOOT/boot.img` | **boot** (default) | `/mnt/rootfs_xiaomi-laurel/boot/boot.img` |
| flash_vbmeta | `avbtool make_vbmeta_image --flags 2 --padding_size $FLASH_PAGESIZE --output /vbmeta.img` luego `fastboot flash $PARTITION_VBMETA /vbmeta.img` | **vbmeta** (deviceinfo `flash_fastboot_partition_vbmeta="vbmeta"`) | `/vbmeta.img` (generado, luego `rm`) |
| flash_dtbo (hook, no en guía) | `fastboot flash $PARTITION_DTBO $BOOT/dtbo.img` | dtbo | `/boot/dtbo.img` |

Variables usadas (de `pmb.flasher.variables`, method fastboot):
- `$PARTITION_KERNEL` = deviceinfo `flash_fastboot_partition_kernel` o **"boot"**
- `$PARTITION_SYSTEM` = deviceinfo `flash_fastboot_partition_system` o **"system"**
- `$PARTITION_VBMETA` = `"vbmeta"` (definido)
- `$PARTITION_DTBO` = None (no definido en deviceinfo)
- `$FLASH_PAGESIZE` = `4096`
- `$DTB` = `-dtb` cuando `deviceinfo_append_dtb="true"`

> IMPORTANTE: el port usaba **nombres de partición sin sufijo A/B**
> (`boot`, `system`, `vbmeta`). La guía pmOS de 2022 no manejaba A/B con
> sufijos automáticos; `fastboot flash boot` mapea al slot activo (o al que
> aboot decida). Este es un punto central para reproducir en nuestro dispositivo
> A/B laurel_sprout (ver R10/R12).

### flash_vbmeta — detalle crítico

pmbootstrap 1.50.0 genera el vbmeta con:

```
avbtool make_vbmeta_image --flags 2 --padding_size 4096 --output /vbmeta.img
```

- **Flags = 2** → `AVB_VBMETA_IMAGE_FLAGS_VERIFICATION_DISABLED`: deshabilita la
  **verificación AVB** de la cadena de arranque (el bootloader no verifica el
  vbmeta). NO deshabilita el hashtree/dm-verity. (flags=1 =
  HASHTREE_DISABLED; flags=3 = ambas; flags=1+2=3.)
- Se generó **sobre la marcha** en el host (chroot), no era un artefacto fijo.
- `--padding_size 4096` → vbmeta de 4096 B.

Esto es RELEVANTE: un vbmeta con flags=2 le dice al bootloader que no verifique
el slot. IT2 usó vbmeta /e/OS con flags=3 (verificación+verity desactivadas),
que también cubre la no-verificación. La reproducción histórica usa **flags=2**.

### Construcción EXACTA del boot.img histórico (hallazgo R3 — código)

Cadena completa verificada en el código fuente congelado:

1. **`postmarketos-mkinitfs` 1.5.1** (`main.go`, línea 82) delega el boot.img a
   **`boot-deploy`** (no lo genera él mismo):
   `boot-deploy -i initramfs -k vmlinuz -d $work -o /boot initramfs-extra`.
2. **`boot-deploy` 0.6.1** (`boot-deploy-functions.sh`):
   - `append_or_copy_dtb()`: con `append_dtb=true`, genera
     `$input/vmlinuz-dtb = vmlinuz + DTB` concatenados y lo añade a
     `additional_files`.
   - `create_bootimg()`: `deviceinfo_generate_bootimg=true` y no pxa →
     `MKBOOTIMG=mkbootimg-osm0sis` (fork C de osm0sis, `provides mkbootimg`,
     dependencia del APKBUILD device). Como `header_version` NO está definido,
     **NO** añade `--header_version 2 --dtb_offset ... --dtb ...`. Como
     `qcdt=false`, **NO** añade `--dt /boot/dt.img`. Como `dtb_second=false`,
     **NO** añade `--second`.
   - Comando resultante (deviceinfo histórico):

```
mkbootimg-osm0sis \
  --kernel /boot/vmlinuz-dtb \
  --ramdisk initramfs \
  --base 0x00000000 \
  --second_offset 0x00f00000 \
  --cmdline clk_ignore_unused \
  --kernel_offset 0x00008000 \
  --ramdisk_offset 0x01000000 \
  --tags_offset 0x00000100 \
  --pagesize 4096 \
  -o /boot/boot.img
```

   - Este es **exactamente** el formato de nuestra variante V2/IT3
     (append_dtb=true, qcdt=false, dtb_size=0, base=0x00000000, mismos
     offsets). Lo que probamos en IT3 ya es el formato histórico.
3. **Nombre del archivo**: boot-deploy copia el resultado como `/boot/boot.img`.
   Como `pmaports.cfg @7aaee51a` define `supported_mkinitfs_without_flavors=True`,
   el flasher usa `$FLAVOR=""` → `flash_kernel` flashea
   `$BOOT/boot.img` (sin sufijo de flavor).
4. **boot.img v0 (header AOSP clásico)**, tamaño = header + kernel(+dtb) +
   ramdisk, con `dtb_size=0` (el DTB va concatenado al kernel, no en sección v2).

### Discrepancia clave con /e/OS y nuestro testeo

- El histórico de pmOS **nunca** usaba `--header_version 2`. Nuestra TEST_IMG
  (IT1) sí lo usaba (dtb_size != 0). IT3 (dtb_size=0) ya es fiel al histórico.
- La cmdline histórica es **solo** `clk_ignore_unused`.
- El vbmeta histórico usaba **flags=2**.
- El boot se flasheaba a **boot** sin sufijo (ver nota A/B arriba).

## Hashes de artefactos descargados

Ver `local-private/historical-port/sources/` (SHA256 de cada archivo registrado
en el árbol). Hash clave:

| Archivo | SHA256 |
|---|---|
| deviceinfo-xiaomi-laurel.a27a7ce.txt | `54f9766e1540d3a75e1fe1d2d7606bc68afa62fd17db93b503e484878138751a` |
| config kernel 6.1 (7aaee51a) | `08bcee71d4164ef3e7c1244cdf4d5a0e4e7e2eedcadd9e5576166f8661417c4a` |
| APKBUILD kernel 6.1 (7aaee51a) | `03558f1f363249eb9158751d008830587d97e7bd666ad19707902affefc7c728` |

## Fuentes

- `sources.lock.json` actualizado con 4 nuevas entradas históricas verificadas.
- Artefactos locales: `local-private/historical-port/sources/`.
- `local-private/historical-port/logs/` para logs de auditoría.