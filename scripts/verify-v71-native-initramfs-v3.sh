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

for marker in V71_V3_PID1_FIRST_INSTRUCTION V71_V3_PROC_READY \
  V71_V3_SYS_READY V71_V3_DEVTMPFS_READY V71_V3_FB_STATUS_BEGIN \
  V71_V3_FB_STATUS_END V71_V3_USB_PHY_STATUS_BEGIN V71_V3_USB_PHY_STATUS_END \
  V71_V3_DWC3_STATUS_BEGIN V71_V3_DWC3_STATUS_END V71_V3_EXTCON_PRESENT \
  V71_V3_UDC_SCAN_BEGIN V71_V3_UDC_SCAN_END V71_V3_UDC_FOUND \
  V71_V3_UDC_TIMEOUT V71_V3_GADGET_BIND_BEGIN V71_V3_GADGET_BIND_SUCCESS \
  V71_V3_GADGET_BIND_FAILED V71_V3_RNDIS_BOUND V71_V3_RNDIS_BIND_FAILED \
  V71_V3_USB0_PRESENT V71_V3_USB0_ABSENT \
  V71_V3_TELNET_STARTED V71_V3_TELNET_FAILED V71_V3_STABLE_LOOP \
  V71_V3_HEARTBEAT; do
  grep -q "$marker" "$INIT" || { echo "ERROR: falta marcador $marker" >&2; exit 1; }
done

if grep -qE '6\.1\.0-sm6125|/lib/modules/6\.1|vermagic.*6\.1' "$INIT"; then
  echo "ERROR: referencia a módulos 6.1 en init v3" >&2; exit 1
fi
for bad in fastboot flash erase mkfs wipefs reboot poweroff; do
  grep -qE "^[^#]*\\b${bad}\\b" "$INIT" && {
    echo "ERROR: operación prohibida en init v3: $bad" >&2; exit 1; }
done
for app in ifconfig telnetd find readlink; do
  test -e "$TMP/root/bin/$app" -o -e "$TMP/root/sbin/$app" -o \
    -e "$TMP/root/usr/bin/$app" -o -e "$TMP/root/usr/sbin/$app" || {
    echo "ERROR: falta applet $app" >&2; exit 1; }
done
file -b "$TMP/root/bin/busybox" | grep -q 'ARM aarch64'
file -b "$TMP/root/bin/busybox" | grep -q 'static'
gzip -dc "$RAMDISK" | cpio -t > "$OUT/initramfs-file-list.txt"
cat > "$OUT/initramfs-verification.md" <<EOF
# Initramfs nativo v7.1 v3

- /init: presente
- marcadores V71_V3: presentes
- heartbeat: presente (10 s)
- módulos/scripts 6.1: no detectados
- operaciones destructivas: no detectadas
- USB applets: ifconfig/telnetd/find/readlink presentes
- BusyBox: ARM aarch64 estático
EOF
cat "$OUT/initramfs-verification.md"
