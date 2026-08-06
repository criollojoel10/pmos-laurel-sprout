# First boot intent — resultado (H0)

Estado: `FASTBOOT_BOOT_COMMAND_UNSUPPORTED`

## Contexto

- Fecha UTC: 2026-08-04
- Dispositivo: Xiaomi Mi A3 `laurel_sprout`
- Método: `fastboot boot` (boot en RAM, no escribe flash)
- Artefacto: `boot-laurel-diagnostic.img` (run CI `30916017707`)
  SHA256 `66e7005fa031dd4f3117c56b9fa01f2c123377c95604a0975edd343cf6090b9d`

## Resultado del dispositivo (exacto, sanitizado)

```
Sending 'boot.img' (20996 KB)  OKAY [  0.482s]
Booting                                                      FAILED (remote: 'unknown command')
fastboot: error: Command failed
```

## Interpretación

- La transferencia del boot.img fue **aceptada** (OKAY).
- El fallo ocurrió al solicitar el comando Fastboot `boot`.
- **No hubo ejecución del kernel.**
- **No hubo evaluación física del initramfs.**
- No hubo rechazo demostrado del contenido del boot.img.
- No se escribió ninguna partición.
- El teléfono permaneció en Fastboot.
- `current-slot` siguió siendo `a`.
- `product=laurel_sprout`, `unlocked=yes`, `slot-count=2`.

## Alcance de la conclusión

Se registra con precisión que **ESTE bootloader** respondió:

```
FAILED (remote: 'unknown command')
```

No se afirma que todos los bootloaders Mi A3 carezcan necesariamente de
`fastboot boot` basándose únicamente en este intento.

## No clasificar como

Este intento **NO** se etiqueta como fallo de:
- kernel,
- initramfs,
- UFS,
- pantalla,
- GPU.

Ninguna de esas capas fue ejercitada: el comando `boot` fue rechazado por el
bootloader antes de transferir el control al kernel.

## Consecuencia

La vía no destructiva `fastboot boot` está **bloqueada en el dispositivo
ensayado**. Para probar el kernel/initramfs en hardware se requiere una vía
persistente controlada escribiendo el boot image en una partición boot
explícita (A/B), con recuperación documentada y autorización explícita
(FASE 8).