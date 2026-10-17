#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# build-pmos-laurel.sh
#
# Construye una imagen postmarketOS edge para Xiaomi Mi A3 (xiaomi-laurel /
# laurel_sprout) con pmbootstrap. Se ejecuta SOLO dentro de GitHub Actions, en
# el contenedor de pmos-build/Dockerfile. NO se ejecuta en local.
#
# Base: recetario probado de philipplinux/mia3-postmarketos
# (simple-install/build.sh), adaptado a:
#   - UI y gestor de servicios configurables (por defecto plasma-mobile+systemd)
#   - overlay opcional de pmaports (parches DTS, k7.dtb, firmware)
#   - firmware propietario opcional extraído del ROM oficial (sin teléfono)
#   - validación de artefactos y manifiesto reproducible
#
# Uso:
#   scripts/build-pmos-laurel.sh --out <dir> [opciones]
#
# Opciones:
#   --out <dir>               Directorio de salida de artefactos (obligatorio)
#   --work <dir>              Directorio de trabajo de pmbootstrap (def /work)
#   --ui <ui>                 Interfaz pmOS (def plasma-mobile)
#   --service-manager <sm>    openrc o systemd (def systemd)
#   --user <u>                Usuario pmOS (def user)
#   --password <p>            Contraseña del usuario (def changeme)
#   --hostname <h>            Hostname del dispositivo (def laurel)
#   --pmaports-commit <sha>   Commit de pmaports (def ec98dddc...)
#   --apply-overlay           Aplica pmaports-overlay/ al árbol de pmaports
#   --with-firmware           Extrae firmware del ROM oficial y lo empaqueta

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OUT=""
WORK="/work"
DEVICE="xiaomi-laurel"
UI="plasma-mobile"
SERVICE_MANAGER="systemd"
KERNEL_PKG="linux-nura-qcom-sm61x5"
DEVICE_PKG="device-xiaomi-laurel"
FIRMWARE_PKG="firmware-xiaomi-laurel-cdsp"
PMAPORTS_COMMIT="ec98dddc8d525c874603a8e91ae6113d2b0c66d1"
PMAPORTS_REMOTE="https://gitlab.postmarketos.org/postmarketOS/pmaports.git"
PMOS_USER="user"
PMOS_HOSTNAME="laurel"
PMOS_PASSWORD="changeme"
APPLY_OVERLAY=0
WITH_FIRMWARE=0

# Firmware propietario: se extrae del ROM oficial (sin teléfono). El hash es el
# prefijo md5 de 10 dígitos hex que Xiaomi codifica en el nombre del fichero.
ROM_URL="https://cdnorg.d.miui.com/V12.0.26.0.RFQMIXM/laurel_sprout_global_images_V12.0.26.0.RFQMIXM_20220808.0000.00_11.0_2292e2c0b1.tgz"
ROM_MD5_PREFIX="2292e2c0b1"

usage() {
  printf 'uso: %s --out <dir> [--work <dir>] [--ui <ui>] [--service-manager <sm>]\n' "$0" >&2
  printf '       [--user <u>] [--password <p>] [--hostname <h>]\n' >&2
  printf '       [--pmaports-commit <sha>] [--apply-overlay] [--with-firmware]\n' >&2
  exit 2
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
say() { printf '\n== %s ==\n' "$*"; }

while (( $# > 0 )); do
  case "$1" in
    --out) OUT="${2:-}"; shift 2 ;;
    --work) WORK="${2:-}"; shift 2 ;;
    --ui) UI="${2:-}"; shift 2 ;;
    --service-manager) SERVICE_MANAGER="${2:-}"; shift 2 ;;
    --user) PMOS_USER="${2:-}"; shift 2 ;;
    --password) PMOS_PASSWORD="${2:-}"; shift 2 ;;
    --hostname) PMOS_HOSTNAME="${2:-}"; shift 2 ;;
    --pmaports-commit) PMAPORTS_COMMIT="${2:-}"; shift 2 ;;
    --apply-overlay) APPLY_OVERLAY=1; shift ;;
    --with-firmware) WITH_FIRMWARE=1; shift ;;
    *) usage ;;
  esac
