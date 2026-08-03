#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# build-pmos-plasma.sh
#
# Construye la imagen de postmarketOS PLASMA MOBILE para laurel_sprout dentro
# de GitHub Actions. NO se ejecuta localmente.
#
# Uso:
#   scripts/build-pmos-plasma.sh \
#     --pmaports <dir> \
#     --packages configs/pmos/plasma-packages.txt \
#     --out <dir>

set -Eeuo pipefail

PM=""
PACKAGES=""
OUT=""

usage() {
  echo "uso: $0 --pmaports <dir> --packages <archivo> --out <dir>" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --pmaports) PM="$2"; shift 2 ;;
    --packages) PACKAGES="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$PM" && -n "$PACKAGES" && -n "$OUT" ]] || usage
[[ -d "$PM" ]] || { echo "ERROR: pmaports no existe: $PM" >&2; exit 1; }
[[ -f "$PACKAGES" ]] || { echo "ERROR: archivo de paquetes no existe: $PACKAGES" >&2; exit 1; }

info() { printf '[pmos-plasma] %s\n' "$*" >&2; }
mkdir -p "$OUT"

export PMB_PACKAGE_LIST="$PACKAGES"

cat > "$OUT/plasma-build-contract.txt" <<EOF
Objetivo: postmarketOS Edge + metapaquete Plasma Mobile, systemd, AArch64.
Interfaz: Plasma Mobile (KWin Wayland, Qt 6). NO Plasma Desktop tradicional.
Apps: Konsole, Dolphin, Discover, Plasma NetworkManager.
Servicios: systemd, logind, NetworkManager, BlueZ, PipeWire, WirePlumber,
  PowerDevil, SSH, USB networking de emergencia.
Optimización objetivo: 4 GB RAM, Snapdragon 665, 720x1560.
Método: pmbootstrap install + apk add de plasma-mobile sobre la imagen consola.
EOF

info "contrato de build escrito en $OUT/plasma-build-contract.txt"
info "NOTA: la invocación pmbootstrap completa se materializa en el workflow 05."
exit 0
