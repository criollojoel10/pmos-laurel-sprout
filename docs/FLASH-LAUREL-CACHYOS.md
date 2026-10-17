# Flashear postmarketOS en el Mi A3 (laurel_sprout) desde cachyos

Los artefactos los produce el workflow `25-build-pmos-laurel` en GitHub
Actions. Se descargan desde la pestaña Actions (artefacto
`pmos-laurel-<ui>`) y se copian a cachyos.

**Todo el flasheo se hace desde cachyos. Este repo (begonia) no toca el
teléfono** (AGENTS.md §0).

## Artefactos

| Fichero | Destino | Notas |
|---|---|---|
| `boot.img` | `boot_b` | kernel 7.2.3 + initramfs |
| `rootfs.img` | `userdata` | rootfs postmarketOS (sector 4096) |
| `vbmeta.img` | `vbmeta_b` | `avbtool make_vbmeta_image --flags 2 --padding_size 4096` |
| `SHA256SUMS` | — | integridad |
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

## Primera prueba: qué mirar (Kupfer)

Mismos artefactos y mismos comandos. Diferencias: el rootfs es Arch, el usuario
es `user`/`changeme` y el initramfs lo genera `mkinitcpio` con el conf de Kupfer
(`/etc/kupfer/mkinitcpio.conf`). Si arranca al shell de emergencia, lo primero es
comprobar que la rootfs se montó y que `deviceinfo_dtb` apunta a
`qcom/sm6125-xiaomi-laurel-sprout`.

