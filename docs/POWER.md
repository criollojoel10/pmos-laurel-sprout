# Energía

Estado: **inicial**. Sin prueba física aún.

## Objetivos

- Lectura de batería (power supply).
- Carga (cuando exista soporte mainline).
- Regulación térmica.
- CPUfreq.
- CPUidle.
- Suspensión cuando sea técnicamente viable.

## Kconfig relevante

- `POWER_SUPPLY`
- `THERMAL`
- CPUfreq / CPUidle de Qualcomm
- battery/charger cuando exista soporte

La configuración física (reguladores, thermistors, nodos DT) se documentará
tras la investigación upstream. No se declara `working` sin prueba física.
