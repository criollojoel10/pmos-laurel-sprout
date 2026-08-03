# Decisiones de arquitectura (ADR)

Registro de decisiones relevantes del proyecto. Cada decisión también queda
reflejada en `reports/evidence-matrix.json`.

| ID | Título | Estado | Fecha |
|---|---|---|---|
| [ADR-001](ADR-001-dispositivo-solo-lectura.md) | Dispositivo de solo lectura hasta autorización explícita | Aceptado | 2026-08-02 |
| [ADR-002](ADR-002-trabajo-pesado-gha.md) | Trabajo pesado exclusivamente en GitHub Actions | Aceptado | 2026-08-02 |
| [ADR-003](ADR-003-opencode-permission-singular.md) | opencode.json usa `permission` (singular) según schema oficial | Aceptado | 2026-08-02 |
| [ADR-004](ADR-004-acciones-fijadas-sha.md) | Acciones externas fijadas por SHA completo | Aceptado | 2026-08-02 |

## Cómo proponer un ADR nuevo

1. Crear `docs/ADRs/ADR-NNN-titulo-corto.md`.
2. Estado inicial `propuesto`.
3. Discutir y marcar `aceptado` o `rechazado`.
4. Actualizar `reports/evidence-matrix.json`.
