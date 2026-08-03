#!/usr/bin/env bash
#
# process-device-logs.sh
#
# Analiza logs sanitizados del dispositivo (dmesg/journalctl) dentro del
# workflow 08-process-device-logs. Genera:
#   - hardware-test-report.md
#   - detected-regressions.json
#   - suggested-next-actions.md
#   - proposed-hardware-matrix.json
#
# Uso: scripts/process-device-logs.sh <dir-logs> [<dir-salida>]
# Licencia: GPL-3.0-or-later

set -Eeuo pipefail

LOGS="${1:?uso: $0 <dir-logs> [<dir-salida>]}"
OUT="${2:-reports/device-logs}"
[[ -d "$LOGS" ]] || { echo "ERROR: $LOGS no existe" >&2; exit 1; }
mkdir -p "$OUT"

info() { printf '[device-logs] %s\n' "$*" >&2; }

TODAY="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Recolectar texto de todos los logs
ALL="$(cat "$LOGS"/* 2>/dev/null || true)"
if [[ -z "$ALL" ]]; then
  info "sin logs en $LOGS"
  ALL="(sin contenido)"
fi

find_in_logs() {
  # $1 = label, $2 = regex
  local label="$1" regex="$2"
  if printf '%s' "$ALL" | grep -qiE "$regex"; then
    printf '%s' "$label"
  fi
}

DISPLAY=$(find_in_logs "display/DPU/DSI detectado" "msm_dpu|mdss|dsi|panel|s6e8fc0")
GPU=$(find_in_logs "GPU: MSM/Adreno presente" "msm_gpu|adreno|a610|renderD128")
GPU_FW=$(find_in_logs "GPU firmware carga" "adreno.*firmware|qcom_a610")
TOUCH=$(find_in_logs "táctil: focaltech" "ft3518|focaltech|fts")
WIFI=$(find_in_logs "wifi: controlador" "ath10k|wcn36xx|wlan|wifi")
BT=$(find_in_logs "bluetooth" "bluetooth|hci|qcom.*bt|btqcomsmd")
IOMMU=$(find_in_logs "IOMMU presente" "iommu|arm-smmu")
IOMMU_FAULT=$(find_in_logs "IOMMU fault (posible fallo)" "iommu.*fault|arm-smmu.*(abort|fault)")
UFS=$(find_in_logs "UFS" "ufshcd|ufs-qcom|ufs")
USB=$(find_in_logs "USB" "dwc3|musb|xhci|usb")
BAT=$(find_in_logs "batería" "battery|power_supply|fuelgauge")
THERMAL=$(find_in_logs "térmicas" "thermal|tsens")
CPUFREQ=$(find_in_logs "cpufreq" "cpufreq")
REMPROC=$(find_in_logs "remoteproc" "remoteproc|adsp|mpss")
FAILED_UNITS=$(find_in_logs "unidades systemd fallidas" "failed to start|Job .* failed|systemd.*failed")
PANIC=$(find_in_logs "panic/kernel oops" "Kernel panic|Oops:|BUG:")
SUSPEND=$(find_in_logs "suspensión" "PM: suspend|suspend")

cat > "$OUT/hardware-test-report.md" <<EOF
# Informe de prueba de hardware — laurel_sprout

Generado: $TODAY
Logs analizados: $(find "$LOGS" -maxdepth 1 -type f | sort | tr '\n' ' ')

| Componente | Detección en logs |
|---|---|
| Pantalla | ${DISPLAY:-no detectado} |
| GPU | ${GPU:-no detectado} ${GPU_FW:+(firmware: $GPU_FW)} |
| Táctil | ${TOUCH:-no detectado} |
| Wi-Fi | ${WIFI:-no detectado} |
| Bluetooth | ${BT:-no detectado} |
| IOMMU | ${IOMMU:-no detectado} ${IOMMU_FAULT:+⚠ $IOMMU_FAULT} |
| UFS | ${UFS:-no detectado} |
| USB | ${USB:-no detectado} |
| Batería | ${BAT:-no detectado} |
| Térmicas | ${THERMAL:-no detectado} |
| CPUfreq | ${CPUFREQ:-no detectado} |
| Remoteproc | ${REMPROC:-no detectado} |
| Suspensión | ${SUSPEND:-no detectado} |
| Fallos | ${PANIC:+⚠ $PANIC} ${FAILED_UNITS:+⚠ $FAILED_UNITS} |
EOF

# Regresiones detectadas
jq -n \
  --arg panic "$PANIC" \
  --arg iommu_fault "$IOMMU_FAULT" \
  --arg failed "$FAILED_UNITS" \
  '{generated_at:"'"$TODAY"'", detected:{panic:($panic != ""), iommu_fault:($iommu_fault != ""), systemd_failed:($failed != "")}, notes:{panic:($panic // ""), iommu_fault:($iommu_fault // ""), systemd_failed:($failed // "")}}' \
  > "$OUT/detected-regressions.json"

cat > "$OUT/suggested-next-actions.md" <<EOF
# Próximas acciones sugeridas

Generado: $TODAY

- [ ] Revisar $OUT/hardware-test-report.md.
- [ ] Si hay IOMMU fault: capturar 'dmesg' completo y subir como artifact.
- [ ] Si el panel no se enlaza: verificar DTS/panel compatible en sm61x5.
- [ ] Si falta firmware Adreno/WLAN/BT: comprobar 'firmware-manifest.json'.
- [ ] Actualizar 'reports/hardware-matrix.json' con estados honestos.
EOF

# Matriz propuesta (solo propuesta; no modifica main)
jq -n \
  --arg display "$DISPLAY" \
  --arg gpu "$GPU" \
  --arg touch "$TOUCH" \
  --arg wifi "$WIFI" \
  --arg bt "$BT" \
  --arg ufs "$UFS" \
  --arg usb "$USB" \
  --arg bat "$BAT" \
  --arg thermal "$THERMAL" \
  --arg cpufreq "$CPUFREQ" \
  '{generated_at:"'"$TODAY"'", proposed:{display:($display != ""), gpu:($gpu != ""), touchscreen:($touch != ""), wifi:($wifi != ""), bluetooth:($bt != ""), ufs:($ufs != ""), usb:($usb != ""), battery:($bat != ""), thermal:($thermal != ""), cpufreq:($cpufreq != "")}}' \
  > "$OUT/proposed-hardware-matrix.json"

info "informes generados en $OUT/"
ls -la "$OUT/"
exit 0
