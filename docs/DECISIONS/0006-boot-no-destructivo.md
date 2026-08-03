# DECISION-0006 — Estrategia de boot no destructiva (fastboot boot)

- Estado: **Propuesta**
- Fecha: 2026-08-02

## Contexto

El dispositivo está en Fastboot y es de SOLO LECTURA hasta autorización.
La estrategia inicial debe probar mainline sin escribir flash permanente.

## Decisión

Usar `fastboot boot` (boot en RAM) como método preferido de prueba, con
imagen `boot.img` v2+ que incluya el DTB (QCDT) para no depender de la
partición dtbo. No se borra ni `dtbo` ni `vbmeta`. No se toca el slot
activo.

- Detalles operativos: `docs/NON-DESTRUCTIVE-BOOT.md`.
- Ayudante de dry-run: `scripts/flash-helper.sh` (no ejecuta fastboot;
  valida argumentos e imprime plan).
- Ninguna automatización invoca fastboot; la ejecución es manual y con
  autorización (FASE 8).

## Consecuencias

- `boot.img` debe llevar el DTB mainline embebido (`verify-dtb.sh`).
- Si el bootloader exige `dtbo`, se detecta en la primera prueba y se
  reevalúa con `fastboot boot` igualmente (no destructivo).
- La FASE 8 (parada obligatoria) sigue vigente antes de cualquier flash.

## Alternativas consideradas

- Flash directo en `boot_a`/`boot_b`: rechazado (destructivo sin respaldos).
- Borrar `dtbo`/`vbmeta`: rechazado (innecesario si se usa boot con DTB
  integrado; y destructivo).
