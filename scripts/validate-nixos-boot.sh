#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# validate-nixos-boot.sh
#
# Fase 3E: empaqueta y valida el conjunto final NixOS console (boot.img desde
# 3D, rootfs desde 3C, closure desde 3A) y genera SHA256SUMS, índice de
# artefactos y resumen maquina-legible. Fail-closed; hardware tested = false.
#
# Uso:
#   scripts/validate-nixos-boot.sh \
#     --closure-dir <dir 3A> \
#     --image-dir <dir 3C> \
#     --boot-dir <dir 3D> \
#     --out <dir salida>

set -Eeuo pipefail

CLOSURE=""
IMAGE=""
BOOT=""
OUT="artifacts-3e"

usage() {
  echo "uso: $0 --closure-dir <dir> --image-dir <dir> --boot-dir <dir> [--out <dir>]" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --closure-dir) CLOSURE="$2"; shift 2 ;;
    --image-dir) IMAGE="$2"; shift 2 ;;
    --boot-dir) BOOT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$CLOSURE" && -n "$IMAGE" && -n "$BOOT" ]] || usage
for dir in "$CLOSURE" "$IMAGE" "$BOOT"; do
  [[ -d "$dir" ]] || { echo "ERROR: dir no existe: $dir" >&2; exit 1; }
done

info() { printf '[nixos-validate-boot] %s\n' "$*" >&2; }

TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOT_IMG="$(find "$BOOT" -maxdepth 1 -name 'boot-laurel-*.img' | head -1)"
[[ -n "$BOOT_IMG" ]] || { echo "ERROR: boot.img no encontrado en $BOOT" >&2; exit 1; }
ROOTFS_IMG="$(find "$IMAGE" -maxdepth 1 -name 'nixos-rootfs.img' | head -1)"
[[ -n "$ROOTFS_IMG" ]] || { echo "ERROR: nixos-rootfs.img no encontrado en $IMAGE" >&2; exit 1; }
NAR="$(find "$CLOSURE" -maxdepth 1 -name 'nixos-laurel-console-closure.nar.zst' | head -1)"
[[ -n "$NAR" ]] || { echo "ERROR: nar.zst no encontrado en $CLOSURE" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT" /tmp/unpack
info "boot.img: $BOOT_IMG"
info "rootfs:   $ROOTFS_IMG"
info "closure:  $NAR"

# ── 1. boot.img: magic, payloads y cmdline ───────────────────────────────
CMDLINE="$(python3 "$TOOLS/unpack-boot-image.py" --boot "$BOOT_IMG" --out /tmp/unpack --print-cmdline)"
grep -q 'root=LABEL=NIXOS_ROOT' <<<"$CMDLINE" || { echo "ERROR: cmdline sin root=LABEL=NIXOS_ROOT" >&2; exit 1; }
grep -q 'init=/nix/store/' <<<"$CMDLINE" || { echo "ERROR: cmdline sin init=/nix/store/..." >&2; exit 1; }
test -s /tmp/unpack/kernel || { echo "ERROR: kernel extraído vacío" >&2; exit 1; }
test -s /tmp/unpack/ramdisk || { echo "ERROR: ramdisk extraído vacío" >&2; exit 1; }
test -s /tmp/unpack/dtb || { echo "ERROR: dtb extraído vacío" >&2; exit 1; }

# ── 2. initramfs del boot: init, busybox, coherencia de kernelrelease ─────
gzip -dc /tmp/unpack/ramdisk | cpio -t 2>/dev/null | sort > /tmp/unpack/rd.list
grep -qE '(^\./)?init$' /tmp/unpack/rd.list || { echo "ERROR: init ausente en initramfs" >&2; exit 1; }
grep -qE '(^\./)?busybox$' /tmp/unpack/rd.list || { echo "ERROR: busybox ausente en initramfs" >&2; exit 1; }
rm -rf /tmp/unpack/rm
mkdir -p /tmp/unpack/rm
( cd /tmp/unpack/rm && gzip -dc /tmp/unpack/ramdisk | cpio -id --quiet ./busybox 2>/dev/null )
BB_ARCH="$(file /tmp/unpack/rm/busybox | grep -oE 'ARM aarch64|aarch64' | head -1)"
[[ "$BB_ARCH" == *aarch64* ]] || { echo "ERROR: busybox no aarch64 ($BB_ARCH)" >&2; exit 1; }

MREL="$(sed -nE 's#^\./lib/modules/([^/]+)/.*#\1#p' /tmp/unpack/rd.list | head -1)"
KREL="$(strings /tmp/unpack/kernel | grep -m1 '^Linux version' | sed 's/^Linux version \([^ ]*\).*/\1/' || true)"
[[ -n "$MREL" && -n "$KREL" ]] || { echo "ERROR: kernelrelease no extraíble (kernel='$KREL', modules='$MREL')" >&2; exit 1; }
[[ "$KREL" == "$MREL" ]] || {
  echo "ERROR: kernelrelease incongruente kernel='$KREL' modules='$MREL'" >&2
  exit 1
}
info "kernelrelease coherencia OK: $KREL"

# ── 3. SHA256SUMS y secret scan ───────────────────────────────────────────
SHA_BOOT="$(sha256sum "$BOOT_IMG" | awk '{print $1}')"
SHA_ROOTFS="$(sha256sum "$ROOTFS_IMG" | awk '{print $1}')"
SHA_NAR="$(sha256sum "$NAR" | awk '{print $1}')"
{
  printf '%s  boot-laurel-nixos-console.img\n' "$SHA_BOOT"
  printf '%s  nixos-rootfs.img\n' "$SHA_ROOTFS"
  printf '%s  nixos-laurel-console-closure.nar.zst\n' "$SHA_NAR"
} > "$OUT/SHA256SUMS"

TEXT_FILES=()
while IFS= read -r -d '' f; do
  TEXT_FILES+=("$f")
done < <(find "$BOOT" "$IMAGE" "$CLOSURE" "$OUT" -type f \( -name '*.txt' -o -name '*.json' -o -name '*.md' -o -name 'cmdline*' \) -print0 2>/dev/null || true)
if (( ${#TEXT_FILES[@]} > 0 )); then
  if grep -RlnE 'BEGIN (RSA|OPENSSH|EC|DSA) (PRIVATE )?KEY|PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}' "${TEXT_FILES[@]}" 2>/dev/null; then
    echo "ERROR: secretos detectados" >&2
    exit 1
  fi
fi
info "secret scan de text artifacts: limpio"

# ── 4. Evidencia maquina-legible (3E) ─────────────────────────────────────
IMG_SIZE="$(stat -c %s "$BOOT_IMG")"
jq -n \
  --arg run_id "${GITHUB_RUN_ID:-unknown}" \
  --arg boot_sha256 "$SHA_BOOT" \
  --arg rootfs_sha256 "$SHA_ROOTFS" \
  --arg closure_sha256 "$SHA_NAR" \
  --argjson boot_bytes "$IMG_SIZE" \
  --arg kernelrelease "$KREL" \
  --arg cmdline "$CMDLINE" \
  '{fase:"3E", run_id:$run_id, artifacts:{boot:{boot_sha256:$boot_sha256, bytes:$boot_bytes}, rootfs:{rootfs_sha256:$rootfs_sha256}, closure:{closure_sha256:$closure_sha256}}, kernelrelease:$kernelrelease, cmdline:$cmdline, hardwareTested:false}' > "$OUT/artifact-index.json"

cat > "$OUT/nixos-boot-validation.md" <<EOF
# Validación NixOS boot (FASE 3E)

Run: ${GITHUB_RUN_ID:-unknown} — commit ${GITHUB_SHA:-unknown}

| Comprobación | Resultado |
|---|---|
| boot.img ANDROID! + payloads extraíbles | OK |
| cmdline: root=LABEL=NIXOS_ROOT + init=/nix/store/... | OK |
| initramfs: init + busybox ARM64 (aarch64) | OK |
| kernelrelease kernel == modules del initramfs | $KREL |
| e2fsck NIXOS_ROOT (ya en 3C) | OK |
| SHA256SUMS de boot/rootfs/closure | generado |
| Secret scan | limpio |
| Hardware probado | **false** (documentado; no se flashea) |
EOF

info "artefactos de 3E en $OUT:"
ls -lh "$OUT"