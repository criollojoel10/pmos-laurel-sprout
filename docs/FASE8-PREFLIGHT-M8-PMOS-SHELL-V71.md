# FASE 8 — Preflight: boot 7.1 → rootfs pmOS (system_b)

Estado: artefacto construido y validado en CI. **DETENERSE antes de cualquier
Fastboot de escritura.** Este documento no autoriza flasheo.

## 1. Objetivo

Arrancar el kernel mainline v7.1 con el initramfs pmOS histórico y continuar
hacia el rootfs pmOS instalado en `system_b` (slot b). Si el rootfs levanta,
debería aparecer la consola/login por `simplefb`/`fbcon` y, vía udev/pmOS del
rootfs, el gadget RNDIS → SSH. Es el paso que reemplaza al boot de diagnóstico
por uno que "entra directo al shell pmOS" como el 6.1.

## 2. Artefactos

| Campo | Valor |
|---|---|
| Kernel run (03) | `31459886925` (success) |
| Rootfs run (11) | `31355730519` (success) |
| Boot run (05) | `31509192782` (success) |
| Artefacto | `boot-laurel-pmos-shell-v71.img` |
| Ruta local | `local-private/boot-31509192782/boot-out/boot-laurel-pmos-shell-v71.img` |
| SHA-256 | `80792ca2f835e04b4d8e47a45c48512ba7da2319d38b4175647593fbffa49f0f` |
| Tamaño | 24,846,336 bytes (límite 67,108,864) |
| Partición prevista | solo `boot_b` |
| skip_initramfs | no (corre el initramfs pmOS) |

## 3. Cmdline del boot final (extraído y verificado)

```text
console=ttyMSM0,115200n8 console=tty0 consoleblank=0 clk_ignore_unused
androidboot.hardware=qcom androidboot.console=ttyMSM0
root=PARTUUID=dd9c45fe-41b1-02a1-ed69-58eb218e5043 rootwait ro init=/init
loop.max_part=7 buildvariant=user
```

- `root=PARTUUID=dd9c45fe-41b1-02a1-ed69-58eb218e5043` (rootfs SSH de `system_b`).
- Sin `skip_initramfs`: el initramfs pmOS (mkinitfs 1.5.1) corre y monta root.
- `consoleblank=0` + anti-blank runtime para evitar el apagado a los 600 s.
- DTB v7.1 conserva `framebuffer@5c000000` (720x1560, a8r8g8b8).

## 4. Validación independiente (no solo "verde" de CI)

- `sha256sum -c SHA256SUMS`: OK.
- Kernel, ramdisk y DTB extraídos: hashes idénticos a los originales.
- Ramdisk pmOS: cpio gzip con `/init` presente.
- DTB: `framebuffer@5c000000` presente.
- Tamaño 24,846,336 B < 64 MiB: OK.
- Cmdline extraído contiene `root=PARTUUID`, `rootwait`, `console=tty0`,
  `consoleblank=0`.

## 5. Riesgos conocidos / no clasificar sin evidencia

- El initramfs pmOS se construyó para el kernel 6.1 (módulos en `/lib/modules`
  de 6.1). Con el kernel 7.1, si `modprobe` del initramfs no encuentra módulos
  del release 7.1, la carga puede degradarse; UFS/block están built-in en
  nuestro config 7.1, por lo que el montaje de root debería proseguir.
- No se declara `working` nada. Estados permitidos antes/después:
  `packaged`/`static-validation-passed` → `boot-untested` hasta observar boot;
  el display solo será `detected`/`partially-working` con consola visible; SSH
  solo `working` tras autenticar `root@172.16.42.1`.
- El kernel `31459886925` NO incluye todavía el nodo WiFi WCN3990 (parche 0004
  está en build 03 `31509183456`). Este boot prueba display+rootfs+SSH;
  Wi-Fi se validará con el siguiente kernel.

## 6. Estado del dispositivo (fastboot read-only, inmediatamente antes)

```sh
fastboot getvar current-slot        # debe ser b
fastboot getvar partition-size:boot_b
```

No se tocan `system_b`, `dtbo_b`, `vbmeta_b`, `persist` ni slot.

## 7. Recuperación

- A 6.1 funcional: reflashear `boot_b` con
  `local-private/run31320766387-artifacts/export-resolved/boot.img`
  (SHA `3b692fef…`).
- A stock/eOS: `local-private/phase-e-flash/recovery-kit/KNOWN_GOOD_boot_eos-4.1.1.img`.
- Respaldos `local-private/backups/2026-08-09/` presentes.

## 8. Punto de parada

Este documento no autoriza el flasheo. Antes de ejecutar el comando se debe:
confirmar slot, verificar SHA-256 del artefacto, y solicitar autorización
explícita e inmediata.

## 9. Comando preparado, NO ejecutado

```text
fastboot flash boot_b local-private/boot-31509192782/boot-out/boot-laurel-pmos-shell-v71.img
fastboot reboot
# tras boot: ssh -i local-private/ssh-laurel/id_ed25519 root@172.16.42.1
```

## 10. Observaciones esperadas (para registrar en reports/physical-tests)

1. Consola/kernel visible en pantalla (simplefb).
2. Login pmOS en pantalla y/o RNDIS `172.16.42.1` respondiendo.
3. SSH root por clave tras desbloqueo documentado.
4. `consoleblank=0` eficaz (sin apagado a los ~600 s).
5. Anotar cualquier fallo del initramfs pmOS con kernel 7.1 (módulos).
