# Revisión del parche v2 — MPSS transport DTS (Linux 6.1)

Fecha: 2026-08-13. Misión M12 de la variante WCN3990 v2 BUILD-READY.
Revisión estática del parche `0002-dts-sm6125-add-mpss-transport-v2.patch`
contra el fork fijado `77de535b8dbd8f483b5802c8937cb714bab5b485`.

Este documento NO autoriza ninguna operación física. Estado registrado:
`configured` (build-ready, boot-untested).

## Verdict

**PASS (gate M12).** El parche 0002 aplica limpio sobre el `sm6125.dtsi`
del fork fijado, añade el transporte MPSS que la WCN3990 necesita para
QMI WLFW vía QRTR, mantiene `status = "disabled"` (sin cambio de
comportamiento de boot) y deja intacto el nodo WCN3990 v1 (0001).

## Revalidación del compatible PAS (driver real del fork)

En M2 se había documentado como riesgo la ausencia del compatible
`qcom,sm6115/sm6125-mpss-pas`. Para M12 se descargó y auditó el driver
REAL que compila el fork fijado:

- Fuente: `drivers/remoteproc/Makefile` del fork → `obj-$(CONFIG_QCOM_Q6V5_PAS)
  += qcom_q6v5_pas.o` (NO `pas-v66.c`, que es de la rama 6.6).
- Archivo real: `drivers/remoteproc/qcom_q6v5_pas.c` (1004 líneas) descargado
  del fork `v6.1-sm6125` (commit `77de535b`).
- Compatibles MPSS presentes en el fork 6.1:
  - `qcom,sc7180-mpss-pas` → `mpss_resource_init`
  - `qcom,sc7280-mpss-pas` → `mpss_resource_init`
  - `qcom,sc8180x-mpss-pas` → `sc8180x_mpss_resource`
  - `qcom,sm6350-mpss-pas` → `mpss_resource_init`
  - `qcom,sm8150-mpss-pas` → `mpss_resource_init`
  - `qcom,sm8350-mpss-pas` → `mpss_resource_init`
- **NO existe** `qcom,sm6115-mpss-pas` ni `qcom,sm6125-mpss-pas` en el fork 6.1
  (esos compatibles aparecen solo en la rama 6.6 `pas-v66.c`).

`mpss_resource_init` (qcom_q6v5_pas.c:804-820):
`crash_reason_smem=421, firmware_name="modem.mdt", pas_id=4, minidump_id=3,
has_aggre2_clk=false, auto_boot=false, proxy_pd_names=["cx","mss"],
load_state="modem", ssr_name="mpss", sysmon_name="modem", ssctl_id=0x12`.

Coincide con el MPSS vendor SM6125 (pas_id 4). `sc8180x_mpss_resource` difiere
(sin minidump, solo cx), por lo que se descarta.

### Decisión del compatible

`compatible = "qcom,sm8150-mpss-pas"` — mismo `adsp_data` que el MPSS vendor,
sin necesidad de parche de driver. Confirmado contra el driver real del fork
(no contra la rama 6.6).

## Confirmación de la rama single power-domain

En `adsp_pds_attach()` (qcom_q6v5_pas.c:386-421), cuando el nodo tiene un
único power-domain se cumple `if (dev->pm_domain)` y se usa `devs[0]=dev`
con `pm_runtime_enable()`, ignorando los nombres "cx"/"mss" del
`proxy_pd_names`. El nodo usa exactamente un power-domain
`<&rpmpd SM6125_VDDCX>` sin `power-domain-names`, satisfaciendo esta rama.

## Elementos del parche 0002

| elemento | detalle |
|----------|---------|
| archivo | `arch/arm64/boot/dts/qcom/sm6125.dtsi` |
| nodo 1 | `smp2p-mpss` (top-level, `qcom,smp2p`, smem 435/428, GIC_SPI 70, mbox 14, pid 0→1, entries master-kernel/slave-kernel/wlan) |
| nodo 2 | `remoteproc_mpss: remoteproc@6080000` (`qcom,sm8150-mpss-pas`, reg 0x06080000, interrupts-extended wdog 307 + modem_smp2p_in 0/1/2/3/7, xo clock, `power-domains = <&rpmpd SM6125_VDDCX>`, `memory-region = <&modem_mem>`, smem-states stop, **status = "disabled"**) |
| subnodo | `glink-edge` (GIC_SPI 68, label "mpss", remote-pid 1, mbox 12) |
| enable board | NO — diferido a la fase de prueba física autorizada |

## Requisitos previos de árbol (todos presentes en el fork)

- `modem_mem` (0x4b000000 + 0x7e00000) ✓ (sm6125.dtsi:214)
- `wlan_msa_mem` (0x53300000 + 0x200000) ✓ (sm6125.dtsi:224)
- `rpmpd` `qcom,sm6125-rpmpd` con `SM6125_VDDCX` ✓ (sm6125.dtsi:306)
- `apcs_glb` mailbox@f111000 ✓ (sm6125.dtsi:644)
- `intc` interrupt-controller@f200000 ✓ (sm6125.dtsi:710)
- `rpmcc RPM_SMD_XO_CLK_SRC` ✓ (sm6125.dtsi:301)
- include `dt-bindings/interrupt-controller/arm-gic.h` ✓ (sm6125.dtsi:4)

## Validaciones estáticas realizadas

| check | resultado |
|-------|-----------|
| Balance de llaves (smp2p-mpss) | 0 |
| Balance de llaves (remoteproc@6080000) | 0 |
| Todos los labels referenciados resueltos | 0 missing (modem_mem, apcs_glb, rpmpd, rpmcc, intc, modem_smp2p_in/out) |
| Contexto del diff coincide con el dtsi original (hunks 361 y 715) | OK |
| Sin colisión con nodos remoteproc/smp2p preexistentes | OK (0 ocurrencias en orig) |
| WCN3990 v1 (0001, board) intacto | OK (parche solo toca sm6125.dtsi) |
| Indentación con tabs (sin espacios al inicio) | OK |
| Compatible PAS validado contra driver real | OK |
| Power-domain único (rama single-domain) | OK |

## Preservación del probe v1

El parche modifica solo `arch/arm64/boot/dts/qcom/sm6125.dtsi`; el nodo
`wifi@c800000` del board (0001) y el resto del árbol no cambian. Con
`remoteproc_mpss` en `disabled`, el MPSS no se inicia en boot: el probe
v1 WCN3990 (TrustZone, sin wifi-firmware child) se comporta igual que antes.

## Nota de licencia y autoría

Parche downstream-only, GPL-2.0 (kernel). Autor: `pmos-laurel-sprout
<dev@laurel.invalid>` (coherente con 0001). Origen: diseño v2
(`reports/linux61-wcn3990-v2-mpss-transport-design.md`).

## Pendiente (no bloqueante para build-ready)

- Validación de compilación real (dtc) y build del DTB se hará en CI (M13),
  no localmente (AGENTS.md §3: make/dtc completo solo en GitHub Actions).
- El enable del board (`&remoteproc_mpss { status = "okay"; }`) y la
  confirmación del board-id quedan para la fase de prueba física autorizada.
