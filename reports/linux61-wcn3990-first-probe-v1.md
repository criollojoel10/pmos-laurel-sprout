# Primer probe físico WCN3990 — Linux 6.1 (v1)

Fecha: 2026-08-12. Boot flasheado por el usuario: `boot_b` con
`boot-linux61-wifi-debug-v1.img` (SHA-256
`ba26d5c68b14afb82e326edbf727b407e70d53fa87c3d4e79dee7e0ae88fa74e`, run
`31629258734`). Solo se modificó `boot_b`; `system_b`/rootfs no se tocaron.

Captura completa: `local-private/diagnostics/wifi-priority/wifi-v1-first-probe/`.

## Confirmación de canal de rescate

- Ping USB `172.16.42.1`: 3/3, RTT 0.15-0.26 ms.
- SSH `pmos@172.16.42.1`: OK.
- Kernel arrancado: `6.1.0-sm6125` banner `Mon Aug 10 05:15:17 UTC` (variante
  correcta, kernel del baseline).
- UFS/rootfs/SSH intactos; no hay regresión.

## Resultado del probe

1. **El nodo DT se enlazó correctamente**:
   `/sys/bus/platform/devices/c800000.wifi` con
   `OF_FULLNAME=/soc/wifi@c800000`,
   `OF_COMPATIBLE_0=qcom,wcn3990-wifi`,
   `MODALIAS=of:NwifiT(null)Cqcom,wcn3990-wifi`,
   driver vinculado `ath10k_snoc`.

2. **El driver probó y llegó a los regulators**:
   `[17.096029] ath10k_snoc c800000.wifi: supply vdd-3.3-ch1 not found, using dummy regulator`.
   Los suppliers reales quedaron enlazados: `regulator.0/9/17/18/24`
   (`vdd-0.8-cx-mx`, `vdd-1.8-xo`, `vdd-1.3-rfa`, `vdd-3.3-ch0` + dummy ch1).

3. **Los workqueues del driver están vivos** (`ath10k_wq`, `ath10k_aux_wq`,
   `ath10k_tx_compl`), indicando que `ath10k_core` se inicializó.

4. **El probe quedó esperando sin más mensajes**: no hay líneas QMI/QRTR/
   remoteproc/firmware en dmesg; no hay `wlan0`, `phy` ni `rfkill`; no hay
   deferred probes.

## Diagnóstico

- Hipótesis con mayor soporte: `ath10k_qmi_init` (o la espera del servicio
  QMI/QRTR del WCN3990) está esperando indefinidamente. Con `use_tz=true` el
  driver confía en que TrustZone/firmware levante el servicio wlfw vía QMI; al
  no haber firmware WCN3990 cargado ni remoteproc QMI activo, el servicio nunca
  aparece y el probe no avanza (sin error, en espera).
- Coincide con el resultado "también útil" previsto: el transporte SNOC se
  confirma a nivel DT/driver/regulators; falta la ruta QMI/QRTR/firmware.
- No se observó el nombre exacto del firmware solicitado porque el driver no
  llegó a pedirlo (se detuvo antes, en la espera QMI).

## Qué NO se logró

- `wlan0`, `phy`, `rfkill`, scan, asociación: NO.
- Mensaje de firmware `ath10k/WCN3990/hw1.0/*`: NO (probe bloqueado antes).
- IRQ/ruta SNOC completa: sin confirmar (no hay IRQ request visible).

## Plan para v2

Necesita al menos una de las siguientes vías, en orden de evidencia:

1. **Proporcionar el servicio QMI/QRTR**: cargar el firmware WCN3990 mediante
   remoteproc/QMI. En la rama 6.1 esto implica el driver `qcom_wcnss_pil` o el
   camino QMI del propio ath10k; el firmware `firmware-5.bin` se entrega por
   QMI (wlfw). Requiere instalar `firmware-5.bin` + `board-2.bin` en el rootfs
   y habilitar la ruta QMI que el driver espera.
2. **Revisar el uso de `use_tz`**: confirmar si el bootloader expone
   TrustZone para WCN3990; si no, la v2 debe añadir el subnodo `wifi-firmware`
   con `iommus` (SID 0x80) y portar `apps_smmu` (iommu@c600000), para que el
   propio driver cargue el firmware por IOMMU en lugar de TrustZone.
3. **Habilitar debug/dynamic-debug de ath10k** para ver dónde se detiene
   exactamente el probe (en esta build `CONFIG_ATH10K_DEBUG`/`DEBUGFS` no
   están; solo hay `ath10k_dbg`, silencioso).

Recomendado para v2: instalar firmware `firmware-5.bin`/`board-2.bin` en el
rootfs (verificando hashes/licencia) y, según el resultado, decidir si hace
falta SMMU + `wifi-firmware` o habilitar el camino QMI. No se usa aún
wpa_supplicant.

## Rollback

El baseline anterior (`boot-linux61-baseline-consoleblank0.img`, SHA
`41ed6045...`) sigue disponible para restaurar `boot_b` si la v2 rompiera SSH.
No hubo necesidad de rollback en esta v1.
