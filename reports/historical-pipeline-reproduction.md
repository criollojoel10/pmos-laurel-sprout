# Reporte R3 — Reproducción del flujo flasher pmbootstrap 1.50.0 (sin flashear)

Fecha: 2026-08-05. Método: análisis de código fuente congelado + dry-run
determinista. Ningún comando de escritura se ha ejecutado ni se ejecutará aquí.

## Objetivo

Reproducir de forma fiable **qué habría hecho pmbootstrap 1.50.0** en el
dispositivo xiaomi-laurel con el deviceinfo histórico (a27a7ce) y el kernel 6.1,
sin necesidad de construir el rootfs ni de tocar el teléfono.

## Cadena completa de generación de boot.img (verificada en código)

```
kernel package (Image.gz /boot/vmlinuz, flavor postmarketos-qcom-sm6125)
  + deviceinfo (/etc/deviceinfo generado por devicepkg-dev)
  + DTB (/boot/dtbs/qcom/sm6125-xiaomi-laurel_sprout.dtb)
      |
      v
postmarketos-mkinitfs 1.5.1 (main.go:82) -> boot-deploy -i initramfs -k vmlinuz
      |
      v
boot-deploy 0.6.1:
  1. append_or_copy_dtb(): append_dtb=true  ->  vmlinuz-dtb = vmlinuz + DTB
  2. create_bootimg(): generate_bootimg=true, no pxa -> mkbootimg-osm0sis
     (header_version NO definido -> header v0; qcdt=false; dtb_second=false)
  3. mkbootimg-osm0sis -o /boot/boot.img
      |
      v
/boot/boot.img  (header v0, dtb_size=0, kernel=vmlinuz-dtb concatenado)
```

## Transcripción exacta de comandos (dry-run determinista)

Generada por `local-private/historical-port/reproduce-flasher-commands.py`
(a partir de deviceinfo a27a7ce + pmaports.cfg @7aaee51a
`supported_mkinitfs_without_flavors=True`). Transcript guardado en
`local-private/historical-port/logs/flasher-dry-run-transcript.txt`.

```
## flash_rootfs
$ fastboot flash system /home/pmos/rootfs/xiaomi-laurel.img

## flash_kernel
$ fastboot flash boot /mnt/rootfs_xiaomi-laurel/boot/boot.img

## flash_vbmeta
$ avbtool make_vbmeta_image --flags 2 --padding_size 4096 --output /vbmeta.img
$ fastboot flash vbmeta /vbmeta.img
$ rm -f /vbmeta.img

## flash_dtbo
# ERROR: $PARTITION_DTBO es None (deviceinfo no define partition dtbo)

## boot (no flashea, solo bootea)
$ fastboot --cmdline clk_ignore_unused boot /mnt/rootfs_xiaomi-laurel/boot/boot.img
```

Notas de la transcripción:
- `flash_dtbo` **no existía** en el flujo histórico: pmbootstrap fallaría si se
  invocara. El `fastboot erase dtbo` de la guía se ejecutaba a mano (root) y
  por separado.
- `flash_rootfs` usa `$IMAGE` = `/home/pmos/rootfs/xiaomi-laurel.img`
  (imagen completa, no split).
- `$FLAVOR=""` → boot.img sin sufijo de flavor.

## Mocks preparados (dry-run sin dispositivos)

`local-private/historical-port/mock-bin/`:
- `fastboot`: registra comandos de escritura (flash/erase/reboot/set_active/
  boot/format/continue/oem/update) en `$MOCK_FASTBOOT_LOG` y devuelve OK
  ficticio; delega lecturas al fastboot real si existe.
- `mkbootimg-osm0sis`: registra la invocación y crea boot.img v0
  (header 2048 + kernel + ramdisk).
- `avbtool`: registra y crea vbmeta.img relleno a `--padding_size`.

Uso: `MOCK_FASTBOOT_LOG=... PATH=.../mock-bin:$PATH pmbootstrap flasher flash_kernel`
en un entorno pmbootstrap 1.50.0 (CI). Este mock NO se usará contra el
dispositivo real.

## Hallazgo central

La variante **IT3** que ya probamos (append_dtb=true, qcdt=false, dtb_size=0,
base=0x00000000, cmdline clk_ignore_unused) es **estructuralmente idéntica** al
boot.img que pmbootstrap/boot-deploy generaban en 2022. Por tanto, el retorno a
Fastboot de IT3 indica que el problema NO está en el formato del boot.img
(ya fiel al histórico), sino en algo del arranque real (kernel, aboot, slot,
AVB, dtbo) — ver `reports/h1-flash-boot-result.md`.

## Fuentes congeladas nuevas (R3)

| Paquete | Versión | Tarball local | SHA256 |
|---|---|---|---|
| postmarketos-mkinitfs | 1.5.1 | sources/postmarketos-mkinitfs-1.5.1.tar.gz | `947981964cf018b794c568adc58592cb87dfde5b35c4fcdc9e2e85a41a7a3be3` |
| boot-deploy | 0.6.1 | sources/boot-deploy-0.6.1.tar.gz | `28b8b6b56bd2634968ca6b7bc4e3d3c1a2903676b1c65178c4ef889426b7a02d` |

`sources.lock.json` actualizado (15 fuentes).
