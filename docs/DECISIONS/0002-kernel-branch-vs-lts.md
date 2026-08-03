# DECISION-0002 — Rama estable vs LTS como base del kernel

- Estado: **Propuesta**
- Fecha: 2026-08-02

## Contexto

`pmaports` publica kernels `linux-postmarketos-qcom-*` sobre ramas
principales recientes (p. ej. 6.19.x). Las LTS (6.6.x, 6.12.x) dan
mantenimiento más largo pero suelen carecer de los últimos parches de
display/GPU para SM6125.

## Candidatos

| Base | Ventaja | Riesgo |
|---|---|---|
| mainline estable reciente (6.19.x) | parches display/GPU más nuevos | ciclo corto |
| LTS 6.12.x | mantenimiento largo | posible backport manual |
| LTS 6.6.x | máxima estabilidad | backport mayor |

## Decisión (provisional)

Usar la **rama estable que coincida con la elegida por pmaports para
SM6125** (referencia de los dispositivos soportados), con validación en
03-build-kernel. El veredicto se registra en `reports/kernel-candidates.json`
y `docs/KERNEL-BASE-COMPARISON.md` tras la primera build de referencia.

## Consecuencias

- `sources.lock.json` fija el commit concreto de la base elegida antes de
  compilar (FASE 3).
- Revisión periódica de la issue #1 de sm61x5-mainline por si aparece la
  rama estable oficial.
