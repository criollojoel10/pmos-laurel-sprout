#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# flash-helper.sh
#
# Ayudante de planificación de pruebas NO destructivas. NO ejecuta fastboot:
# valida argumentos, lee la metadata sanitizada y emite el plan de comandos
# que el operador humano podría autorizar (AGENTS.md FASE 8).
#
# El dispositivo permanece de SOLO LECTURA hasta autorización explícita e
# inmediata. Este script jamás invoca fastboot/adb.
#
# Uso: scripts/flash-helper.sh --dry-run [--image boot.img]
#      scripts/flash-helper.sh --verify-metadata

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
META="$REPO_ROOT/device-metadata/fastboot-sanitized.json"

usage() {
  cat >&2 <<'EOF'
uso: scripts/flash-helper.sh --verify-metadata
     scripts/flash-helper.sh --dry-run --image RUTA/boot.img

  --verify-metadata : comprueba que la metadata sanitizada es coherente
  --dry-run         : valida la imagen y emite el plan de comandos (sin
                      ejecutarlos); requiere autorización FASE 8 antes.
  --image RUTA      : ruta al boot.img a planificar.
EOF
  exit 2
}

[ $# -ge 1 ] || usage

CMD=""
IMAGE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verify-metadata) CMD="verify"; shift ;;
    --dry-run) CMD="dryrun"; shift ;;
    --image) IMAGE="$2"; shift 2 ;;
    *) usage ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq requerido" >&2; exit 1; }

if [[ "$CMD" == "verify" ]]; then
  if [[ ! -f "$META" ]]; then
    echo "ERROR: no existe $META" >&2
    exit 1
  fi
  jq -e '.fastboot.product == "laurel_sprout" and .fastboot.unlocked == true and .fastboot.slot_count == "2"' "$META" \
    >/dev/null 2>&1 || { echo "ERROR: metadata incoherente" >&2; exit 1; }
  echo "metadata OK:"
  jq '{device: .device, slot: .fastboot.current_slot, unlocked: .fastboot.unlocked, sizes: {boot_a: .partitions.boot.size_a, dtbo_a: .partitions.dtbo.size_a, vbmeta_a: .partitions.vbmeta.size_a}}' "$META"
  echo ""
  echo "NOTA: nada se ejecuta. La prueba física requiere autorización (FASE 8)."
  exit 0
fi

# ---- dry-run ---------------------------------------------------------------
if [[ "$CMD" == "dryrun" ]]; then
  if [[ -z "$IMAGE" || ! -f "$IMAGE" ]]; then
    echo "ERROR: --image debe apuntar a un boot.img existente" >&2
    exit 1
  fi
  if [[ ! -f "$META" ]]; then
    echo "ERROR: falta $META" >&2
    exit 1
  fi

  SIZE="$(stat -c%s "$IMAGE")"
  BOOT_SIZE_HEX="$(jq -r '.partitions.boot.size_a' "$META")"
  BOOT_SIZE="$(( BOOT_SIZE_HEX ))"

  echo "== Plan de prueba NO destructiva (dry-run) =="
  echo ""
  echo "Imagen  : $IMAGE"
  echo "Tamaño  : $SIZE bytes"
  echo "Límite  : boot = $BOOT_SIZE bytes ($BOOT_SIZE_HEX)"
  echo ""
  if (( SIZE > BOOT_SIZE )); then
    echo "ERROR: la imagen supera el tamaño de la partición boot." >&2
    exit 1
  fi
  echo "Comandos que el operador PODRÍA autorizar (FASE 8):"
  echo ""
  echo "  # 1. Solo lectura: verificar dispositivo y slot actual"
  echo "  fastboot devices"
  echo "  fastboot getvar current-slot"
  echo ""
  echo "  # 2. Prueba en RAM (NO escribe flash)"
  echo "  fastboot boot \"$IMAGE\""
  echo ""
  echo "  # 3. Volver a arrancar normalmente (sin tocar flash)"
  echo "  fastboot reboot"
  echo ""
  echo "IMPORTANTE:"
  echo "  - Este script NO ejecuta los comandos."
  echo "  - No se flashea boot_a/boot_b, dtbo ni vbmeta."
  echo "  - Se requiere respaldo registrado (AGENTS.md sección 7) y"
  echo "    autorización explícita antes de cada comando."
  exit 0
fi

usage
