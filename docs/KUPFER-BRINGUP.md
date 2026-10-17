# Kupfer — bring-up en el Mi A3 (laurel_sprout)

Guía operativa de lo aplicado en la prueba física del **2026-10-17**
(ver `reports/physical-tests/KUPFER-LAUREL-BRINGUP-2026-10-17/result.md`).

Flasheo base: `docs/FLASH-LAUREL-CACHYOS.md` (slot b + `userdata`, Android intacto en slot a).

> Todos los pasos por `ssh`; con `sudo` ya configurado sin contraseña en la imagen de esta
> prueba. Tras el Wi-Fi, el acceso puede ser por red o Tailscale.

## 1. Arranque: `fstab` sin `kupfer_boot`

El layout A/B flashea **solo p2** (`kupfer_root`) en `userdata`; no existe la subpartición
`kupfer_boot` que pide el `fstab` heredado. Sin este paso se cae a *emergency mode*.

Parchear la imagen **antes de flashear** (con `debugfs`, sin montar):

```sh
printf 'LABEL=kupfer_boot       /boot   ext2    rw,noatime,nofail,x-systemd.device-timeout=5s      0       0\n' > /tmp/fstab.new
debugfs -w -R "rm /etc/fstab" rootfs.img
debugfs -w -R "write /tmp/fstab.new /etc/fstab" rootfs.img
# red de seguridad (consola de rescate con root bloqueado)
debugfs -w -R "mkdir /etc/systemd/system/emergency.service.d" rootfs.img
printf '[Service]\nEnvironment=SYSTEMD_SULOGIN_FORCE=1\n' > /tmp/oe.conf
debugfs -w -R "write /tmp/oe.conf /etc/systemd/system/emergency.service.d/override.conf" rootfs.img
e2fsck -fy rootfs.img
```

## 2. GPU: `a630_sqe.fw`

Kupfer trae el zap (`a610_zap.mbn`) pero no `qcom/a630_sqe.fw` (KWin cae a `llvmpipe`):

```sh
curl -fsSL -o /tmp/a630_sqe.fw https://gitlab.com/kernel-firmware/linux-firmware/-/raw/main/qcom/a630_sqe.fw
sudo install -Dm644 /tmp/a630_sqe.fw /usr/lib/firmware/qcom/a630_sqe.fw
# sha256 1c21b527d9183487cc550dabbb3f43e555df5a977a461934fc61f0635a9aa90c
```

## 3. Plasma: drop-in `libPlasma.so.7` (partial upgrade de ALARM)

ALARM está a medio actualizar a Plasma 6.8 (`libplasma` 6.8.0 vs `plasma-workspace` 6.7.5).
Mientras no publique `plasma-workspace 6.8.0`, este drop-in aditivo hace arrancar plasmashell:

```sh
for f in libplasma-6.7.5-1.fc44 plasma-activities-6.7.5-1.fc44; do
  curl -fsSLO "https://kojipkgs.fedoraproject.org/packages/${f%%-[0-9]*}/6.7.5/1.fc44/aarch64/$f.aarch64.rpm"
done
mkdir -p x && bsdtar xf libplasma-6.7.5-1.fc44.aarch64.rpm -C x && bsdtar xf plasma-activities-6.7.5-1.fc44.aarch64.rpm -C x
sudo install -m755 x/usr/lib64/libPlasma.so.6.7.5 x/usr/lib64/libPlasmaQuick.so.6.7.5 /usr/lib/
sudo ln -sf libPlasma.so.6.7.5 /usr/lib/libPlasma.so.7
sudo ln -sf libPlasmaQuick.so.6.7.5 /usr/lib/libPlasmaQuick.so.7
sudo ldconfig && sudo reboot
```
Rollback cuando ALARM publique 6.8.0: borrar esos 4 ficheros de `/usr/lib` y `pacman -Syu`.

## 4. Wi-Fi: DTB con wifi + userspace del módem

**4a) DTB.** El kernel usa el fork sin los parches DTS de wifi/cdsp/mpss. Compilar
`pmaports-overlay/dts/k7.dts` y sustituir el DTB anexado del `boot.img` de Kupfer:

```sh
dtc -q -I dts -O dtb -o k7.dtb k7.dts            # 44444 B, con qcom,wcn3990-wifi
# reemplazar el DTB dentro del boot.img (header v0, DTB al final de la región del kernel)
# y escribir a boot_b:  sudo dd if=boot-kupfer-k7.img of=/dev/disk/by-partlabel/boot_b bs=4M conv=fsync
```

**4b) Userspace del módem.** El WCN3990 necesita el MPSS (módem) arriba:

```sh
sudo pacman -S --needed rmtfs-git qrtr-git \           # repo aur
    pd-mapper-git tqftpserv-git q6voiced hexagonrpcd    # repo device (Kupfer)
```
Orden obligatorio: `rmtfs`/`tqftpserv` → **módem** → `pd-mapper` → `ath10k_snoc`
(`pd-mapper` solo lee los PD maps con el módem corriendo). Automatizado por
`mia3-wifi.service` + `mia3-wifi-up.sh` (ver `kupfer-overlay/mia3-support/`).

## 5. Batería (PMI632)

Los módulos se compilan **contra el kernel exacto**. Fuera del CI:

```sh
# en el host (clang)
curl -fsSL -o linux.tar.gz https://codeberg.org/sm61x5-mainline/linux/archive/v7.2.3-r0.tar.gz
tar xf linux.tar.gz && cd linux
ssh laurel cat /proc/config.gz | zcat > .config
make ARCH=arm64 LLVM=1 olddefconfig modules_prepare
make ARCH=arm64 LLVM=1 KBUILD_MODPOST_WARN=1 M=<dir-módulo> modules
# el .dtbo SIN -@ (el DTB vivo no tiene __symbols__)
dtc -I dts -O dtb -o mia3-qg.dtbo mia3-qg.dts
```

Instalación en el dispositivo (ver `kupfer-overlay/mia3-support/`):
`mia3_qg.ko`, `pmi632_chg.ko`, `mia3_dtbo.ko` → `/usr/lib/modules/$(uname -r)/extra/`,
`mia3-qg.dtbo` → `/usr/lib/firmware/`, `depmod -a`, y habilitar `mia3-qg.service` +
`chargectl.service` (objetivo de carga en `/var/lib/chargectl/chargectl.json`).

## 6. Tailscale + SSH bidireccional

```sh
sudo pacman -S --needed tailscale && sudo systemctl enable --now tailscaled
sudo tailscale up          # autorizar en el navegador
# claves cruzadas en authorized_keys + alias en ~/.ssh/config
```

Nota: `sudo` sin contraseña debe ir en un fichero que ordene **después** de
`/etc/sudoers.d/wheel` (p.ej. `zz-user-nopasswd`); gana la última coincidencia.
