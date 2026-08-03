# Auditoría del Device Tree (DTS)

Estado: actualizado con CI (2026-08-03, run 30775362988, commit f9e3513).

## Hechos verificados

- El DTS mainline correcto es `arch/arm64/boot/dts/qcom/sm6125-xiaomi-laurel-sprout.dts`
  → DTB `qcom/sm6125-xiaomi-laurel-sprout.dtb` (con guiones, no guion bajo).
- Compatible del panel (tras fix v2 de 2026-06-08):
  `samsung,s6e8fc0-m1906f9` (con CERO).
- El DTS incluye: `mdss`, `mdss_dsi0`, `panel@0`, `mdss_dsi0_out`,
  `mdss_dsi0_phy`, pinctrl `mdss_default/mdss_sleep` (gpio90), reguladores
  `panel_vddi_1p8` (gpio26) y `panel_vci_3p0` (gpio124).

## Verificado en el árbol fijado (sm61x5-mainline master 7a52441d)

| Elemento | Archivo esperado | Estado |
|---|---|---|
| DTS principal | `sm6125-xiaomi-laurel-sprout.dts` | **presente** |
| DTS panel | `.../s6e8fc0*` | NO localizado en master |
| DTS táctil | `.../focaltech*` | NO localizado en master |
| driver panel | `drivers/gpu/drm/panel/*s6e8fc0*` | NO localizado en master |
| driver táctil | `drivers/input/touchscreen/*focaltech*` | NO localizado en master |
| defconfig | `arch/arm64/configs/sm61x5_defconfig` | NO existe (confirmado) |

El DTS principal de laurel ya está en master, pero panel y táctil NO: deben
portarse desde ramas `barni2000/*` (p. ej. `barni2000/6.19-develop`) o desde
parches pendientes, y registrarse en `docs/PATCH-PLAN.md`.

## Reglas

- No reintroducir el typo `s6e8fco`.
- Todo overlay/parche DTS se audita con `scripts/audit-patches.sh`.
- El DTB se embeberá en `boot.img` (QCDT) para boot no destructivo.
