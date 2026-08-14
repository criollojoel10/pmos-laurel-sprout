# Audit firmware real WCN3990 (hw1.0) — variante MPSS v2

Estado: `source-available`
Fecha: 2026-08-13
Fase: M9 de la misión MPSS v2 (firmware WCN3990 real)
No se ejecutó ninguna operación física; nada se probó en el dispositivo.

---

## 1. Objetivo

Determinar y auditar el firmware real del WCN3990 (hw1.0) que el stack
ath10k SNOC necesita en la variante v2, descartando aceptar como
"firmware real" un archivo que fuera un stub de descarga fallida
(pointer LFS, HTML, 404) y documentando con honestidad qué archivo es
realmente ejecutable y qué archivo es metadata.

## 2. Pregunta crítica resuelta

El reporte de fase v1 (`reports/linux61-wcn3990-firmware-matrix.md:21-23`)
cuestionaba el `firmware-5.bin` de **60 B** por ser un tamaño inusual para
un firmware ejecutable. **La investigación M9 resuelve la duda:**

- Los 60 B **sí son el archivo genuino** que linux-firmware distribuye para
  `ath10k/WCN3990/hw1.0/firmware-5.bin`. No es stub, no es LFS, no es HTML.
- `firmware-5.bin` para WCN3990 es un **descriptor de metadata** (IEs de
  versión/características), no una imagen de firmware.
- El **firmware ejecutable** del WCN3990 es `wlanmdsp.mbn` (ELF DSP6 de
  Qualcomm, ~3.7 MB), entregado **por QMI WLFW** desde la WPSS/MPSS y
  descargado por el DSP del modem vía **tqftpserv**. El driver ath10k no lo
  carga por BMI (ver sección 4).

## 3. Verificaciones realizadas

### 3.1 firmware-5.bin (60 B)

- **Reproducibilidad del hash**: IDÉNTICO (`cmp` sin diferencias) entre
  dos fuentes independientes:
  - linux-firmware commit `e3c0c4b70f50ae77bea557b4a44be04413d3f3ed`
    (descargado en fase v1).
  - ti-linux-firmware (mirror) commit
    `edbfc3e540c9f426feb51db6a466a9015ada4dd0`.
  - SHA-256: `fef6539e0127579536bc977be57a90d018b83f2931fedc3a8870fbe38d6c4127`
- **Magic**: `QCA-ATH10K\0` correcto (`ATH10K_FIRMWARE_MAGIC`, hw.h:158).
- **Contenido parseado** (formato `ath10k_fw_ie`, core.c):
  - IE 1 (TIMESTAMP) = `0x5bb2e4a4`
  - IE 2 (FEATURES) = bytes `40 00 0c` → bits **6, 18, 19**
  - IE 5 (WMI_OP_VERSION) = 4
  - IE 6 (HTT_OP_VERSION) = 3
- **Interpretación de bits de features** (enum `ath10k_fw_features`,
  core.h:738-838):
  - bit 6 = `ATH10K_FW_FEATURE_WOWLAN_SUPPORT`
  - bit 18 = `ATH10K_FW_FEATURE_MGMT_TX_BY_REF`
  - bit 19 = `ATH10K_FW_FEATURE_NON_BMI`
- **Consecuencia**: con `NON_BMI` activo, `ath10k_core_fetch_firmware_api_n`
  NO exige `ATH10K_FW_IE_FW_IMAGE` (core.c:2133-2138). El archivo de 60 B es
  **válido y suficiente** como `firmware-5.bin` para el flujo QMI de WCN3990.

### 3.2 wlanmdsp.mbn (firmware DSP real)

- Origen: ti-linux-firmware commit `edbfc3e`, ruta `qcom/sdm845/wlanmdsp.mbn`
  (en linux-firmware es symlink:
  `ath10k/WCN3990/hw1.0/wlanmdsp.mbn -> ../../../qcom/sdm845/wlanmdsp.mbn`).
- `file`: `ELF 32-bit LSB executable, QUALCOMM DSP6, dynamically linked`
- Tamaño: 3,725,044 B. SHA-256:
  `92e1501254e6de78c0f2e2cf091507d488b608d07e53acd14813a82744823ec2`
- Versión WHENCE: `WLAN.HL.2.0-01387-QCAHLSWMTPLZ-1`
- Licencia: Redistributable (LICENSE.QualcommAtheros_ath10k); notice:
  `notice.txt_wlanmdsp` presente.

### 3.3 board-2.bin

