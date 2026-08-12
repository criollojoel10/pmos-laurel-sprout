# Decisión de transporte WCN3990 — Linux 6.1

Fecha: 2026-08-12. Evidencia runtime capturada antes de cambios en
`local-private/diagnostics/wifi-priority/baseline-before-wifi-20260812T131500Z/`.

## Resultado

**TRANSPORTE PROBABLE, FALTA EVIDENCIA FÍSICA DE PROBE.**

La hipótesis de trabajo es **SNOC mediante `ath10k_snoc`**, no SDIO. No se
declara `working` ni `detected`: el DT 6.1 instalado carece del nodo Wi-Fi y no
hay `wlan0`, `phy`, `rfkill` ni firmware cargado.

## Comparación

| Alternativa | Evidencia laurel/árbol 6.1 | Driver/match | Veredicto |
|---|---|---|---|
| SNOC / `ath10k_snoc` | El driver instalado anuncia `Driver support for Atheros WCN3990 SNOC devices` y alias `qcom,wcn3990-wifi`; el DT Android de referencia usa `icnss@C800000`; el parche downstream 7.1 usa `wifi@c800000` | `ath10k_snoc.ko`, `of:N*T*Cqcom,wcn3990-wifi` | **Probable** |
| SDIO / `ath10k_sdio` | `CONFIG_ATH10K_SDIO` no está configurado; ambos `mmc@4744000` y `mmc@4784000` están `status = "disabled"`; `/sys/class/mmc_host` está vacío | No hay `ath10k_sdio` operativo | No soportado por la evidencia |
| WCNSS/WCSS remoteproc | Config tiene `QCOM_Q6V5_WCSS`, `QCOM_WCNSS_PIL` y `QCOM_WCNSS_CTRL`, pero el DT instalado no tiene nodos `wcss`, `remoteproc`, `q6` o `icnss` y no hay dmesg de remoteproc | No hay match DT runtime | Dependencia no demostrada |
| ICNSS/QMI vendor | `icnss@C800000` aparece en el DT Android de referencia, no en el DT Linux 6.1; el driver Linux presente hace match con `qcom,wcn3990-wifi`, no con `qcom,icnss` | QMI/QRTR disponibles, nodo ausente | Referencia comparativa |

## Datos específicos

- SoC: SM6125 / trinket / laurel_sprout.
- Dirección propuesta por la referencia vendor y parche 7.1: `0x0c800000`,
  tamaño `0x800000`.
- Memoria reservada existente: `memory@53300000`, tamaño `0x200000`,
  equivalente a `wlan_msa_mem` en `sm6125.dtsi` @ `77de535b`.
- El driver 6.1 `snoc.c` llama a `of_dma_configure`,
  `iommu_domain_alloc`, `iommu_attach_device` e `iommu_map` (líneas 1616-1641
  del archivo descargado del commit fijado) únicamente para el subnodo
  `wifi-firmware`; sin ese subnodo entra en la ruta TrustZone (`use_tz=true`).
- El DT 6.1 no tiene `apps_smmu`; la rama moderna de referencia define
  `apps_smmu: iommu@c600000`, compatible `qcom,sm6125-smmu-500`. El primer
  probe no añade SMMU ni `iommus` porque usa la ruta TrustZone; si el probe
  demuestra que el firmware necesita el subnodo IOMMU, se hará una variante
  posterior separada. El SID de Wi-Fi `0x80` está confirmado para SM6125 en el
  parche 7.1.
- El driver 6.1 pide clocks opcionales `cxo_ref_clk_pin`/`qdss` y cinco
  nombres de regulator: `vdd-0.8-cx-mx`, `vdd-1.8-xo`, `vdd-1.3-rfa`,
  `vdd-3.3-ch0`, `vdd-3.3-ch1`. El mapping físico del quinto no está
  demostrado.
- IMPORTANTE (revisión independiente 2026-08-12): con DT poblada, un supply
  ausente NO aborta el probe: `have_full_constraints()` es true vía
  `of_have_populated_dt()`, `dummy.o` se compila con `CONFIG_REGULATOR=y` y
  `regulator_dummy_init()` se llama incondicionalmente en `regulator_init`;
  por tanto `devm_regulator_bulk_get` resolverá `vdd-3.3-ch1` con el dummy
  regulator (warning) y el probe continuará. El primer probe NO debe
  interpretarse como "fallo por regulator faltante".

## Decisión de implementación

No activar MMC/SDIO por intuición. La primera variante deberá probar el camino
SNOC con DT explícito, SMMU y firmware, conservando RNDIS/SSH. Antes de aplicar
el cambio se debe resolver el quinto supply `vdd-3.3-ch1` con evidencia del
hardware o una decisión documentada; no copiar L22A/L24A sin demostración.

## Fuentes

- `local-private/diagnostics/wifi-priority/baseline-before-wifi-20260812T131500Z/`
- `patches/kernel/0004-dts-enable-wifi-wcn3990.patch` (7.1, downstream-only)
- `reports/firmware-wcn3990-inventory.md`
- LineageOS `android_kernel_xiaomi_sm6125` @ `713c1f8d`, `trinket.dtsi`,
  `icnss@C800000`
- `sm6125-mainline/linux` @ `77de535b8dbd8f483b5802c8937cb714bab5b485`
