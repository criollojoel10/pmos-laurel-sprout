# Guía de respaldo físico del dispositivo (R8)

Documento de aplicación ESTRICTA antes de cualquier prueba que escriba en el
teléfono. El AGENTE no ejecuta estos comandos; los ejecuta el USUARIO con
autorización explícita. Esta guía documenta el procedimiento y los comandos.

Estado actual del dispositivo: **Fastboot, `current-slot: a`** (leído
solo-lectura). El respaldo se hace desde **/e/OS (slot a)** con root.

## Prerrequisitos

- Dispositivo en /e/OS (slot a) o recovery con root.
- `adb` autorizado en el host (USB debugging).
- Almacenamiento local suficiente (~300 MiB).
- Los respaldos NUNCA se publican: vivirán en `local-private/backups/`
  (gitignore), con SHA256 y sin serial/IMEI en los nombres.

## Paso 0 — Arrancar /e/OS desde Fastboot

El usuario ejecuta (autorización previa):

```
fastboot set_active a
fastboot reboot
```

Esperar a /e/OS. Confirmar con `adb devices`.

## Paso 1 — Root shell en el dispositivo

```
adb shell
su
```

(En /e/OS el superusuario se habilita en Ajustes → *; si no hay root, se
arranca recovery con `adb root` si el recovery lo permite, o se usa un
recovery root como TWRP.)

## Paso 2 — Localizar las particiones

En el dispositivo root:

```
ls -la /dev/block/by-name/ | grep -E "boot|dtbo|vbmeta|persist|modemst|fsg|fsc|modem"
```

Registrar las rutas exactas de:

| Partición | Ruta esperada | Tamaño esperado |
|---|---|---|
| boot_a / boot_b | /dev/block/by-name/boot_a / boot_b | 64 MiB (0x4000000) |
| dtbo_a / dtbo_b | /dev/block/by-name/dtbo_a / dtbo_b | 24 MiB (0x1800000) |
| vbmeta_a / vbmeta_b | /dev/block/by-name/vbmeta_a / vbmeta_b | 64 KiB (0x10000) |
| persist | /dev/block/by-name/persist | ~16 MiB |
| modemst1 / modemst2 | /dev/block/by-name/modemst1 / modemst2 | ~4 MiB c/u |
| fsg / fsc | /dev/block/by-name/fsg / fsc | ~4 MiB c/u |
| modem | /dev/block/by-name/modem | ~100-200 MiB |

> NOTA: tamaños medidos por `fastboot getvar partition-size:*` (2026-08-06,
> lecturas de solo lectura). Este dispositivo NO tiene partición `super`;
> `system_a`/`system_b` son particiones ext4 físicas de 3 GiB (0xC0000000)
> que contienen /e/OS y NO se respaldan.

Verificar los tamaños contra `device-metadata/fastboot-sanitized.json`
(preflight-fastboot-sanitized.txt).

## Paso 3 — Extraer los respaldos

En el dispositivo (root shell), en `/data/local/tmp`:

```
cd /data/local/tmp
dd if=/dev/block/by-name/boot_a    of=boot_a.img    bs=1M status=progress
dd if=/dev/block/by-name/boot_b    of=boot_b.img    bs=1M status=progress
dd if=/dev/block/by-name/dtbo_a    of=dtbo_a.img    bs=1M status=progress
dd if=/dev/block/by-name/dtbo_b    of=dtbo_b.img    bs=1M status=progress
dd if=/dev/block/by-name/vbmeta_a  of=vbmeta_a.img  bs=1M status=progress
dd if=/dev/block/by-name/vbmeta_b  of=vbmeta_b.img  bs=1M status=progress
dd if=/dev/block/by-name/persist   of=persist.img   bs=1M status=progress
dd if=/dev/block/by-name/modemst1  of=modemst1.img  bs=1M status=progress
dd if=/dev/block/by-name/modemst2  of=modemst2.img  bs=1M status=progress
dd if=/dev/block/by-name/fsg       of=fsg.img       bs=1M status=progress
dd if=/dev/block/by-name/fsc       of=fsc.img       bs=1M status=progress
```

Para `modem`: decidir si se respalda (tamaño grande, solo lectura; si la ROM
stock está identificada y disponible, el respaldo de modem puede omitirse
documentándolo).

## Paso 4 — Bajar los respaldos al host

En el host:

```
mkdir -p local-private/backups/<fecha-iso>
adb pull /data/local/tmp/boot_a.img local-private/backups/<fecha-iso>/
# ... repetir para cada partición respaldada
adb shell rm /data/local/tmp/boot_a.img  # limpiar tras verificar
```

> NOTA: `local-private/` está en `.gitignore`; nunca `git add` estos archivos.

## Paso 5 — Verificar

En el host:

```
sha256sum local-private/backups/<fecha-iso>/*.img > local-private/backups/<fecha-iso>/SHA256SUMS
ls -la local-private/backups/<fecha-iso>/
```

Verificar que los tamaños coinciden con el preflight (64 MiB boot, 24 MiB
dtbo, 64 KiB vbmeta) y que el contenido no está vacío ni es todo ceros.

## Paso 6 — Registrar

Actualizar `local-private/backups/manifest.json` (o `reports/backup-status.md`)
con: fecha, particiones respaldadas, SHA256, y marcar el estado como COMPLETO.
Este registro es condición obligatoria para el gate FASE 8.

## Restauración (referencia)

```
fastboot flash boot_<slot>   respaldo-boot_<slot>.img
fastboot flash dtbo_<slot>   respaldo-dtbo_<slot>.img
fastboot flash vbmeta_<slot> respaldo-vbmeta_<slot>.img
```

Persist/modemst/fsg/fsc/modem: SOLO si se corrompieron y con procedimiento
documentado; son identidad de radio.
