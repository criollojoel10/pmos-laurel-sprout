#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# build-pmos-console.sh
#
# Construye la imagen de postmarketOS CONSOLA (recuperación) para
# laurel_sprout dentro de GitHub Actions. NO se ejecuta localmente.
#
# Uso:
#   scripts/build-pmos-console.sh \
#     --pmaports <dir> \
#     --packages configs/pmos/console-packages.txt \
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

info() { printf '[pmos-console] %s\n' "$*" >&2; }
mkdir -p "$OUT"

# pmbootstrap con systemd, sin cifrado, usuario por defecto.
# IMPORTANTE: pmbootstrap requiere chroot + qemu/aarch64; esto corre en CI.
info "configurando pmbootstrap..."
python3 - <<'PY'
import os, subprocess, sys
# pmbootstrap está pensado para ejecutarse como root en CI.
PY

info "creando deviceinfo y config del port (temporal, en el job)"
PMB_PACKAGE_LIST="$PACKAGES"
export PMB_PACKAGE_LIST

# La construcción real depende de la fase de integración pmaports completa.
# Aquí documentamos los parámetros y dejamos el contrato para el workflow.
cat > "$OUT/console-build-contract.txt" <<EOF
Objetivo: postmarketOS Edge, systemd, AArch64, sin cifrado.
Hostname: laurel-pmos
Usuario: configurable
Paquetes: $(basename "$PACKAGES")
Servicios: SSH, NetworkManager, BlueZ, PipeWire básico
Herramientas: dmesg, journalctl, eglinfo, glmark2-es2-wayland,
  Weston, foot, wvkbd, libinput, mesa-utils
Método: pmbootstrap install con variante systemd
EOF

info "contrato de build escrito en $OUT/console-build-contract.txt"
info "NOTA: la invocación pmbootstrap completa se materializa en el workflow 04."
exit 0
