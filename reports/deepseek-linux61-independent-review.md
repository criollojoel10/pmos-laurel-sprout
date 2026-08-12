# Revisión independiente DeepSeek — Baseline Linux 6.1

Fecha: 2026-08-12. Revisión inicial de SOLO LECTURA sobre el baseline Linux 6.1
generado por Luna (`16adaf8`..`d1d44a1`). No se modificó ningún archivo del
dispositivo; no se ejecutó Fastboot; no se escribió ninguna partición; no se
cambió el teléfono.

## Alcance y método

- Revisión binaria: se extrajeron kernel, ramdisk y segundo payload de los
  boot.img locales y se compararon los hashes entre el boot físico probado y el
  empaquetado en el baseline.
- Config: `local-private/diagnostics/ssh-live/kernel-6.1.config` (config del
  kernel 6.1 en ejecución, capturada por SSH en 2026-08-11).
- Evidencia física: `reports/linux-61-*`, `reports/physical-tests/*`,
  `local-private/diagnostics/ssh-live/`, `wcn-audit/`.
- Workflows: se buscaron comandos destructivos.
- Artefactos: `local-private/linux61-baseline-31563265029/` y preflight FASE 8.

## Resumen ejecutivo

El baseline seleccionado corresponde al kernel 6.1 más funcional del que hay
evidencia (6.1.0-sm6125 @77de535b). La composición es coherente: el boot
empaquetado y el rootfs provienen del mismo run `31355730519`. La separación
entre el boot físico probado y el boot empaquetado está correctamente
documentada. SSH root por RNDIS está demostrado físicamente en el dispositivo.

Sin embargo, el baseline NO es reproducible como "working": es
`packaged/static-validation-passed/boot-untested`. Se detectan tres hallazgos
sustantivos: (1) pstore/ramoops no está habilitado en la config 6.1, lo que
invalida un criterio de aceptación del propio preflight; (2) la ruta del rootfs
en el preflight no existe; (3) el kernel del baseline no es byte-idéntico al
kernel físicamente probado (difiere 53 bytes de banner), aunque sea el mismo
fork y config.

## Hallazgos

### CRÍTICO

**H-C1 — pstore/ramoops no recuperable en el kernel 6.1 empaquetado**

- Archivo: `local-private/diagnostics/ssh-live/kernel-6.1.config`
- Líneas: `CONFIG_PSTORE=y` pero `# CONFIG_PSTORE_RAM is not set`,
  `# CONFIG_PSTORE_CONSOLE is not set`, `# CONFIG_PSTORE_PMSG is not set`,
  `# CONFIG_PSTORE_BLK is not set`; únicamente `CONFIG_EFI_VARS_PSTORE=y`.
- Evidencia: config del kernel 6.1 que arrancó el dispositivo (capturada por
  SSH, `root-full-...`). El kernel del baseline se construye con el mismo
  APKBUILD/config pmaports (`77de535b` + config `08bcee71…`) en el mismo
  proyecto; `PSTORE_RAM` tampoco está en esa config.
- Impacto: sin `PSTORE_RAM` no existe ramoops y no hay `/sys/fs/pstore` con
  registros de console/pmsg. La recuperación post-crash/reboot no es posible.
- Invalida declaración working: sí, el criterio "pstore ... recuperables" del
  preflight (`docs/FASE8-PREFLIGHT-LINUX61-BASELINE.md:71`) no es alcanzable.
- Corrección mínima: añadir `CONFIG_PSTORE_RAM=y` al fragmento de build del
  kernel 6.1 y reconstruir el boot; o documentar que pstore queda para 7.1.
- Requiere rebuild: sí (para que pstore sea utilizable).
- Requiere prueba física: no (cambia solo el kernel empaquetado; la prueba
  física seguiría siendo necesaria para cualquier imagen).
- Puede esperar a 7.1: la decisión es del proyecto; pstore no bloquea SSH/la
  depuración por canal RNDIS, pero sí deja una vía de recuperación menos
  cubierta.

**H-C2 — La imagen física probada y la imagen del baseline NO son la misma**

