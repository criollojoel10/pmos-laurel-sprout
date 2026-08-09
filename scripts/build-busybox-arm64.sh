#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# build-busybox-arm64.sh
#
# Construye un BusyBox estático para aarch64 (SM6125 / trinket / Snapdragon
# 665) con el toolchain cruzado de Ubuntu (crossbuild-essential-arm64).
# Se ejecuta en GitHub Actions (workflow 04-build-diagnostic-boot.yml).
# NO se ejecuta localmente (AGENTS.md: el trabajo pesado solo en CI).
#
# Antecedente: el paquete busybox-static de Ubuntu es x86-64; el dispositivo
# es aarch64 y el initramfs con ese binario falla con "exec format error".
# Esta build sustituye esa dependencia por un binario arm64 estático.
#
# Uso:
#   scripts/build-busybox-arm64.sh --out <directorio-salida>
#
# El tarball queda fijado por SHA-256 (registrado en sources.lock.json).

set -Eeuo pipefail

VERSION="1.38.0"
URL="https://busybox.net/downloads/busybox-${VERSION}.tar.bz2"
SHA256="34f9ea6ff8636f2c9241153b9114eefa9e65674a45318ae1ef95bb5f31c53bb2"
TARBALL="busybox-${VERSION}.tar.bz2"
CROSS="aarch64-linux-gnu-"
ARCH="arm64"

