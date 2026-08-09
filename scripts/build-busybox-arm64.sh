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
# Applets que /init y la shell de rescate necesitan en tiempo de ejecución.
# Forzamos su símbolo Kconfig a 'y' en el .config ANTES de silentoldconfig:
# defconfig suele habilitarlos, pero no queremos depender de que lo haga
# (el run 31328942346 construyó un busybox SIN el applet awk). La clave del
# array es el nombre de applet; el valor es el sufijo de su símbolo CONFIG_*.
declare -A APP_SYM=(
  [sh]=ASH [cat]=CAT [sed]=SED [grep]=GREP [awk]=AWK [mount]=MOUNT
  [umount]=UMOUNT [mkdir]=MKDIR [mknod]=MKNOD [sleep]=SLEEP
  [dmesg]=DMESG [uptime]=UPTIME [ls]=LS [cp]=CP [sync]=SYNC
  [switch_root]=SWITCH_ROOT [tr]=TR [wc]=WC [setsid]=SETSID
  [echo]=ECHO [test]=TEST [uname]=UNAME [chmod]=CHMOD [ln]=LN
  [mv]=MV [rm]=RM [touch]=TOUCH [head]=HEAD [tail]=TAIL
)
for a in "${!APP_SYM[@]}"; do
  sym="CONFIG_${APP_SYM[$a]}"
  if grep -q "^# ${sym} is not set$" .config; then
    sed -i "s/^# ${sym} is not set$/${sym}=y/" .config
  elif ! grep -q "^${sym}=y$" .config; then
    printf '%s=y\n' "$sym" >> .config
  fi
done
# silentoldconfig reconcilia dependencias tras los cambios manuales en
# .config. OJO: busybox 1.38 (kconfig heredado del kernel ~2.6.30) NO tiene el
# target 'olddefconfig' (añadido al kernel en 3.5); 'silentoldconfig' con
# stdin vacío es el equivalente no interactivo y SÍ existe aquí.
make ARCH="$ARCH" CROSS_COMPILE="$CROSS" silentoldconfig </dev/null >/dev/null
grep -q '^CONFIG_STATIC=y$' .config || { echo "ERROR: no se pudo habilitar CONFIG_STATIC" >&2; exit 1; }
grep -q '^# CONFIG_TC is not set$' .config || { echo "ERROR: no se pudo deshabilitar CONFIG_TC" >&2; exit 1; }
grep -q '^CONFIG_SED=y$' .config || { echo "ERROR: no se pudo habilitar CONFIG_SED" >&2; exit 1; }
for a in "${!APP_SYM[@]}"; do
  sym="CONFIG_${APP_SYM[$a]}"
  grep -q "^${sym}=y$" .config || {
    echo "ERROR: no se pudo habilitar ${sym} (applet '$a')" >&2
    exit 1
  }
done

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

# Instalar el árbol completo de applets (bin/sbin/usr/bin/usr/sbin) generando
# los enlaces desde busybox.links en lugar de `make install`. busybox.links es
# generado por el propio build (applets/busybox.mkll) y lista UNA ruta por
# applet EFECTIVAMENTE compilado; si un applet no está en busybox.links es que
# NO se compiló (el run 31328942346 instaló 164 applets SIN awk: awk no estaba
# en el .config, así que tampoco estaba en busybox.links). 'make install'
# depende del mismo archivo y además crea enlaces relativos; aquí creamos
# enlaces absolutos a /bin/busybox y validamos los REQUIRED directamente
# contra busybox.links. Antes el initramfs creaba SOLO una lista fija de
# enlaces y /init fallaba por falta de 'sed' (Kernel panic: Attempted to kill
# init).
APPS="$OUT/applet-root"
mkdir -p "$APPS/bin"
info "generando lista de enlaces (busybox.links)"
make ARCH="$ARCH" CROSS_COMPILE="$CROSS" busybox.links >"$WORK/links.log" 2>&1 || {
  cp "$WORK/links.log" "$OUT/links.log" 2>/dev/null || true
  echo "ERROR: make busybox.links falló. Log: $OUT/links.log" >&2
  tail -n 30 "$WORK/links.log" >&2
  exit 1
}
[[ -s busybox.links ]] || { echo "ERROR: busybox.links está vacío (¿falló el preprocesado?)" >&2; exit 1; }
cp busybox.links "$OUT/busybox.links"

# Validar ANTES de crear enlaces que cada applet requerido aparece en
# busybox.links; su presencia garantiza que quedó compilado en el binario.
REQUIRED=(sh cat sed grep awk mount umount mkdir mknod sleep dmesg uptime ls cp sync switch_root)
for a in "${REQUIRED[@]}"; do
  grep -Eq "/${a}$" busybox.links || {
    echo "ERROR: busybox.links no incluye el applet requerido '$a' (no se compiló)" >&2
    exit 1
  }
done

info "copiando busybox a $APPS/bin/busybox"
install -m 755 "$BB" "$APPS/bin/busybox"
while IFS= read -r l; do
  [[ "$l" == /* ]] || { echo "ERROR: ruta inesperada en busybox.links: '$l'" >&2; exit 1; }
  mkdir -p "$APPS${l%/*}"
  ln -sfn /bin/busybox "$APPS$l"
done < <(sort -u busybox.links)

# Verificar que busybox quedó instalado y que cada ruta de busybox.links tiene
# su enlace en el árbol. OJO: la auditoría anterior usaba 'find bin sbin usr
# -maxdepth 1', que NO veía los enlaces en usr/bin y usr/sbin (profundidad 2) y
# reportaba falsamente que faltaba 'awk' (p. ej. /usr/bin/awk) aunque el enlace
# SÍ existiera.
[[ -x "$APPS/bin/busybox" ]] || { echo "ERROR: no se instaló $APPS/bin/busybox" >&2; exit 1; }
while IFS= read -r l; do
  [[ -L "$APPS$l" ]] || { echo "ERROR: falta el enlace $APPS$l (de busybox.links)" >&2; exit 1; }
done < <(sort -u busybox.links)

# Lista los applets instalados (nombres de enlace) para auditoría. Se deriva de
# busybox.links: cada ruta genera un enlace (verificado arriba), así que es
# equivalente al árbol real y no depende de la profundidad del find.
sed 's@.*/@@' busybox.links | sort -u > "$OUT/applets.txt"
info "applets instalados: $(wc -l < "$OUT/applets.txt")"

# Validar los applets que /init y la shell de rescate requieren.
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
