#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# assemble-boot-image.sh
#
# Ensambla un boot.img Android para laurel_sprout usando mkbootimg/avbtool
# dentro de GitHub Actions. NO se ejecuta localmente.
#
# Investiga el formato real del boot image del Mi A3 antes de asumir nada
# (header version, page size, base, offsets, DTB append, vendor_boot, AVB).
#
# Uso:
#   scripts/assemble-boot-image.sh \
#     --kernel <Image> \
#     --ramdisk <initramfs> \
#     --dtb <sm6125-xiaomi-laurel-sprout.dtb> \
#     --out <boot.img> \
#     [--header-version N] [--base 0x...] [--pagesize N] \
#     [--cmdline "..."] [--os-version x.y] [--os-patch-level ...] \
#     [--dtbo-address 0x...] [--ramdisk-offset 0x...] [--tags-offset 0x...]

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
    --dtbo-address) DTBO_ADDR="$2"; shift 2 ;;
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

# mkbootimg disponible en repos? Intentar, con mensaje claro si no.
command -v mkbootimg >/dev/null 2>&1 || { echo "ERROR: mkbootimg requerido (instalar en CI)" >&2; exit 1; }

ARGS=(
  --kernel "$KERNEL"
  --ramdisk "$RAMDISK"
  --dtb "$DTB"
  --header_version "$HEADER_VERSION"
  --base "$BASE"
  --pagesize "$PAGESIZE"
  --cmdline "$CMDLINE"
)
[[ -n "$OS_VERSION" ]] && ARGS+=(--os_version "$OS_VERSION")
[[ -n "$OS_PATCH" ]] && ARGS+=(--os_patch_level "$OS_PATCH")
[[ -n "$DTBO_ADDR" ]] && ARGS+=(--dtb_offset "$DTBO_ADDR")
[[ -n "$RAMDISK_OFFSET" ]] && ARGS+=(--ramdisk_offset "$RAMDISK_OFFSET")
[[ -n "$TAGS_OFFSET" ]] && ARGS+=(--tags_offset "$TAGS_OFFSET")

info "ensamblando boot image (header v$HEADER_VERSION)..."
mkbootimg "${ARGS[@]}" -o "$OUT" 2>&1 | sed 's/^/[mkbootimg] /' >&2

info "boot image creado: $OUT"
ls -la "$OUT"
exit 0
