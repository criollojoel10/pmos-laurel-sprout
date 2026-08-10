# FASE 8 — Preflight: desbloqueo del apagado de pantalla (consoleblank=0)

**Fecha**: 2026-08-10. **Dispositivo**: Xiaomi Mi A3 `laurel_sprout`.
Este documento cumple el punto de parada obligatorio de AGENTS.md §8:
muestra artefactos, hashes, tamaños, slot, particiones a modificar, plan de
recuperación y respaldos; **NO continúa** hasta recibir autorización explícita.

## 1. Artefactos

| Artefacto | Tamaño (bytes) | SHA-256 |
|---|---|---|
| boot.img actual en `boot_b` (pmOS run 31320766387, export-resolved) | 12,402,688 | `3b692fef…` |
| `boot-consoleblank0.img` (parcheado: cmdline + `consoleblank=0`) | 12,402,688 | `b64eaaa8d692011b92b3f7634296411a597d056c98da185e3a11b70984ee20d2` |
| `vmlinuz` (kernel 6.1.0-sm6125) | 9,408,875 | `7dd4103e…` (idéntico en ambos boot.img) |
| `initramfs` | 2,973,250 | `089e344a…` (idéntico en ambos boot.img) |

La única diferencia entre ambos boot.img es el campo `cmdline` del header
(`clk_ignore_unused` → `clk_ignore_unused consoleblank=0`); kernel y ramdisk
son byte-idénticos (verificado por `scripts/patch-bootimg-cmdline.py`).

## 2. Tamaño de boot y límite

- Partición `boot_b` (y `boot_a`): **67,108,864 bytes** (0x4000000) — respaldo manifest `r8-2026-08-09`.
- Imagen a flashear: 12,402,688 bytes → cabe con 54 MB libres (margen 81%).

## 3. Slot y particiones que se modificarían

- **Slot actual: `b`** (`androidboot.slot_suffix=_b` en cmdline del último boot).
- Partición a escribir: **SOLO `boot_b`** (imagen de 12.4 MB).
- NO se tocan: `system_b`, `dtbo_b`, `vbmeta_b`, `persist`, `modem*`, ni se cambia de slot.

## 4. Respaldos (confirmados, manifest `r8-2026-08-09` en `local-private/backups/`)

| Partición | SHA-256 respaldo |
|---|---|
| `boot_a` (stock/eOS) | `c382ee59…` |
| `boot_b` (stock) | `a31f0bc8…` |
| `vbmeta_a` / `vbmeta_b` | `a734ca47…` (simétrico) |
| `dtbo_a` / `dtbo_b` | `ca6533b7…` (simétrico) |
| `persist` | `a2981cf1…` |
| `modemst1`/`modemst2`/`fsg`/`fsc` | respaldados |
| `modem_a`/`dsp_a` | respaldados |

## 5. Procedimiento de recuperación (rollback)

- **Revertir a estado funcional conocido**: reflashear `boot_b` con el boot.img
  original de run 31320766387 (`3b692fef…`, se conserva en
  `local-private/run31320766387-artifacts/export-resolved/boot.img`).
- **Revertir a stock**: flashear `boot_b` desde respaldo `boot_b.img` (`a31f0bc8…`).

## 6. Prueba recomendada (menos destructiva primero)

Orden propuesto, cada paso espera su autorización:

1. **P0 (sin flasheo, sin reboots)**: prueba visual del panel escribiendo un
   patrón rojo en `/dev/fb0` vía SSH — confirma que el panel está vivo y que el
   apagado era solo blanking de consola. Reversible (reinicia/fbcon redibuja).
2. **P1 (escritura única `boot_b`)**: flashear `boot-consoleblank0.img`.
   Objetivo: la consola permanece visible >10 min (sin apagado). Si falla,
   revertir con el boot.img de run 31320766387.
3. **P2 (a futuro)**: validar SSH rootfs rebuild (run 31393947046) y conectar
   input (teclado/OTG) para interacción local.

## 7. Estado de CI

- Run **31393947046** (workflow `11-build-historical-ssh-rootfs`, head
  `ac7d6fd`, iniciado 2026-08-10 13:38Z) estaba `in_progress` — rootfs SSH de
  referencia; no bloquea P0/P1.

## 8. Autorización

**DETENERSE AQUÍ.** Se requiere autorización explícita e inmediata para cada
prueba. Nada se flashea ni se escribe en el dispositivo sin este visto bueno.
