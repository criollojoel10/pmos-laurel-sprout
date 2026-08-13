# Diagnóstico v1.5 — WCN3990: dónde se detiene el probe

Fecha: 2026-08-12. Después del primer probe físico v1
(`reports/linux61-wcn3990-first-probe-v1.md`). Método: inspección del código
del driver en el commit fijado `77de535b8dbd8f483b5802c8937cb714bab5b485`
(v6.1) y comparación con la referencia mainline funcional qcs404. Sin
recompilar; Dynamic Debug no está disponible en la build actual.

## Pregunta 1 — ¿El probe terminó correctamente y espera asincrónicamente al servicio WLFW?

**SÍ, terminó correctamente y espera asincrónicamente.**

Evidencia en el dispositivo (v1):
- Los workqueues `ath10k_wq`/`ath10k_aux_wq`/`ath10k_tx_compl` están en
  `rescuer_thread` (idle, sin work item pendiente). No están bloqueados en
  espera QMI síncrona.
- El driver está vinculado (`c800000.wifi/driver -> ath10k_snoc`) y
  `devices_deferred` está vacío → el probe retornó 0 con éxito.

Evidencia en código (`ath10k_snoc_probe`, snoc.c v6.1):
- El probe NO crea `wlan0`. Secuencia: core_create → resources → IRQs →
  regulators → clocks → MSA → `ath10k_fw_init` (use_tz=true, sin child
  `wifi-firmware`) → `ath10k_qmi_init` → `ath10k_modem_init` → return 0.
- `wlan0` se crea en `ath10k_core_register` → `ath10k_mac_register`, que en
  SNOC/WCN3990 solo ocurre cuando llega el **servidor QMI `wlfw`**
  (`ath10k_qmi_event_server_arrive`, qmi.c línea 772+).

Conclusión: el probe terminó; el driver quedó registrado como cliente QMI
`wlfw` (`qmi_add_lookup(..., WLFW_SERVICE_ID_V01, ...)`) y espera que el
servidor aparezca vía QRTR. Como nunca llega, no hay wlan0 ni petición de
firmware.

## Pregunta 2 — ¿Existe un transporte QRTR real, además del protocolo registrado?

**NO.**

- `NET: Registered PF_QIPCRTR` solo registra el protocolo QRTR.
- `lsmod` muestra solo `qrtr` (core). `qrtr-smd`, `qrtr-tun` y
  `qcom_wcnss_pil` existen como módulos pero NO están cargados.
- No hay canal rpmsg `IPCRTR`, no hay glink-edge del WCNSS, no hay
  remoteproc WCNSS vinculado. Los únicos endpoints glink/rpmsg del sistema
  son del **RPM** (`rpm-glink.*`: reguladores/clocks/power-controller), que
  no tienen relación con WiFi.
- `/proc/net/qrtr` vacío: sin nodos ni servicios QRTR.

Sin transporte QRTR hacia el WCN3990, el servidor wlfw jamás llega → el
probe espera para siempre (exactamente lo observado).

## Pregunta 3 — ¿TrustZone o wifi-firmware + SMMU?

**Ninguna de las dos es la causa del bloqueo. El problema es la ausencia del
componente que arranca el WCN3990 y expone su QRTR.**

Referencia mainline funcional (qcs404, `qcom,qcs404-wcss-pas` en
`remoteproc@7400000` con `glink-edge { label = "wcss"; qcom,remote-pid = <1>; }`):
- El WCN3990 se carga por **remoteproc PAS** (TrustZone autentica el firmware).
- El remoteproc WCNSS provee el **glink-edge** que es el transporte QRTR para
  el servicio wlfw.
- El nodo wifi (`qcom,wcn3990-wifi`) con `use_tz=true` y `wlan_msa_mem`
  funciona porque ese transporte QRTR existe.

Estado del SM6125 en nuestro árbol fijado:
- `sm6125.dtsi` NO contiene remoteproc WCNSS ni nodo wifi; solo `wlan_msa_mem`
  y los remoteproc RPM. El nodo `wifi@c800000` se añadió por nuestro parche.
- No hay glink-edge WCNSS → no hay QRTR hacia el WCN3990 → wlfw no llega.

Por tanto:
- **Camino A (TrustZone+QMI)** es correcto en principio (use_tz ya activo),
  pero necesita el remoteproc WCNSS + glink-edge + firmware para que el
  transporte QRTR exista. En SM6125 esto requiere portar/crear el nodo
  remoteproc del WCNSS y verificar que el secure world realmente lo levante.
- **Camino B (wifi-firmware + SMMU)** no es la causa del bloqueo; aplicarlo
  solo añadiría una ruta de DMA que no resuelve el transporte QRTR. Se
  descarta hasta confirmar que el WCN3990 del SM6125 no arranca por PAS.

## Firmware-5.bin de 60 bytes

**Es un stub/truncado, NO el firmware real.** Contenido (60 bytes):
magic `QCA-ATH10K.w` + cabecera TLV. Un firmware WCN3990 hw1.0 real en
linux-firmware pesa ~2 MB (algunas fuentes ~1.5 MB). SHA-256
`fef6539e0127579536bc977be57a90d018b83f2931fedc3a8870fbe38d6c4127`.
NO debe copiarse al rootfs. `board-2.bin` (893,528 B, SHA
`c49d2f18...`) sí tiene tamaño plausible de board data, pero no se instala
todavía.

## Conclusión y recomendación

1. El probe v1 fue un éxito parcial correcto: DT → driver → regulators
   confirmados; el bloqueo es la espera del servicio QMI wlfw por falta de
   transporte QRTR.
2. La v2 NO debe añadir firmware ni SMMU a ciegas. El siguiente paso es
   determinar cómo arranca el WCN3990 en SM6125/laurel_sprout:
   a. Verificar en la tabla de particiones si hay firmware WCN3990 (wlan) y
      si el bootloader/TrustZone lo carga (evidencia del stock).
   b. Comprobar si el SM6125 mainline más reciente (2024+) tiene remoteproc
      WCNSS o un manejo de WCN3990 añadido, para portarlo.
   c. Decidir: portar remoteproc WCNSS (glink-edge + qcom,smem-states) o,
      si se confirma que el WCN3990 no tiene PAS, evaluar el camino QMI
      completo con firmware.
3. Camino C (instrumentación) solo como respaldo si se necesita confirmar el
   punto exacto de espera, pero la evidencia de código ya lo localiza
   (espera QRTR en server-arrive).

## Nota sobre limpieza

La referencia de código descargada (snoc.c/qmi.c v6.1 y dtsi de referencia)
se mantiene en `/tmp/opencode` y NO se incluye en el repositorio.
