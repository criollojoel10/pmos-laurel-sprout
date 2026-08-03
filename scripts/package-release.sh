#!/usr/bin/env bash
#
# package-release.sh
#
# Reúne artefactos validados y genera la GitHub prerelease experimental.
# Solo se ejecuta en CI (workflow 07) sobre main, con contents: write.
#
# Uso:
#   scripts/package-release.sh \
#     --work-dir <dir> --tag <tag> --title <título> --repo <org/repo>
# Licencia: GPL-3.0-or-later

set -Eeuo pipefail

WORK=""
TAG=""
TITLE=""
REPO=""
DRY=1

usage() {
  echo "uso: $0 --work-dir <dir> --tag <tag> --title <título> --repo <org/repo> [--publish]" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --work-dir) WORK="$2"; shift 2 ;;
    --tag) TAG="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --publish) DRY=0; shift ;;
    *) usage ;;
  esac
done

[[ -n "$WORK" && -n "$TAG" && -n "$TITLE" && -n "$REPO" ]] || usage
[[ -d "$WORK" ]] || { echo "ERROR: work-dir no existe: $WORK" >&2; exit 1; }

info() { printf '[release] %s\n' "$*" >&2; }

# Lista de artefactos esperados (los que existan se incluyen)
FILES=(
  "$WORK/boot-laurel-debug.img"
  "$WORK/boot-laurel-release.img"
  "$WORK/rootfs-laurel-console.img.xz"
  "$WORK/rootfs-laurel-plasma.img.xz"
  "$WORK/modules-laurel.tar.zst"
  "$WORK/dtb-laurel.tar.zst"
  "$WORK/manifest.json"
  "$WORK/SHA256SUMS"
  "$WORK/reports.tar.zst"
  "$WORK/INSTALL.md"
  "$WORK/RECOVERY.md"
  "$WORK/TESTING.md"
)

PRESENT=()
for f in "${FILES[@]}"; do
  [[ -f "$f" ]] && PRESENT+=("$f")
done

if (( ${#PRESENT[@]} == 0 )); then
  info "no hay artefactos en $WORK"
  exit 0
fi

info "artefactos a publicar: ${#PRESENT[@]}"
for f in "${PRESENT[@]}"; do
  info "  - $(basename "$f") ($(stat -c %s "$f") bytes)"
done

if (( DRY )); then
  info "modo seco (dry-run): no se publica release."
  info "para publicar: re-ejecutar con --publish"
  exit 0
fi

NOTES_FILE="$WORK/release-notes.md"
cat > "$NOTES_FILE" <<EOF
## postmarketOS Plasma Mobile for Xiaomi Mi A3 — Alpha

> **ESTADO**: prerelease, experimental, NOT validated on hardware.

- Kernel: fijado en \`sources.lock.json\`.
- Rootfs: postmarketOS Edge (systemd).
- Interfaz: Plasma Mobile.
- No incluye firmware con licencia incierta.

**No probado sobre hardware real.** Ver \`docs/INSTALL.md\` y \`docs/RECOVERY.md\`.
EOF

info "publicando prerelease $TAG ..."
gh release create "$TAG" \
  --repo "$REPO" \
  --title "$TITLE" \
  --notes-file "$NOTES_FILE" \
  --prerelease \
  "${PRESENT[@]}" 2>&1 | sed 's/^/[gh] /' >&2

info "release publicada."
exit 0
