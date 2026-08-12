# FASE 8 — Preflight baseline fisico Linux 6.1

Estado: **PREPARADO, NO EJECUTADO**.

Este documento no autoriza ninguna escritura. La imagen preferida debe ser la
variante con `consoleblank=0`, porque la evidencia fisica demostro que el boot
original pierde la imagen despues de aproximadamente 600 s aunque el sistema
continua accesible por SSH.

## Artefactos

Se producira en CI mediante `16-build-linux61-baseline.yml`, usando el artefacto
`historical-rootfs-ssh` del run `31355730519`. El directorio local con los
artefactos del run final `31563265029` es
`local-private/linux61-baseline-31563265029/`:

- boot original: `boot-linux61-original.img`;
- boot preferido: `boot-linux61-baseline-consoleblank0.img`;
- rootfs comprimido: `xiaomi-laurel-ssh.img.xz` (descomprimir antes de flashear);
- hashes: `SHA256SUMS`;
- manifest: `manifest.json`.

La run final de empaquetado es `31563265029`. El boot que contiene ese artefacto
proviene del export del run SSH y, antes del parche de cmdline, tiene SHA-256
`5b03b8847f449bf740a7e648f705163f491ecb346e55750475eb7321227d5ac1`. La
variante baseline generada tiene SHA-256
`41ed6045f5b587f4917fa24e1e00b5710c9e7fab088212ab98f9979a9c4f6056`.

El boot fisico original conocido mide 12,402,688 B y tiene SHA-256
`3b692fefa4836246634955318232f416502a3ac316f403736a489ab9edf7b5fb3`.
No es byte-identico al boot del nuevo baseline y por eso el nuevo artefacto
permanece `boot-untested`.
El rootfs SSH mide 550,935,480 B sin comprimir y tiene SHA-256
`ebc8287f277d8ffd28c5eb128e1248e668e44a316cb4484916d0748d5bc40a2a`.

## Requisitos antes de probar

- firmware stock identificado;
- slot actual y tamaños reales de boot/dtbo/vbmeta A y B;
- boot/dtbo/vbmeta A y B respaldados;
- `persist`, modemst1, modemst2, fsg, fsc y EFS respaldados según el procedimiento
  del proyecto;
- procedimiento de restauracion verificado;
- rootfs descomprimido localmente y hash comprobado;
- particiones objetivo confirmadas: `boot_b` y `system_b` solamente;
- no tocar `dtbo`, `vbmeta` ni cambiar slot en esta primera prueba;
- descomprimir el rootfs antes de flashear:
  `xz -dk local-private/linux61-baseline-31563265029/xiaomi-laurel-ssh.img.xz`
  (genera `xiaomi-laurel-ssh.img` y permite comprobar su SHA-256
  `ebc8287f277d8ffd28c5eb128e1248e668e44a316cb4484916d0748d5bc40a2a`).

## Comando preparado

COMANDO PREPARADO, NO EJECUTADO:

```text
fastboot flash boot_b local-private/linux61-baseline-31563265029/boot-linux61-baseline-consoleblank0.img
```

COMANDO PREPARADO, NO EJECUTADO:

```text
fastboot flash system_b local-private/linux61-baseline-31563265029/xiaomi-laurel-ssh.img
```

La primera prueba recomendada es la menos destructiva disponible. El bootloader
de este dispositivo no acepto `fastboot boot` en pruebas anteriores, por lo que
la estrategia persistente solo puede considerarse tras completar todos los
respaldos de FASE 8 y revisar la recuperacion.

## Criterios de aceptacion

- pantalla visible durante al menos 60 minutos sin blanking;
- `usb0`/RNDIS enumera y `172.16.42.1` responde;
- SSH root por clave funciona, sin password authentication;
- tres arranques independientes con el mismo artefacto;
- dmesg y cmdline recuperables (vía SSH); pstore queda pendiente hasta añadir
  `CONFIG_PSTORE_RAM=y` en el kernel 6.1 (config actual solo tiene
  `CONFIG_EFI_VARS_PSTORE`, sin backend RAM para este arranque);
- UFS sin errores graves;
- ningun panic, oops, SError ni watchdog reset.

Hasta cumplirlos, el estado es `packaged`, `static-validation-passed` o
`boot-untested`; nunca `working`.
