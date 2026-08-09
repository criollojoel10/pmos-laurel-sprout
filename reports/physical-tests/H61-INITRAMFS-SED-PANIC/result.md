# H61 — Kernel 6.1 histórico: initramfs alcanzado, panic por sed ausente

Fecha: 2026-08-09. Test físico: EX3 slot b, `boot_b` = kernel 6.1 histórico
v0 + initramfs de diagnóstico. Estado: **initramfs alcanzado / panic por
applet ausente (NO es fallo de kernel, DTB, AVB, UFS ni display)**.

## Transcripción visible (pantalla del dispositivo)

```
Run /init as init process
[diag-init] == initramfs de diagnóstico laurel_sprout (mainline v7.1) ==
[diag-init] kernel: 6.1.0-sm6125 [aarch64]
[diag-init] uptime: 5 s
[diag-init] -- dmesg --
/init: line 35: sed: not found
Kernel panic - not syncing: Attempted to kill init! exitcode=0x00007f00
CPU: 4 PID: 1 Comm: init
```

## Clasificación

| Estado | Valor |
|---|---|
| KERNEL_6_1_ENTERED | SÍ |
| DISPLAY_CONSOLE_6_1_WORKING | SÍ (framebuffer/consola visible) |
| UFS_6_1_DETECTED | SÍ (blkdevs enumerados en pantalla) |
| INITRAMFS_6_1_REACHED | SÍ (`Run /init as init process`) |
| INITRAMFS_PID1_EXITED_MISSING_SED | SÍ (causa primaria) |
| KERNEL_PANIC_ATTEMPTED_TO_KILL_INIT | SÍ (consecuencia de PID 1 salir) |

## Lo que la pantalla demuestra

- kernel 6.1 ejecutado;
- DTB aceptado;
- header v0 aceptado;
- append_dtb correcto;
- vbmeta_b flags=2 suficiente;
- dtbo_b borrado suficiente;
- display/framebuffer funcional para consola;
- UFS detectado;
- SCSI detectado;
- discos y particiones enumerados;
- `/init` ejecutado como PID 1.

## Diagnóstico

El panic es **secundario**. Causa primaria visible:

```
/init: line 35: sed: not found
```

`exitcode=0x00007f00` = shell status 127 desplazado (<< 8), coherente con
`command not found`. El init usa `mount | sed` en la línea 35; `sed` no existe
como applet/enlace en el initramfs. PID 1 terminó y el kernel paniqueó
deliberadamente (`Attempted to kill init`).

## NO clasificar como

- kernel no arrancó
- bootloader rechazó imagen
- AVB rechazó imagen
- DTB inválido
- UFS no funciona
- display no funciona

## Estado persistente del slot b (NO reescribir en próxima iteración)

| Partición | Estado |
|---|---|
| dtbo_b | borrado |
| vbmeta_b | vbmeta histórico flags=2 |
| system_b | xiaomi-laurel.img (rootfs histórico, MBR completo) |
| boot_b | boot kernel 6.1 v0 con initramfs diagnóstico defectuoso |
| active slot | b durante el intento |

Slot a intacto con /e/OS.

La siguiente iteración debe cambiar únicamente `boot_b`.

## Corrección planificada

1. Incluir applet `sed` (y todos los usados por /init) en BusyBox.
2. Instalar enlaces de applets correctamente (no solo el binario).
3. No depender de symlinks cuando se pueda invocar `busybox` explícito.
4. Impedir que PID 1 termine si un comando diagnóstico falla.
5. Abrir shell de rescate.
6. Mantener PID 1 vivo si la shell termina.
7. Reconstruir boots 6.1 y 7.1.
8. Extraer y verificar la imagen final.
9. Probar primero únicamente `boot_b` con kernel 6.1 corregido.
10. Después, si funciona, cambiar únicamente `boot_b` al kernel 7.1.

No tocar Plasma ni Kupfer todavía.
