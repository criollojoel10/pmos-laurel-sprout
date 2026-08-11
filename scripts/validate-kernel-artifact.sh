#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# validate-kernel-artifact.sh
# Valida un artefacto kernel-debug de una run CI completada.

set -Eeuo pipefail

RUN_ID=""
OUT=""
usage() {
  echo "uso: $0 --run-id <id> --out <dir>" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --run-id) RUN_ID="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) usage ;;
  esac
done
[[ -n "$RUN_ID" && -n "$OUT" ]] || usage
command -v gh >/dev/null || { echo "ERROR: falta gh" >&2; exit 1; }
command -v dtc >/dev/null || { echo "ERROR: falta dtc" >&2; exit 1; }

mkdir -p "$OUT"
OUT="$(readlink -f "$OUT")"
ART="$OUT/kernel-debug"
STATUS_JSON="$(gh run view "$RUN_ID" --json status,conclusion)"
[[ "$(jq -r .status <<<"$STATUS_JSON")" == completed ]] || {
  echo "ERROR: la run $RUN_ID no terminó" >&2; exit 1;
}
[[ "$(jq -r .conclusion <<<"$STATUS_JSON")" == success ]] || {
  echo "ERROR: la run $RUN_ID no terminó success: $(jq -r .conclusion <<<"$STATUS_JSON")" >&2
  exit 1
}

rm -rf "$ART"
gh run download "$RUN_ID" -n kernel-debug -D "$ART"
cd "$ART"
sha256sum -c SHA256SUMS

expect() {
  local line="$1"
  grep -Fx "$line" kernel.config >/dev/null || {
    echo "ERROR: kernel.config no contiene: $line" >&2; exit 1;
  }
}
expect CONFIG_FB=y
expect CONFIG_FB_SIMPLE=y
expect CONFIG_DRM_MSM=m
expect CONFIG_FRAMEBUFFER_CONSOLE=y
expect CONFIG_VT=y
expect CONFIG_USB_ETH=y
expect CONFIG_USB_ETH_RNDIS=y
if grep -Eq '^CONFIG_DRM_SIMPLEDRM=' kernel.config; then
  echo "ERROR: DRM_SIMPLEDRM no debe competir con FB_SIMPLE" >&2
  exit 1
fi
grep -Eq '(^|/)msm\.ko$' modules-manifest.txt || {
  echo "ERROR: modules-manifest.txt no contiene msm.ko" >&2; exit 1;
}

mkdir -p "$OUT/dtb"
dtc -I dtb -O dts -o "$OUT/dtb/laurel.dts" sm6125-xiaomi-laurel-sprout.dtb
grep -q 'framebuffer@5c000000' "$OUT/dtb/laurel.dts"
grep -Eq 'width = <(0x2d0|720)>;' "$OUT/dtb/laurel.dts"
grep -Eq 'height = <(0x618|1560)>;' "$OUT/dtb/laurel.dts"
grep -Eq 'stride = <(0xb40|2880)>;' "$OUT/dtb/laurel.dts"
grep -q 'format = "a8r8g8b8"' "$OUT/dtb/laurel.dts"
grep -q 'memory@5c000000' "$OUT/dtb/laurel.dts"

cat > "$OUT/kernel-validation.md" <<EOF
# Validación artefacto kernel-debug

- run: $RUN_ID
- conclusión: success
- SHA256SUMS: OK
- Kconfig: FB_SIMPLE=y, DRM_MSM=m, FRAMEBUFFER_CONSOLE=y, VT=y, USB_ETH_RNDIS=y
- módulo msm.ko: presente
- DTB: framebuffer@5c000000 720x1560 stride 2880 a8r8g8b8 y memoria reservada presentes
EOF
cat "$OUT/kernel-validation.md"
