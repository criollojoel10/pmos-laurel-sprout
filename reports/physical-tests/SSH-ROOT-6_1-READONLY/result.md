# Diagnóstico root SSH 6.1 — lectura completa

Fecha: 2026-08-11. Método: SSH por RNDIS a `pmos`/`root`, sin ADB ni cambios de
particiones. La contraseña histórica solo se usó para `sudo` local del sistema;
SSH mantiene `PasswordAuthentication no` y acceso root por clave pública.

## Resultado de acceso

- `pmos@172.16.42.1`: `uid=10000(pmos)`, sshd activo.
- `root@172.16.42.1`: acceso por la clave Ed25519 del repositorio confirmado.
- Kernel: `6.1.0-sm6125`, `aarch64`, pmOS histórico.
- `sshd -T`: `permitrootlogin without-password`, `pubkeyauthentication yes`,
  `passwordauthentication no`.
- La sesión root se obtuvo después de corregir el rootfs instalado con la
  contraseña histórica documentada; no se habilitó autenticación SSH por
  contraseña.

## Display y camino de bring-up

- `/dev/fb0` presente.
- `dmesg`: `simple-framebuffer ... framebuffer at 0x5c000000`, formato
  `a8r8g8b8`, modo `720x1560x32`, stride `2880`.
- `dmesg`: `fb0: simplefb registered!`.
- Config efectiva: `CONFIG_FB_SIMPLE=y`, `CONFIG_FRAMEBUFFER_CONSOLE=y`,
  `CONFIG_DRM_MSM=m` sin cargar; `CONFIG_DRM_MSM_DPU=y` y
  `CONFIG_DRM_MSM_DSI=y` dentro del módulo.

Conclusión: esta es la receta de display que debe reproducir el kernel 7.1
antes de intentar activar DRM/MSM y GPU.

## Hardware observado

- UFS: detectado y operativo (`ufshcd-qcom`, dispositivo Samsung KM5V7001DM-B621).
- USB gadget: RNDIS operativo, `usb0` y SSH funcionando; QUSB2 PHY registrada.
- Wi-Fi/Bluetooth: sin `mmc_host`/SDIO, `wlan0` o `hci0`; no hay evidencia de
  transporte activo.
- GPU/DRM: sin `/dev/dri` ni probe runtime; correcto para el bring-up simplefb.
- Energía: sin `power_supply`, thermal zones o sysfs cpufreq visibles.
- Errores: solo avisos `psci: failed to set PC mode: -3` y supplies USB/UFS
  ausentes usando dummy/asumiendo enabled; requieren investigación posterior.

## Aplicación a 7.1

1. Mantener `FB_SIMPLE=y` y `DRM_MSM=m` en la primera prueba.
2. Conservar el nodo DT `/chosen/framebuffer@5c000000` y `consoleblank=0`.
3. No declarar GPU, Wi-Fi, Bluetooth, batería, térmicas o cpufreq funcionales
   hasta obtener la misma evidencia runtime en 7.1.
4. Usar RNDIS/SSH del initramfs para capturar dmesg si la imagen no aparece.
