# Baseline físico Laurel 6.1 funcional

Fuente exacta disponible localmente (no publicar):
`local-private/run31355730519-artifacts/artifacts/export-resolved/boot.img`
(boot pmOS original) + rootfs SSH del mismo run en `system_b`.

- Kernel: `6.1.0-sm6125` aarch64.
- Initramfs: boot histórico pmOS/mkinitfs, header v0; incluye el DTB appendado
  en el payload histórico y el ramdisk gzip.
- Runtime confirmado: simplefb/fbcon 720x1560, UFS/rootfs, RNDIS y SSH root.
- `DRM_MSM=m` no cargado; no hay `/dev/dri`.
- QUSB2 PHY registrada; USB gadget RNDIS funcional.
- Sin `mmc_host`, `wlan0`, `hci0`, power-supply, thermal zones ni cpufreq.
- El cmdline del boot original no tenía `consoleblank=0`; el negro después de
  ~600 s fue blanking de fbcon, no apagado físico del panel.

El DT 6.1 de referencia descompilado está en
