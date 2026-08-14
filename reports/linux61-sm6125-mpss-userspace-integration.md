# Integración userspace MPSS/WCN3990 — Linux 6.1 (postmarketOS) — REVISIÓN M11

Estado: `source-available` (sin instalación ni ejecución)
Fecha: 2026-08-13 (revisión M11 con corrección de hipótesis M5)
Fork fijado: `sm6125-mainline/linux` @ `77de535b8dbd8f483b5802c8937cb714bab5b485`
(rama `v6.1-sm6125` verificada contra el commit fijado vía API GitLab)

---

## 1. Hallazgo crítico: el QRTR Name Service pertenece al kernel

### 1.1 Configuración real del kernel (artefactos y fork)

Los dos `.config` autoritativos del kernel 6.1 (local-private/kernel-final y
kernel-final2, SHA-256 idéntico `108d591400635c4f5122332733473e71706a513e1b154b1839a9df596f587a85`)
contienen:

| símbolo | valor |
|---|---|
| `CONFIG_QRTR` | `y` (built-in) |
| `CONFIG_QRTR_SMD` | `y` (built-in) |
| `CONFIG_QRTR_TUN` | `y` |
| `CONFIG_QRTR_MHI` | `m` |
| `CONFIG_QCOM_Q6V5_PAS` | `m` |
| `CONFIG_RPMSG_QCOM_GLINK_SMEM` | `y` |
| `CONFIG_QRTR_NS` | **no existe como símbolo** |

### 1.2 Evidencia de código (net/qrtr/ del fork fijado)

`net/qrtr/Kconfig` define solo QRTR / QRTR_SMD / QRTR_TUN / QRTR_MHI.
**No hay `config QRTR_NS`**: el Name Service no es opt-out, se construye
siempre con QRTR.

`net/qrtr/Makefile`:
```
obj-$(CONFIG_QRTR) += qrtr.o
qrtr-y	:= af_qrtr.o ns.o
```
→ `ns.o` se compila como parte de `qrtr.o`; con `CONFIG_QRTR=y` queda
**built-in** (no genera `qrtr-ns.ko`).

`net/qrtr/ns.c` (822 líneas, hash `a5abad26...`):
- `qrtr_ns_init()` (ns.c:758) crea socket en `QRTR_PORT_CTRL` (puerto 0),
  workqueue `qrtr_ns_handler`, y bind del puerto de control.
- `qrtr_ns_worker` (ns.c:661) procesa HELLO / BYE / DEL_CLIENT /
  NEW_SERVER / DEL_SERVER / NEW_LOOKUP / DEL_LOOKUP y distribuye
  NEW_SERVER/DEL_SERVER a los nodos.
- Exported: `qrtr_ns_init` / `qrtr_ns_remove` (EXPORT_SYMBOL_GPL).

`net/qrtr/af_qrtr.c` (1320 líneas, hash `a814bfeb...`):
- `qrtr_port_assign` (af_qrtr.c:725): bindear el puerto de control
  (`QRTR_PORT_CTRL`) desde userspace requiere `CAP_NET_ADMIN` y fallaría
  con `-EADDRINUSE` porque el kernel ya lo ocupa.
- `qrtr_proto_init` (af_qrtr.c:1284) llama `qrtr_ns_init()` en
  `postcore_initcall` (línea 1308) → el Name Service arranca durante el
  boot del kernel, sin daemon userspace.

`net/qrtr/smd.c` (el Makefile usa `qrtr-smd-y := smd.o`):
- match `{"IPCRTR"}` (smd.c:93), `MODULE_ALIAS("rpmsg:IPCRTR")`,
  `qrtr_endpoint_register(..., QRTR_EP_NID_AUTO)` → el endpoint GLINK
  IPCRTR se une al core QRTR automáticamente.

### 1.3 Upstream

El commit `0c2204a4ad71` — "net: qrtr: Migrate nameservice to kernel from
userspace" (Manivannan Sadhasivam, ciclo kernel 5.7, feb 2020) movió el NS
al kernel (net/qrtr/ns.c), motivado precisamente por eliminar la
dependencia de un daemon userspace para WiFi (ath11k). Aplicó a 5.7+ y por
tanto está presente en el fork 6.1 fijado. `qrtr-lookup` quedó como
herramienta de consulta (no es el Name Service).

### 1.4 Conclusión sobre qrtr-ns

- **No se necesita** daemon `qrtr-ns` userspace con el kernel 6.1 fijado.
- El paquete Alpine `qrtr` (aports master, pkgver 1.2, linux-msm) compila
  con `-Dqrtr-ns=disabled -Dsystemd-service=disabled`: solo instala los
  binarios `qrtr-cfg` y `qrtr-lookup` (consulta), **no** el daemon.
- Los init.d de pd-mapper/tqftpserv/rmtfs usan dependencias OpenRC
  **débiles** (`want`/`use qrtr-ns`), que NO exigen que el servicio exista.
