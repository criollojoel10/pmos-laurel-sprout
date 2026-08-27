#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# validate-local.sh — Local validation for pmos-laurel-sprout
# Run without network, sudo, mounts, or hardware.
# Exits non-zero on any CRITICAL failure.

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0
SKIP=0

ok()   { PASS=$((PASS+1)); printf '  PASS  %s\n' "$*"; }
fail() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$*"; }
skip() { SKIP=$((SKIP+1)); printf '  SKIP  %s\n' "$*"; }

echo "=== Local Validation ==="
echo "Branch: $(git branch --show-current 2>/dev/null || echo 'detached')"
echo "HEAD:   $(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
echo ""

# ── 1. Git diff --check ──
echo "--- 1. git diff --check ---"
if git diff --check HEAD >/dev/null 2>&1; then
  ok "no whitespace errors"
else
  fail "whitespace errors detected"
  git diff --check HEAD 2>&1 | head -10
fi

# ── 2. JSON validation ──
echo "--- 2. JSON validation ---"
if jq empty sources.lock.json 2>/dev/null; then
  ok "sources.lock.json valid"
else
  fail "sources.lock.json invalid"
fi
if [[ -f reports/hardware-matrix.json ]]; then
  if jq empty reports/hardware-matrix.json 2>/dev/null; then
    ok "hardware-matrix.json valid"
  else
    fail "hardware-matrix.json invalid"
  fi
fi

# ── 3. Shell syntax ──
echo "--- 3. Shell syntax (bash -n) ---"
for f in scripts/*.sh; do
  [[ -f "$f" ]] || continue
  if bash -n "$f" 2>/dev/null; then
    ok "syntax: $(basename "$f")"
  else
    fail "syntax: $(basename "$f")"
  fi
done

# ── 4. ShellCheck ──
echo "--- 4. ShellCheck ---"
if command -v shellcheck >/dev/null 2>&1; then
  SCFAIL=0
  for f in scripts/*.sh; do
    [[ -f "$f" ]] || continue
    if shellcheck --external-sources "$f" 2>/dev/null; then
      ok "shellcheck: $(basename "$f")"
    else
      fail "shellcheck: $(basename "$f")"
      SCFAIL=$((SCFAIL+1))
    fi
  done
else
  skip "shellcheck not installed"
fi

# ── 5. YAML validation ──
echo "--- 5. YAML validation ---"
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "
import yaml, os, sys
ok = 0; fail = 0
for f in sorted(os.listdir('.github/workflows')):
    if not f.endswith(('.yml','.yaml')): continue
    try:
        with open(os.path.join('.github/workflows', f)) as fh:
            yaml.safe_load(fh)
        ok += 1
    except Exception as e:
        print(f'FAIL {f}: {e}', file=sys.stderr)
        fail += 1
print(f'YAML: {ok} OK, {fail} FAIL')
sys.exit(1 if fail else 0)
" 2>&1; then
  ok "all workflows valid YAML"
else
  fail "YAML validation errors"
fi
else
  skip "python3 not installed"
fi

# ── 6. Actionlint ──
echo "--- 6. Actionlint ---"
if command -v actionlint >/dev/null 2>&1; then
  if actionlint 2>/dev/null; then
    ok "actionlint passed"
  else
    fail "actionlint errors"
  fi
else
  skip "actionlint not installed"
fi

# ── 7. Nix flake check ──
echo "--- 7. Nix flake check ---"
if command -v nix >/dev/null 2>&1; then
  if nix flake check ./nixos --no-build 2>/dev/null; then
    ok "nix flake check"
  else
    fail "nix flake check failed"
  fi
else
  skip "nix not installed"
fi

# ── 8. Referenced files exist ──
echo "--- 8. Referenced files ---"
for wf in .github/workflows/*.yml; do
  grep 'scripts/' "$wf" 2>/dev/null | grep -oE 'scripts/[a-zA-Z0-9._-]+\.(sh|py)' | sort -u | while read -r script; do
    sfile="${script#scripts/}"
    if [[ ! -f "scripts/$sfile" ]]; then
      fail "workflow $(basename "$wf") references missing $script"
    fi
  done
  grep 'configs/' "$wf" 2>/dev/null | grep -oE 'configs/[a-zA-Z0-9._/-]+\.txt' | sort -u | while read -r cfg; do
    if [[ ! -f "$cfg" ]]; then
      fail "workflow $(basename "$wf") references missing $cfg"
    fi
  done
done
ok "referenced files check completed"

# ── 9. Dangerous patterns ──
echo "--- 9. Security patterns ---"
DANGEROUS=$(grep -RInE 'curl.*\|.*(sh|bash)|eval [^(]|set -x' scripts .github nixos configs 2>/dev/null | grep -v 'test-opencode-security' | grep -v '.gitignore' || true)
if [[ -z "$DANGEROUS" ]]; then
  ok "no dangerous patterns"
else
  fail "dangerous patterns found:"
  echo "$DANGEROUS" | head -5
fi

# ── 10. Secrets check ──
echo "--- 10. Secrets check ---"
LEAK_CHECK=$(grep -RInE 'ghp_[a-zA-Z0-9]{36}|gho_[a-zA-Z0-9]{36}|password\s*=\s*"[^"]+"|api_key\s*=\s*"[^"]+"' scripts .github nixos configs 2>/dev/null || true)
if [[ -z "$LEAK_CHECK" ]]; then
  ok "no secrets found"
else
  fail "potential leaks found:"
  echo "$LEAK_CHECK" | head -5
fi

# ── 11. Matrix completeness ──
echo "--- 11. Matrix completeness ---"
for wf in 04-build-pmos-console.yml 04-build-pmos-phosh.yml 05-build-pmos-plasma.yml 05-build-archlinux.yml 06-build-nixos.yml; do
  if [[ -f ".github/workflows/$wf" ]]; then
    if grep -q 'workflow_call' ".github/workflows/$wf"; then
      ok "workflow_call: $wf"
    else
      fail "workflow_call missing: $wf"
    fi
  else
    fail "workflow missing: $wf"
  fi
done

# ── Summary ──
echo ""
echo "=== Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo "SKIP: $SKIP"
if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "RESULT: FAIL ($FAIL critical issues)"
  exit 1
else
  echo ""
  echo "RESULT: PASS"
  exit 0
fi
