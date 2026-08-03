# Táctil

Estado: **inicial**. Se documenta tras la investigación upstream y las pruebas
físicas.

## Objetivo

- Controlador FocalTech FT3518.
- I2C del táctil.
- Pinctrl del táctil.
- Generación de `/dev/input/event*`.
- Coordenadas alineadas con la orientación.
- Multitouch básico.

## Criterios de `working`

Ver `docs/HARDWARE-STATUS.md`.

## Parches

En `patches/touchscreen/`. Cada parche se verifica contra upstream/sm61x5 y el
commit fijado, y se documenta su estado
(upstream/accepted/queued/pending/downstream-only/local-workaround).