- Archivo: `reports/linux-61-authoritative-baseline.md` (línea 10 vs 14),
  verificación binaria propia.
- Evidencia:
  - Boot físico probado (`PMOS_CONSOLE_6_1_BOOTED`, run `31320766387`):
    SHA `3b692fefa…`, kernel payload `7dd4103ec0b7…`, banner
    `Sun Aug 9 16:22:18 UTC`.
  - Boot empaquetado en el baseline (run `31355730519`): SHA `5b03b884…`,
    kernel payload `637c94ec…`, banner `Mon Aug 10 05:15:…`.
  - Ambos son 6.1.0-sm6125 del mismo fork; el ramdisk es idéntico
    (`089e344a…`); el kernel descomprimido difiere en 53 bytes (fecha del
    banner de `linux_banner`).
- Impacto: el dispositivo que probó SSH en 2026-08-11 corría el kernel
  `7dd4103e` (banner Sun), no el empaquetado (`637c94ec`, banner Mon). Aunque
  la config es la misma, el empaquetado no ha sido probado como imagen única.
- Invalida declaración working: no (el informe ya dice `boot-untested`), pero
  el riesgo es que se trate la imagen empaquetada como si fuera la probada.
- Corrección mínima: mantener explícito en el preflight que el artefacto
  `boot-linux61-baseline-consoleblank0.img` no es la imagen probada; ya está
  documentado, pero el preflight usa `boot_b` como si fuera el mismo.
- Requiere rebuild: no. Requiere prueba física: sí (la imagen baseline debe
  probarse como tal antes de usarse como referencia).
- Puede esperar a 7.1: no aplica.

### ALTO

**H-A1 — El criterio de aceptación "pstore montado" es falso en la config 6.1**

- Archivo: `docs/FASE8-PREFLIGHT-LINUX61-BASELINE.md:71`
- Evidencia: mismo `kernel-6.1.config` (ver H-C1). `CONFIG_PSTORE=y` sin backend
  RAM y con `EFI_VARS_PSTORE` (inoperante sin EFI en el arranque de boot.img).
- Impacto: el preflight pide un criterio que la propia config no cumple; quien
  siga el preflight no podrá comprobar pstore y quedará bloqueado sin saber por
  qué.
