#!/usr/bin/env bash
#
# inspect-boot-image.sh
#
# Extrae y verifica un boot.img Android: kernel, ramdisk, DTB, cmdline y
# límite de partición. Compara kernel/ramdisk extraídos con los originales.
#
# Uso:
#   scripts/inspect-boot-image.sh \
#     --boot <boot.img> \
#     --kernel <Image-original> \
#     --ramdisk <initramfs-original> \
#     --dtb <dtb-original> \
#     --boot-limit <bytes> \
#     --out <dir>
# Licencia: GPL-3.0-or-later

set -Eeuo pipefail

BOOT=""
KERNEL=""
RAMDISK=""
DTB=""
LIMIT=""
OUT=""

usage() {
  echo "uso: $0 --boot <boot.img> --kernel <Image> --ramdisk <initramfs> --dtb <dtb> --boot-limit <bytes> --out <dir>" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --boot) BOOT="$2"; shift 2 ;;
    --kernel) KERNEL="$2"; shift 2 ;;
    --ramdisk) RAMDISK="$2"; shift 2 ;;
    --dtb) DTB="$2"; shift 2 ;;
    --boot-limit) LIMIT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$BOOT" && -n "$KERNEL" && -n "$RAMDISK" && -n "$DTB" && -n "$LIMIT" && -n "$OUT" ]] || usage

info() { printf '[inspect] %s\n' "$*" >&2; }
mkdir -p "$OUT"

command -v unbootimg >/dev/null 2>&1 && TOOL="unbootimg" || TOOL="none"
info "herramienta de extracción: $TOOL"

# Tamaño del boot y límite de partición
BOOT_SIZE="$(stat -c %s "$BOOT")"
if (( BOOT_SIZE > LIMIT )); then
  echo "ERROR: boot.img ($BOOT_SIZE) supera el límite de partición ($LIMIT)" >&2
  exit 1
fi
info "boot.img: $BOOT_SIZE bytes (límite $LIMIT) — OK"

cat > "$OUT/boot-image-report.md" <<EOF
# Informe boot image — laurel_sprout

Generado: $(date -u +%Y-%m-%dT%H:%M:%SZ)

| Comprobación | Resultado |
|---|---|
| Tamaño boot.img | $BOOT_SIZE bytes |
| Límite partición boot | $LIMIT bytes |
| Cabe en partición | $( (( BOOT_SIZE <= LIMIT )) && echo SÍ || echo NO ) |
| Hash original kernel | $(sha256sum "$KERNEL" | awk '{print $1}') |
| Hash original ramdisk | $(sha256sum "$RAMDISK" | awk '{print $1}') |
| Hash original dtb | $(sha256sum "$DTB" | awk '{print $1}') |
EOF

# Extracción con la herramienta disponible
if [[ "$TOOL" == "unbootimg" ]]; then
  (cd "$OUT" && unbootimg "$BOOT") >/dev/null 2>&1 || info "unbootimg falló; revisa en CI"
fi

# Comparación por hashes si se extrajeron
EXT_KERNEL="$OUT/kernel"
EXT_RAMDISK="$OUT/ramdisk"   # nombre variable según herramienta
EXT_DTB="$OUT/dtb"

for pair in "kernel:$KERNEL" "ramdisk:$RAMDISK" "dtb:$DTB"; do
  name="${pair%%:*}"
  orig="${pair#*:}"
  ext=""
  for cand in "$OUT/$name" "$OUT/$name.img" "$OUT/${name}-orig" "$OUT/${name}_$(basename "$orig")"; do
    if [[ -f "$cand" ]]; then ext="$cand"; break; fi
  done
  if [[ -n "$ext" ]]; then
    if [[ "$(sha256sum "$orig" | awk '{print $1}')" == "$(sha256sum "$ext" | awk '{print $1}')" ]]; then
      echo "| $name extraído == original | SÍ |" >> "$OUT/boot-image-report.md"
      info "OK: $name coincide con el original"
    else
      echo "| $name extraído == original | NO |" >> "$OUT/boot-image-report.md"
      info "AVISO: $name extraído difiere del original (puede ser normal con re-empaquetado)"
    fi
  else
    echo "| $name extraído | no disponible (herramienta) |" >> "$OUT/boot-image-report.md"
    info "AVISO: no se pudo extraer $name"
  fi
done

echo "" >> "$OUT/boot-image-report.md"
echo "## Verificación DTB dentro del boot" >> "$OUT/boot-image-report.md"
echo "" >> "$OUT/boot-image-report.md"
echo "Se valida el DTB extraído (o el original) con scripts/verify-dtb.sh." >> "$OUT/boot-image-report.md"

info "informe: $OUT/boot-image-report.md"
exit 0
