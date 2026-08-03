# Recuperación

Documentación de recuperación del Xiaomi Mi A3 `laurel_sprout`.

> Solo se puede restaurar lo que previamente se respaldó. Sin respaldos, NO
> flashear nada y detenerse.

## Requisitos previos a cualquier prueba física

Registrar antes de escribir el dispositivo:

1. Firmware stock exacto identificado.
2. Instrucciones de restauración.
3. Slot activo.
4. Tamaños reales de boot/dtbo/vbmeta (A y B) — ver
   `device-metadata/fastboot-sanitized.json`.
5. Estado del bootloader.
6. Respaldos de boot/dtbo/vbmeta (A y B), persist y particiones de identidad
   de radio.

Fastboot normalmente no permite leer particiones. Los respaldos se obtienen
arrancando Android/recovery con root y extrayendo las particiones.

## Cómo volver a Fastboot

- Desde Android: `adb reboot bootloader`.
- Desde recovery: `adb reboot bootloader`.
- Si el sistema no arranca: mantener Power + VolDown.

## Identificar el slot

```
fastboot getvar current-slot
```

Restaura siempre en el slot activo correspondiente.

## Restaurar boot del slot actual

```
fastboot flash boot_<slot> respaldo-boot_<slot>.img
```

## Restaurar dtbo del slot actual

```
fastboot flash dtbo_<slot> respaldo-dtbo_<slot>.img
```

## Restaurar vbmeta del slot actual

```
fastboot flash vbmeta_<slot> respaldo-vbmeta_<slot>.img
```

## Firmware stock

Identificar el build stock exacto (versión MIUI/Android One) y conservar su
procedimiento de restauración (herramientas oficiales del fabricante o
fastboot stock). No usar firmware de licencia incierta.

## Particiones que NUNCA deben escribirse sin necesidad

- `persist`
- `modemst1`, `modemst2`
- `fsg`, `fsc`
- EFS (identidad de radio)

Escribirlas sin un caso concreto y verificado puede romper la identidad de
radio de forma permanente.

## Casos típicos

### Pantalla negra con USB activo

- El sistema puede haber arrancado pero la pantalla falla.
- Intenta SSH/USB networking por consola (imagen console).
- No asumas brick: revisa `dmesg`.

### Bootloop

- Vuelve a Fastboot (Power + VolDown) y restaura boot del slot activo.
- No borres userdata en el primer intento.

### Ausencia de Fastboot

- Mantener Power + VolDown hasta confirmar en `fastboot devices`.
- Si no responde, cargar y dejar cargar, luego reintentar.
- EDL es el último recurso; exige herramientas y autorizaciones específicas.
  No se publican enlaces a herramientas EDL no verificadas.

## Advertencia EDL

Modo Emergency Download (EDL) permite flasheo a nivel de bajo nivel.
Usarlo incorrectamente puede hacer el dispositivo irreparable. No se debe
entrar en EDL sin un caso concreto y sin las herramientas autorizadas.
