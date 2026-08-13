# Diff semántico DT — MPSS para laurel_sprout (Linux 6.1)

Fecha: 2026-08-13. Comparación en 6 áreas entre:
1. `sm6125.dtsi` del fork fijado (idéntico a `ref-sm6125.dtsi`, commit
   `77de535b`)
2. `trinket.dtsi` vendor (LineageOS SM6125, `icnss`/`pil_modem`)
3. `qcm2290.dtsi` torvalds v6.6 (referencia mainline MPSS-PAS)
4. DTB v1 instalada (parche `0001-dts-laurel-wcn3990-first-probe`)

Evidencia privada: `local-private/diagnostics/wifi-priority/mpss-risk-audit/dts-semantic-diff/`.

## Área 1 — Nodo remoteproc MPSS (PAS)

| aspecto | fork 6.1 sm6125.dtsi | QCM2290 v6.6 | vendor trinket |
|---------|---------------------|--------------|----------------|
| nodo | **AUSENTE** | `remoteproc_mpss: remoteproc@6080000` | `pil_modem: qcom,mss@6080000` |
| compatible | — | `qcom,qcm2290-mpss-pas`, `qcom,sm6115-mpss-pas` | `qcom,pil-tz-generic` |
| reg | — | `<0 0x06080000 0 0x100>` | `<0x6080000 0x100>` |
| clocks | — | `rpmcc RPM_SMD_XO_CLK_SRC` ("xo") | `CXO_SMD_PIL_MSS_CLK` ("xo") |
| power-domains | — | `<&rpmpd QCM2290_VDDCX>` (single) | `vdd_cx-supply = <&VDD_CX_LEVEL>` |
| memory-region | `modem_mem` ya existe | `pil_modem_mem` | `pil_modem_mem` |
| qcom,smem-states | — | `<&modem_smp2p_out 0>` "stop" | `modem_smp2p_out 0` "force-stop" |

**GAP v2**: añadir nodo `remoteproc@6080000` completo en `sm6125.dtsi` con
valores SM6125 (reg 0x06080000, IRQ wdog GIC_SPI 307, power-domain
`<&rpmpd SM6125_VDDCX>`, memory-region `&modem_mem`).

## Área 2 — IRQs del q6v5 (fatal/ready/handover/stop/shutdown)

El driver `qcom_q6v5_init` (fork) requiere por nombre: `wdog`, `fatal`,
`ready`, `handover`, `stop-ack`, `shutdown-ack`. Estos provienen de los
bits 0,2,1,3,7 de `modem_smp2p_in`.

| IRQ | QCM2290 v6.6 | vendor trinket |
|-----|--------------|----------------|
| wdog | GIC_SPI 307 | wakegic 0 307 |
| fatal | smp2p bit 0 | smp2p bit 0 |
| ready | smp2p bit 1 | smp2p bit 1 |
| handover | smp2p bit 2 | smp2p bit 2 |
| stop-ack | smp2p bit 3 | smp2p bit 3 |
| shutdown-ack | smp2p bit 7 | smp2p bit 7 |

Los bits coinciden. **GAP v2**: requiere el nodo `smp2p-mpss` con
`modem_smp2p_in` (área 4).

## Área 3 — GLINK edge (canal IPCRTR)

| aspecto | QCM2290 v6.6 | vendor trinket | fork 6.1 |
|---------|--------------|----------------|----------|
| forma | subnode `glink-edge` dentro de remoteproc_mpss | nodo global `glink_modem` | ausente |
| IRQ | GIC_SPI 68 | GIC_SPI 68 | — |
| mbox | apcs_glb 12 | apcs_glb 12 | — |
| remote-pid | 1 | 1 | — |
| label | "mpss" | "modem"/glink-label "mpss" | — |
| canal | dinámico (IPCRTR por firmware) | `qcom,modem_qrtr` "IPCRTR" explícito | — |

El fork usa el modelo subnode `glink-edge` (qcom_common.c:
`of_get_child_by_name(dev->parent->of_node, "glink-edge")`), igual que
QCM2290. El vendor usa el modelo global (no aplicable). **GAP v2**: añadir
subnode `glink-edge` dentro del remoteproc.

## Área 4 — SMP2P modem (master/slave-kernel + wlan)

| aspecto | QCM2290 v6.6 | vendor trinket | fork 6.1 |
|---------|--------------|----------------|----------|
| compatible | qcom,smp2p | qcom,smp2p | ausente |
| qcom,smem | <435>,<428> | <435>,<428> | — |
| IRQ | GIC_SPI 70 | GIC_SPI 70 | — |
| mbox | apcs_glb 14 | apcs_glb 14 | — |
| remote-pid | 1 | 1 | — |
| master-kernel | "master-kernel" | "master-kernel" | — |
| slave-kernel | "slave-kernel" | "slave-kernel" | — |
| wlan entry | `wlan_smp2p_in` "wlan" | `smp2p_wlan_1_in` "wlan" | — |

