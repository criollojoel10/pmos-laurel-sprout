# Auditoría de firmware

Estado: registro inicial (2026-08-02). Detalles por componente se completan
en el workflow 01 (`reports/firmware-audit.md`).

## Componentes requeridos para laurel_sprout

| Componente | Blobs / paquete | Origen | Licencia | Estado |
|---|---|---|---|---|
| GPU Adreno 610 | `firmware-qcom-adreno-a610` (pmaports) | linux-firmware / pmaports | por verificar | pendiente |
| WLAN/BT | WCN3990 (`qcom/wcn3990*`, `qca6390`) | linux-firmware | por verificar | pendiente |
| Modem | `mba.mbn`, `qdsp6.mbn` | firmware stock Xiaomi | propietario | pendiente (no redistribuir) |
| ADSP/CDSP | `adsp.mbn`, `cdsp.mbn` | firmware stock Xiaomi | propietario | pendiente |
| Venus | `venus-*.mbn` (solo HW codec) | firmware stock | propietario | pendiente |

## Reglas

- No se redistribuye firmware sin verificación de licencia (AGENTS.md §1, §10).
- El manifiesto `configs/firmware/firmware-manifest.json` clasifica cada blob.
- El firmware propietario del Mi A3 se extrae del stock/Lineage por el
  usuario (con guía en `docs/RECOVERY.md`), NO se sube al repo.

## Verificación

- `firmware-qcom-adreno-a610` presente en pmaports main: se verifica en CI.
- Correspondencia entre `linux-firmware` y el manifiesto: `verify-kconfig.sh`
  y auditoría.
