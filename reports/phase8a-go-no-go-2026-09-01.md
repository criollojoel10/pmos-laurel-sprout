# Matriz GO / NO-GO — preflash audit Linux 6.1

## Resultado

GO_FOR_SEPARATE_FLASH_AUTHORIZATION

## Criterios cumplidos

- hashes correctos del artefacto original y de la variante preparada;
- imagen original preservada;
- imagen preparada preservada;
- payload kernel y ramdisk byte-idéntico;
- diferencia semántica de la preparación limitada al cmdline (`consoleblank=0`);
- `consoleblank=0` ausente en el cmdline actual arrancado;
- base de Linux 6.1 viva y accesible por SSH;
- no se ejecutó flash, erase, slot change ni reboot;
- no hay escritura persistente al teléfono durante esta fase.

## Criterios pendientes

- confirmación de slot activo real;
- confirmación del AVB/boot slot actual;
- validación manual de la imagen `boot-consoleblank0.img` en hardware bajo autorización humana explícita.

## Decisión

Se autoriza la siguiente fase humana: una prueba controlada del boot con `consoleblank=0`, pero NO se ejecuta durante esta auditoría. La ejecución debe esperar autorización explícita separada.
