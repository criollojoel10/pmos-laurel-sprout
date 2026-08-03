# Boot no destructivo

Estado: propuesta (2026-08-02). Requiere autorización explícita para ejecutar
cualquier cosa en hardware (FASE 8).

## Principios

- El dispositivo es de SOLO LECTURA hasta autorización explícita.
- Nada se escribe en flash: ni `boot_a/b`, ni `dtbo`, ni `vbmeta`, ni slot.
- Se usa `fastboot boot` (boot en RAM) para pruebas.

## Imagen de boot

- `boot.img` formato v2+ (Android boot image) con DTB mainline embebido
  (QCDT), para no depender de la partición `dtbo`.
- Tamaño límite: partición `boot` = 64 MiB (0x4000000), slot A/B.
- Se valida con `scripts/inspect-boot-image.sh` antes de cualquier prueba.

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
2. Verificar `fastboot devices` (solo lectura).
3. Confirmar slot actual (`fastboot getvar current-slot`).
4. Copia de seguridad previa registrada (boot/dtbo/vbmeta A y B) según
   AGENTS.md sección 7.
5. `fastboot boot boot.img` (RAM; no escribe).
6. Recoger logs vía `dmesg`/serial y procesar con
   `scripts/process-device-logs.sh`.
7. Reboot normal (sin tocar flash) para volver al sistema anterior.

## Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| DTB en boot.img incompatible | validar QCDT contra indices conocidos |
| Bootloader exige dtbo | usar boot con DTB integrado; si falla, registrar y NO flashear |
| Pérdida de boot funcional | nunca flash sin respaldos previos |
| Logs con datos privados | `scripts/sanitize-logs.sh` antes de publicar |

## Relación con otros docs

- `docs/DECISIONS/0006-boot-no-destructivo.md`
- `scripts/flash-helper.sh` (dry-run)
- `docs/RECOVERY.md`
