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
#     [--boot-layout v0-append|v2-dtb-field] \
#     [--ramdisk-offset 0x...] [--os-version X.Y.Z] [--os-patch-level YYYY-MM] \
#     [--boot-limit <bytes>]
#
# --boot-layout:
#   v2-dtb-field (defecto): header v2 + DTB en el campo v2 (dtb_addr
#       0x01f00000). LEGACY / KNOWN-BOOTLOADER-REJECTED en laurel_sprout
#       (el ABL rechaza toda imagen v2 con fallback a Fastboot; conservado
#       como evidencia histórica).
#   v0-append: header v0 + DTB concatenado al kernel (append_dtb), sin
#       campo DTB v2. ÚNICO layout que el ABL acepta (H61 6.1 sedfix →
#       INITRAMFS_SHELL_ACTIVE). Modo C validado en boot-builder-v0-validation.md.
#       La cmdline diagnóstica lleva boot.shell_on_fail=1 (shell persistente si
#       falta NIXOS_ROOT) y console=tty0 tras la serial (consola en pantalla).

set -Eeuo pipefail

KERNEL=""
DTB=""
RAMDISK=""
SYSTEM_PATH=""
OUT=""
BOOT_LIMIT="67108864"
BOOT_LAYOUT="v2-dtb-field"
RAMDISK_OFFSET="0x01000000"
OS_VERSION="12.0.0"
OS_PATCH_LEVEL="2026-08"

usage() {
  echo "uso: $0 --kernel <Image> --dtb <dtb> --ramdisk <cpio.gz> --system-path <ruta> --out <boot.img> [--boot-layout v0-append|v2-dtb-field] [--ramdisk-offset 0x...] [--os-version X.Y.Z] [--os-patch-level YYYY-MM] [--boot-limit <bytes>]" >&2
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
    --boot-layout) BOOT_LAYOUT="$2"; shift 2 ;;
    --ramdisk-offset) RAMDISK_OFFSET="$2"; shift 2 ;;
    --os-version) OS_VERSION="$2"; shift 2 ;;
    --os-patch-level) OS_PATCH_LEVEL="$2"; shift 2 ;;
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
HEADER_VERSION=""
DTB_OFFSET=""
APT="no"
case "$BOOT_LAYOUT" in
  v2-dtb-field)
    HEADER_VERSION="2"
    DTB_OFFSET="0x01f00000"
    CMDLINE="androidboot.hardware=laurel_sprout console=ttyMSM0,115200n8 root=LABEL=NIXOS_ROOT init=$INIT"
    info "layout v2-dtb-field (legacy / known-bootloader-rejected en laurel_sprout)"
    ;;
  v0-append)
    HEADER_VERSION="0"
    DTB_OFFSET=""
    APT="yes"
    CMDLINE="androidboot.hardware=laurel_sprout console=ttyMSM0,115200n8 console=tty0 boot.shell_on_fail=1 clk_ignore_unused msm.modeset=0 consoleblank=0 root=LABEL=NIXOS_ROOT init=$INIT"
    info "layout v0-append (header v0 + DTB concatenado al kernel)"
    ;;
  *)
    echo "ERROR: boot-layout inválido: $BOOT_LAYOUT (permitidos: v0-append, v2-dtb-field)" >&2
    exit 2
    ;;
esac

# Guarda contra duplicados contradictorios en la cmdline (singularidad).
# Nota: console= no se comprueba aquí: v0-append usa dos (ttyMSM0 + tty0).
for token in root= init= boot.shell_on_fail; do
  N="$(printf '%s' "$CMDLINE" | tr ' ' '\n' | grep -c "^$token" || true)"
  if [[ "$N" != "1" ]]; then
    echo "ERROR: cmdline inconsistente para '$token' (apariciones=$N): $CMDLINE" >&2
    exit 1
  fi
done
info "cmdline diagnóstica: $CMDLINE"

ASSEMBLE_ARGS=(
  "--kernel" "$KERNEL"
  "--ramdisk" "$RAMDISK"
  "--dtb" "$DTB"
  "--out" "$OUT"
  "--header-version" "$HEADER_VERSION"
  "--base" "0x00000000"
  "--pagesize" "4096"
  "--cmdline" "$CMDLINE"
  "--os-version" "$OS_VERSION"
  "--os-patch-level" "$OS_PATCH_LEVEL"
  "--kernel-offset" "0x00008000"
  "--ramdisk-offset" "$RAMDISK_OFFSET"
  "--tags-offset" "0x00000100"
)
[[ -n "$DTB_OFFSET" ]] && ASSEMBLE_ARGS+=(--dtb-offset "$DTB_OFFSET")
[[ "$APT" == "yes" ]] && ASSEMBLE_ARGS+=(--append-dtb)

bash "$TOOLS/assemble-boot-image.sh" "${ASSEMBLE_ARGS[@]}"

INSPECT_ARGS=(
  --boot "$OUT"
  --kernel "$KERNEL"
  --ramdisk "$RAMDISK"
  --dtb "$DTB"
  --boot-limit "$BOOT_LIMIT"
  --out "$(dirname "$OUT")/boot-validation"
)
[[ "$APT" == "yes" ]] && INSPECT_ARGS+=(--append-dtb)
bash "$TOOLS/inspect-boot-image.sh" "${INSPECT_ARGS[@]}"

info "boot.img listo: $OUT"
ls -lh "$OUT" "$(dirname "$OUT")/boot-validation"