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

La wiki daba el siguiente flujo (los prefijos `$` y `#` son **prompts de shell**:
`$` = usuario normal, `#` = root; NO son comentarios de script):

```
$ pmbootstrap init
$ pmbootstrap install
# fastboot erase dtbo            → sudo fastboot erase dtbo
$ pmbootstrap flasher flash_vbmeta
$ pmbootstrap flasher flash_rootfs
$ pmbootstrap flasher flash_kernel
# fastboot reboot                → sudo fastboot reboot
```

> CORRECCIÓN (2026-08-05): `erase dtbo` y `reboot` NO estaban comentados. El
> prefijo `#` es el prompt de root. Ver `reports/historical-installation-correction.md`.

Clasificación respecto a NUESTRO objetivo (boot no destructivo vía `fastboot boot`):

| Paso histórico | Clasificación | Justificación |
|---|---|---|
| `pmbootstrap init` | `con modificación` | En nuestro flujo no hay pmbootstrap; la build es GH Actions (workflow 04). |
| `pmbootstrap install` | `con modificación` | Nosotros generamos rootfs en GH Actions; para diagnóstico no se instala rootfs. |
| `sudo fastboot erase dtbo` | **`peligroso / a verificar** | **Activo en el flujo original** (no comentado). El layout (B0) sugiere que dtbo contiene overlays de devboard; sin embargo el port histórico lo ejecutaba como root. Para nuestro arranque experimental, si se prueba un día, se hará SOLO sobre `dtbo_b` con respaldo previo (H3). NO se ejecuta sin gate/autorización. |
| `pmbootstrap flasher flash_vbmeta` | `peligroso / no aplica ahora` | Solo necesario cuando se instala rootfs permanente (vbmeta con flags para deshabilitar verificación). Parte del flujo de instalación completo, no del arranque puntual. |
| `pmbootstrap flasher flash_rootfs` | `no aplica (fase posterior)` | Escritura destructiva que requiere respaldos previos; parte del flujo completo. |
| `pmbootstrap flasher flash_kernel` | `no aplica` | No se flashea boot en este proyecto (diagnóstico). |
| `fastboot reboot` | `no aplica` | Con arranque temporal (`fastboot boot`) no se invoca reboot manual; el dispositivo ya está en Fastboot. |

Conclusión B1 (revisada): La guía histórica describe un **flujo completo de
instalación** (init → install → erase dtbo → flash vbmeta → flash rootfs →
flash kernel → reboot). Ningún paso de escritura se reproduce aquí como tal, pero
**no debe afirmarse que `erase dtbo` era opcional/comentado**: era parte activa y
obligatoria del flujo original ejecutada como root. Los datos de configuración
(offsets, padding, DTB, cmdline `clk_ignore_unused`) se mantienen como
referencia y ya coinciden con el análisis de B0 y el DTS mainline v7.1.

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
