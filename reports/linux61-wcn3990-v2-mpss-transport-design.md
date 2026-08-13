# Diseño v2 — MPSS + transporte para WCN3990 (Linux 6.1)

Fecha: 2026-08-13. DISEÑO SOLO PARA REVISIÓN — **NO APLICADO, NO COMPILADO,
NO FLASHEADO**. Cumple AGENTS.md §8 (FASE 8): detenerse antes de cualquier
prueba física y solicitar autorización explícita.

## Objetivo

Añadir el subsistema MPSS (modem) vía remoteproc PAS en el fork fijado 6.1
y permitir que la WCN3990 reciba QMI WLFW vía QRTR (glink-edge "mpss",
canal IPCRTR), manteniendo intacto el resto del árbol y el probe v1.

## Principio de diseño: UNA sola variable

La v2 modifica un único vector: **añadir el nodo `remoteproc@6080000`
(MPSS) + sus subnodos glink-edge y smp2p-mpss en `sm6125.dtsi`**, usando el
compatible PAS existente del fork (`qcom,sm8150-mpss-pas`) con
power-domain único `SM6125_VDDCX`. NO se cambia el wifi node de la v1, NO
se toca MMC/SDIO, NO se añaden iommus.

## Decisiones de diseño (respaldadas en M1/M2/M3)

| decisión | opción | justificación |
|----------|--------|---------------|
| compatible PAS | `qcom,sm8150-mpss-pas` (existe en fork) | mismos params que vendor: pas_id 4, smem 421, minidump 3, firmware `modem.mdt`, ssctl 0x12; evita parche de driver |
| power-domain | `<&rpmpd SM6125_VDDCX>` único, SIN names | `genpd_dev_pm_attach` solo adjunta con 1 dominio → rama single-domain de `adsp_pds_attach` ignora "cx"/"mss" (mismatch evitado) |
| memory-region | `&modem_mem` (0x4b000000 + 0x7e00000) | ya existe en el árbol fijado; coincide con vendor |
| glink-edge | subnode dentro del remoteproc (modelo mainline) | `qcom_add_glink_subdev` busca subnode "glink-edge" |
| smp2p-mpss | nodo top-level `smp2p-mpss` | requerido por q6v5 (fatal/ready/handover/stop-ack/shutdown-ack) y contiene entry "wlan" |
| IRQ wdog | GIC_SPI 307 | coincide vendor trinket y QCM2290 |
| firmware | `/lib/firmware/qcom/sm6125/modem.mdt` | driver PAS espera `modem.mdt` (configurable por `qcom,firmware-name`, default "modem") |

## Pseudodiff DTS (NO aplicado)

En `arch/arm64/boot/dts/qcom/sm6125.dtsi` (fork fijado), añadir:

```dts
/* --- PSEUDODIFF v2 — NO APLICADO --- */

/* 1. smp2p-mpss (top-level, dentro de /soc@0) */
smp2p-mpss {
	compatible = "qcom,smp2p";
	qcom,smem = <435>, <428>;

	interrupts = <GIC_SPI 70 IRQ_TYPE_EDGE_RISING>;
	mboxes = <&apcs_glb 14>;

	qcom,local-pid = <0>;
	qcom,remote-pid = <1>;

	modem_smp2p_out: master-kernel {
		qcom,entry-name = "master-kernel";
		#qcom,smem-state-cells = <1>;
	};

	modem_smp2p_in: slave-kernel {
		qcom,entry-name = "slave-kernel";
		interrupt-controller;
		#interrupt-cells = <2>;
	};

	wlan_smp2p_in: wlan-wpss-to-ap {
		qcom,entry-name = "wlan";
		interrupt-controller;
		#interrupt-cells = <2>;
	};
};

/* 2. remoteproc MPSS (dentro de /soc@0) */
remoteproc_mpss: remoteproc@6080000 {
	compatible = "qcom,sm8150-mpss-pas";
	reg = <0x0 0x06080000 0x0 0x100>;

	interrupts-extended = <&intc GIC_SPI 307 IRQ_TYPE_EDGE_RISING>,
			      <&modem_smp2p_in 0 IRQ_TYPE_EDGE_RISING>,
			      <&modem_smp2p_in 1 IRQ_TYPE_EDGE_RISING>,
			      <&modem_smp2p_in 2 IRQ_TYPE_EDGE_RISING>,
			      <&modem_smp2p_in 3 IRQ_TYPE_EDGE_RISING>,
			      <&modem_smp2p_in 7 IRQ_TYPE_EDGE_RISING>;
	interrupt-names = "wdog", "fatal", "ready",
			  "handover", "stop-ack", "shutdown-ack";

	clocks = <&rpmcc RPM_SMD_XO_CLK_SRC>;
	clock-names = "xo";

	power-domains = <&rpmpd SM6125_VDDCX>;

	memory-region = <&modem_mem>;

	qcom,smem-states = <&modem_smp2p_out 0>;
	qcom,smem-state-names = "stop";

	status = "disabled";   /* se habilita solo en la prueba autorizada */

	glink-edge {
		interrupts = <GIC_SPI 68 IRQ_TYPE_EDGE_RISING>;
		label = "mpss";
		qcom,remote-pid = <1>;
		mboxes = <&apcs_glb 12>;
	};
};
```

