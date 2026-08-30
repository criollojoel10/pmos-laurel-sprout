# Diagnóstico — fallback del v0-append NixOS (7.1) vs 6.1 que sí arrancó

Fecha: 2026-08-29. Estado: hipótesis GEOMETRÍA en validación física (T1).

## Hechos (solo evidencia física registrada)

| Imagen | Header | kernel payload (in-file) | ramdisk_offset | Resultado físico |
|---|---|---|---|---|
| **6.1 sedfix** (`d2c8145d…`, slot b, dtbo_b borrado, vbmeta_b flags=2) | **v0+append** | **9 252 106 B (~8.9 MiB)** | 0x1000000 (16 MiB) | **INITRAMFS_6_1_SHELL_ACTIVE** ✅ |
| pmOS-shell 7.1 IT1 (v2, DTB campo) | v2 | 20 284 596 B (~19 MiB) | 0x1000000 | fallback Fastboot |
| pmOS-shell 7.1 IT3 (v2, append_dtb) | v2+append | 20 284 596 B | 0x1000000 | fallback Fastboot |
| NixOS v2 (`66ae73a3…`, slot b) | v2 + dtb field | 17 951 274 B | 0x1000000 | **bootloader-rejected** |
| NixOS v0-append (`1043b607…`, slot A) | v0+append | 17 951 274 B | 0x1000000 | fallback Fastboot |

Datos de referencia: stock MIUI `V12.0.26.0.RFQMIXM` usa header v2, `ramdisk_offset
0x1000000`, kernel comprimido ~10 MiB (< 16 MiB, sin solape).

## Hipótesis principal (GEOMETRÍA)

El payload de kernel comprimido de 7.1 NixOS es 17 951 274 B **> ramdisk_offset
16 MiB**. Aboot (QCOM) carga ramdisk en `base+ramdisk_offset`; con el kernel
ocupando ~17.9 MiB el ramdisk se solapa con la cola del kernel → el kernel no
arranca o aboot descarta → fallback a Fastboot. La v7.1 **jamás** se probó
físicamente con payload < 16 MiB ni con ramdisk_offset mayor; el único éxito
(6.1) tiene payload 8.9 MiB < 16 MiB. Todas las v7.x (cualquier layout:
v2-campo, v2-append, v0-append) comparten el solape → coherente con que TODAS
fallen.

## Hipótesis secundaria (ENTORNO)

El 6.1 exitoso probó en **slot b con dtbo_b borrado + vbmeta_b flags=2**.
Nuestro v0-append se probó en **slot a** (dtbo/vbmeta de fábrica). Confundida
con la geometría; se despeja con el control T0 (6.1) en el MISMO slot b.

## Experimentos

- **T1 (lanzado):** NixOS v0-append con `ramdisk_offset=0x2000000` + `os_version
  1.0.0/2022-12` (paridad 6.1). CI OK → sha `50a147b2327cecdbf2c0bccc5340412cc4320310c475189b386c6b69ab8570af`
  (run `33283688275`), ramdisk_addr `0x2000000` confirmado en header v0.
  Flash objetivo: slot b (mismo entorno H61).
- **T0 (control):** rebuild del 6.1 sedfix EXACTO (run `33283770375`,
  `build_kernels=true` — artefactos de agosto expirados). Flash `boot_b` con
  `vbmeta_b` flags=2 + `dtbo_b` borrado → debe dar la rescue shell.
  Si T0 falla → entorno degradado (dtbo/vbmeta cambiados) → restaurar ambiente.

## Criterios

- T0 shell activa: entorno+procedimiento OK → T1 es el único delta (geometría).
- T1 shell activa: **causa raíz = solape de ramdisk_offset**; fix aplicado al
  pipeline (default 0x2000000 para 7.1).
- T0 OK + T1 falla: siguiente bisect = 7.1 sedfix (mismo ramdisk busybox que 6.1)
  para aislar kernel-7.1-vs-initramfs-NixOS.
- T0 falla: revisar slote/entorno (dtbo_b / vbmeta_b / slot activo) antes de nada.

## Estado del dispositivo

`fc178bb9491e` fastboot; `current-slot: a` (boot_a = v0-append fallido);
`unlocked: yes`; boot A/B 64 MiB. Recuperación ante todo: restaurar boot_a de R8
y `fastboot set_active a`, o `set_active b` (Lineage).