**GAP v2**: añadir `smp2p-mpss` (SM6125) con los 3 entries. El entry "wlan"
(`wlan_smp2p_in`) es el que el vendor usa para las IRQs de crash del
icnss/wifi (bits 0 y 1). En el fork, el ath10k_snoc no usa este smp2p
(usa QMI), pero el subnode es requerido por q6v5 (fatal/ready/...) y por
consistencia con QCM2290.

## Área 5 — Power-domains (rpmpd)

| aspecto | fork 6.1 sm6125.dtsi | QCM2290 v6.6 |
|---------|---------------------|--------------|
| rpmpd | `rpmpd: power-controller` compatible `qcom,sm6125-rpmpd`, `#power-domain-cells = <1>` | `qcom,qcm2290-rpmpd` |
| VDDCX id | `SM6125_VDDCX = 0` (header fork ya presente) | `QCM2290_VDDCX` |
| dominios expuestos | vddcx, vddcx_ao, vddcx_vfl, vddmx, ... | vddcx, vddmx, vdd_lpi_* |
| uso existente | GPU y CDSP ya usan `<&rpmpd SM6125_VDDCX>` (líneas 472, 500) | mpss usa `<&rpmpd QCM2290_VDDCX>` |

**Sin GAP**: el rpmpd sm6125 y su header ya existen en el fork. La v2 solo
debe referenciar `<&rpmpd SM6125_VDDCX>` en el nodo mpss.

## Área 6 — Memory regions y Wi-Fi node

| aspecto | fork 6.1 sm6125.dtsi | QCM2290 v6.6 | vendor trinket | DTB v1 |
|---------|---------------------|--------------|----------------|--------|
| modem_mem | `modem_mem @4b000000 +0x7e00000` ✓ | pil_modem 0x4ab00000+0x6900000 | pil_modem 0x4b000000+0x7e00000 | — |
| wlan_msa_mem | `wlan_msa_mem @53300000 +0x200000` ✓ | 0x51900000+0x100000 | 0x53300000+0x200000 | ✓ (usado) |
| wifi nodo | ausente (lo añade el parche v1 en board file) | `wifi: wifi@c800000` (disabled) | `icnss: qcom,icnss@C800000` | `wifi@c800000` (parche v1, okay) |
| wifi IRQ | — | GIC_SPI 358-369 | 358-369 | 358-369 ✓ |
| wifi iommus | — | `<&apps_smmu 0x1a0 0x1>` | `<&apps_smmu 0x80 0x1>` | sin iommus (use_tz) |
| wifi reg | — | `<0 0x0c800000 0 0x800000>` | `<0xC800000 0x800000>` | `<0x0c800000 0x800000>` ✓ |

**GAP parcial v2**: `modem_mem` y `wlan_msa_mem` ya están en el árbol
fijado. El nodo wifi ya existe en la DTB v1 (use_tz, sin iommus). Para MPSS
solo falta referenciar `modem_mem` desde el remoteproc.

## Divergencias detectadas

1. **SID iommus del wifi**: mainline QCM2290 usa SID 0x1a0; vendor SM6125
   usa 0x80. El fork no tiene `apps_smmu` → la v1 usa la ruta TrustZone
   (sin iommus). Para MPSS esto NO bloquea (el MPSS no usa el SID wifi).
2. **modelo glink**: fork/QCM2290 usan subnode `glink-edge`; vendor usa
   glink global. La v2 debe usar el modelo subnode.
3. **smem-state name**: QCM2290 usa "stop"; vendor usa "force-stop". El
   driver del fork (`devm_qcom_smem_state_get(dev, "stop")`) exige el
   nombre "stop".
4. **firmware del modem**: vendor usa "modem"; el driver PAS del fork
   espera `modem.mdt` con `pas_id=4` → compatible.

## Conclusión M3

Todo el andamiaje DT requerido por el driver PAS del fork (IRQ wdog,
smp2p-mpss con wlan, glink-edge, power-domain único SM6125_VDDCX,
memory-region modem_mem) está ausente en el árbol fijado pero modelado
fielmente en QCM2290 v6.6 y en el vendor trinket, con coincidencia total de
IRQ/mbox/smem/remote-pid. La v2 del DT para laurel_sprout debe replicar el
modelo QCM2290 con valores SM6125.

## Fuentes

- `sm6125.dtsi` (fork, idéntico a ref-sm6125.dtsi) y
  `sm6125-xiaomi-laurel_sprout.dts` descargados a
  `local-private/diagnostics/wifi-priority/mpss-risk-audit/dts-semantic-diff/`
- `vendor-scratch/trinket.dtsi` (LineageOS)
- `qcm2290.dtsi` v6.6 (torvalds)
- `patches/kernel-61/0001-dts-laurel-wcn3990-first-probe.patch`
