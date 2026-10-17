# mia3-support — soporte de hardware del Mi A3 para Kupfer

Módulos y servicios fuera del árbol que el kernel mainline no trae, aplicados y
**verificados sobre hardware** en la prueba del 2026-10-17 (ver
`reports/physical-tests/KUPFER-LAUREL-BRINGUP-2026-10-17/result.md`).

| Fichero | Qué hace |
|---|---|
| `mia3_qg.c` | Fuel gauge PMI632 **read-only** → `/sys/class/power_supply/mia3-qg` (`capacity`, `voltage_now`, `current_now`) |
| `pmi632_chg.c` | Cargador PMI632 con parámetros (`charging_enabled`, `usb_suspend`, `usb_icl_ma`) |
| `mia3_dtbo.c` | Cargador de overlays de device-tree en runtime (`modprobe mia3_dtbo dtbo=<f>.dtbo`) |
| `mia3-qg.dts` | Overlay que añade `fuel-gauge@4800` bajo `pmic@2` con la tabla OCV (Sunwoda 4030 mAh) |
| `mia3-qg.service` | Aplica el overlay y carga `mia3_qg` (una vez por arranque) |
| `chargectl.py` + `chargectl.service` | Mantiene la carga en el objetivo (`/var/lib/chargectl/chargectl.json`, por defecto 50 %), con corte térmico (45/40 °C) y failsafe de batería baja |
| `mia3-wifi-up.sh` + `mia3-wifi.service` | Bring-up del WCN3990: espera `remoteproc0` → arranca el módem → `pd-mapper` → recarga `ath10k_snoc` |

## Compilación (contra el kernel exacto)

`mia3-support` compila los tres módulos con `ARCH=arm64 LLVM=1 KBUILD_MODPOST_WARN=1`
contra `linux-sm61x5-headers`. **No se compila con GCC**: aunque el kernel del
dispositivo se construyó con GCC, los módulos con clang cargan igual (config del
teléfono: `CONFIG_LTO_NONE`, `CONFIG_RANDSTRUCT_NONE`, sin `MODVERSIONS`, sin
`MODULE_SIG_FORCE`). Gotcha original (`struct module` / `.gnu.linkonce.this_module
section size must match`) se evita usando el **mismo config** que el teléfono
(`/proc/config.gz`).

Procedimiento manual verificado (host con clang + pahole):

```sh
curl -fsSL -o linux.tar.gz https://codeberg.org/sm61x5-mainline/linux/archive/v7.2.3-r0.tar.gz
tar xf linux.tar.gz && cd linux
ssh laurel 'cat /proc/config.gz' | zcat > .config
make ARCH=arm64 LLVM=1 -j"$(nproc)" olddefconfig modules_prepare
make ARCH=arm64 LLVM=1 KBUILD_MODPOST_WARN=1 M=<dir> modules
dtc -I dts -O dtb -o mia3-qg.dtbo mia3-qg.dts      # SIN -@
```

## Overlay de DT: por qué **sin** `-@`

El DTB vivo (`k7.dtb`) **no** exporta `__symbols__`. El overlay usa referencias por
ruta (`&{/soc@0/spmi@1c40000/pmic@2}`), que no lo necesitan. Si se compila con `-@`,
el kernel rechaza el overlay:

```
OF: overlay: symbols in overlay, but not in live tree
OF: overlay: init_overlay_changeset() failed, ret = -22
```

Un overlay se aplica **una sola vez por arranque**; `mia3-qg.service` salta la
aplicación si el nodo `fuel-gauge@4800` ya existe.

## Dependencias de Wi-Fi

El WCN3990 exige el **módem (MPSS)** arriba, y el módem necesita el userspace QMI/QRTR.
Los paquetes (repos de Kupfer/ALARM) son: `rmtfs-git`, `qrtr-git`, `pd-mapper-git`,
`tqftpserv-git` (el `pd-mapper` en sí ya es in-kernel: `qcom_pd_mapper`).
Orden: `rmtfs`/`tqftpserv` → **módem** → `pd-mapper` → `ath10k_snoc`.

## Pendiente / mejoras

- `chg_temp` (iio:device1) lee un valor inválido (~377 °C) y `chargectl` lo descarta;
  usa `quiet_therm`/`xo_therm` (~30 °C), que sí leen.
- Sensores TSENS de CPU/GPU (`thermal-sensors/` del repo de referencia): opcionales,
  mejoran el *thermal-guard*. Requieren su propio `.ko` + overlay.
- `xt_connmark` (Tailscale) no está en el config del kernel; Tailscale funciona igual.
