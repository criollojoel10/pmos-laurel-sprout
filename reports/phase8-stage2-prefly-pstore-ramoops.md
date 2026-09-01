# FASE 8 — Preflight Etapa 2 (reserved-memory/ramoops): artefacto para prueba física

Fecha: 2026-09-01
Este documento se DETIENE en el punto de parada obligatorio (AGENTS.md §8):
muestra artefactos, hashes, límites, slot, particiones afectadas, respaldo
y restauración, y recomienda la prueba menos destructiva. **NO continúa
automáticamente**: requiere autorización explícita del propietario.

## 0. Resumen

El artefacto de Etapa 2 (`boot-linux61-stage2.img`) está construido y
validado en CI (run **33538415304**, success, todos los gates de
manifiesto aprobados). Su único cambio funcional respecto al boot que ya
funciona (SSH root) es el kernel: mismo commit `77de535b` + `PSTORE_RAM`
habilitado + fijación del nodo `reserved-memory`/ramoops. El ramdisk es
byte-idéntico al funcional. Sin firmware nuevo, sin cambios de rootfs.

## 1. Artefacto

| ítem | valor |
|---|---|
| workflow | `22-build-linux61-stage2` |
| run | 33538415304 (success) |
| artefacto | `boot-linux61-stage2` (id 9813165072) |
| local | `local-private/linux61-dev/stage2/boot-linux61-stage2.img` |
| SHA-256 | `2e81102fe61c73a810a4022314e03068bf983324d29a42e6643a5d67b435affd` |
| kernel.gz | `aeb4bac7ccf0ea3b0320f11ede59ffd3519220aaacf9bac0923a6bae604bf326` |
| final.dtb | `6a77ebe7ed8b8dedbdc9cad5205f3d05ce7eccf2c59963a8527139b0cf30208c` |
| ramdisk | `c34d6b83b57a296cb8b085d18a53b4033415e6f292fe0a79c79ac0662749e136` |
| manifest | `local-private/linux61-dev/stage2/manifest.json` (`doksay_true:false`, `boot-untested`) |

### Verificación independiente realizada

- `sha256sum -c SHA256SUMS`: todo OK.
- Header boot v0: `ANDROID!`, page 4096, offsets 0x8000/0x1000000/0x100,
  OS_VERSION field = **0x0** (idéntico al funcional), cmdline
  `clk_ignore_unused`.
- Ramdisk en boot == ramdisk funcional (`export-resolved/boot.img`, run 21)
  byte a byte.
- DTB: `/reserved-memory` (guion) con ramoops hijo, `pmsg-size = <0x20000>`,
  sin `reserved_memory` (guion bajo), `rmtfs-mem` + `qcom,wcn3990-wifi`
  presentes (parches 0004/0001).

## 2. Tamaño vs límite

| ítem | bytes | notas |
|---|---|---|
| boot funcional (run 21) | 12 406 784 | ~11.83 MiB |
| **boot-linux61-stage2.img** | **12 247 040** | ~11.68 MiB (cabe holgado) |
| Límite partición boot | 67 108 864 | 64 MiB (`0x4000000`), medido 2026-08-06 |

Margen: ~54.7 MiB libres. Sin riesgo de overflow.

## 3. Slot y particiones

- Slot activo documentado (última lectura): **a**. Se DEBE re-leer
  `fastboot getvar current-slot` como primer paso de la prueba (solo
  lectura).
- Prueba de referencia histórica (boot funcional pmOS): flasheada en
  `boot_b` con `vbmeta_b flags=2` y rootfs `system_b`. La Etapa 2 NO toca
  vbmeta ni rootfs: **solo reemplaza la imagen de boot del slot de prueba
  por el artefacto**, sin cambiar slot activo.

### Particiones que se modificarían (si se flashea)

| partición | contenido | cambio |
|---|---|---|
| `boot_<slot>` | imagen Etapa 2 | reemplazo del kernel autoboot |
| (sin cambio) | dtbo/vbmeta/system | NO se tocan |

## 4. Respaldo y restauración

- Respaldo de imágenes de boot actuales: disponible en
  `local-private/backups/2026-08-09/` (hashes verificados 13/13) y el boot
  funcional completo en `local-private/linux61-dev/export-resolved/boot.img`.
- Restauración si el boot de Etapa 2 falla:
  `fastboot flash boot_<slot> local-private/linux61-dev/export-resolved/boot.img`
  (preservando slot activo).
- Recovery: ver `docs/BACKUP-GUIDE.md`, `docs/RECOVERY.md`.

## 5. Prueba menos destructiva recomendada

1. `fastboot devices` + `fastboot getvar current-slot` (lectura).
2. **Preferible**: `fastboot boot boot-linux61-stage2.img` si la imagen se
   aceptara desde RAM (o una sola escritura en `boot_<slot actual>` con
   vbmeta intacto); NO rotar slots.
3. Criterio de éxito: arranque + `ssh root@172.16.42.1`, luego
   `cat /proc/iomem | grep ffc4`, `ls /sys/fs/pstore/` y
   `echo c > /proc/sysrq-trigger` tras guardar estado → ver
   `reports/stage1-memory-rmtfs-ramoops.md` §9-§10.
4. Criterio de no-daño: si no arranca, flash del boot funcional y volver
   al slot original.

## 6. Autorización requerida

Por AGENTS.md §0/§8, el agente NO ejecuta ninguna de las operaciones 1-2.
Se requiere confirmación explícita del propietario (incluyendo slot
objetivo y método: `fastboot boot` vs flash de `boot_<slot>`). Hasta esa
autorización, esta etapa queda **DETENIDA** con el artefacto listo y
verificado.