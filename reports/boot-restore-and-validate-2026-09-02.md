# Plan de restauración y validación del boot (FASE 8 preflight)

Fecha: 2026-09-02. Estado: **documento de preparación — NO ejecutar sin
autorización explícita y verificación previa.** El agente no flashea; el
propietario ejecuta cada comando tras el gate FASE 8.

## 1. Contexto / problema

El dispositivo pasó de arrancar por SSH (2026-09-01, slot b, boot run 21
funcional, rootfs devtools en `system_b`) a presentar **"boot partition
not found"** (2026-09-02). Este mensaje del ABL Xiaomi indica que el
bootloader no puede encontrar/validar la partición `boot` del slot activo y
cae a Fastboot. El diagnóstico concluye que la causa **no es la imagen
boot** (los layouts v0, DTB, os-version y second_addr son correctos) sino el
**entorno del slot** (misc/slot state / AVB).

Bloqueante: mientras el boot no arranque, **no se puede probar nada**
(WiFi, GPU, display, USB). Este documento restaura y valida primero el boot.

## 2. Riesgo crítico: NO existen respaldos de particiones en este workspace

- `local-private/backups/` — **AUSENTE** (vació/inexistente). Los documentos
  previos (historical-flash-instructions.md R12, preflight stage2) referencian
  `local-private/backups/2026-08-09/` con 13 particiones y un
  `KNOWN_GOOD_boot_eos-4.1.1.img`, pero **ninguno existe en el workspace**.
- Consecuencia AGENTS §7: no flashear particiones stock sin respaldo completo.
  El **slot a** (que contendría /e/OS de fábrica) NO debe tocarse sin antes
  confirmar su respaldo.

**Antes de cualquier flash destructivo**, SI no existen respaldos, generar la
guía de respaldo desde Android/recovery root (`docs/BACKUP-GUIDE.md`) y
respaldar `boot_a/b`, `dtbo_a/b`, `vbmeta_a/b`, `persist`, `modemst1/2`,
`fsg`, `fsc`. Detenerse si no hay respaldos.

## 3. Artefactos de boot disponibles y verificados (local)

| Artefacto | Ruta | SHA-256 | Header | cmdline | Uso |
|---|---|---|---|---|---|
| Boot funcional run 21 (arrancó 01-sep) | `local-private/linux61-dev/export-resolved/boot.img` | `f5769064...8883402` | v0, page 4096, osver 0x0 | `clk_ignore_unused` | **Restaurar el arranque del slot b** |
| Boot + fix pantalla (consoleblank=0) | `local-private/linux61-dev/export-resolved/boot-consoleblank0.img` | `c344668f...3f136b` | v0, page 4096 | `clk_ignore_unused consoleblank=0` | Opción tras recuperar SSH |
| Boot Etapa 2 (rmtfs+ramoops+wcn3990-probe, MPSS disabled) | `local-private/linux61-dev/stage2/boot-linux61-stage2.img` | `2e81102f...35affd` | v0, page 4096, osver 0x0 | `clk_ignore_unused` | **Siguiente a validar** (pstore/rmtfs; NO WiFi) |
| vbmeta flags=2 (slot b) | `local-private/09-control/boot-out/vbmeta-historical-flags2.img` | `fe1f4b55...4ca2` | — | — | Requerido para slot b (AVB) |

`boot-consoleblank0` y `boot.img` comparten kernel/ramdisk/DTB byte-idénticos;
solo difiere el cmdline (consoleblank=0 para evitar el apagado de pantalla por
blanking VT, ver `reports/runtime-6.1-devtools-live.md`).

## 4. Paso 1 — Diagnóstico de solo lectura (SIEMPRE primero)

Con el teléfono en Fastboot, registrar la salida sanitizada:

```
fastboot devices
fastboot getvar current-slot
fastboot getvar slot-count
fastboot getvar unlocked
fastboot getvar secure
fastboot getvar partition-size:boot_a
fastboot getvar partition-size:boot_b
fastboot getvar partition-size:dtbo_b
fastboot getvar partition-size:vbmeta_b
fastboot getvar slot-successful:b
fastboot getvar slot-unbootable:b
fastboot getvar slot-retry-count:b
```

Guardar en `local-private/` (reinventar el preflight FASE 8, ver
`scripts/read-fastboot-metadata.sh` para sanitizar). Con `current-slot` se
decide la reconstrucción.

## 5. Paso 2 — Restaurar el arranque del slot b (el experimento histórico)

Objetivo: devolver el slot b al entorno que SÍ arrancó el 01-sep
(boot funcional + vbmeta flags2 + dtbo_b borrado + system_b devtools).
NO toca el slot a.

```
fastboot flash boot_b    local-private/linux61-dev/export-resolved/boot.img
fastboot flash vbmeta_b  local-private/09-control/boot-out/vbmeta-historical-flags2.img
fastboot erase dtbo_b
fastboot set_active b
fastboot reboot
```

Criterio de éxito: arranca y responde `ssh root@172.16.42.1` (RNDIS, clave
`local-private/devkeys/id_ed25519`). Si falla de nuevo con
"boot partition not found", el slot b está degradado a nivel misc/AVB y hay
que inspeccionar misc y el estado de bootloader ANTES de seguir (detenerse).

## 6. Paso 3 — Validar Etapa 2 (siguiente hito, NO WiFi)

Una vez restaurado el arranque con el boot funcional, probar el
`boot-linux61-stage2.img` (kernel 6.1 + rmtfs-mem + ramoops/pstore + 
wcn3990-probe, `mpss disabled`):

```
fastboot flash boot_b  local-private/linux61-dev/stage2/boot-linux61-stage2.img
fastboot reboot
```

Criterio: tras SSH — `cat /proc/iomem | grep -i ffc4`, `ls /sys/fs/pstore/`,
`ls /dev/qcom_rmtfs_mem*`. Ver `reports/stage1-memory-rmtfs-ramoops.md` y
`reports/phase8-stage2-prefly-pstore-ramoops.md`.

**OJO**: el stage2 NO habilita WiFi (aplica 0001+0004+0005, deja MPSS
`disabled`). Su objetivo es pstore/rmtfs, no WiFi.

## 7. Sobre WiFi (honestidad)

El WiFi (WCN3990) requiere una cadena física dedicada que **nunca se probó
end-to-end**: rmtfs → MPSS running (0002+0003) → QRTR/QMI WLFW → firmware
WCN3990 + MPSS (propietario) en rootfs → `wlan0`. NO es alcanzable con un
simple build. Ver `reports/physical-tests/WIFI-V3-MPSS-RMTFS-BLOCKED/` 
(solo test físico, bloqueado en el primer eslabón rmtfs) y el diagnóstico
consolidado en esta misma sesión. Clasificación honesta: `boot-untested` /
`blocked`.

## 8. Acciones

1. Ejecutar Paso 1 (getvar solo lectura) e informar `current-slot` y los
   `slot-unbootable/retry-count`. Sin esto no se decide la reconstrucción.
2. Confirmar si existen respaldos de particiones en otra máquina/ruta (si no,
   generarlos antes de flashear).
3. Autorizar FASE 8 para el Paso 2 (restaurar slot b) y luego Paso 3 (stage2).
4. Con el arranque estable, priorizar display/USB/GPU (menos eslabones de
   bloqueo) antes de la cadena WiFi dedicada.
