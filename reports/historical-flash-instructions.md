# Reporte R12 — Instrucciones de flasheo histórico (DOCUMENTO — NO EJECUTAR)

Fecha: 2026-08-05. Estado: **documento de referencia, pendiente de gate FASE 8,
respaldos físicos (R8) y autorización explícita**. NINGÚN comando de este
documento debe ejecutarse aún.

## Principio

El AGENTE no flashea. El USUARIO ejecuta cada bloque SOLO cuando el gate FASE 8
se haya superado (respaldos completos + autorización por escrito).

## Secuencia histórica corregida (para slot b, adaptada de la guía 2022)

Flujo histórico original (comandos root `#` = `sudo`):

```
$ pmbootstrap init
$ pmbootstrap install
# fastboot erase dtbo
$ pmbootstrap flasher flash_vbmeta
$ pmbootstrap flasher flash_rootfs
$ pmbootstrap flasher flash_kernel
# fastboot reboot
```

### Adaptación a nuestro dispositivo A/B (slot b experimental)

Los comandos pmbootstrap históricos flashean `boot`/`system`/`vbmeta` SIN
sufijo (el deviceinfo no los define). Para no tocar el slot a (que funciona),
la reproducción experimental en slot b usa sufijos explícitos. Los archivos de
la sección "Artefactos" deben existir y estar verificados ANTES.

## Artefactos verificados (rutas y SHA-256 al 2026-08-08)

| Artefacto | Ruta local | SHA-256 |
|---|---|---|
| vbmeta flags=2 (pmOS histórico) | `local-private/historical-port/artifacts/vbmeta-historical-pmos-flags2.img` | `fe1f4b55…f4ca2` (idéntico al de workflow 09) |
| boot v0 kernel 6.1 (EX1/EX3) | `local-private/workflow-09-artifacts/boot-out/boot-laurel-kernel-6.1-historical-v0.img` | `ff5f0905…a8be` |
| boot v0 kernel 7.1 + appenddtb | `local-private/workflow-09-artifacts/boot-out/boot-laurel-kernel-7.1-v0-appenddtb.img` | `391d40e2…5849` |
| initramfs (diagnóstico) | `local-private/workflow-09-artifacts/initramfs-out/initramfs.cpio.gz` | (ver SHA256SUMS) |
| KNOWN_GOOD boot /e/OS 4.1.1 | `local-private/phase-e-flash/recovery-kit/KNOWN_GOOD_boot_eos-4.1.1.img` | `87ceeb42…1fb` |
| TEST_IMG boot diagnóstico | `local-private/phase-e-flash/recovery-kit/TEST_IMG_boot-laurel-diagnostic.img` | `66e7005f…0b9d` |
| rootfs histórico (EX3) | `local-private/run31320766387-artifacts/` (descargado del workflow 10, run 31320766387 success) | ver tabla siguiente |
| `xiaomi-laurel.img` (sparse completo) | `local-private/run31320766387-artifacts/artifacts/xiaomi-laurel.img` | `754bd35c…88 9a` |
| `part1.img` (p1 /boot ext2, 247 MB) | `local-private/run31320766387-artifacts/artifacts/part1.img` | `e4df9958…f8` |
| `part2.img` (p2 / ext4, 1.8 GB) | `local-private/run31320766387-artifacts/artifacts/part2.img` | `2c763492…f8f8` |
| manifest.json (pmbootstrap 1.52.0, pmaports 7aaee51a, kernel 6.1 @77de535b) | `local-private/run31320766387-artifacts/artifacts/manifest.json` | — |

Layout verificado en el reporte del CI: MBR msdos, p1 /boot ext2, p2 / ext4.
`flash_rootfs` destina la imagen a `system_b` (3 GiB confirmado, cabe ~2 GiB).


### 0. Prerrequisitos verificados (bloqueante)

- [x] `local-private/backups/2026-08-09/` COMPLETO (R8): boot_a/b, dtbo_a/b,
      vbmeta_a/b, persist, modemst1/2, fsg, fsc, modem_a, dsp_a. Manifest
      `manifest.json` status=COMPLETO (13 particiones, ~427 MiB, SHA256).
      [2026-08-09]
