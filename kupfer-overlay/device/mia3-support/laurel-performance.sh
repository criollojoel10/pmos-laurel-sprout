#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Max performance para laurel: CPU governor performance y frecuencia fija al
# maximo de cada policy, GPU Adreno 610 en governor performance.
# Instalado por mia3-support y habilitado como laurel-performance.service.
set -u
for p in /sys/devices/system/cpu/cpufreq/policy*; do
	[ -d "$p" ] || continue
	max=$(cat "$p/cpuinfo_max_freq" 2>/dev/null) || continue
	echo performance >"$p/scaling_governor" 2>/dev/null || true
	echo "$max" >"$p/scaling_max_freq" 2>/dev/null || true
	echo "$max" >"$p/scaling_min_freq" 2>/dev/null || true
done
g=/sys/class/devfreq/5900000.gpu
if [ -d "$g" ]; then
	echo performance >"$g/governor" 2>/dev/null || true
fi
