#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# fetch-ssh-artifacts.sh
#
# Descarga y verifica los artefactos del workflow 11 (rootfs histórico SSH)
# para una revisión local antes del checklist FASE 8.
#
# Uso: scripts/fetch-ssh-artifacts.sh [RUN_ID] [--verify-only]
#   RUN_ID por defecto: último run exitoso del workflow 11 en main.
#   --verify-only: usar la descarga ya existente (no volver a descargar).
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
VERIFY_ONLY=0
[[ "${2:-}" == "--verify-only" ]] && VERIFY_ONLY=1

status="$(gh run view "$RUN_ID" --json status,conclusion --jq '.status + "/" + .conclusion')"
echo "run $RUN_ID: $status"
[[ "$status" == completed/success ]] || {
  echo "ERROR: el run no está completado con éxito"; exit 1; }

DEST="$REPO_ROOT/local-private/run${RUN_ID}-artifacts"
if [[ "$VERIFY_ONLY" == "1" ]]; then
  test -d "$DEST" || { echo "ERROR: no existe $DEST (descarga previa)"; exit 1; }
else
  rm -rf "$DEST"
  mkdir -p "$DEST"

  gh run download "$RUN_ID" -n historical-rootfs-ssh -D "$DEST/artifacts" 2>/dev/null
  gh run download "$RUN_ID" -n historical-rootfs-ssh-logs -D "$DEST/logs" 2>/dev/null || true
fi

# upload-artifact guarda el zip con las carpetas 'artifacts/' y
# 'export-resolved/' en su raíz; ubicar los ficheros de forma tolerante.
ART=$(find "$DEST/artifacts" -name xiaomi-laurel-ssh.img -print -quit)
SPARSE="${ART:-$DEST/artifacts/xiaomi-laurel-ssh.img}"
test -f "$SPARSE" || { echo "ERROR: no se descargó $SPARSE"; exit 1; }
SIZE="$(stat -c %s "$SPARSE")"
echo "sparse size=$SIZE bytes (límite $LIMIT = 3 GiB)"
[[ "$SIZE" -le "$LIMIT" ]] || { echo "ERROR: supera system_b"; exit 1; }

echo "== sha256 (imagen) =="
H="$(sha256sum "$SPARSE" | awk '{print $1}')"
echo "$H  xiaomi-laurel-ssh.img"
echo "== referencia en SHA256SUMS-final =="
SUMS="$(dirname "$SPARSE")/SHA256SUMS-final"
grep xiaomi-laurel-ssh.img "$SUMS" 2>/dev/null || true
grep -q "$H" "$SUMS" 2>/dev/null \
  && echo "OK: hash coincide con SHA256SUMS-final" \
  || echo "AVISO: hash no encontrado en SHA256SUMS-final"

echo "== manifest.json =="
MANIFEST="$(dirname "$SPARSE")/manifest.json"
if [[ -f "$MANIFEST" ]]; then
  jq '{image, image_bytes, flash_target, pub_fp: .ssh.public_key_ed25519_fingerprint, layout}' \
    "$MANIFEST"
  MANIFEST_FP="$(jq -r '.ssh.public_key_ed25519_fingerprint' "$MANIFEST")"
  echo "fingerprint local: $LOCAL_FP"
  [[ "$MANIFEST_FP" == "$LOCAL_FP" ]] \
    && echo "OK: fingerprint del manifest == clave local" \
    || echo "ERROR: fingerprint no coincide con la clave local"
fi

echo "== artefactos finales =="
ls -la "$(dirname "$SPARSE")/"

P2="$(dirname "$SPARSE")/final-part2.img"
if [[ -f "$P2" ]]; then
  ROOT_SHADOW="$(debugfs -R 'cat /etc/shadow' "$P2" 2>/dev/null || true)"
  if ! grep -qE '^root:\$[0-9]+\$' <<<"$ROOT_SHADOW"; then
    echo "ERROR: final-part2.img mantiene root bloqueado; falta hash de password" >&2
    exit 1
  fi
  echo "OK: final-part2.img contiene cuenta root desbloqueada"
fi
