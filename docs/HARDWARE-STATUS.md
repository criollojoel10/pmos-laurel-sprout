# Estado del hardware

Estado honesto de cada componente. Los estados permitidos son únicamente:

`not-targeted`, `source-available`, `configured`, `compiled`, `packaged`,
`static-validation-passed`, `boot-untested`, `detected`, `partially-working`,
`working`, `blocked`, `regressed`.

La referencia canónica es `reports/hardware-matrix.json`. Este documento la
resume y explica los criterios.

## Estado actual (2026-08-09)

| Componente | Estado | Notas |
|---|---|---|
| Pantalla / DRM-KMS | `detected` | DTS MDSS+DSI+PHY habilitado y panel `samsung,s6e8fc0-m1906f9` en DTB compilado (mainline v7.1 + parche 0001). PRUEBA FÍSICA EX3 (kernel 6.1, slot b): imagen en pantalla; tras el fix sedfix, `INITRAMFS_REACHED` + rescue shell con consola visible y estable. Falta GPU 3D y entorno completo para `working`. |
| GPU Adreno 610 | `source-available` | Firmware confirmado: `firmware-qcom-adreno-a610` (subpackage) + `a630_sqe.fw` (2026-08-03). Nodos GPU (gpu@5900000, gmu_wrapper, gpucc, adreno_smmu) añadidos al DTSI/DTS (parches 0002/0003); DTB compilado. Sin boot. |
| Táctil FT3518 | `compiled` | Driver `edt-ft5x06` (FT3518) en fragmento base; DTS touch habilitado (parche 0001). Sin boot. |
| Wi-Fi | `source-available` | `ATH10K_SNOC` (WCN3990) y `WCN36XX` en fragmento base; modelo real por confirmar en boot. |
| Bluetooth | `source-available` | `BT_QCOMSMD` en fragmento base; por confirmar en boot. |
| UFS | `configured` | `SCSI_UFSHCD_PLATFORM` + `SCSI_UFS_QCOM` (símbolos v7.1). |
| USB gadget | `partially-working` | Modo device OK (gadget rndis, host `172.16.42.2`, ping `172.16.42.1` OK en boot pmOS 2026-08-09). OTG host BLOQUEADO: `usb@4e00000` (`snps,dwc3`) con `dr_mode="peripheral"` en el DTB `cb37540d` → nunca pasa a host y no hay VBUS para periféricos (teclado USB no alimentado). El kernel fork a27a7ce sí compila `USB_DWC3_DUAL_ROLE=y` + `extcon-usb-gpio` (id-gpio tlmm 102), pero `dr_mode` lo bloquea. Pendiente probar `dr_mode="otg"` + VBUS. |
| Batería | `not-targeted` | PMI632 sin driver dedicado en mainline v7.1 (`QCOM_BATT_METER`/`QCOM_SPMI_SCHG` son de fork sm61x5). |
| Térmicas | `configured` | `QCOM_TSENS` + `QCOM_SPMI_TEMP_ALARM`. |
| CPUfreq | `configured` | `ARM_QCOM_CPUFREQ_HW` + `CPUFREQ_DT`. |
| Audio | `not-targeted` | Prioridad secundaria. |
| Módem | `not-targeted` | Prioridad secundaria. |
| Cámara | `not-targeted` | Prioridad secundaria. |

Nota: el kernel debug compiló con éxito en CI (workflow 03, run 30786551830)
sobre mainline v7.1 + parches downstream; `sm6125-xiaomi-laurel-sprout.dtb`
generado (37KB) y verificado con `scripts/verify-dtb.sh`. El estado `compiled`
se refiere a que el driver/nodo está integrado y compilado, NO a que funcione
en hardware.

## Hito de prueba física (2026-08-09)

- EX3 kernel 6.1 v0: imagen en pantalla + `Kernel panic` por `/init: line 35:
  sed: not found` (initramfs, no kernel/DTB/AVB/display/UFS).
- EX3 sedfix (mismo kernel 6.1, ramdisk nuevo): `INITRAMFS_REACHED` +
  `[diag-init] entering rescue shell` + prompt interactivo →
  `INITRAMFS_6_1_SHELL_ACTIVE`. Sin kernel panic.
- **PMOS_CONSOLE_6_1_BOOTED**: boot.img original pmOS histórico (run
  31320766387) en `boot_b` → prompt de login de postmarketOS visible en
  pantalla + gadget rndis enumerado (`172.16.42.1` responde ping) + rootfs
  montado desde `system_b` (switch_root completado). Hito consola alcanzado.
  Bloqueos: sin entrada (OTG host inactivo, `dr_mode="peripheral"`) y sin
  sshd (rootfs instalado con `--no-sshd`) → los logs del dispositivo aún no
  son accesibles de forma remota.
- EX3 comparación 7.1 (solo cambió `boot_b`): pantalla NEGRA persistente,
  dispositivo encendido, sin serial conectado → no clasificable como
  `INITRAMFS_7_1_*`. El pipeline display del kernel 7.1 no muestra consola en
  hardware (el 6.1 sí). Restaurado `boot_b` a la 6.1 sedfix funcional.
- Evidencia: `reports/physical-tests/H61-INITRAMFS-SHELL-ACTIVE/result.md`,
  `reports/physical-tests/H61-KERNEL-7_1-BLACKSCREEN/result.md` y
  `reports/physical-tests/PMOS-CONSOLE-6_1-BOOTED/result.md`.

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
