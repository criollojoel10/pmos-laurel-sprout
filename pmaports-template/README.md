# pmaports Template (device-xiaomi-laurel-sprout)

Estado: `placeholder` — pmOS mainline NO tiene aún este dispositivo.

Estos archivos son la plantilla de aporte a https://gitlab.com/postmarketOS/pmaports
que DESBLOQUEA la build real pmbootstrap del rootfs postmarketOS (console/phosh).

## Qué falta para que la build pmOS sea real

1. `device/device-xiaomi-laurel-sprout/` (deviceinfo + APKBUILD)
2. `device/linux-postmarketos-qcom-sm6125/` (APKBUILD del kernel con los 4 parches)

La Firma de los 4 parches (SHA256 en `reports/manifest-kernel.json` del prerelease):

- 0001-dts-mdss-panel-s6e8fc0.patch
  `bec2c12f114b382b369b534751c2191c8a82318589c8b8b658fbd0835e80fdc9`
- 0002-dtsi-gpu-adreno610.patch
  `01b3378378e54490cd7080fc6c6ad4281bc0ff6df0edcb2e39c8790e5e168a8a`
- 0003-dts-enable-gpu.patch
  `7db0d696838f078d939b58346cd7a88b9c0155398affc98f1cac0aa474f443c0`
- 0004-dts-enable-wifi-wcn3990.patch
  `5e9af131bfe6e149831699c247ad22b63cd19e92b7bcc403d51a1c2494ec6bf0`

## CLI pmbootstrap una vez aportado al upstream

```sh
pmbootstrap init            # device: xiaomi-laurel-sprout, ui: console|phosh
pmbootstrap install         # genera rootfs + boot.img (imagen systemd)
pmbootstrap flasher flash_boot  # NO correr: flashea el dispositivo
```

## Alternativa sin esperar upstream

Las imágenes Arch Linux ARM y NixOS (workflows 05/06/07) ya son producibles
y NO dependen de pmaports. Usá esas para bootear mientras se aporta pmOS.