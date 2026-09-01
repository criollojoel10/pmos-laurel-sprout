# Auditoría de particiones, slot y AVB (solo lectura)

## Estado

No se ejecutó `fastboot` ni inspección de particiones del teléfono por escritura; la auditoría se limita a la evidencia del árbol del proyecto y a la observación del dispositivo en Linux 6.1.

## Evidencia disponible

- El proyecto documenta que hay A/B slots y particiones `boot_a`/`boot_b`, `dtbo_a`/`dtbo_b`, `vbmeta_a`/`vbmeta_b`.
- El dispositivo actual está arrancado y la evidencia del sistema documenta `boot_b` como el slot de la base histórica en varias pruebas del repositorio.
- No hubo validación fresca de `fastboot getvar current-slot` ni de `fastboot getvar all` durante esta fase.

## Resultado formal

- Slot activo real: UNKNOWN_REQUIRES_MANUAL_EVIDENCE
- Slot inactivo real: UNKNOWN_REQUIRES_MANUAL_EVIDENCE
- AVB: UNKNOWN_REQUIRES_MANUAL_EVIDENCE
- Ruta de recuperación: READY_ONLY_IF_STOCK_BACKUP_EXISTS

## Convención aplicada

La ruta de recuperación no se autoriza ni se ejecuta. Se documenta únicamente como requisito previo para cualquier prueba futura.
