# DECISION-0007 — Registro honesto de estados de hardware

- Estado: **Aceptado**
- Fecha: 2026-08-02

## Contexto

AGENTS.md sección 2 exige estados honestos y prohíbe declarar que algo
funciona porque compila. La ampliación de la auditoría añade un registro de
hipótesis para distinguir hechos verificados de suposiciones.

## Decisión

- `reports/hardware-matrix.json` mantiene los estados permitidos de AGENTS.md
  (`not-targeted` ... `working`).
- `reports/hypothesis-registry.json` registra hipótesis con estados:
  `confirmed`, `refuted`, `needs-reverification`, `unverified`, `deferred`.
- Ningún componente pasa de `not-targeted` sin evidencia física o de boot
  (FASE 8/09 con autorización).
- `docs/HARDWARE-STATUS.md` y `reports/evidence-matrix.json` se actualizan al
  cambiar un estado.

## Consecuencias

- Las suposiciones quedan marcadas como `needs-reverification`, no como
  hechos.
- Evita la confusión documentada en AGENTS.md (KGSL vs DRM/MSM, llvmpipe vs
  GPU, DPU vs aceleración 3D).

## Alternativas consideradas

- Un solo archivo de estado: rechazado (mezcla hechos y suposiciones).
