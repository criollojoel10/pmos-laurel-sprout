#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Construye fastboot 30.0.5 nativo para aarch64 desde nmeum/android-tools.
#
# El ABL del Mi A3 (laurel_sprout) es el que mejor se lleva con el cliente
# 30.0.5; los clientes 33/37 fallan con "unknown command" en `fastboot boot`
# (que este bootloader no soporta de todos modos). Para flashear se usa este.
#
# Uso:
#   scripts/build-fastboot-30.0.5.sh [directorio-destino]
#
# Dependencias (Arch ARM): cmake go perl libusb pcre2 zlib gcc
set -eu

VERSION=30.0.5
SHA256=1b870a3f28d75e4907c95dbe8e71b4014f56be636d089a75257ef3922ad39d62
WORK="${WORK:-$HOME/.cache/fastboot-$VERSION}"
DEST="${1:-/usr/local/bin}"
TARBALL="android-tools-$VERSION.tar.xz"
URL="https://github.com/nmeum/android-tools/releases/download/$VERSION/$TARBALL"

for c in curl tar cmake make cc c++ go perl pkg-config; do
	if ! command -v "$c" >/dev/null 2>&1; then
		echo "falta $c; instala las dependencias (cmake go perl libusb pcre2)" >&2
		exit 1
	fi
done

mkdir -p "$WORK"
cd "$WORK"
if [ ! -f "$TARBALL" ]; then
	echo "descargando $TARBALL"
	curl -fL -o "$TARBALL" "$URL"
fi
printf '%s  %s\n' "$SHA256" "$TARBALL" | sha256sum -c -

rm -rf "android-tools-$VERSION"
tar -xf "$TARBALL"
cd "android-tools-$VERSION"

# Compatibilidad con GCC/CMake modernos (parches idempotentes; no cambian
# comportamiento, solo permiten compilar el codigo de 2021 hoy).
if grep -q 'set(C_CXX_FLAGS "-Werror ' vendor/boringssl/CMakeLists.txt; then
	sed -i 's/set(C_CXX_FLAGS "-Werror /set(C_CXX_FLAGS "/' \
		vendor/boringssl/CMakeLists.txt
fi
if ! grep -q '#include <cstdint>' \
	vendor/libziparchive/include/ziparchive/zip_writer.h; then
	sed -i 's/#include <cstdio>/#include <cstdint>\n#include <cstdio>/' \
		vendor/libziparchive/include/ziparchive/zip_writer.h
fi
if ! grep -q '#include <algorithm>' vendor/core/fs_mgr/liblp/utility.cpp; then
	sed -i 's/#include <map>/#include <algorithm>\n#include <map>/' \
		vendor/core/fs_mgr/liblp/utility.cpp
fi

cmake -S . -B build -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build build --target fastboot -j"$(nproc)"

install -m755 build/vendor/fastboot "$DEST/fastboot-$VERSION"
ln -sf "fastboot-$VERSION" "$DEST/fastboot"
"$DEST/fastboot-$VERSION" --version
