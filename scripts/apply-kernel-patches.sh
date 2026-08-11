#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# apply-kernel-patches.sh
#
# Aplica los parches downstream de patches/kernel/ sobre un árbol de kernel
# mainline v7.1, verificando que cada uno aplique limpio con git apply.
#
# Parches:
#   0001-dts-mdss-panel-s6e8fc0.patch  Enable MDSS + panel S6E8FC0 (typo corregido)
#   0002-dtsi-gpu-adreno610.patch      Nodos GPU (gpu/gmu_wrapper/gpucc/adreno_smmu)
#   0003-dts-enable-gpu.patch          Enable GPU + zap-shader en DTS de placa
#   0004-dts-enable-wifi-wcn3990.patch Nodo WCN3990 SNOC + MSA/reguladores
#
# Uso:
#   scripts/apply-kernel-patches.sh <árbol-kernel>

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TREE="${1:-}"
if [[ -z "$TREE" ]]; then
  echo "uso: $0 <árbol-kernel>" >&2
  exit 2
fi
[[ -d "$TREE" ]] || { echo "ERROR: árbol no existe: $TREE" >&2; exit 1; }

PATCH_DIR="$REPO_ROOT/patches/kernel"
shopt -s nullglob
PATCHES=("$PATCH_DIR"/*.patch)

if (( ${#PATCHES[@]} == 0 )); then
  echo "Sin parches en $PATCH_DIR"
  exit 0
fi

cd "$TREE"

for p in "${PATCHES[@]}"; do
  git apply --check "$p" || {
    echo "ERROR: $p no aplica limpio sobre $TREE" >&2
    echo "  ejecuta: git apply --verbose '$p' para diagnóstico" >&2
    exit 1
  }
  git apply "$p"
  echo "aplicado: $(basename "$p")"
done

echo "OK: todos los parches downstream aplicados"
