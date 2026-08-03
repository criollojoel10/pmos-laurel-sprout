# DECISION-0008 — APKBUILD preliminar propio (linux-postmarketos-qcom-sm6125)

- Estado: **Propuesta**
- Fecha: 2026-08-02

## Contexto

El port archivado `xiaomi-laurel` de pmaports (MR 3105) usaba el kernel
histórico `linux-xiaomi-laurel` (6.1-sm6125). El árbol moderno
`sm61x5-mainline` aún no está empaquetado oficialmente para postmarketOS
(issue #1 sin release).

## Decisión

Mantener en este repositorio un APKBUILD preliminar
`device/linux-postmarketos-qcom-sm6125/APKBUILD` que:
- fija el commit base en `sources.lock.json` (rama `master`,
  `7a52441d...`);
- define DTB `qcom/sm6125-xiaomi-laurel-sprout.dtb`;
- se ajusta cuando exista el paquete oficial de pmaports.

El `deviceinfo` de referencia se toma del port archivado y se revisa contra
la metadata real del dispositivo (`device-metadata/fastboot-sanitized.json`).

## Consecuencias

- Permite builds reproductibles sin depender del release de sm61x5-mainline.
- `scripts/audit-patches.sh` verifica que los parches aplicados no dupliquen
  parches ya en el commit fijado.

## Alternativas consideradas

- Esperar el release oficial de sm61x5-mainline: rechazado (bloquea el
  proyecto indefinidamente).
- Reusar `linux-xiaomi-laurel` (6.1): descartado como base (kernel antiguo).