- Por tanto: **NO crear paquete qrtr-ns, NO overlay, NO init.d qrtr-ns,
  NO parche a Alpine.**

## 2. Corrección de la hipótesis M5

| | contenido |
|---|---|
| **Hipótesis anterior (M5)** | `qrtr-ns` (daemon userspace) debía arrancar ANTES que el endpoint QRTR para registrar nodos/servicios; se listaba como paso 1 de la secuencia. |
| **Evidencia nueva** | El NS está en el kernel (net/qrtr/ns.c, built-in vía `CONFIG_QRTR=y`, `postcore_initcall`). No hay símbolo `CONFIG_QRTR_NS`. El daemon userspace es histórico/redundante. |
| **Comportamiento correcto** | El kernel (NS built-in) + endpoint qrtr-smd IPCRTR + MPSS up → los servicios QMI (SSCTL, WLFW) se anuncian vía NS del kernel. El daemon userspace solo estorbaría (no puede bindear QRTR_PORT_CTRL). |
| **Impacto en packaging** | Los paquetes `qrtr` (solo libs/herramientas), `pd-mapper`, `rmtfs`, `tqftpserv` se instalan sin depender de un daemon qrtr-ns. Los init.d ya usan dependencias débiles. |
| **Impacto en gate M11** | Gate se evalúa con el NS del kernel (ver §7). No requiere qrtr-ns userspace. |

## 3. Modelo de arranque corregido (M11)

```
Kernel:
  remoteproc MPSS (PAS) sube  ->  glink-edge (IPCRTR)
  -> qrtr-smd endpoint (IPCRTR) -> QRTR core -> kernel QRTR Name Service
  -> aparición de servicios QMI (SSCTL 43, WLFW) en QRTR

Userspace (según necesidad demostrada, sin qrtr-ns):
  rmtfs      (EFS/modem diag; init.d: before networkmanager/ofono/modemmanager,
              after udev-settle, use qrtr-ns)
  pd-mapper  (protección de dominios; init.d: want qrtr-ns)
  tqftpserv  (TFTP sobre AF_QIPCRTR; init.d: before rmtfs, use qrtr-ns)
```

`qrtr-lookup` se usa solo como herramienta de diagnóstico.

## 4. Paquetes Alpine (verificados en aports/pmaports master)

| paquete | repo/ruta | versión | licencia | binarios reales | función | deps |
|---------|-----------|---------|----------|-----------------|---------|------|
| `qrtr` | aports community | 1.2 | BSD-3-Clause | `qrtr-cfg`, `qrtr-lookup` (+libs `qrtr-libs`) | herramientas QRTR; **sin qrtr-ns** (`-Dqrtr-ns=disabled`) | linux-headers, meson |
| `pd-mapper` | aports testing | 1.1 | BSD-3-Clause | `/usr/bin/pd-mapper` + openrc/systemd | dominio de protección QMI | qrtr-dev, xz-dev |
| `tqftpserv` | aports community | 1.2 | BSD-3-Clause | `/usr/bin/tqftpserv` + openrc/systemd | TFTP sobre AF_QIPCRTR | qrtr-dev, zstd-dev |
| `rmtfs` | aports community | 1.3 | BSD-3-Clause | `/usr/bin/rmtfs` + openrc/systemd | EFS/modem (opción `-s` = sync mss rproc) | (checksum upstream) |
| `msm-modem` | pmaports community | 13 | GPL-3.0-or-later | `msm-modem-uim-selection`, `msm-modem-wwan-port` (+openrc/systemd) | UIM selection, wwan-port | uim: `rmtfs libqmi qmi-utils`; wwan: `rmtfs` |
| `soc-qcom-sm7125` | pmaports testing | 2 | BSD-3-Clause | metapaquete | ref más cercana al SM6125; `-nonfree-firmware` depende `msm-modem tqftpserv` | msm-modem-uim-selection, bootmac |

Notas:
- `soc-qcom-sm7125` v2 (pmaports, Nikroks) `-nonfree-firmware` depende de
  `msm-modem tqftpserv` (no pd-mapper/qrtr explícito; pd-mapper viene vía
  msm-modem chain). Es la referencia para crear el SM6125.
- `msm-modem-uim-selection` (dependencia base de `msm-modem`) trae
  `rmtfs libqmi qmi-utils`.
- El APKINDEX local (snapshot antiguo, 2022) mostraba qrtr 0.3 de
  andersson con `qrtr-ns` incluido; **eso quedó obsoleto** en aports
  master (qrtr 1.2 linux-msm, qrtr-ns deshabilitado). No usar ese
  snapshot como referencia.

## 5. Firmware y rutas (resumen M9+M10)

- `ath10k/WCN3990/hw1.0/firmware-5.bin` (60 B, genuino, NON_BMI) y
  `board-2.bin` — verificados (M9), en `local-private/`.
