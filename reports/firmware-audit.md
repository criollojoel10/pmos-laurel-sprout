# Auditoría de firmware

Generado: 2026-08-03

Componentes de radio/vendedor necesarios para laurel_sprout:

- GPU: firmware-qcom-adreno-a610 (paquete pmaports: no localizado en main)
- WLAN/BT: WCN3990 (qca6390 / qcom/wcn3990*)
- Modem: mba.mbn + qdsp6.mbn (SM6125/trinket)
- ADSP/CDSP: adsp.mbn, cdsp.mbn
- Venüs: venus-*.mbn (solo si se usa Venus HW codec)

Origen: deviceinfo/lk2nd y firmware stock (Xiaomi Mi A3). No se
redistribuye firmware sin verificación de licencia.

Verificación local pendiente en workflow build:
- licencias de cada blob en linux-firmware
- correspondencia con configs/firmware/firmware-manifest.json
