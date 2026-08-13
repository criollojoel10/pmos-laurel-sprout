# Secuencia userspace MPSS/WCN3990 — Linux 6.1 (postmarketOS)

Fecha: 2026-08-13. Cadena de servicios necesarios tras subir la MPSS por
remoteproc para que la WCN3990 reciba QMI WLFW. Evidencia de paquetes Alpine
descargada en `local-private/diagnostics/wifi-priority/mpss-risk-audit/`.

## Orden de arranque requerido

```
1. qrtr-ns        (registro de nodos del bus QRTR)
2. rmtfs          (provee EFS/modem diag vía QRTR; requerido por el modem)
3. pd-mapper      (mapea dominios de protección; requerido por QMI)
4. remoteproc MPSS sube (kernel, con modem.mdt)
5. tqftpserv      (provee firmware extra al modem por AF_QIPCRTR, si aplica)
6. ath10k QMI client -> WLFW server -> FW_READY -> wlan0
```

En la práctica el kernel sube la MPSS y crea el nodo QRTR; `qrtr-ns` debe
estar corriendo ANTES para registrar el servicio SSCTL y WLFW. `pd-mapper`
se requiere para que el subsistema tenga sus dominios. `rmtfs` es condición
para el funcionamiento correcto del modem (UIM/EFS).

## Paquetes Alpine (verificados en aports/pmaports)

| paquete | repo/ruta | versión | licencia | función | origen |
|---------|-----------|---------|----------|---------|--------|
| `qrtr` | aports (community) | 1.2 | BSD-3-Clause | qrtr-ns (node registrar) + libs | linux-msm/qrtr |
| `pd-mapper` | aports (testing) | 1.1 | BSD-3-Clause | proteccion-domain mapper | linux-msm/pd-mapper |
| `tqftpserv` | aports (community) | 1.2 | BSD-3-Clause | TFTP sobre AF_QIPCRTR | linux-msm/tqftpserv |
| `msm-modem` | pmaports (community) | 13 | GPL-3.0-or-later | soporte modem (uim-selection, wwan-port) | postmarketOS/msm-modem |
| `msm-modem-uim-selection` | subpkg | — | GPL-3.0-or-later | depende `rmtfs libqmi qmi-utils` | — |
| `soc-qcom` | pmaports (community) | — | — | metapaquete SoC con subpkgs modem/pd-mapper | — |
| `soc-qcom-sm7125` | pmaports (testing) | 1.0 | BSD-3-Clause | `-nonfree-firmware` depende `msm-modem pd-mapper tqftpserv` | — |

NOTA: `soc-qcom-sm7125-nonfree-firmware` es la referencia más cercana al
SM6125 y depende exactamente de `msm-modem pd-mapper tqftpserv`, validando
la cadena para esta familia die.

## Estado en el rootfs actual del dispositivo

El `rootfs-manifest.json` del baseline (run 31355730519) **no incluye**
qrtr, pd-mapper, tqftpserv, rmtfs, ni paquetes soc-qcom/msm-modem. El
remoteproc.txt del health report confirma `/sys/class/remoteproc` vacío y
`remoteproc: command failed`. → la cadena userspace está **ausente** en el
rootfs instalado.

## Respuestas a las 12 preguntas clave de M5

1. **¿qrtr-ns presente?** NO en el rootfs; disponible como paquete `qrtr`
   de aports (1.2, BSD-3-Clause).
2. **¿pd-mapper presente?** NO en el rootfs; `pd-mapper` en aports/testing
   (1.1, BSD-3-Clause).
3. **¿rmtfs presente?** NO en el rootfs; dependencia de
   `msm-modem-uim-selection` (rmtfs/libqmi/qmi-utils).
4. **¿tqftpserv presente?** NO en el rootfs; en aports/community (1.2,
   BSD-3-Clause); depende de `qrtr-dev` para compilar.
5. **¿el kernel ya crea el nodo QRTR?** El módulo QRTR_SMD=m y QRTR=m están
   en la config 6.1; pero sin MPSS up no hay endpoint IPCRTR → no hay nodo.
6. **¿quién sube la MPSS?** El kernel vía remoteproc PAS; en la v2 el DT
   debe declarar el nodo. Sin autorización no se inicia (`rproc start`).
7. **¿el SSCTL service (43) se registra solo?** Sí, el sysmon del kernel lo
   anuncia vía QMI al subir el remoteproc; requiere QRTR funcional.
8. **¿el WLFW service (QMI) proviene del modem?** Sí, del firmware MPSS;
   por eso MPSS debe estar up ANTES que ath10k intente connect.
9. **¿firmware del modem en /lib/firmware/qcom/sm6125/?** NO; ausente
   (ver M4). Es condición bloqueante.
10. **¿firmware ath10k WCN3990 instalado?** NO; solo stub de 60 B y
    board-2.bin sin instalar (ver M4).
11. **¿orden de servicios manejado por OpenRC/systemd?** postmarketOS usa
    OpenRC; los paquetes traen `.initd`/`-openrc`. El orden rmtfs→pd-mapper
    →qrtr-ns es responsabilidad del init.
12. **¿riesgo de romper servicios actuales?** No aplicar nada en esta
    misión; la v2 define la instrumentación y los gates.

## Riesgos de la cadena userspace

- **PD-mapper y firmware**: sin las reglas de pd-mapper para SM6125 (JSON
  con dominios), el QMI puede fallar. pd-mapper 1.1 usa la lista embebida;
  SM6125 puede requerir entrada propia (falta verificar upstream).
- **rmtfs**: necesita el repo rmtfs `libqmi`/`qmi-utils` y acceso al EFS;
  el SM6125 usa modemst1/2 (ver particiones). Sin rmtfs el modem puede no
  responder UIM pero el WCN3990 QMI podría aún arrancar.
- **tqftpserv**: solo necesario si el modem pide firmware adicional por
  TFTP; en WCN3990 normalmente no es obligatorio, pero es dependencia del
  port de referencia sm7125.
- **Nada de esto se instala ni se ejecuta en esta misión.**

## Conclusión M5

La cadena userspace completa está disponible en el ecosistema Alpine
(qrtr, pd-mapper, tqftpserv, msm-modem, soc-qcom), pero **ninguno está
instalado** en el rootfs actual y **el firmware modem.mdt falta**. La v2
requeriría: instalar `soc-qcom` (o paquetes individuales), colocar
firmware, y definir el orden de servicios — todo pendiente de autorización
de prueba física.

## Fuentes

- `local-private/diagnostics/wifi-priority/mpss-risk-audit/{qrtr,pd-mapper,tqftpserv,msm-modem,soc-qcom-sm7125}.APKBUILD`
- `local-private/research-tree/pmaports-main.jsonl` (soc-qcom subpackages)
- `local-private/linux61-baseline-31563265029/rootfs-manifest.json`
- `local-private/diagnostics/wifi-priority/baseline-before-wifi-20260812T131500Z/v61-health/{remoteproc.txt,firmware.txt,uname.txt}`
