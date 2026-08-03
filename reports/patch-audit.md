# Auditoría de parches

Generado: 2026-08-03 (actualizado tras investigación M1).

Áreas: display (s6e8fc0-m1906f9), touchscreen (FT3518), GPU, wifi,
bluetooth, power.

## Panel S6E8FC0/M1906F9 — ACCEPTED upstream

- Compatible: `samsung,s6e8fc0-m1906f9` (CERO, no O).
- Typo `s6e8fco`->`s6e8fc0` corregido en v5 del patchset (2026-03-17,
  Yedaya Katsman). Ver docs/PANEL-PATCH-HISTORY.md.
- Driver upstream: `49837b6babe7` (drm-misc-next → mainline v7.1).
- DTS upstream (Enable MDSS + panel): `493cb869874c` (mainline v7.1).
- sm61x5 master: NO presente; barni2000/6.19-develop: presente (backport).
- Clasificación: accepted-not-present (en la base sm61x5 master actual).

## Táctil FT3518 — ACCEPTED upstream

- Driver edt-ft5x06 upstream: `5383e76483dc` (mainline v7.0).
- DTS upstream: `8cbbb339048a` (mainline v7.0).
- sm61x5 master: NO presente; barni2000/6.19-develop: presente (backport).
- Clasificación: accepted-not-present (en la base sm61x5 master actual).

## GPU Adreno 610

- DTS enable GPU: `92aacc57f7` (sm61x5 dev). Firmware: `a630_sqe.fw` vía
  `firmware-qcom-adreno-a610` (subpackage) + `-a630-sqe`.

## Firmware A610

- Subpackage de `firmware-qcom-adreno` en pmaports main (metapaquete vacío
  + dependencia `-a630-sqe` con `a630_sqe.fw`). H5 confirmed.

Estado de cada parche (upstream/accepted/queued/pending/downstream-only/
local-workaround) se registra en reports/panel-patch-inventory.json y
reports/touchscreen-patch-inventory.json.
