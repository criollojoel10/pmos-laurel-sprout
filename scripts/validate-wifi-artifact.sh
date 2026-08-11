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

# 2) DTB: nodo wifi y propiedades
DTS="$OUT/laurel-wifi.dts"
dtc -I dtb -O dts -o "$DTS" "$DTB" 2>/dev/null
check_dtb() { # check_dtb <label> <regex>
  local label="$1" regex="$2"
  if grep -Eq "$regex" "$DTS"; then
    info "OK: DTB $label"
  else
    info "FALLO: DTB sin $label"
    fail="dtb"
  fi
}
check_dtb "nodo wifi@c800000" 'wifi@c800000 \{'
check_dtb "compatible qcom,wcn3990-wifi" 'compatible = "qcom,wcn3990-wifi"'
check_dtb "reg 0x0c800000/0x800000" 'reg = <0x0c800000 0x800000>'
check_dtb "memory-region wlan_msa_mem" 'memory-region = <&wlan_msa_mem>'
check_dtb "iommus apps_smmu 0x80 0x1" 'iommus = <&apps_smmu 0x80 0x1>'
check_dtb "qcom,msa-fixed-perm" 'qcom,msa-fixed-perm'
check_dtb "IRQ 358" 'GIC_SPI 358'
check_dtb "IRQ 369" 'GIC_SPI 369'
check_dtb "vreg_l8a" 'vdd-0.8-cx-mx-supply = <&vreg_l8a>'
check_dtb "vreg_l16a" 'vdd-1.8-xo-supply = <&vreg_l16a>'
check_dtb "vreg_l17a" 'vdd-1.3-rfa-supply = <&vreg_l17a>'
check_dtb "vreg_l23a" 'vdd-3.3-ch0-supply = <&vreg_l23a>'
check_dtb "framebuffer@5c000000" 'framebuffer@5c000000'

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
