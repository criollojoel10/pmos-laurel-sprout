# Validación CI — boot.img NixOS v0-append (laurel_sprout)

Fecha: 2026-08-29
Layout: `header v0` + DTB **concatenado al kernel** (`append_dtb`), sin campo DTB v2.
Estado: **CI validated** (`hardwareTested=false`, no se flasheó nada).

---

## Artefacto

| Campo | Valor |
|---|---|
| Nombre | `boot-laurel-nixos-console-v0-append.img` |
| SHA-256 | `1043b607ce05515308de5b164f9bbc93667a86a2659f4f9f537f3cfbd94ecd78` |
| Tamaño | 37 814 272 B (36.06 MiB) |
| Límite partición boot | 67 108 864 B (64 MiB) |
| Cabe en partición | SÍ |
| Run CI (ensamblaje) | `33258899468` |
| Run fuente artefactos (closure/kernel/busybox/rootfs) | `33256486259` |
| init sellado (cmdline) | `/nix/store/12zh8s1y1is0mn99hfjwswxfi9d99xkx-nixos-system-laurel-pmos-26.11.20260823.56c02bc/init` |
| kernelrelease | `7.1.0-postmarketos-sm6125-00001-gcedc0f9bbabc` |

## Estructura verificada (validación primaria — CI)

- Magic `ANDROID!` presente.
- `header v0` confirmado byte-level (`--assert-header-version 0`).
- `kernel_size = 17 951 274 B` = kernel `Image.gz` (17 913 515 B) + DTB (37 759 B).
- `ramdisk_size = 19 856 484 B`.
- Header sin sección/offset DTB v2 (header_size 1632, no 1660).
- 3E estricta (job `Strict end-to-end validation`): magic, payloads, kernelrelease
  kernel==módulos, busybox aarch64, init presente, secret scan limpio, SHA256SUMS.

## Validación secundaria (local, inspección independiente)

- Header parseado: `header_version=0`, `page=4096` (builder Python, modo C).
- DTB concatenado localizado en el tail del payload del kernel
  (último magic `d0 0d fe ed` en offset `17 913 515` = `kernel_size - dtb_size`).
- Campo `totalsize` del DTB (big endian, offset+4) = 37 759 = tail exacto → DTB íntegro.
- `unpack-boot-image.py --append-dtb` recuperó el DTB (37 759 B) del payload.
- Kernel extraído empieza por gzip (1f 8b) → `Image.gz` + DTB, sin truncado.
- ramdisk del boot == initramfs construido en CI (3D): sha256
  `37ba61869c7091a6b9810c944a7bfabfa1cf5ea4e5e8c79734f2ea091b3d9981` (idéntico).
- Initramfs: 1 990 entradas de módulos bajo `lib/modules/7.1.0-…`, `init` y
  `busybox` presentes.
- SHA256 consumidores coherentes: manifest `sha256` == `SHA256SUMS` (3E) ==
  sha256 local `1043b607ce05515308de5b164f9bbc93667a86a2659f4f9f537f3cfbd94ecd78`.

## cmdline diagnóstica

```
androidboot.hardware=laurel_sprout console=ttyMSM0,115200n8 console=tty0 boot.shell_on_fail=1 root=LABEL=NIXOS_ROOT init=/nix/store/12zh8s1y1is0mn99hfjwswxfi9d99xkx-nixos-system-laurel-pmos-26.11.20260823.56c02bc/init
```

- `root=LABEL=NIXOS_ROOT` ✅ (ausente en la imagen v2 probada: rootfs no montaría).
- `init=/nix/store/…` sellado ✅ (stage2 de la closure, no placeholder).
- `boot.shell_on_fail=1` ✅: si falta NIXOS_ROOT el uinit exec
  `setsid sh -i` en la consola (no `reboot -f`) → shell de rescate persistente.
- `console=tty0` ✅ (tras la serial) → consola visible en pantalla.

## Comparación con intentos anteriores

| Imagen | Layout | Resultado físico |
|---|---|---|
| H61 6.1 sedfix | header v0 + append_dtb | INITRAMFS_SHELL_ACTIVE (ABL arrancó) |
| h1 IT1/IT2/IT3 | header v2 | fallback Fastboot |
| NixOS v2 (`66ae73a3…`) | header v2 + dtb field | **bootloader-rejected** |
| **NixOS v0-append** (`1043b607…`) | **header v0 + append_dtb** | **hardwareTested=false** (PENDIENTE test físico, PASO 8) |

## Conclusión

Punto A del plan v0-append **completo**: header v0 confirmado, DTB concatenado
confirmado, cmdline diagnóstica confirmada, `shell_on_fail` cubre la ausencia de
rootfs, imagen < 64 MiB, sha256 verificado, validación 3E estricta verde,
artefacto descargado e inspeccionado de forma independiente.
`hardwareTested=false` — ninguna fastboot ejecutada.