#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Verificacion de hardware/servicios de Kupfer en el Xiaomi Mi A3 (laurel_sprout).
#
# Uso (en el telefono, como root o con sudo):
#   sh scripts/verify-kupfer-laurel.sh
#
# No modifica nada: solo lee. Los estados "FALLA" son los que rompen la
# experiencia minima (arranque A/B, pantalla, GPU, bateria, Wi-Fi); "AVISO"
# indica algo opcional o que puede tardar en aparecer tras el arranque.
set -u
fails=0
warns=0

ok()   { printf '  OK    %s\n' "$1"; }
warn() { warns=$((warns + 1)); printf '  AVISO %s\n' "$1"; }
bad()  { fails=$((fails + 1)); printf '  FALLA %s\n' "$1"; }

section() { printf '\n== %s ==\n' "$1"; }

section "sistema"
echo "kernel: $(uname -r)"
echo "modelo: $(tr -d '\0' </proc/device-tree/model 2>/dev/null || echo desconocido)"
if [ "$(id -u)" -ne 0 ]; then
	echo "nota: ejecutado sin root; algunas lecturas pueden faltar"
fi

section "arranque A/B (qbootctl)"
if command -v qbootctl >/dev/null 2>&1; then
	# qbootctl necesita root para leer misc; sin permisos se usa el
	# resultado del oneshot del arranque (Result=success).
	if out=$(sudo -n qbootctl 2>/dev/null) && [ -n "$out" ]; then
		echo "$out" | sed 's/^/  /'
		if echo "$out" | grep -q 'Successful: *1'; then
			ok "slot actual marcado successful"
		else
			bad "slot no marcado successful (revisa qbootctl.service)"
		fi
	else
		res=$(systemctl show -p Result --value qbootctl.service 2>/dev/null || true)
		if [ "$res" = "success" ]; then
			ok "qbootctl ejecutado en el arranque (sin permisos para leer misc)"
		else
			warn "no se pudo leer el slot (Result=${res:-desconocido})"
		fi
	fi
else
	bad "qbootctl no instalado"
fi

section "unidades"
if command -v systemctl >/dev/null 2>&1; then
	failed=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
	if [ "$failed" -eq 0 ]; then
		ok "0 unidades fallidas"
	else
		bad "$failed unidades fallidas"
	fi
	for u in qbootctl mia3-qg mia3-audio mia3-wifi chargectl; do
		st=$(systemctl is-active "$u.service" 2>/dev/null || true)
		res=$(systemctl show -p Result --value "$u.service" 2>/dev/null || true)
		case "$st" in
			active) ok "$u activo" ;;
			*) if [ "$res" = "success" ]; then
				ok "$u completado (oneshot)"
			else
				warn "$u = ${st:-desconocido} (Result=${res:-?})"
			fi ;;
		esac
	done
fi

section "pantalla y tactil"
for c in /sys/class/drm/card*-DSI-1; do
	[ -e "$c/status" ] || continue
	echo "  $c: $(cat "$c/status")"
	if grep -q connected "$c/status"; then
		ok "conector DSI activo"
	fi
done
if [ -e /dev/fb0 ]; then
	ok "/dev/fb0 presente"
else
	warn "/dev/fb0 ausente (normal con DRM/KMS)"
fi
if [ -d /sys/class/input ]; then
	events=$(find /sys/class/input -maxdepth 1 -name 'event*' 2>/dev/null | wc -l)
	if [ "$events" -gt 0 ]; then
		ok "$events dispositivos input"
	else
		bad "sin /dev/input/event*"
	fi
fi

section "GPU (Adreno 610)"
if [ -e /dev/dri/renderD128 ]; then
	ok "/dev/dri/renderD128 presente"
else
	bad "sin renderD128 (GPU no inicializo)"
fi
if command -v glxinfo >/dev/null 2>&1 && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
	renderer=$(glxinfo -B 2>/dev/null | sed -n 's/.*OpenGL renderer string: *//p' | head -n1)
	[ -n "$renderer" ] && echo "  renderer: $renderer"
	case "$renderer" in
		*llvmpipe*|"") warn "renderer por CPU ($renderer)" ;;
		*) ok "renderer por GPU" ;;
	esac
fi

section "bateria (PMI632)"
if [ -r /sys/class/power_supply/mia3-qg/capacity ]; then
	echo "  capacidad: $(cat /sys/class/power_supply/mia3-qg/capacity)%"
	echo "  voltaje:   $(cat /sys/class/power_supply/mia3-qg/voltage_now 2>/dev/null) uV"
	echo "  corriente: $(cat /sys/class/power_supply/mia3-qg/current_now 2>/dev/null) uA"
	ok "fuel gauge mia3-qg"
else
	bad "sin /sys/class/power_supply/mia3-qg (overlay o modulo)"
fi

section "Wi-Fi (WCN3990)"
if [ -e /sys/class/net/wlan0 ]; then
	ok "wlan0 existe"
	ip -br addr show wlan0 2>/dev/null | sed 's/^/  /'
	command -v nmcli >/dev/null 2>&1 && nmcli -t -f GENERAL.STATE device show wlan0 2>/dev/null | sed 's/^/  /'
else
	bad "wlan0 no existe"
	command -v systemctl >/dev/null 2>&1 && \
		echo "  pista: journalctl -u mia3-wifi -b ; dmesg | grep -iE 'ath10k|wcn3990|remoteproc'"
fi

section "audio (altavoz inferior)"
if [ -r /proc/asound/cards ] && grep -q 'Mi-A3' /proc/asound/cards; then
	ok "tarjeta Mi-A3 presente"
	grep -A1 'Mi-A3' /proc/asound/cards | sed 's/^/  /'
else
	warn "tarjeta Mi-A3 ausente"
	command -v systemctl >/dev/null 2>&1 && \
		echo "  pista: journalctl -u mia3-audio -b ; dmesg | grep -iE 'adsp|q6|apr'"
fi

section "firmware clave"
for f in \
	qcom/a630_sqe.fw \
	qcom/sm6125/xiaomi/laurel/a610_zap.mbn \
	qcom/sm6125/xiaomi/laurel/wlanmdsp.mbn \
	qcom/sm6125/xiaomi/laurel/adsp.mdt \
	mia3-qg.dtbo mia3-adsp.dtbo mia3-apr.dtbo mia3-speaker.dtbo
do
	if [ -e "/usr/lib/firmware/$f" ]; then
		ok "$f"
	else
		bad "falta $f"
	fi
done

printf '\n== resumen ==\n'
echo "fallas: $fails | avisos: $warns"
[ "$fails" -eq 0 ]
