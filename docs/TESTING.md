# Pruebas

Metodología de prueba física del port. La FASE 8 (punto de parada) es
obligatoria antes de tocar el dispositivo.

## Reglas

- Toda prueba física requiere autorización explícita, respaldos previos y un
  plan de recuperación.
- El kernel y rootfs se prueban primero en la imagen **console**
  (recuperación), antes de Plasma Mobile.
- `fastboot boot` (temporal) es la prueba preferida si es compatible.
- Probar UNA variable a la vez (boot, luego dtbo, luego vbmeta; nunca juntas).
- Registrar exactamente lo ejecutado.
- Tener otra terminal observando USB durante la prueba.

## Escenario de prueba incremental

1. `fastboot boot boot-laurel-debug.img` con imagen console.
2. Verificar `dmesg`, SSH, USB networking, `/dev/dri`, input, firmware.
3. Recoger logs con `scripts/process-device-logs.sh` (sanitizados).
4. Subir logs al workflow `08-process-device-logs` para análisis automático.
5. Solo después: probar Plasma Mobile.
6. Actualizar `reports/hardware-matrix.json` con estados honestos.

## Qué medir (según docs/HARDWARE-STATUS.md)

- GPU: `eglinfo`, `glmark2-es2-wayland`, presencia de `renderD128`.
- Pantalla: conector DRM activo, orientación, brillo, suspensión de pantalla.
- Táctil: `libinput debug-events`, multitouch.
- Wi-Fi/Bluetooth: `nmcli`, `bluetoothctl`.
- Energía: batería, térmicas, CPUfreq, suspensión.

## Recolección de logs

Los logs se recogen en el dispositivo y se suben SANITIZADOS:
`scripts/sanitize-logs.sh` elimina serial, IMEI, MAC y otros identificadores
antes de publicar.

## Estados resultantes

Tras cada prueba, actualizar hardware-matrix.json con uno de los estados
permitidos. Nada se declara `working` sin cumplir todos los criterios de
`docs/HARDWARE-STATUS.md`.
