#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# build-nixos-initramfs.sh
#
# Fase 3D: ensambla el initramfs (cpio.gz) para arrancar NixOS en laurel_sprout.
# Contiene uinit propio (monta root, carga módulos UFS/DWC3, switch_root al
# stage-2 de la closure), busybox ARM64 estático y los módulos del kernel v7.1
# compartido (NO se reconstruye kernel; se consume el artefacto del build).
#
# El init replica el contrato real de stage-1 de NixOS (ver investigación en
# reports/plan-nixos-phosh.md): parsea /proc/cmdline (init=, root=),
# localiza LABEL=NIXOS_ROOT, monta ext4 rw, mueve /proc /sys /dev /run y hace
# `exec switch_root /newroot <stage2>`.
#
# Uso:
#   scripts/build-nixos-initramfs.sh \
#     --busybox /tmp/busybox-out/busybox \
#     --modules /tmp/kernel-artifact/modules.tar.zst \
#     --out /tmp/initramfs-out

set -Eeuo pipefail

BUSYBOX=""
MODULES=""
OUT="initramfs-out"

usage() {
  echo "uso: $0 --busybox <binario> --modules <modules.tar.zst> [--out <dir>]" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --busybox) BUSYBOX="$2"; shift 2 ;;
    --modules) MODULES="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$BUSYBOX" && -n "$MODULES" ]] || usage
[[ -f "$BUSYBOX" ]] || { echo "ERROR: falta el binario busybox ($BUSYBOX)" >&2; exit 1; }
[[ -f "$MODULES" ]] || { echo "ERROR: falta modules.tar.zst ($MODULES)" >&2; exit 1; }
for b in cpio gzip sed; do
  command -v "$b" >/dev/null 2>&1 || { echo "ERROR: $b no está instalado" >&2; exit 1; }
done

info() { printf '[nixos-initramfs] %s\n' "$*" >&2; }

rm -rf "$OUT"
mkdir -p "$OUT"
OUT="$(readlink -f "$OUT")"

# ── 1. busybox + módulos ───────────────────────────────────────────────────
cp "$BUSYBOX" "$OUT/busybox"
chmod 755 "$OUT/busybox"
mkdir -p "$OUT/lib/modules"
tar --zstd -xf "$MODULES" -C "$OUT/lib/modules"
REL="$(ls "$OUT/lib/modules")"
info "kernelrelease de módulos: $REL"
if command -v depmod >/dev/null 2>&1; then
  depmod -b "$OUT" "$REL" 2>/dev/null || true
fi

# ── 2. uinit (contrato stage-1 de NixOS) ───────────────────────────────────
cat > "$OUT/init" <<'EOF'
#!/bin/busybox sh
export PATH=/bin:/sbin
busybox --install -s /bin

mount -t proc proc /proc 2>/dev/null || true
mount -t sysfs sysfs /sys 2>/dev/null || true
mount -t devtmpfs devtmpfs /dev 2>/dev/null || mount -t tmpfs tmpfs /dev
mkdir -p /dev/pts /run /tmp /newroot
mount -t devpts devpts /dev/pts 2>/dev/null || true
mount -t tmpfs tmpfs /run 2>/dev/null || true

echo /bin/busybox modprobe > /proc/sys/kernel/modprobe 2>/dev/null || true

shell_on_fail=0
stage2=/init
rootdev="LABEL=NIXOS_ROOT"
console=ttyMSM0
for o in $(cat /proc/cmdline); do
  case $o in
    init=*) stage2="${o#init=}" ;;
    root=*) rootdev="${o#root=}" ;;
    console=*) console="${o#console=}" ;;
    boot.shell_on_fail) shell_on_fail=1 ;;
    boot.debug) set -x ;;
  esac
done

recover() {
  msg="$1"
  echo "nixos-initramfs: $msg" > /dev/kmsg 2>/dev/null || true
  if [ "$shell_on_fail" = 1 ]; then
    echo "nixos-initramfs: shell interactivo en $console" > /dev/kmsg 2>/dev/null || true
    exec setsid sh -i < /dev/$console > /dev/$console 2> /dev/$console
  fi
  echo "nixos-initramfs: reiniciando" > /dev/kmsg 2>/dev/null || true
  sleep 3
  reboot -f
  exit 1
}

for m in dwc3_qcom dwc3 phy_qcom_qusb2 phy_qcom_qmp_pcie \
         phy_qcom_qmp_ufs phy_qcom_qmp_usb ufs_qcom ufs \
         ext4 crypto_sha256; do
  modprobe "$m" 2>/dev/null || true
done

sleep 2
udevadm settle 2>/dev/null || true

want="${rootdev#LABEL=}"
dev=""
i=0
while [ $i -lt 30 ]; do
  for d in $(awk 'NR>2{print $4}' /proc/partitions); do
    node="/dev/$d"
    lbl="$(blkid "$node" 2>/dev/null | sed -n 's/.*LABEL="\([^"]*\)".*/\1/p')"
    if [ "$lbl" = "$want" ]; then dev="$node"; break; fi
  done
  [ -n "$dev" ] && break
  sleep 1
  i=$((i+1))
done

[ -n "$dev" ] || recover "root $rootdev no encontrado"
mount -t ext4 -o rw "$dev" /newroot || recover "mount $dev falló"
[ -x "/newroot$stage2" ] || recover "init $stage2 no ejecutable"
for p in proc sys dev run; do
  mkdir -p "/newroot/$p"
  mount --move "/$p" "/newroot/$p" || recover "mount --move $p falló"
done
exec switch_root /newroot "$stage2" 2>/dev/null || recover "switch_root falló"
EOF
chmod 755 "$OUT/init"

# ── 3. Empacar initramfs.cpio.gz ───────────────────────────────────────────
( cd "$OUT" && find . -print0 | sort -z | cpio --null -o -H newc 2>/dev/null | gzip -9 ) > "$OUT/initramfs.cpio.gz"
info "initramfs.cpio.gz: $(du -h "$OUT/initramfs.cpio.gz" | cut -f1)"
info "uinit con módulos: $(gzip -dc "$OUT/initramfs.cpio.gz" | cpio -t 2>/dev/null | wc -l) entradas"