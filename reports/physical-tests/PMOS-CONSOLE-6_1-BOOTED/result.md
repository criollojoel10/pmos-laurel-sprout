# PMOS_CONSOLE_6_1_BOOTED — Boot original postmarketOS histórico

Fecha: 2026-08-09. Test físico: slot b, `boot_b` = boot.img ORIGINAL pmOS
histórico (run 31320766387, pmbootstrap 1.52, kernel `6.1.0-sm6125` fork
a27a7ce musl + DTB append `cb37540d…` + initramfs mkinitfs 1.5.1). Estado:
**PMOS_CONSOLE_6_1_BOOTED — PASS** (consola de postmarketOS arrancada desde
`system_b`).

## Evidencia

- **Prompt de login de postmarketOS visible en pantalla** (rootfs montado desde
  `system_b`, `switch_root` completado, getty en el framebuffer console).
- **Gadget USB rndis enumerado**: en el host Fedora apareció la interfaz
  `enp4s0f3u2` con `172.16.42.2/24`, DHCP del teléfono (`unudhcpd`),
  `ping 172.16.42.1` OK (3/3, RTT ~0.2 ms).
- `lsusb`: dispositivo Xiaomi presente (fastboot/gadget) — detección USB OK.
- Sin kernel panic.

## Bloqueos detectados (no invalidan el hito)

1. **Sin entrada**: OTG host NO activo. El DTB `cb37540d` define
   `usb@4e00000 { dr_mode = "peripheral"; }` → el dwc3 nunca cambia a host y no
   hay VBUS para periféricos (teclado USB no alimentado/no detectado).
   Config del kernel fork a27a7ce: `USB_DWC3_DUAL_ROLE=y`,
   `USB_DWC3_QCOM=y`, `TYPEC/TCPM=m`, y nodo `extcon-usb` (`id-gpio` tlmm 102)
   — el bloqueo es de DT, no de Kconfig.
2. **Sin acceso remoto de logs**: rootfs instalado con `--no-sshd`
   (workflow `10-build-historical-rootfs.yml`) → `sshd` ausente; no hay
   telnetd/otros servicios (puertos 22, 23, 80, 2222 cerrados).

## Clasificación

| Estado | Valor |
|---|---|
| KERNEL_6_1_FORK_BOOTED | SÍ |
| DISPLAY_PMOS_LOGIN_VISIBLE | SÍ |
| USB_GADGET_RNDIS_WORKING | SÍ (172.16.42.1 responde) |
| ROOTFS_SYSTEM_B_MOUNTED | SÍ (switch_root OK) |
| PMOS_CONSOLE_6_1_BOOTED | SÍ (login getty en pantalla) |
| OTG_HOST_INPUT_WORKING | NO (`dr_mode="peripheral"` en DTB) |
| REMOTE_LOG_ACCESS | NO (sin sshd/telnetd) |

## Estado persistente del slot b (sin cambios para la siguiente prueba)

| Partición | Estado |
|---|---|
| dtbo_b | borrado |
| vbmeta_b | vbmeta histórico flags=2 |
| system_b | xiaomi-laurel.img (rootfs pmOS, MBR) |
| boot_b | boot.img pmOS original (3b692fef…) |
| active slot | b |

Slot a intacto con /e/OS.

## Siguientes pasos propuestos

1. Obtener acceso remoto a logs (SSH o telnetd) construyendo en GitHub Actions
   un rootfs/boot con acceso habilitado; flashear y volcar `dmesg`/logs.
2. Fijar OTG: override de DT `dr_mode="otg"` en `usb3_dwc3` (board DTS) + VBUS
   y probar teclado; verificar el cambio de rol en dmesg (sysfs dwc3 role).
3. Con input funcional: login en consola (`pmos` / `147147`) para validar
   interactivamente.

## Referencias

- Preflight/artefacto: `local-private/phase-e-flash/preflight/pmos-console-6.1/`
  (`boot-laurel-6.1-pmos-original.img`, sha `3b692fef…`).
- DTS fuente: `sm6125-mainline/linux` @ `77de535b…`,
  `arch/arm64/boot/dts/qcom/sm6125-xiaomi-laurel_sprout.dts`.
