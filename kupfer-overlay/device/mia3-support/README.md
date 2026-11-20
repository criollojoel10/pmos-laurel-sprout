# mia3-support — soporte de hardware del Mi A3 para Kupfer

Módulos y servicios fuera del árbol que el kernel mainline no trae, aplicados y
**verificados sobre hardware** en la prueba del 2026-10-17 (ver
`reports/physical-tests/KUPFER-LAUREL-BRINGUP-2026-10-17/result.md`).

| Fichero | Qué hace |
|---|---|
| `mia3-qg.dts` | Overlay que añade `fuel-gauge@4800` bajo `pmic@2` con la tabla OCV (Sunwoda 4030 mAh) |
| `mia3-adsp.dts` / `mia3-apr.dts` / `mia3-speaker.dts` | Overlays de audio (ADSP remoteproc + smp2p, APR/Q6, tarjeta `Mi-A3` + I2S secundario) |
| `bringup.sh` + `max98937-init.sh` + `mia3-audio.service` | Secuencia de arranque del altavoz inferior y programación del amplificador MAX98937 por I2C |
| `mia3-qg.service` | Aplica el overlay y carga `mia3_qg` (una vez por arranque) |
| `chargectl.py` + `chargectl.service` | Mantiene la carga en el objetivo (`/var/lib/chargectl/chargectl.json`, por defecto 50 %), con corte térmico (45/40 °C) y failsafe de batería baja |
| `mia3-wifi-up.sh` + `mia3-wifi.service` | Bring-up del WCN3990: espera `remoteproc0` → arranca el módem → `pd-mapper` → recarga `ath10k_snoc` |

El audio necesita además, en el kernel, `CONFIG_QCOM_Q6V5_ADSP`,
`CONFIG_QCOM_APR`, `CONFIG_SND_SOC_QDSP6`, `CONFIG_SND_SOC_SM8250` y
`CONFIG_SND_SOC_SPDIF` (ya están en `kupfer-overlay/linux/sm61x5/extra_config`).
El amplificador es un **MAX98937** (no MAX98927): no hay driver mainline, se
programa desde userspace con `i2c-tools`; el enlace termina en el codec dummy
`linux,spdif-dit` (`snd-soc-spdif`).

## Compilación (contra el kernel exacto)

Los módulos (`mia3_qg`, `mia3_dtbo`, `mia3_adsp`, `pmi632_chg`) los compila el
propio paquete `linux-sm61x5` (mismo árbol y compilador) y quedan en
`/usr/lib/modules/<ver>/extra/`; este paquete solo aporta datos, overlays y
unidades. Así se evita depender de `linux-sm61x5-headers` y de `qbootctl` dentro
del chroot de compilación.

Referencia histórica de la compilación manual con clang: **No se compila con GCC**: aunque el kernel del
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

## Arranque A/B y orden de unidades (2026-10-17)

- **`qbootctl`** (dependencia de este paquete): sin marcar el slot como *successful*,
  el ABL agota los reintentos y deja el teléfono en el **logo de Mi**. `mia3-support`
  depende de `qbootctl`; su servicio (`qbootctl -m`) debe estar `enabled`.
- **Orden:** `mia3-qg.service` **no** lleva `After=multi-user.target` (junto con
  `WantedBy=multi-user.target` crea un ciclo y `chargectl` no arranca). `chargectl`
  usa `Wants=`+`After=mia3-qg.service`.
