# Prueba física console — NixOS en Xiaomi Mi A3 (laurel_sprout)

Estado: **hardware-tested=false**. Imagen recomendada para el test:
`boot-laurel-nixos-console-v0-append.img` (header v0 + append_dtb, run
`33258899468`, commit `35b6669`). La v2 (`66ae73a3…`, run `33240188674`) quedó
como evidencia histórica: **rechazada por el ABL** (`bootloader-rejected`).
Todo lo de abajo es para un operador con el dispositivo en mano; el pipeline NO
flashea nada.

## Artefactos necesarios

| Artefacto | Contenido |
|---|---|
| `nixos-console-boot` | `boot-laurel-nixos-console-v0-append.img` (37 814 272 B, sha256 `1043b607ce05515308de5b164f9bbc93667a86a2659f4f9f537f3cfbd94ecd78`, header v0), `cmdline.txt`, `boot-manifest.json`, reporte de imagen |
| `nixos-console-rootfs-image` | `nixos-rootfs.img` (~2.43 GiB, ext4, label `NIXOS_ROOT`, uuid `87bf6242-3f0b-458c-8bbb-e0be1ad48d0e`, sha256 `e6fd88d3…`) |
| `nixos-console-release-validation` | `nixos-boot-validation.md`, `artifact-index.json`, `SHA256SUMS` |

Kernel/módulos/dtb coherentes: kernelrelease `7.1.0-postmarketos-sm6125-00001-gcedc0f9bbabc`.

## Paso 0 — Preparación del dispositivo (una vez)

1. Backup completo (userdata/cust/etc. se borran).
2. Bootloader desbloqueado: `fastboot oem unlock` (o vía Mi Unlock oficial según
   variante) y confirmar en menú fastboot.
3. Termux (o cualquier host Linux): `pkg install android-tools` para `fastboot`.

## Paso 1 — Boot de prueba SIN flashear (recomendado primero)

```sh
fastboot devices                # debe listar el device
fastboot boot boot-laurel-nixos-console-v0-append.img
```

- Esperar arranque de kernel + initramfs propio (console `ttyMSM0,115200n8`).
- El initramfs monta `LABEL=NIXOS_ROOT`. Si NO hay rootfs ext4 con ese label,
  entra en el shell de recuperación del init (diseñado para eso).
- Verificar en consola/UART-USB:
  - `/proc/cmdline` contiene `root=LABEL=NIXOS_ROOT init=/nix/store/
    12zh8s1y1is0mn99hfjwswxfi9d99xkx-nixos-system-laurel-pmos-26.11.20260823.56c02bc/init`
  - Si stage-2 llega: unidad `systemd` PID 1, hostname `laurel-pmos`.

## Paso 2 — Rootfs persistente (solo cuando Paso 1 boot-ok)

```sh
fastboot erase userdata
fastboot flash userdata nixos-rootfs.img
fastboot reboot
```

- La imagen ext4 ya tiene label `NIXOS_ROOT` y el store completo (663 paths).
- Tras el arranque: `lsblk -f | grep NIXOS_ROOT`, `mount | grep NIXOS_ROOT`,
  `ls /nix/store | wc -l` ≈ 663, `cat /etc/nixos/...` presente desde el árbol.

## Paso 3 — Si algo falla (rede de diagnóstico)

- `fastboot boot` con el boot.img SIEMPRE es no-destructivo: solo cambia rootfs
  al flashearlo en el Paso 2.
- Recuperar: menú fastboot + `fastboot flash boot` con el stock de MIUI.
- Bug → ticket con log de `dmesg`/kmsg de la consola ttyMSM0 y el hash del
  boot.img usado.

## Notas de seguridad del pipeline

- Ninún paso del CI flashea hardware; `hardwareTested=false` queda serializado
  en `nixos-console-release-validation`.
- SHA256SUMS del run sellado permiten verificar los descargados antes de flashear.