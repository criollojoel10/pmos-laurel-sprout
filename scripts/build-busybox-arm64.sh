#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# build-busybox-arm64.sh
#
# Construye un BusyBox estático para aarch64 (SM6125 / trinket / Snapdragon
# 665) con el toolchain cruzado de Ubuntu (crossbuild-essential-arm64).
# Se ejecuta en GitHub Actions (workflow 04-build-diagnostic-boot.yml).
# NO se ejecuta localmente (AGENTS.md: el trabajo pesado solo en CI).
#
# Antecedente: el paquete busybox-static de Ubuntu es x86-64; el dispositivo
# es aarch64 y el initramfs con ese binario falla con "exec format error".
# Esta build sustituye esa dependencia por un binario arm64 estático.
#
# Uso:
#   scripts/build-busybox-arm64.sh --out <directorio-salida>
#
# El tarball queda fijado por SHA-256 (registrado en sources.lock.json).

set -Eeuo pipefail

VERSION="1.38.0"
URL="https://busybox.net/downloads/busybox-${VERSION}.tar.bz2"
SHA256="34f9ea6ff8636f2c9241153b9114eefa9e65674a45318ae1ef95bb5f31c53bb2"
TARBALL="busybox-${VERSION}.tar.bz2"
CROSS="aarch64-linux-gnu-"
ARCH="arm64"

OUT=""
usage() {
  echo "uso: $0 --out <dir>" >&2
  exit 2
}
while (( $# > 0 )); do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    *) usage ;;
  esac
done
[[ -n "$OUT" ]] || usage
mkdir -p "$OUT"

info() { printf '[busybox] %s\n' "$*" >&2; }

command -v "${CROSS}gcc" >/dev/null 2>&1 || {
  echo "ERROR: toolchain cruzado no disponible (instala crossbuild-essential-arm64)" >&2
  exit 1
}

WORK="$(mktemp -d /tmp/busybox-build.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

info "descargando $URL"
curl -fsSL "$URL" -o "$WORK/$TARBALL"
( cd "$WORK" && printf '%s  %s\n' "$SHA256" "$TARBALL" > SHA256SUMS && sha256sum -c SHA256SUMS )

info "extrayendo"
tar -xjf "$WORK/$TARBALL" -C "$WORK"
cd "$WORK/busybox-${VERSION}"

info "configurando (ARCH=$ARCH CROSS=$CROSS, estático)"
make ARCH="$ARCH" CROSS_COMPILE="$CROSS" defconfig >/dev/null
sed -i 's/^# CONFIG_STATIC is not set$/CONFIG_STATIC=y/' .config
grep -q '^CONFIG_STATIC=y$' .config || { echo "ERROR: no se pudo habilitar CONFIG_STATIC" >&2; exit 1; }

info "compilando (puede tardar 1-2 min)"
make -j"$(nproc)" ARCH="$ARCH" CROSS_COMPILE="$CROSS" busybox 2>&1 | tail -20

BB="$WORK/busybox-${VERSION}/busybox"
[[ -f "$BB" ]] || { echo "ERROR: no se generó el binario busybox" >&2; exit 1; }
FB="$(file -b "$BB")"
info "archivo generado: $FB"
[[ "$FB" == *"ARM aarch64"* ]] || { echo "ERROR: el binario NO es aarch64: $FB" >&2; exit 1; }
[[ "$FB" == *"static"* ]] || { echo "ERROR: el binario NO es estático: $FB" >&2; exit 1; }

cp "$BB" "$OUT/busybox"
sha256sum "$OUT/busybox" > "$OUT/busybox.SHA256"
info "salida: $OUT/busybox"
cat "$OUT/busybox.SHA256"
exit 0
