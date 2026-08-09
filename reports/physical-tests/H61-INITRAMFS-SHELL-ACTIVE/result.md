# H61 sedfix — Kernel 6.1 histórico: initramfs completo + rescue shell activa

Fecha: 2026-08-09. Test físico: EX3 slot b, `boot_b` = kernel 6.1 histórico +
initramfs sedfix (mismo kernel, solo cambió el ramdisk). Estado:
**INITRAMFS_6_1_SHELL_ACTIVE — PASS**.

## Antecedente

El boot v0 del mismo kernel 6.1 paniqueaba (`Kernel panic - not syncing:
Attempted to kill init!` por `/init: line 35: sed: not found`). El fix cambió
únicamente el initramfs: busybox con applets REQUIRED forzados en `.config`,
árbol de enlaces desde `busybox.links`, `/init` sin `set -e`, invocación
explícita `/bin/busybox <applet>` y rescue shell. Auditado en
`reports/h61-sedfix-boot-audit.md` (kernel 6.1 byte-idéntico al v0, sha
`97b4bff0…`).

## Evidencia visible (pantalla del dispositivo + serial ttyMSM0)

```
INITRAMFS_REACHED
[diag-init] entering rescue shell
sh: can't access tty; job control turned off
<prompt interactivo>
```

- `INITRAMFS_REACHED`: el init completó todo el flujo diagnóstico sin morir.
- `[diag-init] entering rescue shell`: entrada a la shell de rescate.
- `sh: can't access tty; job control turned off`: NO es un kernel panic; solo
  indica que la shell no obtuvo TTY controlador (no hay USB gadget funcional en
  este initramfs). Aceptable para un initramfs de diagnóstico; el prompt sigue
  operativo.
- No ocurrió `Kernel panic`.
- La falta de OTG/USB dentro del initramfs NO invalida el resultado: no forma
  parte del criterio de esta prueba.

## Clasificación

| Estado | Valor |
|---|---|
| KERNEL_6_1_ENTERED | SÍ |
| DISPLAY_CONSOLE_6_1_WORKING | SÍ |
| UFS_6_1_DETECTED | SÍ |
| INITRAMFS_6_1_REACHED | SÍ |
| INITRAMFS_PID1_MISSING_SED | NO (resuelto) |
| INITRAMFS_6_1_SHELL_ACTIVE | SÍ (INITRAMFS_REACHED + rescue shell con prompt) |

## Lo que la pantalla demuestra

- kernel 6.1 ejecutado y estable hasta el initramfs;
- DTB aceptado;
- header v0 / append_dtb correctos;
- vbmeta_b flags=2 suficiente;
- dtbo_b borrado suficiente;
- display/framebuffer funcional para consola;
- `/init` ejecutado como PID 1 y MANTENIDO vivo;
- rescue shell interactiva aceptando órdenes (prompt disponible).

## Estado persistente del slot b (sin cambios para la siguiente prueba)

| Partición | Estado |
|---|---|
| dtbo_b | borrado |
| vbmeta_b | vbmeta histórico flags=2 |
| system_b | xiaomi-laurel.img (rootfs histórico, MBR completo) |
| boot_b | boot kernel 6.1 sedfix funcional (respaldo) |
| active slot | b |

Slot a intacto con /e/OS.

## Siguiente (P9)

Cambiar únicamente `boot_b` a la variante 7.1 sedfix
(`boot-laurel-kernel-7.1-v0-appenddtb-sedfix.img`, sha `1b311cd7…`, 21,581,824 B,
mismo ramdisk). Preflight en
`local-private/phase-e-flash/preflight/h61-sedfix-boot-71/manifest.json`.
Clasificación esperada: `INITRAMFS_7_1_SHELL_ACTIVE` (u otra clasificación
según la última línea visible, ver preflight).
