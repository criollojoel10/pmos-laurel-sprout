# DECISION-0004 — Fuentes en gitlab.postmarketos.org (pmaports/pmbootstrap)

- Estado: **Aceptado**
- Fecha: 2026-08-02

## Contexto

La auditoría (2026-08-02) confirmó que `pmaports` y `pmbootstrap`
migraron de `gitlab.com` a `gitlab.postmarketos.org`, y su rama por defecto
es `main` (no `master`).

Verificado por `git ls-remote`:
- pmaports: `https://gitlab.postmarketos.org/postmarketOS/pmaports.git`,
  HEAD `9cdff6e1...` (2026-08-02), rama `main`.
- pmbootstrap: `https://gitlab.postmarketos.org/postmarketOS/pmbootstrap.git`,
  HEAD `ea17c149...` (2026-07-31), rama `main`.

## Decisión

Usar exclusivamente las URLs de `gitlab.postmarketos.org` en
`scripts/research-upstream.sh`, `sources.lock.json` y los workflows.
`gitlab.com` queda como referencia histórica únicamente.

## Consecuencias

- `sources.lock.json` actualizado con las URLs correctas y commits fijados.
- Los clones shallow de los workflows usan la rama `main`.
- Evita fallos silenciosos por URLs muertas.
