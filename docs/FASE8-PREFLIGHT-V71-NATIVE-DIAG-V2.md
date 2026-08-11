# FASE 8 — Preflight boot nativo v7.1 v2

Estado: artefacto construido y validado; **detenerse antes de Fastboot**.

## Objetivo

Determinar si la pantalla cae por deshabilitar clocks/reguladores/power-domains
y capturar por qué no aparece USB/UDC en el kernel v7.1. No monta rootfs, no usa
módulos 6.1, no toca particiones.

## Artefacto

| Campo | Valor |
|---|---|
| Kernel run | `31513653872` |
| Workflow v2 | `31526065844` |
| Commit | `5d783ad` |
| Artefacto | `boot-laurel-v71-native-diag-v2.img` |
| Ruta local | `local-private/boot-31526065844/boot-out/boot-laurel-v71-native-diag-v2.img` |
| SHA-256 | `17de69041178cfbf7c94a3343346634ec722bc0730b9c7ab4aa774c0474358f7` |
| Tamaño | 23,085,056 bytes |
| Límite boot | 67,108,864 bytes |
| USB | RNDIS (`usb_function=rndis`) |
| Rootfs | no monta `system_b` |

## Cmdline (extraída y verificada)

```text
console=ttyMSM0,115200n8 console=tty0 consoleblank=0 ignore_loglevel
loglevel=8 initcall_debug printk.time=1 panic=10 clk_ignore_unused
pd_ignore_unused regulator_ignore_unused androidboot.hardware=qcom
androidboot.console=ttyMSM0 loop.max_part=7 buildvariant=user
```

- `clk_ignore_unused`, `pd_ignore_unused`, `regulator_ignore_unused`: solo
  diagnóstico; NO sustituyen la descripción correcta de clocks/reguladores.
- Sin `root=`, sin `skip_initramfs`, sin `quiet`.

## Observabilidad

- Primera instrucción `/init`: `V71_V2_PID1_FIRST_INSTRUCTION`, pausa 5 s.
- Marcadores `V71_V2_*` con repetición a los 2 s hacia stdout, `/dev/console`,
  `/dev/tty0`, `/dev/ttyMSM0` y `/dev/kmsg`.
- Heartbeat `[V71_V2_HEARTBEAT]` cada 10 s.
- Auditoría USB/DWC3/QUSB2/UDC/configfs antes y después del gadget.
- Espera UDC 30 s (`V71_V2_UDC_WAIT`/`FOUND`/`TIMEOUT`), bind único, espera
  usb0/rndis0 20 s, telnetd solo tras interfaz.
- MAC de laboratorio locally-administered derivadas en runtime (no publicadas).
- PID 1 nunca sale; sin set -e.

## Punto de parada

No se ejecutó ninguna operación física con este artefacto. Antes de una prueba:
repetir consultas Fastboot de solo lectura, confirmar slot y respaldos, verificar
SHA-256 y solicitar autorización explícita inmediata.

## Comando preparado, NO ejecutado

```text
fastboot flash boot_b local-private/boot-31526065844/boot-out/boot-laurel-v71-native-diag-v2.img
```
