#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Muestra y reinicia el contador de intentos fallidos (pam_faillock) de un
# usuario. Ejecutar EN LAUREL como root (o con sudo).
#
# Uso:
#   sudo scripts/reset-faillock-laurel.sh [usuario]
set -eu

USER_NAME="${1:-user}"

if [ "$(id -u)" -ne 0 ]; then
	echo "ejecuta este script con sudo/root" >&2
	exit 1
fi
if ! command -v faillock >/dev/null 2>&1; then
	echo "faillock no esta instalado (paquete pam)" >&2
	exit 1
fi

echo "== estado actual de $USER_NAME =="
faillock --user "$USER_NAME" || true
echo "== reiniciando contador =="
faillock --user "$USER_NAME" --reset
echo "== configuracion efectiva =="
if [ -r /etc/security/faillock.conf ]; then
	grep -vE '^[[:space:]]*(#|$)' /etc/security/faillock.conf || true
fi
echo "listo: $USER_NAME puede volver a intentar el login"
