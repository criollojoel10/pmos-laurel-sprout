# FASE B0 — Análisis de imágenes de referencia (boot layout)

Estado: **completo**. Solo lectura. Ninguna imagen se flasheó ni se ejecutó script de flash.

Fuentes en `local-private/rom-references/` (privadas, no en Git) y resultados en
`local-private/rom-analysis/` (privados). Informes públicos derivados de estos datos en `reports/`.

## 1. Imágenes analizadas

| Referencia | Descripción | SHA-256 |
|---|---|---|
| Stock Xiaomi global V12.0.26.0.RFQMIXM (Android 11, 2022-08) | tgz | `0e6b3c…44fe3c` |
| Stock `images/boot.img` | boot | md5 `814dd1c3` |
| Stock `images/dtbo.img` | dtbo | md5 `0fc29667` |
| Stock `images/vbmeta.img` | vbmeta | md5 `a75f18ae` |
| /e/OS 4.1.1 (Android 16) community | zip | `66b8ea…1ecb1e40` |
| /e/OS `boot.img` (= `recovery.img`) | boot | `87ceeb…7241fb` |
| /e/OS `dtbo.img` / `vbmeta.img` | extraídos del payload | resp. `033b4a…` / `b5c6ca…` |

Los 3 hashes de las imágenes stock coinciden con `md5sum.xml` del paquete (integridad verificada).

## Boot image header (IDÉNTICO en stock y /e/OS)

Campo clave del layout que debe usar el port mainline:

- magic `ANDROID!`
- **header_version 2**
- **page size 4096**
- **base 0x00000000**
- **kernel_load_offset 0x8000**
- **ramdisk_load_offset 0x1000000**
- **tags_offset 0x100**
- **second_offset 0x0**
- **dtb_offset 0x1f00000**
- kernel y ramdisk = **gzip**
- tamaño boot.img = 67108864 (64 MiB) → límite para nuestro boot diagnóstico

El requisito observable del bootloader (aboot en este dispositivo) es `header v2 + page 4096 + base 0x00000000
+ offsets kernel/ramdisk/tags/dtb`. Esto es independiente del vendor code; es la convención use para trinket
y coincide con lo que ya adoptamos en `docs/NON-DESTRUCTIVE-BOOT.md`.

## Selección del Device Tree

- **Stock**: boot lleva **multi-DTB concatenado** (11 DTBs) usando `qcom,msm-id` + `qcom,board-id` para selección
  por aboot. El que corresponde a trinket SM6125 es `qcom,trinket` con `msm-id = <0x18a 0x10000>` (0x18a = **394**).
- **/e/OS**: boot lleva **un solo DTB** `qcom,trinket` (mismo compatible, same msm-id), 466682 bytes.

Conclusión: el bootloader acepta un DTB genérico `qcom,sm6125`/`qcom,trinket` embebido en boot.img. Para
nuestro boot diagnóstico usaremos el DTS **`sm6125-xiaomi-laurel-sprout`** si aplica en display, o el DTS
`sm6125` base — a decidir en función de qué DTS mainline compilamos para esta placa. (El stock/`/e/OS` usan
el genérico `qcom,trinket`; el port preferirá el específico de xiaomi si existe upstream.)

## dtbo

- **Stock**: formato **DTBO v0**, **17 entradas** (IDP / QRD / RUMI / IOT de Qualcomm; no hay DTB de Xiaomi;
  ninguno es el `laurel_sprout`).
- **/e/OS**: DTBO v0, **1 entrada** `QRD`.

Ninguno contiene partición de dtbo de Xiaomi específica: son overlays de devboard de referencia. Para un SO
mainline/upstream el dtbo **no es necesario**: el DTB va embebido en boot.img y el panel se cablea en el device
tree base. Esto refuerza que no hay que tocar `dtbo` para el port (ni se debe borrar). 

## vbmeta

