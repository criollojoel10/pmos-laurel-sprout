#!/usr/bin/env bash
#
# verify-dtb.sh
#
# Descompila un DTB (o extrae del árbol fuente) y verifica los nodos
# esenciales del Xiaomi Mi A3 laurel_sprout.
#
# Uso:
#   scripts/verify-dtb.sh --dtb <archivo.dtb> [--dts <archivo.dts>] --out <dir>
#
# Verifica:
#   - modelo Xiaomi Mi A3
#   - compatible del dispositivo
#   - MDSS / DSI / panel (compatible samsung,s6e8fc0-m1906f9)
#   - reset GPIO y supplies del panel
#   - táctil FT3518 e I2C
#   - UFS, USB, GPU, IOMMU, reserved-memory, remoteproc
#
# Genera un informe Markdown. No declara GPU funcional por existir nodo GPU.
# Licencia: GPL-3.0-or-later

set -Eeuo pipefail

DTB=""
DTS=""
OUT=""

usage() {
  echo "uso: $0 --dtb <archivo.dtb> [--dts <archivo.dts>] --out <dir>" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --dtb) DTB="$2"; shift 2 ;;
    --dts) DTS="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$OUT" ]] || usage
[[ -n "$DTB" || -n "$DTS" ]] || usage

info() { printf '[dtb] %s\n' "$*" >&2; }
mkdir -p "$OUT"

command -v dtc >/dev/null 2>&1 || { echo "ERROR: dtc no instalado" >&2; exit 1; }

DECOMPILED="$OUT/sm6125-laurel.dts"
if [[ -n "$DTS" && -f "$DTS" ]]; then
  cp "$DTS" "$DECOMPILED"
  info "usando DTS fuente: $DTS"
elif [[ -f "$DTB" ]]; then
  dtc -I dtb -O dts "$DTB" -o "$DECOMPILED" 2>/dev/null
  info "descompilado: $DTB -> $DECOMPILED"
else
  echo "ERROR: ni DTB ni DTS válidos" >&2
  exit 1
fi

has() { grep -qE "$1" "$DECOMPILED"; }
report() { printf '| %s | %s |\n' "$1" "$2"; }

REPORT="$OUT/dtb-report.md"
{
  echo "# Informe de verificación DTB — sm6125-xiaomi-laurel-sprout"
  echo ""
  echo "Generado: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo ""
  echo "| Comprobación | Resultado |"
  echo "|---|---|"
} > "$REPORT"

check() {
  local label="$1" pattern="$2"
  if has "$pattern"; then
    report "$label" "OK"
    echo "[OK] $label"
  else
    report "$label" "FALTA"
    echo "[FALTA] $label"
  fi
}

{
  check "Modelo Xiaomi Mi A3" "model = \"Xiaomi Mi A3\""
  check "compatible dispositivo (trinket)" "compatible = \"xiaomi,laurel-sprout\"|compatible = \"xiaomi,laurel\"|trinket"
  check "Nodo MDSS" "mdss"
  check "Nodo DSI" "dsi@"
  check "Panel compatible s6e8fc0-m1906f9" "samsung,s6e8fc0-m1906f9"
  check "Reset GPIO del panel" "reset-gpios"
  check "Supplies del panel" "vddi-supply|vdda-supply|vci-supply"
  check "Táctil FT3518" "focaltech,ft3518|focaltech,fts|focaltech"
  check "Nodo I2C" "i2c"
  check "Nodo UFS" "ufs"
  check "Nodo USB / DWC3" "dwc3|usb@"
  check "Nodo GPU" "gpu@"
  check "IOMMU / SMMU" "smmu|iommu"
  check "reserved-memory" "reserved-memory"
  check "Remoteproc" "remoteproc|adsp|mpss"
  check "Reguladores" "regulator"
  check "Pinctrl" "pinctrl"
  check "Batería/power-supply" "power-supply|battery"
  check "Thermal/tsens" "tsens|thermal"
  check "CPUfreq" "cpufreq|cpu_opp_table"
} >> "$REPORT"

{
  echo ""
  echo "## Notas"
  echo ""
  echo "- La existencia del nodo GPU **no** implica GPU funcional."
  echo "- La existencia del nodo panel **no** implica pantalla funcional."
  echo "- Ver `docs/HARDWARE-STATUS.md` para los criterios de `working`."
} >> "$REPORT"

info "informe generado: $REPORT"
