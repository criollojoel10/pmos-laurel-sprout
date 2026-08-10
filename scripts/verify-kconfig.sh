#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# verify-kconfig.sh
#
# Comprueba que los símbolos de los fragmentos Kconfig:
#   a) existen en el Kconfig del árbol (búsqueda recursiva);
#   b) terminaron en el .config final con el MISMO valor que pedía el
#      fragmento (=y, =m o no-set). Una degradación silenciosa
#      (p. ej. pedido CONFIG_FOO=y y resultado CONFIG_FOO=m, causada por
#      `make olddefconfig` al reevaluar dependencias tristate) se reporta
#      como error.
#
# Adicionalmente, con --deny-list <archivo> se impone un conjunto de
# límites MÁXIMOS: cualquier símbolo listado como =m no puede terminar =y,
# y cualquier símbolo listado como no-set debe quedar apagado.
#
# Uso:
#   scripts/verify-kconfig.sh --config <ruta-config> --tree <ruta-árbol>
#     [--fragments frag1.fragment [frag2.fragment ...]]
#     [--deny-list deny.fragment]
#     [--fail-missing] [--fail-deny]

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CONFIG=""
TREE=""
FAIL_MISSING=0
FAIL_DENY=0
FRAGMENTS=()
DENY_LIST=""

usage() {
  echo "uso: $0 --config <config> --tree <árbol> [--fragments f...] [--deny-list f] [--fail-missing] [--fail-deny]" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --config) CONFIG="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    --fragments) shift; while (( $# > 0 )) && [[ "$1" != -* ]]; do FRAGMENTS+=("$1"); shift; done ;;
    --deny-list) DENY_LIST="$2"; shift 2 ;;
    --fail-missing) FAIL_MISSING=1; shift ;;
    --fail-deny) FAIL_DENY=1; shift ;;
    *) usage ;;
  esac
done

