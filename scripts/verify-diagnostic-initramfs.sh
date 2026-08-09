#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# verify-diagnostic-initramfs.sh
#
# Verifica que un initramfs de diagnóstico (cpio gzip) cumple los requisitos
# aprendidos del incidente EX3 (kernel 6.1: /init murió por falta de sed ->
# "Kernel panic - not syncing: Attempted to kill init!").
#
# Comprobaciones:
#   - ramdisk es cpio newc + gzip
#   - /init tiene shebang #!/bin/busybox sh (no /bin/sh)
#   - /init NO usa `set -e`
#   - /init contiene la marca INITRAMFS_REACHED (llega al final)
#   - /init NO contiene operaciones destructivas (reboot, format, fsck, dd,
#     flash, erase, fastboot, userdata, set_active)
#   - bin/busybox existe y es aarch64 estático
#   - existen los applets requeridos por /init y la shell de rescate
#     (sed, grep, awk, mount, umount, mkdir, mknod, sleep, dmesg, uptime,
#     ls, cp, sync, switch_root, cat, sh, tr, wc, setsid)
#   - sed está disponible (causa raíz EX3)
#
# Uso:
#   scripts/verify-diagnostic-initramfs.sh \
#     --ramdisk <initramfs.cpio.gz> \
#     [--init <initramfs/init>] \
#     [--busybox-root <árbol-instalado>] \
#     [--out <dir>]

set -Eeuo pipefail

RAMDISK=""
INIT_SRC=""
BBROOT=""
OUT="."

while (( $# > 0 )); do
  case "$1" in
    --ramdisk) RAMDISK="$2"; shift 2 ;;
    --init) INIT_SRC="$2"; shift 2 ;;
    --busybox-root) BBROOT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) echo "uso: $0 --ramdisk <cpio.gz> [--init <init>] [--busybox-root <dir>] [--out <dir>]" >&2; exit 2 ;;
  esac
done

[[ -n "$RAMDISK" && -f "$RAMDISK" ]] || { echo "ERROR: --ramdisk requerido y debe existir" >&2; exit 2; }
mkdir -p "$OUT"

REQUIRED_APPLETS=(sh cat sed grep awk mount umount mkdir mknod sleep dmesg \
                  uptime ls cp sync switch_root tr wc setsid)
# Comandos destructivos: se buscan SOLO en líneas de código (no comentarios),
# como palabra completa. Un encabezado que diga "NO formatea" no debe fallar.
DESTRUCTIVE=(reboot format mkfs fsck dd flash erase fastboot userdata \
             set_active wipe swapon swapoff)

report=""
fail=""
check() {
  # check <nombre> <bool> <detalle>
  local name="$1" ok="$2" detail="$3"
  report+="| $name | $([[ "$ok" == "1" ]] && echo SÍ || echo NO) | $detail |\n"
  if [[ "$ok" != "1" ]]; then fail+=" $name"; fi
}

TMP="$(mktemp -d /tmp/verify-initramfs.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
gzip -dc "$RAMDISK" > "$TMP/ram.cpio" 2>"$TMP/gz.err" || true

check "ramdisk es gzip" "$([[ -s "$TMP/gz.err" ]] && echo 0 || echo 1)" "gzip -dc sin error"
if cpio -t < "$TMP/ram.cpio" >/dev/null 2>&1; then
  check "ramdisk es cpio newc" "1" "cpio -t OK"
  ( cd "$TMP" && cpio -idm < ram.cpio >/dev/null 2>&1 ) || true
else
  check "ramdisk es cpio newc" "0" "cpio -t falló"
fi

if [[ -n "$INIT_SRC" && -f "$INIT_SRC" ]]; then
  INIT="$INIT_SRC"
  src_mode="fuente ($INIT_SRC)"
else
  INIT="$TMP/init"
  src_mode="extraído"
fi

if [[ -f "$INIT" ]]; then
  head1="$(head -n1 "$INIT" | tr -d '\r')"
  check "shebang #!/bin/busybox sh" "$([[ "$head1" == "#!/bin/busybox sh" ]] && echo 1 || echo 0)" "$head1"
  check "sin set -e" "$(grep -qE '^[[:space:]]*set -e([[:space:]]|$)' "$INIT" && echo 0 || echo 1)" "no debe abortar PID 1"
  check "marca INITRAMFS_REACHED" "$(grep -q 'INITRAMFS_REACHED' "$INIT" && echo 1 || echo 0)" "llegar al final"
  for d in "${DESTRUCTIVE[@]}"; do
    # Solamente líneas de código (que no comiencen por '#') y palabra completa.
    if grep -qE "^[^#]*\b${d}\b" "$INIT"; then
      check "sin '$d'" "0" "no operaciones destructivas"
    fi
  done
  check "sin operaciones destructivas" "1" "reboot/format/mkfs/fsck/dd/flash/erase/fastboot/userdata"
else
  check "init presente" "0" "no se encontró $src_mode"
fi

if [[ -n "$BBROOT" && -x "$BBROOT/bin/busybox" ]]; then
  FB="$(file -b "$BBROOT/bin/busybox")"
  check "busybox aarch64 estático" "$([[ "$FB" == *"ARM aarch64"* && "$FB" == *"static"* ]] && echo 1 || echo 0)" "$FB"
  for a in "${REQUIRED_APPLETS[@]}"; do
    if test -L "$BBROOT/bin/$a" -o -L "$BBROOT/sbin/$a" -o -L "$BBROOT/usr/bin/$a" -o -L "$BBROOT/usr/sbin/$a"; then
      check "applet $a" "1" "enlace presente"
    else
      check "applet $a" "0" "FALTA (EX3: sed ausente)"
    fi
  done
else
  check "árbol busybox-root" "0" "--busybox-root requerido para validar applets"
fi

{
  echo "# Verificación initramfs de diagnóstico (sedfix)"
  echo
  echo "Ramdisk: $(basename "$RAMDISK") ($(stat -c %s "$RAMDISK") bytes)"
  echo "Init: $src_mode"
  echo
  echo "| Comprobación | Resultado | Detalle |"
  echo "|---|---|---|"
  printf '%b' "$report"
  if [[ -n "$fail" ]]; then
    echo
    echo "CONCLUSIÓN: FAIL ($fail)"
  else
    echo
    echo "CONCLUSIÓN: PASS"
  fi
} > "$OUT/initramfs-verification.md"

cat "$OUT/initramfs-verification.md"
if [[ -n "$fail" ]]; then exit 1; fi
exit 0
