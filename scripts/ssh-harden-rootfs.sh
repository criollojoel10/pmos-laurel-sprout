#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# ssh-harden-rootfs.sh — habilita acceso SSH para root sobre el rootfs
# HISTÓRICO postmarketOS 6.1 del Xiaomi Mi A3 (laurel_sprout), operando
# sobre la imagen RAW COMPLETA (MBR msdos).
#
# Por qué la imagen completa y no la partición aislada: el initramfs
# histórico (mkinitfs 1.5.1) espera el layout MBR y descubre pmOS_boot /
# pmOS_root mediante kpartx sobre /dev/block/... (partición física system_b).
# Flashear únicamente part2.img rompería ese flujo.
#
# Este script SOLO modifica la partición p2 (ext4, pmOS_root):
#   - /root/.ssh/authorized_keys   (0600 root:root, dir 0700)
#   - /etc/shadow                  (desbloquea la cuenta root: pmbootstrap
#                                   deja root con password '!' -> OpenSSH
#                                   rechaza a root con "account is locked"
#                                   incluso con publickey válida. Se fija un
#                                   hash SHA-512 determinista del password
#                                   '147147'; con PasswordAuthentication no +
#                                   PermitRootLogin prohibit-password el
#                                   password solo desbloquea la cuenta, el
#                                   acceso sigue siendo exclusivo por clave)
#   - /etc/ssh/sshd_config         (PermitRootLogin prohibit-password,
#                                   PasswordAuthentication no,
#                                   KbdInteractiveAuthentication no,
#                                   PubkeyAuthentication yes)
#   - /etc/runlevels/default/sshd  (symlink -> /etc/init.d/sshd; se crea si
#                                   la base no lo trae, p.ej. una base
#                                   construida con --no-sshd)
#
# La partición p1 (boot) queda byte-idéntica y se verifica al final.
# Determinista: misma entrada + misma clave => misma p2 resultante (los
# bytes de metadatos de ext4 modificados son los mínimos necesarios).
#
# Uso:
#   scripts/ssh-harden-rootfs.sh <raw-in> <raw-out> <authorized_keys> [sector]
#
#   <raw-in>          imagen MBR RAW de entrada (simg2img ya aplicado)
#   <raw-out>         imagen MBR RAW de salida (archivo NUEVO)
#   <authorized_keys> archivo con la(s) clave(s) pública(s) para root
#   [sector]          tamaño de sector MBR del dispositivo
#                     (default 512; laurel_sprout usa 4096,
#                     deviceinfo_rootfs_image_sector_size)
#
# Dependencias del runner/CI: e2fsprogs (debugfs, e2fsck), coreutils (dd),
# python3, jq, file. NO toca el teléfono. SOLO LECTURA sobre <raw-in>.

set -Eeuo pipefail

RAWIN="${1:-}"
RAWOUT="${2:-}"
AUTHKEYS="${3:-}"
SECTOR="${4:-512}"

if [[ -z "$RAWIN" || -z "$RAWOUT" || -z "$AUTHKEYS" ]]; then
  echo "uso: $0 <raw-in> <raw-out> <authorized_keys> [sector]" >&2
  exit 2
fi
[[ -f "$RAWIN" ]]  || { echo "error: raw-in no existe: $RAWIN" >&2; exit 1; }
[[ -f "$AUTHKEYS" ]] || { echo "error: authorized_keys no existe: $AUTHKEYS" >&2; exit 1; }
[[ "$RAWIN" != "$RAWOUT" ]] || { echo "error: raw-out debe ser distinto de raw-in" >&2; exit 1; }
if ! [[ "$SECTOR" =~ ^[0-9]+$ ]] || (( SECTOR == 0 )); then
  echo "error: sector no válido: $SECTOR" >&2
  exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

DBG() { debugfs -w -R "$1" "$TMP/root.img" >/dev/null 2>&1; }
RO() { debugfs -R "$1" "$TMP/root.img" 2>/dev/null; }

echo "==> copiando raw base: $RAWIN -> $RAWOUT"
cp -f --reflink=auto "$RAWIN" "$RAWOUT"

echo "==> parseando MBR (sector=$SECTOR)"
PARTS=$(python3 - "$RAWOUT" "$SECTOR" <<'PY'
import json, struct, sys
raw, sector = sys.argv[1], int(sys.argv[2])
with open(raw, "rb") as fh:
    d = fh.read(512)
if d[510:512] != b"\x55\xaa":
    sys.exit("ERROR: no es imagen MBR (falta firma 0x55aa)")
parts = []
for i in range(4):
    e = d[446 + i * 16 : 446 + i * 16 + 16]
    _, _, ptype, _, start, size = struct.unpack("<B3sB3sII", e)
    if ptype == 0 or size == 0:
        continue
    parts.append({"num": i + 1, "type": ptype, "start": start, "size": size})
if len(parts) < 2:
    sys.exit("ERROR: se esperaban al menos 2 particiones (p1 boot, p2 root)")
print(json.dumps(parts))
PY
)

