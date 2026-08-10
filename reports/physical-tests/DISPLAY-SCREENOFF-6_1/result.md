# Diagnóstico: apagado irreversible de pantalla — kernel 6.1 (2026-08-10)

- **Fecha**: 2026-08-10
- **Kernel**: 6.1.0-sm6125 `#1-postmarketos-qcom-sm6125` (fork sm61x5, boot.img run 31320766387, cmdline header `clk_ignore_unused`)
- **Rootfs**: run 31355730519 (SSH) en `system_b`; boot `b`
- **Acceso**: `ssh root@172.16.42.1` (gadget RNDIS, clave local `local-private/ssh-laurel/`)
- **Evidencia**: `local-private/diagnostics/kernel-6.1/20260810-090149/` (43 archivos, manifest.json, SHA256SUMS)

## Síntoma (observado por el usuario)

- Consola pmOS visible al arrancar.
- A los pocos minutos (≈10) la pantalla se apaga (queda negra).
- El sistema sigue funcionando (SSH/red vivos).
- Tocar pantalla / volumen / power no restaura la imagen.

## Comandos y resultado (solo lectura)

| Comando | Resultado |
|---|---|
| `cat /proc/cmdline` | `clk_ignore_unused androidboot.… msm_drm.dsi_display0=dsi_s6e8fco_… skip_initramfs rootwait ro init=/init` — **sin `consoleblank`** |
| `cat /proc/fb` | `0 simple` |
| `cat /proc/uptime` | `2899.59` (≈48 min; el apagado ocurrió antes) |
| `ls /sys/class/graphics/fb0/` | fb0 simple 720x1560x32, stride 2880, `state=0` |
| `dd if=/dev/fb0 | wc -c` | 4,492,800 bytes (exacto) |
| `dd if=/dev/fb0 \| tr -d "\000\000\000\377" \| wc -c` | **0** → el fb completo es uniforme `00 00 00 ff` (NEGRO opaco) |
| `grep clk /sys/kernel/debug/clk/clk_summary` | `gcc_disp_hf_axi_clk`, `gcc_disp_ahb_clk`, `gcc_disp_gpll0_div_clk_src` → **hw_state=Y** (relojes del display VIVOS) |
| `cat /sys/kernel/debug/suspend_stats` | success=0 → **sin suspensión** |
| `cat /sys/kernel/debug/thermal/…`, zones | 0 zonas térmicas; sin mensajes de kernel tras 20.5s de boot |
| `ls /sys/class/input` | vacío → **sin dispositivos de input** |
| `ls /sys/class/backlight` | vacío → sin backlight class |
| `ls /sys/class/drm`, `/dev/dri` | vacío → sin DRM |
| `ls /sys/class/bluetooth`, rfkill | vacío → sin BT |

## Interpretación (hechos → inferencia)

Hechos demostrados:

1. El framebuffer **entero** quedó rellenado con el char de borrado (negro).
2. Los relojes de display (`gcc_disp_hf_axi_clk`, etc.) siguen **encendidos en hardware** (`hw_state=Y`).
3. El sistema no suspendió; no hay mensajes de kernel, térmica ni de error de driver.
4. No existe ningún dispositivo de input, ni backlight class, ni DRM.
5. `CONFIG_DRM_MSM=m`: el módulo msm NO está cargado → nadie apaga el panel desde un driver.

Mecanismo (código v6.1, `drivers/video/fbdev/core/fbcon.c`):

- Sin `consoleblank` en cmdline, el timeout de blanking del VT es el default **600 s**.
- Al expirar, `do_blank_screen` → `fbcon_blank(vc, 1, 0)`.
- simplefb no implementa `fb_blank` → `fb_blank()` devuelve `-EINVAL` → se ejecuta
  `fbcon_generic_blank(vc, info, blank)` → **`fbcon_clear(vc, 0, 0, rows, cols)`**,
  que rellena TODO el framebuffer con el erase-char (negro).
- El panel sigue encendido (los relojes están vivos) y muestra el framebuffer ahora negro.
- Como no hay input devices, ninguna tecla/tacto puede disparar el unblank del VT
  (`update_screen`), y los botones físicos no son eventos de Linux → la imagen no vuelve.

Conclusión: **el apagado es blanking de consola (software) que limpió el framebuffer;
el panel NO se apagó físicamente.**

## P0 — Prueba visual del panel (autorizada y ejecutada 2026-08-10)

- Estado previo: fb0 completo `00 00 00 ff` (negro, medición local `tr -d` → 0 restantes).
- Escribí un patrón rojo (`00 00 ff ff`) en todo `/dev/fb0` vía SSH (4,492,800 B, `dd bs=65536`).
- Verificación de lectura: inicio y medio = `00 00 ff ff`, conteo de bytes no-rojos = **0**.
- **Resultado visual: el usuario confirma PANTALLA ROJA SÓLIDA.**
- Implicación: el panel y la señal de vídeo están vivos; el apagado era solo
  blanking de consola (fbcon limpió el fb). La ruta de recuperación queda validada.

## Fix reproducible

- Añadir **`consoleblank=0`** al kernel cmdline (boot.img header).
- `scripts/patch-bootimg-cmdline.py` genera `boot-consoleblank0.img` a partir del
  boot.img de run 31320766387: **solo cambia el campo cmdline**; kernel/initramfs
  byte-idénticos (kernel `7dd4103e…`, initramfs `089e344a…`).
- sha256 `boot-consoleblank0.img` = `b64eaaa8d692011b92b3f7634296411a597d056c98da185e3a11b70984ee20d2`
  (12,402,688 bytes, cabe en boot_b).
- Pendiente FASE 8: flashear `boot_b` (autorización explícita) y verificar que la
  consola permanece visible >10 min.

## Próxima prueba

1. Confirmación visual del usuario (panel vivo): escribir un patrón rojo en `/dev/fb0`
   y verificar que aparece en pantalla.
2. Tras autorización FASE 8: flashear `boot_b` con el boot.img parcheado y confirmar
   que la consola NO se apaga pasados los 10 min.

## Riesgos / no tocar

- No tocar `system_b`, `vbmeta_b`, `dtbo_b` ni cambiar de slot.
- El `boot_b` actual (run 31320766387) es el estado funcional conocido; preservar el
  original y documentar rollback.