- Corrección mínima: corregir el preflight (decir "dmesg y cmdline recuperables
  vía SSH; pstore pendiente por falta de PSTORE_RAM en el kernel 6.1").
- Requiere rebuild: no para el texto; sí si se quiere pstore funcional.

**H-A2 — Ruta del rootfs en el preflight no existe**

- Archivo: `docs/FASE8-PPREFLIGHT-LINUX61-BASELINE.md:57`
- Línea: `fastboot flash system_b local-private/linux61-baseline/xiaomi-laurel-ssh.img`
- Evidencia: en `local-private/linux61-baseline/` y
  `local-private/linux61-baseline-31563265029/` el archivo existente es
  `xiaomi-laurel-ssh.img.xz` (comprimido); `xiaomi-laurel-ssh.img` sin comprimir
  no existe.
- Impacto: un flasheo siguiendo el comando fallaría (archivo no encontrado).
- Corrección mínima: descomprimir el rootfs en el directorio correcto antes de
  usar el comando, y documentar que el comando asume el rootfs ya descomprimido.
- Requiere prueba física: no (solo el procedimiento).

**H-A3 — El preflight referencia el directorio `linux61-baseline/` pero el
artefacto final está en `linux61-baseline-31563265029/`**

- Archivo: `docs/FASE8-PREFLIGHT-LINUX61-BASELINE.md:51,57`
- Evidencia: `local-private/linux61-baseline-31563265029/` (run final
  `31563265029`) y `local-private/linux61-baseline/` (run `31562923337`, el
  que no tenía el manifest sanitizado). Ambos contienen los mismos binarios
  (SHA `41ed6045…` y `5b03b884…`), pero el preflight apunta a la ruta sin
  sufijo.
- Impacto: riesgo de operar sobre un directorio con artefactos de un run
  anterior (el manifest no sanitizado no se usa, pero la ruta documentada no es
  la del run final).
- Corrección mínima: actualizar la ruta del preflight al directorio del run
  final, o mover los artefactos al directorio documentado y verificarlo.

### MEDIO

**H-M1 — WiFi WCN3990: sin nodo DT, sin transporte, sin firmware**

- Evidencia: `wcn-audit/runtime-20260811T161539Z` muestra `/sys/class/mmc_host`
  vacío, `/sys/class/net` solo `lo` y `usb0`, sin rfkill, sin wlan0.
- Config: `CONFIG_ATH10K=m`, `CONFIG_ATH10K_SNOC=m`, `# CONFIG_ATH10K_SDIO is
  not set`, `CONFIG_WCN36XX=m`, `CONFIG_MMC=y`, `CONFIG_REMOTEPROC=y`.
- Impacto: no hay evidencia de que el nodo WCN3990 esté presente en el DTB 6.1
  ni de un transporte operativo. No se debe declarar Wi-Fi `configured` como
  funcional; `configured` (Kconfig/DT) es el máximo honesto. El documento ya lo
  deja como "configured", pero la nota histórica en la matriz decía "va por
  SDIO" sin demostrarlo.
- Corrección: la matriz ya fue corregida en `16adaf8` (quitar afirmación SDIO).
  Mantener el estado en `configured`.

**H-M2 — La memoria del ramdisk en la config 6.1 no incluye PSTORE backend;
cualquier claim de pstore en docs 6.1 previos es falso positivo**

- Evidencia: ver H-C1. La matriz de hardware de 7.1 (`reports/hardware-matrix.json`)
  menciona pstore en el contexto del kernel 7.1 (`configs/kernel/laurel-base.fragment`
  tiene PSTORE_RAM), lo cual es correcto; el problema es solo en 6.1.

**H-M3 — La auditoría de Workflow 16 no verifica la fecha del kernel ni que el
boot no probado no se reutilice**

- Archivo: `.github/workflows/16-build-linux61-baseline.yml` (paso "Verificar
  componentes de entrada")
- Evidencia: el paso verifica `kernel = 6.1 @77de535b`, `.ssh.enabled` y
  `sshd_config`, pero no compara el SHA del boot con el físico probado ni
  verifica el banner.
- Impacto: la run CI no detecta la diferencia de 53 bytes (ver H-C2). El
  manifest lo marca `boot-untested`, así que el estado se conserva, pero el CI
  no previene el mal uso.
- Corrección mínima: en el workflow, registrar en el manifest el SHA del boot de
  entrada y el del físico probado (ya se imprime, pero no se contrasta).

### BAJO

**H-L1 — `scripts/patch-bootimg-cmdline.py` modifica `id[8]` del header (SHA1)
pero mantiene el payload; el `id` queda distinto al original**

- Evidencia: verificación binaria: `id` de `3b692f…` =
  `8954c227f59d0f333feeeaa2686f0327181ee0a6…`, `id` de `41ed…` =
  `adda88d61eb61da1ef65f50cd5d32510dfc4bb8…`. El payload es idéntico; el `id`
  cambia porque el cmdline está en el header. Es esperado y correcto, pero debe
  documentarse que el SHA del archivo cambia al cambiar el cmdline (ya está en
  el reporte).

**H-L2 — Los directorios locales duplicados (`linux61-baseline/` y
`linux61-baseline-31563265029/`) no son distinguibles por el preflight**

- Ver H-A3. Riesgo bajo de confusión operativa.

## Veredictos por subsistema

| Subsistema | Veredicto | Evidencia |
|---|---|---|
| Reproducibilidad | `packaged/static-validation-passed`, NO `working` | H-C2; boot físico ≠ boot empaquetado |
| Pantalla/logs | `partially-working` (simplefb/fbcon 720x1560 físico); `consoleblank=0` solo en la imagen, sin prueba física | evidencia física 2026-08-10/11 |
| SSH | `working` por RNDIS (`172.16.42.1`), root por clave; el canal es estable y recuperable | `SSH-ROOT-6_1-READONLY` |
| Wi-Fi WCN3990 | `configured`/`not-demonstrated` (sin nodo DT operativo, sin transporte, sin wlan0) | wcn-audit |
| USB gadget | `partially-working` (RNDIS/`usb0` físico) | dmesg, ssh-live |
| OTG | `blocked`/`not-demonstrated` (`dr_mode="peripheral"`) | reportes físicos |
| DRM/display | simplefb `partially-working`; DRM/MSM `compiled`, sin `/dev/dri` | matriz, ssh-live |
| GPU/3D | `not-demonstrated` (sin `/dev/dri`, sin firmware GPU, sin mesa) | matriz |
| Power/thermal | `not-targeted`/`configured` (sin power_supply, sin thermal zones) | ssh-live |
| Bluetooth/audio | `configured`/`not-demonstrated` (sin hci0, sin soundcards) | ssh-live |
| Suspend | `not-demonstrated` | sin evidencia |

## Falsos positivos encontrados y corregidos (o pendientes)

1. pstore: la config 6.1 NO tiene backend RAM; cualquier claim de pstore en 6.1
   es falso. Pendiente de corregir el preflight (H-A1).
2. El "kernel 6.1" del baseline se trata en ocasiones como si fuera el probado:
   H-C2 lo desmiente (53 bytes de banner). El informe ya es honesto.
3. Afirmación histórica "WCN3990 va por SDIO": sin demostrar. La matriz ya fue
   corregida en `16adaf8`.

## Riesgos de brick / regresión

- El preflight cumple con los respaldos (boot_a/boot_b, vbmeta, dtbo, modem,
  persist en `local-private/backups/2026-08-09/`, con manifest y SHA256SUMS).
- Riesgo principal: probar el baseline sobre `boot_b`/`system_b` ya modificados
  con respaldo existente; el procedimiento está documentado.
- No se detecta ninguna operación destructiva automática en los workflows
  (ninguna coincidencia de `fastboot flash/erase/format/set_active/reboot`,
  `mkfs`, `wipefs`, ni escritura a `/dev/`).

## Correcciones a incorporar (tras el informe)

1. Preflight H-A1: documentar que pstore no es recuperable en 6.1 por falta de
   `PSTORE_RAM` (texto).
2. Preflight H-A2: indicar que el rootfs debe descomprimirse antes de flashear
   (texto) o descomprimir localmente.
3. Preflight H-A3: apuntar al directorio del run final
   (`linux61-baseline-31563265029/`), o mover artefactos al directorio
   documentado y verificarlo.
4. Workflow 16 (H-M3, opcional): contrastar el SHA del boot de entrada contra el
   físico probado en el manifest.

Ninguna de estas correcciones requiere rebuild ni prueba física; son
documentales/preventivas. La decisión sobre PSTORE_RAM en 6.1 (rebuild) queda
al proyecto.

## Qué sigue bloqueado

- pstore/ramoops en 6.1 (falta `PSTORE_RAM` en la config).
- Wi-Fi, Bluetooth, OTG host, GPU/3D, DRM/display, power/thermal, audio,
  suspend: sin evidencia física o sin soporte de la rama 6.1.

## ¿Baseline listo como referencia de migración a 7.1?

Parcialmente. El kernel, el canal SSH/RNDIS y simplefb/fbcon son una referencia
válida y reproducible. Pero el baseline empaquetado sigue `boot-untested`, y
pstore no es recuperable. Debe probarse la imagen empaquetada (con `consoleblank=0`
y rootfs SSH) antes de congelarla como referencia oficial, y decidir si se
añade PSTORE_RAM en 6.1 o se deja a 7.1.

## Confirmaciones solicitadas

- No se ejecutó Fastboot en esta revisión.
- No se escribió ninguna partición.
- No se modificó el teléfono.
- Linux 7.1 continúa congelado en `31553208748` (`boot-untested`).
- Las funciones no probadas siguen marcadas como no demostradas
  (`configured`, `not-targeted`, `not-demonstrated`, `blocked`).
