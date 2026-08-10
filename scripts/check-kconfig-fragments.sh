#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# check-kconfig-fragments.sh
#
# Validación estática de los fragmentos Kconfig y su deny-list, sin clonar el
# árbol del kernel (se ejecuta en CI ligera, workflow 00-quality):
#   - formato de cada línea (CONFIG_X=valor | # CONFIG_X is not set)
#   - sin símbolos duplicados con valores contradictorios dentro de un
#     fragmento
#   - sin conflictos entre fragmentos (dos fragmentos piden valores distintos
#     para el mismo símbolo)
#   - deny-list coherente: un símbolo con límite máximo =m (o no-set) no puede
#     aparecer como =y en ningún fragmento
#
# Uso:
#   scripts/check-kconfig-fragments.sh \
#     --fragments frag1.fragment [frag2.fragment ...] \
#     [--deny-list deny.fragment]

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

FRAGMENTS=()
DENY_LIST=""

usage() {
  echo "uso: $0 --fragments f... [--deny-list f]" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --fragments) shift; while (( $# > 0 )) && [[ "$1" != -* ]]; do FRAGMENTS+=("$1"); shift; done ;;
    --deny-list) DENY_LIST="$2"; shift 2 ;;
    *) usage ;;
  esac
done

(( ${#FRAGMENTS[@]} > 0 )) || usage

if [[ -n "$DENY_LIST" ]]; then
  [[ "$DENY_LIST" != /* && -f "$REPO_ROOT/$DENY_LIST" ]] && DENY_LIST="$REPO_ROOT/$DENY_LIST"
  [[ -f "$DENY_LIST" ]] || { echo "ERROR: deny-list no existe: $DENY_LIST" >&2; exit 1; }
fi

info() { printf '[kconfig-lint] %s\n' "$*" >&2; }

FAIL=0

# --- Formato + duplicados dentro de cada fragmento ---
declare -A SEEN

check_fragment() {
  local frag="$1" line sym val
  if [[ "$frag" != /* && -f "$REPO_ROOT/$frag" ]]; then
    frag="$REPO_ROOT/$frag"
  fi
  [[ -f "$frag" ]] || { echo "ERROR: fragmento no existe: $frag" >&2; FAIL=1; return; }

  local lineno=0
  while IFS= read -r line; do
    lineno=$((lineno + 1))
    case "$line" in
      ""|\#*)
        [[ "$line" == \#\ CONFIG_* ]] || continue
        sym="${line#\# }"; sym="${sym%% is not set*}"
        if [[ -n "${SEEN[$sym]+x}" && "${SEEN[$sym]}" != "n" ]]; then
          echo "CONFLICTO: $sym pedido como ${SEEN[$sym]} y como no-set (${frag##*/}:$lineno)" >&2
          FAIL=1
        else
          SEEN["$sym"]="n"
        fi
        ;;
      CONFIG_*=y|CONFIG_*=m)
        sym="${line%%=*}"
        val="${line#*=}"
        if [[ -n "${SEEN[$sym]+x}" && "${SEEN[$sym]}" != "$val" ]]; then
          echo "CONFLICTO: $sym pedido como =${SEEN[$sym]} y =$val (${frag##*/}:$lineno)" >&2
          FAIL=1
        else
          SEEN["$sym"]="$val"
        fi
        ;;
      CONFIG_*=\"*\"|CONFIG_*=[0-9]*)
        sym="${line%%=*}"
        val="$line"
        if [[ -n "${SEEN[$sym]+x}" && "${SEEN[$sym]}" != "$val" ]]; then
          echo "CONFLICTO: $sym con valores distintos (${frag##*/}:$lineno)" >&2
          FAIL=1
        else
          SEEN["$sym"]="$val"
        fi
        ;;
      *)
        echo "FORMATO: línea $lineno no válida en ${frag##*/}: $line" >&2
        FAIL=1
        ;;
    esac
  done < "$frag"
}

for f in "${FRAGMENTS[@]}"; do
  check_fragment "$f"
done

# --- Deny-list coherente con los fragmentos ---
if [[ -n "$DENY_LIST" ]]; then
  local_lineno=0
  while IFS= read -r line; do
    local_lineno=$((local_lineno + 1))
    case "$line" in
      ""|\#*)
        [[ "$line" == \#\ CONFIG_* ]] || continue
        sym="${line#\# }"; sym="${sym%% is not set*}"
        if [[ -n "${SEEN[$sym]+x}" && "${SEEN[$sym]}" != "n" ]]; then
          echo "DENY-CONFLICTO: $sym en deny-list (no-set) pero un fragmento pide ${SEEN[$sym]}" >&2
          FAIL=1
        fi
        ;;
      CONFIG_*=m)
        sym="${line%%=*}"
        if [[ -n "${SEEN[$sym]+x}" && "${SEEN[$sym]}" == "y" ]]; then
          echo "DENY-CONFLICTO: $sym en deny-list (max=m) pero un fragmento pide =y" >&2
          FAIL=1
        fi
        ;;
      CONFIG_*=y)
        info "AVISO: deny-list con =y no impone límite (${DENY_LIST##*/}:$local_lineno)"
        ;;
      *)
        echo "FORMATO: línea $local_lineno no válida en deny-list: $line" >&2
        FAIL=1
        ;;
    esac
  done < "$DENY_LIST"
fi

if (( FAIL )); then
  echo "ERROR: fragmentos Kconfig inválidos" >&2
  exit 1
fi

info "fragmentos Kconfig coherentes"
exit 0
