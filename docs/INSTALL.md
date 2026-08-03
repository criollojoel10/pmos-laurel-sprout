# Instalación

> Este documento describe el procedimiento de instalación. NINGÚN paso se
> ejecuta automáticamente: requiere autorización explícita en cada operación
> destructiva, respaldos previos y verificación de hashes.

## Advertencias generales

- Este port es experimental. Puede brickear el dispositivo o borrar datos.
- No usar en el teléfono principal.
- Tener respaldos completos antes de flashear (ver `docs/RECOVERY.md`).
- El dispositivo debe estar en Fastboot y el bootloader desbloqueado
  (verificado, no asumido).

## 0. Identificar estado del dispositivo (solo lectura)

```
fastboot devices
fastboot getvar current-slot
fastboot getvar unlocked
```

No continúes si `unlocked` no es `yes`.

## 1. Verificación de hashes

Descarga las imágenes y verifica:

```
sha256sum -c SHA256SUMS
```

Nunca flashees una imagen con hash incorrecto.

## 2. Método preferido: arranque temporal (`fastboot boot`)

Si el dispositivo y el formato lo admiten, esta es la prueba menos
destructiva. No cambia particiones:

```
fastboot boot boot-laurel-release.img
```

PUNTO DE PARADA: antes de ejecutarlo, confirma respaldos y slot actual, y
mantén un plan de recuperación.

## 3. Flasheo persistente (solo con respaldos)

> Cada comando toca particiones específicas. Se recomienda probar UNA
> variable a la vez. No se debe borrar `dtbo` ni escribir `vbmeta` sin
> entender las implicaciones (ver `docs/RECOVERY.md`).

Ejemplo de flasheo mínimo (verificar tamaños reales y slot primero):

```
fastboot flash boot_a boot-laurel-release.img
```

Señala en tu registro exactamente qué partición toca cada comando.

## Qué NO hacer

- No `fastboot erase dtbo` sin verificación previa.
- No escribir `vbmeta` si no es estrictamente necesario.
- No formatear `userdata` en la primera prueba.
- No combinar boot+dtbo+vbmeta+userdata en una sola operación.
- No usar comandos destructivos sin respaldos y autorización.

## Restauración

Ver `docs/RECOVERY.md`. Nunca proponer restaurar `persist`, `modemst`, `fsg`,
`fsc` o EFS salvo un caso concreto verificado.
