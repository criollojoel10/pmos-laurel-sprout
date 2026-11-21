# Flashear laurel desde begonia (procedimiento validado)

Procedimiento usado el **2026-11-21** para flashear el artefacto de Kupfer +
Phosh (`26-build-kupfer`, run `44848808710`) desde begonia (Arch Linux ARM,
MT6785) como host USB. Resultado: arranque correcto en el slot b y todos los
componentes de `reports/physical-tests/KUPFER-2026-11-21/result.md`
funcionando.

> Este documento es operativo. No publica serial, IMEI, MAC ni claves Wi‑Fi.
> Antes de escribir: backup del slot que se va a tocar y del `persist`.

## 0. Requisitos

- laurel con bootloader desbloqueado y **cable de datos** (no solo carga).
- Artefactos verificados de `kupfer-laurel-phosh`:
  `boot.img`, `vbmeta.img`, `rootfs.img` (ext4 raw) y `SHA256SUMS`.
- En begonia: `fastboot` **30.0.5** y `adb` (android-tools).

## 1. fastboot 30.0.5 (obligatorio para este ABL)

El bootloader del Mi A3 no soporta `fastboot boot` y con clientes modernos
(33/37) responde `unknown command`. El cliente validado es **30.0.5**:

```sh
git clone https://github.com/criollojoel10/pmos-laurel-sprout
cd pmos-laurel-sprout
sudo scripts/build-fastboot-30.0.5.sh        # deja /usr/local/bin/fastboot
fastboot --version                            # 30.0.5-android-tools
```

`adb` se instala con `pacman -S android-tools` (37.0.0p1 funciona; solo se usa
para `adb devices`/`reboot`).

## 2. Comprobar el host USB de begonia

El puerto USB-C de begonia debe estar en rol host:

```sh
cat /sys/class/typec/port0/data_role   # host [device]
lsusb                                  # laurel en fastboot: 18d1:d00d
fastboot devices
```

Si no aparece: revisa el cable (datos), vuelve a entrar en fastboot en laurel
(**Volumen abajo + Power**) y reconecta.

## 3. Preflight de solo lectura

```sh
fastboot getvar product          # laurel_sprout
fastboot getvar current-slot     # a o b
fastboot getvar unlocked         # yes
fastboot getvar slot-count       # 2
fastboot getvar partition-size:userdata
```

No ejecutar `getvar all` en público: incluye el serial.

## 4. Flasheo (slot b, Android del slot a intacto)

Con el teléfono en fastboot:

```sh
cd kupfer-laurel-44848808710
sha256sum -c SHA256SUMS

fastboot flash vbmeta_b vbmeta.img
fastboot erase dtbo_b
fastboot flash userdata rootfs.img      # ~8,4 GB; tarda varios minutos
fastboot flash boot_b boot.img
fastboot set_active b
fastboot reboot
```

Tiempos medidos: `userdata` 532 s, `boot_b` 47 s. Es normal ver
`Invalid sparse file format at header magic` al principio: la imagen es raw y
fastboot cae a envío por trozos.

## 5. Después del arranque: USB RNDIS

laurel arranca y se reenumera como gadget:

```
lsusb
# 1d6b:0104 Linux Foundation Multifunction Composite Gadget
# Product: Arch Linux ARM   Manufacturer: kupfer
```

El gadget usa `172.16.42.1`; begonia ya tiene esa IP en su propio `usb0`. Para
no romper `usb0`, mueve la interfaz de laurel a un netns:

```sh
sudo scripts/laurel-usb-netns.sh
# netns 'laurel': enu1u4 = 172.16.42.2/24
sudo ip netns exec laurel ssh user@172.16.42.1
```

Contraseña del perfil: `user` / `changeme` (cámbiala en el teléfono).

### 5.1 Primer arranque: cambia la contraseña

El perfil crea `user` / `changeme` (SSH y sudo). Cámbiala ya:

```sh
passwd              # contraseña del usuario
sudo passwd         # contraseña de root, si la vas a usar
```

El repo no guarda contraseñas reales; no publiques la que elijas.

### 5.2 Si te bloqueas por intentos fallidos

`pam_faillock` bloquea el login tras varios fallos (SSH incluido):

1. Espera `unlock_time` (600 s por defecto) o **reinicia** laurel; si el estado
   está en `/var/run/faillock` (tmpfs), el reinicio lo borra.
2. Ya dentro: `sudo scripts/reset-faillock-laurel.sh user`
   (equivale a `faillock --user user --reset`).
3. Si perdiste la contraseña: reflashea solo `userdata` con el `rootfs.img`
   verificado; vuelve a `changeme` y borra los cambios desde el flasheo, sin
   tocar el slot a/Android.

No sigas probando contraseñas: cada fallo reinicia el contador.

## 6. Verificación

Por USB (netns) o por Wi‑Fi (misma LAN):

```sh
ssh user@172.16.42.1 'sh -s' < scripts/verify-kupfer-laurel.sh
```

Debe dar `fallas: 0 | avisos: 0`. Comprobaciones que necesitan root:

```sh
sudo qbootctl                         # Current slot _b, Successful 1
sudo dmesg | grep -iE 'adsp|ath10k|a630|panel'
nmcli device wifi list                # 14 BSS en la prueba de referencia
cat /proc/asound/cards                # tarjeta Mi-A3
```

Prueba audible del altavoz:

```sh
speaker-test -t sine -f 440 -l 1 -p 1 -D plughw:0,0
```

## 7. Recuperación

Si no arranca o se queda en el logo:

```sh
fastboot set_active a && fastboot reboot
```

El slot a conserva Android. Si el ABL marca el slot como unbootable,
`fastboot set_active b` (o `a`) resetea el contador; `qbootctl.service` evita
que vuelva a pasar en cada arranque.

## 9. Recuperar el boot tras XNU/HakiOS (GPT del boot LUN)

Si tras probar HakiOS/XNU el ABL cae a fastboot en ambos slots, `set_active b`
no basta y el contador de reintentos baja, la metadata del **boot LUN 4** pudo
quedar inconsistente. No borres `userdata`.

1. En CI, workflow `28-extract-stock-gpt` descarga el ROM oficial y publica los
   ficheros pequeños (`gpt_both*.bin`, `prog_firehose_ddr.elf`, `flash-all`).
2. Restaura **solo el LUN 4**:

   ```sh
   fastboot flash partition:4 gpt_both4.bin
   ```

   No uses `gpt_both0.bin` (LUN 0/datos) salvo que sepas exactamente lo que
   haces.
3. Reflashea el Linux verificado y marca el slot:

   ```sh
   for s in a b; do
     fastboot flash boot_$s boot.img
     fastboot flash vbmeta_$s vbmeta.img
     fastboot erase dtbo_$s
   done
   fastboot set_active b
   fastboot reboot
   ```

4. Si el ABL no soporta `partition:4`, usa EDL con `prog_firehose_ddr.elf`
   (el workflow 28 también lo publica). No es necesario si fastboot responde.

Detalle de la incidencia: `reports/physical-tests/KUPFER-2026-11-21-RECOVERY/result.md`.

## 8. Avisos conocidos (inofensivos)

- `ath10k_snoc: chan info: invalid frequency 0` — DTB k7; no impide Wi‑Fi.
- `ath10k_snoc: invalid MAC address; choosing random` — MAC aleatoria.
- `a630_sqe.fw` falla la primera carga y se carga después “from new location”.
- `MultiMedia1: ASoC: no backend DAIs enabled` — sonda de audio antes del routing
  del altavoz; la reproducción por `MultiMedia3` funciona.
- `qcom_q6v5_pas: Handover signaled, but it already happened` — ADSP/MPSS.
