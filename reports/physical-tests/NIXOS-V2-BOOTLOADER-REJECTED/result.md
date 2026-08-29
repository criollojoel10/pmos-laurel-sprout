# NixOS boot header v2 — rechazado por bootloader (fallback a Fastboot)

Fecha: 2026-08-29. Test físico en slot b (autorizado). Estado:
**bootloader-rejected** — imagen rechazada antes de alcanzar un estado
observable del initramfs. No se declara kernel booting.

## Artefacto probado

| Campo | Valor |
|---|---|
| Archivo | `boot-laurel-nixos-console.img` |
| Ruta local | `artifacts/nixos-console/boot/boot-out/boot-laurel-nixos-console.img` |
| SHA-256 | `66ae73a3aff6337bec23edc75332155492bebd2a13a2c0c8b24c27a951378b68` |
| Tamaño | 37 818 368 B |
| Run CI | 33240188674 |
| Header | **v2** (AOSP bootimg.h, 1660 B) |
| DTB | campo v2, `dtb_addr = 0x01f00000`, `dtb_size > 0` |
| Cmdline | `androidboot.hardware=laurel_sprout console=ttyMSM0,115200n8 root=LABEL=NIXOS_ROOT init=/nix/store/12zh8s1y1is0mn99hfjwswxfi9d99xkx-nixos-system-laurel-pmos-26.11.20260823.56c02bc/init` |
| kernelrelease | `7.1.0-postmarketos-sm6125-00001-g8eab428f49a7` |

## Entorno físico

| Campo | Valor |
|---|---|
| Serial | redactado (no se publica) |
| `unlocked` | yes |
| `current-slot` | b |
| `slot-count` | 2 |
| Modo | ABL clásico (`is-userspace: Not found`) |
| `boot_b` | imagen NixOS v2 recién flasheada |
| `dtbo_b` | borrado |
| `vbmeta_b` | flags=2 |
| `system_b` | estado persistente post-H61 |
| Slot a | **intacto** (/e/OS) |
| Respaldos | R8 completos (boot A/B incluidos), accesibles |

## Secuencia ejecutada

### Paso 3 — `fastboot boot` (RAM), rechazado por el ABL

Con los dos clientes (37.0.0 y platform-tools r33.0.3), la descarga funciona
(`Sending ... OKAY`) pero el comando `boot` es rechazado:

```
Sending 'boot.img' (36932 KB)                      OKAY [  0.850s]
Booting                                            FAILED (remote: 'unknown command')
fastboot: error: Command failed
```

Confirmado con ambos clientes → `FASTBOOT_BOOT_COMMAND_UNSUPPORTED` definitivo.
La versión del cliente NO es la causa (el error "crclist"/"crclist" es de Mi
Flash Tool en Windows, contexto distinto e irrelevante aquí).

### Paso 4 — flash `boot_b` + `set_active b` + reboot (autorizado)

```
Sending 'boot_b' (36932 KB)  OKAY [  0.842s]
Writing 'boot_b'             OKAY [  0.194s]
Setting current slot to 'b'  OKAY [  0.009s]
current-slot: b
```

Reboot → **fallback inmediato a Fastboot** (idVendor 18d1 / idProduct d00d),
sin que el kernel llegara a un estado observable. No hubo pantalla del kernel,
ni initramfs, ni USB gadget de red.

## Interpretación

El ABL de este dispositivo rechaza las imágenes con **header v2** (con DTB en
campo v2); vuelve a Fastboot sin intentar el arranque. Es coherente con todo el
historial registrado (`reports/h1-flash-boot-result.md` IT1/IT2/IT3):

| Prueba | Header | DTB | Resultado |
|---|---|---|---|
| h1 IT1/IT2 (diag) | v2 | campo `0x1f00000` | fallback Fastboot |
| h1 IT3 (diag) | v2 | append | fallback Fastboot |
| H61 6.1 sedfix | **v0** | **append** | INITRAMFS_SHELL_ACTIVE |
| H61 7.1 sedfix | **v0** | **append** | pantalla negra (intento) |
| **NixOS v2 (esta prueba)** | v2 | campo `0x1f00000` | **fallback Fastboot** |

El layout válido en este dispositivo es `header v0 + append_dtb`
(`scripts/build-boot-image.py` modo C, validado en
`reports/boot-builder-v0-validation.md`). La variante NixOS debe usar ese
layout (`--boot-layout v0-append`).

## Clasificación honesta

| Estado | Valor |
|---|---|
| KERNEL_NIXOS_7_1_BOOTING | NO declarado (sin evidencia de arranque de kernel) |
| INITRAMFS_NIXOS_REACHED | NO |
| USERS_NIXOS_TESTED | NO (sin rootfs `NIXOS_ROOT` en el dispositivo) |
| HARDWARE_STATE_MAX | **bootloader-rejected** |

- rootfs `NIXOS_ROOT` **ausente** en el dispositivo (imagen `nixos-rootfs.img`
  aún no descargada/flasheada).
- Ninguna prueba de userspace NixOS fue posible.

## Estado persistente tras la prueba (sin cambios adicionales)

| Partición | Estado |
|---|---|
| boot_b | imagen NixOS v2 (rechazada por ABL; no daña slot a) |
| dtbo_b | borrado |
| vbmeta_b | flags=2 |
| active slot | b |
| Slot a | intacto con /e/OS |

## Próximo paso

Construir en CI la variante **`boot-laurel-nixos-console-v0-append.img`**
(header v0 + append_dtb + `boot.shell_on_fail=1` + `console=tty0` + cmdline
diagnóstica), validarla estáticamente y probarla físicamente (flash `boot_b` +
`set_active b` + reboot) con gate FASE 8.