- Existen dos versiones según commit:
  - `e3c0c4b7` (fase v1): 893,528 B, SHA-256
    `c49d2f1894de6edc0ab0c8c9a17ca0328703747c49b6e9428f1de501c2c02c1d`
    (36 board names).
  - `edbfc3e` (TI): 670,116 B, SHA-256
    `c03d801cba1233914d777644e368ea942f36064e805ba6102514dedb47e53c76`
    (subset).
- Magic del archivo: `QCA-ATH10K-BOARD\0`, versión `0x6d6d6d`.
- Board names con `bus=snoc` (36): sdm845 (chip-id 30214), sm8150
  (30224), WCN3990 (chip-id 320 y 4320: GO_LAZOR, GO_POMPOM,
  GO_QUACKINGSTICK, GO_PAZQUEL360, GO_HOMESTAR, GO_MRBLAND,
  GO_WORMDINGLER, ECS_QC710, RB1, RB2, Arduino_Iola, Shikra_EVK,
  Google_blueline, crosshatch, Huawei_Planck, Lenovo_C630, DB845C,
  oneplus_sdm845, shift_axolotl, xiaomi_beryllium, Xiaomi_raphael).
- **No hay variante explícita para `laurel` / `SM6125` / `trinket`**.
  La entrada genérica `bus=snoc,qmi-board-id=67` (sin variante) es la
  candidata más probable, pero **el board-id real del SM6125 debe
  confirmarse en dmesg durante un futuro probe** (igual que señalaba el
  inventario v1).
- `board.bin` (fallback API<5): **NO existe** en linux-firmware para
  WCN3990/hw1.0; el driver WCN3990 usa `board-2.bin` (API 5). No hay que
  crear un fallback falso.

## 4. Cómo se entrega el firmware en el stack v2 (flujo real)

1. MPSS (modem/remoteproc) arranca; el DSP del modem descarga
   `wlanmdsp.mbn` vía tqftpserv (servidor TFTP del host, fase M10/M11).
2. El WCN3990 queda con firmware y expone el servicio **QMI WLFW**.
3. ath10k (SNOC) se conecta por QMI; con `NON_BMI` no descarga firmware
   por BMI (core.c:2133). Solo necesita:
   - `firmware-5.bin` (metadata/features, 60 B) — verificado.
   - `board-2.bin` (calibración por board-id) — verificado.
4. El driver crea `wlan0` **solo si** MPSS+glink+QMI están operativos.

Esto refuerza el diseño v2 (MPSS como prerequisito del WCN3990).

## 5. Registro de licencias

| Archivo | Licencia | Fuente WHENCE |
|---|---|---|
| `firmware-5.bin` | Redistributable | `Licence: Redistributable. See LICENSE.QualcommAtheros_ath10k` |
| `board-2.bin` | Redistributable | idem |
| `wlanmdsp.mbn` | Redistributable | idem (version WLAN.HL.2.0-01387) |
| `notice.txt_wlanmdsp` | notice QCA 2015 | WHENCE |
| `LICENSE.QualcommAtheros_ath10k` | texto completo (2713 B) | raíz linux-firmware |

LICENSE verificada (SHA-256 `337a5510...`): redistribución en binario sin
modificación para uso con chipset Qualcomm Atheros; prohibe reverse
engineering; licencia de patente limitada.

## 6. Estado del firmware v2 (honesto)

| Item | Estado permitido | Evidencia |
|---|---|---|
| `firmware-5.bin` | `source-available` (validado) | hash reproducible 2 fuentes, magic, IEs NON_BMI |
| `wlanmdsp.mbn` | `source-available` (descargado) | ELF DSP6, licencia Redistributable, notice |
| `board-2.bin` | `source-available` (validado) | magic, 36 variantes; variante laurel pendiente |
| `board.bin` | `not-targeted` (no existe) | linux-firmware no lo distribuye |
| wlan0 / firmware cargado / MPSS up | **NO DECLARADO** | sin prueba física |

## 7. Gate M9

Criterios del gate:
- `firmware-5.bin` no es stub/LFS/HTML: **PASS** (es el archivo genuino
  de linux-firmware, validado por `cmp` y por estructura).
- payload plausible: **PASS** (IEs coherentes con WCN3990; NON_BMI).
- hash reproducible: **PASS** (idéntico en 2 commits independientes).
- licencia registrada: **PASS** (Redistributable + LICENSE + notice).

**Veredicto gate M9: PASS**, con dos pendientes que no bloquean la
investigación pero sí el estado BUILD-READY final:
1. Confirmar board-id real de laurel (en dmesg, solo en futura prueba
   física).
2. Incluir `wlanmdsp.mbn` en el paquete de firmware de la MPSS
   (tqftpserv) — decisión que se cierra en M10/M11.

Los binarios permanecen SOLO en `local-private/`
(`.../wcn3990-v2-build-ready/firmware/`). Nada se publica.
