#!/bin/sh
# Licencia: GPL-3.0-or-later
# Copia logs runtime sin reiniciar, desmontar ni escribir particiones.
set -u

OUT=${1:-/tmp/v61-logs}
mkdir -p "$OUT"
STAMP=$(date -u +%Y%m%dT%H%M%SZ)

copy() {
    src=$1
    dst=$2
    if [ -e "$src" ]; then
        cp -a "$src" "$OUT/$dst" 2>/dev/null || cat "$src" >"$OUT/$dst" 2>/dev/null || true
    fi
}

copy /proc/cmdline cmdline.txt
copy /proc/version version.txt
copy /proc/uptime uptime.txt
copy /proc/meminfo meminfo.txt
copy /proc/interrupts interrupts.txt
copy /proc/partitions partitions.txt
copy /proc/mounts mounts.txt
copy /sys/fs/pstore pstore
dmesg >"$OUT/dmesg.txt" 2>&1 || true
if command -v journalctl >/dev/null 2>&1; then
    journalctl --no-pager -b >"$OUT/journal-boot.txt" 2>&1 || true
fi
sha256sum "$OUT"/* >"$OUT/SHA256SUMS" 2>/dev/null || true
printf 'collected=%s\n' "$STAMP" >"$OUT/manifest.txt"
printf '%s\n' "$OUT"
