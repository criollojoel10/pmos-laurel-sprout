#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# assemble-boot-image.sh
#
# Ensambla un boot.img Android para laurel_sprout.
#
# El ensamblado real se delega en scripts/build-boot-image.py (builder
# autocontenido en Python, sin dependencias de paquetes mkbootimg que
# varían entre distros). Este script solo traduce los argumentos.
#
# Investigó el formato real del boot image del Mi A3 (header v2, page 4096,
# base 0x0, kernel 0x8000, ramdisk 0x1000000, tags 0x100, dtb 0x1f00000).
#
# Uso:
#   scripts/assemble-boot-image.sh \
#     --kernel <Image> \
#     --ramdisk <initramfs> \
#     --dtb <sm6125-xiaomi-laurel-sprout.dtb> \
#     --out <boot.img> \
#     [--header-version N] [--base 0x...] [--pagesize N] \
#     [--cmdline "..."] [--os-version x.y] [--os-patch-level ...] \
#     [--kernel-offset 0x...] [--dtb-offset 0x...] \
#     [--ramdisk-offset 0x...] [--tags-offset 0x...]
#
# Localización del builder Python:
PYBUILDER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build-boot-image.py"

set -Eeuo pipefail

KERNEL=""
RAMDISK=""
DTB=""
OUT=""
HEADER_VERSION="2"
BASE="0x00000000"
PAGESIZE="4096"
CMDLINE="androidboot.hardware=laurel_sprout console=ttyMSM0,115200n8"
OS_VERSION=""
OS_PATCH=""
KERNEL_OFFSET=""
DTBO_ADDR=""
RAMDISK_OFFSET=""
TAGS_OFFSET=""

usage() {
  echo "uso: $0 --kernel <Image> --ramdisk <initramfs> --dtb <dtb> --out <boot.img> [opciones]" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --kernel) KERNEL="$2"; shift 2 ;;
    --ramdisk) RAMDISK="$2"; shift 2 ;;
    --dtb) DTB="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --header-version) HEADER_VERSION="$2"; shift 2 ;;
    --base) BASE="$2"; shift 2 ;;
    --pagesize) PAGESIZE="$2"; shift 2 ;;
    --cmdline) CMDLINE="$2"; shift 2 ;;
    --os-version) OS_VERSION="$2"; shift 2 ;;
    --os-patch-level) OS_PATCH="$2"; shift 2 ;;
    --kernel-offset) KERNEL_OFFSET="$2"; shift 2 ;;
    --dtb-offset) DTBO_ADDR="$2"; shift 2 ;;
    --ramdisk-offset) RAMDISK_OFFSET="$2"; shift 2 ;;
    --tags-offset) TAGS_OFFSET="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$KERNEL" && -n "$RAMDISK" && -n "$DTB" && -n "$OUT" ]] || usage
[[ -f "$KERNEL" ]] || { echo "ERROR: kernel no existe: $KERNEL" >&2; exit 1; }
[[ -f "$RAMDISK" ]] || { echo "ERROR: ramdisk no existe: $RAMDISK" >&2; exit 1; }
[[ -f "$DTB" ]] || { echo "ERROR: dtb no existe: $DTB" >&2; exit 1; }

info() { printf '[bootimg] %s\n' "$*" >&2; }

[[ -f "$PYBUILDER" ]] || { echo "ERROR: builder Python no encontrado: $PYBUILDER" >&2; exit 1; }

ARGS=(
  --kernel "$KERNEL"
  --ramdisk "$RAMDISK"
  --dtb "$DTB"
  --out "$OUT"
  --base "$BASE"
  --page-size "$PAGESIZE"
  --kernel-offset "$KERNEL_OFFSET"
  --ramdisk-offset "$RAMDISK_OFFSET"
  --tags-offset "$TAGS_OFFSET"
  --dtb-offset "$DTBO_ADDR"
  --cmdline "$CMDLINE"
)
[[ -n "$OS_VERSION" ]] && ARGS+=(--os-version "$OS_VERSION")
[[ -n "$OS_PATCH" ]] && ARGS+=(--os-patch-level "$OS_PATCH")

info "ensamblando boot image (header v$HEADER_VERSION, builder python)..."
python3 "$PYBUILDER" "${ARGS[@]}"

info "boot image creado: $OUT"
ls -la "$OUT"
exit 0
