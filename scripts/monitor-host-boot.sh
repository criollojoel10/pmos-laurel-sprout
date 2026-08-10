#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# monitor-host-boot.sh
#
# Monitor host-side para pruebas A/B de arranque (AGENTS.md FASE 8).
# Se ejecuta en la máquina host (Fedora) ANTES del reboot del dispositivo.
# NO toca el teléfono: solo observa USB/red y registra con timestamp.
#
# Canales observados:
#   1. udevadm monitor (usb, net)
#   2. lsusb periódico
#   3. ip monitor link
#   4. ping periódico a la IP del gadget (172.16.42.1)
#   5. intento SSH periódico (root@172.16.42.1)
#
# Uso: scripts/monitor-host-boot.sh [--outdir DIR] [--timeout SEG] [--ssh-key RUTA]
#   --timeout  duración del monitor en segundos (def: 240; 0 = indefinido)
#   --ssh-key  clave SSH para el intento (def: local-private/ssh-laurel/id_ed25519)

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OUTDIR=""
TIMEOUT=240
SSH_KEY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --outdir) OUTDIR="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --ssh-key) SSH_KEY="$2"; shift 2 ;;
    *) echo "ERROR: argumento desconocido: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$OUTDIR" ]] || OUTDIR="$REPO_ROOT/local-private/host-boot-monitor/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUTDIR"
[[ -n "$SSH_KEY" ]] || SSH_KEY="$REPO_ROOT/local-private/ssh-laurel/id_ed25519"

for c in udevadm lsusb ip ping; do
  command -v "$c" >/dev/null 2>&1 || { echo "ERROR: $c no disponible en el host" >&2; exit 1; }
done

L_USB="$OUTDIR/udev-usb.log"
L_NET="$OUTDIR/udev-net.log"
L_LSUSB="$OUTDIR/lsusb.log"
L_IPMON="$OUTDIR/ipmon.log"
L_PING="$OUTDIR/ping.log"
L_SSH="$OUTDIR/ssh.log"
L_SUMMARY="$OUTDIR/summary.json"

ts() { date -u +%Y-%m-%dT%H:%M:%S.%3NZ; }
log() { echo "[$(ts)] $*" >> "$L_SUMMARY"; }

echo "Monitor host iniciado $(ts) -> $OUTDIR"
echo "  timeout: ${TIMEOUT}s | ping/ssh target: 172.16.42.1"
echo "  logs: $L_USB $L_NET $L_LSUSB $L_IPMON $L_PING $L_SSH $L_SUMMARY"

( udevadm monitor --udev --subsystem-match=usb --subsystem-match=net 2>&1 \
  | while IFS= read -r line; do echo "[$(ts)] $line"; done ) > "$L_USB" &
UDEV_PID=$!

( ip monitor link 2>&1 \
  | while IFS= read -r line; do echo "[$(ts)] $line"; done ) > "$L_IPMON" &
IPMON_PID=$!

run_snapshot() {
  {
    echo "[$(ts)] --- snapshot ---"
    echo "[$(ts)] lsusb:"
    lsusb 2>&1
    echo "[$(ts)] ip link (gadget):"
    ip -o link show 2>&1 | grep -E "usb|rndis|172\.16\.42\.1|DOWN|UP" || true
    echo "[$(ts)] arp/dns para 172.16.42.1:"
    ip neigh show 2>&1 | grep 172.16.42.1 || true
  } >> "$L_LSUSB"
}

snapshot() {
  run_snapshot
  if ping -c 1 -W 1 172.16.42.1 >/dev/null 2>&1; then
    log "PING_OK 172.16.42.1 responde"
    echo "[$(ts)] PING_OK" >> "$L_PING"
    if timeout 6 ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=4 \
        -o BatchMode=yes root@172.16.42.1 \
        'echo SSH_OK; uname -r 2>/dev/null; hostname 2>/dev/null' >/dev/null 2>&1; then
      log "SSH_OK root@172.16.42.1"
      echo "[$(ts)] SSH_OK" >> "$L_SSH"
    else
      log "PING_OK_PERO_NO_SSH"
      echo "[$(ts)] SSH_FAIL" >> "$L_SSH"
    fi
  else
    log "NO_PING"
    echo "[$(ts)] NO_PING" >> "$L_PING"
  fi
}

START=$(date +%s)
trap 'kill $UDEV_PID $IPMON_PID 2>/dev/null || true' EXIT

while true; do
  NOW=$(date +%s)
  ELAPSED=$((NOW - START))
  if [[ "$TIMEOUT" -gt 0 && "$ELAPSED" -ge "$TIMEOUT" ]]; then
    break
  fi
  snapshot
  sleep 5
done

log "MONITOR_FIN $(date -u)"

echo "Monitor finalizado $(ts). Revisar $OUTDIR (summary: $L_SUMMARY)"
