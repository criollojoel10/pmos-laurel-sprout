#!/usr/bin/env bash
#
# read-fastboot-metadata.sh
#
# Consulta SOLO variables Fastboot de solo lectura sobre el Xiaomi Mi A3
# conectado. Guarda la salida cruda en local-private/ (ignorado por Git) y
# genera device-metadata/fastboot-sanitized.json sin identificadores.
#
# NUNCA ejecuta fastboot boot/flash/erase/format/set_active/reboot.
#
# Uso: scripts/read-fastboot-metadata.sh
# Licencia: GPL-3.0-or-later

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

RAW_DIR="local-private"
RAW_FILE="$RAW_DIR/fastboot-raw.txt"
OUT_FILE="device-metadata/fastboot-sanitized.json"

mkdir -p "$RAW_DIR" "device-metadata"

info() { printf '[fastboot] %s\n' "$*" >&2; }
die() { printf '[fastboot] ERROR: %s\n' "$*" >&2; exit 1; }

command -v fastboot >/dev/null 2>&1 || die "fastboot no está instalado"
command -v jq >/dev/null 2>&1 || die "jq no está instalado"

# Lista explícita y única de consultas permitidas.
readarray -t QUERIES <<'EOF'
product
current-slot
unlocked
slot-count
has-slot:boot
has-slot:dtbo
has-slot:vbmeta
partition-size:boot_a
partition-size:boot_b
partition-size:dtbo_a
partition-size:dtbo_b
partition-size:vbmeta_a
partition-size:vbmeta_b
partition-type:boot_a
partition-type:dtbo_a
partition-type:vbmeta_a
EOF

info "comprobando dispositivo en Fastboot..."
if ! fastboot devices > "$RAW_DIR/fastboot-devices.txt" 2>&1; then
  die "no se pudo enumerar dispositivos Fastboot"
fi

if ! grep -q 'fastboot' "$RAW_DIR/fastboot-devices.txt"; then
  die "ningún dispositivo Fastboot detectado"
fi

: > "$RAW_FILE"

# Serial detectado (nunca se publica).
SERIAL="$(awk '{print $1}' "$RAW_DIR/fastboot-devices.txt" | head -n1)"

info "dispositivo detectado (serial oculto)"
info "escribiendo respuestas crudas en local-private/fastboot-raw.txt"

for q in "${QUERIES[@]}"; do
  {
    printf '== %s ==\n' "$q"
    fastboot getvar "$q" 2>&1
    printf '\n'
  } >> "$RAW_FILE"
done

info "consultando fastboot getvar all (solo para metadata interna, se sanitiza)..."
{
  printf '== getvar all ==\n'
  fastboot getvar all 2>&1
  printf '\n'
} >> "$RAW_FILE"

# --- Sanitización -----------------------------------------------------------
# 1. Extraer los pares var:valor que nos interesan.
# 2. Eliminar serial, IMEI, MAC, tokens y cualquier otro identificador.

sanitize_value() {
  local v="$1"
  v="$(printf '%s' "$v" | tr -d '\r' | sed 's/(bootloader) //g')"
  # Valores que indican "no configurado" / var no soportada
  case "$v" in
    ""|"<not found>"|"unknown") printf 'unavailable' ;;
    *) printf '%s' "$v" ;;
  esac
}

get_pair() {
  # $1 = nombre de variable; extrae de fastboot-raw.txt el valor tras "name:"
  local name="$1"
  grep "^$name:" "$RAW_FILE" | head -n1 | sed "s/^$name:[[:space:]]*//" || true
}

PRODUCT="$(sanitize_value "$(get_pair product)")"
CURRENT_SLOT="$(sanitize_value "$(get_pair current-slot)")"
SLOT_COUNT="$(sanitize_value "$(get_pair slot-count)")"
# unlocked puede venir como "yes"/"no"; normalizamos a booleano.
UNLOCKED_V="$(get_pair unlocked)"
case "$UNLOCKED_V" in
  *yes*) UNLOCKED=true ;;
  *no*)  UNLOCKED=false ;;
  *)     UNLOCKED=null ;;
esac

