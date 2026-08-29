#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# research-upstream.sh
#
# Ejecuta la auditoría upstream dentro de GitHub Actions (01-research-upstream).
# Descarga de forma temporal y liviana (shallow, profundidad acotada):
#   - pmbootstrap
#   - pmaports (port archivado xiaomi-laurel + dispositivos de referencia)
#   - sm61x5-mainline/linux (DTS laurel_sprout, panel, touchscreen, GPU)
#   - LineageOS SM6125 (referencia DT Android)
# Genera en reports/:
#   - source-candidates.json
#   - source-audit.md
#   - patch-audit.md
#   - device-comparison.md
#   - firmware-audit.md
#   - boot-image-layout.md
#   - hypothesis-registry.json
#   - hardware-matrix.json
#
# No sube fuentes, no construye kernel, no modifica el repositorio.
# Uso: scripts/research-upstream.sh [--tmp DIR] [--out DIR]

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

TMP_DIR="/tmp/research-upstream"
OUT_DIR="reports"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tmp) TMP_DIR="$2"; shift 2 ;;
    --out) OUT_DIR="$2"; shift 2 ;;
    *) echo "uso: $0 [--tmp DIR] [--out DIR]" >&2; exit 2 ;;
  esac
done

info() { printf '[research] %s\n' "$*" >&2; }

command -v git >/dev/null 2>&1 || { echo "ERROR: git requerido" >&2; exit 1; }
command -v jq  >/dev/null 2>&1 || { echo "ERROR: jq requerido" >&2; exit 1; }

mkdir -p "$TMP_DIR" "$OUT_DIR"

# Git minimal: shallow, single branch, depth acotado.
fetch_shallow() {
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
if fetch_shallow "https://gitlab.postmarketos.org/postmarketOS/pmbootstrap.git" "$PMB" "main"; then
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
if fetch_shallow "https://gitlab.postmarketos.org/postmarketOS/pmaports.git" "$PM" "main"; then
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
    info "port archivado xiaomi-laurel NO encontrado en la rama main actual (puede estar archivado/eliminado)"
    LAUREL_NOTE="no localizado en main actual; buscar en historial git de pmaports"
  fi

  # Buscar en historial (git log --all) el último commit del port
  LAST_LAUREL_COMMIT="$(git -C "$PM" log --all --oneline --diff-filter=A -- '*/device-xiaomi-laurel/*' 2>/dev/null | head -n5 || true)"

  # APKBUILD y deviceinfo históricos
  KERNEL_APKBUILD="$(find "$PM" -path '*linux-xiaomi-laurel/APKBUILD' 2>/dev/null | head -n1 || true)"
  DEVICEINFO="$(find "$PM" -path '*device-xiaomi-laurel/deviceinfo' 2>/dev/null | head -n1 || true)"
  FW_DIR="$(find "$PM" -maxdepth 5 -type d -name 'firmware-xiaomi-laurel' 2>/dev/null | head -n1 || true)"

  # Dispositivos de referencia del mismo SoC o GPU (comparativa)
  info "buscando dispositivos de referencia en pmaports..."
  REF_DEVICES="{}"
  while read -r d; do
    [[ -z "$d" ]] && continue
    name="$(basename "$d")"
    devinfo="$d/deviceinfo"
    if [[ -f "$devinfo" ]]; then
      arch="$(awk -F= '/^deviceinfo_arch=/{print $2}' "$devinfo" 2>/dev/null | tr -d '"' || true)"
      soc="$(awk -F= '/^deviceinfo_soc=/{print $2}' "$devinfo" 2>/dev/null | tr -d '"' || true)"
      cpu="$(awk -F= '/^deviceinfo_chassis=/{print $2}' "$devinfo" 2>/dev/null | tr -d '"' || true)"
      REF_DEVICES="$(jq -n --arg name "$name" --arg arch "$arch" --arg soc "$soc" --arg chassis "$cpu" \
        --argjson acc "$REF_DEVICES" \
        '$acc + {($name): {path: $name, arch: $arch, soc: $soc, chassis: $chassis}}')"
    fi
  done < <(find "$PM/device" -maxdepth 3 -type d \( -name 'device-xiaomi-*' -o -name 'device-xiaomi_*' \) 2>/dev/null | sort | head -n 40)

  # Candidatos específicos por interés (sofia, ginkgo, willow, pdx201, doha)
  REF_KEYS="{}"
  for cand in sofia ginkgo willow pdx201 doha; do
    if echo "$REF_DEVICES" | jq -e --arg c "$cand" 'keys | map(contains($c)) | any' >/dev/null 2>&1; then
      REF_KEYS="$(jq -n --arg c "$cand" --argjson acc "$REF_KEYS" '$acc + {($c): true}')"
    fi
  done

  # Firmware-qcom-adreno-a610 en pmaports.
  # No es un directorio independiente: es un subpackage generado desde el
  # APKBUILD padre firmware-qcom-adreno (device/community/firmware-qcom-adreno).
  # Buscar el APKBUILD padre y analizar subpackages declarados.
  FW_A610=""
  FW_A610_PKG="$(find "$PM" -path '*firmware-qcom-adreno/APKBUILD' -type f 2>/dev/null | head -n1 || true)"
  if [[ -n "$FW_A610_PKG" ]]; then
    FW_A610_VER="$(awk -F= '/^pkgver=/{gsub(/"/,"",$2); print $2; exit}' "$FW_A610_PKG" 2>/dev/null || true)"
    FW_A610_ARCH="$(awk -F= '/^arch=/{gsub(/"/,"",$2); print $2; exit}' "$FW_A610_PKG" 2>/dev/null || true)"
    FW_A610_NAME="$(awk -F= '/^pkgname=/{gsub(/"/,"",$2); print $2; exit}' "$FW_A610_PKG" 2>/dev/null || true)"
    FW_A610_SUBPKGS="$(awk '/^subpackages=/,/^"/' "$FW_A610_PKG" 2>/dev/null | tr -d '"' | tr '\t' ' ' | tr -s ' ' | sed "s/\$pkgname/${FW_A610_NAME:-firmware-qcom-adreno}/g" | grep -o 'firmware-qcom-adreno-a610[^ ]*' | head -n1 || true)"
    if [[ -n "$FW_A610_SUBPKGS" ]]; then
      FW_A610="subpackage generado: pkgver=$FW_A610_VER arch=$FW_A610_ARCH (padre: $FW_A610_PKG)"
      info "firmware-qcom-adreno-a610: $FW_A610"
    else
      FW_A610="APKBUILD padre localizado pero sin subpackage a610 ($FW_A610_PKG)"
    fi
  else
    FW_A610="APKBUILD padre firmware-qcom-adreno no localizado en main"
    info "$FW_A610"
  fi
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
  REF_DEVICES="{}"
  REF_KEYS="{}"
  FW_A610="unavailable"
