# Reporte R13 — Guía de respaldo físico R8 (gate FASE 8)

Fecha: 2026-08-08. Estado: **guía operativa; los respaldos R8 NO existen aún**
(`local-private/backups/` ausente). Sin respaldos completos NO se flashea nada
(AGENTS.md §7, prerequisito bloqueante 0 de `reports/historical-flash-instructions.md`).

## Principio

El AGENTE no ejecuta estos comandos en el dispositivo. El USUARIO los ejecuta
en el teléfono (Android con root / recovery) y guarda la salida en
`local-private/backups/<fecha>/` (fuera del repo público). El `dd` de lectura
NO modifica el dispositivo; aun así, se hace primero una vuelta a Fastboot con
`solo lectura` para verificar slot activo y tamaños.

## Qué se necesita (checklist mínimo AGENTS.md §7)

| Partición | Fuente | ¿Crítica? |
|---|---|---|
| `boot_a`, `boot_b` | `dd` desde Android root, o extraer de payload de la ROM instalada (/e/OS 4.1.1) | sí |
| `dtbo_a`, `dtbo_b` | `dd` desde Android root, o extraer de payload de la ROM | sí |
| `vbmeta_a`, `vbmeta_b` | `dd` desde Android root, o extraer de payload de la ROM | sí |
| `persist` | SOLO `dd` desde Android root (es específica de esta unidad) | sí |
| `modemst1`, `modemst2` | SOLO `dd` desde Android root (identidad de radio) | sí |
| `fsg`, `fsc` | SOLO `dd` desde Android root (identidad de radio) | sí |
| `modem` (NON-HLOS), `dsp` (ADSP) | `dd` desde Android root, o extraer de la ROM | recomendable |
| `bluetooth`, `secdata`, `sts`, `spul`, `qupfw` | `dd` desde Android root | recomendable |

Persist, modemst1/2, fsg y fsc NO se obtienen de ninguna ROM: son calibración e
identidad generadas en fábrica. Si se pierden sin respaldo, la radio puede
quedar sin IMEI ni calibración.

## Estado actual de lo ya disponible (NO son respaldos completos)

Extraídos de las ROMs (referencia, no estado actual del dispositivo):

- `/e/OS 4.1.1 (A16)` → `local-private/rom-analysis/eos/`: `boot.img` (64 MiB),
  `dtbo.img` (8 MiB), `vbmeta.img` (4 KiB), `vendor.img`.
- `stock MIUI V12.0.26.0 (Android 11)` → `local-private/rom-analysis/stock/`:
  `boot.img`, `dtbo.img`, `vbmeta.img`.
- Recovery kit → `local-private/phase-e-flash/recovery-kit/`:
  `KNOWN_GOOD_boot_eos-4.1.1.img` (SHA256 `87ceeb42…`), `TEST_IMG_…diagnostic.img`
  (SHA256 `66e7005f…`), `VBMETA_custom_flags3_eos.img` (SHA256 `b5c6ca4a…`).

Estos sirven para restaurar boot/dtbo/vbmeta desde ROM si el `dd` de una
partición fallara, pero el estado REAL de `boot_a/b`, `dtbo_a/b`, `vbmeta_a/b`,
`persist` y radio debe respaldarse del propio dispositivo.

## Preflight read-only ya registrado (2026-08-08)

`local-private/phase-e-flash/preflight/r8/preflight-fastboot-sanitized.txt`:
`current-slot: a`, `unlocked: yes`, `slot-count: 2`,
`boot_a/b = 0x4000000` (64 MiB), `dtbo_a/b = 0x1800000` (24 MiB),
`vbmeta_a/b = 0x10000` (64 KiB). Pendiente de autorizar: `partition-size:system_b`
(no está en la lista permitida de AGENTS.md).

## Procedimiento (USUARIO, en el teléfono)

### A. Desde /e/OS con root (Método recomendado)

1. Habilitar root (Magisk o `/e/OS` advanced settings) o arrancar recovery root.
2. Abrir terminal root y verificar rutas:

```
ls -l /dev/block/bootdevice/by-name/ | grep -E 'boot|dtbo|vbmeta|persist|modem|fsg|fsc'
```

3. Respaldar cada partición a `/sdcard/backup-pmos/` (o `/data/local/tmp`):

```
D=/sdcard/backup-pmos; mkdir -p "$D"
for p in boot_a boot_b dtbo_a dtbo_b vbmeta_a vbmeta_b persist modemst1 modemst2 fsg fsc modem dsp; do
  [ -e "/dev/block/bootdevice/by-name/$p" ] && dd if="/dev/block/bootdevice/by-name/$p" of="$D/$p.img" bs=4M
done
```

4. Copiar `$D/*` al host y guardar en `local-private/backups/<fecha>/`.
   Calcular SHA-256 y registrarlos en `SHA256SUMS` del directorio.

### B. Desde recovery con `dd` (si el teléfono no arranca a /e/OS)

- TWRP/OrangeFox con soporte de terminal: montar `/sdcard`, mismo `dd` que A3.

### C. Registro obligatorio tras el respaldo

Actualizar `reports/historical-backup-guide-r8.md` (checklist marcado) y crear
`local-private/backups/<fecha>/manifest.json` con: fecha, slot activo, tamaños
(0x…), SHA-256 de cada partición, origen (dd del dispositivo), y hash de las
imágenes de ROM de referencia. Sin este manifest, el gate FASE 8 permanece
cerrado.

## Advertencias

- NUNCA escribir `persist`, `modemst1/2`, `fsg`, `fsc` sin procedimiento
  específico; son solo lectura para diagnóstico.
- No flashear `boot`/`dtbo`/`vbmeta`/`system` sin sufijo de slot.
- `local-private/` está gitignored: los respaldos NO se suben al repo público.
- Prohibido Git LFS para respaldos (AGENTS.md §1).
