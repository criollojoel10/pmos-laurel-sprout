# Wi-Fi y Bluetooth

Estado: **inicial**. Los modelos, buses y firmware exactos están POR
DETERMINAR mediante fuentes verificadas (investigación upstream). No se asume
nada sobre el módulo inalámbrico.

## Wi-Fi

Criterios de `working` (ver `docs/HARDWARE-STATUS.md`):
controlador, firmware, calibración, interfaz, escaneo, asociación, IP y
conexión estable.

## Bluetooth (BlueZ)

Criterios de `working`:
controlador detectado, firmware carga, `bluetoothctl` muestra adaptador,
escaneo y emparejamiento.

## Por determinar

- Modelo de chip WLAN/Bluetooth del Mi A3.
- Bus (SDIO/UART/USB/PCIe interno).
- Firmware requerido y su clasificación (ver
  `configs/firmware/firmware-manifest.json`).
- Configuración Kconfig necesaria.

La información se actualizará tras `01-research-upstream` y la comparación con
el Device Tree Android de `lineageos/android_kernel_xiaomi_sm6125`.
