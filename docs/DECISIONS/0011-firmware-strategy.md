# DECISION-0011 — Estrategia de firmware para laurel_sprout

- Estado: **Aceptado**
- Fecha: 2026-08-03

## Contexto

Corrección de la hipótesis H5: la primera auditoría (workflow 01) declaró
`firmware-qcom-adreno-a610` como "no localizado en main" porque la búsqueda
solo miraba directorios con ese nombre exacto. El paquete real es un
subpackage generado desde un APKBUILD padre.

## Hallazgos verificados (2026-08-03)

- `firmware-qcom-adreno-a610` es subpackage del APKBUILD padre
  `firmware-qcom-adreno` en pmaports main
  (`device/community/firmware-qcom-adreno/APKBUILD`).
- Es un metapaquete vacío: instala `/usr/lib/firmware/qcom/` y depende de
  `firmware-qcom-adreno-a630-sqe`.
- `firmware-qcom-adreno-a630-sqe` instala `qcom/a630_sqe.fw`. El A610 no tiene
  GMU; el driver MSM carga `a630_sqe.fw` como SQE.
- Índice oficial pkgs.postmarketos.org: 20260110-r1, origin
  `firmware-qcom-adreno`, inst. size 1.0B, armv7 + aarch64.
- linux-firmware tag 20260110 (commit 06a743fd69999590e88199bb9edba9d5b73d6ad1):
  `qcom/a630_sqe.fw` presente (sha256
  1c21b527d9183487cc550dabbb3f43e555df5a977a461934fc61f0635a9aa90c); no hay
  bins `a610_*`.

## Decisión

1. Usar `firmware-qcom-adreno` (que genera el subpackage a610 + a630-sqe)
   como fuente del firmware GPU para laurel_sprout.
2. Verificar la presencia de `qcom/a630_sqe.fw` en el manifest de firmware
   (`configs/firmware/firmware-manifest.json`) para SM6125.
3. No empaquetar firmware A610 propio desde linux-firmware mientras el
   paquete pmaports cubra la necesidad (a630_sqe.fw).
4. El firmware propietario de radio (modem/adsp/cdsp/venus) se extrae del
   stock/Lineage por el usuario, NO se sube al repo (AGENTS.md §1).
5. La búsqueda de paquetes en auditorías debe detectar subpackages
   (leer `subpackages=` del APKBUILD padre), no solo directorios.

## Consecuencias

- H5 pasa a `confirmed`.
- El workflow 01 queda con una regresión: detecta subpackages generados.
- El A610 no requiere GMU propio ni zap shader; el driver MSM maneja la
  ausencia de zap con `-ENODEV` y `SECVID_TRUST_CNTL`.

## Alternativas consideradas

- Empaquetar firmware a610 propio en este repo: rechazado (duplica el
  mantenimiento y el paquete pmaports ya cubre la necesidad).
- Tratar "no hay directorio" como "no existe": rechazado (causa del error H5).
