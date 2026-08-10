# Causa raíz: degradación silenciosa `=y → =m` tras `make olddefconfig`

**Estado:** `static-validation-passed` (verificado contra Kconfig del kernel
mainline v7.1 = commit `b3f94b2b3f3e51ab880a51fc6510e1dafba654ed`).

**Fecha:** 2026-08-10

## Resumen

El fragmento `configs/kernel/laurel-base.fragment` pide varios símbolos como
`=y` (built-in). `merge_config.sh -m` los aplica correctamente (el log muestra
`Previous value: CONFIG_DRM_MSM=m` → `New value: CONFIG_DRM_MSM=y`), pero el
`make olddefconfig` posterior **degrada silenciosamente** parte de ellos a `=m`.

El `.config` final del run (artefacto `kernel-final2`, run 30792773593, head
`b36a195`, fragmento del mismo run) queda con:

| Símbolo | Pedido | Merge log | `.config` final | Causa |
|---|---|---|---|---|
| `CONFIG_DRM_MSM` | `=y` | `m→y` | **`=m`** | `depends on QCOM_OCMEM || QCOM_OCMEM=n` y `depends on QCOM_LLCC || QCOM_LLCC=n` |
| `CONFIG_BT` | `=y` | `m→y` | **`=m`** | `depends on RFKILL \|\| !RFKILL` |
| `CONFIG_ATH10K` | `=y` | `m→y` | **`=m`** | `depends on MAC80211 && HAS_DMA` |
| `CONFIG_ATH10K_SNOC` | `=y` | `m→y` | **`=m`** | `depends on ATH10K` (cascada) |
| `CONFIG_WCN36XX` | `=y` | `m→y` | **`=m`** | `depends on MAC80211` |
| `CONFIG_QCOM_Q6V5_ADSP` | `=y` | `m→y` | **`=m`** | `depends on QCOM_SYSMON || QCOM_SYSMON=n` |
| `CONFIG_QCOM_Q6V5_MSS` | `=y` | `m→y` | **`=m`** | idem |
| `CONFIG_QCOM_RPROC_COMMON` | — | (select) | **`=m`** | arrastrado por Q6V5 |

Símbolos que **sí** sobreviven a `=y`: `QRTR_SMD`, `QRTR_TUN`, `BT_HCIUART`,
`TOUCHSCREEN_EDT_FT5X06`, `I2C_QCOM_GENI`, `QCOM_SPMI_TEMP_ALARM`, `DRM`,
`USB_CONFIGFS`, `SCSI_UFS_QCOM`, `RPMSG_QCOM_GLINK_SMEM`, `FTRACE` (sus
dependencias tristate quedan en `=y` o `=n`, no en `=m`).

## Mecanismo Kconfig

Kconfig evalúa `depends on` en lógica tristate (`n < m < y`). El patrón
`depends on X || X=n` significa: "X debe estar habilitado, o bien puede estar
apagado". Pero cuando `X=m`, la expresión `X || X=n` evalúa a `m` (porque
`m || n = m`), y **limita** al símbolo dependiente a como máximo `=m`.

Con la defconfig base de mainline v7.1 (`arch/arm64/configs/defconfig`), los
siguientes símbolos quedan en `=m` antes del merge:

- `CONFIG_QCOM_OCMEM=m`, `CONFIG_QCOM_LLCC=m`
- `CONFIG_RFKILL=m`
- `CONFIG_MAC80211=m`, `CONFIG_CFG80211=m`
- `CONFIG_QCOM_SYSMON=m`

El fragmento pide `CONFIG_DRM_MSM=y`, `CONFIG_BT=y`, `CONFIG_ATH10K=y`,
`CONFIG_QCOM_Q6V5_ADSP=y` sin forzar esas dependencias a `=y` (o `=n`). Al
reevaluar con `make olddefconfig`, Kconfig capa el símbolo al nivel `m`.

Evidencia directa en Kconfig v7.1:

- `drivers/gpu/drm/msm/Kconfig`:
  `depends on QCOM_OCMEM || QCOM_OCMEM=n`
  `depends on QCOM_LLCC || QCOM_LLCC=n`
