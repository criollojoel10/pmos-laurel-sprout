#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# monitor-workflow.sh
#
# Monitorea un run de GitHub Actions y registra SOLO transiciones de estado
# (no hace spam cada tick). Diseñado para ejecutarse desde cron cada 5
# minutos y para comprobaciones manuales puntuales.
#
# Estado se guarda en local-private/workflow-11-monitor/ (gitignored):
#   run-<ID>.json   último JSON crudo de gh run view
#   state-<ID>.txt  último snapshot (para detectar cambios)
#   <RUN_ID>.log    historial de transiciones
#
# Uso: scripts/monitor-workflow.sh [RUN_ID]
#   RUN_ID por defecto: último run de 11-build-historical-ssh-rootfs en main.
#

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

export PATH="/usr/bin:/bin:/usr/local/bin"

if [[ -n "${1:-}" ]]; then
  RUN_ID="$1"
else
  RUN_ID="$(gh run list --workflow 11-build-historical-ssh-rootfs \
    --branch main --limit 1 --json databaseId --jq '.[0].databaseId')"
fi

MON_DIR="$REPO_ROOT/local-private/workflow-11-monitor"
mkdir -p "$MON_DIR"
LOG="$MON_DIR/${RUN_ID}.log"
STATE="$MON_DIR/state-${RUN_ID}.txt"
JSON="$MON_DIR/run-${RUN_ID}.json"

# Fallos transitorios de red/gh: salir 0 para que cron reintente el próximo
# tick sin lanzar alertas falsas.
if ! gh run view "$RUN_ID" --json status,conclusion,createdAt,headSha,displayTitle,jobs > "$JSON" 2>/dev/null; then
  exit 0
fi

status="$(jq -r '.status // "unknown"' "$JSON")"
conclusion="$(jq -r '.conclusion // "-"' "$JSON")"
created="$(jq -r '.createdAt // "-"' "$JSON")"

# El paso actual = primer paso no terminado del job en curso.
current="$(jq -r '[.jobs[]?.steps[]? | select(.status == "queued" or .status == "in_progress") | .name][0] // "-"' "$JSON")"

snapshot="$(printf 'run=%s status=%s conclusion=%s\n%s' \
  "$RUN_ID" "$status" "$conclusion" \
  "$(jq -r '.jobs[]?.steps[]? | "  [\(.status)] \(.name)"' "$JSON" | sort)")"

now="$(date -u +%FT%TZ)"

if [[ ! -f "$STATE" ]] || ! diff -q <(printf '%s\n' "$snapshot") "$STATE" >/dev/null 2>&1; then
  {
    printf '=== %s ===\n' "$now"
    printf '%s\n' "$snapshot"
    printf '  actual: %s (created %s)\n' "$current" "$created"
  } >> "$LOG"
  # el "actual" cambia con cada transición de paso; registrarlo siempre en
  # una línea aparte para seguimiento rápido del progreso
  printf '%s status=%s paso="%s"\n' "$now" "$status" "$current" >> "$LOG"
fi
printf '%s\n' "$snapshot" > "$STATE"

# Resumen en stdout para invocaciones manuales (cron lo descarta).
printf 'run %s: %s (conclusion=%s)\n' "$RUN_ID" "$status" "$conclusion"
printf 'paso actual: %s\n' "$current"
printf 'últimas transiciones:\n'
tail -4 "$LOG" 2>/dev/null || true
