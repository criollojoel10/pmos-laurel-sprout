# Reporte R10 — Matriz experimental para la reproducción histórica

Fecha: 2026-08-05. Estado: DISEÑO. Nada se ha ejecutado.

## Contexto (resultados IT1/IT2/IT3)

Todas las pruebas en slot b devolvieron a Fastboot (18d1:d00d):
- IT1 TEST_IMG (header v2, DTB en sección) — sin vbmeta modificado
- IT2 TEST_IMG + vbmeta_b flags=3
- IT3 boot.img formato histórico (append_dtb, dtb_size=0) + vbmeta_b flags=3

Ninguna reprodujo el `erase dtbo` histórico. Tampoco hay control de que el
slot b pueda arrancar NINGUNA imagen.

## Hipótesis en liza

| ID | Hipótesis | Evidencia previa | Prueba decisiva |
|---|---|---|---|
| H-SLOTB | Slot b no arranca ninguna imagen (particiones b no provisionadas / sistema) | Ningún arranque exitoso en b | EX0 |
| H-DTBO | aboot aplica overlays dtbo_b sobre el DTB mainline → fallo | `erase dtbo` en receta histórica | EX2/EX1 |
| H-KERNEL | Kernel mainline (7.1 o 6.1) no arranca en este aboot (config/initramfs) | IT1-3 | EX1 (6.1) vs EX2 (7.1) |
| H-VBMETA | Verificación AVB interfiere (descartada: flags=3 desactiva verificación) | IT2/IT3 | EX1/EX2 con flags=2 |

## Matriz de experimentos (todos en slot b, tras respaldo físico R8)

Cada experimento: `set_active b` → reboot → registrar → restaurar slot a →
`set_active a` + `reboot` (usuario). Orden de ejecución por riesgo creciente.

### EX0 — Control del slot b (riesgo MUY bajo)

| | |
|---|---|
| boot_b | `KNOWN_GOOD_boot_eos-4.1.1.img` (recovery-kit) |
| vbmeta_b | `VBMETA_custom_flags3_eos.img` (ya presente) |
| dtbo_b | sin tocar |
| Resultado esperado | /e/OS arranca desde slot b (valida que b funciona) |
| Si falla | Slot b defectuoso/no provisionado → abortar enfoque slot b |

### EX1 — Kernel 6.1 histórico + dtbo_b borrado (riesgo medio)

| | |
|---|---|
| boot_b | kernel 6.1 `77de535b` boot.img histórico (append_dtb, cmdline `clk_ignore_unused`) |
| vbmeta_b | `vbmeta-historical-pmos-flags2.img` (flags=2, artefacto R5) |
| dtbo_b | `fastboot erase dtbo_b` (tras respaldo) |
| Resultado esperado | Kernel 6.1 inicia initramfs; sin rootfs fallará al montar system → diagnóstico "kernel arrancó" vs "no arrancó" |
| Decisión | Valida cadena kernel+boot+vbmeta+dtbo de 2022 sin flashear rootfs |

### EX2 — Kernel 7.1 append_dtb + dtbo_b borrado (riesgo medio)

| | |
|---|---|
| boot_b | boot-laurel-append-dtb.img (IT3, kernel v7.1) |
| vbmeta_b | flags=2 |
| dtbo_b | `fastboot erase dtbo_b` |
| Resultado esperado | Si H-DTBO es cierta → kernel 7.1 inicia. Si no → Fastboot (H-KERNEL) |
| Decisión | Confirma/descarta H-DTBO para el kernel moderno |

### EX3 — Reproducción histórica completa (riesgo ALTO, requerirá gate)

| | |
|---|---|
| boot_b | boot.img histórico kernel 6.1 (EX1) |
| vbmeta_b | flags=2 |
| dtbo_b | borrado |
| system_b | rootfs pmOS histórico (imagen ext4, construida en CI) |
| Precaución | La imagen histórica es para `system` sin A/B; requiere adaptar a `system_b` y tamaño <= partición (ver R4) |

### EX4 (no recomendada aún) — borrado de slot a

Solo si slot b queda inservible y se descarta. NO se contempla.

## Reglas

1. Ningún experimento sin respaldo físico previo (R8) y gate FASE 8.
2. Después de cada experimento: restaurar slot a y verificar que /e/OS arranca.
3. Nunca tocar `persist`/`modemst*`/`fsg`/`fsc`/`modem`.
4. `fastboot erase dtbo_b` solo tras respaldo de `dtbo_b` (R8) y autorización.
5. El slot a permanece intacto como punto de retorno (boot_a/vbmeta_a/apps
   originales no se tocan).