El board file `sm6125-xiaomi-laurel_sprout.dts` añadiría
`&remoteproc_mpss { status = "okay"; };` SOLO en la variante de prueba.

### Requisitos previos de árbol ya presentes (ver M3)

- `modem_mem` (0x4b000000, 0x7e00000) ✓ en sm6125.dtsi
- `wlan_msa_mem` (0x53300000, 0x200000) ✓
- `rpmpd` compatible `qcom,sm6125-rpmpd` con `SM6125_VDDCX=0` ✓
- `apcs_glb` mailbox@f111000 ✓
- `intc` interrupt-controller@f200000 ✓
- `rpmcc RPM_SMD_XO_CLK_SRC` ✓

## Instrumentación de diagnóstico (fases)

La instrumentación NO cambia el comportamiento del kernel; solo captura.
Se define para la prueba física futura (no ejecutada ahora):

| sonda | qué mide | objetivo |
|-------|----------|----------|
| MPSS-DIAG | dmesg remoteproc/qcom_q6v5/pas tras `rproc_boot` | confirmar start del MPSS |
| GLINK-DIAG | `/sys/bus/rpmsg/devices/` + dmesg glink | confirmar edge "mpss" y canal IPCRTR |
| QRTR-DIAG | `/sys/kernel/debug/qrtr/` o dmesg qrtr-smd; `qrtr-ns -l` | confirmar nodo del modem |
| WCN3990-DIAG | dmesg ath10k + `ath10k_qmi_*` | confirmar connect QMI y FW_READY |
| SYSFS-SNAPSHOT | `/sys/class/remoteproc/*`, `/sys/class/net/` | estado tras cada gate |

## Gates 0-11 (prueba física futura, orden estricto)

1. **G0** autorización explícita e inmediata.
2. **G1** respaldo verificado (OK, M6).
3. **G2** `modem.mdt` presente + hash (M4).
4. **G3** firmware WCN3990 real presente (M4).
5. **G4** paquetes userspace instalados: qrtr, pd-mapper, rmtfs, tqftpserv (M5).
6. **G5** artefacto boot v2: `fastboot boot` temporal (menos destructivo), hash+size ≤ 0x4000000, slot listado.
7. **G6** boot temporal OK; MPSS-DIAG limpio; `/sys/class/remoteproc` muestra el rproc (aún sin start manual).
8. **G7** GLINK-DIAG: edge mpss presente tras start (rproc start SOLO si G6 y autorización nueva).
9. **G8** QRTR-DIAG: nodo modem registrado; SSCTL/WLFW visibles.
10. **G9** WCN3990-DIAG: QMI WLFW server aparece; FW_READY; `ath10k_core_register`.
11. **G10** `wlan0`/phy presentes; sin crash ni reset.
12. **G11** (opcional) `rfkill unblock` + asociación solo si G10 y autorización adicional.

Tras G11: recoger artefactos, detenerse, revisar y decidir siguiente
variante. NO continuar automáticamente.

## Riesgos de diseño v2 (resumen M6)

- Compatible `qcom,sm8150-mpss-pas` es un mapeo semántico (sc7180/sm8150
  para sm6125); aceptable como experimento, no como fix definitivo.
- `pd-mapper` requiere JSON de dominios para SM6125; puede fallar sin
  entrada propia (verificar upstream en M5).
- Firmware MPSS es condición bloqueante (M4/M6).

## Lo que NO hace la v2 (restricciones)

- NO modifica kernel, config, rootfs, initramfs ni workflows.
- NO compila, NO genera boot.img, NO abre CI.
- NO usa fastboot/adb/remoteproc start en esta misión.
- NO incluye iommus/SMMU (se mantiene ruta TrustZone de la v1).
- NO toca persist/modemst/fsg/fsc.
