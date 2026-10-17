#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# validate-pmos-laurel.sh
#
# Valida los artefactos producidos por build-pmos-laurel.sh (boot.img,
# rootfs.img, vbmeta.img) y el árbol de pmbootstrap. Se ejecuta SOLO en GitHub
# Actions, dentro del contenedor de pmos-build/Dockerfile.
#
# Uso:
#   scripts/validate-pmos-laurel.sh --out <dir> [--work <dir>]

set -Eeuo pipefail

OUT=""
WORK="/work"

usage() {
  printf 'uso: %s --out <dir> [--work <dir>]\n' "$0" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --out) OUT="${2:-}"; shift 2 ;;
    --work) WORK="${2:-}"; shift 2 ;;
    *) usage ;;
  esac
done
[[ -n "$OUT" ]] || usage

FAIL=0
ok() { printf '[OK]    %s\n' "$*"; }
bad() { printf '[FALLO] %s\n' "$*" >&2; FAIL=1; }
info() { printf '[info]  %s\n' "$*"; }

# 1. Ficheros presentes
for f in boot.img rootfs.img vbmeta.img SHA256SUMS; do
  if [[ -f "$OUT/$f" ]]; then ok "existe $f ($(du -h "$OUT/$f" | cut -f1))"
  else bad "falta $OUT/$f"; fi
done
[[ "$FAIL" -eq 0 ]] || { printf '\nvalidación abortada: faltan artefactos\n' >&2; exit 1; }

# 2. Integridad
if ( cd "$OUT" && sha256sum -c SHA256SUMS >/dev/null ); then
  ok "SHA256SUMS verificado"
else
  bad "SHA256SUMS no verifica"
fi

# 3. boot.img: cabecera y contenido
TMP="$(mktemp -d)"
if unpack_bootimg --boot_img "$OUT/boot.img" --out "$TMP" >"$TMP/header.txt" 2>&1; then
  ok "unpack_bootimg correcto"
  grep -Ei 'header version|page size|kernel size|ramdisk size|dtb' "$TMP/header.txt" | sed 's/^/[boot]  /' || true
  [[ -s "$TMP/kernel" ]] || bad "boot.img sin kernel"
  [[ -s "$TMP/ramdisk" ]] || bad "boot.img sin ramdisk"
  # DTB añadido (deviceinfo_append_dtb): buscar la firma FDT en el kernel.
  if python3 - "$TMP/kernel" <<'PY'
import sys
d = open(sys.argv[1], "rb").read()
sys.exit(0 if b"\xd0\x0d\xfe\xed" in d else 1)
PY
  then ok "DTB añadido presente en boot.img"
  else info "no se detectó DTB en el kernel (deviceinfo_append_dtb puede estar off)"; fi
else
  bad "unpack_bootimg falló sobre boot.img"
fi

# 4. rootfs.img: rootfs real
RSZ="$(stat -c %s "$OUT/rootfs.img")"
if (( RSZ > 200000000 )); then ok "rootfs.img ${RSZ} bytes"
else bad "rootfs.img demasiado pequeño ($RSZ bytes)"; fi
if LC_ALL=C grep -qa -m1 -E 'postmarketos|alpine-baselayout' "$OUT/rootfs.img"; then
  ok "rootfs.img contiene un rootfs postmarketOS/Alpine"
else
  bad "rootfs.img sin marcadores de rootfs"
fi

# 5. Contenido del rootfs montado (si es posible): UI y systemd
DB="$WORK/pmbootstrap/chroot_rootfs_xiaomi-laurel/lib/apk/db/installed"
if [[ -f "$DB" ]]; then
  for p in postmarketos-base plasma-mobile postmarketos-base-systemd; do
    if grep -q "^P:$p\$" "$DB"; then ok "paquete presente: $p"
    else info "paquete no encontrado en el db apk: $p"; fi
  done
else
  info "sin db apk en el chroot ($DB); se omite comprobación de paquetes"
fi

# 6. Kernel: DTB de laurel
KD="$(find "$WORK/pmbootstrap/chroot_rootfs_xiaomi-laurel" -name 'sm6125-xiaomi-laurel-sprout*' 2>/dev/null | head -n1 || true)"
if [[ -n "$KD" ]]; then ok "DTB de laurel: $KD"
else info "no se encontró el DTB en el chroot (puede venir solo en boot.img)"; fi

rm -rf "$TMP"

if (( FAIL == 0 )); then
  printf '\nVALIDACION OK\n'
else
  printf '\nVALIDACION CON FALLOS\n' >&2
fi
exit "$FAIL"