done

[[ -n "$OUT" ]] || usage
[[ -n "$PMAPORTS_COMMIT" ]] || die "pmaports-commit vacío"

PA="$WORK/pmaports"
PW="$WORK/pmbootstrap"
OUT="${OUT%/}"

# pmbootstrap se niega a correr como root; este script debe ejecutarse como el
# usuario no privilegiado "build".
[[ "$(id -u)" -ne 0 ]] || die "no ejecutes este script como root (pmbootstrap lo rechaza)"

command -v pmbootstrap >/dev/null 2>&1 || die "pmbootstrap no está en PATH"

pmb() { pmbootstrap "$@"; }

prepare_pmaports() {
  say "pmaports @ ${PMAPORTS_COMMIT:0:7}"
  if [[ ! -d "$PA/.git" ]]; then
    git init -q "$PA"
    git -C "$PA" remote add origin "$PMAPORTS_REMOTE"
  fi
  git -C "$PA" fetch -q --depth 1 origin "$PMAPORTS_COMMIT"
  # pmbootstrap lee channels.cfg de origin/main
  git -C "$PA" update-ref refs/remotes/origin/main FETCH_HEAD
  git -C "$PA" checkout -qfB main FETCH_HEAD
  git -C "$PA" clean -qfdx
  printf '[pmaports] HEAD=%s\n' "$(git -C "$PA" rev-parse HEAD)"
}

apply_overlay() {
  say "overlay de pmaports"
  local ov="$REPO_ROOT/pmaports-overlay"
  [[ -d "$ov" ]] || die "falta $ov"
  if [[ -f "$ov/pmaports-ec98ddd.diff" ]]; then
    git -C "$PA" apply "$ov/pmaports-ec98ddd.diff"
    printf '[overlay] diff aplicado\n'
  fi
  if compgen -G "$ov/linux-nura-qcom-sm61x5/*.patch" >/dev/null; then
    cp "$ov"/linux-nura-qcom-sm61x5/*.patch \
      "$PA/device/testing/$KERNEL_PKG/"
    printf '[overlay] parches DTS copiados\n'
  fi
  if [[ -f "$ov/dts/k7.dtb" ]]; then
    cp "$ov/dts/k7.dtb" "$PA/device/testing/$KERNEL_PKG/"
    printf '[overlay] k7.dtb copiado\n'
  fi
  if (( WITH_FIRMWARE == 0 )); then
    # Sin firmware no se puede satisfacer la dependencia del paquete de
    # dispositivo; se elimina la línea para permitir un build base.
    sed -i "/^${FIRMWARE_PKG}\$/d" \
      "$PA/device/testing/$DEVICE_PKG/APKBUILD"
    printf '[overlay] dependencia %s eliminada (build base)\n' "$FIRMWARE_PKG"
  fi
}

fetch_firmware() {
  say "firmware del ROM oficial"
  local c="$WORK/cache"
  mkdir -p "$c"
  local rom="$c/rom.tgz"
  if [[ ! -s "$rom" ]]; then
    printf '[fw] descargando ROM (~2.4 GB)\n'
    curl -fL -C - -o "$rom.part" "$ROM_URL"
    mv "$rom.part" "$rom"
  fi
  local got
  got="$(md5sum < "$rom" | cut -c1-10)"
  [[ "$got" == "$ROM_MD5_PREFIX" ]] || die "md5 del ROM no coincide ($got): borra $rom y reintenta"

  local unpack="$c/rom" fwdir="$c/fw"
  rm -rf "$unpack" "$fwdir"
  mkdir -p "$unpack"
  tar -xzf "$rom" -C "$unpack" --strip-components=2 --wildcards \
    '*/images/NON-HLOS.bin' '*/images/BTFM.bin' '*/images/vendor.img'
  mv "$unpack/NON-HLOS.bin" "$unpack/modem_a"
  mv "$unpack/BTFM.bin" "$unpack/bluetooth_a"
  simg2img "$unpack/vendor.img" "$unpack/vendor_a"
  rm -f "$unpack/vendor.img"

  L="$unpack" FW="$fwdir/fw" sh "$REPO_ROOT/pmaports-overlay/firmware/extract-firmware.sh"

  local fwpkg="$PA/device/testing/$FIRMWARE_PKG"
  rm -rf "$fwpkg"
  cp -r "$REPO_ROOT/pmaports-overlay/firmware-xiaomi-laurel-cdsp" "$fwpkg"
  # El extractor instala en <FW>/...; el APKBUILD espera los blobs en su carpeta.
  find "$fwdir" -type f -exec cp -n {} "$fwpkg/" \;
  printf '[fw] blobs: %s\n' "$(find "$fwpkg" -maxdepth 1 -type f | wc -l)"
}

