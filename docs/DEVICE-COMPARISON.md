# Comparativa de dispositivos de referencia

Estado: actualizado con CI (2026-08-03, run 30775362988, commit f9e3513).

## Criterio de selección

Dispositivos ya soportados en postmarketOS con:
- mismo SoC SM6115/SM6125 (trinket), o
- misma GPU Adreno 610, o
- mismo combo WLAN/BT WCN3990.

## Candidatos

| Dispositivo | Código | SoC | GPU | WLAN/BT | Relevancia |
|---|---|---|---|---|---|
| Redmi 6A | sofia | SM6115 | Adreno 610 | WCN3990 | config + firmware GPU |
| Redmi Note 8 | ginkgo | SM6125 | Adreno 610 | ? | config SM6125 |
| Redmi Note 8T | willow | SM6125 | Adreno 610 | ? | config SM6125 |
| Xperia 10 II | pdx201 | SM6125 | Adreno 610 | WCN3990 | referencia mainline |
| Xperia 10 III | doha | SM7225 | Adreno 619 | ? | relativo |

## Qué se extrae de cada uno

- `deviceinfo` completo (arch, soc, chassis, flash_method, bootimg).
- Fragment de kernel en pmaports (si existe).
- Paquete de firmware (`firmware-qcom-adreno-a610`, etc.).
- DTS mainline (si está soportado).

## Estado en pmaports main (confirmado por CI)

- `device-xiaomi-willow` (Redmi Note 8T): **presente** en main → fuente de
  config SM6125 y deviceinfo.
- `device-xiaomi-laurel` (Mi A3): presente (port **archivado** en
  `device/archived/device-xiaomi-laurel`); solo deviceinfo, sin
  kernel_apkbuild ni firmware.
- `device-xiaomi-ginkgo` / `device-xiaomi-sofia`: **NO localizados** en main.
- Sony pdx201/doha no aparecen en la lista de `device-xiaomi-*`; se revisan
  con prefijo `device-sony-*` en una iteración posterior si hacen falta.