- `wlanmdsp.mbn` (ELF DSP6, 3.7 MB) — descargado (M9); se entrega vía
  QMI WLFW / tqftpserv, NO por el driver.
- `modem.mdt` + `modem.bXX` → `/lib/firmware/qcom/sm6125/` — pendiente
  de extracción autorizada (M10, script dry-run listo; modem.mdt sigue
  `unavailable/unextracted`).

## 6. Preguntas M5 revisadas (respuestas con evidencia nueva)

1. ¿qrtr-ns daemon necesario? **NO** (NS en kernel, commit 5.7+).
2. ¿qrtr-ns en paquete Alpine? **NO** (`-Dqrtr-ns=disabled`); no instala.
3. ¿qrtr-lookup es el NS? **NO**, es herramienta de consulta.
4. ¿qrtr-ns genera .ko? **NO**, queda built-in (`qrtr-y := af_qrtr.o ns.o`).
5. ¿quién ocupa QRTR_PORT_CTRL? El kernel (ns.c, bind en qrtr_ns_init).
6. ¿cómo se distribuyen NEW/DEL_SERVER? Kernel NS (qrtr_ns_worker).
7. ¿el kernel 6.1 necesita daemon para servicios remotos? **NO**.
8. ¿endpoint IPCRTR? `net/qrtr/smd.c` match `{"IPCRTR"}` (build de QRTR_SMD=y).
9. ¿PD-mapper sin qrtr-ns? Sí, init.d usa `want qrtr-ns` (no `need`).
10. ¿tqftpserv/rmtfs? `use`/`before` débiles; no requieren qrtr-ns.

## 7. Gate M11 (revisado)

PASS si:
- `CONFIG_QRTR=y` (built-in) — **CUMPLE** (`=y`).
- `CONFIG_QRTR_SMD=y` — **CUMPLE** (`=y`).
- `net/qrtr/ns.c` construido — **CUMPLE** (`qrtr-y := af_qrtr.o ns.o`, built-in).
- NS pertenece al kernel — **CUMPLE** (postcore_initcall → qrtr_ns_init).
- Paquetes userspace identificados y empaquetables — **CUMPLE** (qrtr-libs,
  pd-mapper 1.1, rmtfs 1.3, tqftpserv 1.2, msm-modem 13).
- No se introduce daemon qrtr-ns redundante — **CUMPLE** (no se crea).

**Veredicto gate M11: PASS.** La cadena userspace requiere rmtfs,
pd-mapper, tqftpserv (y msm-modem) pero NO qrtr-ns. El NS del kernel
6.1 fijado lo cubre.

## 8. Pendientes / riesgos

- `pd-mapper` 1.1 en aports **testing** (no community): necesario mover o
  usar el paquete de testing en el APKBUILD del SM6125.
- reglas pd-mapper para SM6125: verificar si la lista embebida cubre
  SM6125 o requiere entrada propia (pendiente de evidencia upstream).
- `rmtfs` necesita EFS/particiones (modemst); es condición del modem UIM,
  no del WCN3990.
- Nada se instala ni se ejecuta en esta misión; todo queda documentado.
- Los binarios de firmware permanecen SOLO en local-private.

## 9. Nota: metapaquete soc-qcom-sm6125 (decisión)

La misión pedía crear `packaging/pmaports/soc-qcom-sm6125/` "si aplica".
**Decisión: no crear, documentar.** Los paquetes userspace requeridos ya
existen en aports (qrtr-libs, pd-mapper 1.1, rmtfs 1.3, tqftpserv 1.2) y
pmaports (msm-modem 13, soc-qcom-sm7125 v2 como referencia directa).
Crear un `soc-qcom-sm6125` propio duplicaría el metapaquete sin aportar
divergencia demostrada. La instalación se hará con los paquetes
existentes, fijando versiones en el futuro rootfs (posterior a la
autorización de prueba). Si en el futuro se necesitara un `-nonfree-firmware`
específico del SM6125, se modelará sobre `soc-qcom-sm7125-nonfree-firmware`
(que ya depende de `msm-modem tqftpserv`).

## Fuentes

- `local-private/kernel-final/kernel.config`, `kernel-final2/kernel.config` (SHA-256 `108d5914...`)
- `local-private/diagnostics/wifi-priority/wcn3990-v2-build-ready/kernel-net-qrtr/` (Kconfig, Makefile, ns.c, af_qrtr.c, smd.c, qrtr.h — hashes en §1.2)
- GitLab API: rama v6.1-sm6125 = commit `77de535b8dbd8f483b5802c8937cb714bab5b485`
- aports master: qrtr 1.2 (qrtr-ns=disabled), pd-mapper 1.1 (testing), tqftpserv 1.2, rmtfs 1.3
- pmaports: soc-qcom-sm7125 v2 (testing), msm-modem 13 (community)
- upstream: commit `0c2204a4ad71` (net/qrtr: Migrate nameservice to kernel)
- reportes M5/M9/M10 previos (secuencia corregida aquí)
