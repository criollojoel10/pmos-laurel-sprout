# WIFI-V3-MPSS-RMTFS-BLOCKED — bring-up WCN3990 v3: MPSS no arranca por falta de `rmtfs_mem`

Fecha: 2026-08-15. Método: SSH por RNDIS como `root` (previa reparación del
acceso root: cuenta bloqueada con `!` → `passwd -d root` + fragmento sshd
`/etc/ssh/sshd_config.d/10-root-key-only.conf`). Dispositivo en slot `b`
(kernel `6.1.0-sm6125`, rootfs pmOS v22.12.2 integrada). Servicios iniciados
uno por uno con autorización explícita (tqftpserv → pd-mapper → rmtfs) y
detenidos en orden inverso al detectar el bloqueo. Sin cambios de particiones.

## Resultado

- **Estado final: `MPSS-FAILED / LOGS-CAPTURED`.** WiFi NO funciona (aún).
- `remoteproc0` (`6080000.remoteproc`) quedó en `state=offline`, firmware
  `modem.mdt`.
- Sin `wlan0`, sin `phy0`, sin mensajes QRTR/QMI/WLFW en dmesg.

## Causa raíz

1. El stack userfspace arranca correctamente:
   - `tqftpserv` → started (PID 2031).
   - `pd-mapper` → started (supervise-daemon PID 2095).
   - `rmtfs -s -P` → rc-service arranca, pero el proceso hijo queda zombie y
     `remoteproc` sigue `offline`.
2. `rmtfs` falla en `rmtfs_mem_open()` porque **no existe el device del
   kernel** necesario para compartir EFS con el modem:

   ```
   failed to open /dev/qcom_rmtfs_mem1: No such file or directory
   falling back to uio access
   failed to open /dev/qcom_rmtfs_uio1: No such file or directory
   falling back to /dev/mem access
   failed to mmap: Invalid argument
   ```

3. Causa estructural: el **DTB v3 no contiene el nodo `qcom,rmtfs-mem`**.
   - El driver `qcom_rmtfs_mem` SÍ está compilado en el kernel
     (`/sys/bus/platform/drivers/qcom_rmtfs_mem` existe), pero sin nodo DT no
     se crea el device `/dev/qcom_rmtfs_mem*`.
   - Verificado en el DTB flasheado (`final-v3.dtb` extraído de
     `boot-linux61-wcn3990-v3.img`): `strings` no muestra `qcom,rmtfs-mem` ni
     `rmtfs`; tampoco existe en `sm6125.dtsi` del fork fijado `77de535b` ni en
     el board `sm6125-xiaomi-laurel_sprout.dts`.
4. Conclusión: sin rmtfs funcional el modem no recibe EFS, no se inicia MPSS
   y la cadena GLINK → QRTR → QMI WLFW → ath10k FW_READY → `wlan0` queda
   bloqueada en el primer eslabón.

## Evidencia

- Log completo: `local-private/physical-v3-runtime-20260815T004810Z/why-wifi-not-working.log`.
- Colector v3: `local-private/physical-v3-runtime-20260815T004810Z/collector-run-v3.txt`.
- Snapshot bring-up: `local-private/physical-v3-runtime-20260815T004810Z/bringup-snapshot-final.txt`.
- Snapshot reparación root: `local-private/physical-v3-runtime-20260815T004810Z/ssh-root-fix/root-snapshot.txt`.
- dmesg relevante (completo):
  ```
  [ 18.755456] remoteproc remoteproc0: 6080000.remoteproc is available
  [ 18.817986] ath10k_snoc c800000.wifi: supply vdd-3.3-ch1 not found, using dummy regulator
  ```
- Módulos cargados (cadena completa presente): `ath10k_snoc`, `ath10k_core`,
  `mac80211`, `qrtr`, `qcom_q6v5_pas`, `qcom_q6v5`, `qcom_sysmon`,
  `mdt_loader`, `qcom_pil_info`.
- `/dev/qcom_rmtfs*` y `/dev/qcom_rmtfs_uio*`: ausentes.
- `/dev/disk/by-partlabel` SÍ expone `modemst1`, `modemst2`, `fsg`, `fsc`
  (los datos están, falta el transporte).

## Cómo arreglarlo (orden de trabajo)

1. **Añadir el nodo `qcom,rmtfs-mem` al Device Tree** (parche kernel 6.1
   downstream, estilo `0004-dts-sm6125-add-rmtfs-mem`):
   - Definir una `reserved-memory` `rmtfs_mem` en `sm6125.dtsi` (o en el board
     `sm6125-xiaomi-laurel_sprout.dts`) con `no-map`, de ~2 MiB, en un hueco
     libre (el layout actual reserva `modem_mem` en `0x4b000000`–`0x52e00000`;
     revisar superposición antes de elegir dirección).
   - Añadir un nodo `/soc/rmtfs@<addr>` con `compatible = "qcom,rmtfs-mem"`,
     `memory-region = <&rmtfs_mem>` y, según variante, `qcom,vmid`/
     `qcom,use-mbaregion`.
   - Referencia mainline: el driver `qcom_rmtfs_mem` (drivers/soc/qcom) crea
     `/dev/qcom_rmtfs_mem*` cuando existe el nodo compatible.
   - Regenerar `boot v3` con el nuevo DTB, flashear (con autorización) y
     repetir el bring-up.
2. **Verificar de nuevo la cadena** tras el parche:
   - `/dev/qcom_rmtfs_mem0` presente → `rc-service rmtfs start` (con `-s`)
     debe dejar `remoteproc0` en `running` (MPSS arranca con `modem.mdt`).
   - Tras MPSS running: QRTR NS (kernel) + `pd-mapper` deben resolver los
     servicios QMI; ath10k envía QMI WLFW; `wlan0`/`phy0` aparecen.
3. **Opción de diagnóstico intermedio (sin reconstruir kernel)**: probar
   `rmtfs -o /boot/modem_fs1 -s` (modo ficheros) para verificar el resto de la
   cadena (MPSS/QRTR/QMI) aunque el EFS real siga pendiente. NO recomendado
   como estado final (el port debe usar las particiones `modemst1/2`,
   `fsg/fsc` vía `-P`), pero útil para aislar si el bloqueo es solo rmtfs_mem.

## Clasificación honesta

- Estado público: WiFi `boot-untested` (no hay evidencia runtime de transporte
  WLAN). No declarar nada más.
- Lo que SÍ funciona y queda demostrado: boot del kernel v3 en slot b, RNDIS,
  SSH root por clave, carga de toda la cadena de módulos WiFi/QRTR/remoteproc,
  bins userspace presentes y servicios arrancables.