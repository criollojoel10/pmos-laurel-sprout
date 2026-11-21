#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Descarga un artefacto de GitHub Actions con aria2c (multi-conexion) y valida
# los SHA256. Pensado para el PC con fastboot, no para el telefono.
#
# Uso:
#   scripts/download-kupfer-artifact.sh [run-id] [artefacto] [destino]
#
# Por defecto descarga el artefacto verde del 2026-11-21.
set -eu

REPO="criollojoel10/pmos-laurel-sprout"
RUN_ID="${1:-44848808710}"
ARTIFACT="${2:-kupfer-laurel-phosh}"
DEST="${3:-kupfer-laurel-$RUN_ID}"

for c in gh curl aria2c unzip sha256sum; do
	if ! command -v "$c" >/dev/null 2>&1; then
		echo "falta $c (Arch: pacman -S github-cli aria2 unzip coreutils)" >&2
		exit 1
	fi
done

ID=$(gh api "repos/$REPO/actions/runs/$RUN_ID/artifacts" \
	--jq ".artifacts[] | select(.name==\"$ARTIFACT\") | .id")
if [ -z "$ID" ]; then
	echo "artefacto '$ARTIFACT' no encontrado en el run $RUN_ID" >&2
	exit 1
fi

URL=$(curl -s -o /dev/null -w '%{redirect_url}' \
	-H "Authorization: Bearer $(gh auth token)" \
	-H 'Accept: application/vnd.github+json' \
	"https://api.github.com/repos/$REPO/actions/artifacts/$ID/zip")
if [ -z "$URL" ]; then
	echo "no se pudo obtener la URL firmada del artefacto" >&2
	exit 1
fi

mkdir -p "$DEST"
echo "descargando $ARTIFACT (id $ID) con aria2c..."
aria2c -x16 -s16 -k1M --file-allocation=none \
	-d "$DEST" -o "$ARTIFACT.zip" "$URL"
unzip -q -o "$DEST/$ARTIFACT.zip" -d "$DEST"
if [ -f "$DEST/SHA256SUMS" ]; then
	( cd "$DEST" && sha256sum -c SHA256SUMS )
fi
echo "listo en $DEST"
