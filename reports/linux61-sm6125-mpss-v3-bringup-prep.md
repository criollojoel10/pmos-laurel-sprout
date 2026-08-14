# Misión v3 — MPSS bring-up: preparación (firmware + userspace + DTS enable)

Fecha: 2026-08-14
Documento interno; sigue el estado honesto de AGENTS.md §2. Esta misión es
**SOLO de preparación**: no ejecuta ninguna prueba física, no construye
nada local, no flashea. La construcción del artefacto v3 se hará en
GitHub Actions con autorización aparte.

## Contexto

La v2 (WCN3990 first-probe + MPSS transport, MPSS `disabled`) quedó
CI-PASS / ARTIFACT-VALIDATED / BOOT-UNTESTED en main `52198ed` (PR #7).
La v3 habilita el MPSS para el bring-up real, deteniéndose en los gates de
MPSS (remoteproc running, GLINK/IPCRTR, QRTR services, WLFW, FW_READY).
`wlan0`/scan/asociación es una fase posterior. El Mi A3 **no soporta
`fastboot boot`**: la única prueba viable requiere escribir `boot_b`, que
permanece bloqueada hasta autorización explícita (FASE 8).

## Entregables de esta misión

| componente | estado | ubicación |
|---|---|---|
| Firmware MPSS extraído (`modem.mdt` + 28 segmentos) | `extracted` | `local-private/diagnostics/wifi-priority/wcn3990-v2-build-ready/modem-firmware/` |
| Verificación de integridad MPSS | 29/29 OK | `modem-firmware/sha256-after.txt` + re-extracción de control |
| Kit firmware WCN3990 (`firmware-5.bin`, `board-2.bin`, `wlanmdsp.mbn`) | `source-available`, hashes OK | `.../firmware/` |
| Kit userspace (qrtr, pd-mapper, rmtfs, tqftpserv, msm-modem) | `source-available` | `.../userspace/` |
| Parche DTS separado 0003 (enable `&remoteproc_mpss` → `okay`) | `configured` | `patches/kernel-61/0003-dts-laurel-enable-mpss.patch` |
| Validador/verify con modo MPSS enabled (v3) sin romper v2 | `static-validation-passed` | `scripts/validate-mpss-v2-final.py`, `scripts/verify-wcn3990-mpss-v2.sh` |
| Rollback 6.1 y respaldos | `verified` (13/13 hashes OK) | `local-private/backups/2026-08-09/` + `docs/BACKUP-GUIDE.md` |

## 1. Firmware MPSS (bloqueante 1 resuelto)

- Origen: `local-private/rom-references/.../NON-HLOS.bin` (117,198,848 B,
  SHA-256 `ed5279f2...`, MIUI 12.0.26.0 global).
- Extraído con `tools/private/prepare-sm6125-modem-firmware.sh` (autorizado
  por esta misión): `modem.mdt` (9,100 B, ELF QUALCOMM DSP6) + 28 segmentos
  `modem.b00..b12, b14..b18, b20..b29` (sin b13/b19).
- Integridad: hashes de salida registrados (`sha256-after.txt`); control de
  re-extracción comparado → 29/29 OK; hash de entrada coincide.
- Bug corregido en el script: el awk generaba `bXX` en vez de `modem.bXX`
  (los nombres FAT incluyen el prefijo `modem.`). Sin impacto en integridad.
- Destino de instalación futura (NO realizada): `/lib/firmware/qcom/sm6125/`
  (ruta que `qcom_mdt_load` espera con `fw_name` "modem").
- Licencia: propietario Qualcomm/Xiaomi, **NO redistribuible**. Solo
  `local-private/`.

## 2. Kit firmware WCN3990

- `firmware-5.bin.ti` (60 B, `fef6539e...`): archivo genuino de
  linux-firmware para WCN3990/hw1.0, con `NON_BMI` → el ejecutable se
  entrega por QMI WLFW, no por BMI.
- `board-2.bin.ti` (670,116 B, `c03d801c...`): subset TI; variante
  específica laurel pendiente de confirmar (probable `qmi-board-id=67`).
- `wlanmdsp.mbn.ti` (3,725,044 B, `92e15012...`): ELF QUALCOMM DSP6, el
  firmware DSP real del WCN3990 (sdm845/wlanmdsp.mbn), se descarga por el
  modem vía tqftpserv.
- `notice.txt_wlanmdsp` y `LICENSE.QualcommAtheros_ath10k` (Redistributable)
  acompañan; ver `firmware/firmware-provenance.md` y
  `reports/linux61-wcn3990-firmware-matrix.md`.

## 3. Userspace

Kit en `local-private/diagnostics/wifi-priority/wcn3990-v2-build-ready/
userspace/` (APKBUILDs, initd, matrices):
- `qrtr` (aports community 1.2, `-Dqrtr-ns=disabled`): el NS lo cubre el
  kernel 6.1 (`net/qrtr/ns.c`, built-in, `CONFIG_QRTR=y`); NO se crea
  daemon qrtr-ns userspace.
- `pd-mapper`, `rmtfs`, `tqftpserv` (aports): cadena QRTR/PD/fs del modem.
- `msm-modem` (pmaports): UIM/wwan.
- Ver `linux61-sm6125-mpss-userspace-integration.md` y
  `linux61-sm6125-mpss-userspace-sequence.md`.

## 4. Parche DTS 0003 (enable MPSS, separado)

`patches/kernel-61/0003-dts-laurel-enable-mpss.patch` — sobre el fork
fijado `77de535b`, tras 0001 (WCN3990) y 0002 (MPSS transport, `disabled`):

- Añade `&remoteproc_mpss { status = "okay"; };` a nivel de placa
  (`sm6125-xiaomi-laurel_sprout.dts`, +4 líneas).
- Verificado con `git apply --check` y `git diff --check` sobre un árbol
  sintético con 0001+0002 aplicados.
- Se mantiene separado para que la v2 disabled siga byte-idéntica y el
  rollback 6.1 no cambie.

## 5. Validador (modo MPSS enabled sin romper v2)

- `scripts/validate-mpss-v2-final.py`: nuevo flag `--expect-mpss
  {disabled|okay}` (default `disabled`); el gate de status usa el valor
  esperado. Probado: v2 real (run 31819773343) PASS en disabled; DTS
  sintético con status `okay` PASS en okay.
- `scripts/verify-wcn3990-mpss-v2.sh`: flag `--expect-mpss` propagado al
  validador; en modo fuente, el gate del DTSI sigue esperando `disabled`
  (el estado efectivo lo decide el override de placa) y la rama de override
  valida en v3 la presencia del `&remoteproc_mpss` con `status="okay"` y sin
  re-declaraciones (power-domains/memory-region/interrupts). Corregido el
  uso de `!` en `gate` (no es palabra reservada en `"$@"`) → `gate_absent`.
- Resultados: v2 fuente sin override PASS (26 gates); v3 fuente con
  override PASS (30 gates); final-dts ambas variantes PASS (defecto
  cosmético conocido: el wrapper reporta "Gates: 0" en modo final-dts).
- Deuda técnica (cosmética, no bloqueante): `git diff --cached --check`
  señala "space before tab in indent" en las líneas de contexto del parche
  0003. Es un falso positivo del formato canónico de patch (espacio-marcador
  de contexto seguido de tab en DTS tabulado); 0001/0002 (ya merged en main)
  presentan exactamente el mismo patrón, y `git apply --whitespace=error
  --check` + `git apply` de la secuencia 0001→0002→0003 pasan sin error.
  00-quality no ejecuta `git diff --check` sobre parches. Se deja el parche
  en formato canónico (`git format-patch`) en vez de añadir `.gitattributes`
  que ampliaría el alcance a un sexto archivo.
- ShellCheck y `py_compile` OK.

## 6. Rollback 6.1 y respaldos

- `local-private/backups/2026-08-09/`: 13/13 hashes verificados contra
  `SHA256SUMS` (boot_a/b, dtbo_a/b, vbmeta_a/b, persist, modemst1/2,
  fsg/fsc, modem_a, dsp_a). `manifest.json` intacto.
- Procedimiento en `docs/BACKUP-GUIDE.md`.
- Dispositivo: no conectado en el momento de la verificación; se
  re-leerán vars de solo lectura (slot, unlocked) antes de cualquier prueba.

## 7. Estado honesto y siguiente puerta

Estado por subsistema (AGENTS.md §2):

| subsistema | estado |
|---|---|
| MPSS | `configured-enabled` / `boot-untested` |
| GLINK/QRTR | `untested` |
| WLFW | `untested` |
| WCN3990 | `DT-present` / `not functional` |
| Wi-Fi | `not working` |
| Prueba física | `blocked` (requiere autorización FASE 8) |

- Estado general: **CONFIGURED-CI-READY (v3 preparada)** / `boot-untested`
  / `blocked` en prueba física.
- NO se declara que la v3 funcione: la cadena MPSS→GLINK→QRTR→WLFW→FW_READY
  no está validada en hardware.
- Siguiente paso (requiere autorización): construir el artefacto v3 en
  GitHub Actions (aplicar 0003, DTB con MPSS okay, rootfs con firmware y
  userspace) y, en una FASE 8 autorizada, escribir `boot_b` y ejecutar los
  gates de MPSS, deteniéndose antes de wlan0/scan/asociación.

## Archivos relevantes

- `tools/private/prepare-sm6125-modem-firmware.sh` (bug del nombre corregido)
- `patches/kernel-61/0003-dts-laurel-enable-mpss.patch`
- `scripts/validate-mpss-v2-final.py`, `scripts/verify-wcn3990-mpss-v2.sh`
- `reports/linux61-sm6125-modem-firmware-extraction-plan.md` (actualizado)
- `local-private/diagnostics/wifi-priority/wcn3990-v2-build-ready/`
  (modem-firmware/, firmware/, userspace/, kernel-dts/, kernel-net-qrtr/)
