# DECISION-0005 — Compatible del panel: samsung,s6e8fc0-m1906f9

- Estado: **Aceptado**
- Fecha: 2026-08-02

## Contexto

El panel del laurel_sprout es `s6e8fc0-m1906f9`. La corrección v2 de
Yedaya Katsman (2026-06-08, Message-Id
`<20260608-b4-compatible-s6e8fc0-fixup-v2-1-d23f373603a3@gmail.com>`) cambia
en `arch/arm64/boot/dts/qcom/sm6125-xiaomi-laurel-sprout.dts` el compatible
`"samsung,s6e8fco-m1906f9"` (typo: O en vez de 0) por
`"samsung,s6e8fc0-m1906f9"`.

## Decisión

Todo DTS/parche que toque el panel debe usar `samsung,s6e8fc0-m1906f9`
(con CERO). El driver del panel debe hacer `match` contra ese compatible.

## Consecuencias

- El `docs/DISPLAY.md` y el `reports/patch-audit.md` documentan el nombre
  canónico para evitar reintroducir el typo.
- Al auditar parches (`scripts/audit-patches.sh`), se verifica que no exista
  la variante con "o".

## Alternativas consideradas

- Mantener el typo y normalizarlo en el driver: rechazado (rompe consistencia
  y el fix ya está upstream).
