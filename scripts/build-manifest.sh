#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# build-manifest.sh
#
# Generates a unified build manifest across all distro artifacts.
#
# Usage:
#   scripts/build-manifest.sh --out <manifest.json>

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT=""
ARTIFACTS_DIR=""

usage() {
  echo "usage: $0 --out <manifest.json> [--artifacts <dir>]" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --artifacts) ARTIFACTS_DIR="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$OUT" ]] || usage

# Kernel info from kernel artifact
KERNEL_COMMIT="unknown"
KERNEL_VERSION="unknown"
DTB_NAME="sm6125-xiaomi-laurel-sprout.dtb"

if [[ -n "$ARTIFACTS_DIR" && -f "$ARTIFACTS_DIR/manifest.json" ]]; then
  KERNEL_COMMIT=$(jq -r '.kernel_commit // "unknown"' "$ARTIFACTS_DIR/manifest.json" 2>/dev/null || echo "unknown")
  KERNEL_VERSION=$(jq -r '.kernel_version // "unknown"' "$ARTIFACTS_DIR/manifest.json" 2>/dev/null || echo "unknown")
fi

# Git info
GIT_COMMIT=$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
GIT_TAG=$(git -C "$REPO_ROOT" describe --tags --always 2>/dev/null || echo "unknown")

# Timestamp
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Distro artifacts
DISTROS=()

if [[ -n "$ARTIFACTS_DIR" ]]; then
  # postmarketOS
  for ui in console phosh plasma; do
    artifact=$(find "$ARTIFACTS_DIR" -name "*pmos*${ui}*" -type f 2>/dev/null | head -1)
    if [[ -n "$artifact" ]]; then
      sha=$(sha256sum "$artifact" | cut -d' ' -f1)
      size=$(stat -c%s "$artifact" 2>/dev/null || echo "0")
      DISTROS+=("{\"distro\":\"postmarketos\",\"variant\":\"${ui}\",\"sha256\":\"${sha}\",\"size\":${size},\"file\":\"$(basename "$artifact")\"}")
    fi
  done

  # Arch Linux ARM
  for variant in console phosh; do
    artifact=$(find "$ARTIFACTS_DIR" -name "*archlinux*${variant}*" -type f 2>/dev/null | head -1)
    if [[ -n "$artifact" ]]; then
      sha=$(sha256sum "$artifact" | cut -d' ' -f1)
      size=$(stat -c%s "$artifact" 2>/dev/null || echo "0")
      DISTROS+=("{\"distro\":\"archlinux\",\"variant\":\"${variant}\",\"sha256\":\"${sha}\",\"size\":${size},\"file\":\"$(basename "$artifact")\"}")
    fi
  done

  # NixOS
  for variant in console phosh; do
    artifact=$(find "$ARTIFACTS_DIR" -name "*nixos*${variant}*" -type f 2>/dev/null | head -1)
    if [[ -n "$artifact" ]]; then
      sha=$(sha256sum "$artifact" | cut -d' ' -f1)
      size=$(stat -c%s "$artifact" 2>/dev/null || echo "0")
      DISTROS+=("{\"distro\":\"nixos\",\"variant\":\"${variant}\",\"sha256\":\"${sha}\",\"size\":${size},\"file\":\"$(basename "$artifact")\"}")
    fi
  done
fi

# Build JSON
DISTROS_JSON="[]"
if [[ ${#DISTROS[@]} -gt 0 ]]; then
  DISTROS_JSON=$(printf '%s\n' "${DISTROS[@]}" | jq -s '.')
fi

jq -n \
  --arg git_commit "$GIT_COMMIT" \
  --arg git_branch "$GIT_BRANCH" \
  --arg git_tag "$GIT_TAG" \
  --arg kernel_commit "$KERNEL_COMMIT" \
  --arg kernel_version "$KERNEL_VERSION" \
  --arg dtb "$DTB_NAME" \
  --arg generated_at "$TIMESTAMP" \
  --argjson distros "$DISTROS_JSON" \
  '{
    git: { commit: $git_commit, branch: $git_branch, tag: $git_tag },
    kernel: { commit: $kernel_commit, version: $kernel_version, dtb: $dtb },
    generated_at: $generated_at,
    distros: $distros
  }' > "$OUT"

cat "$OUT"
