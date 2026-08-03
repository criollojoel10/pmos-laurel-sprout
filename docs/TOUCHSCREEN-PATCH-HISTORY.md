# Historial del parche del táctil FocalTech FT3518

Estado: completo (2026-08-03). Inventario JSON: `reports/touchscreen-patch-inventory.json`.

## Resumen

Táctil capacitivo del Xiaomi Mi A3 (laurel_sprout), compatible
`focaltech,ft3518`, integrado en el driver EDT-FT5x06. Soporte aceptado
upstream y presente en Linux mainline v7.0.

- Driver: `drivers/input/touchscreen/edt-ft5x06.c`
- DTS: `arch/arm64/boot/dts/qcom/sm6125-xiaomi-laurel-sprout.dts`
- Autor: Yedaya Katsman (coaut. Kamil Gołda)
- Hardware: I2C `i2c2` (qupv3_id_0) @ 0x38, reset gpio 83 (sin pinctrl
  downstream), hasta 10 puntos de contacto.

## Revisiones del patchset

| Versión | Fecha | Message-ID | Estado |
|---|---|---|---|
| v1 | 2026-01-13 | 20260113-touchscreen-patches-v1-0-a10957f32dd8@gmail.com | superseded |
| v2 | 2026-01-14 | 20260114-touchscreen-patches-v2-0-4215f94c8aba@gmail.com | superseded |
| v3 | 2026-01-18 | 20260118-touchscreen-patches-v3-0-1c6a729c5eb4@gmail.com | **accepted** (driver) |
| v4 | 2026-01-20 | 20260120-touchscreen-patches-v4-0-30145da9d6d3@gmail.com | superseded |
| v5 | 2026-02-08 | 20260208-touchscreen-patches-v5-1-5821dff9c9a2@gmail.com | **accepted** (DTS) |

## Commits aplicados

- dt-bindings: `9b352327add1` (mainline v7.0)
- driver: `5383e76483dc` (mainline v7.0, aplicado por Dmitry Torokhov,
  "Applied, thank you.")
- DTS: `8cbbb339048a` (mainline v7.0, aplicado por Bjorn Andersson)

## Notas

- v3 tenía un warning de dtbs_check por nodos pinctrl `pmx_ts_*` no
  documentados en `qcom,sm6125-tlmm.yaml`; se resolvió en revisiones
  posteriores del DTS.
- La rama `laurel` de SzczurekYT (2026-03-10) contiene el soporte.

## Estado en árboles relevantes

| Árbol | Estado |
|---|---|
| Linux mainline v7.0+ | presente (accepted) |
| sm61x5-mainline master (7a52441d) | NO presente |
| sm61x5-mainline barni2000/6.19-develop | presente (backport) |
| SzczurekYT/linux rama laurel | presente |