[[ -n "$CONFIG" && -n "$TREE" ]] || usage
[[ -f "$CONFIG" ]] || { echo "ERROR: config no existe: $CONFIG" >&2; exit 1; }
[[ -d "$TREE" ]] || { echo "ERROR: árbol no existe: $TREE" >&2; exit 1; }
if [[ -n "$DENY_LIST" ]]; then
  [[ "$DENY_LIST" != /* && -f "$REPO_ROOT/$DENY_LIST" ]] && DENY_LIST="$REPO_ROOT/$DENY_LIST"
  [[ -f "$DENY_LIST" ]] || { echo "ERROR: deny-list no existe: $DENY_LIST" >&2; exit 1; }
fi

info() { printf '[kconfig] %s\n' "$*" >&2; }

MISSING_SYMBOLS=()
MISMATCH_SYMBOLS=()
DENY_VIOLATIONS=()

resolve_fragment() {
  local f="$1"
  if [[ "$f" != /* && -f "$REPO_ROOT/$f" ]]; then
    f="$REPO_ROOT/$f"
  fi
  printf '%s' "$f"
}

# Valor de un símbolo en el .config: "y" | "m" | "n"
# (los símbolos ausentes del .config se consideran "n")
config_value() {
  local sym="$1"
  if grep -qE "^${sym}=[ym]$" "$CONFIG"; then
    grep -E "^${sym}=[ym]$" "$CONFIG" | head -n1 | cut -d= -f2
  elif grep -qE "^# ${sym} is not set" "$CONFIG"; then
    printf 'n'
  elif grep -qE "^${sym}=" "$CONFIG"; then
    # string/int: la comparación de valor la hace quien llama
    grep -E "^${sym}=" "$CONFIG" | head -n1 | cut -d= -f2-
  else
    printf 'n'
  fi
}

# ¿Existe el símbolo en el Kconfig del árbol? (búsqueda recursiva)
symbol_exists() {
  local sym="$1"
  grep -rqE --include='Kconfig*' "(config|menuconfig)[[:space:]]+${sym#CONFIG_}" "$TREE" 2>/dev/null
}

# --- Deny-list primero: límites máximos ---
if [[ -n "$DENY_LIST" ]]; then
  while IFS= read -r line; do
    case "$line" in
      CONFIG_*=m)
        sym="${line%%=*}"
        val="$(config_value "$sym")"
        if [[ "$val" == "y" ]]; then
          DENY_VIOLATIONS+=("$sym: deny-list max=m pero quedó =y")
          info "DENY: $sym debe quedar como máximo =m, terminó =y"
        fi
        ;;
        \#\ CONFIG_*)
        sym="${line#\# }"
        if [[ "$sym" == CONFIG_* ]]; then
          sym="${sym%% is not set*}"
          val="$(config_value "$sym")"
          if [[ "$val" != "n" ]]; then
            DENY_VIOLATIONS+=("$sym: deny-list exige no-set pero quedó =$val")
            info "DENY: $sym debe quedar no-set, terminó =$val"
          fi
        fi
        ;;
      CONFIG_*=y)
        info "AVISO: deny-list con =y no impone límite ($line)"
        ;;
      ""|\#*) ;;
      *)
        info "AVISO: línea no reconocida en deny-list: $line"
        ;;
    esac
  done < "$DENY_LIST"
fi

# --- Símbolos de los fragmentos: valor exacto ---
declare -A EXPECTED

parse_fragment() {
  local frag="$1"
  local line sym val
  while IFS= read -r line; do
    case "$line" in
      CONFIG_*=*)
        sym="${line%%=*}"
        val="${line#*=}"
        EXPECTED["$sym"]="$val"
        ;;
      \#\ CONFIG_*)
        sym="${line#\# }"; sym="${sym%% is not set*}"
        EXPECTED["$sym"]="n"
        ;;
    esac
  done < "$frag"
}

for frag in "${FRAGMENTS[@]:-}"; do
  frag="$(resolve_fragment "$frag")"
  [[ -f "$frag" ]] || { echo "ERROR: fragmento no existe: $frag" >&2; exit 1; }
  parse_fragment "$frag"
done

if (( ${#EXPECTED[@]} == 0 )); then
  info "sin símbolos explícitos en fragmentos; validando deny-list y símbolos presentes"
fi

for sym in "${!EXPECTED[@]}"; do
  # ¿Existe el símbolo en el Kconfig del árbol?
  if ! symbol_exists "$sym"; then
    MISSING_SYMBOLS+=("$sym")
    info "MISSING en Kconfig: $sym"
    continue
  fi

  expected="${EXPECTED[$sym]}"
  case "$expected" in
    y|m)
      val="$(config_value "$sym")"
      if [[ "$val" != "$expected" ]]; then
        MISMATCH_SYMBOLS+=("$sym: esperado =$expected, resultado =$val")
        info "MISMATCH: $sym esperado =$expected, resultado =$val"
      else
        info "OK: $sym =$expected"
      fi
      ;;
    n)
      val="$(config_value "$sym")"
      if [[ "$val" != "n" ]]; then
        MISMATCH_SYMBOLS+=("$sym: esperado no-set, resultado =$val")
        info "MISMATCH: $sym esperado no-set, resultado =$val"
      else
        info "OK: $sym no-set"
      fi
      ;;
    *)
      # string/int: exigir que el valor final coincida con el pedido
      if ! grep -qE "^${sym}=${expected}$" "$CONFIG"; then
        MISMATCH_SYMBOLS+=("$sym: esperado =$expected, no coincide")
        info "MISMATCH: $sym esperado =$expected, no coincide"
      else
        info "OK: $sym =$expected"
      fi
      ;;
  esac
done

if (( ${#MISSING_SYMBOLS[@]} > 0 )); then
  echo "Símbolos inexistentes en Kconfig (a revisar):" >&2
  printf '  %s\n' "${MISSING_SYMBOLS[@]}" >&2
fi

if (( ${#MISMATCH_SYMBOLS[@]} > 0 )); then
  echo "Símbolos con valor degradado/alterado respecto al fragmento:" >&2
  printf '  %s\n' "${MISMATCH_SYMBOLS[@]}" >&2
  if (( FAIL_MISSING )); then
    info "FALLO: degradación de símbolos obligatorios"
    exit 1
  fi
fi

if (( ${#DENY_VIOLATIONS[@]} > 0 )); then
  echo "Violaciones de deny-list:" >&2
  printf '  %s\n' "${DENY_VIOLATIONS[@]}" >&2
  if (( FAIL_DENY )); then
    info "FALLO: deny-list violada"
    exit 1
  fi
fi

if (( ${#MISSING_SYMBOLS[@]} > 0 )) && (( FAIL_MISSING )); then
  info "FALLO: símbolos inexistentes en Kconfig"
  exit 1
fi

info "verificación Kconfig completada"
exit 0
