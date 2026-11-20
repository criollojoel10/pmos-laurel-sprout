#!/bin/sh
# Mi A3 (laurel_sprout) speaker bring-up: Q6 ADSP + APR + MAX98937.
#
# Adaptado de philipplinux/mia3-postmarketos (GPL-2.0), audio/bringup.sh
# (probado en hardware el 2026-10-13). Cambios para Kupfer:
#   - los modulos viven en /usr/lib/modules (los empaqueta linux-sm61x5), no en
#     este directorio: se cargan con modprobe, no con insmod;
#   - el codec dummy "linux,spdif-dit" es snd-soc-spdif del propio kernel;
#   - idempotente: si la tarjeta Mi-A3 ya existe, no vuelve a aplicar overlays
#     (un overlay solo se puede aplicar una vez por arranque).
#
# Necesita en /lib/firmware: mia3-adsp.dtbo, mia3-apr.dtbo, mia3-speaker.dtbo
# (los instala mia3-support). Orden obligatorio; reboot para deshacer.
set -e
P=${P:-/usr/local/lib/mia3-audio}
A=/soc@0/remoteproc@ab00000/glink-edge/apr
log() { echo "mia3-audio: $*"; }

if grep -q 'Mi-A3' /proc/asound/cards 2>/dev/null; then
	log "la tarjeta Mi-A3 ya existe; nada que hacer"
	exit 0
fi


# 1) ADSP remoteproc + smp2p (overlay de mia3_adsp.ko)
modprobe mia3_adsp || { log "mia3_adsp no carga"; exit 0; }
sleep 1

# 2) APR sobre el glink del ADSP (q6core/q6afe/q6asm/q6adm)
modprobe -r mia3_dtbo 2>/dev/null || true
modprobe mia3_dtbo dtbo=mia3-apr.dtbo
for m in apr q6core q6afe-clocks q6afe-dai q6routing q6asm-dai; do
	modprobe "$m" || log "aviso: $m no carga"
done

R=$(grep -l adsp /sys/class/remoteproc/*/name 2>/dev/null | head -n1 | xargs -r dirname)
if [ -z "$R" ]; then
	log "el ADSP no aparece en /sys/class/remoteproc; se omite el audio"
	exit 0
fi
if [ "$(cat "$R/state" 2>/dev/null)" = running ]; then
	echo stop >"$R/state"
	sleep 1
fi
echo start >"$R/state"
for _ in $(seq 1 20); do
	[ -e /sys/bus/apr/devices ] && [ -n "$(ls /sys/bus/apr/devices 2>/dev/null)" ] && break
	sleep 1
done
sleep 3

# 3) tarjeta de sonido + amp MAX98937 (dummy codec + SEC_MI2S)
modprobe -r mia3_dtbo 2>/dev/null || true
modprobe snd-soc-spdif 2>/dev/null || true
modprobe mia3_dtbo dtbo=mia3-speaker.dtbo \
	ph="$A/service@7/dais=0x8001,$A/service@4/dais=0x8002,$A/service@8/routing=0x8003" \
	pdev=/mia3-amp-codec,/sound
modprobe snd-soc-sm8250

for _ in $(seq 1 10); do
	grep -q Mi-A3 /proc/asound/cards 2>/dev/null && break
	sleep 1
done
cat /proc/asound/cards || true

if grep -q 'Mi-A3' /proc/asound/cards 2>/dev/null; then
	sh "$P/max98937-init.sh"
	log "altavoz listo (tarjeta Mi-A3)"
else
	log "la tarjeta Mi-A3 no aparecio; revisa dmesg (APR/ADSP)"
fi
