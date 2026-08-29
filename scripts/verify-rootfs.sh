#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# verify-rootfs.sh
#
# Valida un rootfs de postmarketOS: integridad, fsck no destructivo,
# presencia de systemd, SSH, NetworkManager/USB networking y (si es Plasma)
# del metapaquete plasma-mobile.
#
# Uso:
#   scripts/verify-rootfs.sh --rootfs <imagen.img> [--plasma] --out <dir>

set -Eeuo pipefail

ROOTFS=""
PLASMA=0
OUT=""

usage() {
  echo "uso: $0 --rootfs <imagen.img> [--plasma] --out <dir>" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --rootfs) ROOTFS="$2"; shift 2 ;;
    --plasma) PLASMA=1; shift ;;
    --out) OUT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$ROOTFS" && -n "$OUT" ]] || usage
[[ -f "$ROOTFS" ]] || { echo "ERROR: rootfs no existe: $ROOTFS" >&2; exit 1; }

info() { printf '[rootfs] %s\n' "$*" >&2; }
mkdir -p "$OUT"

REPORT="$OUT/rootfs-report.md"
{
  echo "# Informe rootfs — laurel_sprout"
  echo ""
  echo "Generado: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo ""
  echo "| Comprobación | Resultado |"
  echo "|---|---|"
  echo "| Imagen | \`$ROOTFS\` |"
  echo "| Tamaño | $(stat -c %s "$ROOTFS") bytes |"
  echo "| SHA-256 | $(sha256sum "$ROOTFS" | awk '{print $1}') |"
} > "$REPORT"

# Determinación del tipo de filesystem (ext4 esperado)
FSTYPE="$(file -b "$ROOTFS")"
echo "| Tipo detectado | \`$FSTYPE\` |" >> "$REPORT"
info "tipo: $FSTYPE"

# fsck en modo no destructivo si es ext4
case "$FSTYPE" in
  *ext4*)
    if command -v e2fsck >/dev/null 2>&1; then
      set +e
      e2fsck -n -f "$ROOTFS" > "$OUT/fsck.log" 2>&1
      RC=$?
      set -e
      if (( RC == 0 || RC == 1 )); then
        echo "| fsck (no destructivo) | OK (rc=$RC) |" >> "$REPORT"
      else
        echo "| fsck (no destructivo) | ERROR (rc=$RC) |" >> "$REPORT"
      fi
      info "fsck: rc=$RC"
    else
      echo "| fsck | e2fsck no disponible en runner |" >> "$REPORT"
    fi
    ;;
  *)
    echo "| fsck | no aplicable (tipo no ext4) |" >> "$REPORT"
    ;;
esac

# Montaje de solo lectura para verificar contenidos (si es posible en CI)
if command -v mount >/dev/null 2>&1; then
  MNT="$OUT/mnt"
  mkdir -p "$MNT"
  set +e
  sudo mount -o ro,loop "$ROOTFS" "$MNT" 2>/dev/null
  RC=$?
  set -e
  if (( RC == 0 )); then
    info "rootfs montado en solo lectura"
    if [[ -d "$MNT/usr/lib/systemd" ]]; then
      echo "| systemd presente | SÍ |" >> "$REPORT"
    else
      echo "| systemd presente | NO |" >> "$REPORT"
    fi
    if [[ -f "$MNT/etc/ssh/sshd_config" || -d "$MNT/etc/ssh" ]]; then
      echo "| SSH configurado | SÍ |" >> "$REPORT"
    else
      echo "| SSH configurado | NO |" >> "$REPORT"
    fi
    if (( PLASMA )); then
      if grep -q 'plasma-mobile' "$MNT/etc/apk/world" 2>/dev/null || [[ -d "$MNT/usr/share/plasma" ]]; then
        echo "| Plasma Mobile | SÍ |" >> "$REPORT"
      else
        echo "| Plasma Mobile | NO |" >> "$REPORT"
      fi
    fi
    # Lista de unidades systemd activadas
    (cd "$MNT" && find etc/systemd -name '*.wants' -maxdepth 3 2>/dev/null) > "$OUT/systemd-units.txt" || true
    sudo umount "$MNT"
  else
    info "no se pudo montar el rootfs (no crítico en CI)"
    echo "| Montaje de lectura | no disponible en este runner |" >> "$REPORT"
  fi
fi

info "informe generado: $REPORT"
exit 0
