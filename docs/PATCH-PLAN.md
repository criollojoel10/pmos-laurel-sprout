# Plan de parches

Estado: actualizado con CI (2026-08-03, run 30775362988, commit f9e3513).

## Convención de estado

`upstream` / `accepted` / `queued` / `pending` / `downstream-only` /
`local-workaround`.

## Parches candidatos

| # | Parche | Origen | Estado upstream | Relevancia |
|---|---|---|---|---|
| P1 | Fix compatible panel `s6e8fc0` (v2, Yedaya Katsman, 2026-06-08) | lore.kernel.org | pending (NO en sm61x5 master, confirmado por CI) | display |
| P2 | Enable MDSS + panel (v3, Yedaya Katsman, 2026-03) | lore.kernel.org | pending (NO en sm61x5 master, confirmado por CI) | display |
| P3 | DTS initial support laurel_sprout (Lux Aliaga, v6/v7 2023) | mainline | accepted (presente en sm61x5 master) | DTS base |
| P4 | Soporte touchscreen FT3518 | por localizar (NO en sm61x5 master) | por verificar | táctil |
| P5 | Parches de sm61x5-mainline no presentes en la base elegida | codeberg | downstream | varios |

CI confirmó que ni el DTS de panel ni el driver de panel/táctil están en
sm61x5-mainline master (7a52441d): P1, P2 y P4 deben recuperarse de ramas
`barni2000/*` (p. ej. `barni2000/6.19-develop`) o de lore.kernel.org, y
verificarse antes de aplicar.

## Proceso (obligatorio)

1. Verificar si el parche ya está en la base (git log).
2. Verificar si está en `sm61x5-mainline` master.
3. `git apply --check`.
4. Registrar origen, licencia, autoría y Signed-off-by.
5. Evitar duplicados.
6. Documentar estado en este archivo.

## Notas

- Con la base mainline (DECISION-0001), la mayoría de los parches de
  sm61x5-mainline serán `downstream-only` o `local-workaround`.
- Al cerrarse la issue #1 de sm61x5-mainline (release), se reevaluará si
  conviene cambiar de base.
