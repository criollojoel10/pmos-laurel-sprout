# FASE 8 — Preflight v7.1 USB/DTB diagnóstico v3

Estado: artefacto construido y validado; **detenerse antes de Fastboot**.

| Campo | Valor |
|---|---|
| Kernel run | `31513653872` |
| Workflow 14 | `31550642940` |
| Commit workflow | `b7948e5` |
| Artefacto | `boot-laurel-v71-usb-dtb-diag-v3.img` |
| Ruta local | `local-private/boot-31550642940/boot-out/boot-laurel-v71-usb-dtb-diag-v3.img` |
| SHA-256 | `1a6781d16a0631900aecf47fbcad80fb542263bae2bb474e0e1a0b9ffe70806c` |
| Tamaño | `23085056` bytes |
| Límite boot | `67108864` bytes |
| Rootfs | no monta `system_b` |

## Cmdline v3

```text
console=ttyMSM0,115200n8 console=tty0 consoleblank=0 ignore_loglevel
loglevel=8 initcall_debug printk.time=1 panic=10 clk_ignore_unused
pd_ignore_unused regulator_ignore_unused androidboot.hardware=qcom
androidboot.console=ttyMSM0 loop.max_part=7 buildvariant=user
```

## Validación

- Kernel/ramdisk/DTB extraídos byte-idénticos.
- DTB USB/display auditado con `fdtget`: PHY, wrapper, core, extcon, supplies,
  ramoops y simplefb.
- Initramfs arm64 autocontenido, sin módulos/scripts 6.1.
- Marcadores V71_V3 y heartbeat de 10 s presentes.
- UDC wait 30 s, bind único, usb0/rndis0 wait 20 s, telnet tras interfaz.
- Sin `root=`, `skip_initramfs`, `quiet` ni `splash`.

## Punto de parada

No se ejecutó ninguna operación física. Antes de probar se deben repetir
consultas Fastboot de solo lectura, verificar SHA-256, confirmar slot/backups y
solicitar autorización explícita inmediata.

## Comando preparado, NO ejecutado

```text
fastboot flash boot_b local-private/boot-31550642940/boot-out/boot-laurel-v71-usb-dtb-diag-v3.img
```
