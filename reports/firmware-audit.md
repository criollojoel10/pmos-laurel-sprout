# Auditoría de firmware

Generado: 2026-08-03
Actualizado: 2026-08-03 (corrección H5: firmware Adreno A610)

## GPU Adreno 610 — firmware-qcom-adreno-a610 (CORREGIDO)

Hallazgo inicial erróneo: "no localizado en main". La búsqueda solo miraba
directorios con el nombre exacto `firmware-qcom-adreno-a610` y no detectaba
subpackages generados.

Realidad (confirmado el 2026-08-03):

- El paquete padre es `firmware-qcom-adreno`
  (`device/community/firmware-qcom-adreno/APKBUILD`, mantenido por Marijn
  Suijten).
- `firmware-qcom-adreno-a610` es un SUBPACKAGE generado desde ese APKBUILD,
  no un directorio independiente.
- El subpackage `a610` es un METAPAQUETE VACÍO: instala solo el directorio
  `/usr/lib/firmware/qcom/` y declara `depends="firmware-qcom-adreno-a630-sqe"`.
- `firmware-qcom-adreno-a630-sqe` instala `qcom/a630_sqe.fw`. El A610 no tiene
  GMU; el driver MSM mainline carga `a630_sqe.fw` como SQE para la familia
  a610.
- pkgver=20260110, pkgrel=1, arch="aarch64 armv7", license="custom".
- Índice oficial pkgs.postmarketos.org: `firmware-qcom-adreno-a610`
  20260110-r1, origin `firmware-qcom-adreno`, inst. size 1.0B, depends
  firmware-qcom-adreno-a630-sqe.

linux-firmware (tag 20260110, commit 06a743fd69999590e88199bb9edba9d5b73d6ad1):
- `qcom/a630_sqe.fw` presente (sha256 1c21b527d9183487cc550dabbb3f43e555df5a977a461934fc61f0635a9aa90c).
- No existen `a610_*` bins en qcom/ (a610 sin GMU, usa SQE compartido).
- `a612_rgmu.bin` y `a630_gmu.bin` presentes (no usados por SM6125/a610).

## Otros componentes

- WLAN/BT: WCN3990 (qca6390 / qcom/wcn3990*)
- Modem: mba.mbn + qdsp6.mbn (SM6125/trinket)
- ADSP/CDSP: adsp.mbn, cdsp.mbn
- Venüs: venus-*.mbn (solo si se usa Venus HW codec)

Origen: deviceinfo/lk2nd y firmware stock (Xiaomi Mi A3). No se
redistribuye firmware sin verificación de licencia.

Verificación local pendiente en workflow build:
- licencias de cada blob en linux-firmware
- correspondencia con configs/firmware/firmware-manifest.json
