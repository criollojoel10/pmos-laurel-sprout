#!/bin/sh
# Licencia: GPL-3.0-or-later
# Resumen no destructivo del runtime Linux 6.1.
set -u

OUT=${1:-/tmp/v61-health}
mkdir -p "$OUT"

run() {
    name=$1
    shift
    "$@" >"$OUT/$name" 2>&1 || printf 'command failed: %s\n' "$*" >>"$OUT/$name"
}

run uname.txt uname -a
run cmdline.txt cat /proc/cmdline
run uptime.txt cat /proc/uptime
run dmesg.txt dmesg
run mounts.txt mount
run lsblk.txt lsblk
run partitions.txt cat /proc/partitions
run meminfo.txt cat /proc/meminfo
run interrupts.txt cat /proc/interrupts
run devices-platform.txt ls -la /sys/devices/platform
run deferred-probes.txt cat /sys/kernel/debug/devices_deferred
run framebuffer.txt sh -c 'cat /proc/fb; ls -la /sys/class/graphics; cat /sys/class/graphics/fb0/{name,modes,stride,virtual_size,state} 2>/dev/null'
run drm.txt sh -c 'ls -la /dev/dri /sys/class/drm 2>/dev/null'
run usb.txt sh -c 'ls -la /sys/class/udc /sys/class/net/usb0 /sys/bus/usb/devices 2>/dev/null'
run network.txt ip -details addr
run firmware.txt sh -c 'dmesg | grep -iE "firmware|ath10k|wcn|remoteproc|qmi|bluetooth|hci"'
# shellcheck disable=SC2016 # $x must expand in the child shell, not here.
run remoteproc.txt sh -c 'ls -la /sys/class/remoteproc; for x in /sys/class/remoteproc/*; do cat "$x/name" "$x/state" 2>/dev/null; done'
run thermal.txt sh -c 'find /sys/class/thermal -maxdepth 2 -type f -print -exec cat {} \;'
run power-supply.txt sh -c 'find /sys/class/power_supply -maxdepth 2 -type f -print -exec cat {} \;'
run cpufreq.txt sh -c 'find /sys/devices/system/cpu -path "*/cpufreq/*" -type f -print -exec cat {} \;'
run cpuidle.txt sh -c 'find /sys/devices/system/cpu -path "*/cpuidle/*" -type f -print -exec cat {} \;'
run input.txt sh -c 'ls -la /sys/class/input /dev/input 2>/dev/null'
run bluetooth.txt sh -c 'ls -la /sys/class/bluetooth /sys/class/rfkill 2>/dev/null'
run sound.txt sh -c 'cat /proc/asound/cards 2>/dev/null; ls -la /dev/snd 2>/dev/null'
run pstore.txt sh -c 'mount -t pstore 2>/dev/null || true; ls -la /sys/fs/pstore 2>/dev/null'

{
    printf '# Linux 6.1 health report\n\n'
    printf -- '- generated: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- kernel: '; tr '\n' ' ' <"$OUT/uname.txt"; printf '\n'
    printf -- '- cmdline: '; tr '\n' ' ' <"$OUT/cmdline.txt"; printf '\n'
    printf -- '- uptime: '; tr '\n' ' ' <"$OUT/uptime.txt"; printf '\n'
    for pair in 'framebuffer:framebuffer.txt' 'drm:drm.txt' 'usb:usb.txt' 'pstore:pstore.txt' 'thermal:thermal.txt' 'power:power-supply.txt' 'cpufreq:cpufreq.txt' 'input:input.txt' 'bluetooth:bluetooth.txt' 'sound:sound.txt'; do
        label=${pair%%:*}; file=${pair#*:}
        printf -- '- %s bytes: %s\n' "$label" "$(wc -c <"$OUT/$file")"
    done
} >"$OUT/summary.md"

printf '%s\n' "$OUT/summary.md"
