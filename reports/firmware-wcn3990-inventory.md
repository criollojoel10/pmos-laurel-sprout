# Inventario firmware WCN3990 (Wi-Fi SNOC) — laurel_sprout

Fecha: 2026-08-11. Fuente: código mainline v7.1 (`ath10k`), linux-firmware
(API GitLab) y dispositivo 6.1 (solo lectura). No se incluyen blobs.

## Rutas que solicitará ath10k_snoc (v7.1)

Driver `drivers/net/wireless/ath/ath10k`:
- Directorio: `ath10k/WCN3990/hw1.0/` (`ATH10K_FW_DIR "/WCN3990/hw1.0"`).
- Firmware: `firmware-<fw_api>.bin` → `firmware-5.bin` (SNOC/PCI/AHB usan
  `firmware-N.bin`).
- Board: `board.bin` o `board-2.bin` (API 1/2) en el mismo directorio.
- Cal (opcional, privada): `cal-snoc-<device>.bin` y `pre-cal-snoc-<device>.bin`.

## Clasificación

| Archivo | Origen | Clase | Estado |
|---|---|---|---|
| `ath10k/WCN3990/hw1.0/firmware-5.bin` | linux-firmware | A. redistribuible | confirmado presente |
| `ath10k/WCN3990/hw1.0/board-2.bin` | linux-firmware | A. redistribuible | confirmado presente; entrada para el board-id de laurel pendiente de dmesg |
| `ath10k/WCN3990/hw1.0/board.bin` (si no hay entrada en board-2.bin) | linux-firmware | A. redistribuible | pendiente de confirmación runtime |
| `cal-snoc-<device>.bin` / `pre-cal-snoc-<device>.bin` | vendor Android (NV) | C. privada por unidad | no accesible desde pmOS (sin /vendor); nunca publicar |
| `ath10k/WCN3990/hw1.0/wlanmdsp.mbn` | linux-firmware | A. redistribuible | audio DSP; NO requerido para Wi-Fi |

## Referencia linux-firmware (fijar para reproducibilidad)

- Proyecto: `kernel-firmware/linux-firmware` (GitLab).
- HEAD consultado: `e3c0c4b70f50ae77bea557b4a44be04413d3f3ed` (2026-08-11).
  `main` es mutable; para el resultado reproducible se debe congelar un tag o
  el commit anterior confirmado y registrar SHA-256 de `firmware-5.bin` y
  `board-2.bin` en `sources.lock.json` (pendiente de ejecutar en CI).

## Cómo se carga (flujo real)

- `firmware-5.bin` lo descarga ath10k y, con `use_tz=true` (sin subnodo
  `wifi-firmware`), el firmware Q6 se carga por TrustZone vía QMI; el archivo
  se usa para validación/boardid.
- `board-2.bin` es un contenedor con entradas por board-id (QMI board_info).
- Si el board-id de laurel no está en `board-2.bin`, ath10k imprime
  `failed to fetch board-2.bin or board.bin` → sin interfaz. Es el riesgo
  principal pendiente de evidencia runtime (`dmesg`).

## Evidencia 6.1 (solo lectura)

- `/lib/firmware`: sin archivos WCN/ath10k.
- `/vendor`, `/vendor/firmware`, `/vendor/etc/wifi`, `/mnt/vendor/persist`:
  no montados en el rootfs pmOS → calibración por unidad no accesible en este
  boot. Extracción legal solo desde stock/vendor con autorización y nunca al repo.
