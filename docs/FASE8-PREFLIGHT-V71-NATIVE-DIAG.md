# FASE 8 — Preflight boot nativo diagnóstico v7.1

Estado: artefacto construido y validado; **detenerse antes de Fastboot**.

## Artefacto

| Campo | Valor |
|---|---|
| Kernel run | `31513653872` |
| Workflow nativo | `31524524876` |
| Commit workflow | `43e777b` |
| Artefacto | `boot-laurel-v71-native-diag.img` |
| Ruta local | `local-private/boot-31524524876/boot-out/boot-laurel-v71-native-diag.img` |
| SHA-256 | `ef200c424c2929efa013a38aaac097e6d4cadf29ede210932a19c46905a5445d` |
| Tamaño | `23080960` bytes |
| Límite boot | `67108864` bytes |
| USB | RNDIS (`usb_function=rndis`) |
| Rootfs | no monta `system_b` |

## Contenido y validación

- Kernel v7.1 y DTB del run `31513653872`.
- BusyBox AArch64 estático compilado en CI.
- Initramfs nuevo, sin `/lib/modules/6.1*`, sin módulos ni scripts del
  initramfs pmOS histórico.
- Marcadores `V71_*` para kernel userspace, proc/sys/devtmpfs, fb, UFS, UDC,
  gadget, USB0, shell remoto y rescue shell.
- Heartbeat `[V71_HEARTBEAT]` cada 15 s.
- Configfs RNDIS temporal en `172.16.42.1/24`, telnetd diagnóstico.
- `console=tty0`, `consoleblank=0`, `ignore_loglevel`, `loglevel=8`,
  `initcall_debug`, `printk.time=1`.
- Sin `root=` ni `skip_initramfs`; no intenta montar rootfs.
- Kernel/ramdisk/DTB extraídos byte-idénticos; tamaño dentro de boot_b.

## Qué diagnostica

Este boot separa el problema anterior del ramdisk 6.1. Si la pantalla se apaga,
el heartbeat y los marcadores permiten distinguir kernel vivo, fbcon, UDC,
configfs y USB0. Si USB enumera, el host puede usar telnet en `172.16.42.1:23`
para leer dmesg sin depender del rootfs.

## Punto de parada

No se ha ejecutado ninguna operación física con este artefacto. Antes de una
prueba se deben repetir consultas Fastboot de solo lectura, confirmar slot y
respaldos, verificar SHA-256 y solicitar autorización explícita inmediata.

## Comando preparado, NO ejecutado

```text
fastboot flash boot_b local-private/boot-31524524876/boot-out/boot-laurel-v71-native-diag.img
```
