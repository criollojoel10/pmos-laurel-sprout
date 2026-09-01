# Plan de recuperación para pruebas futuras (no ejecutado)

## Principio

No se ejecuta ninguna operación de cambio ni flash. Este plan solo documenta la recuperación de la línea base existente.

## Baseline conocida

El boot original ya validado en el repositorio tiene SHA256:

`f5769064303ce077d5fc9377826cd7d78cd43f2bd2dd34401b9dc407e8883402`

## Requisitos previos

- preservar `boot.img` original y `system_b` intactos;
- confirmar slot activo y partición objetivo con lectura explícita antes de cualquier cambio;
- asegurar respaldo de `boot_a/b`, `dtbo_a/b` y `vbmeta_a/b`;
- disponer del procedimiento de recuperacion del fabricante o del proyecto;
- no borrar `userdata`, `metadata` ni `persist`.

## Ruta de recuperación documentada

1. confirmar que el dispositivo sigue arrancando en el slot original;
2. confirmar que la imagen original de boot coincide con el SHA256 registrado;
3. restaurar el slot mismo que se hubiera probado;
4. si el bootloader lo permite, volver al slot original;
5. si se pierde la consola, usar la recuperación manual documentada por el proyecto y conservar logs sanitizados.

## Restricción

No se ejecuta ni se recomienda ningún comando de flash, erase o slot switching en esta fase.
