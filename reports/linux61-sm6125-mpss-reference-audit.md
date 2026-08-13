# Referencia mainline MPSS — Linux 6.1 para SM6125

Fecha: 2026-08-13. Misión de auditoría de requisitos MPSS previa a la v2 de
WCN3990. Evidencia privada en
`local-private/diagnostics/wifi-priority/mpss-risk-audit/`.

## Resultado

**REFERENCIA FUNCIONAL IDENTIFICADA: QCM2290 (y `qcom,sm6115-mpss-pas` en
mainline v6.6).**

La familia die SM6115/SM6125 comparte la arquitectura MPSS-PAS con
glink-edge, smp2p-mpss (con entry `wlan`) y Wi-Fi WCN3990. El layout del
nodo `remoteproc_mpss` mainline coincide con el vendor trinket.dtsi de
SM6125 en IRQ, mbox, smem y remote-pid. Esta es la referencia que la v2
debe replicar; no se declara `working`: el MPSS no está activado en
ninguna plataforma mainline validada públicamente.

## Hallazgo principal de diseño

El fork fijado (`sm6125-mainline/linux` v6.1) **no incluye**
`qcom,sm6115-mpss-pas` ni `qcom,sm6125-mpss-pas`; el primero fue añadido a
mainline en v6.3. Los compatibles MPSS-PAS disponibles en el fork son
sc7180/sc7280/sc8180x/sdx55/sm6350/sm8150/sm8350/sm8450. La v2 deberá
elegir entre usar `qcom,sm8150-mpss-pas` (o sc7180) — cuyos parámetros
(pas_id 4, smem 421, minidump 3, firmware `modem.mdt`, ssctl 0x12)
coinciden con el vendor trinket — o añadir un parche downstream con
`qcom,sm6125-mpss-pas`.

## Tabla de referencia

| elemento | QCM2290 v6.6 (torvalds) | vendor trinket SM6125 | fork 6.1 sm6125.dtsi |
|----------|------------------------|----------------------|----------------------|
| remoteproc reg | 0x06080000 | 0x06080000 | ausente |
| wdog | GIC_SPI 307 | GIC_SPI 307 | — |
| glink-edge IRQ / mbox | GIC_SPI 68 / apcs_glb 12 | GIC_SPI 68 / apcs_glb 12 | — |
| smp2p-mpss smem / IRQ / mbox | <435>,<428> / 70 / 14 | <435>,<428> / 70 / 14 | — |
| remote-pid | 1 | 1 | — |
| entry wlan | "wlan" | "wlan" | — |
| pil_modem | 0x4ab00000+0x6900000 | 0x4b000000+0x7e00000 | modem_mem 0x4b000000+0x7e00000 |
| wlan_msa | 0x51900000+0x100000 | 0x53300000+0x200000 | wlan_msa_mem 0x53300000+0x200000 |
| wifi iommus SID | 0x1a0 | 0x80 (divergente) | sin iommus |

Las regiones `modem_mem` y `wlan_msa_mem` ya existen en el árbol fijado con
los mismos offsets que el vendor trinket, por lo que no se requieren
cambios de reserva de memoria para la v2.

## Power-domains (crítico)

`adsp_pds_attach` del driver PAS del fork solo usa `proxy_pd_names`
("cx"/"mss") si el dispositivo no tiene un único power-domain adjunto
(`dev->pm_domain`). El rpmpd sm6125 del fork expone dominios llamados
`vddcx`/`vddmx` (no "cx"/"mss"). Por tanto la v2 debe declarar un único
`power-domains = <&rpmpd SM6125_VDDCX>` (sin `power-domain-names`),
activando la rama single-domain que ignora los nombres — exactamente como
hace QCM2290 v6.6.

## Cadena MPSS → WCN3990 (verificada contra el código del fork)

```
rproc_mpss (PAS) start
 ├─ qcom_q6v5 (IRQ wdog/fatal/ready/handover/stop-ack + smem-state "stop")
 ├─ qcom_mdt_load (modem.mdt → modem_mem)
 ├─ qcom_q6v5_pas (auth, pas_id 4)
 ├─ glink-subdev → edge "mpss" (IPCRTR)
 ├─ smp2p-mpss (master/slave-kernel + wlan)
 └─ sysmon-subdev → QMI SSCTL (service 43)
        ▼
qrtr-smd (canal "IPCRTR") → QRTR core
        ▼
ath10k_qmi → kernel_connect AF_QIPCRTR (WLFW server)
        ▼
FW_READY → ATH10K_QMI_EVENT_FW_READY_IND → ath10k_core_register
```

## Firmware requerido (M4)

`/lib/firmware/qcom/sm6125/modem.mdt` + segmentos `.b0X` (MPSS propietario
no redistribuible), y firmware `ath10k/WCN3990/hw1.0/*`. Sin `modem.mdt`
legítimo no se puede subir MPSS.

## Fuentes

- `local-private/diagnostics/wifi-priority/mpss-risk-audit/reference-candidates.md`
- `qcm2290.dtsi` y `qcom_q6v5_pas.c` de torvalds v6.6 (raw.githubusercontent)
- `qcom_q6v5.c`, `qcom_q6v5_pas.c`, `qcom_common.c`, `qcom_sysmon.c`,
  `mdt_loader.c`, `smp2p.c`, `smem.c`, `smem_state.c`,
  `qcom_glink_*.c`, `rpmpd.c` del fork `sm6125-mainline/linux`
  v6.1-sm6125 (raw.gitlab.com), hashes en `kernel-driver-hashes.txt`
- LineageOS `android_kernel_xiaomi_sm6125`, `trinket.dtsi`
- `patches/kernel-61/0001-dts-laurel-wcn3990-first-probe.patch`
- `sm6125-mainline/linux` @ `77de535b8dbd8f483b5802c8937cb714bab5b485`
