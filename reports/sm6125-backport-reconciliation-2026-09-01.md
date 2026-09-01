# Reconciliación de backports sm6125 — 2026-09-01

## Parches relevantes del repositorio

- `patches/kernel/0001-dts-mdss-panel-s6e8fc0.patch`
- `patches/kernel/0002-dtsi-gpu-adreno610.patch`
- `patches/kernel-61/0004-dts-sm6125-add-rmtfs-mem.patch`

## Categorización

### 1. reserved-memory / rmtfs

- Estado: `CLEAN_BACKPORT` en la línea base 6.1 del proyecto.
- Evidencia: el patch `0004-dts-sm6125-add-rmtfs-mem.patch` añade la región `rmtfs-mem` requerida por `qcom_rmtfs_mem`.
- Riesgo: medio. Puede afectar a la cadena del modem, pero el parche ya tiene evidencia de necesidad y no es arbitrario.

### 2. FT3518 touch

- Estado: `NEEDS_ADAPTATION`.
- Evidencia: el repositorio documenta FT3518, `focaltech,ft3518`, y `edt-ft5x06`, pero el sistema actual no presenta `/dev/input/event*` ni probe del bus.
- Riesgo: alto si se integra sin validar `i2c2`, GPIO, VDD y IRQ.

### 3. OTG / Type-C / VBUS

- Estado: `CLEAN_BACKPORT` o `NEEDS_ADAPTATION` según el árbol concreto.
- Evidencia: el repositorio documenta que `dr_mode=peripheral` bloquea host mode y que el port de laurel exige `otg` + VBUS + Type-C.
- Riesgo: medio, dependerá de `usb-role-switch` y del árbol del kernel actual.

### 4. display / DRM / DSI / panel

- Estado: `NEEDS_ADAPTATION`.
- Evidencia: solo existe simple-framebuffer; el driver del panel no está cargado y no aparece `DRM`.
- Riesgo: alto. La diferencia entre framebuffer y DRM/KMS es un punto crítico.

### 5. Adreno 610

- Estado: `BLOCKED_BY_DEPENDENCY`.
- Evidencia: el repositorio ya documenta que el GPU no está validado y requiere DRM/KMS estable primero.
- Riesgo: alto. GPU no debe tratarse como objetivo principal antes de resolver display/DSI.

## Orden recomendado

1. reserved-memory / rmtfs
2. FT3518 / GPIO / regulators / i2c2
3. OTG / role switch / VBUS
4. display / DSI / panel / DRM
5. Adreno 610
6. Wi-Fi / BT
7. audio
8. modem
9. suspensión y batería
