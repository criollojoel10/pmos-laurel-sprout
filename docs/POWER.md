# Energía

Estado: **parcialmente configurado, sin funcionamiento runtime demostrado**.
En la captura 6.1 del 2026-08-10 no hubo power-supply de batería, zonas
térmicas activas ni sysfs cpufreq. No se declara hardware funcional por tener
los símbolos Kconfig compilados.

## Objetivos

- Lectura de batería (power supply).
- Carga (cuando exista soporte mainline).
- Regulación térmica.
- CPUfreq.
- CPUidle.
- Suspensión cuando sea técnicamente viable.

## Estado runtime conocido

- PMI632: sin driver dedicado de batería/cargador en la base v7.1 actual.
- Thermal: `QCOM_TSENS` y alarma SPMI configurados; 0 zonas activas en 6.1.
- CPUfreq: `ARM_QCOM_CPUFREQ_HW` y `CPUFREQ_DT` configurados; sin sysfs
  cpufreq activo en 6.1.

## Kconfig relevante

- `POWER_SUPPLY`
- `THERMAL`
- CPUfreq / CPUidle de Qualcomm
- battery/charger cuando exista soporte

La siguiente investigación debe contrastar nodos PMIC, thermal-zones, OPPs,
reguladores y secuencia de carga con el DT Android. No se declara `working`
sin prueba física y evidencia de sysfs/lecturas reales.
