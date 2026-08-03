# DECISION-0003 — Configuración del kernel por fragments (no defconfig upstream)

- Estado: **Propuesta**
- Fecha: 2026-08-02

## Contexto

`sm61x5-mainline` no provee `sm61x5_defconfig` (verificado 2026-08-02).
Los kernels de postmarketOS se configuran combinando `postmarketos-base.
defconfig` (pmaports) con fragments específicos del dispositivo.

## Decisión

La configuración se construye como:

```
pmaports/linux-postmarketos-qcom-sm6125 (base del SoC)
+ configs/kernel/laurel-base.fragment
+ configs/kernel/laurel-debug.fragment    (solo builds de depuración)
+ configs/kernel/laurel-release.fragment  (solo releases)
```

Los fragments existentes (`configs/kernel/laurel-*.fragment`) se revisan y
ajustan contra la base real de pmaports durante 03-build-kernel. El estado se
registra en `reports/kernel-candidates.json`.

## Consecuencias

- Mayor control que una defconfig fija.
- Cada fragment debe documentarse; `verify-kconfig.sh` valida símbolos clave.
- El resultado es reproducible porque la base de pmaports está fijada por
  commit en `sources.lock.json`.

## Alternativas consideradas

- Escribir una defconfig completa propia: descartado (mantenimiento alto).
- Usar `barni2000/6.19-develop` por su defconfig: rechazado como base (rama
  de desarrollo).
