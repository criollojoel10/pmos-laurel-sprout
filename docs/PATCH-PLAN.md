# Plan de parches

Estado: actualizado (2026-08-03, parches downstream v1 creados).

## Parches downstream en el repositorio (patches/kernel/)

Base: Linux mainline v7.1 (decisión 0002). Aplicados por
`scripts/build-kernel.sh` / `scripts/apply-kernel-patches.sh` con `git apply`.

| # | Archivo | Contenido | Origen | Estado |
|---|---|---|---|---|
| K1 | `0001-dts-mdss-panel-s6e8fc0.patch` | Enable MDSS/DSI + panel S6E8FC0 en DTS de placa, con compatible CORREGIDO `s6e8fc0` + `&dispcc` status okay | port de mainline `493cb869874c` (typo `s6e8fco` corregido) + `&dispcc` de sm61x5 7.0-develop | downstream (fix local del typo upstream) |
| K2 | `0002-dtsi-gpu-adreno610.patch` | Nodos GPU en `sm6125.dtsi`: `gpu@5900000`, `gmu_wrapper@596a000`, `gpucc@5990000`, `adreno_smmu@59a0000` (1-cell, `RPMPD_VDDCX`) | sm61x5-mainline barni2000/7.0-develop (c41e0655) | downstream-only |
| K3 | `0003-dts-enable-gpu.patch` | Enable GPU + zap-shader `qcom/sm6125/xiaomi/laurel/a610_zap.mbn` en DTS de placa | sm61x5-mainline barni2000/7.0-develop | downstream-only (GPU fase 2) |

Los tres parches aplican limpios en secuencia sobre v7.1 (verificado con
`git apply --check` en árbol de prueba).

Nota K3: el firmware `a610_zap.mbn` aún no está empaquetado (fase de
firmware). Sin zap, la GPU no arranca con aceleración pero el sistema sigue
booting con llvmpipe.

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

Hallazgo M1b (2026-08-03): existe la rama `barni2000/7.0-develop` (base
**7.0.8 estable**) con TODO el soporte laurel (panel `s6e8fc0`, GPU,
FT3518, `sm61x5_defconfig`). Es el análogo exacto del patrón pmaports
`linux-postmarketos-qcom-sm6350` (fork mainline a 7.0.8). Se usa como
**fuente autoritativa de parches**; no como base de build por sus commits
`fixup!`/`HACK`. Ver `docs/DTS-AUDIT.md`.

## Proceso (obligatorio)

1. Verificar si el parche ya está en la base (git log).
2. Verificar si está en `sm61x5-mainline` master.
3. `git apply --check`.
4. Registrar origen, licencia, autoría y Signed-off-by.
5. Evitar duplicados.
6. Documentar estado en este archivo.

## Notas

- Con una base mainline reciente (v7.0+), los parches de panel/táctil ya
  están dentro y solo quedan los downstream (K1-K3).
- Si el proyecto sm61x5-mainline publica una release estable (issue #1), se
  reevaluará si conviene cambiar la base a su fork (como pmaports hace con
  sm6350-mainline).
