# Contributing

Este proyecto sigue `AGENTS.md` estrictamente. Léelo antes de contribuir.

## Reglas básicas

1. **No publicar información sensible**: serial, IMEI, MAC, tokens, firmware de
   unidad, respaldos del dispositivo, logs con identificadores.
2. **Dispositivo de solo lectura**: ninguna operación Fastboot destructiva sin
   autorización explícita y respaldos previos.
3. **Honestidad técnica**: usa los estados permitidos en
   `reports/hardware-matrix.json` y `docs/HARDWARE-STATUS.md`. Compilar no es
   funcionar.
4. **Licencias**: GPL-3.0-or-later para lo propio; preservar autoría upstream.
5. **Fuentes reproducibles**: todo pin por commit en `sources.lock.json`.

## Workflow de contribución

1. Branch corto y descriptivo.
2. Commits pequeños y descriptivos.
3. Antes del push: `scripts/audit-public-repository.sh`, `git status`,
   `git diff --stat`.
4. Abre Pull Request contra `main`.

## Convenciones

- Scripts en bash con `set -Eeuo pipefail` y shebang `#!/usr/bin/env bash`.
- YAML: 2 espacios, sin tabs. JSON: `jq`-valido.
- Workflows: `workflow_dispatch` para trabajo pesado; acciones fijadas por SHA.
- Documentación en `docs/` en español (mismo idioma que `AGENTS.md`).
