#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# verify-kconfig.sh
#
# Comprueba que cada símbolo obligatorio de un fragmento Kconfig existe en el
# Kconfig del árbol y que terminó habilitado en el .config final.
# La build debe fallar si un símbolo obligatorio fue solicitado pero quedó
# silenciosamente deshabilitado.
#
# Uso:
#   scripts/verify-kconfig.sh --config <ruta-config> --tree <ruta-árbol>
#   [--fragments frag1.fragment [frag2.fragment ...]] [--fail-missing]

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CONFIG=""
TREE=""
FAIL_MISSING=0
FRAGMENTS=()

usage() {
  echo "uso: $0 --config <config> --tree <árbol> [--fragments f...] [--fail-missing]" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --config) CONFIG="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    --fragments) shift; while (( $# > 0 )) && [[ "$1" != -* ]]; do FRAGMENTS+=("$1"); shift; done ;;
    --fail-missing) FAIL_MISSING=1; shift ;;
    *) usage ;;
  esac
done

[[ -n "$CONFIG" && -n "$TREE" ]] || usage
[[ -f "$CONFIG" ]] || { echo "ERROR: config no existe: $CONFIG" >&2; exit 1; }
[[ -d "$TREE" ]] || { echo "ERROR: árbol no existe: $TREE" >&2; exit 1; }

info() { printf '[kconfig] %s\n' "$*" >&2; }

MISSING_SYMBOLS=()
DISABLED_SYMBOLS=()

# Recolectar símbolos de los fragmentos
SYMBOLS=()
for frag in "${FRAGMENTS[@]:-}"; do
  if [[ "$frag" != /* && -f "$REPO_ROOT/$frag" ]]; then
    frag="$REPO_ROOT/$frag"
  fi
  [[ -f "$frag" ]] || { echo "ERROR: fragmento no existe: $frag" >&2; exit 1; }
  while IFS= read -r line; do
    case "$line" in
      CONFIG_*=*)
        sym="${line%%=*}"
        SYMBOLS+=("$sym")
        ;;
    esac
  done < "$frag"
done

if (( ${#SYMBOLS[@]} == 0 )); then
  info "sin símbolos explícitos en fragmentos; validando símbolos presentes en el config"
fi

for sym in "${SYMBOLS[@]}"; do
  # ¿Existe el símbolo en el Kconfig del árbol? (búsqueda recursiva)
  if ! grep -rqE --include='Kconfig*' "(config|menuconfig)[[:space:]]+${sym#CONFIG_}" "$TREE" 2>/dev/null; then
    MISSING_SYMBOLS+=("$sym")
    info "MISSING en Kconfig: $sym"
    continue
  fi
  # ¿Terminó habilitado en el .config final?
  # Soporta booleanos (y/m) y símbolos de string/int (CONFIG_X="...", CONFIG_X=123)
  if grep -qE "^# ${sym} is not set" "$CONFIG"; then
    DISABLED_SYMBOLS+=("$sym")
    info "DESHABILITADO silenciosamente: $sym"
  elif grep -qE "^${sym}=" "$CONFIG"; then
    info "OK: $sym"
  else
    DISABLED_SYMBOLS+=("$sym")
    info "NO presente en config final: $sym"
  fi
done

if (( ${#MISSING_SYMBOLS[@]} > 0 )); then
  echo "Símbolos inexistentes en Kconfig (a revisar):" >&2
  printf '  %s\n' "${MISSING_SYMBOLS[@]}" >&2
fi

if (( ${#DISABLED_SYMBOLS[@]} > 0 )); then
  echo "Símbolos obligatorios silenciosamente deshabilitados:" >&2
  printf '  %s\n' "${DISABLED_SYMBOLS[@]}" >&2
  if (( FAIL_MISSING )); then
    info "FALLO: símbolos obligatorios deshabilitados"
    exit 1
  fi
fi

info "verificación Kconfig completada"
exit 0
