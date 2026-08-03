# Auditoría de firmware

Estado: actualizado (2026-08-03). Corrección H5 completada con evidencia de
pmaports main, índice oficial pkgs.postmarketos.org y linux-firmware.

## Componentes requeridos para laurel_sprout

| Componente | Blobs / paquete | Origen | Licencia | Estado |
|---|---|---|---|---|
| GPU Adreno 610 | `firmware-qcom-adreno-a610` (subpackage) | pmaports main (`device/community/firmware-qcom-adreno`); linux-firmware | custom | **confirmado** (metapaquete vacío + `a630_sqe.fw`) |
| WLAN/BT | WCN3990 (`qcom/wcn3990*`, `qca6390`) | linux-firmware | por verificar | pendiente |
| Modem | `mba.mbn`, `qdsp6.mbn` | firmware stock Xiaomi | propietario | pendiente (no redistribuir) |
| ADSP/CDSP | `adsp.mbn`, `cdsp.mbn` | firmware stock Xiaomi | propietario | pendiente |
| Venus | `venus-*.mbn` (solo HW codec) | firmware stock | propietario | pendiente |

## GPU Adreno 610 (H5, confirmado)

- `firmware-qcom-adreno-a610` NO es un directorio: es un subpackage generado
  del APKBUILD padre `firmware-qcom-adreno`
  (`device/community/firmware-qcom-adreno/APKBUILD`).
- El subpackage `a610` es un metapaquete vacío: instala solo
  `/usr/lib/firmware/qcom/` y depende de `firmware-qcom-adreno-a630-sqe`
  (que instala `qcom/a630_sqe.fw`). El A610 no tiene GMU.
- pkgver=20260110, pkgrel=1, arch="aarch64 armv7", license="custom".
- Índice oficial: 20260110-r1, origin `firmware-qcom-adreno`, inst. size 1.0B.
- linux-firmware tag 20260110 (commit
  06a743fd69999590e88199bb9edba9d5b73d6ad1): `qcom/a630_sqe.fw` presente
  (sha256 1c21b527...a9aa90c); no hay bins `a610_*`.
- El kernel solicitará `a630_sqe.fw`. No hay firmware GMU específico A610 ni
  firmware de calibración en este paquete (zap shader device-specific se
  excluye; el driver MSM lo maneja con `-ENODEV` y usa
  `SECVID_TRUST_CNTL`).

## Reglas

- No se redistribuye firmware sin verificación de licencia (AGENTS.md §1, §10).
- El manifiesto `configs/firmware/firmware-manifest.json` clasifica cada blob.
- El firmware propietario del Mi A3 se extrae del stock/Lineage por el
  usuario (con guía en `docs/RECOVERY.md`), NO se sube al repo.

## Verificación

- Detección de subpackages: `research-upstream.sh` ahora analiza el APKBUILD
  padre (busca `$pkgname-a610` en `subpackages=`) en lugar de solo directorios.
- Regresión añadida: la ausencia de un directorio `firmware-qcom-adreno-a610`
  ya no se interpreta como "no existe".
- Correspondencia entre `linux-firmware` y el manifiesto: `verify-kconfig.sh`
  y auditoría.
