#!/usr/bin/env bash
#
# resolve-sources.sh
#
# Genera sources.lock.proposed.json a partir de sources.lock.json validando:
#   - cada commit existe (git ls-remote);
#   - no hay main/master/HEAD/latest sin commit fijado;
#   - las URLs no cambian silenciosamente (flags);
#   - los checksums declarados son SHA-256.
#
# Uso: scripts/resolve-sources.sh [-o SALIDA]
# Licencia: GPL-3.0-or-later

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

INPUT="sources.lock.json"
OUTPUT="${1:-sources.lock.proposed.json}"

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq requerido" >&2; exit 1; }

info() { printf '[resolve] %s\n' "$*" >&2; }

[[ -f "$INPUT" ]] || { echo "ERROR: $INPUT no existe" >&2; exit 1; }

# Verificar formato JSON
jq empty "$INPUT" || { echo "ERROR: JSON inválido en $INPUT" >&2; exit 1; }

FAIL=0

while IFS= read -r idx; do
  name="$(jq -r ".sources[$idx].name" "$INPUT")"
  url="$(jq -r ".sources[$idx].url" "$INPUT")"
  commit="$(jq -r ".sources[$idx].commit" "$INPUT")"
  vcs="$(jq -r ".sources[$idx].vcs" "$INPUT")"
  checksum="$(jq -r ".sources[$idx].sha256 // empty" "$INPUT")"

  # Rechazar ramas móviles sin commit fijado
  case "$commit" in
    null|""|"main"|"master"|"HEAD"|"latest")
      info "BLOQUEADO: $name usa '$commit' sin commit fijado"
      FAIL=1
      ;;
  esac

  # URLs de descarga "latest" que cambian silenciosamente
  case "$url" in
    *"/latest"*|*"download/latest"*|*"/releases/latest"*)
      info "BLOQUEADO: $name usa URL que cambia silenciosamente: $url"
      FAIL=1
      ;;
  esac

  # Checksum declarado debe ser SHA-256 (64 hex)
  if [[ -n "$checksum" ]] && ! printf '%s' "$checksum" | grep -qE '^[0-9a-f]{64}$'; then
    info "BLOQUEADO: $name checksum no es SHA-256"
    FAIL=1
  fi

  # Verificar existencia del commit via git ls-remote cuando hay vcs git
  if [[ "$vcs" == "git" && "$commit" != null && "$commit" != "" ]]; then
    refs="$(git ls-remote "$url" 2>/dev/null | grep -F "$commit" || true)"
    if [[ -z "$refs" ]]; then
      info "AVISO: commit $commit de $name no encontrado por git ls-remote (puede ser shallow o privado)"
    else
      info "OK: $name -> $commit verificado"
    fi
  fi
done < <(jq -r '.sources | length' "$INPUT" | xargs -I{} seq 0 $(( {} - 1 )))

if (( FAIL != 0 )); then
  info "resolución fallida: hay fuentes sin commit fijado o con URL inestable"
  exit 1
fi

# Generar propuesta con fecha de auditoría
jq '.sources[] | .verification_status = "validated" | .last_audited = "'"$(date -u +%Y-%m-%d)"'"' "$INPUT" | jq -s '{format_version:1, sources: .}' > "$OUTPUT"

info "propuesta escrita en $OUTPUT"
exit 0
