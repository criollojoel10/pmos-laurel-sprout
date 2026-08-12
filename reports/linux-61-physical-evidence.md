# Evidencia fisica Linux 6.1

## Evidencia confirmada

### `PMOS_CONSOLE_6_1_BOOTED` - 2026-08-09

- Slot b, boot original pmOS, run `31320766387`, kernel `6.1.0-sm6125`.
- Login de postmarketOS visible y switch_root desde `system_b` completado.
- RNDIS enumero en Fedora; `172.16.42.1` respondio ping 3/3.
- UFS/rootfs operativo y sin kernel panic.
- No hubo SSH porque ese rootfs se construyo con `--no-sshd`.
- OTG host no funciono: el DTB historico tenia `dr_mode="peripheral"`.

### `SSH-ROOT-6_1-READONLY` - 2026-08-11

- RNDIS y SSH root por clave funcionaron en `172.16.42.1`.
- `6.1.0-sm6125` aarch64; UFS Samsung KM5V7001DM-B621 detectado.
- simplefb/fbcon registrado: 720x1560x32, stride 2880, framebuffer en
  `0x5c000000`.
- No aparecieron `wlan0`, `hci0`, `power_supply`, thermal zones, cpufreq ni
  `/dev/dri`.
- DRM/MSM permanecio como modulo no cargado, deliberadamente.

### Apagado de pantalla

El sistema siguio accesible por SSH y los relojes de display continuaron vivos.
El framebuffer completo quedo en negro tras aproximadamente 600 s porque
faltaba `consoleblank=0`; el kernel limpio el framebuffer mediante blanking de
fbcon. La escritura de un patron rojo por SSH produjo pantalla roja, probando
que el panel y la senal de video seguian vivos.

## Lo que no esta demostrado

- Una sola imagen que combine boot original, rootfs SSH y todos los resultados.
- Tres arranques independientes de 60 minutos.
- Wi-Fi WCN3990 o Bluetooth en 6.1.
- USB host/OTG, DRM/MSM, GPU/Freedreno, tactil, bateria, thermal, cpufreq,
  audio, sensores o suspend/resume.

## Regla de uso

Estos hechos permiten clasificar el baseline historico como `partially-working`,
no como `working`. Cada nueva capacidad requiere su propia captura de kernel,
DTB, cmdline, firmware, logs y prueba fisica reproducible.
