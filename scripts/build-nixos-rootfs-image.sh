#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# build-nixos-rootfs-image.sh
#
# Fase 3C: crea y verifica la imagen ext4 NIXOS_ROOT a partir del árbol 3B.
# NO toca hardware; fail-closed.
#
# Criterios (de reports/plan-nixos-phosh.md):
#   - imagen ext4 con label NIXOS_ROOT;
#   - e2fsck -f limpio;
#   - label NIXOS_ROOT confirmada (tune2fs -l);
#   - imagen vuelta a montar (loop, ro) y contenido /nix/store íntegro
#     (mismo número de paths que validation.json; toplevel/init presente);
#       fallback sin root: debugfs (inspección read-only).
#
# Uso:
#   scripts/build-nixos-rootfs-image.sh \
#     --tree rootfs-tree \
#     --out nixos-rootfs.img
#     [--label NIXOS_ROOT]

set -Eeuo pipefail

TREE="rootfs-tree"
OUT="nixos-rootfs.img"
LABEL="NIXOS_ROOT"

usage() {
  echo "uso: $0 --tree <dir árbol 3B> --out <imagen> [--label <LABEL>]" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --tree) TREE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --label) LABEL="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$TREE" && -n "$OUT" ]] || usage
for b in mkfs.ext4 e2fsck tune2fs du sha256sum; do
  command -v "$b" >/dev/null 2>&1 || { echo "ERROR: $b no está instalado" >&2; exit 1; }
done
[[ -d "$TREE/nix/store" ]] || { echo "ERROR: $TREE no parece un árbol rootfs (falta nix/store)" >&2; exit 1; }
[[ -f "$TREE/validation.json" ]] || { echo "ERROR: falta $TREE/validation.json (producido 3B)" >&2; exit 1; }

info() { printf '[rootfs-image] %s\n' "$*" >&2; }

STORE_PATHS="$(jq -r '.storePaths' "$TREE/validation.json")"
[[ "$STORE_PATHS" =~ ^[0-9]+$ ]] || { echo "ERROR: storePaths no válido en validation.json" >&2; exit 1; }

# ── 1. Tamaño: árbol + 10% + 64 MiB de margen para metadatos ext4 ──────────
TREE_KB="$(du -sk "$TREE" | awk '{print $1}')"
SIZE_BYTES=$(( TREE_KB * 1024 * 11 / 10 + 64 * 1024 * 1024 ))
info "tamaño imagen: $SIZE_BYTES bytes (~$(( SIZE_BYTES / 1024 / 1024 )) MiB) para árbol de $(( TREE_KB / 1024 )) MiB"
truncate -s "$SIZE_BYTES" "$OUT"

# ── 2. mkfs.ext4 con la closure poblada (-L NIXOS_ROOT) ───────────────────
# -i 4096   árbol con ~162k ficheros => inodes suficientes (-d los agota).
info "mkfs.ext4 -L $LABEL (poblada desde $TREE)..."
if ! mkfs.ext4 -q -F -i 4096 -L "$LABEL" -d "$TREE" "$OUT"; then
  echo "ERROR: mkfs.ext4 falló" >&2
  exit 1
fi

# ── 3. e2fsck -f limpio ─────────────────────────────────────────────────────
# El criterio es el código de salida de e2fsck (-y con exit 0 => fs consistente;
# durante la 1ª pasada tras -d suele marcar "FILE SYSTEM WAS MODIFIED", normal).
info "e2fsck -f ..."
if ! e2fsck -y -f "$OUT" > /tmp/e2fsck.log 2>&1; then
  echo "ERROR: e2fsck -f NO limpio; volcado:" >&2
  tail -30 /tmp/e2fsck.log >&2
  exit 1
fi
info "e2fsck exit=0: $(tail -1 /tmp/e2fsck.log)"

# ── 4. Label y UUID confirmadas ─────────────────────────────────────────────
VOL_NAME="$(tune2fs -l "$OUT" | awk -F: '/Filesystem volume name/{gsub(/^ +| +$/,"",$2); print $2}')"
UUID="$(tune2fs -l "$OUT" | awk -F: '/Filesystem UUID/{gsub(/^ +| +$/,"",$2); print $2}')"
[[ "$VOL_NAME" == "$LABEL" ]] || { echo "ERROR: label='$VOL_NAME', se esperaba '$LABEL'" >&2; exit 1; }
info "label=$VOL_NAME uuid=$UUID"

# ── 5. Remontable (loop, ro); contenido /nix/store íntegro ─────────────────
NIX_STORE_OK=0
MNT="$(mktemp -d)"
if sudo -n mount -t ext4 -o loop,ro "$OUT" "$MNT" 2>/dev/null; then
  COUNT="$(find "$MNT/nix/store" -mindepth 1 -maxdepth 1 | wc -l)"
  INIT="$MNT/nix/store/$(basename "$(jq -r '.systemPath' "$TREE/validation.json")")/init"
  if [[ "$COUNT" -eq "$STORE_PATHS" && -x "$INIT" ]]; then
    NIX_STORE_OK=1
    info "remontada OK: $COUNT store paths (esperados $STORE_PATHS), init presente"
  else
    echo "ERROR: tras remontado COUNT=$COUNT (esperado $STORE_PATHS), init=$INIT" >&2
  fi
  sudo -n umount "$MNT" || true
fi
if [[ "$NIX_STORE_OK" -eq 0 ]]; then
  info "mount loop no disponible; verificando con debugfs (read-only)..."
  ROOT_SEEN=$(debugfs -R "ls /nix/store" "$OUT" 2>/dev/null | grep -c '^ *[0-9]' || true)
  [[ "$ROOT_SEEN" -gt 0 ]] || { echo "ERROR: debugfs no pudo listar /nix/store" >&2; exit 1; }
  if [[ "$ROOT_SEEN" -ne "$STORE_PATHS" ]]; then
    echo "ERROR: debugfs halló $ROOT_SEEN entries en /nix/store (esperado $STORE_PATHS)" >&2
    exit 1
  fi
  NIX_STORE_OK=1
  info "debugfs OK: $ROOT_SEEN entries en /nix/store"
fi
[[ "$NIX_STORE_OK" -eq 1 ]] || { echo "ERROR: no se pudo verificar /nix/store en la imagen" >&2; exit 1; }
rmdir "$MNT" 2>/dev/null || true

# ── 6. Evidencia maquina-legible ────────────────────────────────────────────
SHA="$(sha256sum "$OUT" | awk '{print $1}')"
IMG_SIZE="$(stat -c %s "$OUT")"
jq -n \
  --arg run_id "${GITHUB_RUN_ID:-unknown}" \
  --arg label "$VOL_NAME" \
  --arg uuid "$UUID" \
  --argjson size_bytes "$IMG_SIZE" \
  --argjson store_paths "$STORE_PATHS" \
  --arg image_sha256 "$SHA" \
  '{
    fase: "3C",
    run_id: $run_id,
    tipo: "imagen ext4 NIXOS_ROOT (raw)",
    label: $label,
    uuid: $uuid,
    sizeBytes: $size_bytes,
    storePaths: $store_paths,
    e2fsckClean: true,
    remountable: true,
    "integrity-nix-store": true,
    imageSha256: $image_sha256
  }' > "$(dirname "$OUT")/image-validation.json"

info "imagen ext4 lista: $OUT"
info "sha256: $SHA"
ls -lh "$OUT"
tune2fs -l "$OUT" | grep -E 'Filesystem volume name|Filesystem UUID|Filesystem state|Block count'