write_config() {
  say "config de pmbootstrap"
  local cfg_dir="$HOME/.config"
  mkdir -p "$cfg_dir"
  cat > "$cfg_dir/pmbootstrap_v3.cfg" <<EOF
[pmbootstrap]
aports = $PA
work = $PW
device = $DEVICE
ui = $UI
service_manager = $SERVICE_MANAGER
user = $PMOS_USER
hostname = $PMOS_HOSTNAME
locale = en_US.UTF-8
timezone = UTC
ssh_keys = False
EOF
  printf '[cfg] %s\n' "$cfg_dir/pmbootstrap_v3.cfg"
}

run_build() {
  say "pmbootstrap init"
  # La config ya está escrita; los saltos de línea confirman los valores.
  printf '\n%.0s' {1..40} | pmb init >/dev/null

  local pkgs=("$KERNEL_PKG" "$DEVICE_PKG")
  if (( WITH_FIRMWARE == 1 )); then
    pkgs+=("$FIRMWARE_PKG")
  fi
  say "checksum: ${pkgs[*]}"
  pmb checksum "${pkgs[@]}"

  say "build kernel $KERNEL_PKG (30-60 min)"
  pmb build "$KERNEL_PKG"

  say "pmbootstrap install (ui=$UI, $SERVICE_MANAGER)"
  pmb -y install --password "$PMOS_PASSWORD"
  pmb shutdown 2>/dev/null || true
}

export_images() {
  say "exportando imágenes -> $OUT"
  mkdir -p "$OUT"
  local boot="$PW/chroot_rootfs_$DEVICE/boot/boot.img"
  local rootfs="$PW/chroot_native/home/pmos/rootfs/$DEVICE.img"
  [[ -f "$boot" ]] || die "no se generó boot.img ($boot)"
  [[ -f "$rootfs" ]] || die "no se generó rootfs.img ($rootfs)"
  cp "$boot" "$OUT/boot.img"
  cp "$rootfs" "$OUT/rootfs.img"
  avbtool make_vbmeta_image --flags 2 --padding_size 4096 \
    --output "$OUT/vbmeta.img"
  # Un rootfs sin sistemas de ficheros arrancaría al shell de depuración del
  # initramfs; se comprueba que contiene un rootfs real.
  LC_ALL=C grep -qa -m1 -E 'postmarketos|alpine-baselayout' "$OUT/rootfs.img" \
    || die "rootfs.img vacío; no lo flashees"
  ( cd "$OUT" && sha256sum boot.img rootfs.img vbmeta.img > SHA256SUMS )
  ls -la "$OUT"
}

main() {
  say "entorno"
  pmbootstrap --version || true
  uname -a
  df -h "$WORK" || true

  prepare_pmaports
  if (( APPLY_OVERLAY == 1 )); then
    apply_overlay
  fi
  if (( WITH_FIRMWARE == 1 )); then
    fetch_firmware
  fi
  write_config
  run_build
  export_images
  say "build completado"
}

main