- **Stock**: `avbtool 1.1.0`, RSA2048 SHA256, **flags 0**, `rollback index 0`; contiene `HTree descriptor` para
  boot/dtbo/product/vendor, `Hash descriptor` para boot/dtbo.
- **/e/OS**: `avbtool 1.3.0`, RSA4096 SHA256, **flags 3** (hashtree + verificación avb deshabilitadas). 

La flag 3 en `/e/OS` explica por qué pueden entregar boot/recovery no firmados con claves stock: avb verificación
deshabilitada en vbmeta semilla. Para `fastboot boot` (FASE E) no interfere si el slot no es marcado failed.

## flash scripts (stock) — NO ejecutados

Auditoría (solo lectura) de `flash_all.sh` / `flash_all_except_data_storage.sh`:

1. Comprobación de **antirollback**: `fastboot getvar anti`, aborta si `anti > 0` del paquete (paquete `anti=0`).
2. **product = laurel_sprout** — verifica que no flasheemos el modelo equivocado.
3. Flashea **ambos slots A/B** para firmware: tz, xbl, xbl_config, rpm, abl, devcfg, hyp, cmnlib, cmnlib64,
   keymaster, qupfw, imagefv, bluetooth, uefisecapp, storsec, dsp, modem.
4. **Borra** (erase) las particiones de datos previo al flash: `boot_a/b`, `system_a/b`, `vendor_a/b`,
   `mdtp_a/b`, y en `flash_all.sh` además `userdata`.
5. Flashea `vbmeta_a/b`, `dtbo_a/b`, `vendor_a/b`, `system_a/b`, `product_a/b`, `boot_a/b` en A/B.
   **No hace `set_active`**: confía en el slot actual y deja que aboot decida.
6. `fastboot reboot` final.
6. `fastboot reboot` final.

Aprendizajes para nuestro uso (no flasheable aquí):
- Un flash de seguridad (si un día se repara) debe respetar **en ambos slots** las particiones de arranque y
  borrar `userdata` solo si se quiere borrado total (excepto `_except_data` conserva datos).
- NO se debe ejecutar `fastboot erase dtbo` por la guía histórica; el layout demuestra que dtbo es solo overlay
  de devboard y el DTB va en boot.img. Eliminar dtbo es innecesario y arriesgado para el SO stock.

## /e/OS initramfs (referencia al initramfs Android, no a la nuestra)

Tanto stock como /e/OS usan **initramfs de Android completo**: `init` = symlink a `/system/bin/init`,
`first_stage_ramdisk`, `apex`, sepolicy, etc. No es una referencia directa para nuestro initramfs Linux
minimalista/lpm (nuestro es un `init` BusyBox/busybox con util-linux). La referencia válida para nuestro es
`/e/OS` en cómo **desactivan verificación** (flags 3) y usan recovery-in-otro, no la estructura de su ramdisk.

## Reglas confirmadas para las fases siguientes

- **ORIGINAL_SLOT** actual = `a`; si un día se flashea: validar a/b, registra ORIGNAL/TARGET/EXPECTED, usar
  `boot_a`/`boot_b` explícitos, consultar `current-slot` tras los flashes y restaurar EXPECTED, abortar si no
  coincide; nunca `set_active` automático; `fastboot boot` (FASE E) no cambia slot ni requiere verificación AVB.
- **Gate de construcción**: boot.img mainline debe caber en **64 MiB** y usar header v2/page 4096/offsets
  documentados. QCDT NO necesario (usar DTB embebido simple con el compatible correcto).
- No ejecutar scripts `flash_all*` ni ninguna imagen de referencia (reglas AGENTS y aquí).

## Reportes relacionados

- `reports/stock-boot-layout.json`
- `reports/eos-boot-layout.json`
- `reports/dtb-audit-structured.md` (fase A)

## Pendiente (B0) → se resuelve en fases siguientes

- Decidir DTB exacto (sm6125-genérico vs sm6125-xiaomi-laurel-sprout) al construir la imagen (FASE D).
- Configurar offsets de consumición en el `mkbootimg` que armaremos (script del repo).