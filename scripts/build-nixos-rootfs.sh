#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# build-nixos-rootfs.sh
#
# Ensambla el rootfs/imagen de arranque de NixOS para laurel_sprout a partir
# del kernel compartido. Se ejecuta en GitHub Actions (no localmente).
#
# Pasos:
#   1. Evalúa/construye la closure NixOS (experimental: cross aarch64 desde
#      runner x86_64; si falla, genera salida mínima + kernel + initramfs).
#   2. Construye un initramfs mínimo de diagnóstico (BusyBox estático arm64).
#   3. Ensambla boot.img (kernel + dtb + ramdisk) via build-boot-image.py.
#
# Uso:
#   scripts/build-nixos-rootfs.sh \
#     --kernel-artifact /tmp/kernel-artifact \
#     --variant <console|gnome|kde> \
#     --out /tmp/output

set -Eeuo pipefail

KERNEL=""
VARIANT="console"
OUT=""

usage() {
  echo "uso: $0 --kernel-artifact <dir> [--variant console|gnome|kde] [--out <dir>]" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --kernel-artifact) KERNEL="$2"; shift 2 ;;
    --variant) VARIANT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$KERNEL" && -n "$OUT" ]] || usage
mkdir -p "$OUT"
OUT="$(readlink -f "$OUT")"
KERNEL="$(readlink -f "$KERNEL")"

info() { printf '[nixos] %s\n' "$*" >&2; }

command -v nix >/dev/null 2>&1 || { echo "ERROR: nix no está instalado" >&2; exit 1; }

# ── 1. Closure NixOS ──────────────────────────────────────────────────────
CONFIG="laurel-${VARIANT}"
info "evaluando nixosConfigurations.${CONFIG}..."
cd nixos
if ! nix build \
  ".#nixosConfigurations.${CONFIG}.config.system.build.toplevel" \
  --no-link --print-out-paths \
  > /tmp/nix-build.log 2>&1; then
  info "NOTE: NixOS cross-build para SM6125 es experimental."
  info "La build requiere emulación aarch64 o runner nativo."
  info "Log completo: /tmp/nix-build.log (se sube como diagnostico)."
  info "Generando salida mínima (kernel + initramfs diagnostico)."
else
  info "closure NixOS construida OK, últimos logs:"
  tail -3 /tmp/nix-build.log
fi

mkdir -p /tmp/output-nixos
cp "$KERNEL/Image" /tmp/output-nixos/ 2>/dev/null || true
cp "$KERNEL/sm6125-xiaomi-laurel-sprout.dtb" /tmp/output-nixos/ 2>/dev/null || true
if [[ -f "$KERNEL/modules.tar.zst" ]]; then
  mkdir -p /tmp/output-nixos/modules
  tar --zstd -xf "$KERNEL/modules.tar.zst" -C /tmp/output-nixos/modules/ 2>/dev/null || true
fi
cp "${GITHUB_WORKSPACE:-.}/nixos/flake.nix" /tmp/output-nixos/ 2>/dev/null || true
cp -a "${GITHUB_WORKSPACE:-.}/nixos/" /tmp/output-nixos/nixos-config/ 2>/dev/null || true
strings "$KERNEL/Image" 2>/dev/null | grep -m1 'Linux version' \
  | sed 's/^Linux version \([^ ]*\).*/\1/' > /tmp/output-nixos/kernelrelease 2>/dev/null || true

# ── 2. Initramfs mínimo (BusyBox estático arm64) ─────────────────────────
info "construyendo initramfs diagnóstico..."
if [[ -x scripts/build-busybox-arm64.sh && -x scripts/build-diagnostic-initramfs.sh ]]; then
  chmod +x scripts/build-busybox-arm64.sh scripts/build-diagnostic-initramfs.sh
  bash scripts/build-busybox-arm64.sh --out /tmp/busybox-out
  bash scripts/build-diagnostic-initramfs.sh \
    --init initramfs/init \
    --busybox-root /tmp/busybox-out/applet-root \
    --out /tmp/initramfs-out
else
  info "scripts de initramfs no disponibles; sin ramdisk"
fi

# ── 3. Boot image ─────────────────────────────────────────────────────────
if [[ -f "$KERNEL/Image" && -f /tmp/initramfs-out/initramfs.cpio.gz ]]; then
  info "ensamblando boot.img..."
  python3 scripts/build-boot-image.py \
    --kernel "$KERNEL/Image" \
    --ramdisk /tmp/initramfs-out/initramfs.cpio.gz \
    --dtb "$KERNEL/sm6125-xiaomi-laurel-sprout.dtb" \
    --cmdline "console=ttyMSM0,115200n8 androidboot.hardware=laurel_sprout" \
    --out /tmp/output-nixos/boot.img || info "NOTA: fallo al ensamblar boot.img"
fi

# ── 4. Checksums y manifest ───────────────────────────────────────────────
cd /tmp/output-nixos
find . -type f -not -name 'SHA256SUMS' -not -name 'manifest.json' \
  -exec sha256sum {} + > SHA256SUMS 2>/dev/null || true
KERNELRELEASE="$(cat kernelrelease 2>/dev/null || strings Image 2>/dev/null \
  | grep -m1 '^Linux version' | sed 's/^Linux version \([^ ]*\).*/\1/' || echo 'unknown')"
jq -n \
  --arg variant "$VARIANT" \
  --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg kernelrelease "$KERNELRELEASE" \
  '{distro:"nixos", variant:$variant, kernelrelease:$kernelrelease, generated_at:$date}' > manifest.json
cat manifest.json

# Devolver a OUT para que el workflow suba los artefactos
mkdir -p "$OUT/nixos"
cp -a /tmp/output-nixos/. "$OUT/nixos/"
info "salida lista en $OUT/nixos"