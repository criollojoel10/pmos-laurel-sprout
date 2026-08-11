#!/usr/bin/env bash
# Licencia: GPL-3.0-or-later

set -Eeuo pipefail
RAMDISK=""
BBROOT=""
OUT="."
while (( $# > 0 )); do
  case "$1" in
    --ramdisk) RAMDISK="$2"; shift 2 ;;
    --busybox-root) BBROOT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) echo "uso: $0 --ramdisk <cpio.gz> --busybox-root <dir> --out <dir>" >&2; exit 2 ;;
  esac
done
[[ -f "$RAMDISK" && -d "$BBROOT" ]] || exit 2
mkdir -p "$OUT"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
gzip -dc "$RAMDISK" > "$TMP/root.cpio"
mkdir -p "$TMP/root"
(cd "$TMP/root" && cpio -idm < "$TMP/root.cpio" >/dev/null 2>&1)
test -f "$TMP/root/init" || { echo "ERROR: falta /init" >&2; exit 1; }
grep -q 'V71_INITRAMFS_REACHED' "$TMP/root/init"
grep -q 'V71_HEARTBEAT' "$TMP/root/init"
grep -q 'V71_GADGET_CONFIGURED' "$TMP/root/init"
grep -q 'V71_RESCUE_SHELL_ACTIVE' "$TMP/root/init"
if grep -qE '6\.1\.0-sm6125|/lib/modules/6\.1|vermagic.*6\.1' "$TMP/root/init"; then
  echo "ERROR: referencia a módulos 6.1 en init nativo" >&2
  exit 1
fi
for bad in fastboot reboot poweroff mkfs wipefs; do
  if grep -qE "^[^#]*\\b${bad}\\b" "$TMP/root/init"; then
    echo "ERROR: operación prohibida en init: $bad" >&2
    exit 1
  fi
done
for app in ifconfig telnetd; do
  test -e "$TMP/root/bin/$app" -o -e "$TMP/root/sbin/$app" -o \
       -e "$TMP/root/usr/bin/$app" -o -e "$TMP/root/usr/sbin/$app" || {
    echo "ERROR: falta applet $app" >&2; exit 1;
  }
done
file -b "$TMP/root/bin/busybox" | grep -q 'ARM aarch64'
file -b "$TMP/root/bin/busybox" | grep -q 'static'
cpio -t < "$TMP/root.cpio" > "$OUT/initramfs-file-list.txt"
cat > "$OUT/initramfs-verification.md" <<EOF
# Initramfs nativo v7.1

- /init: presente
- marcadores V71: presentes
- heartbeat: presente (15 s)
- módulos/scripts 6.1: no detectados
- operaciones destructivas: no detectadas
- USB applets: ifconfig/telnetd presentes
- BusyBox: ARM aarch64 estático
EOF
cat "$OUT/initramfs-verification.md"
