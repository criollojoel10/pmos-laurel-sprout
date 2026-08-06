# Reporte R11 — Kit de reproducción histórica (contenido + dry-run)

Fecha: 2026-08-05. Kit completo sin necesidad de dispositivo ni de builds
pesados para reproducir la LÓGICA del flujo.

## Contenido del kit (`local-private/historical-port/`)

```
mock-bin/
  fastboot            # mock: registra comandos de escritura, no los ejecuta
  mkbootimg-osm0sis   # mock: genera boot.img v0 (header 2048 + kernel + ramdisk)
  avbtool             # mock: genera vbmeta.img relleno a --padding_size
sources/              # fuentes congeladas y verificadas (R1/R3)
  deviceinfo-xiaomi-laurel.a27a7ce.txt
  APKBUILD-* (device, linux-sm6125 6.0/6.1)
  config-postmarketos-qcom-sm6125.aarch64.{a27a7ce,7aaee51a}
  pmb-*.py            # pmbootstrap 1.50.0 (flasher, variables, config, initfs)
  postmarketos-mkinitfs-1.5.1/        (código fuente + tarball)
  boot-deploy-0.6.1/                  (código fuente + tarball)
artifacts/
  vbmeta-historical-pmos-flags2.img   # vbmeta histórico reproducido (flags=2, 4096 B)
logs/
  flasher-dry-run-transcript.{txt,json}
reproduce-flasher-commands.py         # dry-run determinista del flasher
```

## Dry-run verificado

```
python3 reproduce-flasher-commands.py
```

Produce la transcripción EXACTA de comandos de pmbootstrap 1.50.0 (ver
`logs/flasher-dry-run-transcript.txt`). Coincide línea a línea con el código
congelado (variables + acciones del diccionario `flashers["fastboot"]`).

Verificación independiente del dry-run contra el binario real (opcional):
ejecutar pmbootstrap 1.50.0 en CI con `PATH=.../mock-bin:$PATH` y
`MOCK_FASTBOOT_LOG=...` y comparar las líneas `[MOCK-FASTBOOT]` con el
transcript. El mock devuelve OK sin tocar el dispositivo.

## Reproducción histórica del vbmeta (R5, hecho localmente)

```
avbtool make_vbmeta_image --flags 2 --padding_size 4096 \
    --output artifacts/vbmeta-historical-pmos-flags2.img
```

Verificado con `avbtool info_image`: Flags=2, Algorithm NONE, 4096 B — igual
que generaba pmbootstrap 1.50.0 en el chroot.

## Qué falta para la reproducción COMPLETA (builds pesados → CI)

1. Kernel 6.1 `77de535b` → Image.gz + DTB (build CI; APKBUILD congelado).
2. boot.img histórico = `mkbootimg-osm0sis` con los offsets del deviceinfo
   (paso 3 del pipeline R3) a partir de (1) + initramfs.
3. rootfs pmOS histórico (pmbootstrap 1.50.0 install → `xiaomi-laurel.img`) y
   adaptación a `system_b` (R4).
4. (Opcional) verificador de integridad del kit en CI con los mocks.

## Integridad

SHA256 registrados en `sources.lock.json` (15 fuentes) y en los reportes
R1/R3. Los tarballs `postmarketos-mkinitfs-1.5.1.tar.gz` y
`boot-deploy-0.6.1.tar.gz` se conservan intactos en `sources/`.
