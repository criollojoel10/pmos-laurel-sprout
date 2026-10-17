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
EXTRA_PACKAGES="openssh"
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
  if [[ -f "$ov/dts/k7.dts" ]]; then
    local kdir="$PA/device/testing/$KERNEL_PKG"
    local apk="$kdir/APKBUILD"
    # k7.dtb no se versiona (*.dtb, *.dtbo y *.bin están en la lista negra de
    # scripts/audit-public-repository.sh): se compila aquí desde k7.dts con dtc.
    dtc -q -I dts -O dtb -o "$kdir/k7.dtb" "$ov/dts/k7.dts"
    [[ -s "$kdir/k7.dtb" ]] || die "dtc no generó k7.dtb"
    # Añadir k7.dtb a source y sustituir el DTB de laurel que instala el kernel,
    # para que boot.img lleve el de k7 (cpufreq, BT, IR, Wi-Fi).
    awk '/^\tconfig-\$_flavor\.aarch64$/ {print; print "\tk7.dtb"; next} {print}' \
      "$apk" > "$apk.step1"
    awk '/^\trm -f "\$pkgdir"\/usr\/lib\/modules/ {print; print "\tinstall -Dm644 \"\$srcdir/k7.dtb\" \"\$pkgdir/boot/dtbs/qcom/sm6125-xiaomi-laurel-sprout.dtb\""; next} {print}' \
      "$apk.step1" > "$apk.step2"
    mv "$apk.step2" "$apk"
    rm -f "$apk.step1"
    grep -q 'k7.dtb' "$apk" || die "no se pudo añadir k7.dtb al APKBUILD del kernel"
    grep -q 'sm6125-xiaomi-laurel-sprout.dtb' "$apk" \
      || die "no se pudo sustituir el DTB de laurel"
    printf '[overlay] k7.dtb compilado (%s bytes) y enganchado al kernel\n' \
      "$(stat -c %s "$kdir/k7.dtb")"
  fi
  if (( WITH_FIRMWARE == 0 )); then
    # Sin firmware no se puede satisfacer la dependencia del paquete de
    # dispositivo; se elimina la línea para permitir un build base.
    sed -i "/^${FIRMWARE_PKG}\$/d" \
      "$PA/device/testing/$DEVICE_PKG/APKBUILD"
    printf '[overlay] dependencia %s eliminada (build base)\n' "$FIRMWARE_PKG"
  fi
}

patch_device_package() {
  say "deviceinfo: habilitar DRM"
  local di="$PA/device/testing/$DEVICE_PKG/deviceinfo"
  local apk="$PA/device/testing/$DEVICE_PKG/APKBUILD"
  [[ -f "$di" ]] || die "no existe $di"
  # pmbootstrap esconde las UIs con opción pmb:drm / pmb:gpu-accel cuando el
  # deviceinfo no declara deviceinfo_drm (pmb/config/init.py): sin esto,
  # plasma-mobile ni siquiera aparece y init cae a console. El msm DRM del
  # kernel nura 7.2.3 sí funciona, así que declararlo es correcto.
  if ! grep -q '^deviceinfo_drm=' "$di"; then
    printf '\ndeviceinfo_drm="true"\n' >> "$di"
    printf '[device] deviceinfo_drm="true" añadido\n'
  fi
  # El paquete de device se construye siempre en local; un pkgrel distinto del
  # de pmaports/repo binario garantiza que apk elija el nuestro.
  sed -i 's/^pkgrel=[0-9]\+$/pkgrel=9/' "$apk"
  grep -q '^pkgrel=9$' "$apk" || die "no se pudo fijar pkgrel del device"
  printf '[device] pkgrel=9 (build local)\n'
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

  sudo -n env L="$unpack" FW="$fwdir/fw" \
    sh "$REPO_ROOT/pmaports-overlay/firmware/extract-firmware.sh"
  sudo -n chown -R "$(id -u):$(id -g)" "$fwdir"

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
extra_packages = $EXTRA_PACKAGES
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

  # El device se parchea siempre (deviceinfo_drm + pkgrel), así que se compila
  # en local. El kernel solo se fuerza si el overlay cambia sus fuentes; sin
  # overlay el prebuilt del repo de pmOS es equivalente y ahorra ~30 min.
  if (( APPLY_OVERLAY == 1 )); then
    say "build kernel $KERNEL_PKG --force (overlay aplicado)"
    pmb build --force "$KERNEL_PKG"
  else
    say "kernel $KERNEL_PKG (prebuilt del repo de pmOS si está disponible)"
    pmb build "$KERNEL_PKG"
  fi
  say "build device $DEVICE_PKG --force (deviceinfo parcheado)"
  pmb build --force "$DEVICE_PKG"

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
  {
    printf 'device=%s\n' "$DEVICE"
    printf 'ui=%s\n' "$UI"
    printf 'service_manager=%s\n' "$SERVICE_MANAGER"
    printf 'pmos_user=%s\n' "$PMOS_USER"
    printf 'pmaports_commit=%s\n' "$PMAPORTS_COMMIT"
    printf 'kernel_pkg=%s\n' "$KERNEL_PKG"
    printf 'apply_overlay=%s\n' "$APPLY_OVERLAY"
    printf 'with_firmware=%s\n' "$WITH_FIRMWARE"
    printf 'pmbootstrap=%s\n' "$(pmbootstrap --version 2>/dev/null || echo desconocido)"
    printf 'built_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'boot_img_bytes=%s\n' "$(stat -c %s "$OUT/boot.img")"
    printf 'rootfs_img_bytes=%s\n' "$(stat -c %s "$OUT/rootfs.img")"
    printf 'boot_img_sha256=%s\n' "$(sha256sum "$OUT/boot.img" | cut -d' ' -f1)"
    printf 'rootfs_img_sha256=%s\n' "$(sha256sum "$OUT/rootfs.img" | cut -d' ' -f1)"
  } > "$OUT/manifest.txt"
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
  patch_device_package
  if (( WITH_FIRMWARE == 1 )); then
    # El firmware entra en la imagen por la dependencia que añade el overlay.
    (( APPLY_OVERLAY == 1 )) || die "--with-firmware requiere --apply-overlay"
    EXTRA_PACKAGES="$EXTRA_PACKAGES,linux-firmware-ath10k,firmware-qcom-adreno-a630-sqe"
    fetch_firmware
  fi
  write_config
  run_build
  export_images
  say "build completado"
}

main
