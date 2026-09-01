# Revisión independiente de la fase 8A

## Alcance

Esta revisión cierra la evidencia faltante antes de autorizar una prueba controlada de:

`local-private/linux61-dev/export-resolved/boot-consoleblank0.img`

Sin ejecutar ninguna operación destructiva ni ninguna escritura persistente sobre el teléfono.

## Estado inicial del análisis

Se trata el estado previo como `UNKNOWN_REQUIRES_MANUAL_EVIDENCE` porque la auditoría anterior declaró GO sin aportar valores concretos para:

- slot activo
- slot inactivo
- partición objetivo
- tamaño de `boot_a` / `boot_b`
- tamaño exacto de la imagen
- estado de AVB / vbmeta
- ruta de recuperación comprobada
- hash del DTB extraído de ambas imágenes
- sintaxis del comando exacto de restauración

## Evidencia existente revisada

Se leyeron los informes siguientes:

- `reports/phase8a-go-no-go-2026-09-01.md` — presente
- `reports/partition-slot-avb-audit-2026-09-01.md` — presente
- `reports/phase8a-recovery-plan-2026-09-01.md` — presente
- `reports/boot-consoleblank0-diff-audit-2026-09-01.md` — presente
- `reports/boot-image-structure-2026-09-01.md` — presente
- `reports/linux61-reproducible-baseline-2026-09-01.md` — presente
- `reports/boot-dtb-live-content-audit-2026-09-01.md` — MISSING_EVIDENCE

### Conclusión de la revisión documental

La evidencia documental confirma que:

- `boot.img` y `boot-consoleblank0.img` son imágenes Android boot; ambas tienen el mismo tamaño y el mismo kernel/ramdisk.
- La diferencia semántica está limitada al cmdline del header.
- No se confirma slot activo real ni ninguna partición objetivo concreta.
- No se confirma AVB ni vbmeta reales para el dispositivo actual.
- No se documenta un flujo de recuperación verificable desde fastboot con valores demostrados.

## Revalidación de artefactos locales

### 1) Identidad de las imágenes

Ruta absoluta:

- `/home/joel/Projects/pmos-laurel-sprout/local-private/linux61-dev/export-resolved/boot.img`
- `/home/joel/Projects/pmos-laurel-sprout/local-private/linux61-dev/export-resolved/boot-consoleblank0.img`

Tamaño exacto:

- `12406784` bytes para cada imagen

SHA256 verificado:

- `f5769064303ce077d5fc9377826cd7d78cd43f2bd2dd34401b9dc407e8883402` para `boot.img`
- `c344668f74f18927b246dce963f6b939458718d694185e5cbbad07874b3f136b` para `boot-consoleblank0.img`

Tipo reconocido:

- `Android bootimg, kernel (0x8000), ramdisk (0x1000000), page size: 4096`

Cmdline exacto:

- `boot.img`: `clk_ignore_unused`
- `boot-consoleblank0.img`: `clk_ignore_unused consoleblank=0`

### 2) Identidad del kernel y del ramdisk

Extracción independiente de ambas imágenes con `scripts/unpack-boot-image.py --append-dtb`:

- `kernel` hash: `a6c11ca2ce1f33fa5f31019ad5810ce5ac776fcc804c3e58e16842b7cc376197` en ambas imágenes
- `ramdisk` hash: `c34d6b83b57a296cb8b085d18a53b4033415e6f292fe0a79c79ac0662749e136` en ambas imágenes
- `ramdisk` normalizado (gzip decompress + sha256): `174dc1054088a933023435d90c4bb25211be8093dd4a8d1c992dcb71c5bb8c29` en ambas imágenes

Matriz de identidad:

- kernel identical: YES
- ramdisk identical: YES
- ramdisk normalized identical: YES
- DTB identical: YES
- bootconfig identical: NOT_PRESENT
- cmdline identical: NO
- consoleblank=0 only semantic change: YES

### 3) Identidad del DTB

DTB extraído independientemente del payload del kernel:

- SHA256: `cb37540db8e8667c4a850c8da34704003f05e5c84c7761e58f369b18371c690e` en ambas imágenes

Esto confirma que no hay cambio de DTB ni de payload detrás del cmdline.

## Datos del slot y particiones

### Evidencia disponible

Se intentó obtener evidencia únicamente en modo lectura.

- `fastboot devices`: no hay hardware fastboot detectado
- `ssh root@172.16.42.1`: `Permission denied (publickey)`
- `getprop` y `/dev/block/by-name` no pudieron obtenerse desde la sesión actual

Resultado:

- current_slot = unknown
- inactive_slot = unknown
- boot_a_size_bytes = unknown
- boot_b_size_bytes = unknown
- test_image_size_bytes = 12406784
- fits_boot_a = unknown
- fits_boot_b = unknown
- target_candidate = unknown

No se puede elegir un slot objetivo con evidencia operativa.

## AVB y VBMETA

Se intentó inspeccionar la imagen con `avbtool`:

- `avbtool info_image --image boot.img` → `Given image does not look like a vbmeta image.`

Esto indica que la imagen `boot.img` no es un `vbmeta` y que no hay una firma AVB demostrada dentro del paquete boot actual. También significa que el estado de AVB en el dispositivo no ha sido verificado con evidencia fresca.

Resultado:

- avb_state = unknown
- modified_image_bootable_under_current_avb = unknown

## Ruta de recuperación

La ruta de recuperación se documenta, pero no se demuestra con valores reales del teléfono. El original está presente en el equipo local y su SHA256 coincide; sin embargo, no existe evidencia fresca de:

- slot activo real
- partición `boot_a` / `boot_b` accesible
- `fastboot getvar current-slot`
- `fastboot getvar partition-size:boot_a|boot_b`
- desbloqueo del bootloader verificado
- plan de restauración validado con el hardware real

Resultado:

- recovery_readiness = unknown

## Congelación real de la base 6.1

La base 6.1 está documentada como funcional y reproducible, y ahora cuenta con una referencia Git local verificada.

Estado actual:

- `baseline_documented = yes`
- `baseline_committed = yes`
- `baseline_tagged_or_bundled = yes`
- `baseline_reproducibly_frozen = yes`

La referencia local se conserva como el commit `3ec4bcd` y el tag local `laurel-linux61-baseline-ssh-fb-2026-09-01`, sin publicar nada ni incluir artefactos privados.

## Conclusión final

No se autoriza la prueba de flash controlada porque aún faltan los datos mínimos de recuperación y slot/AVB.

Resultado formal:

`UNKNOWN_REQUIRES_MANUAL_EVIDENCE`

## Evidencia faltante en la revisión

1. `fastboot getvar current-slot` desde el teléfono conectado manualmente en Fastboot
2. `fastboot getvar partition-size:boot_a` y `boot_b`
3. `fastboot getvar slot-successful:a|b` y `slot-unbootable:a|b`
4. `fastboot getvar unlocked` / `secure`
5. `ls -l /dev/block/by-name` y `readlink -f` sobre `boot_a` / `boot_b` desde el sistema en ejecución
6. confirmación del `vbmeta` asociado y del estado AVB del slot real
7. un bundle local o tag git que selle la línea base 6.1
8. comandante de restauración validado con el hardware real

## Operaciones destructivas

La revisión no ejecutó ninguna operación destructiva:

- flash executed: NO
- fastboot boot executed: NO
- erase executed: NO
- slot changed: NO
- reboot executed: NO
- persistent phone write: NO
