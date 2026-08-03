#!/usr/bin/env bash
#
# prepare-pmaports.sh
#
# Prepara pmaports para construir las imágenes dentro de GitHub Actions:
#   - Clona pmaports en el commit fijado.
#   - Aplica los parches locales del repo (device/, configs/) al árbol de
#     pmaports sin tocar el repo de este proyecto.
#
# Uso:
#   scripts/prepare-pmaports.sh --pmaports <dir> --commit <sha> [--apply-device]
# Licencia: GPL-3.0-or-later

set -Eeuo pipefail

PM=""
COMMIT=""
APPLY_DEVICE=0

usage() {
  echo "uso: $0 --pmaports <dir> --commit <sha> [--apply-device]" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --pmaports) PM="$2"; shift 2 ;;
    --commit) COMMIT="$2"; shift 2 ;;
    --apply-device) APPLY_DEVICE=1; shift ;;
    *) usage ;;
  esac
done

[[ -n "$PM" && -n "$COMMIT" ]] || usage

info() { printf '[pmaports] %s\n' "$*" >&2; }

if [[ ! -d "$PM/.git" ]]; then
  info "clonando pmaports..."
  git clone --filter=blob:none --no-checkout \
    https://gitlab.com/postmarketOS/pmaports.git "$PM"
  cd "$PM"
  git fetch --depth 1 origin "$COMMIT"
  git checkout "$COMMIT"
  git submodule update --init --recursive || true
else
  info "pmaports ya presente; asegurando commit $COMMIT"
  cd "$PM"
  if [[ "$(git rev-parse HEAD)" != "$COMMIT" ]]; then
    git fetch --depth 1 origin "$COMMIT"
    git checkout "$COMMIT"
  fi
fi

info "pmaports en $(git rev-parse HEAD)"

# Aplicar parches de dispositivo del repositorio (opcional).
if (( APPLY_DEVICE )); then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  if [[ -d "$REPO_ROOT/patches/pending" ]]; then
    for p in "$REPO_ROOT"/patches/pending/*.patch; do
      [[ -f "$p" ]] || continue
      if git apply --check --directory="$PM" "$p" 2>/dev/null; then
        git apply --directory="$PM" "$p"
        info "aplicado: $(basename "$p")"
      else
        info "SKIP (no aplica limpio): $(basename "$p")"
      fi
    done
  fi
fi

info "pmaports preparado."
exit 0
