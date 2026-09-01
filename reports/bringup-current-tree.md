# Bring-up — estado actual del árbol (2026-09-01)

Documento vivo. Complementa `docs/HARDWARE-STATUS.md` (canónico) con el
punto exacto del bring-up en rama `bringup/linux61-hardware` y `main`.

## 1. Base verificada

- Boot funcional original pmOS 6.1 ("histórico", run 21): prompt de login
  visible + SSH (`root@172.16.42.1`, gadget RNDIS) + UFS arranca +
  simplefb 720x1560x32. Ramdisk/cmdline del boot funcional intactos
  (header: page 4096, kernel `clk_ignore_unused`, `os_version = 0x0`).
- Kernel: `linux-postmarketos-qcom-sm6125` 6.1 fork `sm6125-mainline`
  @`77de535b`, compilado vía pmbootstrap pmaports @`7aaee51a`
  (`kernel 6.1.0-sm6125 #1-postmarketos-qcom-sm6125`).
- El DTB del boot (hash `cb37540db8...`) es exacto al artefacto
  `kernel-6-1-historical` del workflow 09.

## 2. Etapa 1 (completada) — estatus del árbol

Ramas y tags congelados:

- `main` (desarrollo): contiene 0001 (wcn3990 first-probe), 0004
  (rmtfs-mem), 0005 (fix reserved-memory/ramoops) y workflow 22.
- Tag congelado `laurel-linux61-baseline-ssh-fb-2026-09-01` (=`1e702ee`):
  baseline de BIOS del boot funcional, NO se toca.
- `bringup/linux61-hardware` (dev): sale de `1e702ee`, contiene los
  cambios de Etapa 2.

## 3. Etapa 2 (en ejecución) — memory/ramoops/pstore

Bug raíz encontrado y por construir en CI:

- `/reserved_memory` (guion bajo) en el board DTS del fork → el kernel solo
  procesa `/reserved-memory` (guion) → ramoops/pstore, debug_mem,
  last_log_mem y cmdline_mem estaban en la DTB pero NUNCA en runtime.
- `msg-size` (binding inexistente) → `pmsg-size`; unit-address alineadas.
- Config: faltaba `CONFIG_PSTORE_RAM/CONSOLE/PMSG=y`. Presente:
  `QCOM_RMTFS_MEM=y`, `ATH10K_SNOC=m`, `QCOM_WCNSS_PIL=m`, `PSTORE=y`.
- Workflow `22-build-linux61-stage2` produce `boot-linux61-stage2.img`
  (boot v0, ramdisk idéntico al funcional, kernel recompilado con el fix).
  Detalles: `reports/stage1-memory-rmtfs-ramoops.md`.
- Estado actual del artefacto: **`boot-untested`** (CI OK → prueba física
  manual pendiente de autorización FASE 8).

## 4. Estado honesto por subsistema (árbol actual)

| subsistema | estado | notas |
|---|---|---|
| UFS | `working` | arranca desde UFS (system_b) |
| USB gadget RNDIS | `working` | SSH a 172.16.42.1 |
| Display (simplefb/fbcon) | `partially-working` | consola visible; se apaga por consoleblank (fix dirigido en v7.1, no en 6.1) |
| GPU Adreno / DRM-MSM | `compiled` | módulo NO cargado (`CONFIG_DRM_MSM=m`) en 6.1 |
| Wi-Fi (ath10k_snoc) | `blocked` | parche 0001 (probe) incluido en Etapa 2; **falta firmware** `wlanmdsp.mbn`/`board-2.bin` en rootfs. No declarar funcionando bajo ninguna condición |
| Bluetooth | `configured` | mismo bloqueo de bus/firmware |
| Táctil FT3518 | `compiled` | driver `edt-ft5x06`; sin input en runtime |
| pstore/ramoops (Etapa 2) | `configured` (en CI) | boot-untested |
| rmtfs-mem (Etapa 2) | `configured` (nodo + driver =y) | sin userspace rmtfs aún |
| MPSS | `disabled` | sin firmware de módem; correcto no arrancarlo |
| Audio / cámara / batería | `not-targeted` | sin esfuerzo |

## 5. Reglas activas

- No flashear sin autorización FASE 8 (el agente solo lee; las pruebas
  físicas las ejecuta el propietario tras aprobación explícita).
- No publicar firmware propietario, EFS, identidades ni seriales.
- No push sin `scripts/audit-public-repository.sh` verde.
- Estados permitidos: usar solo los de `docs/HARDWARE-STATUS.md` (§2).
- Todo trabajo pesado en GitHub Actions; localmente solo lectura/git.

## 6. Próximos pasos

1. Terminar Etapa 2 (CI) → verificar artefacto `boot-linux61-stage2`
   (cmdline, DTB con ramoops, SHA256, manifest `doksay_true:false`,
   `boot-untested`).
2. Reportar al propietario con artefactos, hashes, tamaño boot vs límite,
   slot actual, particiones afectadas y procedimiento de recuperación
   (FASE 8), y DETENERSE pidiendo autorización para `fastboot boot`/flash.
3. Tras resultado físico: pstore válido + SSH OK → declarar `working` y
   planificar siguiente etapa (firmware Wi-Fi/módem, OTG host, DRM-MSM).