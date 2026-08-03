#!/usr/bin/env bash
#
# research-upstream.sh
#
# Ejecuta la auditoría upstream dentro de GitHub Actions (01-research-upstream).
# Descarga de forma temporal y liviana (shallow, profundidad acotada):
#   - pmbootstrap
#   - pmaports (busca el port archivado xiaomi-laurel)
#   - sm61x5-mainline/linux (DTS laurel_sprout, panel, touchscreen, GPU)
#   - LineageOS SM6125 (referencia DT Android)
# Genera en reports/:
#   - source-audit.md
#   - source-candidates.json
#   - patch-audit.md
#   - hardware-matrix.json
#
# No sube fuentes, no construye kernel, no modifica el repositorio.
# Uso: scripts/research-upstream.sh [--tmp DIR] [--out DIR]
# Licencia: GPL-3.0-or-later

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

TMP_DIR="${1:-/tmp/research-upstream}"
OUT_DIR="${2:-reports}"

info() { printf '[research] %s\n' "$*" >&2; }

command -v git >/dev/null 2>&1 || { echo "ERROR: git requerido" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq requerido" >&2; exit 1; }

mkdir -p "$TMP_DIR" "$OUT_DIR"

# Git minimal: shallow, single branch, depth acotado.
fetch_shallow() {
  # $1 = url; $2 = dir; $3 = ref
  local url="$1" dir="$2" ref="$3"
  if [[ -d "$dir/.git" ]]; then
    info "reutilizando $dir"
    return 0
  fi
  git clone --depth 20 --single-branch --branch "$ref" "$url" "$dir" 2>&1 | sed 's/^/[git] /' >&2 || return 1
}

TODAY="$(date -u +%Y-%m-%d)"

# ---- 1. pmbootstrap ---------------------------------------------------------
info "descargando pmbootstrap (shallow)..."
PMB="$TMP_DIR/pmbootstrap"
if fetch_shallow "https://gitlab.com/postmarketOS/pmbootstrap.git" "$PMB" "master"; then
  PMB_COMMIT="$(git -C "$PMB" rev-parse HEAD)"
  PMB_DATE="$(git -C "$PMB" log -1 --format=%cI 2>/dev/null || echo "unknown")"
  info "pmbootstrap: $PMB_COMMIT ($PMB_DATE)"
else
  info "AVISO: no se pudo descargar pmbootstrap"
  PMB_COMMIT="unavailable"
  PMB_DATE=""
fi

# ---- 2. pmaports -----------------------------------------------------------
info "descargando pmaports (shallow)..."
PM="$TMP_DIR/pmaports"
if fetch_shallow "https://gitlab.com/postmarketOS/pmaports.git" "$PM" "master"; then
  PM_COMMIT="$(git -C "$PM" rev-parse HEAD)"
  PM_DATE="$(git -C "$PM" log -1 --format=%cI 2>/dev/null || echo "unknown")"
  info "pmaports: $PM_COMMIT ($PM_DATE)"

  # Localizar el port archivado xiaomi-laurel
  LAUREL_DIR=""
  for d in "$PM"/device/testing/device-xiaomi-laurel "$PM"/device/community/device-xiaomi-laurel "$PM"/device/main/device-xiaomi-laurel; do
    [[ -d "$d" ]] && LAUREL_DIR="$d"
  done
  if [[ -z "$LAUREL_DIR" ]]; then
    LAUREL_DIR="$(find "$PM/device" -maxdepth 3 -type d -name 'device-xiaomi-laurel' 2>/dev/null | head -n1 || true)"
  fi
  LAUREL_FOUND="no"
  LAUREL_NOTE=""
  if [[ -n "$LAUREL_DIR" ]]; then
    LAUREL_FOUND="yes"
    LAUREL_NOTE="port archivado localizado en $LAUREL_DIR"
    info "$LAUREL_NOTE"
  else
    info "port archivado xiaomi-laurel NO encontrado en la rama master actual (puede estar archivado/eliminado)"
    LAUREL_NOTE="no localizado en master actual; buscar en historial git de pmaports"
  fi

  # Buscar en historial (git log --all) el último commit del port
  LAST_LAUREL_COMMIT="$(git -C "$PM" log --all --oneline --diff-filter=A -- '*/device-xiaomi-laurel/*' 2>/dev/null | head -n5 || true)"

  # APKBUILD y deviceinfo históricos
  KERNEL_APKBUILD="$(find "$PM" -path '*linux-xiaomi-laurel/APKBUILD' 2>/dev/null | head -n1 || true)"
  DEVICEINFO="$(find "$PM" -path '*device-xiaomi-laurel/deviceinfo' 2>/dev/null | head -n1 || true)"
  FW_DIR="$(find "$PM" -maxdepth 5 -type d -name 'firmware-xiaomi-laurel' 2>/dev/null | head -n1 || true)"
else
  info "AVISO: no se pudo descargar pmaports"
  PM_COMMIT="unavailable"
  PM_DATE=""
  LAUREL_FOUND="no"
  LAUREL_NOTE="pmaports no disponible"
  LAST_LAUREL_COMMIT=""
  KERNEL_APKBUILD=""
  DEVICEINFO=""
  FW_DIR=""
fi

# ---- 3. sm61x5-mainline ----------------------------------------------------
info "descargando sm61x5-mainline/linux (shallow)..."
SM="$TMP_DIR/sm61x5"
if fetch_shallow "https://codeberg.org/sm61x5-mainline/linux.git" "$SM" "sm61x5-mainline"; then
  SM_COMMIT="$(git -C "$SM" rev-parse HEAD)"
  SM_DATE="$(git -C "$SM" log -1 --format=%cI 2>/dev/null || echo "unknown")"
  info "sm61x5-mainline: $SM_COMMIT ($SM_DATE)"

  DTS_LAUREL="$(find "$SM/arch/arm64/boot/dts/qcom" -name 'sm6125*laurel*' 2>/dev/null | head -n1 || true)"
  PANEL_DTS="$(find "$SM/arch/arm64/boot/dts/qcom" -name '*s6e8fc0*' 2>/dev/null | head -n1 || true)"
  FT_DTS="$(find "$SM/arch/arm64/boot/dts/qcom" -iname '*focaltech*' 2>/dev/null | head -n1 || true)"
  PANEL_DRIVER="$(find "$SM/drivers/gpu/drm/panel" -name '*s6e8fc0*' 2>/dev/null | head -n1 || true)"
  FT_DRIVER="$(find "$SM/drivers/input/touchscreen" -iname '*focaltech*' 2>/dev/null | head -n1 || true)"
else
  info "AVISO: no se pudo descargar sm61x5-mainline"
  SM_COMMIT="unavailable"
  SM_DATE=""
  DTS_LAUREL=""
  PANEL_DTS=""
  FT_DTS=""
  PANEL_DRIVER=""
  FT_DRIVER=""
fi

# ---- 4. LineageOS SM6125 (referencia) --------------------------------------
info "descargando LineageOS SM6125 (shallow, referencia)..."
LO="$TMP_DIR/lineage-sm6125"
if fetch_shallow "https://github.com/LineageOS/android_kernel_xiaomi_sm6125.git" "$LO" "lineage-21"; then
  LO_COMMIT="$(git -C "$LO" rev-parse HEAD)"
  LO_DATE="$(git -C "$LO" log -1 --format=%cI 2>/dev/null || echo "unknown")"
  LO_LAUREL_DTS="$(find "$LO/arch/arm64/boot/dts" -iname '*laurel*' 2>/dev/null | head -n1 || true)"
  info "lineage-sm6125: $LO_COMMIT ($LO_DATE)"
else
  info "AVISO: no se pudo descargar LineageOS SM6125 (rama puede diferir)"
  LO_COMMIT="unavailable"
  LO_DATE=""
  LO_LAUREL_DTS=""
fi

# ---- 5. Generar informes ----------------------------------------------------
info "generando source-candidates.json..."
cat > "$OUT_DIR/source-candidates.json" <<EOF
{
  "generated_at": "$TODAY",
  "sources": [
    {
      "name": "pmbootstrap",
      "url": "https://gitlab.com/postmarketOS/pmbootstrap.git",
      "commit": $(jq -n --arg v "$PMB_COMMIT" '$v'),
      "commit_date": $(jq -n --arg v "$PMB_DATE" '$v'),
      "verified": "$PMB_COMMIT"
    },
    {
      "name": "pmaports",
      "url": "https://gitlab.com/postmarketOS/pmaports.git",
      "commit": $(jq -n --arg v "$PM_COMMIT" '$v'),
      "commit_date": $(jq -n --arg v "$PM_DATE" '$v'),
      "verified": "$PM_COMMIT",
      "archived_port": {
        "xiaomi_laurel_found": "$LAUREL_FOUND",
        "notes": $(jq -n --arg v "$LAUREL_NOTE" '$v'),
        "last_commits": $(jq -n --arg v "$LAST_LAUREL_COMMIT" '$v'),
        "kernel_apkbuild": $(jq -n --arg v "${KERNEL_APKBUILD:-}" '$v'),
        "deviceinfo": $(jq -n --arg v "${DEVICEINFO:-}" '$v'),
        "firmware_dir": $(jq -n --arg v "${FW_DIR:-}" '$v')
      }
    },
    {
      "name": "sm61x5-mainline",
      "url": "https://codeberg.org/sm61x5-mainline/linux.git",
      "branch": "sm61x5-mainline",
      "commit": $(jq -n --arg v "$SM_COMMIT" '$v'),
      "commit_date": $(jq -n --arg v "$SM_DATE" '$v'),
      "verified": "$SM_COMMIT",
      "files": {
        "dts_laurel": $(jq -n --arg v "${DTS_LAUREL:-}" '$v'),
        "panel_dts": $(jq -n --arg v "${PANEL_DTS:-}" '$v'),
        "focaltech_dts": $(jq -n --arg v "${FT_DTS:-}" '$v'),
        "panel_driver": $(jq -n --arg v "${PANEL_DRIVER:-}" '$v'),
        "focaltech_driver": $(jq -n --arg v "${FT_DRIVER:-}" '$v')
      }
    },
    {
      "name": "lineageos-sm6125",
      "url": "https://github.com/LineageOS/android_kernel_xiaomi_sm6125.git",
      "branch": "lineage-21",
      "commit": $(jq -n --arg v "$LO_COMMIT" '$v'),
      "commit_date": $(jq -n --arg v "$LO_DATE" '$v'),
      "verified": "$LO_COMMIT",
      "laurel_dts_android": $(jq -n --arg v "${LO_LAUREL_DTS:-}" '$v')
    }
  ]
}
EOF

info "generando source-audit.md..."
{
  echo "# Auditoría de fuentes"
  echo ""
  echo "Generado: $TODAY (workflow 01-research-upstream)"
  echo ""
  echo "| Fuente | Commit | Fecha | Verificado | Notas |"
  echo "|---|---|---|---|---|"
  echo "| pmbootstrap | \`$PMB_COMMIT\` | $PMB_DATE | ${PMB_COMMIT:-no} | |"
  echo "| pmaports | \`$PM_COMMIT\` | $PM_DATE | ${PM_COMMIT:-no} | $LAUREL_NOTE |"
  echo "| sm61x5-mainline | \`$SM_COMMIT\` | $SM_DATE | ${SM_COMMIT:-no} | |"
  echo "| LineageOS SM6125 | \`$LO_COMMIT\` | $LO_DATE | ${LO_COMMIT:-no} | referencia DT Android |"
  echo ""
  echo "## Port archivado xiaomi-laurel"
  echo ""
  echo "- Localizado: $LAUREL_FOUND"
  echo "- Notas: $LAUREL_NOTE"
  echo "- Commits recientes en historial:"
  echo "\`\`\`"
  echo "$LAST_LAUREL_COMMIT"
  echo "\`\`\`"
  echo "- kernel APKBUILD: ${KERNEL_APKBUILD:-no localizado}"
  echo "- deviceinfo: ${DEVICEINFO:-no localizado}"
  echo "- firmware dir: ${FW_DIR:-no localizado}"
  echo ""
  echo "## sm61x5-mainline (DTS/panel/táctil)"
  echo ""
  echo "- DTS laurel: \`${DTS_LAUREL:-no localizado}\`"
  echo "- DTS panel S6E8FC0: \`${PANEL_DTS:-no localizado}\`"
  echo "- DTS focaltech: \`${FT_DTS:-no localizado}\`"
  echo "- driver panel: \`${PANEL_DRIVER:-no localizado}\`"
  echo "- driver focaltech: \`${FT_DRIVER:-no localizado}\`"
  echo ""
  echo "## LineageOS SM6125 (referencia)"
  echo ""
  echo "- DTS Android laurel: \`${LO_LAUREL_DTS:-no localizado}\`"
} > "$OUT_DIR/source-audit.md"

info "generando patch-audit.md..."
{
  echo "# Auditoría de parches"
  echo ""
  echo "Generado: $TODAY"
  echo ""
  echo "Áreas a investigar: display (s6e8fc0-m1906f9), touchscreen (FT3518),"
  echo "GPU, wifi, bluetooth, power."
  echo ""
  echo "## Panel S6E8FC0"
  echo ""
  echo "- Compatible objetivo: \`samsung,s6e8fc0-m1906f9\` (con CERO, no O)."
  echo "- DTS sm61x5: \`${PANEL_DTS:-pendiente}\`"
  echo "- Driver sm61x5: \`${PANEL_DRIVER:-pendiente}\`"
  echo ""
  echo "## Táctil FT3518"
  echo ""
  echo "- DTS sm61x5: \`${FT_DTS:-pendiente}\`"
  echo "- Driver sm61x5: \`${FT_DRIVER:-pendiente}\`"
  echo ""
  echo "Estado de cada parche (upstream/accepted/queued/pending/downstream-only/"
  echo "local-workaround) se registra al aplicar."
} > "$OUT_DIR/patch-audit.md"

# hardware-matrix.json se regenera con estados honestos (no tocar hardware).
info "generando hardware-matrix.json..."
jq -n '{
  generated_at: "'"$TODAY"'",
  device: {manufacturer: "Xiaomi", model: "Mi A3", codename: "laurel_sprout"},
  components: {
    display:   {status: "not-targeted", notes: "kernel aún no construido ni probado"},
    gpu:       {status: "not-targeted", notes: "kernel aún no construido ni probado"},
    touchscreen:{status: "not-targeted", notes: "kernel aún no construido ni probado"},
    wifi:      {status: "not-targeted", notes: "hardware por identificar"},
    bluetooth: {status: "not-targeted", notes: "hardware por identificar"},
    ufs:       {status: "not-targeted", notes: ""},
    usb:       {status: "not-targeted", notes: ""},
    battery:   {status: "not-targeted", notes: ""},
    thermal:   {status: "not-targeted", notes: ""},
    cpufreq:   {status: "not-targeted", notes: ""},
    audio:     {status: "not-targeted", notes: "prioridad secundaria"},
    modem:     {status: "not-targeted", notes: "prioridad secundaria"},
    camera:    {status: "not-targeted", notes: "prioridad secundaria"}
  },
  states_allowed: ["not-targeted","source-available","configured","compiled","packaged","static-validation-passed","boot-untested","detected","partially-working","working","blocked","regressed"]
}' > "$OUT_DIR/hardware-matrix.json"

info "informes generados en $OUT_DIR/"
ls -la "$OUT_DIR/"
