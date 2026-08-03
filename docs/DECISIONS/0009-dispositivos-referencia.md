# DECISION-0009 — Dispositivos de referencia para configuración y firmware

- Estado: **Aceptado**
- Fecha: 2026-08-02

## Contexto

Para acelerar la configuración (fragments), firmware y deviceinfo del
laurel_sprout, se usan dispositivos ya soportados en postmarketOS con el
mismo SoC (SM6115/SM6125) o GPU (Adreno 610).

## Decisión

Candidatos de referencia (verificados su existencia en `docs/DEVICE-COMPARISON.md`):

| Dispositivo | SoC | GPU | Uso |
|---|---|---|---|
| sofia (Redmi 6A) | SM6115 | Adreno 610 | config, firmware GPU |
| ginkgo (Redmi Note 8) | SM6125 | Adreno 610 | config SM6125 |
| willow (Redmi Note 8T) | SM6125 | Adreno 610 | config SM6125 |
| pdx201 (Xperia 10 II) | SM6125 | Adreno 610 | referencia mainline |
| doha (Xperia 10 III) | SM7225 | Adreno 619 | relativo, no directo |

La auditoría (workflow 01) registra qué dispositivos existen realmente en
pmaports main y sus `deviceinfo` (`reports/device-comparison.md`).

## Consecuencias

- La configuración del kernel se basa en la defconfig de pmaports para
  SM6125, no en suposiciones.
- El firmware Adreno A610 se toma de `firmware-qcom-adreno-a610` si existe
  en pmaports (verificado en la auditoría).

## Alternativas consideradas

- Ignorar referencias y partir de cero: rechazado (más lento y propenso a
  error).
