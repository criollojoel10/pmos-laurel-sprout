#!/usr/bin/env bash
# Licencia: GPL-3.0-or-later

set -Eeuo pipefail
DTB=""; CFG=""; OUT="."
while (( $# > 0 )); do
  case "$1" in
    --dtb) DTB="$2"; shift 2 ;;
    --config) CFG="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) echo "uso: $0 --dtb <dtb> --config <config> --out <dir>" >&2; exit 2 ;;
  esac
done
[[ -f "$DTB" && -f "$CFG" ]] || exit 2
mkdir -p "$OUT"
fail=0
ok() { printf '[usb-dtb] OK: %s\n' "$1"; }
bad() { printf '[usb-dtb] FALLO: %s\n' "$1"; fail=1; }
has_prop() { fdtget -p "$DTB" "$1" 2>/dev/null | grep -qx "$2"; }
has_value() { fdtget -t s "$DTB" "$1" "$2" 2>/dev/null | grep -Fq "$3"; }
check() {
  local label="$1"; shift
  if "$@"; then ok "$label"; else bad "$label"; fi
}

for sym in CONFIG_EXTCON=y CONFIG_EXTCON_USB_GPIO=y CONFIG_USB_DWC3=y \
  CONFIG_USB_DWC3_QCOM=y CONFIG_PHY_QCOM_QUSB2=y CONFIG_USB_GADGET=y \
  CONFIG_USB_LIBCOMPOSITE=y CONFIG_USB_CONFIGFS=y CONFIG_USB_CONFIGFS_RNDIS=y \
  CONFIG_FB_SIMPLE=y CONFIG_FRAMEBUFFER_CONSOLE=y CONFIG_VT_CONSOLE=y \
  CONFIG_PSTORE_RAM=y; do
  check "$sym" grep -qx "$sym" "$CFG"
done

PHY=/soc@0/phy@1613000
WRAP=/soc@0/usb@4ef8800
CORE=/soc@0/usb@4ef8800/usb@4e00000
EXT=/usb-id
for node in "$PHY" "$WRAP" "$CORE" "$EXT"; do
  check "nodo $node" fdtget -p "$DTB" "$node"
done
check 'QUSB2 compatible' has_value "$PHY" compatible 'qcom,msm8996-qusb2-phy'
check 'wrapper qcom,sm6125-dwc3' has_value "$WRAP" compatible 'qcom,sm6125-dwc3'
check 'core snps,dwc3' has_value "$CORE" compatible 'snps,dwc3'
check 'dr_mode peripheral' has_value "$CORE" dr_mode peripheral
check 'maximum-speed high-speed' has_value "$CORE" maximum-speed high-speed
check 'core extcon phandle' has_prop "$CORE" extcon
check 'core usb2-phy' has_value "$CORE" phy-names usb2-phy
if has_prop "$PHY" vdd-supply && has_prop "$PHY" vdda-pll-supply && \
   has_prop "$PHY" vdda-phy-dpdm-supply; then
  ok 'QUSB2 supplies'
else
  bad 'QUSB2 supplies'
fi
check 'extcon-usb-gpio' has_value "$EXT" compatible 'linux,extcon-usb-gpio'
check 'extcon id-gpios' has_prop "$EXT" id-gpios
RAM=/reserved-memory/ramoops@ffc00000
check 'ramoops compatible' has_value "$RAM" compatible ramoops
for prop in reg record-size console-size pmsg-size; do
  check "ramoops $prop" has_prop "$RAM" "$prop"
done
FB=/chosen/framebuffer@5c000000
if has_prop "$FB" reg && has_prop "$FB" width && has_prop "$FB" height && \
   has_prop "$FB" stride && has_prop "$FB" format; then
  ok 'simple framebuffer properties'
else
  bad 'simple framebuffer properties'
fi

cat > "$OUT/usb-dtb-audit.md" <<EOF
# Auditoría USB/display DTB v7.1

- PHY: qcom,msm8996-qusb2-phy en $PHY, supplies presentes.
- Wrapper: qcom,sm6125-dwc3 en $WRAP.
- Core: snps,dwc3 en $CORE, dr_mode=peripheral, high-speed, extcon y USB2 PHY.
- Extcon: linux,extcon-usb-gpio con id-gpios.
- Ramoops: $RAM con parámetros requeridos.
- Simplefb: $FB con propiedades de formato/tamaño.
EOF
cat "$OUT/usb-dtb-audit.md"
(( fail == 0 )) || exit 1
