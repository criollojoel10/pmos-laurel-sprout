#!/usr/bin/env bash
#
# sanitize-logs.sh
#
# Elimina identificadores de logs del dispositivo antes de publicarlos:
# serial, IMEI, direcciones MAC, tokens, y patrones de fastboot/adb.
#
# Uso: scripts/sanitize-logs.sh <archivo-origen> [<archivo-salida>]
# Licencia: GPL-3.0-or-later

set -Eeuo pipefail

SRC="${1:?uso: $0 <archivo-origen> [<archivo-salida>]}"
OUT="${2:-${SRC}.sanitized}"

[[ -f "$SRC" ]] || { echo "ERROR: $SRC no existe" >&2; exit 1; }

# Redactar identificadores con patrones conservadores.
sed -E \
  -e 's/[0-9A-Fa-f]{8}\s+fastboot/[REDACTED-SERIAL] fastboot/g' \
  -e 's/\b[0-9]{15}\b/[REDACTED-IMEI]/g' \
  -e 's/([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}/[REDACTED-MAC]/g' \
  -e 's/(gh[pous]_|github_pat_|AKIA)[A-Za-z0-9_]+/[REDACTED-TOKEN]/g' \
  -e 's/(BEGIN [A-Z ]*PRIVATE KEY)/[REDACTED-KEY]/g' \
  -e 's/(password|passwd|secret|token)[=: ][^ ]+/[REDACTED]/Ig' \
  -e 's/\b([0-9A-Fa-f]{8,16})\b/[REDACTED-ID]/g' \
  "$SRC" > "$OUT"

# Quitar salida completa de getvar all (puede contener identificadores).
sed -i -e '/partition-(type|size):persist/,/^$/d' -e '/modemst1/d' -e '/modemst2/d' -e '/fsg/d' -e '/fsc/d' -e '/efs/d' "$OUT"

echo "Log sanitizado en: $OUT"
exit 0
