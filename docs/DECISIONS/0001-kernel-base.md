# DECISION-0001 — Base del kernel: Linux mainline (no sm61x5/6.19.5)

- Estado: **Propuesta** (a confirmar tras 03-build-kernel)
- Fecha: 2026-08-02

## Contexto

La hipótesis inicial era usar la rama `sm61x5/6.19.5` y el tag
`v6.19.5-r0` de `sm61x5-mainline/linux` como base. La auditoría (2026-08-02)
verificó que:

- No existe la rama `sm61x5/6.19.5` (ls-remote: solo `master`,
  `barni2000/6.19-develop`, `barni2000/7.0-develop`).
- No existe el tag `v6.19.5-r0`.
- No existe `sm61x5_defconfig` en `arch/arm64/configs`.
- La issue #1 de `sm61x5-mainline` ("Create a stable branch and release")
  sigue abierta; las tareas de tag, release branch y defconfig están sin
  completar.

## Decisión

Usar como base **Linux mainline estable o LTS** (a decidir en DECISION-0002),
aplicando los parches necesarios de `sm61x5-mainline` como parches
downstream (pendiente o local-workaround), registrados según AGENTS.md sección 6.

La base `sm61x5-mainline` se mantiene como referencia `master` fijada por
commit (`7a52441d...`, 2026-05-25) en `sources.lock.json`, pero NO como
árbol de kernel completo.

## Consecuencias

- No se espera a que la issue #1 se cierre.
- El flujo debe mantener un registro de parches (`docs/PATCH-PLAN.md`) y
  re-verificar periódicamente si la rama estable aparece.
- `sm61x5_defconfig` no existe: la configuración se arma con fragments
  propios sobre la defconfig base del SoC (SM6125/trinket).

## Alternativas consideradas

- Esperar a `sm61x5/6.19.5`: rechazado (no existe y no hay fecha).
- Basarse directamente en `barni2000/6.19-develop`: descartado como base de
  build (rama de desarrollo, no estable), pero es fuente de parches.
