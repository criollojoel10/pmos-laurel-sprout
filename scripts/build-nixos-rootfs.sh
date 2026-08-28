#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# build-nixos-rootfs.sh
#
# Ensambla el rootfs/imagen de arranque de NixOS para laurel_sprout a partir
# del kernel compartido. Se ejecuta en GitHub Actions (no localmente).
#
# CONTRATO fail-closed:
#   - La closure NixOS es OBJETIVO si/no: si `nix build ...toplevel` falla,
#     el script termina con exit != 0. NO hay fallback blando ni salida minima
#     camuflada de "exito".
#   - Los artefactos de kernel (Image, dtb, modules) son requeridos.
#   - El initramfs y boot.img se construyen y se ensamblan; si falta algo,
#     es un error (no un exito parcial).
#
# Pasos:
#   1. Construye la closure NixOS (aarch64; runner x86_64 con binfmt/qemu).
#   2. Copia kernel + dtb + modules (artefacto compartido).
#   3. Construye initramfs (BusyBox estático arm64, diagnostico hasta 3D).
#   4. Ensambla boot.img (kernel + dtb + ramdisk) via build-boot-image.py.
#   5. Checksums y manifest.
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

# ── 0. Entrada de kernel (artefacto compartido) ───────────────────────────
[[ -f "$KERNEL/Image" ]] || { echo "ERROR: falta $KERNEL/Image" >&2; exit 1; }
[[ -f "$KERNEL/sm6125-xiaomi-laurel-sprout.dtb" ]] || { echo "ERROR: falta DTB" >&2; exit 1; }
[[ -f "$KERNEL/modules.tar.zst" ]] || { echo "ERROR: falta modules.tar.zst" >&2; exit 1; }

mkdir -p /tmp/output-nixos

# ── 1. Closure NixOS (SIN fallback) ────────────────────────────────────────
CONFIG="laurel-${VARIANT}"
info "construyendo nixosConfigurations.${CONFIG}..."
cd nixos
: > /tmp/nix-build.log
if ! OUTPATH="$(nix build \
  ".#nixosConfigurations.${CONFIG}.config.system.build.toplevel" \
  --no-link --print-out-paths \
  >> /tmp/nix-build.log 2>&1)"; then
  info "ERROR: fallo construyendo la closure ${CONFIG}; no hay salida minima."
  info "Log completo: /tmp/nix-build.log"
  tail -60 /tmp/nix-build.log >&2 || true
  exit 1
fi
[[ -n "$OUTPATH" ]] || { echo "ERROR: nix build no devolvio out path" >&2; exit 1; }
OUTPATH="$(readlink -f "$OUTPATH")"
[[ -d "$OUTPATH" ]] || { echo "ERROR: out path invalido: $OUTPATH" >&2; exit 1; }
[[ -x "$OUTPATH/init" ]] || { echo "ERROR: falta init ejecutable en $OUTPATH" >&2; exit 1; }
info "closure construida OK: $OUTPATH"
echo "$OUTPATH" > /tmp/output-nixos/closure.outpath
info "últimas líneas del build:"
tail -3 /tmp/nix-build.log

# ── 1.2 Copia de kernel/dtb/módulos (requeridos) ──────────────────────────
cp "$KERNEL/Image" /tmp/output-nixos/
cp "$KERNEL/sm6125-xiaomi-laurel-sprout.dtb" /tmp/output-nixos/
mkdir -p /tmp/output-nixos/modules
tar --zstd -xf "$KERNEL/modules.tar.zst" -C /tmp/output-nixos/modules/
cp "${GITHUB_WORKSPACE:-.}/nixos/flake.nix" /tmp/output-nixos/ 2>/dev/null || true
[[ -f "${GITHUB_WORKSPACE:-.}/nixos/flake.lock" ]] && \
  cp "${GITHUB_WORKSPACE:-.}/nixos/flake.lock" /tmp/output-nixos/
cp -a "${GITHUB_WORKSPACE:-.}/nixos/" /tmp/output-nixos/nixos-config/
if strings "$KERNEL/Image" 2>/dev/null | grep -m1 'Linux version' \
  | sed 's/^Linux version \([^ ]*\).*/\1/' > /tmp/output-nixos/kernelrelease 2>/dev/null; then
  : # kernelrelease capturado
else
  info "WARN: no se pudo extraer kernelrelease; se usará 'unknown'"
  echo "unknown" > /tmp/output-nixos/kernelrelease
fi

# ── 2. Initramfs (BusyBox estático arm64, diagnóstico hasta Fase 3D) ───────
info "construyendo initramfs..."
[[ -x scripts/build-busybox-arm64.sh && -x scripts/build-diagnostic-initramfs.sh ]] || {
  info "ERROR: faltan scripts de initramfs" >&2; exit 1; }
chmod +x scripts/build-busybox-arm64.sh scripts/build-diagnostic-initramfs.sh
bash scripts/build-busybox-arm64.sh --out /tmp/busybox-out
bash scripts/build-diagnostic-initramfs.sh \
  --init initramfs/init \
  --busybox-root /tmp/busybox-out/applet-root \
  --out /tmp/initramfs-out
[[ -f /tmp/initramfs-out/initramfs.cpio.gz ]] || { echo "ERROR: initramfs no generado" >&2; exit 1; }

# ── 3. Boot image ──────────────────────────────────────────────────────────
info "ensamblando boot.img..."
python3 scripts/build-boot-image.py \
  --kernel "$KERNEL/Image" \
  --ramdisk /tmp/initramfs-out/initramfs.cpio.gz \
  --dtb "$KERNEL/sm6125-xiaomi-laurel-sprout.dtb" \
  --cmdline "console=ttyMSM0,115200n8 androidboot.hardware=laurel_sprout" \
  --out /tmp/output-nixos/boot.img
[[ -f /tmp/output-nixos/boot.img ]] || { echo "ERROR: boot.img no generado" >&2; exit 1; }

# ── 4. Checksums y manifest ────────────────────────────────────────────────
cd /tmp/output-nixos
find . -type f -not -name 'SHA256SUMS' -not -name 'manifest.json' \
  -exec sha256sum {} + | LC_ALL=C sort > SHA256SUMS
KERNELRELEASE="$(cat kernelrelease 2>/dev/null || echo 'unknown')"
jq -n \
  --arg variant "$VARIANT" \
  --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg kernelrelease "$KERNELRELEASE" \
  --arg closure "$OUTPATH" \
  '{distro:"nixos", variant:$variant, kernelrelease:$kernelrelease, closure:$closure, generated_at:$date}' > manifest.json
cat manifest.json

# Devolver a OUT para que el workflow suba los artefactos
mkdir -p "$OUT/nixos"
cp -a /tmp/output-nixos/. "$OUT/nixos/"
info "salida lista en $OUT/nixos"