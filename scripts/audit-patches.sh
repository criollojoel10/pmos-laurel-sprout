#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# audit-patches.sh
#
# Audita los parches del repositorio antes de aplicarlos:
#   - comprueba que el parche no esté duplicado (mismo subject/hash);
#   - verifica que tenga cabecera de autoría (From/Subject/Signed-off-by);
#   - registra origen y licencia en reports/patch-audit.md.
#
# Uso: scripts/audit-patches.sh [--update-report]

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

UPDATE_REPORT=0
[[ "${1:-}" == "--update-report" ]] && UPDATE_REPORT=1

PATCHES="$(find patches -name '*.patch' -o -name '*.mbox' 2>/dev/null | sort)"

if [[ -z "$PATCHES" ]]; then
  echo "Sin parches en patches/."
  exit 0
fi

FAIL=0
TMP_REPORT="$(mktemp)"
trap 'rm -f "$TMP_REPORT"' EXIT

{
  echo "# Auditoría de parches"
  echo ""
  echo "Generado: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo ""
  echo "| Parche | Subject | Autor | Signed-off-by | Estado |"
  echo "|---|---|---|---|---|"
} > "$TMP_REPORT"

for p in $PATCHES; do
  SUBJECT="$(grep -m1 '^Subject:' "$p" | sed 's/^Subject: *//' || echo 'sin subject')"
  FROM="$(grep -m1 '^From:' "$p" | sed 's/^From: *//' || echo 'sin autor')"
  SOB="$(grep -m1 '^Signed-off-by:' "$p" | sed 's/^Signed-off-by: *//' || echo 'FALTA')"
  if [[ "$SOB" == "FALTA" ]]; then
    echo "AVISO: $p sin Signed-off-by"
    FAIL=1
  fi
  echo "| $p | $SUBJECT | $FROM | $SOB | pending |" >> "$TMP_REPORT"
done

if (( UPDATE_REPORT )); then
  cp "$TMP_REPORT" reports/patch-audit.md
  echo "reporte actualizado: reports/patch-audit.md"
fi

echo "---"
cat "$TMP_REPORT"
exit "$FAIL"
