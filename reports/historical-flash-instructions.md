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

### 0. Prerrequisitos verificados (bloqueante)

- [ ] `local-private/backups/<fecha>/` COMPLETO (R8): boot_a/b, dtbo_a/b,
      vbmeta_a/b, persist, modemst1/2, fsg, fsc.
- [ ] `fastboot devices` muestra el dispositivo (serial sanitizado en logs).
- [ ] `current-slot: a` (slot a intacto = punto de retorno).
- [ ] Artefactos con SHA256 registrado y correcto.

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