- [x] `fastboot devices` muestra el dispositivo (serial sanitizado en logs).
      [2026-08-09, slot a, unlocked]
- [x] `current-slot: a` (slot a intacto = punto de retorno). [2026-08-09]
- [x] `partition-size:system_b = 0xC0000000` (3 GiB) confirmado por el
      usuario (autorizado 2026-08-09); el rootfs ~2 GiB cabe en EX3.
      Registro: `local-private/phase-e-flash/preflight/r8/preflight-fastboot-sanitized.txt`
- [x] Artefactos con SHA256 registrado y correcto. Rootfs histórico (run 10,
      31320766387 success): `xiaomi-laurel.img` `754bd35c…88 9a` + part1/part2
      verificados localmente contra el CI (2026-08-09). Boot v0 kernel 6.1/7.1 +
      vbmeta flags2 ya verificados. Gate FASE 8 de prerrequisitos COMPLETO.

### 1. Vuelta a Fastboot (si está en /e/OS)

```
adb reboot bootloader
```

### 2. Registro previo (FASE 8)

```
fastboot getvar current-slot
fastboot getvar slot-count
fastboot getvar unlocked
fastboot getvar partition-size:boot_b
fastboot getvar partition-size:dtbo_b
fastboot getvar partition-size:vbmeta_b
fastboot getvar partition-size:system_b
```

Registrar la salida SANITIZADA en `local-private/phase-e-flash/preflight/`.
`partition-size:system_b` ya confirmado (0xC0000000 = 3 GiB, 2026-08-09);
el rootfs pmOS ~2 GiB cabe. No ejecutar `getvar all` sin el script de
`sanitización` (AGENTS.md §0).

### 3. [EX0] Control del slot b (opcional pero recomendado)

```
fastboot flash boot_b local-private/phase-e-flash/recovery-kit/KNOWN_GOOD_boot_eos-4.1.1.img
fastboot set_active b
fastboot reboot
```

Si /e/OS arranca desde slot b → continuar. Si no → DETENERSE (slot b inviable).

Restaurar slot a tras el diagnóstico:

```
fastboot set_active a
fastboot reboot
```

### 4. [EX1/EX2] Prueba de arranque con dtbo_b borrado

```
fastboot flash boot_b <boot.img-histórico-kernel-6.1-o-append-dtb>
fastboot flash vbmeta_b local-private/historical-port/artifacts/vbmeta-historical-pmos-flags2.img
fastboot erase dtbo_b
fastboot set_active b
fastboot reboot
```

Registrar: ¿USB 18d1:d00d (fastboot) o gadget de kernel? ¿log de consola?.
Restaurar siempre al final:

```
fastboot set_active a
fastboot reboot
```

### 5. [EX3] Reproducción histórica completa (SOLO tras EX1/EX2)

```
fastboot flash boot_b    <boot.img-histórico>
fastboot flash vbmeta_b  <vbmeta-flags2>
fastboot flash system_b  <rootfs-pmos-histórico>   # OJO: ver R4 y límite
fastboot erase dtbo_b
fastboot set_active b
fastboot reboot
```

## Restauración de emergencia (siempre disponible)

- Slot a intacto: `fastboot set_active a` + `fastboot reboot` → /e/OS.
- Reponer boot_b/vbmeta_b/dtbo_b desde los respaldos físicos (R8).
- persist/modemst/fsg/fsc/modem: nunca escribir sin procedimiento específico.

## Advertencias

- `fastboot flash boot`/`vbmeta`/`system` SIN sufijo está PROHIBIDO (afectaría
  el slot activo).
- `fastboot erase dtbo` sin sufijo PROHIBIDO → siempre `dtbo_b`.
- No ejecutar `-w`, `flashall`, `format`, `oem`, `flashing` sin autorización.
- ADB mientras el dispositivo está en Fastboot: prohibido al agente.
