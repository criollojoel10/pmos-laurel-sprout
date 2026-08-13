# Auditoría adversarial — Diagnóstico WCN3990 v1.5

Fecha: 2026-08-13. Auditoría del informe `linux61-wcn3990-diagnostic-v15.md`
(commit `d1b7517`). Método: verificación del código exacto del commit fijado
`77de535b8dbd8f483b5802c8937cb714bab5b485` (rama `v6.1-sm6125`), comparación
byte a byte con torvalds v6.1, evidencia runtime solo-lectura capturada en el
dispositivo, y referencia arquitectural del kernel vendor Xiaomi/LineageOS
SM6125 (`trinket.dtsi`, kernel 4.14). Todo el trabajo fue análisis estático y
lectura; sin recompilar, sin tocar el teléfono, sin abrir CI.

Evidencia en `local-private/diagnostics/wifi-priority/wifi-v15-audit/`:
`code-flow.md`, `source-hashes.txt`, `firmware-file-analysis.txt`,
`source-links.txt`, `decision.txt`, `runtime/v15audit/*` (capturas del
dispositivo). (Fuera de git, como exige AGENTS.md.)

---

## 1. Qué afirmaciones de d1b7517 sobreviven y cuáles se corrigen

### 1.1 "El probe terminó correctamente" — CORREGIDA (evidencia inválida)

El informe citaba los symlinks `c800000.wifi/driver -> ath10k_snoc` y
`drivers/ath10k_snoc/c800000.wifi` como prueba de que `probe()` retornó 0.

En `drivers/base/dd.c` (`really_probe`), `driver_sysfs_add(dev)` (línea ~626) se
ejecuta **antes** de `call_driver_probe(dev)` (línea ~639), y es
`driver_sysfs_add` quien crea los dos symlinks (fix-dd.c:434-455). Por tanto los
symlinks **no prueban** que el probe terminó ni su código de retorno; solo
prueban el vínculo device↔driver.

