# Comparativa de dispositivos de referencia

Estado: registro inicial (2026-08-02). Los datos reales de pmaports se
completan con el workflow 01 (`reports/device-comparison.md`).

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

## Estado

Pendiente de completar en CI: `reports/device-comparison.md`.
