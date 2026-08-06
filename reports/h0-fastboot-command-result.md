# H0 — Intento de arranque no destructivo (fastboot boot)

Fecha UTC: 2026-08-04
Dispositivo: Xiaomi Mi A3 `laurel_sprout`
Método: `fastboot boot` (boot en RAM, no escribe flash)

## Resultado exacto del dispositivo

```
Sending 'boot.img' (20996 KB)                      OKAY [  0.482s]
Booting                                            FAILED (remote: 'unknown command')
fastboot: error: Command failed
```

## Clasificación

`FASTBOOT_BOOT_COMMAND_UNSUPPORTED`

## Interpretación verificada (no extrapolación)

- La transferencia del boot.img fue **aceptada** (OKAY).
- El fallo ocurrió al solicitar el comando Fastboot **`boot`**.
- **No hubo ejecución del kernel**.
- **No hubo evaluación física del initramfs**.
- No hubo rechazo demostrado del contenido del boot.img (el comando `boot` no se ejecutó).
- No se escribió ninguna partición.
- El teléfono permaneció en Fastboot.
- `current-slot` permaneció en `a`.
- `product=laurel_sprout`, `unlocked=yes`, `slot-count=2`.
- **No hubo incidente transaccional.**

## Alcance de la conclusión

Se registra con precisión que **ESTE bootloader** respondió:

```
FAILED (remote: 'unknown command')
```

**No** se afirma que todos los bootloaders del Mi A3 carezcan necesariamente del
comando `fastboot boot` basándose únicamente en este intento. Lo que se registra
es que en el dispositivo ensayado, en el estado de firmware actual, el comando
`fastboot boot` no es soportado.

## Consecuencia operativa

La estrategia no destructiva mediante `fastboot boot` (arranque en RAM) está
**bloqueada en el dispositivo ensayado**. Para probar un boot.kernel/initramfs
en hardware se requiere una vía persistente controlada: escribir la imagen de
diagnóstico en una partición boot explícita (A/B), con la transacción de
recuperación documentada y autorización explícita.

## Etiquetado intencional

Este intento **no** se etiqueta como fallo de:
- kernel,
- initramfs,
- UFS,
- pantalla,
- GPU.

Ninguna de esas capas fue ejercitada: el comando `boot` fue rechazado por el
bootloader antes de transferir el control al kernel.