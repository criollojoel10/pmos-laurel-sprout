# Baseline 6.1 → mainline 7.1

Fecha: 2026-08-11. Fuente 6.1: captura root SSH de solo-lectura en
`local-private/diagnostics/ssh-live/`. Fuente 7.1: kernel run `31447941911` y
boot diagnóstico run `31458775118`. El estado 7.1 sigue siendo estático hasta
una prueba física.

| Área | Evidencia 6.1 | Estado 7.1 | Próxima acción |
|---|---|---|---|
| Display bring-up | `simplefb registered`, fb0 720x1560, stride 2880 | `packaged` con `FB_SIMPLE=y`, DTB framebuffer y `consoleblank=0` | Prueba física M8; esperar consola visible |
| DRM/KMS | `DRM_MSM=m`, no cargado, sin `/dev/dri` | `compiled` como `msm.ko`, no probado | No cargar en M8; investigar probe en M9 |
| GPU/3D | No probada, sin DRM runtime | DT A610, módulo MSM y firmware referenciado | Probe MSM, firmware, `/dev/dri`, Freedreno, no llvmpipe |
| UFS | `ufshcd-qcom` detecta Samsung KM5V7001DM-B621 | Kconfig/DT built-in, sin boot físico | Confirmar UFS en primer boot 7.1 |
| USB gadget | RNDIS/`usb0`/SSH funcionando | DWC3/QCOM + legacy RNDIS + initramfs telnet preparados | Confirmar enumeración y SSH/telnet en 7.1 |
| USB OTG host | No: `dr_mode=peripheral`, sin xHCI runtime | DTS aún no resuelve rol/VBUS | Separar M7: `dr_mode=otg`, VBUS, extcon/Type-C |
| Wi-Fi | Sin MMC/SDIO, `wlan0` ausente | No basta `ATH10K_SNOC`/`WCN36XX` | Identificar transporte, host SDIO, power/reset y firmware |
| Bluetooth | Sin `hci0`, sin transporte | `BT_QCOMSMD` compilado, no probado | Resolver UART/SDIO/firmware y registrar hci0 |
| Táctil | Sin input runtime | Driver FT3518 compilado y DT presente | Detectar `/dev/input/event*` en 7.1 |
| Batería | Sin `power_supply` | No hay driver PMI632 dedicado validado | Auditar PMIC, charger, ADC y power-supply |
| Térmicas | 0 thermal zones | Kconfig preparado, sin runtime | Auditar `thermal-zones`, TSENS y sensores PMIC |
| CPUfreq | Sin sysfs cpufreq | Kconfig preparado, sin runtime | Auditar OPPs, `ARM_QCOM_CPUFREQ_HW` y clocks |
| SSH | Root por clave, password SSH deshabilitada | Initramfs ofrece canal diagnóstico temporal | Usar solo para logs; no declararlo rootfs 7.1 |

## Orden de trabajo

1. M8: prueba del boot simplefb v7.1, sin activar MSM.
2. Si hay consola/RNDIS: capturar dmesg 7.1 y comparar con este baseline.
3. M9: activar y depurar MSM/GPU después de tener display observable.
4. M7: resolver OTG host y VBUS en paralelo con consola 6.1.
5. Wi-Fi/BT y energía: primero cerrar hardware/DT/bus, después ajustar Kconfig.
6. pmOS console y Plasma Mobile solo después de display estable, táctil y
   canal de diagnóstico.
7. Kupfer: empaquetar únicamente lo que tenga evidencia estable en pmOS.

## Regla de clasificación

`compiled`/`packaged` no implica `working`. Para elevar un componente se exige
evidencia runtime concreta: nodo/dispositivo, firmware, interfaz y prueba
funcional correspondiente.
