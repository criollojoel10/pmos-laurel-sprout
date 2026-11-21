# Kupfer + Phosh para laurel — artefacto del 2026-11-21

- Workflow: `26-build-kupfer` (run **44848808710**, `main` `9dfe7f5`, perfil **phosh**).
- Estado del run: **success**, todas las validaciones del workflow verdes.
- Artefacto: **`kupfer-laurel-phosh`** (1.826 GB, id 14684264955, caduca 2026-11-28).
- Prueba en hardware: **pendiente** (este informe no la declara).

## Ficheros

| Fichero | Bytes | SHA-256 |
|---|---:|---|
| `boot.img` | 41 869 312 | `ce4c7de5d7fc67d0eb8f09c39e34b5616b68a2691ff85a36b1a72e014118edb6` |
| `vbmeta.img` | 4 096 | `e9f0f23cf362fd9ed921ef7da04716e987370949cef7480d26afc60fd761bf5b` |
| `rootfs.img.zst` | 1 786 173 037 | `dda2819a7bc7a8487aaa3b16c1d90c757a3bb5c1dc4e5b02306685f9b7e73947` |

`rootfs.img` sin comprimir: 8 359 247 872 B (ext4 raw, label `kupfer_root`,
sector 4096). El `fstab` ya lleva `nofail` para `kupfer_boot` y el override de
emergencia.

## Qué valida el workflow (todo verde)

- `packages check` de `linux-sm61x5`, `device-sm61x5-xiaomi-laurel`,
  `firmware-sm61x5-xiaomi-laurel` y `mia3-support`.
- Paquete `linux-sm61x5` con `mia3_qg.ko`, `mia3_dtbo.ko`, `mia3_adsp.ko`,
  `pmi632_chg.ko`, `q6core.ko`, `q6asm-dai.ko`, `snd-soc-sm8250.ko` y el DTB
  `k7` (`qcom/sm6125-xiaomi-laurel-sprout.dtb`).
- Rootfs con `deviceinfo`, `/home/user`, `sshd`, los cuatro `.dtbo` de
  `mia3-support`, `a630_sqe.fw`, `a610_zap.mbn`, `wlanmdsp.mbn`, `adsp.mdt`,
  `qbootctl` y las unidades `qbootctl`, `mia3-qg`, `mia3-audio`, `chargectl` y
  `mia3-wifi` habilitadas.
- `boot.img` con firma `ANDROID!`; initramfs generado; `aboot.img` regenerado
  por `update-bootimg`.

## Cómo probar

1. Descargar el artefacto (desde el PC con fastboot):

   ```sh
   gh run download 44848808710 -R criollojoel10/pmos-laurel-sprout \
     -n kupfer-laurel-phosh
   cd kupfer-laurel-phosh
   sha256sum -c SHA256SUMS
   zstd -d rootfs.img.zst
   ```

2. Flashear al **slot b** (Android del slot a intacto), según
   `docs/FLASH-LAUREL-CACHYOS.md`:

   ```sh
   fastboot flash vbmeta_b vbmeta.img
   fastboot erase dtbo_b
   fastboot flash userdata rootfs.img
   fastboot flash boot_b boot.img
   fastboot set_active b
   fastboot reboot
   ```

3. Tras el arranque (`user` / `changeme`, `172.16.42.1`):

   ```sh
   ssh user@172.16.42.1 'sh -s' < scripts/verify-kupfer-laurel.sh
   ```

4. Si algo falla, recuperación: `fastboot set_active a && fastboot reboot`.

## Honestidad

Los componentes individuales (pantalla, GPU, Wi-Fi, batería, táctil, Plasma) se
validaron en hardware el 2026-10-17; el altavoz inferior se validó en el port de
referencia el 2026-10-13. **Esta imagen concreta (Phosh + audio integrado en el
build) aún no se ha arrancado en el teléfono.**
