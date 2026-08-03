# Historial del parche del panel Samsung S6E8FC0 / M1906F9

Estado: completo (2026-08-03). Inventario JSON: `reports/panel-patch-inventory.json`.

## Resumen

Panel AMOLED 720x1560 del Xiaomi Mi A3 (laurel_sprout). Compatible
`samsung,s6e8fc0-m1906f9`. Soporte aceptado upstream y presente en Linux
mainline v7.1.

- Driver: `drivers/gpu/drm/panel/panel-samsung-s6e8fc0-m1906f9.c`
- DTS: `arch/arm64/boot/dts/qcom/sm6125-xiaomi-laurel-sprout.dts`
- Autor: Yedaya Katsman (coaut. Kamil Gołda), generado con
  `linux-mdss-dsi-panel-driver-generator`.

## Revisiones del patchset

| Versión | Fecha | Message-ID | Estado |
|---|---|---|---|
| v1 | 2026-02-23 | 20260223-panel-patches-v1-0-7756209477f9@gmail.com | superseded |
| v2 | 2026-02-23 | 20260223-panel-patches-v2-0-1b6ad471d540@gmail.com | superseded |
| v3 | 2026-03-12 | 20260312-panel-patches-v3-0-6ed8c006d0be@gmail.com | superseded (S6E8FCO) |
| v4 | 2026-03-14 | 20260314-panel-patches-v4-0-1ecbb2c0c3c8@gmail.com | superseded |
| v5 | 2026-03-17 | 20260317-panel-patches-v5-0-ef99f7b280da@gmail.com | **fix typo s6e8fc0** |
| v6 | 2026-03-18 | 20260318-panel-patches-v6-0-7a30c2f85e0b@gmail.com | superseded |
| v7 | 2026-03-20 | 20260320-panel-patches-v7-0-3eaefc4b3878@gmail.com | **accepted** |

## Fix del typo

`S6E8FCO` (O) → `S6E8FC0` (cero). Se corrigió en **v5 (2026-03-17)**, antes
de la aplicación. El typo venía de downstream, pero el sitio de Samsung
termina en 0. Un resumen previo mencionaba erróneamente "fix v2 2026-06-08";
la evidencia de lore/patchew confirma v5.

## Commits aplicados

- dt-bindings: `f4693b88bc730` (drm-misc-next)
- driver: `49837b6babe7` (drm-misc-next → mainline v7.1)
- DTS Enable MDSS + panel: `493cb869874c` (mainline v7.1)

## Dependencias (también upstream)

- `arm64: dts: qcom: sm6125: Add missing MDSS core reset`
- `arm64: dts: qcom: sm6115: Add missing MDSS core reset`
- `clk: qcom: dispcc-sm6125: Add missing MDSS resets`
- `clk: qcom: dispcc-sm6115: Add missing MDSS resets`
- bindings dispcc correspondientes

## Estado en árboles relevantes

| Árbol | Estado |
|---|---|
| Linux mainline v7.1+ | presente (accepted) |
| sm61x5-mainline master (7a52441d) | NO presente |
| sm61x5-mainline barni2000/6.19-develop | presente (backport) |
| SzczurekYT/linux rama laurel | presente (2026-03-10, aún S6E8FCO) |
