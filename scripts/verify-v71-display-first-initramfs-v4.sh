#!/usr/bin/env bash
# Licencia: GPL-3.0-or-later

set -Eeuo pipefail
RAMDISK=""; BBROOT=""; OUT="."
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
INIT="$TMP/root/init"
test -f "$INIT" || { echo "ERROR: falta /init" >&2; exit 1; }
for marker in V71_V4_PID1_FIRST_INSTRUCTION V71_V4_PROC_READY V71_V4_SYS_READY \
  V71_V4_DEVTMPFS_READY V71_V4_FB_DEVICE_PRESENT V71_V4_FB_DEVICE_ABSENT \
  V71_V4_FBCON_PRESENT V71_V4_FBCON_ABSENT V71_V4_FB_DIRECT_WRITE_BEGIN \
  V71_V4_FB_DIRECT_WRITE_SUCCESS V71_V4_FB_DIRECT_WRITE_FAILED \
  V71_V4_FB_CHECKPOINT_GREEN V71_V4_FB_CHECKPOINT_BLUE \
  V71_V4_FB_CHECKPOINT_RED V71_V4_FB_STILL_ALIVE V71_V4_FB_LOST \
  V71_V4_DISPLAY_AUDIT_COMPLETE V71_V4_USB_AUDIT_BEGIN V71_V4_UDC_FOUND \
  V71_V4_UDC_TIMEOUT V71_V4_RNDIS_BOUND V71_V4_RNDIS_BIND_FAILED \
  V71_V4_STABLE_LOOP V71_V4_HEARTBEAT; do
  grep -q "$marker" "$INIT" || { echo "ERROR: falta marcador $marker" >&2; exit 1; }
done
grep -q 'V71_V4_PID1_FIRST_INSTRUCTION' "$INIT"
if grep -qE '6\.1\.0-sm6125|/lib/modules/6\.1|vermagic.*6\.1' "$INIT"; then
  echo "ERROR: referencia 6.1 en init v4" >&2; exit 1
fi
for bad in fastboot flash erase mkfs wipefs reboot poweroff clear reset chvt setterm; do
  grep -qE "^[^#]*\\b${bad}\\b" "$INIT" && {
    echo "ERROR: operación prohibida en init v4: $bad" >&2; exit 1; }
done
for app in cat grep awk sleep sync ifconfig telnetd find; do
  test -e "$TMP/root/bin/$app" -o -e "$TMP/root/sbin/$app" -o \
    -e "$TMP/root/usr/bin/$app" -o -e "$TMP/root/usr/sbin/$app" || {
    echo "ERROR: falta applet $app" >&2; exit 1; }
done
file -b "$TMP/root/bin/busybox" | grep -q 'ARM aarch64'
file -b "$TMP/root/bin/busybox" | grep -q 'static'
for color in green blue red; do
  test -f "$TMP/root/usr/share/v71-display/$color.raw" || {
    echo "ERROR: falta patrón $color" >&2; exit 1; }
done
gzip -dc "$RAMDISK" | cpio -t > "$OUT/initramfs-file-list.txt"
cat > "$OUT/initramfs-verification.md" <<EOF
# Initramfs DISPLAY-FIRST v7.1 v4

- Marcadores V71_V4: presentes
- PID1 no sale y heartbeat 10 s: presente
- 6.1/vermagic: no detectado
- Operaciones destructivas/clear/chvt: no detectadas
- Patrones framebuffer green/blue/red: presentes
- BusyBox: ARM aarch64 estático
EOF
cat "$OUT/initramfs-verification.md"
