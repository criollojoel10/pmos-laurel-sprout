# H61 comparación 7.1 — pantalla negra (sin evidencia de serial)

Fecha: 2026-08-09. Test físico: EX3 slot b, `boot_b` = kernel 7.1 v0 append_dtb
sedfix (única variable vs el arranque 6.1 que funcionó). Estado:
**boot-untested** (pantalla negra persistente; sin serial no clasificable).

## Entorno (idéntico al 6.1 sedfix que sí arrancó)

| Partición | Estado |
|---|---|
| dtbo_b | borrado |
| vbmeta_b | flags=2 |
| system_b | xiaomi-laurel.img |
| boot_b | kernel 7.1 + ramdisk sedfix (mismo ramdisk que 6.1) |
| active slot | b |

## Evidencia

- `fastboot flash boot_b` 7.1: OKAY (21,076 KB).
- `fastboot reboot`: OKAY.
- Resultado en pantalla: **negra persistente**, dispositivo encendido.
- USB gadget: conectado pero **no enumerado** por Fedora (sin fastboot/adb).
- Serial ttyMSM0: **no disponible** (sin adaptador conectado durante esta
  prueba). Sin evidencia de líneas de kernel ni de initramfs.

## Clasificación honesta

| Estado | Valor |
|---|---|
| KERNEL_7_1_ENTERED | DESCONOCIDO (sin serial) |
| DISPLAY_CONSOLE_7_1_WORKING | NO (pantalla negra persistente) |
| INITRAMFS_7_1_REACHED | DESCONOCIDO (sin serial) |
| INITRAMFS_7_1_SHELL_ACTIVE | NO confirmado |
| COMPARACION_6_1_VS_7_1 | 6.1 muestra consola; 7.1 NO (mismo ramdisk, mismo entorno) |

## Interpretación

Con el entorno fijo (dtbo borrado, vbmeta flags=2, system MBR, ramdisk sedfix),
la única variable fue el kernel: 6.1 histórico `@77de535b` muestra la consola y
llega a `INITRAMFS_REACHED`; 7.1 mainline v7.1 no muestra nada. El pipeline de
display del kernel 7.1 no está funcional en hardware (coherente con que el
display solo se había validado en 6.1). Sin serial no podemos descartar que el
7.1 ni siquiera llegue a ejecutarse, ni confirmar su estado de kernel/initramfs.

## Acción tomada

Restaurado `boot_b` a la 6.1 sedfix funcional
(`boot-laurel-kernel-6.1-historical-v0-sedfix.img`, sha `d2c8145d…`,
`fastboot flash boot_b` OKAY). Verificado de nuevo: `INITRAMFS_REACHED` +
rescue shell.

## Siguientes opciones para el kernel 7.1 (no ejecutadas)

1. Repetir la prueba 7.1 CON adaptador serial ttyMSM0 conectado (clasificación
   con evidencia: KERNEL_7_1_ENTERED / INITRAMFS_7_1_NOT_REACHED / panic).
2. Revisar el pipeline de display del 7.1 (DPU/DSI/panel/PHY mainline) antes
   de reintentar; comparar DTB 7.1 vs 6.1 para el panel.
3. Mantener la 6.1 sedfix como baseline funcional y avanzar con el 6.1
   histórico (plasma/console) si el objetivo a corto plazo es un entorno
   visible.