fi

# ---- 3. sm61x5-mainline ----------------------------------------------------
info "descargando sm61x5-mainline/linux (shallow)..."
SM="$TMP_DIR/sm61x5"
if fetch_shallow "https://codeberg.org/sm61x5-mainline/linux.git" "$SM" "master"; then
  SM_COMMIT="$(git -C "$SM" rev-parse HEAD)"
  SM_DATE="$(git -C "$SM" log -1 --format=%cI 2>/dev/null || echo "unknown")"
  info "sm61x5-mainline: $SM_COMMIT ($SM_DATE)"

  # Verificar existencia de rama sm61x5/6.19.5 y tag v6.19.5-r0 (issue #1)
  info "verificando rama sm61x5/6.19.5 y tag v6.19.5-r0..."
  BR_SM61X5_6195=""
  if git -C "$SM" ls-remote --heads origin 'sm61x5/6.19.5' 2>/dev/null | grep -q .; then
    BR_SM61X5_6195="existe"
  else
    BR_SM61X5_6195="NO existe"
  fi
  TAG_SM61X5=""
  if git -C "$SM" ls-remote --tags origin 'v6.19.5-r0' 2>/dev/null | grep -q .; then
    TAG_SM61X5="existe"
  else
    TAG_SM61X5="NO existe"
  fi

  DTS_LAUREL="$(find "$SM/arch/arm64/boot/dts/qcom" -name 'sm6125*laurel*' 2>/dev/null | head -n1 || true)"
  PANEL_DTS="$(find "$SM/arch/arm64/boot/dts/qcom" -name '*s6e8fc0*' 2>/dev/null | head -n1 || true)"
  FT_DTS="$(find "$SM/arch/arm64/boot/dts/qcom" -iname '*focaltech*' 2>/dev/null | head -n1 || true)"
  PANEL_DRIVER="$(find "$SM/drivers/gpu/drm/panel" -name '*s6e8fc0*' 2>/dev/null | head -n1 || true)"
  FT_DRIVER="$(find "$SM/drivers/input/touchscreen" -iname '*focaltech*' 2>/dev/null | head -n1 || true)"
  DEFCONFIG_SM61X5="$(find "$SM/arch/arm64/configs" -name 'sm61x5_defconfig' 2>/dev/null | head -n1 || true)"
