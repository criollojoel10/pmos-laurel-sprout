# Auditoría del Device Tree (DTS)

Estado: registro inicial (2026-08-02). Se completa con datos reales del
workflow 01 y del árbol sm61x5-mainline fijado.

## Hechos verificados

- El DTS mainline correcto es `arch/arm64/boot/dts/qcom/sm6125-xiaomi-laurel-sprout.dts`
  → DTB `qcom/sm6125-xiaomi-laurel-sprout.dtb` (con guiones, no guion bajo).
- Compatible del panel (tras fix v2 de 2026-06-08):
  `samsung,s6e8fc0-m1906f9` (con CERO).
- El DTS incluye: `mdss`, `mdss_dsi0`, `panel@0`, `mdss_dsi0_out`,
  `mdss_dsi0_phy`, pinctrl `mdss_default/mdss_sleep` (gpio90), reguladores
  `panel_vddi_1p8` (gpio26) y `panel_vci_3p0` (gpio124).

## Por verificar en el árbol fijado

| Elemento | Archivo esperado | Estado |
|---|---|---|
| DTS laural principal | `sm6125-xiaomi-laurel-sprout.dts` | verificar |
| DTS panel | `.../s6e8fc0*` | verificar |
| DTS táctil | `.../focaltech*` | verificar |
| driver panel | `drivers/gpu/drm/panel/*s6e8fc0*` | verificar |
| driver táctil | `drivers/input/touchscreen/*focaltech*` | verificar |
| defconfig | `arch/arm64/configs/sm61x5_defconfig` | NO existe (confirmado) |

## Reglas

- No reintroducir el typo `s6e8fco`.
- Todo overlay/parche DTS se audita con `scripts/audit-patches.sh`.
- El DTB se embeberá en `boot.img` (QCDT) para boot no destructivo.
