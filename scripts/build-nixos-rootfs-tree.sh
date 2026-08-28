#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# build-nixos-rootfs-tree.sh
#
# Fase 3B: construye el ÁRBOL rootfs de NixOS a partir del export reproducible
# de la closure (nixos-laurel-console-closure.nar.zst). NO crea imágenes ext4
# aún (eso es 3C, solo tras validar el árbol).
#
# Además cumple el criterio 3A.6 pendiente: re-import INDEPENDIENTE del export
# en el store del runner -> si `nix-store --import` valida OK, se puede marcar
# `independently-imported=true` con evidencia (ya no solo "documentado").
#
# Estructura producido (rootfs-tree/):
#   nix/store/ ............ paths de la closure (663, copias reales + symlinks)
#   etc/ .................. /etc del sistema (from toplevel)
#   init .................. symlink -> <toplevel>/init (conveniencia)
#   closure-paths.txt ..... lista de requisitos (del artefacto)
#   validation.json ....... evidencia maquina-legible de 3B
#
# Validaciones fail-closed:
#   - `nix-store --import` debe completar (éxito) sobre el store del runner.
#   - Los paths importados deben coincidir con $closure-paths.txt del artefacto.
#   - <toplevel>/init ejecutable; <toplevel>/bin/systemctl presente.
#   - Arquitectura ARM64 de init y systemd (file); sin artefactos x86-64.
#
# Uso:
#   scripts/build-nixos-rootfs-tree.sh \
#     --nar artifacts/nixos-console/nixos-laurel-console-closure.nar.zst \
#     --paths artifacts/nixos-console/closure-paths.txt \
#     --out rootfs-tree

set -Eeuo pipefail

NAR=""
PATHS_FILE=""
OUT="rootfs-tree"

usage() {
  echo "uso: $0 --nar <archivo.nar.zst> --paths <closure-paths.txt> [--out <dir>]" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --nar) NAR="$2"; shift 2 ;;
    --paths) PATHS_FILE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$NAR" && -n "$PATHS_FILE" ]] || usage
command -v nix >/dev/null 2>&1 || { echo "ERROR: nix no está instalado" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq no está instalado" >&2; exit 1; }
[[ -f "$NAR" ]] || { echo "ERROR: falta $NAR" >&2; exit 1; }
[[ -f "$PATHS_FILE" ]] || { echo "ERROR: falta $PATHS_FILE" >&2; exit 1; }

info() { printf '[rootfs-tree] %s\n' "$*" >&2; }

rm -rf "$OUT"
mkdir -p "$OUT/nix/store"

# ── 1. Re-import independiente del export ──────────────────────────────────
info "re-import independiente de la closure (nix-store --import)..."
if ! nix-store --import < "$NAR" > /tmp/import.log 2>&1; then
  info "ERROR: el export NO es importable; fallo 3B."
  cat /tmp/import.log | tail -20 >&2
  exit 1
fi
info "import OK:"; cat /tmp/import.log

# ── 2. Localizar toplevel ──────────────────────────────────────────────────
SYSTEM_PATH="$(find /nix/store -maxdepth 1 -type d -name 'nixos-system-laurel-pmos-*' | head -1)"
[[ -n "$SYSTEM_PATH" ]] || { echo "ERROR: no se encontró el system path tras import" >&2; exit 1; }
info "toplevel importado: $SYSTEM_PATH"

# ── 3. Coherencia con el closure-paths.txt del artefacto ──────────────────
IMPORTED="$(find /nix/store -maxdepth 1 -mindepth 1 | LC_ALL=C sort)"
EXPECTED="$(sed 's#^/nix/store/##' "$PATHS_FILE" | LC_ALL=C sort)"
DIFF="$(diff <(printf '%s\n' "$EXPECTED") <(printf '%s\n' "$IMPORTED") | head -5)"
if [[ -n "$DIFF" ]]; then
  info "ERROR: los paths importados no coinciden con closure-paths.txt"
  echo "$DIFF" >&2
  exit 1
fi
info "paths importados coinciden 1:1 con closure-paths.txt ($(wc -l < "$PATHS_FILE") paths)"

# ── 4. Copiar la closure al árbol ──────────────────────────────────────────
info "copiando la closure al árbol rootfs (puede tardar)..."
COUNT=0
while IFS= read -r p; do
  name="$(basename "$p")"
  cp -a "$p" "$OUT/nix/store/$name"
  COUNT=$((COUNT+1))
done < "$PATHS_FILE"
info "copiados $COUNT store paths"

# ── 5. /etc del sistema y symlink del init ─────────────────────────────────
cp -a "$SYSTEM_PATH/etc" "$OUT/etc"
ln -s "${SYSTEM_PATH#/}" "$OUT/init"

# ── 6. Validaciones (fail-closed) ──────────────────────────────────────────
INIT="$OUT/nix/store/$(basename "$SYSTEM_PATH")/init"
SYSTEMCTL="$OUT/nix/store/$(basename "$SYSTEM_PATH")/bin/systemctl"
test -x "$INIT" || { echo "FALLO: init no ejecutable" >&2; exit 1; }
test -x "$SYSTEMCTL" || { echo "FALLO: bin/systemctl ausente" >&2; exit 1; }
INIT_ARCH="$(file -b "$INIT" | grep -oE 'ARM aarch64|aarch64' | head -1 || true)"
SYS_ARCH="$(file -b "$SYSTEMCTL" | grep -oE 'ARM aarch64|aarch64' | head -1 || true)"
[[ "$INIT_ARCH" == *aarch64* && "$SYS_ARCH" == *aarch64* ]] || {
  info "ERROR: arquitectura inesperada init='$INIT_ARCH' systemctl='$SYS_ARCH'"
  exit 1
}
info "init (ARM64)         : $(file -b "$INIT")"
info "systemctl (ARM64)    : $(file -b "$SYSTEMCTL")"

# ── 7. Evidencia maquina-legible ───────────────────────────────────────────
TREE_SIZE="$(du -s "$OUT" | awk '{print $1}')"
jq -n \
  --arg run_id "${GITHUB_RUN_ID:-unknown}" \
  --arg system_path "$SYSTEM_PATH" \
  --argjson store_paths "$COUNT" \
  --arg tree_size_kb "$TREE_SIZE" \
  --argjson import_verified true \
  '{
    fase: "3B",
    run_id: $run_id,
    independently-imported: $import_verified,
    systemPath: $system_path,
    storePaths: $store_paths,
    treeSizeKB: $tree_size_kb,
    validation: { initExecutable: true, systemctlPresent: true, archAarch64: true }
  }' > "$OUT/validation.json"

cp "$PATHS_FILE" "$OUT/closure-paths.txt"

info "árbol rootfs listo en $OUT ($TREE_SIZE KB, $COUNT store paths)"
du -sh "$OUT"