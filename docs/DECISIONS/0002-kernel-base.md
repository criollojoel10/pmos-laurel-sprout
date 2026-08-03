# DECISION-0002 — Base del kernel: Linux mainline v7.1

- Estado: **Decidido** (2026-08-03)
- Reemplaza/añade a: DECISION-0001 (mainline, a confirmar) → ahora confirmado
  con versión concreta.

## Contexto

La investigación M1 (2026-08-03) verificó que el soporte de laurel_sprout
(panel S6E8FC0, táctil FT3518, MDSS) está ACEPTADO en Linux mainline:

- Panel driver: v7.1 (`49837b6babe7`)
- FT3518 driver/bindings: v7.0 (`5383e76483dc` / `9b352327add1`)
- MDSS core resets (sm6125/sm6115): v7.1
- DTS "Enable MDSS and add panel": solo en v7.2/master, y con el typo
  `s6e8fco` que no coincide con el driver (`s6e8fc0`).

sm61x5-mainline master (7a52441d) NO tiene panel/touch/GPU. La rama dev
(`barni2000/6.19-develop`) lo tiene todo pero es inestable (base 6.19).

## Decisión

Usar como base **Linux mainline v7.1 estable**, tag
`v7.1` = commit `b3f94b2b3f3e51ab880a51fc6510e1dafba654ed`, descargado desde
https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git (tarball o
git), fijado por SHA-256 en `sources.lock.json`.

Parches downstream obligatorios (se aplican como parches con origen
registrado, según AGENTS.md sección 6):

1. **DTS Enable MDSS + panel**: portar del commit upstream `493cb869874c`
   PERO con el compatible corregido a `samsung,s6e8fc0-m1906f9` (el commit
   upstream tiene el typo `s6e8fco`). Origen: sm61x5 dev / lore v5+.
2. **DTS GPU (adreno-610)**: nodo `gpu@5900000` en sm6125.dtsi + enable en
   laurel (`&gpu`, `&adreno_smmu`, `&gpucc`, zap-shader firmware
   `qcom/sm6125/xiaomi/laurel/a610_zap.mbn`). Origen: sm61x5 dev
   (`92aacc57f7`).
3. Auditoría en CI de cualquier otro commit sm61x5 dev que v7.1 no incluya.

## Consecuencias

- La build es reproducible (tag fijado + SHA-256).
- El typo upstream se corrige en nuestro DTS local (local-workaround),
  documentado; si el fix llega a mainline, se elimina el parche.
- No dependemos de la issue #1 de sm61x5-mainline (release).
- El GPU necesita el firmware `a610_zap.mbn` (blob, no GPL) → se instala vía
  paquete de firmware (no dentro del kernel).

## Alternativas consideradas

- v7.2-rc6/master: DTS panel presente pero con typo; no estable. Rechazada.
- sm61x5 barni2000/6.19-develop: todo aplicado pero base 6.19 y rama dev.
  Rechazada como base; se usa SOLO como fuente de parches.
- LTS 6.12/6.6: backport grande de panel/touch/MDSS. Rechazada.
