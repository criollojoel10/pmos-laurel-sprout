#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# build-nixos-boot-image.sh
#
# Fase 3D: ensambla boot.img para laurel_sprout con kernel v7.1 compartido,
# el initramfs NixOS (3D-1) y DTB. La cmdline lleva el contrato stage-2:
#   init=<toplevel>/init  root=LABEL=NIXOS_ROOT  console=ttyMSM0,115200n8
# Sin flasheo (hardware tested = false); el boot-limit de la partición lo
# verifican los inspectores (64 MiB).
#
# Uso:
#   scripts/build-nixos-boot-image.sh \
#     --kernel <Image> \
#     --dtb <sm6125-xiaomi-laurel-sprout.dtb> \
#     --ramdisk <initramfs.cpio.gz> \
#     --system-path /nix/store/<hash>-nixos-system-... \
#     --out <boot.img> \
#     [--boot-limit <bytes>]

set -Eeuo pipefail

KERNEL=""
DTB=""
RAMDISK=""
SYSTEM_PATH=""
OUT=""
BOOT_LIMIT="67108864"

usage() {
  echo "uso: $0 --kernel <Image> --dtb <dtb> --ramdisk <cpio.gz> --system-path <ruta> --out <boot.img> [--boot-limit <bytes>]" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --kernel) KERNEL="$2"; shift 2 ;;
    --dtb) DTB="$2"; shift 2 ;;
    --ramdisk) RAMDISK="$2"; shift 2 ;;
    --system-path) SYSTEM_PATH="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --boot-limit) BOOT_LIMIT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$KERNEL" && -n "$DTB" && -n "$RAMDISK" && -n "$SYSTEM_PATH" && -n "$OUT" ]] || usage
for f in "$KERNEL" "$DTB" "$RAMDISK"; do
  [[ -f "$f" ]] || { echo "ERROR: falta $f" >&2; exit 1; }
done
[[ "$SYSTEM_PATH" == /nix/store/* ]] || { echo "ERROR: system-path debe ser /nix/store/... ($SYSTEM_PATH)" >&2; exit 1; }

info() { printf '[nixos-boot-image] %s\n' "$*" >&2; }

TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT="$SYSTEM_PATH/init"
CMDLINE="androidboot.hardware=laurel_sprout console=ttyMSM0,115200n8 root=LABEL=NIXOS_ROOT init=$INIT"

bash "$TOOLS/assemble-boot-image.sh" \
  --kernel "$KERNEL" \
  --ramdisk "$RAMDISK" \
  --dtb "$DTB" \
  --out "$OUT" \
  --header-version 2 \
  --base 0x00000000 \
  --pagesize 4096 \
  --cmdline "$CMDLINE" \
  --os-version 12.0.0 \
  --os-patch-level 2026-08 \
  --kernel-offset 0x00008000 \
  --ramdisk-offset 0x01000000 \
  --tags-offset 0x00000100 \
  --dtb-offset 0x01f00000

bash "$TOOLS/inspect-boot-image.sh" \
  --boot "$OUT" \
  --kernel "$KERNEL" \
  --ramdisk "$RAMDISK" \
  --dtb "$DTB" \
  --boot-limit "$BOOT_LIMIT" \
  --out "$(dirname "$OUT")/boot-validation"

info "boot.img listo: $OUT"
ls -lh "$OUT" "$(dirname "$OUT")/boot-validation"