OUT=""
usage() {
  echo "uso: $0 --out <dir>" >&2
  exit 2
}
while (( $# > 0 )); do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    *) usage ;;
  esac
done
[[ -n "$OUT" ]] || usage
mkdir -p "$OUT"
OUT="$(readlink -f "$OUT")"

info() { printf '[busybox] %s\n' "$*" >&2; }

command -v "${CROSS}gcc" >/dev/null 2>&1 || {
  echo "ERROR: toolchain cruzado no disponible (instala crossbuild-essential-arm64)" >&2
  exit 1
}

WORK="$(mktemp -d /tmp/busybox-build.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

info "descargando $URL"
curl -fsSL "$URL" -o "$WORK/$TARBALL"
( cd "$WORK" && printf '%s  %s\n' "$SHA256" "$TARBALL" > SHA256SUMS && sha256sum -c SHA256SUMS )

info "extrayendo"
tar -xjf "$WORK/$TARBALL" -C "$WORK"
cd "$WORK/busybox-${VERSION}"

info "configurando (ARCH=$ARCH CROSS=$CROSS, estático)"
make ARCH="$ARCH" CROSS_COMPILE="$CROSS" defconfig >/dev/null
sed -i 's/^# CONFIG_STATIC is not set$/CONFIG_STATIC=y/' .config
# El applet tc (networking/tc.c) usa constantes CBQ (TCA_CBQ_*) que ya no
# existen en los headers de linux del runner (kernel >= 6.13 las eliminó).
# El initramfs de diagnóstico no necesita tc, así que lo deshabilitamos.
sed -i 's/^CONFIG_TC=y$/# CONFIG_TC is not set/' .config
# sed es un requisito del initramfs de diagnóstico (/init usa 'mount | sed').
# En defconfig ya suele estar habilitado; lo fijamos explícitamente para que
# cualquier futuro cambio de config no lo desactive silenciosamente.
if ! grep -q '^CONFIG_SED=y$' .config; then
  sed -i 's/^# CONFIG_SED is not set$/CONFIG_SED=y/' .config
fi
# En caso de estar presente el símbolo FEATURE_SED_REGEX_LIBC lo dejamos en y
# (cualquiera que sea su forma actual en el .config).
if grep -q 'CONFIG_FEATURE_SED_REGEX_LIBC' .config; then
  sed -i 's/^CONFIG_FEATURE_SED_REGEX_LIBC=n$/# CONFIG_FEATURE_SED_REGEX_LIBC is not set/' .config
  sed -i 's/^# CONFIG_FEATURE_SED_REGEX_LIBC is not set$/CONFIG_FEATURE_SED_REGEX_LIBC=y/' .config
fi
# oldconfig reconciliar dependencias tras los cambios manuales en .config.
# OJO: busybox 1.38 (kconfig heredado del kernel ~2.6.30) NO tiene el target
# 'olddefconfig' (añadido al kernel en 3.5); 'silentoldconfig' con stdin vacío
# es el equivalente no interactivo y SÍ existe aquí.
make ARCH="$ARCH" CROSS_COMPILE="$CROSS" silentoldconfig </dev/null >/dev/null
grep -q '^CONFIG_STATIC=y$' .config || { echo "ERROR: no se pudo habilitar CONFIG_STATIC" >&2; exit 1; }
grep -q '^# CONFIG_TC is not set$' .config || { echo "ERROR: no se pudo deshabilitar CONFIG_TC" >&2; exit 1; }
grep -q '^CONFIG_SED=y$' .config || { echo "ERROR: no se pudo habilitar CONFIG_SED" >&2; exit 1; }

info "compilando (puede tardar 1-2 min)"
# Volcamos TODO el log de make a un archivo y, si falla, mostramos las
# últimas 60 líneas en stderr (sin truncar con pipe, para no perder el error).
RC=0
make -j"$(nproc)" ARCH="$ARCH" CROSS_COMPILE="$CROSS" busybox >"$WORK/make.log" 2>&1 || RC=$?
if (( RC != 0 )); then
  cp "$WORK/make.log" "$OUT/make.log" 2>/dev/null || true
  echo "ERROR: make falló (código $RC). Log completo: $OUT/make.log" >&2
  tail -n 60 "$WORK/make.log" >&2
  exit 1
fi
tail -n 8 "$WORK/make.log"

BB="$WORK/busybox-${VERSION}/busybox"
[[ -f "$BB" ]] || { echo "ERROR: no se generó el binario busybox" >&2; exit 1; }
FB="$(file -b "$BB")"
info "archivo generado: $FB"
[[ "$FB" == *"ARM aarch64"* ]] || { echo "ERROR: el binario NO es aarch64: $FB" >&2; exit 1; }
[[ "$FB" == *"static"* ]] || { echo "ERROR: el binario NO es estático: $FB" >&2; exit 1; }

# Instalar el árbol completo de applets (bin/sbin/usr/bin/usr/sbin) con
# `make CONFIG_PREFIX install`: busybox instala busybox + los enlaces de cada
# applet compilado. Antes el initramfs creaba SOLO una lista fija de enlaces y
# /init fallaba por falta de 'sed' (Kernel panic: Attempted to kill init).
APPS="$OUT/applet-root"
mkdir -p "$APPS"
info "instalando árbol de applets (CONFIG_PREFIX=$APPS)"
make -j"$(nproc)" ARCH="$ARCH" CROSS_COMPILE="$CROSS" CONFIG_PREFIX="$APPS" install >"$WORK/install.log" 2>&1 || {
  cp "$WORK/install.log" "$OUT/install.log" 2>/dev/null || true
  echo "ERROR: make install falló. Log: $OUT/install.log" >&2
  tail -n 60 "$WORK/install.log" >&2
  exit 1
}

# El instalador de busybox crea enlaces a "busybox" (relativo) dentro del
# árbol. Verificar que busybox quedó instalado y que sed existe como enlace.
[[ -x "$APPS/bin/busybox" ]] || { echo "ERROR: no se instaló $APPS/bin/busybox" >&2; exit 1; }
[[ -L "$APPS/bin/sed" ]] || { echo "ERROR: falta el enlace bin/sed en el árbol de applets" >&2; exit 1; }

# Lista los applets instalados (nombres de enlace) para auditoría.
( cd "$APPS" && find bin sbin usr -maxdepth 1 -type l -printf '%f\n' 2>/dev/null | sort -u ) > "$OUT/applets.txt"
info "applets instalados: $(wc -l < "$OUT/applets.txt")"

# Validar los applets que /init y la shell de rescate requieren.
REQUIRED=(sh cat sed grep awk mount umount mkdir mknod sleep dmesg uptime ls cp sync switch_root)
for a in "${REQUIRED[@]}"; do
  grep -qx "$a" "$OUT/applets.txt" || {
    echo "ERROR: falta el applet requerido '$a' en el árbol instalado" >&2
    exit 1
  }
done

cp "$BB" "$OUT/busybox"
sha256sum "$OUT/busybox" > "$OUT/busybox.SHA256"
info "salida: $OUT/busybox (+ árbol de applets en $APPS)"
cat "$OUT/busybox.SHA256"
cat "$OUT/applets.txt"
exit 0
