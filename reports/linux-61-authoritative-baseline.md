# Baseline autoritativo Linux 6.1

Fecha: 2026-08-11. Este documento congela la evidencia disponible, no declara
una imagen historica unica cuando las pruebas usaron componentes distintos.

## Composicion reproducible recomendada

| Componente | Artefacto | Evidencia | Estado |
|---|---|---|---|
| Kernel/boot original | run `31320766387`, `boot.img`, 12,402,688 B, SHA-256 `3b692fefa4836246634955318232f416502a3ac316f403736a489ab9edf7b5fb3` | Consola pmOS, rootfs UFS y RNDIS visibles | `partially-working` |
| Kernel 6.1 reconstruido | commit `77de535b8dbd8f483b5802c8937cb714bab5b485`, config SHA-256 `08bcee71d4164ef3e7c1244cdf4d5a0e4e7e2eedcadd9e5576166f8661417c4a` | Compilacion historica reproducida en CI | `compiled` |
| Boot diagnostico sedfix | workflow 09, 12,402,688 B, SHA-256 `ff5f0905282b105c3b17f49c2c07c98971547c29b25ddc75ba19453426b0a8be` | `INITRAMFS_REACHED` y shell de rescate | `partially-working` |
| Rootfs SSH | run `31355730519`, `xiaomi-laurel-ssh.img`, 550,935,480 B, SHA-256 `ebc8287f277d8ffd28c5eb128e1248e668e44a316cb4484916d0748d5bc40a2a` | root SSH por clave sobre RNDIS, UFS operativo | `partially-working` |

## Baseline de trabajo

La siguiente imagen de prueba debe combinar el kernel 6.1 fijado, el DTB
correspondiente, un initramfs compatible con 6.1 y el rootfs SSH del run
`31355730519`. El boot original y el rootfs SSH no son el mismo artefacto ni
se deben describir como una sola imagen ya probada.

Cmdline inicial preferida para una variante nueva, pendiente de build y prueba:

```text
console=ttyMSM0,115200n8 console=tty0 consoleblank=0 loglevel=7 ignore_loglevel printk.time=1 panic=0 clk_ignore_unused pd_ignore_unused regulator_ignore_unused androidboot.hardware=qcom androidboot.console=ttyMSM0 loop.max_part=7 buildvariant=user
```

La primera variante debe conservar simplefb/fbcon, UFS, gadget RNDIS y SSH.
DRM/MSM, GPU, Wi-Fi, Bluetooth, audio, suspend y OTG host quedan fuera de esta
imagen hasta que existan dos canales de diagnostico y una captura runtime.

## Criterio de congelacion

No se elevara a `working` hasta demostrar tres arranques, 60 minutos por
arranque, pantalla sin blanking, rootfs/UFS sin errores graves, SSH estable,
dmesg completo y pstore montado. Las pruebas fisicas requieren preflight FASE 8
y se detienen antes de cualquier escritura.