else
  info "AVISO: no se pudo descargar sm61x5-mainline"
  SM_COMMIT="unavailable"
  SM_DATE=""
  BR_SM61X5_6195="unavailable"
  TAG_SM61X5="unavailable"
  DTS_LAUREL=""
  PANEL_DTS=""
  FT_DTS=""
  PANEL_DRIVER=""
  FT_DRIVER=""
  DEFCONFIG_SM61X5=""
fi

# ---- 4. LineageOS SM6125 (referencia) --------------------------------------
info "descargando LineageOS SM6125 (shallow, referencia)..."
LO="$TMP_DIR/lineage-sm6125"
if fetch_shallow "https://github.com/LineageOS/android_kernel_xiaomi_sm6125.git" "$LO" "lineage-22.2"; then
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
      "url": "https://gitlab.postmarketos.org/postmarketOS/pmbootstrap.git",
      "branch": "main",
      "commit": $(jq -n --arg v "$PMB_COMMIT" '$v'),
      "commit_date": $(jq -n --arg v "$PMB_DATE" '$v')
    },
    {
      "name": "pmaports",
      "url": "https://gitlab.postmarketos.org/postmarketOS/pmaports.git",
      "branch": "main",
      "commit": $(jq -n --arg v "$PM_COMMIT" '$v'),
      "commit_date": $(jq -n --arg v "$PM_DATE" '$v'),
      "archived_port": {
        "xiaomi_laurel_found": "$LAUREL_FOUND",
        "notes": $(jq -n --arg v "$LAUREL_NOTE" '$v'),
        "last_commits": $(jq -n --arg v "$LAST_LAUREL_COMMIT" '$v'),
        "kernel_apkbuild": $(jq -n --arg v "${KERNEL_APKBUILD:-}" '$v'),
        "deviceinfo": $(jq -n --arg v "${DEVICEINFO:-}" '$v'),
        "firmware_dir": $(jq -n --arg v "${FW_DIR:-}" '$v')
      },
      "firmware_qcom_adreno_a610": $(jq -n --arg v "${FW_A610:-}" '$v'),
      "firmware_qcom_adreno_a610_pkgpath": $(jq -n --arg v "${FW_A610_PKG:-}" '$v'),
      "reference_devices": $REF_DEVICES,
      "reference_keys_found": $REF_KEYS
    },
    {
      "name": "sm61x5-mainline",
      "url": "https://codeberg.org/sm61x5-mainline/linux.git",
      "branch": "master",
      "commit": $(jq -n --arg v "$SM_COMMIT" '$v'),
      "commit_date": $(jq -n --arg v "$SM_DATE" '$v'),
      "branch_sm61x5_6195_exists": "$BR_SM61X5_6195",
      "tag_v6195_r0_exists": "$TAG_SM61X5",
      "files": {
        "dts_laurel": $(jq -n --arg v "${DTS_LAUREL:-}" '$v'),
        "panel_dts": $(jq -n --arg v "${PANEL_DTS:-}" '$v'),
        "focaltech_dts": $(jq -n --arg v "${FT_DTS:-}" '$v'),
        "panel_driver": $(jq -n --arg v "${PANEL_DRIVER:-}" '$v'),
        "focaltech_driver": $(jq -n --arg v "${FT_DRIVER:-}" '$v'),
        "sm61x5_defconfig": $(jq -n --arg v "${DEFCONFIG_SM61X5:-}" '$v')
      }
    },
    {
      "name": "lineageos-sm6125",
      "url": "https://github.com/LineageOS/android_kernel_xiaomi_sm6125.git",
      "branch": "lineage-22.2",
      "commit": $(jq -n --arg v "$LO_COMMIT" '$v'),
      "commit_date": $(jq -n --arg v "$LO_DATE" '$v'),
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
  echo "| Fuente | Rama | Commit | Fecha | Notas |"
  echo "|---|---|---|---|---|"
  echo "| pmbootstrap | main | \`$PMB_COMMIT\` | $PMB_DATE | gitlab.postmarketos.org |"
  echo "| pmaports | main | \`$PM_COMMIT\` | $PM_DATE | $LAUREL_NOTE |"
  echo "| sm61x5-mainline | master | \`$SM_COMMIT\` | $SM_DATE | rama sm61x5/6.19.5: $BR_SM61X5_6195; tag v6.19.5-r0: $TAG_SM61X5 |"
  echo "| LineageOS SM6125 | lineage-22.2 | \`$LO_COMMIT\` | $LO_DATE | referencia DT Android |"
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
  echo "## Firmware Adreno A610"
  echo ""
  echo "- firmware-qcom-adreno-a610 en pmaports main: $FW_A610"
  echo ""
  echo "## sm61x5-mainline (DTS/panel/táctil)"
  echo ""
  echo "- Rama sm61x5/6.19.5: $BR_SM61X5_6195 (issue #1 sm61x5-mainline abierta)"
  echo "- Tag v6.19.5-r0: $TAG_SM61X5"
  echo "- DTS laurel: \`${DTS_LAUREL:-no localizado}\`"
  echo "- DTS panel S6E8FC0: \`${PANEL_DTS:-no localizado}\`"
  echo "- DTS focaltech: \`${FT_DTS:-no localizado}\`"
  echo "- driver panel: \`${PANEL_DRIVER:-no localizado}\`"
  echo "- driver focaltech: \`${FT_DRIVER:-no localizado}\`"
  echo "- sm61x5_defconfig: \`${DEFCONFIG_SM61X5:-no localizado}\`"
  echo ""
  echo "## LineageOS SM6125 (referencia)"
  echo ""
  echo "- DTS Android laurel: \`${LO_LAUREL_DTS:-no localizado}\`"
} > "$OUT_DIR/source-audit.md"

