# FASE B1 — Contraste con la guía histórica postmarketOS (xiaomi-laurel)

Fecha del análisis: 2026-08-03. Todo el contraste es análisis estático; nada se ejecutó sobre el teléfono.

## Fuentes consultadas

1. **Wiki postmarketOS** `Xiaomi_Mi_A3_(xiaomi-laurel)`, capture Wayback `20240121085749`
   (última edición 13 Nov 2023). El original está tras Anubis.
   Guardado en `local-private/wiki-xiaomi-laurel-20240121.md`.
2. **pmaports** `device/testing/device-xiaomi-laurel` (APKBUILD + deviceinfo), vía API GitLab.
   Guardados en `local-private/pmaports-deviceinfo-xiaomi-laurel.txt` y
   `local-private/pmaports-APKBUILD-xiaomi-laurel.txt`.
3. **Fork histórico SM61x5** `linux` commit `77de535b8dbd8f483b5802c8937cb714bab5b485`
   (kernel 6.1, dic 2022) que mantiene Lux Aliaga; DTS
   `arch/arm64/boot/dts/qcom/sm6125-xiaomi-laurel_sprout.dts`.
   Guardado en `local-private/dts-sm6125-xiaomi-laurel_sprout-2022.dts`.

## Datos duros obtenidos del port histórico

| Parámetro | Valor histórico (pmaports deviceinfo) | Coincide con nuestro análisis B0 |
|---|---|---|
| `deviceinfo_dtb` | `qcom/sm6125-xiaomi-laurel_sprout` | Sí — DTS específico, no genérico |
| `deviceinfo_generate_bootimg` | `true` | boot.img (fastboot) |
| `deviceinfo_bootimg_qcdt` | `false` | sí, no usamos QCDT |
| `deviceinfo_append_dtb` | `true` | sí, DTB embebido |
| `deviceinfo_flash_pagesize` | `4096` | sí |
| `deviceinfo_flash_offset_base` | `0x00000000` | sí |
| `deviceinfo_flash_offset_kernel` | `0x00008000` | sí |
| `deviceinfo_flash_offset_ramdisk` | `0x01000000` | sí |
| `deviceinfo_flash_offset_second` | `0x00f00000` | (no usamos second) |
| `deviceinfo_flash_offset_tags` | `0x00000100` | sí |
| `deviceinfo_kernel_cmdline` | `clk_ignore_unused` | a adoptar en nuestro cmdline |
| `deviceinfo_flash_method` | `fastboot` | sí |
| `deviceinfo_flash_fastboot_partition_vbmeta` | `vbmeta` | relevante solo si flasheáramos |

El fork histórico confirma:
- Kernel postmarketOS 6.1 para SM6125 con DTS específico `sm6125-xiaomi-laurel_sprout`.
- DTS usa `qcom,msm-id = <0x18a 0x00>` y `qcom,board-id = <0x0b 0x00>` — **idénticos al DTS mainline v7.1 que
  ya compilamos** (verificado en `sm6125-xiaomi-laurel-sprout.dtb`).
- El DTS histórico declara `framebuffer@5c000000` simple-framebuffer (720x1560, a8r8g8b8), ramoops,
  regulators PM6125, UFS, USB (dwc3) con extcon, sdc2 CD gpio98, `gpio-reserved-ranges = <22 2>, <28 6>`.
- Firma del DTB: compatible `xiaomi,laurel_sprout` + `qcom,sm6125`.

## Clasificación de los pasos de la guía histórica

La wiki daba el siguiente flujo (con `#` como comentarios del guion original):

```
$ pmbootstrap init
$ pmbootstrap install
# fastboot erase dtbo
$ pmbootstrap flasher flash_vbmeta
$ pmbootstrap flasher flash_rootfs
$ pmbootstrap flasher flash_kernel
# fastboot reboot
```

Clasificación respecto a NUESTRO objetivo (boot no destructivo vía `fastboot boot`):

| Paso histórico | Clasificación | Justificación |
|---|---|---|
| `pmbootstrap init` | `con modificación` | En nuestro flujo no hay pmbootstrap; la build es GH Actions (workflow 04). |
| `pmbootstrap install` | `con modificación` | Nosotros generamos rootfs en GH Actions; para diagnóstico no se instala rootfs. |
| `fastboot erase dtbo` | **`peligroso / obsoleto`** | La wiki lo tenía como comentario. El layout (B0) demuestra que dtbo solo contiene overlays de devboard (IDP/QRD/RUMI); no aporta al arranque mainline (DTB va en boot.img). Borrarlo es innecesario y degrada el stock. NO se ejecuta. |
| `pmbootstrap flasher flash_vbmeta` | `peligroso / no aplica` | Solo necesario cuando se instala rootfs permanente (vbmeta con flags para deshabilitar verificación, como hace /e/OS). Para `fastboot boot` no hace falta y NO se flashea. |
| `pmbootstrap flasher flash_rootfs` | `no aplica (fase posterior)` | Fuera del objetivo actual; sería escritura destructiva con respaldos previos. |
| `pmbootstrap flasher flash_kernel` | `no aplica` | Idéntico; no se flashea boot en este proyecto. |
| `fastboot reboot` | `no aplica` | No hay flash previo; el dispositivo ya está en Fastboot y tras `fastboot boot` (FASE E) arranca la imagen temporal; no se invoca reboot manual. |

Conclusión B1: **Ningún paso de escritura de la guía histórica se reproduce aquí.** Solo los datos de
configuración (offsets, pagesize, DTB, cmdline `clk_ignore_unused`) se toman como referencia, y ya coinciden
con el análisis de B0 y el DTS mainline v7.1.

## Reglas transaccionales de slot (confirmadas)

Registro formal para cualquier operación futura que flashee (NO se aplica a `fastboot boot`, pero se fija):

1. Al inicio de cualquier flujo con escritura: capturar `ORIGINAL_SLOT` (`fastboot getvar current-slot`).
   Valor actual observado: `a`.
2. Validar `slot-count` (2) y `has-slot` de las particiones objetivo.
3. Registrar tripla `ORIGINAL / TARGET / EXPECTED` antes de cualquier flash.
4. Usar nombres de partición explícitos A/B (`boot_a`, `boot_b`, `dtbo_a`, ...) — nunca sin sufijo.
5. Tras cada flash: `fastboot getvar current-slot`; si difiere de EXPECTED, ABORTAR y restaurar.
6. Prohibido `fastboot set_active` automático sin autorización explícita humana.
7. `fastboot boot` (nuestro método) NO cambia slot y no dispara marcado de "successful" en bootctrl;
   por tanto es el método mínimo-invasivo y el recomendado para la prueba inicial.
8. No marcar el slot como successful desde initramfs antes de montar rootfs (evita que un boot fallido
   quede como "good").

## Implicaciones para FASE C/D (nuestro init y boot)

- Cmdline del boot diagnóstico debe incluir `clk_ignore_unused` (referencia pmaports) además de los parámetros
  de consola/ramoops ya previstos.
- El DTB a embeder es `sm6125-xiaomi-laurel-sprout.dtb` (ya compilado en v7.1), que aboot selecciona por
  `msm-id 0x18a / board-id 0x0b`.
- `simple-framebuffer` declarado en `chosen` (a 0x5c000000) coincide con lo audotado del stock → el kernel
  mainline puede pintar consola/logo en la pantalla del stock (partial display).
- NO se requiere `dtbo` ni `vbmeta` para el boot temporal.
