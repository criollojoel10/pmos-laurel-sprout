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
#     [--ramdisk-offset 0x...] [--tags-offset 0x...] \
#     [--append-dtb]
#
# --append-dtb: concatena el DTB al final del payload del kernel
#   (kernel = Image/Image.gz + DTB, "vmlinuz-dtb", deviceinfo_append_dtb=true).
#   Es el único layout que el ABL de laurel_sprout acepta (H61 v0 sedfix).
#   Con header v2 deja dtb_size=0 en el campo DTB; con header v0 no existe
#   sección DTB. NO se combina con --dtb-offset (campo DTB v2) ni con maskas
#   de "QCDT": el ensamblado falla si ambos se piden.
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
APPEND_DTB="no"

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
    --append-dtb) APPEND_DTB="yes"; shift ;;
    *) usage ;;
  esac
done

[[ -n "$KERNEL" && -n "$RAMDISK" && -n "$DTB" && -n "$OUT" ]] || usage
for f in "$KERNEL" "$RAMDISK" "$DTB"; do
  [[ -f "$f" ]] || { echo "ERROR: archivo no existe: $f" >&2; exit 1; }
  [[ -s "$f" ]] || { echo "ERROR: archivo vacío: $f" >&2; exit 1; }
done

if [[ "$APPEND_DTB" == "yes" && -n "$DTBO_ADDR" ]]; then
  echo "ERROR: --append-dtb NO puede combinarse con --dtb-offset (campo DTB v2)" >&2
  exit 1
fi

info() { printf '[bootimg] %s\n' "$*" >&2; }

[[ -f "$PYBUILDER" ]] || { echo "ERROR: builder Python no encontrado: $PYBUILDER" >&2; exit 1; }

if [[ "$APPEND_DTB" == "yes" ]]; then
  KERNEL_SIZE="$(stat -c %s "$KERNEL")"
  DTB_SIZE="$(stat -c %s "$DTB")"
  info "layout append_dtb: kernel payload = kernel ($KERNEL_SIZE B) + dtb ($DTB_SIZE B) = $((KERNEL_SIZE + DTB_SIZE)) B"
fi

ARGS=(
  --kernel "$KERNEL"
  --ramdisk "$RAMDISK"
  --dtb "$DTB"
  --out "$OUT"
  --header-version "$HEADER_VERSION"
  --base "$BASE"
  --page-size "$PAGESIZE"
  --cmdline "$CMDLINE"
)
[[ -n "$KERNEL_OFFSET" ]]  && ARGS+=(--kernel-offset "$KERNEL_OFFSET")
[[ -n "$RAMDISK_OFFSET" ]] && ARGS+=(--ramdisk-offset "$RAMDISK_OFFSET")
[[ -n "$TAGS_OFFSET" ]]    && ARGS+=(--tags-offset "$TAGS_OFFSET")
[[ -n "$DTBO_ADDR" ]]      && ARGS+=(--dtb-offset "$DTBO_ADDR")
[[ -n "$OS_VERSION" ]]     && ARGS+=(--os-version "$OS_VERSION")
[[ -n "$OS_PATCH" ]]       && ARGS+=(--os-patch-level "$OS_PATCH")
[[ "$APPEND_DTB" == "yes" ]] && ARGS+=(--append-dtb)

info "ensamblando boot image (header v$HEADER_VERSION, append_dtb=$APPEND_DTB, builder python)..."
python3 "$PYBUILDER" "${ARGS[@]}"

info "boot image creado: $OUT"
ls -la "$OUT"
exit 0
