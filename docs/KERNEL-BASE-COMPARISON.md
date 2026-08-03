# Comparativa de bases de kernel

Estado: registro inicial (2026-08-02). Se completa tras la primera build de
referencia (03-build-kernel).

## Hechos verificados (2026-08-02)

- `sm61x5-mainline/linux` no tiene rama `sm61x5/6.19.5`, ni tag
  `v6.19.5-r0`, ni `sm61x5_defconfig` (issue #1 abierta).
- HEAD de `master`: `7a52441d10af679e27711b554411aa31a06aea67`
  (2026-05-25).
- Ramas de desarrollo: `barni2000/6.19-develop`
  (`ae0eeba941898004657ab5335cabb4e342f7df49`) y
  `barni2000/7.0-develop` (`c41e06558608c7efacc3ef493d101efc37b2173a`).

## Candidatos

| # | Base | Origen | Ventaja | Riesgo | Estado |
|---|---|---|---|---|---|
| A | mainline estable 6.19.x | kernel.org | parches display/GPU recientes | ciclo corto | pendiente de evaluar |
| B | LTS 6.12.x | kernel.org | mantenimiento largo | backport manual | pendiente |
| C | LTS 6.6.x | kernel.org | máxima estabilidad | backport mayor | pendiente |
| D | barni2000/6.19-develop | codeberg | parches laurel ya aplicados | inestable (dev) | no como base |

## Criterios de decisión

1. ¿Cuál usa pmaports para `linux-postmarketos-qcom-sm6125`?
2. ¿Cuántos parches de sm61x5-mainline hay que portar a cada base?
3. ¿Soporta la toolchain/año en pmaports?

## Veredicto

Pendiente: `reports/kernel-candidates.json` y DECISION-0002.