P1_START=$(jq -r '.[] | select(.num==1) | .start' <<<"$PARTS")
P1_SIZE=$(jq -r '.[] | select(.num==1) | .size' <<<"$PARTS")
P2_START=$(jq -r '.[] | select(.num==2) | .start' <<<"$PARTS")
P2_SIZE=$(jq -r '.[] | select(.num==2) | .size' <<<"$PARTS")
[[ -n "$P2_START" && -n "$P2_SIZE" ]] \
  || { echo "ERROR: no se encontró p2 en el MBR"; exit 1; }
echo "   p1: start=$P1_START size=$P1_SIZE sectores"
echo "   p2: start=$P2_START size=$P2_SIZE sectores"

echo "==> extrayendo partición p2 (ext4, pmOS_root)"
dd if="$RAWOUT" of="$TMP/root.img" bs="$SECTOR" \
   skip="$P2_START" count="$P2_SIZE" status=none
FILE_P2=$(file -b "$TMP/root.img")
echo "   p2: $FILE_P2"
[[ "$FILE_P2" == *ext4* ]] || { echo "ERROR: p2 no es ext4"; exit 1; }

echo "==> inyectando /root/.ssh/authorized_keys"
DBG "rm /root/.ssh/authorized_keys"
DBG "mkdir /root/.ssh"
DBG "write $AUTHKEYS /root/.ssh/authorized_keys"
DBG "set_inode_field /root/.ssh/authorized_keys uid 0"
DBG "set_inode_field /root/.ssh/authorized_keys gid 0"
DBG "set_inode_field /root/.ssh/authorized_keys mode 0x8180"
DBG "set_inode_field /root/.ssh mode 0x41c0"

echo "==> desbloqueando cuenta root (/etc/shadow)"
RO "cat /etc/shadow" > "$TMP/shadow" \
  || { echo "ERROR: no existe /etc/shadow en p2"; exit 1; }
# Hash determinista SHA-512 de '147147' (salt fijo pmosroot). Root con '!' o
# '*' es "account locked" para OpenSSH: rechaza publickey aun con clave válida.
ROOT_HASH="\$6\$pmosroot\$5agmDwTqS6OfJAJRUQ9V4j6kE1hCs7couJeso8NAk99FXSWzAS6TFbeXHbF79ZcadYOMyzk5gMkytuKrPWM4T0"
if grep -qE '^root:(!|\*|):' "$TMP/shadow"; then
  sed -Ei "s|^root:[^:]*:|root:${ROOT_HASH}:|" "$TMP/shadow"
  echo "   root desbloqueado (password '147147', hash determinista)"
else
  echo "   root ya no estaba bloqueado ('!' no encontrado); sin cambios"
fi
# shellcheck disable=SC2016
grep -q '^root:\$6\$' "$TMP/shadow" \
  || { echo "ERROR: no se pudo desbloquear root en /etc/shadow"; exit 1; }
DBG "rm /etc/shadow"
DBG "write $TMP/shadow /etc/shadow"
DBG "set_inode_field /etc/shadow uid 0"
DBG "set_inode_field /etc/shadow gid 42"
DBG "set_inode_field /etc/shadow mode 0x81a0"

echo "==> endureciendo /etc/ssh/sshd_config"
RO "cat /etc/ssh/sshd_config" > "$TMP/sshd_config" \
  || { echo "ERROR: no existe /etc/ssh/sshd_config en p2"; exit 1; }
sed -i \
  -e 's/^#\s*PermitRootLogin\s\+.*/PermitRootLogin prohibit-password/' \
  -e 's/^PermitRootLogin\s\+.*/PermitRootLogin prohibit-password/' \
  -e 's/^#\s*PasswordAuthentication\s\+.*/PasswordAuthentication no/' \
  -e 's/^PasswordAuthentication\s\+.*/PasswordAuthentication no/' \
  -e 's/^#\s*KbdInteractiveAuthentication\s\+.*/KbdInteractiveAuthentication no/' \
  -e 's/^KbdInteractiveAuthentication\s\+.*/KbdInteractiveAuthentication no/' \
  -e 's/^#\s*PubkeyAuthentication\s\+.*/PubkeyAuthentication yes/' \
  -e 's/^PubkeyAuthentication\s\+.*/PubkeyAuthentication yes/' \
  "$TMP/sshd_config"
