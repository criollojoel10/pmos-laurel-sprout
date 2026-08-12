#!/bin/sh
# Licencia: GPL-3.0-or-later
# Valida una captura ya recogida; no ejecuta acciones sobre el telefono.
set -eu

ROOT=${1:?uso: v61-verify-runtime.sh <captura>}
fail=0
need_file() { [ -s "$ROOT/$1" ] || { printf 'MISSING %s\n' "$1"; fail=1; }; }
contains() { grep -qF "$2" "$ROOT/$1" || { printf 'MISSING_TEXT %s: %s\n' "$1" "$2"; fail=1; }; }

for file in uname.txt cmdline.txt uptime.txt dmesg.txt mounts.txt meminfo.txt framebuffer.txt usb.txt network.txt pstore.txt; do
    need_file "$file"
done
contains cmdline.txt 'consoleblank=0'
contains framebuffer.txt 'fb0'
contains dmesg.txt 'simplefb'

if grep -qE 'Kernel panic|Oops:|Internal error:|watchdog|SError' "$ROOT/dmesg.txt"; then
    printf 'FAIL fatal-pattern-in-dmesg\n'
    fail=1
fi

if [ "$fail" -ne 0 ]; then
    printf '%s\n' 'runtime validation: BLOCKED'
    exit 1
fi
printf '%s\n' 'runtime validation: static capture checks passed; hardware status remains unclassified'
