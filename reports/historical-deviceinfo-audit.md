# Reporte R2 — Auditoría del deviceinfo histórico xiaomi-laurel

Fecha: 2026-08-05. Fuente exacta: `device/testing/device-xiaomi-laurel/deviceinfo`
en commit `a27a7ce7373a6e2125a2c3125370e40d04bf65df` (MR 3727, 2022-12-14),
verificado contra la API GitLab. Copia local:
`local-private/historical-port/sources/deviceinfo-xiaomi-laurel.a27a7ce.txt`
(SHA256 `54f9766e…`). Es byte-idéntico a `local-private/pmaports-deviceinfo-xiaomi-laurel.txt`.

## Valores históricos verificados

| Parámetro | Valor histórico | Notas |
|---|---|---|
| `deviceinfo_format_version` | `0` | |
| `deviceinfo_name` | `Xiaomi Mi A3` | |
| `deviceinfo_manufacturer` | `Xiaomi` | |
| `deviceinfo_codename` | `xiaomi-laurel` | pmbootstrap device (NO `laurel_sprout`) |
| `deviceinfo_year` | `2019` | |
| `deviceinfo_dtb` | `qcom/sm6125-xiaomi-laurel_sprout` | DTS del port |
| `deviceinfo_arch` | `aarch64` | |
| `deviceinfo_chassis` | `handset` | |
| `deviceinfo_keyboard` | `false` | |
| `deviceinfo_external_storage` | `true` | |
| `deviceinfo_screen_width/height` | `720` / `1560` | |
| `deviceinfo_flash_method` | `fastboot` | |
| `deviceinfo_kernel_cmdline` | `clk_ignore_unused` | cmdline mínima histórica |
| `deviceinfo_generate_bootimg` | `true` | pmbootstrap genera boot.img |
| `deviceinfo_flash_fastboot_partition_vbmeta` | `vbmeta` | partición sin sufijo |
| `deviceinfo_bootimg_qcdt` | `false` | NO tabla QCDT |
| `deviceinfo_bootimg_mtk_mkimage` | `false` | |
| `deviceinfo_bootimg_dtb_second` | `false` | DTB no va en "second" |
| `deviceinfo_append_dtb` | `true` | DTB concatenado al kernel |
| `deviceinfo_rootfs_image_sector_size` | `4096` | |
| `deviceinfo_flash_pagesize` | `4096` | |
| `deviceinfo_flash_sparse` | `true` | imagen sparse |
| `deviceinfo_flash_offset_base` | `0x00000000` | |
| `deviceinfo_flash_offset_kernel` | `0x00008000` | |
| `deviceinfo_flash_offset_ramdisk` | `0x01000000` | |
| `deviceinfo_flash_offset_second` | `0x00f00000` | |
| `deviceinfo_flash_offset_tags` | `0x00000100` | |

**No definidos** en el deviceinfo (relevantes): `flash_fastboot_partition_kernel`
(default "boot"), `flash_fastboot_partition_system` (default "system"),
`flash_fastboot_partition_dtbo` (None), `flash_fastboot_max_size` (sin límite).

## Aclaraciones conceptuales (evitar confusiones documentadas)

1. **append_dtb=true** → el payload del kernel = `Image.gz + DTB` concatenados.
   En pmbootstrap 1.50.0 esto se refleja en la variable `$DTB="-dtb"` usada por
   el flasher y en el nombre `vmlinuz-dtb`; boot-deploy/mkinitfs colocan el
   kernel con el DTB pegado al final para que aboot lo pase a Linux.
2. **bootimg_qcdt=false** → no se construye una tabla Qualcomm QCDT (multi-DTB).
   El boot.img usa el layout clásico AOSP (header + kernel + ramdisk [+ dtb]).
3. Diferencia clave:
   - **DTB concatenado al kernel** (append_dtb) = el modo histórico aquí.
   - **Sección DTB del header v2** (`dtb_size`/`dtb_addr`) = lo que usó nuestra
     TEST_IMG (IT1) — NO es QCDT, es el campo v2 estándar.
   - **Tabla QCDT** = mecanismo Qualcomm de múltiples DTBs en una sección.
   - **DTBO overlay partition** = partición aparte con overlays (dtbo.img).
4. El histórico NO tocaba `dtbo` en el deviceinfo (no hay
   `flash_fastboot_partition_dtbo`). El `erase dtbo` de la guía se hacía a mano
   como root, antes del flasheo.

## Implicaciones para reproducción (kernel 7.1 y 6.1)

- Nuestra **variante V2/IT3** (append_dtb=true, qcdt=false, dtb_size=0) ya
  reproduce la entrega del DTB del histórico. Coherente con lo que pmbootstrap
  1.50.0+boot-deploy habrían producido.
- La **cmdline histórica** era solo `clk_ignore_unused`. Nuestra TEST_IMG usó
  `console=ttyMSM0,115200n8 clk_ignore_unused androidboot.hardware=qcom …`.
- El vbmeta histórico se generaba con **flags=2** (`--flags 2`), no 3.
- Rootfs se flasheaba a **system**; el boot a **boot** (sin sufijo A/B).

## Origen y cadena de verificación

- Commit exacto: `a27a7ce7373a6e2125a2c3125370e40d04bf65df`.
- Ruta: `device/testing/device-xiaomi-laurel/deviceinfo`.
- Verificado con la API GitLab (raw). Byte-idéntico a la copia local previa.
- El mismo commit (MR 3727) actualizó el APKBUILD del device (`pkgver=0.1
  pkgrel=3`) y el kernel a 6.1 (`7aaee51a`).