grep -q '^PermitRootLogin'            "$TMP/sshd_config" \
  || echo 'PermitRootLogin prohibit-password' >> "$TMP/sshd_config"
grep -q '^PasswordAuthentication'     "$TMP/sshd_config" \
  || echo 'PasswordAuthentication no' >> "$TMP/sshd_config"
grep -q '^PubkeyAuthentication'       "$TMP/sshd_config" \
  || echo 'PubkeyAuthentication yes' >> "$TMP/sshd_config"
DBG "rm /etc/ssh/sshd_config"
DBG "write $TMP/sshd_config /etc/ssh/sshd_config"
DBG "set_inode_field /etc/ssh/sshd_config uid 0"
DBG "set_inode_field /etc/ssh/sshd_config gid 0"
DBG "set_inode_field /etc/ssh/sshd_config mode 0x81a4"

echo "==> habilitando sshd en runlevel default (si falta)"
if RO "stat /etc/runlevels/default/sshd" | grep -q 'Type: symlink'; then
  echo "   ya presente"
else
  DBG "rm /etc/runlevels/default/sshd"
  DBG "symlink /etc/runlevels/default/sshd /etc/init.d/sshd"
  echo "   symlink creado"
fi

echo "==> e2fsck de p2 modificada (no destructivo)"
set +e
e2fsck -f -n "$TMP/root.img" > "$TMP/e2fsck.log" 2>&1
RC=$?
set -e
echo "   e2fsck rc=$RC"
if [[ $RC -gt 1 ]]; then
  echo "ERROR: e2fsck falla en p2 (rc=$RC)"; tail -20 "$TMP/e2fsck.log" >&2; exit 1
fi

echo "==> reintroduciendo p2 en $RAWOUT (conv=notrunc)"
dd if="$TMP/root.img" of="$RAWOUT" bs="$SECTOR" \
   seek="$P2_START" conv=notrunc status=none

echo "==> verificación: p1 byte-idéntica a la base"
dd if="$RAWIN"  of="$TMP/p1-base.img" bs="$SECTOR" \
   skip="$P1_START" count="$P1_SIZE" status=none
dd if="$RAWOUT" of="$TMP/p1-out.img"  bs="$SECTOR" \
   skip="$P1_START" count="$P1_SIZE" status=none
H1=$(sha256sum "$TMP/p1-base.img" | awk '{print $1}')
H2=$(sha256sum "$TMP/p1-out.img"  | awk '{print $1}')
if [[ "$H1" != "$H2" ]]; then
  echo "ERROR: p1 cambió entre base y salida"; exit 1
fi
echo "   p1 sha256=$H1 (idéntica)"

echo "==> verificación de la p2 final (rutas SSH)"
RO "cat /root/.ssh/authorized_keys" | cmp -s - "$AUTHKEYS" \
  || { echo "ERROR: authorized_keys no coincide con la entrada"; exit 1; }
RO "stat /root/.ssh/authorized_keys" | grep -qE 'Mode:[[:space:]]*0600' \
  || { echo "ERROR: authorized_keys no es 0600"; exit 1; }
RO "stat /root/.ssh" | grep -qE 'Mode:[[:space:]]*0700' \
  || { echo "ERROR: /root/.ssh no es 0700"; exit 1; }
RO "cat /etc/ssh/sshd_config" | grep -qx 'PermitRootLogin prohibit-password' \
  || { echo "ERROR: PermitRootLogin no endurecido"; exit 1; }
RO "cat /etc/ssh/sshd_config" | grep -qx 'PasswordAuthentication no' \
  || { echo "ERROR: PasswordAuthentication no aplicado"; exit 1; }
RO "cat /etc/ssh/sshd_config" | grep -qx 'PubkeyAuthentication yes' \
  || { echo "ERROR: PubkeyAuthentication yes no aplicado"; exit 1; }
# shellcheck disable=SC2016
RO "cat /etc/shadow" | grep -q '^root:\$6\$' \
  || { echo "ERROR: cuenta root sigue bloqueada en /etc/shadow"; exit 1; }
RO "stat /etc/runlevels/default/sshd" | grep -q 'Type: symlink' \
  || { echo "ERROR: sshd no habilitado en runlevel default"; exit 1; }

echo "==> OK: $RAWOUT (solo p2 modificada; p1 idéntica)"
echo "    tamaño raw: $(stat -c %s "$RAWOUT") bytes"
echo "    sha256 raw: $(sha256sum "$RAWOUT" | awk '{print $1}')"
