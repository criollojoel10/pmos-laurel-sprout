# kupfer-overlay — port de Kupfer Linux al Xiaomi Mi A3

Overlay que se copia encima del árbol de pkgbuilds de Kupfer
(`gitlab.com/kupfer/packages/pkgbuilds`, rama `dev`) durante el workflow
`26-build-kupfer`, igual que hace el port de begonia
(`criollojoel10/begonia-kupfer-linux`). El MR contra KupferLinux/pkgbuilds es
`cp -r kupfer-overlay/* <checkout>/`.

## Contenido

| Ruta | Qué es |
|---|---|
| `linux/sm61x5/` | `linux-sm61x5`: kernel del fork `sm61x5-mainline` (tag `v7.2.3-r0`, commit `5a88d98f`) + `config-nura-qcom-sm61x5.aarch64` de pmaports@`ec98dddc`. `extra_config` añade WEXT, `CRYPTO_LZ4` y desactiva la compresión de módulos. |
| `device/device-sm61x5-xiaomi-laurel/` | `device-sm61x5-xiaomi-laurel`: `deviceinfo` de pmaports@`ec98dddc` + `partitions_data`, `partitions_microsd` y `modules_initfs` (msm, panel S6E8FC0, edt_ft5x06), `/etc/machine-info` y el `mkinitcpio.conf.d`. |
| `firmware/sm61x5-xiaomi-laurel/` | `firmware-sm61x5-xiaomi-laurel`: empaqueta `fw.tar`, que la CI genera desde el ROM oficial. Los blobs no se versionan. |
| `firmware/Dockerfile` | Imagen mínima (Alpine + android-tools + pil-squasher) para extraer el firmware. |

## Por qué NO hacen falta los parches de begonia

Begonia es MediaTek: su bootloader exige `header_version=2` + un recovery dtbo
vacío, y el `mkbootimg` de Kupfer tenía un bug de división entera. El Mi A3 es
Qualcomm: su bootloader usa un `boot.img` estándar (header v0, DTB concatenado
al `Image.gz`) flasheado en la partición `boot`. El `update-bootimg.sh` de
Kupfer ya cubre esa ruta cuando no se define `deviceinfo_header_version`, así
que aquí no se parchea ni `boot-android-bootimg-updater` ni `mkbootimg-git`.

## Fuentes y licencias

Todas las fuentes están en `sources.lock.json`. El kernel es GPL-2.0-only
(Codeberg, `sm61x5-mainline/linux`). El `deviceinfo` de base es de pmaports
(GPL-3.0-or-later). El firmware es propietario y no se redistribuye
(AGENTS.md §1): se extrae del ROM oficial dentro de la CI.
