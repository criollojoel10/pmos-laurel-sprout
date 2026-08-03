# ADR-002 — Trabajo pesado exclusivamente en GitHub Actions

- Estado: **Aceptado**
- Fecha: 2026-08-02

## Contexto

La laptop del usuario (AMD Ryzen 5 4500U, 8 GB RAM) no debe realizar trabajo
pesado. Compilar kernel o rootfs localmente es lento y arriesgado.

## Decisión

Todo trabajo pesado (clonar fuentes grandes, kernel, pmbootstrap, rootfs,
boot.img) se ejecuta en runners públicos de GitHub Actions mediante
`workflow_dispatch`. Localmente solo:

- editar archivos del repositorio;
- Git y GitHub CLI;
- consultas Fastboot de solo lectura;
- análisis de texto/YAML/JSON.

## Consecuencias

- El CI tiene limitaciones de espacio; se aplican reglas de limpieza y
  compresión (xz/zstd).
- Los workflows requieren autorización para consumir minutos.
- Los artefactos se descargan cuando son pequeños.

## Alternativas consideradas

- Compilar localmente: rechazado.
- Runners privados/pagos: rechazados sin autorización.
