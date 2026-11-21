# Flashear postmarketOS en el Mi A3 (laurel_sprout) desde cachyos

Los artefactos los produce el workflow `25-build-pmos-laurel` (postmarketOS) o
`26-build-kupfer` (Arch/Kupfer) en GitHub Actions, con el **mismo formato**: se
descargan desde la pestaña Actions y se copian a cachyos.

```sh
# postmarketOS (run 39004800346) o Kupfer (run 39007976354)
gh run download <run-id> -R criollojoel10/pmos-laurel-sprout -n pmos-laurel-plasma-mobile
gh run download <run-id> -R criollojoel10/pmos-laurel-sprout -n kupfer-laurel-phosh
```

Alternativa rapida con aria2c (multi-conexion) y validacion de SHA256:

```sh
scripts/download-kupfer-artifact.sh 44848808710
```

**Todo el flasheo se hace desde cachyos. Este repo (begonia) no toca el
teléfono** (AGENTS.md §0).

## Artefactos

| Fichero | Destino | Notas |
|---|---|---|
| `boot.img` | `boot_b` | kernel 7.2.3 + initramfs |
| `rootfs.img.zst` | `userdata` | rootfs comprimida con zstd (Kupfer+Phosh ronda 8-10 GB descomprimida, sector 4096) |
| `vbmeta.img` | `vbmeta_b` | `avbtool make_vbmeta_image --flags 2 --padding_size 4096` |
| `SHA256SUMS` | — | integridad (cubre `rootfs.img.zst`, no la descomprimida) |
| `manifest.txt` | — | versiones y hashes del build |

Se flashea al **slot b**; el Android stock del **slot a** no se toca.

## Requisitos

- Bootloader desbloqueado.
- `fastboot` (en Arch: `pacman -S android-tools`). Solo fastboot: **no** se usa
  `adb`.
- Teléfono apagado, luego Volumen abajo + Power para entrar en fastboot.

## Comprobaciones previas (solo lectura)

```sh
fastboot devices
fastboot getvar product        # debe decir: laurel_sprout
fastboot getvar unlocked       # debe decir: unlocked: yes
fastboot getvar current-slot
```

## Flasheo

```sh
cd <dir-con-los-artefactos>
sha256sum -c SHA256SUMS
zstd -d rootfs.img.zst          # -> rootfs.img (~2.9 GB)

fastboot flash vbmeta_b vbmeta.img
fastboot erase dtbo_b
fastboot flash userdata rootfs.img
fastboot flash boot_b boot.img
fastboot set_active b
fastboot reboot
```

Primer arranque: ~1 minuto. Después el teléfono levanta el gadget USB y se
entra por SSH:

```sh
ssh user@172.16.42.1        # contraseña por defecto: changeme
```

Si la interfaz no aparece sola, en cachyos:

```sh
ip link set <interfaz> up
ip addr replace 172.16.42.2/32 dev <interfaz>
ip route replace 172.16.42.1/32 dev <interfaz> src 172.16.42.2
# <interfaz> = la que tenga product "Xiaomi Mi A3" en /sys/class/net/*/device/../product
```

## Volver a Android

El slot a sigue intacto:

```sh
fastboot set_active a
fastboot reboot
```

## Primera prueba: qué mirar (postmarketOS)

Con el teléfono recién arrancado, en este orden:

1. **Pantalla y táctil**: el panel AMOLED debe encenderse desde el initramfs
   (módulos `msm`, `panel-samsung-s6e8fc0-m1906f9`, `edt_ft5x06`). Si hay imagen
   pero el táctil no responde, es el módulo `edt_ft5x06`.
2. **Red USB**: el gadget debe levantar RNDIS y dar `172.16.42.1`. `ssh
   user@172.16.42.1` (contraseña `changeme`).
3. **`dmesg | grep -iE 'drm|panel|ft5x06'`**: confirma que el panel enlazó.
4. **Wi-Fi** (solo si el build llevaba `with_firmware=true`):
   `nmcli device` debe listar `wlan0`; si no aparece, revisar
   `dmesg | grep -i ath10k` y que exista
   `/usr/lib/firmware/qcom/sm6125/xiaomi/laurel/wlanmdsp.mbn`.
5. **Batería**: en este primer build **no** está soportada (falta el driver
   out-of-tree del fuel gauge PMI632). `cat /sys/class/power_supply/*/capacity`
   probablemente no exista todavía.

## Primera prueba: qué mirar (Kupfer + Phosh)

Mismos artefactos y mismos comandos. Diferencias: el rootfs es Arch, el usuario
es `user`/`changeme`, el escritorio por defecto es **Phosh** y el initramfs lo
genera `mkinitcpio` con el conf de Kupfer (`/etc/kupfer/mkinitcpio.conf`).

El build ya trae los arreglos que antes había que aplicar a mano (fstab,
`a630_sqe.fw`, DTB k7, `rmtfs`/`pd-mapper`/`tqftpserv`, `mia3-support` y
`qbootctl`). Tras el primer arranque, comprobar en orden:

```sh
# 1. arranque y servicios base
systemctl --failed                       # -> 0 units failed
systemctl is-active qbootctl mia3-qg chargectl mia3-wifi mia3-audio
qbootctl                                 # Current slot: _b / Successful: 1

# 2. GPU (render real, no llvmpipe)
ls /dev/dri                              # card0/card1 + renderD128
glxinfo -B 2>/dev/null | grep -i renderer

# 3. pantalla y táctil
cat /sys/class/drm/card*-DSI-1/status    # connected
libinput list-devices | grep -i ft

# 4. batería
cat /sys/class/power_supply/mia3-qg/{capacity,voltage_now,current_now}

# 5. Wi-Fi
nmcli device status                      # wlan0 conectada
ip -br addr show wlan0

# 6. audio (altavoz inferior)
cat /proc/asound/cards                   # -> Mi-A3
speaker-test -t sine -f 440 -l 1         # o: aplay -D plughw:Mi-A3 ...
```

Todo eso se puede comprobar de golpe con el script del repo (solo lectura):

```sh
ssh user@172.16.42.1 'sh -s' < scripts/verify-kupfer-laurel.sh
```

Si `mia3-audio` no deja la tarjeta `Mi-A3`, revisar
`journalctl -u mia3-audio -b` y `dmesg | grep -iE 'adsp|q6|apr|max98937'`.
Si `wlan0` no aparece, `journalctl -u mia3-wifi -b` y
`dmesg | grep -iE 'ath10k|wcn3990|remoteproc'`.

Si arranca al shell de emergencia, comprobar que la rootfs se montó y que
`deviceinfo_dtb` apunta a `qcom/sm6125-xiaomi-laurel-sprout`.

