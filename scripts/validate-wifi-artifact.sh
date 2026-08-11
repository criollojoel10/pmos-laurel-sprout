#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# validate-wifi-artifact.sh
#
# Valida estáticamente un artefacto kernel-debug (03) para la ruta WCN3990/SNOC:
#   - símbolos Kconfig esperados para ath10k_snoc/QMI/QRTR/SMEM/SCM;
#   - DTB con nodo wifi@c800000 qcom,wcn3990-wifi y sus propiedades.
#
# Uso:
#   scripts/validate-wifi-artifact.sh \
#     --config <kernel.config> --dtb <sm6125-xiaomi-laurel-sprout.dtb> [--out <dir>]

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CFG=""
DTB=""
OUT="."

while (( $# > 0 )); do
  case "$1" in
    --config) CFG="$2"; shift 2 ;;
    --dtb) DTB="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) echo "uso: $0 --config <c> --dtb <d> [--out <dir>]" >&2; exit 2 ;;
  esac
done
[[ -n "$CFG" && -n "$DTB" ]] || { echo "uso: $0 --config <c> --dtb <d> [--out <dir>]" >&2; exit 2; }
[[ -f "$CFG" ]] || { echo "ERROR: config no existe: $CFG" >&2; exit 1; }
[[ -f "$DTB" ]] || { echo "ERROR: dtb no existe: $DTB" >&2; exit 1; }
command -v dtc >/dev/null || { echo "ERROR: falta dtc" >&2; exit 1; }
mkdir -p "$OUT"

fail=""
info() { printf '[wifi-audit] %s\n' "$*"; }

# 1) Kconfig
for sym in "CONFIG_ATH10K=y" "CONFIG_ATH10K_SNOC=y" "CONFIG_QCOM_SMEM=y" \
           "CONFIG_QCOM_QMI_HELPERS=y" "CONFIG_QCOM_SCM=y" \
           "CONFIG_POWER_SEQUENCING=y" "CONFIG_QRTR=y"; do
  if grep -qx "$sym" "$CFG"; then
    info "OK: $sym"
  else
    info "FALLO: $sym no presente en kernel.config"
    fail="kconfig"
  fi
done

# 2) DTB: nodo wifi y propiedades (validación con resolución de phandles)
DTS="$OUT/laurel-wifi.dts"
dtc -I dtb -O dts -o "$DTS" "$DTB" 2>/dev/null
if ! python3 "$REPO_ROOT/scripts/validate-wifi-dtb.py" --dts "$DTS"; then
  fail="dtb"
fi

cat > "$OUT/wifi-validation.md" <<EOF
# Validación artefacto kernel (WCN3990/SNOC)

- kernel.config: ATH10K=y, ATH10K_SNOC=y, QCOM_SMEM=y, QCOM_QMI_HELPERS=y,
  QCOM_SCM=y, POWER_SEQUENCING=y, QRTR=y
- DTB: wifi@c800000 qcom,wcn3990-wifi con MSA, IOMMU SID 0x80, msa-fixed-perm,
  IRQ 358-369, supplies l8a/l16a/l17a/l23a, status okay
- framebuffer@5c000000 conservado
EOF
cat "$OUT/wifi-validation.md"
[[ -z "$fail" ]] || { echo "ERROR: validación WCN3990 falló ($fail)" >&2; exit 1; }
info "WCN3990: validación estática OK"
