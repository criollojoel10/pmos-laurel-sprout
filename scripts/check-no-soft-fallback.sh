#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# check-no-soft-fallback.sh — Regression: forbid "soft" failure patterns in
# build/validation paths. Fail-closed contract:
#   1. A real nix/build failure MUST return a non-zero exit code.
#   2. No `|| true` on production nix commands.
#   3. No `continue-on-error: true` on build/validation steps.
#   4. No `set +e` in scripts.
#   5. No product artifact that keeps being uploaded on failure (diagnostic and
#      log artifacts ARE allowed to use `if: always()`).
# Exits 0 only if no violation is found.

set -Eeuo pipefail

CRITICAL_FILES=(
  .github/workflows/06-build-nixos.yml
  .github/workflows/07-build-distros.yml
  .github/workflows/nixos-build-console.yml
  .github/workflows/nixos-eval.yml
  scripts/build-nixos-rootfs.sh
  scripts/export-nixos-closure.sh
)

fails=0

die() {
  printf '  FALLO %s\n' "$*" >&2
  fails=$((fails + 1))
}

for f in "${CRITICAL_FILES[@]}"; do
  [[ -f "$f" ]] || { echo "SKIP (no existe): $f"; continue; }
  echo "Auditando: $f"

  # 1. continue-on-error: true
  if grep -nE 'continue-on-error:[[:space:]]*true' "$f" >/dev/null 2>&1; then
    die "$f: continue-on-error: true"
  fi

  # 2. set +e
  if grep -nE '[[:space:]]set[[:space:]]+\+e' "$f" >/dev/null 2>&1; then
    die "$f: set +e"
  fi

  # 3. '|| true' sobre un comando nix de produccion (una linea)
  if grep -nE 'nix[[:space:]]+(build|flake|check|copy|store|eval|path)[^|\n]*\|\|[[:space:]]*(true|echo)' "$f" >/dev/null 2>&1; then
    die "$f: '|| true/echo' sobre comando nix"
  fi

  # 4. 'if ! nix build' aun presente
  if grep -nE 'if[[:space:]]+! nix[[:space:]]+build' "$f" >/dev/null 2>&1; then
    die "$f: if ! nix build (fallback blando)"
  fi

  # 5. upload-artifact de producto con if: always() (diagnosticos/logs OK)
  if awk -v RS='- name:' '
    {
      if ($0 ~ /upload-artifact/ && $0 ~ /if: always\(\)/) {
        if ($0 !~ /diagnostic/ && $0 !~ /log/) { bad = 1; print FNR ": upload producto con if: always()" }
      }
    }
    END { exit bad }
  ' "$f" >/dev/null; then
    :
  else
    die "$f: upload-artifact de producto con if: always()"
  fi
done

echo ""
if (( fails > 0 )); then
  echo "RESULT: FAIL ($fails violaciones soft-fallback)"
  exit 1
fi
echo "RESULT: PASS (sin patrones soft-fallback)"