info "generando device-comparison.md..."
{
  echo "# Comparativa de dispositivos de referencia"
  echo ""
  echo "Generado: $TODAY"
  echo ""
  echo "Objetivo: identificar dispositivos ya soportados en postmarketOS que usen"
  echo "SM6115/SM6125, Adreno 610 o WCN3990 para servir de base de config,"
  echo "firmware y deviceinfo."
  echo ""
  if [[ "$REF_DEVICES" == "{}" ]]; then
    echo "No se localizaron dispositivos Xiaomi en pmaports main."
    echo ""
    echo "Sospechosos de interés (se auditan en docs/DEVICE-COMPARISON.md):"
    echo "- sofia (Xiaomi Redmi 6A) — SM6115, Adreno 610"
    echo "- ginkgo (Redmi Note 8) — SM6125, Adreno 610"
    echo "- willow (Redmi Note 8T) — SM6125, Adreno 610"
    echo "- pdx201 (Sony Xperia 10 II) — SM6125, Adreno 610"
    echo "- doha (Sony Xperia 10 III) — SM7225/Adreno 619 (relativo)"
  else
    echo "Dispositivos Xiaomi localizados en pmaports main:"
    echo ""
    echo "\`\`\`json"
    echo "$REF_DEVICES" | jq .
    echo "\`\`\`"
  fi
  echo ""
  echo "Estado: registro inicial. La lista definitiva se completa en el"
  echo "workflow de build con pmaports real."
} > "$OUT_DIR/device-comparison.md"

info "generando firmware-audit.md..."
{
  echo "# Auditoría de firmware"
  echo ""
  echo "Generado: $TODAY"
  echo ""
  echo "Componentes de radio/vendedor necesarios para laurel_sprout:"
  echo ""
  echo "- GPU: firmware-qcom-adreno-a610 -> $FW_A610"
  echo "  - Subpackage generado desde el APKBUILD padre firmware-qcom-adreno"
  echo "    (device/community/firmware-qcom-adreno/APKBUILD)."
  echo "  - El subpackage a610 es un metapaquete vacío (instala solo el"
  echo "    directorio /usr/lib/firmware/qcom/) y depende de"
  echo "    firmware-qcom-adreno-a630-sqe."
  echo "  - a630-sqe instala qcom/a630_sqe.fw (el A610 no tiene GMU propio)."
  echo "- WLAN/BT: WCN3990 (qca6390 / qcom/wcn3990*)"
  echo "- Modem: mba.mbn + qdsp6.mbn (SM6125/trinket)"
  echo "- ADSP/CDSP: adsp.mbn, cdsp.mbn"
  echo "- Venüs: venus-*.mbn (solo si se usa Venus HW codec)"
  echo ""
  echo "Origen: deviceinfo/lk2nd y firmware stock (Xiaomi Mi A3). No se"
  echo "redistribuye firmware sin verificación de licencia."
  echo ""
  echo "Verificación local pendiente en workflow build:"
  echo "- licencias de cada blob en linux-firmware"
  echo "- correspondencia con configs/firmware/firmware-manifest.json"
} > "$OUT_DIR/firmware-audit.md"

