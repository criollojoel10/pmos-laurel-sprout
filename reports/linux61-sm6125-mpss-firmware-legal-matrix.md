# Matriz firmware MPSS/WCN3990 — audit legal y de disponibilidad

Fecha: 2026-08-13. Complementa `reports/linux61-wcn3990-firmware-matrix.md`.
No se extrajo ningún blob; solo inventario con hashes y listados de solo
lectura del stock ya descargado.

## Firmware MPSS (modem) — REQUERIDO para la v2

| ítem | valor |
|------|-------|
| Fuente | `local-private/rom-references/laurel_sprout_global_images_V12.0.26.0.RFQMIXM_11.0/images/NON-HLOS.bin` |
| Tamaño | 117,198,848 B |
| SHA-256 | `ed5279f2595f98ecc86ebc8c1d5e5017033bfc0d3384f144ae8de773cabe24bf` |
| Partición destino | `modem_a`/`modem_b` (184,320 KB, readonly, según partition.xml líneas 66/89) |
| Contenido | imagen ELF/MBN de la MPSS (modem); en Linux 6.1 el driver PAS del fork espera `modem.mdt` + segmentos `.b0X` bajo `/lib/firmware/qcom/sm6125/` (ver kernel-driver-flow.md) |
| Licencia | Firmware propietario Qualcomm/Xiaomi; **no redistribuible**; se puede extraer SOLO para uso privado del dispositivo (autorización explícita de prueba física) |
| Estado | `source-available` (imagen en local-private), extracción pendiente |

## Firmware WCN3990 (Wi-Fi) — inventario del stock

Inspección de solo lectura de `vendor.raw` (debugfs, sin montar/extractar):

| ruta (vendor) | contenido | relevancia |
|---------------|-----------|------------|
| `/firmware/wlan/qca_cld/WCNSS_qcom_cfg.ini` | config WLAN vendor | referencia, no firmware |
| `/firmware/wlan/qca_cld/wlan_mac.bin` | calibración MAC específica de unidad | NO publicar; requerida solo para RF real |
| `/etc/wifi/*` | wpa_supplicant/config | — |
| `wlanmdsp.mbn` | **NO presente** en `/firmware` | no es requerido por la v2 (el firmware WCN3990 se entrega vía QMI WLFW, no wlanmdsp) |

## Firmware ath10k (linux-firmware, redistribuible) — de la v1

| archivo | tamaño | SHA-256 | estado |
|---------|--------|---------|--------|
| `firmware-5.bin` (hw1.0) | 60 B (STUB, no real) | `fef6539e...c4127` | NO usar; falta firmware WCN3990 real |
| `board-2.bin` (hw1.0) | 893,528 B | `c49d2f18...02c1d` | presente, entrada laurel sin verificar |

## Requisitos mínimos de firmware para arrancar MPSS (v2)

1. `modem.mdt` + `modem.b0X` extraídos de NON-HLOS.bin (o del rootfs
   Android del dispositivo) → `/lib/firmware/qcom/sm6125/`.
   Sin esto, `qcom_mdt_load` falla en el start de la MPSS (bloqueante).
2. WCN3990 real `firmware-5.bin` + `board-2.bin` en
   `/lib/firmware/ath10k/WCN3990/hw1.0/` (el stub de 60 B de la v1 no
   sirve; fuente: linux-firmware fijado o extracción del dispositivo).
3. `wlan_mac.bin` (calibración, específica de unidad, privada) solo para
   funcionamiento RF real — NO para el probe.

## Decisión de licencia (aplicando AGENTS.md §1 y §10)

- `NON-HLOS.bin`, `wlan_mac.bin`: firmware propietario, **no publicable**.
  Extracción solo con autorización explícita y para uso privado.
- `firmware-5.bin`/`board-2.bin` reales: redistribuibles vía linux-firmware
  si se fija el commit y se documenta la licencia (BSD/Qualcomm).
- No se incluye ningún blob en el repositorio; todo queda en `local-private/`.

## Riesgo principal M4

El firmware MPSS (`modem.mdt`) es **condición bloqueante**: sin él no se
puede subir el remoteproc. Está disponible en `local-private` (NON-HLOS.bin,
hash registrado) pero la extracción requiere autorización y NO se hace en
esta misión. Hasta que se extraiga y verifique, el estado del MPSS es
`boot-untested`/`blocked` y el veredicto v2 queda condicionado.

## Fuentes

- `local-private/rom-references/.../images/NON-HLOS.bin` + `partition.xml`
- `local-private/rom-analysis/stock/img/vendor.raw` (debugfs, solo listado)
- `reports/linux61-wcn3990-firmware-matrix.md`
- `local-private/diagnostics/wifi-priority/firmware-linux-firmware-e3c0c4b7/`
