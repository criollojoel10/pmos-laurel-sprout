# Boot no destructivo

Estado: boot image de diagnóstico **construido y validado en CI** (2026-08-04).
Pendiente: autorización explícita para la prueba física en hardware (FASE 8).

> 2026-08-05: `fastboot boot` (boot en RAM) fue rechazado por ESTE bootloader
> (`FAILED remote: 'unknown command'`), registrado como
> `FASTBOOT_BOOT_COMMAND_UNSUPPORTED` (`reports/h0-first-boot.md`,
> `reports/h0-fastboot-command-result.md`). No se ejecutó el kernel ni el
> initramfs; no hubo rechazo del contenido de la imagen. La vía no destructiva
> está **bloqueada en este dispositivo**, por lo que la prueba persistente
> controlada (escribir el boot image en `boot_<TARGET_SLOT>`) es la estrategia
> planificada, con recovery-kit en `local-private/phase-e-flash/recovery-kit/`.

## Principios

- El dispositivo es de SOLO LECTURA hasta autorización explícita.
- Nada se escribe en flash: ni `boot_a/b`, ni `dtbo`, ni `vbmeta`, ni slot.
- Se usa `fastboot boot` (boot en RAM) para pruebas.

## Imagen de boot (construida)

- **Artefacto CI**: `boot-laurel-diagnostic.img` (21,499,904 bytes, 21.5 MB)
  del run `30916017707` (workflow `04-build-diagnostic-boot`).
  SHA256: `66e7005fa031dd4f3117c56b9fa01f2c123377c95604a0975edd343cf6090b9d`.
- Formato: boot image header v2 (AOSP), page 4096, base 0x0,
  kernel 0x8000, ramdisk 0x1000000, tags 0x100, dtb 0x1f00000.
- Contenido: kernel mainline v7.1 debug (`Image.gz`, 20 MB) + initramfs de
  diagnóstico (busybox **arm64 estático**, 2.2 MB) + `sm6125-xiaomi-laurel-sprout.dtb`
  (37 KB) embebido (QCDT). No depende de la partición `dtbo`.
- **Validado**: round-trip kernel/ramdisk/dtb byte-idénticos
  (`scripts/inspect-boot-image.sh`); cabe en la partición boot (64 MiB);
  busybox `ELF aarch64, statically linked` confirmado.
- Cmdline: `console=ttyMSM0,115200n8 clk_ignore_unused
  androidboot.hardware=qcom ...`.
- El ensamblado usa `scripts/build-boot-image.py` (autocontenido, sin
  dependencias de paquete mkbootimg; formato verificado byte-por-byte contra
  mkbootimg — solo difiere el campo `id[0:20]`, irrelevante para el arranque).

> 2026-08-04 (incidente resuelto): el artefacto previo (run `30835329663`,
> SHA256 `e1be6bb9…`) contenía un busybox **x86-64** (paquete busybox-static de
> Ubuntu) incompatible con el dispositivo aarch64 (fallaría con `exec format
> error`). Se reconstruyó el initramfs con un busybox estático arm64 compilado
> en CI (`scripts/build-busybox-arm64.sh`); verificado `ARM aarch64`. El
> artefacto actual del run `30916017707` es el válido.

## Parámetros reales del dispositivo (consultados 2026-08-03, solo lectura)

| Parámetro | Valor |
|---|---|
| product | `laurel_sprout` |
| current-slot | `a` |
| unlocked | `yes` |
| slot-count | `2` |
| has-slot:boot | `yes` |
| has-slot:dtbo | variable no definida (pero existen dtbo_a/dtbo_b, ver abajo) |
| has-slot:vbmeta | variable no definida (pero existen vbmeta_a/vbmeta_b) |
| partition-size:boot_a | 0x4000000 (64 MiB) |
| partition-size:boot_b | 0x4000000 (64 MiB) |
| partition-size:dtbo_a | 0x1800000 (24 MiB) |
| partition-size:dtbo_b | 0x1800000 (24 MiB) |
| partition-size:vbmeta_a | 0x10000 (64 KiB) |
| partition-size:vbmeta_b | 0x10000 (64 KiB) |
| partition-type | `raw` (boot/dtbo/vbmeta, A y B) |

Observación: `has-slot:boot` está definido (boot es A/B). Las variables
`has-slot:dtbo` y `has-slot:vbmeta` NO están definidas por el bootloader
(devuelven "GetVar Variable Not found"), aunque las particiones dtbo_a/b y
vbmeta_a/b sí existen (tienen tamaños). Para un boot no destructivo esto
confirma que el DTB debe ir **embebido en boot.img** (QCDT), sin depender de
`dtbo`.

## Flujo de prueba (manual, con autorización)

1. Autorización explícita del usuario (FASE 8 completa).
2. Descargar el artefacto `boot-laurel-diagnostic` del run 30916017707
   (`gh run download 30916017707 -n boot-laurel-diagnostic -D out/`).
3. Verificar SHA256 contra `66e7005fa031dd4f3117c56b9fa01f2c123377c95604a0975edd343cf6090b9d`.
4. `fastboot devices` (solo lectura) y `fastboot getvar current-slot`.
5. `fastboot boot out/boot-laurel-diagnostic.img` (RAM; no escribe nada).
6. Recoger logs vía serial/dmesg y procesar con
   `scripts/process-device-logs.sh` (+ `scripts/sanitize-logs.sh`).
7. Apagar o reboot normal (sin tocar flash) para volver al sistema anterior.

## Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| DTB en boot.img incompatible | validar QCDT contra índices conocidos |
| Bootloader exige dtbo | usar boot con DTB integrado; si falla, registrar y NO flashear |
| Pérdida de boot funcional | nunca flash sin respaldos previos |
| Logs con datos privados | `scripts/sanitize-logs.sh` antes de publicar |

## Relación con otros docs

- `docs/DECISIONS/0006-boot-no-destructivo.md`
- `scripts/flash-helper.sh` (dry-run)
- `docs/RECOVERY.md`
