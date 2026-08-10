#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# ssh-inject-rootfs.sh — habilita SSH (sshd + red USB-gadget persistente)
# en una copia de la imagen rootfs histórica de pmOS para el Mi A3.
#
# Uso:
#   scripts/ssh-inject-rootfs.sh <part2.img> <part2-ssh.img> <authorized_keys>
#
# El image de salida es una COPIA del de entrada con:
#   1. sshd habilitado en el runlevel default de OpenRC
#   2. authorized_keys para root (root:root 0600, dir 0700)
#   3. red USB-gadget RNDIS persistente (configfs) + IP 172.16.42.1/24
#   4. dnsmasq sirviendo DHCP al host en usb0 (172.16.42.2), arrancado
#      por usbnet.start una vez usb0 existe
#   5. NetworkManager ignorando usb0 (config determinista, sin conflictos)
#
# SOLO LECTURA sobre el image de entrada; nunca toca el teléfono.
# Para diagnóstico experimental; la clave privada NUNCA se publica.

set -euo pipefail

SRC="$1"
OUT="$2"
AUTHKEYS="$3"

if [ ! -f "$SRC" ]; then
	echo "error: imagen de entrada no existe: $SRC" >&2
	exit 1
fi
if [ ! -f "$AUTHKEYS" ]; then
	echo "error: authorized_keys no existe: $AUTHKEYS" >&2
	exit 1
fi

[ "$OUT" = "$SRC" ] && { echo "error: salida igual a entrada" >&2; exit 1; }

echo "==> copiando $SRC -> $OUT"
cp -f --reflink=auto "$SRC" "$OUT"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

DBG() { debugfs -w -R "$1" "$OUT"; }

echo "==> inyectando authorized_keys"
DBG "rm /root/.ssh/authorized_keys" "$OUT" 2>/dev/null || true
DBG "mkdir /root/.ssh" "$OUT" 2>/dev/null || true
DBG "write $AUTHKEYS /root/.ssh/authorized_keys" "$OUT"
DBG "set_inode_field /root/.ssh/authorized_keys uid 0" "$OUT"
DBG "set_inode_field /root/.ssh/authorized_keys gid 0" "$OUT"
DBG "set_inode_field /root/.ssh/authorized_keys mode 0x8180" "$OUT"
DBG "set_inode_field /root/.ssh mode 0x41c0" "$OUT"

echo "==> habilitando sshd en runlevel default"
DBG "rm /etc/runlevels/default/sshd" "$OUT" 2>/dev/null || true
DBG "symlink /etc/runlevels/default/sshd /etc/init.d/sshd" "$OUT"

echo "==> configurando dnsmasq para usb0"
cat > "$TMPDIR/usb.conf" <<'EOF'
# pmOS diagnostic: DHCP para el host en la red USB-gadget (RNDIS)
interface=usb0
bind-interfaces
dhcp-range=172.16.42.2,172.16.42.2,255.255.255.0,1h
dhcp-option=3,172.16.42.1
EOF
DBG "write $TMPDIR/usb.conf /etc/dnsmasq.d/usb.conf" "$OUT"

echo "==> NetworkManager: ignorar usb0"
DBG "mkdir /etc/NetworkManager/conf.d" "$OUT" 2>/dev/null || true
cat > "$TMPDIR/usb0-unmanaged.conf" <<'EOF'
[keyfile]
unmanaged-devices=interface-name:usb0
EOF
DBG "write $TMPDIR/usb0-unmanaged.conf /etc/NetworkManager/conf.d/usb0-unmanaged.conf" "$OUT"

echo "==> script usbnet.start (configfs RNDIS + IP)"
cat > "$TMPDIR/usbnet.start" <<'EOF'
#!/bin/sh
# pmOS diagnostic: levantar USB-gadget RNDIS + red 172.16.42.1/24
# Replica determinista del estado de runtime verificado (2026-08-09).

G=/sys/kernel/config/usb_gadget/pmos
UDC=$(ls /sys/class/udc 2>/dev/null | head -n1)

mount -t configfs none /sys/kernel/config 2>/dev/null || true
modprobe libcomposite 2>/dev/null || true
modprobe usb_f_rndis 2>/dev/null || true

if [ -n "$UDC" ] && [ ! -d "$G" ]; then
	mkdir -p "$G"
	echo 0x18d1 > "$G/idVendor"
	echo 0xd001 > "$G/idProduct"
	mkdir -p "$G/strings/0x409"
	echo postmarketOS > "$G/strings/0x409/manufacturer"
	echo "Mi A3 (pmOS)" > "$G/strings/0x409/product"
	mkdir -p "$G/configs/c.1/strings/0x409"
	echo RNDIS > "$G/configs/c.1/strings/0x409/configuration"
	mkdir -p "$G/functions/rndis.usb0"
	mkdir -p "$G/configs/c.1/rndis.usb0"
	echo "$UDC" > "$G/UDC"
fi

ip link set usb0 up 2>/dev/null || true
if ! ip addr show usb0 2>/dev/null | grep -q '172.16.42.1'; then
	ip addr add 172.16.42.1/24 dev usb0 2>/dev/null || true
fi

# el servicio dnsmasq NO esta en el runlevel: se arranca aqui, con usb0 ya
# existente (bind-interfaces exige que la interfaz este presente)
rc-service dnsmasq start 2>/dev/null || true

exit 0
EOF
chmod 0755 "$TMPDIR/usbnet.start"
DBG "write $TMPDIR/usbnet.start /etc/local.d/usbnet.start" "$OUT"
DBG "set_inode_field /etc/local.d/usbnet.start mode 0x81ed" "$OUT"

echo "==> verificacion"
debugfs -R "ls -l /etc/runlevels/default" "$OUT" | grep -E 'sshd'
debugfs -R "ls -l /root/.ssh" "$OUT"
debugfs -R "cat /etc/dnsmasq.d/usb.conf" "$OUT"
debugfs -R "cat /etc/NetworkManager/conf.d/usb0-unmanaged.conf" "$OUT"
debugfs -R "stat /etc/local.d/usbnet.start" "$OUT" | grep -E 'Mode|Size'
echo "==> OK: $OUT"