- `net/bluetooth/Kconfig`: `menuconfig BT` → `depends on RFKILL || !RFKILL`
- `drivers/net/wireless/ath/ath10k/Kconfig`: `depends on MAC80211 && HAS_DMA`
- `drivers/remoteproc/Kconfig` (QCOM_Q6V5_ADSP/MSS):
  `depends on QCOM_SYSMON || QCOM_SYSMON=n`

`QCOM_LLCC`/`QCOM_OCMEM` (drivers/soc/qcom/Kconfig v7.1) son `tristate` sin
`default`; quedan en `=m` solo porque la defconfig base los activa como módulo.

## Por qué `verify-kconfig.sh` anterior no lo detectó

La versión anterior solo comprobaba **presencia**:

```
grep -qE "^${sym}=" "$CONFIG"   # CONFIG_DRM_MSM=m → OK
```

Nunca comparaba el **valor**. `CONFIG_DRM_MSM=m` (degradado) pasaba la
verificación como "OK".

## Corrección (repo)

1. `scripts/verify-kconfig.sh` ahora compara valor exacto:
   - `CONFIG_X=y` → exige `=y` (falla si `=m`/`=n`/ausente).
   - `CONFIG_X=m` → exige `=m`.
   - `# CONFIG_X is not set` → exige no-set.
   - Añade `--deny-list` (límite máximo `=m` o no-set).
2. `scripts/build-kernel.sh` añade checkpoint tras `make olddefconfig` que
   ejecuta `verify-kconfig.sh --fail-missing` y aborta la build antes de
   compilar si hay degradación.
3. `.github/workflows/03-build-kernel.yml` quita el `|| echo AVISO` (la
   verificación pasa a ser fatal) y pasa la deny-list.
4. `configs/kernel/laurel-base.fragment` fuerza a `=y` (o `=n`) las
   dependencias tristate que capan a `=m`, para que los símbolos obligatorios
   se mantengan built-in.

## Fix del fragmento (dependencias a forzar)

Para que cada símbolo obligatorio sobreviva a `olddefconfig`, sus dependencias
tristate que quedaban en `=m` deben fijarse a `=y` (o `=n`):

- `CONFIG_DRM_MSM=y` → `CONFIG_QCOM_OCMEM=y`, `CONFIG_QCOM_LLCC=y`
- `CONFIG_BT=y` → `CONFIG_RFKILL=y`
- `CONFIG_ATH10K=y`, `CONFIG_WCN36XX=y` → `CONFIG_MAC80211=y`,
  `CONFIG_CFG80211=y`
- `CONFIG_QCOM_Q6V5_ADSP=y`, `CONFIG_QCOM_Q6V5_MSS=y` → `CONFIG_QCOM_SYSMON=y`

## Evidencia de la mezcla de runs en artefactos locales

- `local-private/kernel-final2/` = run **30792773593** (head `b36a195`,
  creado 2026-08-03T07:12:12Z, terminado 08:01:00Z). Manifest
  `generated_at=2026-08-03T08:00:53Z`. Internamente consistente.
- `local-private/kernel-final/` = run **30789357941** (head `80aca435`,
  terminado 07:03:55Z). Su manifest (`07:03:48Z`) pertenece a ese run, pero
  su `kernel.config` contiene símbolos (`BT_HCIUART_SERDEV=y`,
  `BT_HCIUART_H4=y`) que solo existen en el fragmento desde `b36a195`
  (07:12Z). → **mezcla runs**: config/merge-log copiados de un run posterior,
  Image/manifest del run `80aca435`.
- Ambos `kernel.config` y `kconfig-merge.log` son byte-idénticos; la
  degradación `DRM_MSM=y→=m` es real dentro del run `b36a195`
  (kernel-final2), no un artefacto de la mezcla.
- El run `30793586800` citado en la misión anterior **no existe** en GitHub.

## Lección

La degradación `=y → =m` es silenciosa: la build "compila" y el merge log
parece correcto. Única forma robusta de detectarla: comparar el valor exacto
pedido por el fragmento contra el `.config` final tras `olddefconfig`, y
fallar la build. Eso implementa la corrección anterior.
