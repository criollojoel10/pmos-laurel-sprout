# Plan de instrumentación — verificación de transporte QRTR (v2, diseño)

Fecha: 2026-08-13. Este documento es un **diseño** de los checkpoints y
verificaciones a ejecutar en la fase v2 (arquitectura modem-hosted), derivado de
la auditoría adversarial v1.5 (`linux61-wcn3990-v15-adversarial-audit.md`).
NO es un parche y NO se construirá hasta nueva autorización. No abre CI.

Objetivo: confirmar en el dispositivo, con evidencia mínima, que el bloqueo
observado (espera del servicio QMI WLFW) se debe a la ausencia de transporte
QRTR hacia el WCN3990 y que la v2 (remoteproc del modem + glink-edge IPCRTR +
smp2p-modem) es el camino correcto.

## 0. Precondiciones (obligatorias, no escritas)
- Autorización explícita del usuario para cada paso físico.
- Backups y hashes registrados (FASE 8 de AGENTS.md).
- Se conserva boot_b como rollback (`boot-linux61-baseline-consoleblank0.img`).

## 1. Verificaciones runtime solo-lectura (sin recompilar)
1. `cat /sys/bus/rpmsg/devices/*/modalias` → confirmar que NO existe canal
   "IPCRTR" (solo rpm-glink.*). Ya capturado en
   `runtime/v15audit/qrtr-rpmsg-glink-inventory.txt`.
2. `cat /proc/net/protocols | grep QIPCRTR` → protocolo registrado (ya visto).
3. `ls /sys/class/remoteproc/` → no hay remoteproc del modem (mpss) ni wcss.
4. `ls /sys/bus/platform/drivers/qcom_q6v5_mss` → módulo soportado pero sin
   device node (ausencia de nodo mpss en DT).
5. `/proc/interrupts` → WLAN_CE_0..11 presentes (request_irq OK, ya visto).

## 2. Checkpoints de código para la v2 (instrumentación propuesta)
Se añadirían marcas `WCN3990-DIAG:` vía `dev_info`/`pr_debug` en la v2 (aún NO):

- `ath10k_snoc_probe`: entrada, retorno (capturar código de retorno real).
- `ath10k_fw_init`: `use_tz = true/false` según presencia de child wifi-firmware.
- `ath10k_qmi_init`: `qmi_handle_init` OK, `qmi_add_lookup(WLFW 0x47)` enviado.
- `ath10k_qmi_event_server_arrive`: **si llega un servidor WLFW** → anotar
  node-id, service-id, versión. Este es el punto de corte del diagnóstico.
- `ath10k_snoc_fw_indication`: FW_READY llegado → core_register.
- `ath10k_core_register_work` / `ath10k_mac_register`: wlan0 creado.

Estos checkpoints solo confirman; la decisión de fondo (añadir remoteproc mpss +
glink IPCRTR + smp2p-modem) la determina la arquitectura del apartado 3.

## 3. Pasos de la v2 (diseño, orden sugerido, NO ejecutados)
1. **DT**: añadir a `sm6125.dtsi` (rama v6.1-sm6125) los nodos:
   - `remoteproc` del modem (`qcom,q6v5-mss` / PAS, compatible que exista para
     SM6125) con `memory-region = <&modem_mem>` (ya reservada en el árbol).
   - `glink-edge` dentro del remoteproc con canal **"IPCRTR"** y `qcom,remote-pid
     = <1>`.
   - `qcom,smp2p-modem` con los estados `master-kernel`/`slave-kernel` y la
     entrada **wlan** (`qcom,entry-name = "wlan"`), que es la que el driver
     icnss/ath10k espera.
   - Mantener el nodo `wifi@c800000` ya parcheado (IRQ 358..369, MSA
     `wlan_msa_mem@53300000`, 4 supplies) — confirmados contra el DT vendor.
2. **Kconfig**: verificar en el defconfig fijado que `QCOM_Q6V5_MSS=m`,
   `QCOM_Q6V5_PAS=m`, `RPMSG_QCOM_GLINK=y`, `QCOM_SMP2P=y`, `QRTR=m` están
   activos (ya lo están; sin cambios de config a priori).
3. **Firmware**: documentar de dónde sale `wlanmdsp.mbn` (modem DSP/tqftpserv) y
   el firmware WCN3990 real (`firmware-5.bin` + `board-2.bin` con entrada
   laurel_sprout), con licencia verificada. NO se instala sin autorización.
4. **Orden de arranque**: el remoteproc del modem debe estar *up* antes de que el
   nodo wifi haga la lookup WLFW (o esperar a que el subsistema notifique). El
   glink-edge del modem debe registrar el canal IPCRTR → qrtr-smd se vincula →
   endpoint QRTR → nameservice anuncia servidores del nodo remoto.

## 4. Criterios de aceptación (cómo se decide)
- **CONFIRMADO bloqueo QRTR**: si tras la v2 el nodo wifi recibe server arrive
  WLFW y wlan0 aparece → la hipótesis modem-hosted queda validada.
- **NO-GO v2**: si con el remoteproc del modem activo el canal IPCRTR no aparece
  (glink/smem roto) o el servidor WLFW no se anuncia → revisar firmware del
  modem, smem states, y si el secure world arranca realmente el WCN3990.

## 5. Riesgos y límites
- Arrancar el modem remoteproc puede alterar otros subsistemas (mss comparte
  recursos). Se limita a una imagen de prueba con rollback inmediato.
- `wlanmdsp.mbn` y el firmware WCN3990 son blobs de licencia restrictiva; solo
  se usan si se dispone de fuente con licencia y no se publican.
- El node-id QRTR exacto del WCN3990 en SM6125 no está verificado; se observará
  en la instrumentación (server arrive lleva src_node).

## 6. Entregables de la fase v2
- Reporte de ejecución con las marcas `WCN3990-DIAG:` y el estado del canal
  IPCRTR / servidor WLFW.
- Actualización de `reports/hardware-matrix.json` y `docs/HARDWARE-STATUS.md`
  según los estados permitidos por AGENTS.md (nunca declarar "working" por
  compilar).