#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# build-diagnostic-initramfs.sh
#
# Ensambla un initramfs mínimo de diagnóstico (BusyBox estático + init + cpio
# gzip) para el boot no destructivo vía `fastboot boot`. Se ejecuta en GitHub
# Actions (workflow 04-build-diagnostic-boot.yml). NO se ejecuta localmente.
#
# Uso:
#   scripts/build-diagnostic-initramfs.sh \
#     --init <initramfs/init> \
#     --out <directorio-salida> \
#     [--busybox /ruta/a/busybox.static] \
#     [--busybox-root /ruta/al-árbol-instalado]

set -Eeuo pipefail

INIT=""
OUT=""
BUSYBOX=""
BUSYBOX_ROOT=""
USB_FUNCTION="rndis"
DISPLAY_PAYLOAD=""

usage() {
  echo "uso: $0 --init <init> --out <dir> [--busybox /ruta] [--busybox-root /ruta/al-árbol]" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --init) INIT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --busybox) BUSYBOX="$2"; shift 2 ;;
    --busybox-root) BUSYBOX_ROOT="$2"; shift 2 ;;
    --usb-function) USB_FUNCTION="$2"; shift 2 ;;
    --display-payload) DISPLAY_PAYLOAD="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$INIT" && -n "$OUT" ]] || usage
[[ -f "$INIT" ]] || { echo "ERROR: init no existe: $INIT" >&2; exit 1; }
case "$USB_FUNCTION" in
  ecm|ncm|rndis) ;;
  *) echo "ERROR: usb-function debe ser ecm, ncm o rndis" >&2; exit 2 ;;
esac
if [[ -n "$DISPLAY_PAYLOAD" ]]; then
  [[ -d "$DISPLAY_PAYLOAD" ]] || { echo "ERROR: display-payload no existe" >&2; exit 1; }
fi
# Rutas absolutas: el empaquetado corre en un subshell con `cd "$STAGE"` y una
# ruta relativa de OUT no se resolvería ahí.
INIT="$(readlink -f "$INIT")"
OUT="$(readlink -f "$OUT")"

info() { printf '[initramfs] %s\n' "$*" >&2; }
STAGE="$(mktemp -d /tmp/initramfs-stage.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$OUT"

# 1) BusyBox estático (proveído por CI o descargado).
if [[ -z "$BUSYBOX" ]]; then
  if command -v busybox >/dev/null 2>&1; then
    BUSYBOX="$(command -v busybox)"
  fi
fi

mkdir -p "$STAGE/bin" "$STAGE/sbin" "$STAGE/usr/bin" "$STAGE/usr/sbin"
if [[ -n "$BUSYBOX_ROOT" && -x "$BUSYBOX_ROOT/bin/busybox" ]]; then
  # Árbol completo instalado por build-busybox-arm64.sh (make CONFIG_PREFIX
  # install): busybox + enlaces de TODOS los applets. Copiar el árbol
  # garantiza que /init y la shell de rescate encuentren sed, grep, awk,
  # uptime, setsid, sync, switch_root, etc. (evita la causa del panic EX3).
  info "usando árbol de applets: $BUSYBOX_ROOT"
  FB="$(file -b "$BUSYBOX_ROOT/bin/busybox")"
  info "busybox: $FB"
  [[ "$FB" == *"ARM aarch64"* ]] || {
    echo "ERROR: busybox del árbol NO es aarch64 (dispositivo arm64): $FB" >&2
    exit 1
  }
  [[ "$FB" == *"static"* ]] || {
    echo "ERROR: busybox del árbol NO es estático: $FB" >&2
    exit 1
  }
  [[ -L "$BUSYBOX_ROOT/bin/sed" ]] || {
    echo "ERROR: el árbol de applets no contiene bin/sed" >&2
    exit 1
  }
  cp -a "$BUSYBOX_ROOT"/. "$STAGE"/
elif [[ -n "$BUSYBOX" && -f "$BUSYBOX" ]]; then
  # Fallback: busybox binario + lista fija de applets (histórico). No es el
  # camino recomendado: si se usa, ampliamos la lista para cubrir /init.
  FB="$(file -b "$BUSYBOX")"
  info "busybox: $FB"
  [[ "$FB" == *"ARM aarch64"* ]] || {
    echo "ERROR: busybox NO es aarch64 (dispositivo arm64): $FB" >&2
    exit 1
  }
  [[ "$FB" == *"static"* ]] || {
    echo "ERROR: busybox NO es estático: $FB" >&2
    exit 1
  }
  cp "$BUSYBOX" "$STAGE/bin/busybox"
  for a in sh mount umount cat echo ls sleep uname dmesg chmod ln mkdir mknod \
           ps cp mv rm touch tail head free df sed grep awk uptime setsid \
           sync switch_root tr wc test ifconfig telnetd; do
    ln -sf /bin/busybox "$STAGE/bin/$a"
  done
  ln -sf /bin/busybox "$STAGE/sbin/mount"
  ln -sf /bin/busybox "$STAGE/sbin/reboot"
else
  info "sin busybox disponible; el init requiere BusyBox en el runner"
  exit 1
fi

# 2) init (PID 1)
mkdir -p "$STAGE"
cp "$INIT" "$STAGE/init"
chmod 0755 "$STAGE/init"

# 3) /etc — mínimo
mkdir -p "$STAGE/etc"
printf 'pmos-diag' > "$STAGE/etc/hostname"
printf 'pmos-diag (telnet diagnostic shell)\n' > "$STAGE/etc/issue"
printf '%s\n' "$USB_FUNCTION" > "$STAGE/etc/diag-usb-function"
: > "$STAGE/etc/mtab"
if [[ -n "$DISPLAY_PAYLOAD" ]]; then
  mkdir -p "$STAGE/usr/share/v71-display"
  cp -a "$DISPLAY_PAYLOAD"/*.raw "$STAGE/usr/share/v71-display/"
fi

# 4) Empaquetar como cpio gzip (format initramfs del kernel)
info "empaquetando initramfs..."
(
  cd "$STAGE"
  find . -print0 | cpio --null -o -H newc 2>/dev/null | gzip -9 > "$OUT/initramfs.cpio.gz"
)

info "initramfs creado: $OUT/initramfs.cpio.gz"
ls -la "$OUT/initramfs.cpio.gz"
cat > "$OUT/initramfs-manifest.txt" <<EOF
initramfs de diagnóstico laurel_sprout (mainline v7.1)
- BusyBox estático aarch64 (arm64), árbol de applets completo
  (make CONFIG_PREFIX install: bin/sbin/usr), incluye sed/grep/awk/uptime
- init: initramfs/init (PID 1)
- consola serial ttyMSM0 + /dev/console
- gadget $USB_FUNCTION temporal en 172.16.42.1/24 + telnetd solo para diagnóstico
- NADA se monta del rootfs del dispositivo
generado: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
cat "$OUT/initramfs-manifest.txt"
exit 0
