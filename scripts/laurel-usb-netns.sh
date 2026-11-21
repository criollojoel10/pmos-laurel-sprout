#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Prepara el enlace USB RNDIS de laurel en un network namespace.
#
# Problema: begonia ya usa 172.16.42.1 en su propio gadget usb0. Cuando laurel
# arranca, su gadget RNDIS tambien es 172.16.42.1; en el namespace principal
# esa IP es local y el trafico se queda en begonia. Moviendo la interfaz de
# laurel a un netns propio se evita el conflicto y no se toca usb0.
#
# Uso (root):
#   scripts/laurel-usb-netns.sh
#   sudo ip netns exec laurel ssh user@172.16.42.1
set -eu

NS=laurel
HOST_IP=172.16.42.2
GUEST_IP=172.16.42.1

if [ "$(id -u)" -ne 0 ]; then
	echo "ejecuta este script con sudo/root" >&2
	exit 1
fi

if ip netns list 2>/dev/null | grep -qx "$NS"; then
	if ip netns exec "$NS" ip -4 addr show 2>/dev/null | grep -q "$HOST_IP"; then
		echo "netns '$NS' ya configurado:"
		ip netns exec "$NS" ip -br addr
		exit 0
	fi
fi

IF=""
for d in /sys/class/net/*; do
	drv=""
	if [ -e "$d/device/driver" ]; then
		drv=$(basename "$(readlink -f "$d/device/driver")")
	fi
	if [ "$drv" = "rndis_host" ]; then
		IF=${d##*/}
		break
	fi
done

if [ -z "$IF" ]; then
	echo "no hay interfaz RNDIS de laurel." >&2
	echo "conecta el telefono, espera a que arranque y comprueba 'lsusb'" >&2
	exit 1
fi

ip netns add "$NS" 2>/dev/null || true
ip link set "$IF" netns "$NS"
ip netns exec "$NS" ip link set lo up
ip netns exec "$NS" ip link set "$IF" up
ip netns exec "$NS" ip addr add "$HOST_IP/24" dev "$IF" 2>/dev/null || true

echo "netns '$NS': $IF = $HOST_IP/24"
ip netns exec "$NS" ping -c 2 -W 2 "$GUEST_IP" || true
echo "SSH: sudo ip netns exec $NS ssh user@$GUEST_IP"
