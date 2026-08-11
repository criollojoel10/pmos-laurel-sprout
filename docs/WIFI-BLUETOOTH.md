# Wi-Fi y Bluetooth

Estado: **bloqueado para funcionamiento**. La captura runtime del kernel 6.1
del 2026-08-10 no mostró `mmc_host`, bus SDIO, `wlan0` ni `hci0`. La matriz
identifica el módulo como WCN3990 por SDIO, pero esta hipótesis aún debe
corroborarse contra el DT Android y el esquemático/firmware del dispositivo.

## Wi-Fi

Criterios de `working` (ver `docs/HARDWARE-STATUS.md`):
controlador, firmware, calibración, interfaz, escaneo, asociación, IP y
conexión estable.

## Bluetooth (BlueZ)

Criterios de `working`:
controlador detectado, firmware carga, `bluetoothctl` muestra adaptador,
escaneo y emparejamiento.

## Por determinar / investigar

- Nodo exacto del WCN3990 y secuencia de power/reset en el DT Android.
- Host SDIO/MMC y reguladores necesarios en mainline.
- Firmware requerido y su clasificación (ver
  `configs/firmware/firmware-manifest.json`).
- Driver correcto: no asumir que `ATH10K_SNOC`, `WCN36XX` o `BT_QCOMSMD`
  bastan sin que exista el transporte.

La información se actualizará tras comparar el Device Tree Android de
`lineageos/android_kernel_xiaomi_sm6125` con el DTS v7.1 y obtener una captura
de `dmesg`, `mmc`, firmware y `rfkill` desde un boot real.
