# Comparativa de bases de kernel

Estado: decisión tomada (2026-08-03, investigación M1 completa).

## Hechos verificados (2026-08-03)

- Linux mainline ha pasado a numeración 7.x: v6.19 fue la última de la serie 6.x
  (tag v6.19 = 2026-02-08). v7.0 = 2026-04-12, v7.1 = 2026-06-14 (stable),
  master = v7.2-rc6 (2026-08-03).
- Panel S6E8FC0 driver en mainline desde **v7.1** (commit `49837b6babe7`).
- FT3518 touch driver + bindings en mainline desde **v7.0**
  (driver `5383e76483dc`, bindings `9b352327add1`).
- DTS "Enable MDSS and add panel" (`493cb869874c`) NO está en v7.1; está en
  v7.2/master. Además, en master el DTS usa `s6e8fco` (typo, letra O) que NO
  coincide con el driver (`s6e8fc0`, cero) → bug upstream pendiente de fix.
  El commit `493cb869874c` se aplicó desde la **v4** del patchset (20260314),
  que aún tenía el typo; la corrección fue en v5 (2026-03-17).
- Nodo `gpu@5900000` (adreno-610) en sm6125.dtsi: NO está en mainline; es
  **downstream-only** en sm61x5-mainline (rama dev, commit `92aacc57f7`).
  El driver msm/adreno mainline SÍ soporta a610 (`adreno_is_a610`) y las
  bindings `gpu.yaml` aceptan `qcom,adreno-610.0`.
- sm61x5-mainline master (`7a52441d`, 2026-05-25): DTS laurel 413 líneas, sin
  panel ni touch (no tocado desde 2024-06-07). edt-ft5x06.c presente pero SIN
  soporte FT3518. `sm61x5_defconfig` NO existe en master.
- sm61x5-mainline `barni2000/6.19-develop`: DTS laurel 664 líneas con panel
  (`s6e8fc0` correcto) + FT3518 + GPU enable + RTC; `sm61x5_defconfig` existe
  (commit `727f79bb9ca0`, 2026-03-30). Rama de desarrollo, no estable.
- pmaports: `linux-postmarketos-qcom-sm6125` está **archivado** (base 6.1,
  commit `77de535b`, árbol sm6125-mainline). El kernel sm6125 activo de
  referencia usa base 6.1. Ejemplo moderno: `linux-postmarketos-qcom-sm6350`
  en community usa pkgver `7.0.8` (mainline 7.x).

## Candidatos

| # | Base | Origen | Ventaja | Riesgo | Estado |
|---|---|---|---|---|---|
| A | mainline v7.1 (tag b3f94b2b...) | kernel.org | panel+FT3518+MDSS resets ya incluidos; estable y reproducible | necesita parches DTS GPU/MDSS downstream | **ELEGIDA** |
| B | mainline master v7.2-rc6 | kernel.org | DTS panel presente | DTS con typo s6e8fco (bug), no estable | rechazada |
| C | LTS 6.12.x | kernel.org | mantenimiento largo | backport manual de panel/touch/MDSS | rechazada |
| D | barni2000/6.19-develop | codeberg | todo aplicado | rama dev inestable; base 6.19 | rechazada (fuente de parches) |
| E | sm61x5-mainline master | codeberg | árbol del ecosistema | sin panel/touch/GPU; sin defconfig | rechazada |

## Criterios de decisión

1. pmaports archiva sm6125; los kernels qcom modernos usan mainline 7.x.
2. Nº de parches a portar: v7.1 es la base con menor trabajo (solo DTS).
3. Toolchain/año: mainline 7.1 es lo que soporta el ecosistema.

## Veredicto

**Base: Linux mainline v7.1** (tag `v7.1` = commit `b3f94b2b3f3e51ab880a51fc6510e1dafba654ed`).
Parches downstream (del árbol sm61x5 dev, ya upstream o FROMLIST):
- DTS: Enable MDSS + panel (con compatible corregido `s6e8fc0`, NO el typo
  `s6e8fco` del mainline master).
- DTS: nodo `gpu@5900000` + Enable GPU en laurel (firmware `a610_zap.mbn`).
- Cualquier otro cambio sm61x5 que v7.1 no tenga (se audita en CI).

Referencia: `reports/kernel-candidates.json`, `docs/DECISIONS/0002-kernel-base.md`.
