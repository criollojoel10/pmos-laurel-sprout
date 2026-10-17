#!/bin/sh
# Bring up WCN3990 Wi-Fi on Xiaomi Mi A3 (laurel_sprout / SM6125).
# Order matters: pd-mapper only finds the PD maps once the modem (MPSS) is running.
set -u
log() { echo "mia3-wifi: $*"; }

# 1) wait for the modem remoteproc device node
i=0
while [ ! -e /sys/class/remoteproc/remoteproc0/state ] && [ "$i" -lt 90 ]; do
	i=$((i + 1)); sleep 1
done
if [ ! -e /sys/class/remoteproc/remoteproc0/state ]; then
	log "remoteproc0 no aparecio"; exit 0
fi

# 2) start the modem; it may crash-loop until its deps are ready, so retry
i=0
while [ "$(cat /sys/class/remoteproc/remoteproc0/state 2>/dev/null)" != "running" ] && [ "$i" -lt 25 ]; do
	echo start >/sys/class/remoteproc/remoteproc0/state 2>/dev/null || true
	sleep 2; i=$((i + 1))
done
log "modem=$(cat /sys/class/remoteproc/remoteproc0/state 2>/dev/null)"

# 3) pd-mapper needs the running modem to fetch the PD maps
systemctl restart pd-mapper.service 2>/dev/null || true
sleep 2
log "pd-mapper=$(systemctl is-active pd-mapper.service 2>/dev/null)"

# 4) (re)load the Wi-Fi driver so it does the QMI handshake with the WCN3990
modprobe -r ath10k_snoc 2>/dev/null || true
modprobe ath10k_snoc 2>/dev/null || true
sleep 3
log "wlan=$(ls /sys/class/net 2>/dev/null | grep -m1 '^wlan' || echo none)"
