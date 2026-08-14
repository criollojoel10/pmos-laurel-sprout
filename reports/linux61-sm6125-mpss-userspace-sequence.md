# Secuencia userspace MPSS/WCN3990 — Linux 6.1 (postmarketOS)

Fecha: 2026-08-13. Cadena de servicios necesarios tras subir la MPSS por
remoteproc para que la WCN3990 reciba QMI WLFW. Evidencia de paquetes Alpine
descargada en `local-private/diagnostics/wifi-priority/mpss-risk-audit/`.

## Orden de arranque requerido

> **CORRECCIÓN (M11, 2026-08-13):** este reporte original (M5) asumía que
> `qrtr-ns` (daemon userspace) debía arrancar primero. La revisión M11
> demostró que el QRTR Name Service vive en el kernel (net/qrtr/ns.c,
> built-in con CONFIG_QRTR=y, postcore_initcall) y NO se necesita daemon
> userspace. Ver sección "Corrección de la hipótesis M5" abajo.

```
Kernel:
  remoteproc MPSS sube (con modem.mdt) -> glink-edge IPCRTR
  -> qrtr-smd endpoint (IPCRTR) -> QRTR core -> kernel QRTR Name Service
  -> servicios QMI (SSCTL 43, WLFW) anunciados por el NS del kernel

Userspace (sin qrtr-ns):
  rmtfs      (EFS/modem diag vía QRTR; init.d: after udev-settle)
  pd-mapper  (dominios de protección; init.d: want qrtr-ns, débil)
  tqftpserv  (firmware extra al modem por AF_QIPCRTR, si aplica)
  ath10k QMI client -> WLFW server -> FW_READY -> wlan0
```

En la práctica el kernel sube la MPSS y crea el nodo QRTR; el NS del kernel
registra los servicios SSCTL y WLFW sin daemon userspace. `pd-mapper` se
requiere para que el subsistema tenga sus dominios. `rmtfs` es condición
para el funcionamiento correcto del modem (UIM/EFS).

## Paquetes Alpine (verificados en aports/pmaports)

| paquete | repo/ruta | versión | licencia | función | origen |
|---------|-----------|---------|----------|---------|--------|
| `qrtr` | aports (community) | 1.2 | BSD-3-Clause | `qrtr-cfg`, `qrtr-lookup` + libs (sin qrtr-ns; NS en kernel) | linux-msm/qrtr |
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

> **Corregidas por M11** (ver sección "Corrección de la hipótesis M5" abajo):
> el Name Service QRTR está en el kernel (net/qrtr/ns.c, built-in), por lo
> que NO se necesita el daemon userspace `qrtr-ns`.

1. **¿qrtr-ns daemon presente/necesario?** NO es necesario (NS en kernel);
   el paquete `qrtr` de aports (1.2) no incluye el binario (compila con
   `-Dqrtr-ns=disabled`); instala solo `qrtr-cfg` y `qrtr-lookup`.
2. **¿pd-mapper presente?** NO en el rootfs; `pd-mapper` en aports/testing
   (1.1, BSD-3-Clause).
3. **¿rmtfs presente?** NO en el rootfs; dependencia de
   `msm-modem-uim-selection` (rmtfs/libqmi/qmi-utils).
4. **¿tqftpserv presente?** NO en el rootfs; en aports/community (1.2,
   BSD-3-Clause); depende de `qrtr-dev` para compilar.
5. **¿el kernel ya crea el nodo QRTR?** `CONFIG_QRTR=y` y `CONFIG_QRTR_SMD=y`
   están en la config 6.1 (built-in, no =m); pero sin MPSS up no hay
   endpoint IPCRTR → no hay nodo.
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
     (con dependencias débiles `want`/`use`) es responsabilidad del init.
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

## Corrección de la hipótesis M5

**Fecha: 2026-08-13 (revisión M11).** Este reporte original de la fase M5
afirmaba que `qrtr-ns` (daemon userspace) debía arrancar ANTES del endpoint
QRTR. La revisión M11 corrige esa hipótesis con evidencia de código.

- **Hipótesis anterior**: qrtr-ns userspace como paso 1 de la secuencia.
- **Evidencia nueva**:
  - `CONFIG_QRTR=y` y `CONFIG_QRTR_SMD=y` en los .config autoritativos
    (kernel-final / kernel-final2, SHA-256 `108d5914...`).
  - `net/qrtr/Makefile`: `qrtr-y := af_qrtr.o ns.o` → ns.c se compila
    siempre con QRTR; **no existe `CONFIG_QRTR_NS`** en el Kconfig del fork.
  - `net/qrtr/ns.c`: el Name Service del kernel ocupa `QRTR_PORT_CTRL`,
    procesa HELLO/NEW_SERVER/DEL_SERVER; `qrtr_ns_init()` se invoca desde
    `postcore_initcall(qrtr_proto_init)` → built-in, no módulo.
  - Upstream: commit `0c2204a4ad71` (kernel 5.7, feb 2020) migró el NS al
    kernel para eliminar la dependencia del daemon userspace en WiFi.
  - Paquete Alpine `qrtr` 1.2 compila con `-Dqrtr-ns=disabled`; los init.d
    de pd-mapper/tqftpserv/rmtfs usan dependencias débiles `want`/`use`.
- **Comportamiento correcto**: el NS del kernel + endpoint IPCRTR
  (qrtr-smd) + MPSS up anuncian los servicios QMI; no hace falta qrtr-ns.
- **Impacto en packaging**: no se crea paquete/overlay/init.d para
  qrtr-ns; se instalan rmtfs, pd-mapper, tqftpserv (y msm-modem para UIM).
- **Impacto en gate M11**: PASS con el NS del kernel; ver
  `reports/linux61-sm6125-mpss-userspace-integration.md` (§7).

Detalle completo en el reporte de integración M11 y en
`local-private/diagnostics/wifi-priority/wcn3990-v2-build-ready/userspace-matrix.md`.

## Fuentes

- `local-private/diagnostics/wifi-priority/mpss-risk-audit/{qrtr,pd-mapper,tqftpserv,msm-modem,soc-qcom-sm7125}.APKBUILD`
- `local-private/research-tree/pmaports-main.jsonl` (soc-qcom subpackages)
- `local-private/linux61-baseline-31563265029/rootfs-manifest.json`
- `local-private/diagnostics/wifi-priority/baseline-before-wifi-20260812T131500Z/v61-health/{remoteproc.txt,firmware.txt,uname.txt}`
