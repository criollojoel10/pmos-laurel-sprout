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
#     [--busybox /ruta/a/busybox.static]

set -Eeuo pipefail

INIT=""
OUT=""
BUSYBOX=""

usage() {
  echo "uso: $0 --init <init> --out <dir> [--busybox /ruta]" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --init) INIT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --busybox) BUSYBOX="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$INIT" && -n "$OUT" ]] || usage
[[ -f "$INIT" ]] || { echo "ERROR: init no existe: $INIT" >&2; exit 1; }

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
if [[ -n "$BUSYBOX" && -f "$BUSYBOX" ]]; then
  # El dispositivo es aarch64 (SM6125). Un busybox x86-64 haría fallar el
  # initramfs con 'exec format error' (incidente registrado en FASE E0).
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
  mkdir -p "$STAGE/bin" "$STAGE/sbin" "$STAGE/usr/bin" "$STAGE/usr/sbin"
  cp "$BUSYBOX" "$STAGE/bin/busybox"
  # applets
  for a in sh mount umount cat echo ls sleep uname dmesg chmod ln mkdir mknod \
           ps cp mv rm touch tail head free df; do
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
: > "$STAGE/etc/mtab"

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
- BusyBox estático aarch64 (arm64) con applets shell básicos
- init: initramfs/init (PID 1)
- consola serial ttyMSM0 + /dev/console
- NADA se monta del rootfs del dispositivo
generado: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
cat "$OUT/initramfs-manifest.txt"
exit 0
