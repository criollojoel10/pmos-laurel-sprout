# Plan de parches

Estado: actualizado (2026-08-03, investigación M1 completa).

## Convención de estado

`upstream` / `accepted` / `queued` / `pending` / `downstream-only` /
`local-workaround`.

## Parches candidatos

| # | Parche | Origen | Estado upstream | Relevancia |
|---|---|---|---|---|
| P1 | Fix compatible panel `s6e8fc0` (v5 del patchset, Yedaya Katsman, 2026-03-17) | mainline | **accepted** (mainline v7.1, `49837b6babe7`) | display |
| P2 | Enable MDSS + panel (v7, Yedaya Katsman, 2026-03-20) | mainline | **accepted** (mainline v7.1, `493cb869874c`) | display |
| P3 | DTS initial support laurel_sprout (Lux Aliaga, 2023) | mainline | accepted (presente en sm61x5 master) | DTS base |
| P4 | Soporte touchscreen FT3518 (edt-ft5x06, Yedaya Katsman) | mainline | **accepted** (mainline v7.0, `5383e76483dc`; DTS `8cbbb339048a`) | táctil |
| P5 | Parches de sm61x5-mainline no presentes en la base elegida | codeberg | downstream | varios |
| P6 | Enable GPU laurel + fix a610 highest_bank_bit | sm61x5/SzczurekYT | downstream (parte en mainline) | GPU |

Hallazgo M1: panel y FT3518 están **aceptados en Linux mainline** (v7.0/v7.1).
No están en sm61x5-mainline master (7a52441d) pero SÍ en la rama
`barni2000/6.19-develop` (backports upstream). Si la base elegida es mainline
reciente, P1/P2/P4 no requieren parches externos. Ver
`docs/PANEL-PATCH-HISTORY.md` y `docs/TOUCHSCREEN-PATCH-HISTORY.md`.

## Proceso (obligatorio)

1. Verificar si el parche ya está en la base (git log).
2. Verificar si está en `sm61x5-mainline` master.
3. `git apply --check`.
4. Registrar origen, licencia, autoría y Signed-off-by.
5. Evitar duplicados.
6. Documentar estado en este archivo.

## Notas

- Con una base mainline reciente (v7.0+), los parches de panel/táctil ya
  están dentro y solo quedarán los downstream de sm61x5-mainline.
- Al cerrarse la issue #1 de sm61x5-mainline (release), se reevaluará si
  conviene cambiar de base.
