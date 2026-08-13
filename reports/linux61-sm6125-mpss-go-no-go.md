# Veredicto MPSS v2 — GO / NO-GO (Linux 6.1)

Fecha: 2026-08-13. Misión de auditoría de requisitos MPSS previa a la v2 de
WCN3990. Este veredicto NO autoriza ninguna operación física; es el
resultado del análisis (M1-M7).

## Veredicto

**CONDICIONAL / NO-GO ACTUAL.**

El diseño v2 es viable (arquitectura MPSS-PAS demostrable en mainline y
coincidente con el vendor trinket), pero **dos requisitos bloqueantes
están ausentes** y **ninguna prueba física está autorizada**. El estado se
registra como `blocked` (no `working`, no `detected`).

## Resumen por fase

| fase | resultado | estado |
|------|-----------|--------|
| M1 referencia mainline | QCM2290 v6.6 + `qcom,sm6115-mpss-pas` → arquitectura MPSS-PAS válida para SM6125 | `source-available` |
| M2 drivers fork | fork 6.1 tiene PAS/glink/smp2p/sysmon/qrtr/ath10k; FALTA compatible sm6115/sm6125-pas | `configured` |
| M3 diff DT | todo el andamiaje modelable replicando QCM2290 con valores SM6125; memory-regions ya presentes | `configured` |
| M4 firmware | `modem.mdt` AUSENTE (NON-HLOS.bin disponible, extracción no autorizada); WCN3990 real ausente | `blocked` |
| M5 userspace | qrtr/pd-mapper/rmtfs/tqftpserv disponibles en Alpine pero NO instalados en rootfs | `blocked` |
| M6 riesgos/rollback | respaldos completos OK; riesgos 1 y 6 bloqueantes | `configured` |
| M7 diseño v2 | diseño UNA variable definido (pseudodiff DTS no aplicado, gates 0-11) | `configured` |

## Bloqueantes (NO-GO actual)

1. **Firmware MPSS (`modem.mdt`) ausente** en el rootfs. Sin él,
   `qcom_mdt_load` falla y la MPSS no sube → sin QRTR → sin QMI WLFW →
   sin WCN3990. Disponible en `local-private` (NON-HLOS.bin, hash
   `ed5279f2...`) pero la extracción NO está autorizada en esta misión.
2. **Firmware WCN3990 real ausente** (solo stub de 60 B). Sin
   `firmware-5.bin`/`board-2.bin` reales no hay radio.
3. **Cadena userspace ausente** (qrtr-ns, pd-mapper, rmtfs) en el rootfs
   instalado.
4. **Sin autorización de prueba física** (FASE 8 obligatoria; no se dio).

## Vía a GO (futuro, en orden)

1. Autorización explícita para extraer `modem.mdt` de NON-HLOS.bin (uso
   privado, no publicable).
2. Instalar paquetes Alpine: `qrtr`, `pd-mapper`, `rmtfs` (+ `tqftpserv`
   si aplica) y firmware WCN3990 real (linux-firmware fijado).
3. Aplicar el pseudodiff v2 (compatible `qcom,sm8150-mpss-pas`, power-domain
   único SM6125_VDDCX, glink-edge, smp2p-mpss), compilar en CI (autorizado
   aparte) y generar boot v2 con hash+size ≤ 0x4000000.
4. Prueba física FASE 8: mostrar artefactos, slot, particiones a modificar,
   procedimiento de rollback (respaldos OK), recomendación de prueba menos
   destructiva (`fastboot boot` temporal), DETENERSE y esperar autorización.
5. Ejecutar gates G0-G11 con instrumentación MPSS/GLINK/QRTR/WCN3990-DIAG.

## Revisión de honestidad (AGENTS.md §2)

- NO se declara que la v2 funciona porque el diseño "tiene sentido": el
  estado es `blocked`/`configured`/`boot-untested`, nunca `working`.
- NO se confunde: diseño DTS con arranque real; compatible mapeado con
  soporte oficial; la cadena MPSS→QMI WLFW end-to-end NO está validada en
  mainline para SM6125.
- La referencia QCM2290 tiene remoteproc_mpss y wifi con `status =
  "disabled"` en v6.6 → no hay evidencia de arranque end-to-end público.

## Salida final (declaración de alcance de esta misión)

Esta misión fue de análisis y reporte únicamente:

- No ejecuté Fastboot, no reinicié el teléfono, no inicié remoteproc, no
  instalé firmware, no modifiqué el rootfs, no construí una imagen y no
  abrí CI.
- El dispositivo NO fue escrito ni tocado; permanece en el estado de
  respaldo conocido (slot `a`).
- Los reportes públicos y las evidencias privadas quedan en el repositorio;
  los blobs/firmware y metadatos sensibles permanecen en `local-private/`.

## Fuentes

- Reportes de esta misión: `reports/linux61-sm6125-mpss-reference-audit.md`,
  `...-dts-semantic-diff.md`, `...-firmware-legal-matrix.md`,
  `...-userspace-sequence.md`, `...-risk-register.md`,
  `reports/linux61-wcn3990-v2-mpss-transport-design.md`
- Evidencias privadas: `local-private/diagnostics/wifi-priority/mpss-risk-audit/`
- Respaldos: `local-private/backups/2026-08-09/`
