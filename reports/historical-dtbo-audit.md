# Reporte R9 — Auditoría de DTBO y rol del `fastboot erase dtbo` histórico

Fecha: 2026-08-05. Sin escritura al dispositivo.

## Datos verificados

| Imagen | Origen | Tamaño | SHA256 | Entradas DTBO |
|---|---|---|---|---|
| dtbo.img | ROM stock MIUI `laurel_sprout_global_images_V12.0.26.0.RFQMIXM_11.0` | 8,388,608 B (8 MiB) | `4d445058bf5558e3…` | 17 overlays |
| dtbo.img | ROM /e/OS 4.1.1 | 8,388,608 B (8 MiB) | `033b4ac5d36f123b…` | 1 overlay |

Formato de ambas: tabla DTBO v0 (`DT_TABLE_MAGIC=0xd7b7ab1e`, header 32 B,
page 4096, big-endian). Cada entrada es un FDT (`d0 0d fe ed`). Los overlays
stock usan `id=0, rev=0` (selección por board id).

Partición: `dtbo_a` / `dtbo_b`, 8 MiB cada una (0x800000), formato raw.

## El `erase dtbo` histórico

La guía pmOS publicada incluía:

```
# fastboot erase dtbo
```

(con `#` = prompt root → `sudo fastboot erase dtbo`, corrección R0). Se
ejecutaba **antes** del `flash_vbmeta/flash_rootfs/flash_kernel`. pmbootstrap
1.50.0 **no** flashea dtbo (no hay `flash_fastboot_partition_dtbo` en el
deviceinfo; `flash_dtbo` falla). El borrado era manual y deliberado.

Rol probable: en laurel_sprout, aboot (Qualcomm bootloader) usa la partición
DTBO para componer el DTB final. Al arrancar un kernel mainline con DTB propio
apendado, los overlays stock del dtbo pueden:
- intentar fusionarse sobre el DTB mainline y corromperlo (kernel no inicia), o
- producir un error de aboot que termina en fallback a fastboot.

Por eso el port pmOS histórico **borraba dtbo**: eliminar la interferencia de
los overlays stock sobre el DTB mainline.

## Estado de nuestras pruebas (IT1/IT2/IT3)

| Prueba | boot_b | vbmeta_b | dtbo_b | Resultado |
|---|---|---|---|---|
| IT1 | TEST_IMG (dtb en sección v2) | (vbmeta_a /e/OS vigente) | intacto | → Fastboot |
| IT2 | TEST_IMG | flags=3 | intacto | → Fastboot |
| IT3 | boot-laurel-append-dtb.img (formato histórico) | flags=3 | intacto | → Fastboot |

**Ninguna prueba reprodujo el `erase dtbo`**. Esta es la diferencia pendiente
más relevante respecto al procedimiento histórico.

## Hipótesis actualizada (R9)

**H9**: el arranque del kernel mainline en laurel_sprout requiere DTBO sin
overlays incompatibles (o vacío). El fallo constante a Fastboot en IT1-IT3
podría deberse a que aboot aplica los overlays de dtbo_b sobre el DTB mainline.
La prueba decisiva es la reproducción histórica completa: **borrar dtbo_b**
(con respaldo físico previo) + boot_b con formato histórico.

Nota de cautela: `erase dtbo` NO se puede ejecutar aún — falta el respaldo
físico de `dtbo_b` (ver AGENTS.md §7 y R8). El `erase dtbo` también era un
comando "prohibido" en el recovery-kit previo; con la nueva guía corregida
(`#` = root) queda como parte del flujo, pero SIEMPRE tras respaldo.

## Acciones necesarias antes de cualquier prueba con dtbo

1. Respaldo físico de `dtbo_b` (y de `boot_b`/`vbmeta_b` actuales) desde /e/OS
   o recovery root (R8). El dtbo.img de ROM es referencia, NO respaldo físico.
2. Gate FASE 8 con el usuario.
3. Recién entonces: `fastboot erase dtbo_b` como parte de la reproducción
   histórica en slot b.
