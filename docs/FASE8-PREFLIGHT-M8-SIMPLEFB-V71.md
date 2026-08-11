# FASE 8 — Preflight M8: simplefb v7.1

Estado: preparado; **detenerse antes de cualquier Fastboot de escritura**.

## Objetivo

Probar el kernel Linux mainline v7.1 con la ruta `FB_SIMPLE`/`fbcon`, equivalente
al camino que mostró consola en el kernel histórico 6.1. No pretende validar
DRM/KMS, GPU 3D, Wi-Fi, Bluetooth ni OTG host.

## Artefactos

| Campo | Valor |
|---|---|
| Commit display | `671b6b6` |
| Commit diagnóstico | `94aa7d4` |
| Corrección Kconfig bool | `a3167ec` |
| Kernel run | `pendiente` |
| Boot run | `pendiente` |
| Artefacto | `boot-laurel-diagnostic.img` |
| SHA-256 | `pendiente de la run 04` |
| Tamaño | `pendiente; límite 67108864 bytes` |
| Partición prevista | solo `boot_b` |

## Configuración esperada

- `CONFIG_FB=y`
- `CONFIG_FB_SIMPLE=y`
- `CONFIG_DRM_SIMPLEDRM` no establecido
- `CONFIG_DRM_MSM=m`
- `CONFIG_FRAMEBUFFER_CONSOLE=y`
- `CONFIG_VT=y`
- `console=tty0 consoleblank=0`
- DTB con `framebuffer@5c000000`, 720x1560, stride 2880, `a8r8g8b8`.

## Estado físico conocido

La prueba anterior de v7.1 fue `boot-untested` con pantalla negra. El slot
actual documentado es `b`; no se debe asumir que siga igual sin repetir las
consultas Fastboot de solo lectura inmediatamente antes de la prueba.

## Recuperación

Rollback previsto: reflashear `boot_b` con:

`local-private/phase-e-flash/preflight/h61-sedfix-boot/boot-laurel-kernel-6.1-historical-v0-sedfix.img`

Debe verificarse su SHA-256 contra su `SHA256SUMS` antes de cualquier operación.
No se tocan `system`, `dtbo`, `vbmeta`, `persist` ni particiones de identidad.

## Observación esperada

Resultado esperado: consola visible por simplefb/fbcon y sin apagado automático
por `consoleblank=0`. Puede aparecer `usb0` en `172.16.42.1/24` con telnetd
temporal de diagnóstico; esa interfaz no es configuración de producción.

La compilación y el empaquetado no permiten declarar `working`. El estado previo
a la prueba es `packaged`/`static-validation-passed`; solo la evidencia física
puede elevarlo a `detected`, `partially-working` o `working`.

## Punto de parada obligatorio

Este documento no autoriza el flasheo. Antes de ejecutar el comando preparado
se deben rellenar run IDs, SHA-256, tamaño, slot actual, respaldos confirmados
y procedimiento de rollback, y solicitar autorización explícita inmediata.

## Comando preparado, NO ejecutado

```text
fastboot flash boot_b <ruta-local>/boot-laurel-diagnostic.img
```
