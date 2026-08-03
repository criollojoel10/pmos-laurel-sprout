# Estado del hardware

Estado honesto de cada componente. Los estados permitidos son únicamente:

`not-targeted`, `source-available`, `configured`, `compiled`, `packaged`,
`static-validation-passed`, `boot-untested`, `detected`, `partially-working`,
`working`, `blocked`, `regressed`.

La referencia canónica es `reports/hardware-matrix.json`. Este documento la
resume y explica los criterios.

## Estado actual (inicial)

| Componente | Estado | Notas |
|---|---|---|
| Pantalla / DRM-KMS | `not-targeted` | Sin kernel ni prueba física aún. |
| GPU Adreno 610 | `source-available` | Firmware confirmado: `firmware-qcom-adreno-a610` (subpackage) + `a630_sqe.fw` (2026-08-03). Sin kernel ni prueba física. |
| Táctil FT3518 | `not-targeted` | Sin prueba física aún. |
| Wi-Fi | `not-targeted` | Por determinar modelo/bus/firmware. |
| Bluetooth | `not-targeted` | Por determinar modelo/bus/firmware. |
| UFS | `not-targeted` | Sin prueba física aún. |
| USB gadget | `not-targeted` | Sin prueba física aún. |
| Batería / térmicas / CPUfreq | `not-targeted` | Sin prueba física aún. |
| Audio | `not-targeted` | Prioridad secundaria. |
| Módem | `not-targeted` | Prioridad secundaria. |
| Cámara | `not-targeted` | Prioridad secundaria. |

## Criterios de `working`

### GPU (Adreno 610)
1. `/dev/dri/card0` existe.
2. `/dev/dri/renderD128` existe.
3. El firmware Adreno se carga correctamente.
4. Sin fallo fatal de IOMMU, GMU, clocks ni regulators.
5. `eglinfo` identifica Freedreno.
6. El renderer no es llvmpipe.
7. `glmark2-es2-wayland` completa una prueba.
8. KWin inicia con aceleración.

### Pantalla
1. El kernel enlaza el panel con el driver correcto.
2. DRM/KMS crea un conector activo.
3. Hay imagen estable.
4. La orientación es correcta.
5. El brillo funciona.
6. Apagar y encender la pantalla funciona.
7. No hay corrupción visual persistente.

### Táctil (FT3518)
1. FT3518 es detectado.
2. Se crea `/dev/input/event*`.
3. `libinput debug-events` recibe coordenadas.
4. Las coordenadas coinciden con la orientación.
5. Multitouch básico funciona.

### Wi-Fi
1. El controlador aparece.
2. El firmware carga.
3. La calibración carga correctamente.
4. Se crea la interfaz.
5. Escanea redes.
6. Se asocia.
7. Obtiene dirección IP.
8. Mantiene conexión estable.

### Bluetooth
1. El controlador es detectado.
2. El firmware carga.
3. `bluetoothctl` muestra el adaptador.
4. El escaneo funciona.
5. El emparejamiento funciona.

## Advertencias

No confundir:

- KGSL Android con DRM/MSM mainline.
- Pantalla funcional con GPU funcional.
- DPU funcional con aceleración 3D funcional.
- llvmpipe con aceleración GPU.
- Configuración Kconfig con funcionamiento físico.
- Compilación exitosa con port terminado.

La existencia de un nodo GPU en el DTB NO implica GPU funcional.
