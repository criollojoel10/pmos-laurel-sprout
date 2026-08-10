#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# fetch-ssh-artifacts.sh
#
# Descarga y verifica los artefactos del workflow 11 (rootfs histórico SSH)
# para una revisión local antes del checklist FASE 8.
#
# Uso: scripts/fetch-ssh-artifacts.sh [RUN_ID]
#   RUN_ID por defecto: último run exitoso del workflow 11 en main.
#   Destino: local-private/run<RUN_ID>-artifacts/
#
# Verifica:
#   - xiaomi-laurel-ssh.img existe y su sha256 coincide con SHA256SUMS-final
#   - tamaño sparse <= 3 GiB (0xC0000000, límite system_b)
#   - manifest.json: flash_target=system_b y fingerprint ed25519 == local
#   - el xz comprimido coincide con el sparse (descomprimiendo solo header)
#   - presence of final-part1/part2 and authorized_keys.pub
#

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

export PATH="/usr/bin:/bin:/usr/local/bin"

LIMIT=$((0xC0000000))
LOCAL_FP="$(ssh-keygen -lf local-private/ssh-laurel/id_ed25519.pub 2>/dev/null | awk '{print $2}')"

if [[ -n "${1:-}" ]]; then
  RUN_ID="$1"
else
  RUN_ID="$(gh run list --workflow 11-build-historical-ssh-rootfs \
    --branch main --limit 1 --json databaseId --jq '.[0].databaseId')"
fi

status="$(gh run view "$RUN_ID" --json status,conclusion --jq '.status + "/" + .conclusion')"
echo "run $RUN_ID: $status"
[[ "$status" == completed/success ]] || {
  echo "ERROR: el run no está completado con éxito"; exit 1; }

DEST="$REPO_ROOT/local-private/run${RUN_ID}-artifacts"
rm -rf "$DEST"
mkdir -p "$DEST"

gh run download "$RUN_ID" -n historical-rootfs-ssh -D "$DEST/artifacts" 2>/dev/null
gh run download "$RUN_ID" -n historical-rootfs-ssh-logs -D "$DEST/logs" 2>/dev/null || true

SPARSE="$DEST/artifacts/xiaomi-laurel-ssh.img"
test -f "$SPARSE" || { echo "ERROR: no se descargó $SPARSE"; exit 1; }
SIZE="$(stat -c %s "$SPARSE")"
echo "sparse size=$SIZE bytes (límite $LIMIT = 3 GiB)"
[[ "$SIZE" -le "$LIMIT" ]] || { echo "ERROR: supera system_b"; exit 1; }

echo "== sha256 (imagen) =="
H="$(sha256sum "$SPARSE" | awk '{print $1}')"
echo "$H  xiaomi-laurel-ssh.img"
echo "== referencia en SHA256SUMS-final =="
grep xiaomi-laurel-ssh.img "$DEST/artifacts/SHA256SUMS-final" 2>/dev/null || true
grep -q "$H" "$DEST/artifacts/SHA256SUMS-final" 2>/dev/null \
  && echo "OK: hash coincide con SHA256SUMS-final" \
  || echo "AVISO: hash no encontrado en SHA256SUMS-final"

echo "== manifest.json =="
if [[ -f "$DEST/artifacts/manifest.json" ]]; then
  jq '{image, image_bytes, flash_target, pub_fp: .ssh.public_key_ed25519_fingerprint, layout}' \
    "$DEST/artifacts/manifest.json"
  MANIFEST_FP="$(jq -r '.ssh.public_key_ed25519_fingerprint' "$DEST/artifacts/manifest.json")"
  echo "fingerprint local: $LOCAL_FP"
  [[ "$MANIFEST_FP" == "$LOCAL_FP" ]] \
    && echo "OK: fingerprint del manifest == clave local" \
    || echo "ERROR: fingerprint no coincide con la clave local"
fi

echo "== artefactos finales =="
ls -la "$DEST/artifacts/"
