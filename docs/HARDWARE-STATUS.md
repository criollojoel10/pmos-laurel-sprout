# Estado del hardware

Estado honesto de cada componente. Los estados permitidos son únicamente:

`not-targeted`, `source-available`, `configured`, `compiled`, `packaged`,
`static-validation-passed`, `boot-untested`, `detected`, `partially-working`,
`working`, `blocked`, `regressed`.

La referencia canónica es `reports/hardware-matrix.json`. Este documento la
resume y explica los criterios.

## Estado actual (2026-08-10)

| Componente | Estado | Notas |
|---|---|---|
| Pantalla / DRM-KMS | `partially-working` | Consola pmOS visible vía simplefb/fbcon (`/dev/fb0` 720x1560x32) en el boot 6.1 SSH; captura root 2026-08-11 confirma `simplefb registered`. **Apagado tras ~10 min: CAUSA identificada** — sin `consoleblank` en cmdline, el timeout VT (600s) hace que `fbcon_generic_blank` (v6.1, simplefb sin `fb_blank`) rellene TODO el fb de negro; el nuevo boot v7.1 lleva `consoleblank=0`. Kernel 7.1: ruta `FB_SIMPLE=y` empaquetada y boot diagnóstico validado, pero pantalla física aún `boot-untested`. DRM/KMS/GPU no se declaran funcionales. |
| GPU Adreno 610 | `compiled` | Firmware confirmado (`firmware-qcom-adreno-a610` + `a630_sqe.fw`); nodos GPU en DTSI/DTS. Runtime (2026-08-10): `CONFIG_DRM_MSM=m` como módulo NO cargado, sin `/dev/dri` → sin aceleración (solo fbcon + software). |
| Táctil FT3518 | `compiled` | Driver `edt-ft5x06` (FT3518) en fragmento base; DTS touch habilitado (parche 0001). Runtime: `/sys/class/input` vacío (sin driver de input cargado). |
| Wi-Fi | `boot-untested` | Runtime (2026-08-10, captura limpia): SIN `wlan0`, sin bus mmc/sdio, módulos `ath10k_core/pci/snoc` + `wcn36xx` presentes pero NO cargados. Estado v3 (2026-08-14): workflow 19 run `31837336958` en main `f3a9246d`, `boot-linux61-wcn3990-v3.img` (sha256 `62c53db3...`) validado 25/25 gates (`mpss_status=okay`, `wifi@c800000` qcom,wcn3990-wifi okay). Rootfs privada integrada (`pmos-root-integrated.img`, sparse, imagen MBR completa sector 4096 → `system_b`). Gate board-2.bin resuelto con datos (variante TI activa; fallbacks `qmi-board-id=67/ff` IDÉNTICOS entre variantes). Prueba física SIN `fastboot boot` (no soportado en Mi A3): slot de prueba + slot de recuperación, deploy conjunto, gates presenciales. **Bring-up físico v3 (2026-08-15): `WIFI-V3-MPSS-RMTFS-BLOCKED`.** tqftpserv/pd-mapper arrancan OK, pero `rmtfs` muere en `rmtfs_mem_open()` porque el DTB v3 NO incluye el nodo `qcom,rmtfs-mem` (driver `qcom_rmtfs_mem` compilado, device ausente) → MPSS nunca arranca (`remoteproc0` offline) → sin QRTR/QMI/WLFW/`wlan0`. **Estado v4 (2026-08-15): fix aplicado.** Workflow 20 run `31868152121` en main `c73af38`, `boot-linux61-wcn3990-v4.img` (sha256 `0aeee96d...`): parche `0004-dts-sm6125-add-rmtfs-mem` añade nodo rmtfs-mem dinámico (`size <0x0 0x200000>`, `alloc-ranges` todo el espacio, `no-map`, `qcom,client-id=<1>`); secuencia 0001→0004 aplica limpia sobre fork 6.1 fijado `77de535b` (validado contra el árbol REAL del fork, no checktree2); `verify-rmtfs-mem.sh` 15/15 gates fuente + 8/8 final; manifest `{mpss_status=okay, rmtfs_mem_in_dtb=true, firmware_in_rootfs=false, userspace_mpss_ready=false, physical_status=boot-untested}`. El DTB final contiene el nodo verificado. **PRECAUCIÓN**: firmware MPSS/WLFW NO está en la rootfs — la v4 demuestra el transporte rmtfs/EFS, NO WiFi aún. Prueba física v4 planificada: `reports/physical-tests/WIFI-V4-RMTFS-BRINGUP` (plan en paquete privado); objetivo `/dev/qcom_rmtfs_mem1` + rmtfs sin abortar + MPSS `running`. |
| Bluetooth | `configured` | Runtime (2026-08-10): SIN `hci0`, sin rfkill BT; módulos `btqcomsmd`/`btqca` presentes pero NO cargados; mismo bloqueo de bus que WiFi. |
| UFS | `working` | Runtime (2026-08-10): `ufshcd-qcom 4804000.ufshc` OK, SAMSUNG KM5V7001DM-B621 detectado; el sistema ARRANCA desde UFS (system_b) y opera sobre él con e2fsck limpio. |
| USB gadget / OTG | `partially-working` | Runtime (2026-08-10, captura limpia): gadget RNDIS FUNCIONAL (`usb0` UP, SSH vía `172.16.42.1`; `qcom-qusb2-phy` OK). HOST NO presente: sin xhci, `/sys/bus/usb/devices` vacío. La evidencia previa de xhci/4 puertos NO se reproduce → no declarar OTG host. |
| Batería | `not-targeted` | Runtime (2026-08-10): spmi arbiter v5 OK pero sin drivers PMIC (batería/charger). PMI632 sin driver dedicado en v7.1. |
| Térmicas | `configured` | `QCOM_TSENS` + `QCOM_SPMI_TEMP_ALARM` (v7.1). Runtime (6.1): 0 zonas térmicas activas. |
| CPUfreq | `configured` | `ARM_QCOM_CPUFREQ_HW` + `CPUFREQ_DT` (v7.1). Runtime (6.1): driver no activo (sin sysfs cpufreq). |
| Audio | `not-targeted` | Runtime (2026-08-10): ALSA inicializado pero "No soundcards found". |
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
