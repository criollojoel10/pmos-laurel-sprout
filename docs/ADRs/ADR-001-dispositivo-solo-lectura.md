# ADR-001 — Dispositivo de solo lectura hasta autorización explícita

- Estado: **Aceptado**
- Fecha: 2026-08-02

## Contexto

El Xiaomi Mi A3 experimental puede estar conectado en Fastboot. Operaciones
destructivas (boot, flash, erase, format, set_active, reboot, oem, adb)
podrían brickear el dispositivo o borrar datos.

## Decisión

Ningún comando Fastboot/adb destructivo se ejecuta sin autorización explícita
e inmediata ANTES de cada operación. La política se codifica en:

- `AGENTS.md` sección 0.
- `opencode.json` (reglas `deny` para `adb *`, `fastboot boot/flash/erase/...`).
- `scripts/test-opencode-security-policy.sh` (verificación estática).

## Consecuencias

- Solo consultas de solo lectura (`fastboot getvar ...`) se ejecutan de forma
  autónoma.
- Cualquier prueba física pasa por la FASE 8 (punto de parada).
- Las reglas se verifican por CI en `00-quality.yml`.

## Alternativas consideradas

- Permitir `fastboot boot` automáticamente: rechazado (riesgo alto sin
  respaldos).