Lo que sí sostiene la conclusión funcional ("el probe no quedó bloqueado en
espera síncrona"):
- 12 IRQ `WLAN_CE_0..11` registradas en `/proc/interrupts` (GICv3 390..401 =
  SPI 358..369, coincide con el DT del parche) → `ath10k_snoc_request_irq` OK
  (snoc.c:1397).
- Workqueues `ath10k_wq`/`ath10k_aux_wq`/`ath10k_tx_compl` creados
  (`ath10k_core_create`, core.c:2082-2087).
- Búsqueda `all-stacks`: ninguna tarea con `ath10k_snoc_probe`/qmi/qrtr en pila.
- `ath10k_snoc` refcnt 0.

Con `use_tz=true` y sin firmware, el probe retorna 0; el primer intento de
solicitud de firmware (`ath10k_core_probe_fw`) se ejecuta en
`ath10k_core_register_work`, que solo se dispara cuando llega el servidor WLFW.

### 1.2 "Workqueues en rescuer_thread = idle sin work" — CORREGIDA (interpretación)

`create_singlethread_workqueue()` usa `WQ_MEM_RECLAIM` y crea un **rescuer
thread** por workqueue; su estado normal y permanente es `rescuer_thread+...`
idle. Los tres hilos observados son rescuers. Esto **no** dice nada sobre el
estado del cliente QMI. Además, el workqueue QMI `ath10k_qmi_driver_event` se
crea con `WQ_UNBOUND` (fix-qmi.c:1048) y **no genera un hilo nombrado visible**,
así que su ausencia de `ps` no es evidencia de nada. La conclusión correcta de
1.1 se apoya en las IRQ y en los stacks, no en la pila del rescuer.

### 1.3 "No existe transporte QRTR real" — MANTENIDA, con precisión

- `/proc/net/qrtr` **no existe** en este kernel: `af_qrtr.c` no tiene
  `proc_create` (verificado en el commit fijado). "Vacío" fue impreciso;
  la ausencia del proc file es normal.
- Lo que demuestra la falta de transporte: en `/sys/bus/rpmsg` solo hay
  dispositivos `rpm-glink.*` (RPM); `qrtr-smd` (id_table `{"IPCRTR"}`) no tiene
  canal que vincular; `qcom_wcnss_pil` no cargado; `/proc/net/protocols`
  registra `QIPCRTR` (protocolo) pero no hay endpoint hacia el WCN3990.
- La nameservice QRTR (`qrtr_ns_init`, ns.c:758) bindea `QRTR_PORT_CTRL` en el
  nodo local; sin transporte no llega ningún `NEW_SERVER` → el lookup WLFW de
  ath10k no responde. Correcto.

### 1.4 "Falta remoteproc WCNSS / analogía qcs404" — CORREGIDA (hallazgo central)

El informe v1.5 asumió el modelo de referencia **qcs404** (remoteproc WCNSS con
glink-edge "wcss" proveyendo QRTR al WCN3990) y recomendó "portar remoteproc
WCNSS". La auditoría muestra que **el SM6125 no usa esa arquitectura**:

- **qcs404** (mainline v6.1): `remoteproc@7400000` compatible
  `qcom,qcs404-wcss-pas` → manejado por `qcom_q6v5_pas.c`
  (`wcss_resource_init`, firmware `wcnss.mdt`, pas_id 6, up-v61-pas.c:958), con
  glink-edge `{label="wcss"; qcom,remote-pid=<1>}` que provee el transporte
  QRTR/IPCRTR hacia el WCN3990. (No hay bug `-pas`/`-pil`: el driver que
  corresponde al DT es el PAS, no el q6v5_wcss.)
- **sdm845/msm8998** (mainline): `wifi@18800000` (`qcom,wcn3990-wifi`) sin
  remoteproc propio; el transporte QRTR hacia el WCN3990 se resuelve por el
  subsistema del **modem**.
- **SM6125 (vendor, trinket.dtsi)**: el nodo es **ICNSS**:
  ```
  icnss: qcom,icnss@C800000 {
      compatible = "qcom,icnss";
      reg = <0xC800000 0x800000>, <0xa0000000 0x10000000>, <0xb0000000 0x10000>;
      reg-names = "membase", "smmu_iova_base", "smmu_iova_ipa";
      iommus = <&apps_smmu 0x80 0x1>;
      interrupts = <0 358 0> .. <0 369 0>;      /* CE0..CE11, iguales a nuestro parche */
      qcom,wlan-msa-fixed-region = <&wlan_msa_mem>;  /* 0x53300000 0x200000 */
      vdd-cx-mx-supply = <&L8A>; vdd-1.8-xo-supply = <&L16A>;
      vdd-1.3-rfa-supply = <&L17A>; vdd-3.3-ch0-supply = <&L23A>;
      qcom,smp2p_map_wlan_1_in { interrupts-extended = <&smp2p_wlan_1_in 0 0>, ... };
  };
  ```
  - `smp2p_wlan_1_in` está **dentro de `qcom,smp2p-modem`** (entry-name
    `"wlan"`, remote-pid 1) → el subsistema WLAN es periférico/raíz del MODEM.
  - El transporte QRTR del WCN3990 en SM6125 es el **glink-edge del modem**:
    `glink_modem { qcom,glink-channels = "IPCRTR"; ... }` dentro de
    `qcom,glink` (`compatible = "qcom,glink"`). No hay edge "wcss".
  - El firmware del WCN3990 (`wlanmdsp.mbn`) lo sirve el **DSP del modem**
    (tqftpserv en mainline/RB1) o vive en la partición modem (evidencia
    msm8998); el driver icnss solo gestiona power/MSA/QMI.
  - IRQ 358..369 y `wlan_msa_mem@53300000` coinciden exactamente con nuestro
    parche v1 → el DT del vendor confirma nuestra asignación de recursos.

**Conclusión**: en SM6125 el WCN3990 es **modem-hosted** (arquitectura
ICNSS/sdm845), no remoteproc-wcss (qcs404). El árbol fijado `sm6125.dtsi` no
tiene remoteproc del modem (mpss), ni glink-edge del modem con IPCRTR, ni
`smp2p-modem` → no existe transporte QRTR → el servidor WLFW jamás llega.
(El `defconfig` fijado sí compila `QCOM_Q6V5_MSS=m`, `QCOM_Q6V5_PAS=m`,
`RPMSG_QCOM_GLINK=y`, `QCOM_SMP2P=y`, `QRTR=m` — el soporte de kernel existe;
falta el DT del modem y el firmware.)

### 1.5 "use_tz vs wifi-firmware+SMMU: ninguna causa el bloqueo" — MANTENIDA

Con sub-nodo `wifi-firmware`, `ath10k_fw_init` solo crea un device y un dominio
IOMMU (`iommu_domain_alloc`/`iommu_attach_device`/`iommu_map`, snoc.c:1600-1670)
para DMA de la MSA; **no crea transporte QRTR**. Con `use_tz=true` (sin child)
se asume que el firmware ya fue cargado por el secure world. En ningún caso se
resuelve la ausencia del transporte QRTR del modem. No es la causa; añadirlo a
ciegas no desbloquea nada.

### 1.6 "firmware-5.bin 60 B es stub; real ~2 MB" — MANTENIDA (stub), NO VERIFICADO (tamaño)

`firmware-5.bin`: 60 bytes, SHA-256
`fef6539e0127579536bc977be57a90d018b83f2931fedc3a8870fbe38d6c4127`, magic
`QCA-ATH10K.w` + cabecera TLV → stub/truncado confirmado; no debe copiarse.
`board-2.bin`: 893,528 B, SHA-256 `c49d2f18...` — tamaño plausible de board
data, no instalado. El tamaño "~2 MB" del firmware real queda **sin fuente
verificada** (no se descargó ninguna imagen real por licencia) → se registra
como pendiente, no se afirma.

---

## 2. Arquitectura SM6125 más probable y confianza

**Módem-hosted / ICNSS** (el WCN3990 es periférico del modem; el QRTR/IPCRTR
viene del glink-edge del modem; el modem DSP sirve `wlanmdsp.mbn`).

Confianza: **alta** (DT vendor `trinket.dtsi` de SM6125 + driver icnss +
glink "IPCRTR" del modem + evidencia RB1/WCN3990 en mainline). La alternativa
"remoteproc wcss" (qcs404) queda **refutada** para SM6125. Limitaciones: no se
verificó el node-id QRTR del WCN3990 en un dispositivo con transporte activo,
ni el estado funcional del WiFi en qcs404 mainline v6.1, ni el contenido del
board-2.bin para laurel_sprout.

## 3. GO / NO-GO — v1.5 instrumentada

**NO-GO.** La instrumentación del probe (checkpoints en snoc/qmi) confirmaría el
punto exacto de espera, pero eso ya está localizado por la evidencia de código
(espera en `ath10k_qmi_event_server_arrive`, sin transporte QRTR) y **no cambia
el diagnóstico ni desbloquea funcionalidad**. No aporta valor suficiente para
justificar una build.

El siguiente paso correcto es **v2 con arquitectura modem-hosted**, no parches
de instrumentación ni de SMMU/wifi-firmware a ciegas:
1. Añadir al DT mainline el **remoteproc del modem** (mpss, PAS) con su
   **glink-edge** (canal `IPCRTR`) y **`qcom,smp2p-modem`** (incluyendo el
   estado wlan), con `modem_mem` ya reservado en el árbol fijado.
2. Confirmar cómo se sirve `wlanmdsp.mbn` (tqftpserv/userspace) y disponer de
   firmware WCN3990 real (`firmware-5.bin` + `board-2.bin` con entrada
   laurel_sprout) con licencia verificada.
3. Mantener `use_tz` (sin child `wifi-firmware`) mientras no se confirme la
   ruta de MSA/SMMU del modem; el nodo wifi ya usa IRQ y MSA correctos.
4. Verificar en el stock si el bootloader/TZ ya arranca el WCN3990 (partición
   `wlan`/`modem`) antes de decidir qué parte toca al kernel.

Esto es trabajo de otra fase (DT de remoteproc + firmware + posible userspace)
que excede la misión actual; queda documentado como recomendación, sin abrir CI.

## 4. Archivos creados / modificados

- `reports/linux61-wcn3990-v15-adversarial-audit.md` (este informe, a commitear).
- Evidencias en `local-private/diagnostics/wifi-priority/wifi-v15-audit/`
  (`code-flow.md`, `source-hashes.txt`, `firmware-file-analysis.txt`,
  `source-links.txt`, `decision.txt`, `runtime/v15audit/*`) — fuera de git.
- `local-private/diagnostics/wifi-priority/wifi-v15-audit/vendor-scratch/`
  (referencias vendor/mirrors, fuera de git).

## 5. Cumplimiento de restricciones

No ejecuté Fastboot, no reinicié el teléfono, no instalé firmware, no modifiqué
el rootfs y no abrí CI. Solo lectura del dispositivo (capturas previas de v1/v1.5).
Sin datos personales en el repositorio.
