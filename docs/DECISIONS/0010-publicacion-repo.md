# DECISION-0010 — Publicación del repo: primero auditoría, luego push

- Estado: **Aceptado**
- Fecha: 2026-08-02

## Contexto

El repositorio GitHub `pmos-laurel-sprout` aún no existe y no hay remote.
AGENTS.md exige auditoría pública antes de cada push y autorización antes
del primer push.

## Decisión

El orden de publicación es:

1. `scripts/audit-public-repository.sh` (bloquea secretos, serial, bins,
   metadatos sin filtrar).
2. Revisión de `git status`, `git diff --stat` y lista de commits.
3. Autorización explícita del usuario para `gh repo create`.
4. `gh repo create` con visibilidad privada o pública según lo que se
   acuerde (default: privada hasta autorización).
5. Primer `git push` y ejecución supervisada de los workflows.

## Consecuencias

- Nada sensible se publica por error.
- Los workflows 00-quality y 01-research pueden ejecutarse contra el repo
  remoto una vez publicado.

## Alternativas consideradas

- Publicar sin auditoría: rechazado (viola AGENTS.md).
- Ejecutar workflows sin repo remoto: imposible (GitHub Actions).