SIZE_BOOT_A="$(sanitize_value "$(get_pair partition-size:boot_a)")"
SIZE_BOOT_B="$(sanitize_value "$(get_pair partition-size:boot_b)")"
SIZE_DTBO_A="$(sanitize_value "$(get_pair partition-size:dtbo_a)")"
SIZE_DTBO_B="$(sanitize_value "$(get_pair partition-size:dtbo_b)")"
SIZE_VBMETA_A="$(sanitize_value "$(get_pair partition-size:vbmeta_a)")"
SIZE_VBMETA_B="$(sanitize_value "$(get_pair partition-size:vbmeta_b)")"
TYPE_BOOT_A="$(sanitize_value "$(get_pair partition-type:boot_a)")"
TYPE_DTBO_A="$(sanitize_value "$(get_pair partition-type:dtbo_a)")"
TYPE_VBMETA_A="$(sanitize_value "$(get_pair partition-type:vbmeta_a)")"

HAS_SLOT_BOOT="$(sanitize_value "$(get_pair has-slot:boot)")"
HAS_SLOT_DTBO="$(sanitize_value "$(get_pair has-slot:dtbo)")"
HAS_SLOT_VBMETA="$(sanitize_value "$(get_pair has-slot:vbmeta)")"

derive_has_slot() {
  # $1 = nombre de partición (boot, dtbo, vbmeta)
  local part="$1"
  local a b
  a="$(get_pair "partition-size:${part}_a")"
  b="$(get_pair "partition-size:${part}_b")"
  if [[ -n "$a" && -n "$b" ]]; then
    printf 'yes'
  elif [[ -n "$a" ]]; then
    printf 'no'
  else
    printf 'unavailable'
  fi
}

[[ "$HAS_SLOT_BOOT" == "unavailable" ]] && HAS_SLOT_BOOT="$(derive_has_slot boot)"
[[ "$HAS_SLOT_DTBO" == "unavailable" ]] && HAS_SLOT_DTBO="$(derive_has_slot dtbo)"
[[ "$HAS_SLOT_VBMETA" == "unavailable" ]] && HAS_SLOT_VBMETA="$(derive_has_slot vbmeta)"

# --- Exportación ------------------------------------------------------------
cat > "$OUT_FILE" <<EOF
{
  "device": {
    "manufacturer": "Xiaomi",
    "model": "Mi A3",
    "codename": "laurel_sprout",
    "soq": "Qualcomm SM6125",
    "platform": "trinket",
    "arch": "aarch64"
  },
  "fastboot": {
    "product": $(jq -n --arg v "$PRODUCT" '$v'),
    "current_slot": $(jq -n --arg v "$CURRENT_SLOT" '$v'),
    "unlocked": $(printf '%s' "$UNLOCKED"),
    "slot_count": $(jq -n --arg v "$SLOT_COUNT" '$v'),
    "has_slot": {
      "boot": $(jq -n --arg v "$HAS_SLOT_BOOT" '$v'),
      "dtbo": $(jq -n --arg v "$HAS_SLOT_DTBO" '$v'),
      "vbmeta": $(jq -n --arg v "$HAS_SLOT_VBMETA" '$v')
    }
  },
  "partitions": {
    "boot": {
      "size_a": $(jq -n --arg v "$SIZE_BOOT_A" '$v'),
      "size_b": $(jq -n --arg v "$SIZE_BOOT_B" '$v'),
      "type_a": $(jq -n --arg v "$TYPE_BOOT_A" '$v')
    },
    "dtbo": {
      "size_a": $(jq -n --arg v "$SIZE_DTBO_A" '$v'),
      "size_b": $(jq -n --arg v "$SIZE_DTBO_B" '$v'),
      "type_a": $(jq -n --arg v "$TYPE_DTBO_A" '$v')
    },
    "vbmeta": {
      "size_a": $(jq -n --arg v "$SIZE_VBMETA_A" '$v'),
      "size_b": $(jq -n --arg v "$SIZE_VBMETA_B" '$v'),
      "type_a": $(jq -n --arg v "$TYPE_VBMETA_A" '$v')
    }
  },
  "privacy": {
    "serial_number_never_published": true,
    "imei_never_published": true,
    "mac_never_published": true,
    "raw_fastboot_output_in_local_private": true
  },
  "captured_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# La salida sanitizada NO debe contener el serial ni otras huellas.
if grep -qE "$SERIAL" "$OUT_FILE" 2>/dev/null; then
  die "sanitización falló: serial presente en salida sanitizada"
fi

# Confirmación final de que no se ejecutó nada destructivo.
info "OK: no se escribió nada en el dispositivo."
info "crudo guardado en  $RAW_FILE (privado, ignorado por Git)"
info "metadata lista en   $OUT_FILE"
exit 0