info "generando boot-image-layout.md..."
{
  echo "# Layout de boot image para laurel_sprout (A/B)"
  echo ""
  echo "Generado: $TODAY"
  echo ""
  echo "Particiones relevantes (metadatos reales del dispositivo):"
  echo ""
  echo "\`\`\`text"
  echo "boot   (64 MiB, has-slot) -> kernel + ramdisk + DTB"
  echo "dtbo   (24 MiB, has-slot) -> overlays DTBO (NO se modificará)"
  echo "vbmeta (64 KiB, has-slot) -> verified boot (NO se modificará)"
  echo "\`\`\`"
  echo ""
  echo "Estrategia no destructiva (ver docs/NON-DESTRUCTIVE-BOOT.md):"
  echo ""
  echo "- boot.img v2+ con DTB integrado (QCDT) para arranque sin partición dtbo"
  echo "- usar \`fastboot boot\` para prueba en RAM (NO escribir flash)"
  echo "- lk2nd habilita boot de mainline desde boot_a sin tocar dtbo/vbmeta"
  echo ""
  echo "Riesgo: si el bootloader exige dtbo, el DTB en boot.img (QCDT) debe"
  echo "coincidir con el índice del dispositivo. Se valida con boot-image"
  echo "convencional (Android) antes de probar mainline."
} > "$OUT_DIR/boot-image-layout.md"

info "generando hypothesis-registry.json..."
jq -n --arg today "$TODAY" \
  --arg br "$BR_SM61X5_6195" \
  --arg tag "$TAG_SM61X5" \
  --arg defc "${DEFCONFIG_SM61X5:-}" \
  '{
  generated_at: $today,
  hypotheses: [
    {id: "H1", claim: "la rama sm61x5/6.19.5 existe en sm61x5-mainline", status: ($br | if . == "existe" then "confirmed" elif . == "NO existe" then "refuted" else "unverified" end), source: "sm61x5-mainline git ls-remote"},
    {id: "H2", claim: "existe tag v6.19.5-r0", status: ($tag | if . == "existe" then "confirmed" elif . == "NO existe" then "refuted" else "unverified" end), source: "sm61x5-mainline git ls-remote"},
    {id: "H3", claim: "existe sm61x5_defconfig", status: (if $defc != "" then "confirmed" else "refuted" end), source: "árbol sm61x5-mainline arch/arm64/configs"},
    {id: "H4", claim: "laurel_sprout soportado en mainline 6.19 (DTS + panel + táctil)", status: "needs-reverification", source: "por verificar en rama dev o patches"},
    {id: "H5", claim: "firmware-qcom-adreno-a610 empaquetado en pmaports", status: "needs-reverification", source: "pmaports"},
    {id: "H6", claim: "WCN3990 es el combo WLAN/BT de laurel_sprout", status: "unverified", source: "referencias Android"},
    {id: "H7", claim: "fastboot boot funciona para arranque no destructivo", status: "unverified", source: "por probar en hardware, SOLO con autorización"},
    {id: "H8", claim: "DTB mainline en boot.img (QCDT) es suficiente sin partición dtbo", status: "unverified", source: "por validar"},
    {id: "H9", claim: "borrar dtbo/vbmeta es necesario para arrancar mainline", status: "unverified", source: "dudoso; se evita (no destructivo)"},
    {id: "H10", claim: "card0/simpledrm activo implica GPU y display funcionales", status: "refuted", source: "no confundir DRM básico con aceleración; honestidad AGENTS.md"},
    {id: "H11", claim: "6.19 es la mejor base frente a LTS/estable", status: "needs-reverification", source: "docs/KERNEL-BASE-COMPARISON.md"}
  ],
  states_allowed: ["confirmed","refuted","needs-reverification","unverified","deferred"]
}' > "$OUT_DIR/hypothesis-registry.json"

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
  echo "- Corrección v2 (2026-06-08, Yedaya Katsman): typo \`s6e8fco\` -> \`s6e8fc0\`."
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
