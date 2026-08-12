# Inventario de artefactos Linux 6.1

## Fuentes fijadas

| Elemento | Fijacion |
|---|---|
| Kernel | `sm6125-mainline-linux` @ `77de535b8dbd8f483b5802c8937cb714bab5b485` |
| Config historica | pmaports @ `7aaee51a`, SHA-256 `08bcee71d4164ef3e7c1244cdf4d5a0e4e7e2eedcadd9e5576166f8661417c4a` |
| Deviceinfo | pmaports historico `device-xiaomi-laurel`, port `a27a7ce` |
| pmbootstrap | `1.52.0`, SHA-256 `a05fef2bb495a2e0d8e0369e4a8a1038baf50b7514ec89582b5ec785f9bfa7cb` |
| pmaports/canal | `7aaee51a`, edge redirigido a v22.12 / Alpine v3.17 |
| Boot format | Android header v0, page 4096, append DTB, limite 64 MiB |

## Artefactos locales

| Ruta | Tamano | SHA-256 |
|---|---:|---|
| `local-private/run31320766387-artifacts/export-resolved/boot.img` | 12,402,688 | `3b692fefa4836246634955318232f416502a3ac316f403736a489ab9edf7b5fb3` |
| `local-private/workflow-09-artifacts/boot-out/boot-laurel-kernel-6.1-historical-v0-sedfix.img` | 12,402,688 | `ff5f0905282b105c3b17f49c2c07c98971547c29b25ddc75ba19453426b0a8be` |
| `local-private/workflow-09-artifacts/initramfs-out/initramfs.cpio.gz` | local, verificado en workflow 09 | `1ba78c8b57a3b4a613617ce05e88759af59bda30f95927689f6e4696d31d0325` |
| `local-private/run31355730519-artifacts/artifacts/artifacts/xiaomi-laurel-ssh.img` | 550,935,480 | `ebc8287f277d8ffd28c5eb128e1248e668e44a316cb4484916d0748d5bc40a2a` |

El rootfs SSH es una imagen MBR completa para `system_b`: p1 `/boot` ext2 y p2
`/` ext4. Su propio manifest indica que fue generado con sshd habilitado,
`PermitRootLogin prohibit-password` y autenticacion por clave.

## Artefactos no equivalentes

- `PMOS_CONSOLE_6_1_BOOTED` uso el boot original y un rootfs historico sin sshd.
- `SSH-ROOT-6_1-READONLY` uso el boot original y el rootfs SSH reconstruido.
- `H61-INITRAMFS-SHELL_ACTIVE` uso el boot sedfix y no demostro rootfs ni SSH.
- El boot v7.1 `31553208748` queda congelado como `boot-untested` y fuera del
  baseline 6.1.
