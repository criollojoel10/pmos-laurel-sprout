#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# build-kernel.sh
#
# Construye el kernel SM6125 (debug o release) para laurel_sprout dentro de
# GitHub Actions. NO se ejecuta localmente.
#
# Requiere que el árbol sm61x5-mainline ya esté presente y en el commit fijado.
#
# Uso:
#   scripts/build-kernel.sh \
#     --tree <árbol-kernel> \
#     --variant debug|release \
#     --fragments <fragmento1> [<fragmento2>...] \
#     --out <directorio-salida>

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TREE=""
VARIANT="debug"
FRAGMENTS=()
OUT=""

usage() {
  echo "uso: $0 --tree <árbol> --variant debug|release --fragments f... --out <dir>" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --tree) TREE="$2"; shift 2 ;;
    --variant) VARIANT="$2"; shift 2 ;;
    --fragments) shift; while (( $# > 0 )) && [[ "$1" != -* ]]; do FRAGMENTS+=("$1"); shift; done ;;
    --out) OUT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$TREE" && -n "$OUT" ]] || usage
[[ "$VARIANT" == "debug" || "$VARIANT" == "release" ]] || usage
[[ -d "$TREE" ]] || { echo "ERROR: árbol no existe: $TREE" >&2; exit 1; }

info() { printf '[kernel] %s\n' "$*" >&2; }
mkdir -p "$OUT"

cd "$TREE"

NPROC="$(nproc)"
info "CPUs: $NPROC"
info "vamos a compilar con $(( NPROC > 0 ? NPROC : 1 )) hilos"

# Cross-compile: si existe el cross toolchain (crossbuild-essential-arm64),
# usarlo; si no, compilar en nativo (aarch64).
CROSS=""
if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
  CROSS="aarch64-linux-gnu-"
  info "cross-compilando con $CROSS"
else
  info "sin toolchain cross; compilando nativo"
fi

# Defconfig objetivo: en mainline v7.1 (torvalds) la base arm64 es "defconfig";
# los forks sm61x5-mainline añaden qcom_defconfig/sm6125_defconfig.
DEFCONFIG="defconfig"
if [[ -f "arch/arm64/configs/sm6125_defconfig" ]]; then
  DEFCONFIG="sm6125_defconfig"
elif [[ -f "arch/arm64/configs/qcom_defconfig" ]]; then
  DEFCONFIG="qcom_defconfig"
fi
info "defconfig: $DEFCONFIG"

make ARCH=arm64 CROSS_COMPILE="$CROSS" "$DEFCONFIG" 2>&1 | tee "$OUT/kconfig-setup.log"

# Aplicar fragmentos con merge_config de scripts/kconfig.
# Las rutas relativas se interpretan desde la raíz del repo.
FRAG_OPTS=()
for f in "${FRAGMENTS[@]:-}"; do
  if [[ "$f" != /* && -f "$REPO_ROOT/$f" ]]; then
    f="$REPO_ROOT/$f"
  fi
  [[ -f "$f" ]] || { echo "ERROR: fragmento no existe: $f" >&2; exit 1; }
  FRAG_OPTS+=("$f")
done

if (( ${#FRAG_OPTS[@]} > 0 )); then
  info "aplicando fragmentos: ${FRAG_OPTS[*]}"
  ./scripts/kconfig/merge_config.sh \
    -O . \
    -m arch/arm64/configs/"$DEFCONFIG" \
    "${FRAG_OPTS[@]}" 2>&1 | tee "$OUT/kconfig-merge.log"
  make ARCH=arm64 CROSS_COMPILE="$CROSS" olddefconfig 2>&1 | tee -a "$OUT/kconfig-merge.log"
fi

cp .config "$OUT/kernel.config"

# Compilar kernel + dtbs + módulos
info "compilando kernel..."
make ARCH=arm64 CROSS_COMPILE="$CROSS" -j"$NPROC" Image Image.gz dtbs 2>&1 | tee "$OUT/build.log"
make ARCH=arm64 CROSS_COMPILE="$CROSS" -j"$NPROC" modules 2>&1 | tee -a "$OUT/build.log"

info "instalando módulos..."
make ARCH=arm64 CROSS_COMPILE="$CROSS" modules_install INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH="$OUT/modules" 2>&1 | tee -a "$OUT/build.log"

info "copiando Image y DTB..."
cp arch/arm64/boot/Image "$OUT/Image"
cp arch/arm64/boot/Image.gz "$OUT/Image.gz" 2>/dev/null || true
cp System.map "$OUT/System.map"

# DTB laurel_sprout
DTB="arch/arm64/boot/dts/qcom/sm6125-xiaomi-laurel-sprout.dtb"
if [[ -f "$DTB" ]]; then
  cp "$DTB" "$OUT/sm6125-xiaomi-laurel-sprout.dtb"
  info "DTB laurel copiado"
else
  info "AVISO: $DTB no generado en esta variante"
fi

# Manifiesto de módulos
find "$OUT/modules" -name '*.ko' -printf '%P\n' | sort > "$OUT/modules-manifest.txt"

info "kernel $VARIANT completado en $OUT"
ls -la "$OUT/"
