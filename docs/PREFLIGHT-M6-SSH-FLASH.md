# Pre-flight FASE 8 — Flasheo M6: rootfs SSH histórico 6.1 en `system_b`

Fecha de preparación: 2026-08-10.
Run en curso: `31355730519` (workflow `11-build-historical-ssh-rootfs`, rama
`main`, commit `58b53e7`). Monitor: `scripts/monitor-workflow.sh` + cron
`*/5` → `local-private/workflow-11-monitor/<run>.log`.

> **PUNTO DE PARADA (AGENTS.md §8).** Este documento es una checklist, NO una
> autorización. Ningún comando se ejecuta en el dispositivo hasta que el
> usuario conceda autorización explícita e inmediata a la prueba que se le
> propone aquí.

## 1. Objetivo

Flashear `xiaomi-laurel-ssh.img` (rootfs histórico 6.1, imagen MBR COMPLETA,
con `sshd` habilitado y `authorized_keys`) a la partición **`system_b`**,
manteniendo `boot_b` intacto. Meta: acceso remoto `ssh root@172.16.42.1` por
el gadget USB RNDIS (única red disponible hoy) para recoger `dmesg`/logs.

El arranque base ya está probado: `PMOS_CONSOLE_6_1_BOOTED` (2026-08-09,
`reports/physical-tests/PMOS-CONSOLE-6_1-BOOTED/result.md`).

## 2. Estado del dispositivo (fastboot read-only, 2026-08-10)

| Dato | Valor |
|---|---|
| product | `laurel_sprout` |
| unlocked | `yes` |
| slot-count | 2 |
| current-slot | **b** |
| Sector MBR del deviceinfo | 4096 (los LBA del MBR usan 4096 B) |
| boot_a / boot_b | 64 MiB (`0x4000000`), tipo `raw` |
| dtbo_a / dtbo_b | 24 MiB (`0x1800000`), tipo `raw` |
| vbmeta_a / vbmeta_b | 64 KiB (`0x10000`), tipo `raw` |
| system_b | imagen MBR ~1.8–2.1 GiB raw; límite `0xC0000000` (3 GiB) confirmado en CI |
| serial / IMEI / MAC | **no se publican** |

## 3. Artefactos del run 11 (run 31355730519 SUCCESS, 2026-08-10)

| Artefacto | Valor |
|---|---|
| `xiaomi-laurel-ssh.img` (sparse) | 550,935,480 B — sha256 `ebc8287f277d8ffd28c5eb128e1248e668e44a316cb4484916d0748d5bc40a2a` |
| `xiaomi-laurel-ssh.raw` | sha256 `4040b8628282a5847b4419be084285279cc70037c281cf7f6d9a7d5e2d180b0d` |
| `final-part1.img` (p1 /boot ext2) | 247,463,936 B — sha256 `4e7704926c569ae1c133fdf4bc42de8204a19b8a2be0381ce437ec198e8b0208` |
| `final-part2.img` (p2 / ext4) | 1,835,008,000 B — sha256 `e8ab704aa997e84ce678664dee59bc737621068f804306ad7ed53ee0c8b53425` |
| `manifest.json` | fingerprint `SHA256:yXbMctxhVMzfEq40J1Wmb48IXTRvbGLn/ZMohLP7EEM` (== clave local), `flash_target: system_b`, `layout: MBR (msdos): p1 /boot ext2, p2 / ext4` |
| xz comprimido | `xiaomi-laurel-ssh.img.xz` 123,148,056 B |

Todos los checks del paso 18 (ver Apéndice A) pasaron en CI. Descarga local
`local-private/run31355730519-artifacts/` con **re-verificación sha256 local
COMPLETADA el 2026-08-10**: sparse, xz (descomprime al mismo hash), p1 y p2
coinciden con SHA256SUMS-final; `authorized_keys.pub` idéntico a la clave
local; fingerprint del manifest == clave local; tamaño ≤ 3 GiB. Script:
`scripts/fetch-ssh-artifacts.sh <run> --verify-only`.

## 4. Particiones que se modificarían

| Partición | Acción |
|---|---|
| **system_b** | ÚNICA modificación: `fastboot flash system_b xiaomi-laurel-ssh.img` |
| boot_a, boot_b, dtbo_a, dtbo_b, vbmeta_a, vbmeta_b | **NO se tocan** |

## 5. Estado persistente actual del slot b (no cambiar)

| Partición | Estado (2026-08-09) |
|---|---|
| boot_b | `boot.img` pmOS original (sha `3b692fef…`) |
| dtbo_b | **borrado** (prueba previa) |
| vbmeta_b | vbmeta histórico `flags=2` |
| system_b | `xiaomi-laurel.img` del run 10 (sha `754bd35c…`) |

Restaurar el estado previo a M6 = re-flashear ese mismo `xiaomi-laurel.img`
de vuelta a `system_b` (la imagen del run 10 se conserva en
`local-private/run31320766387-artifacts/artifacts/`).

## 6. Respaldos — gate FASE 7 CERRADO (2026-08-09)

`local-private/backups/2026-08-09/` — 13 particiones, ~427 MiB, con
`manifest.json` + `SHA256SUMS`:

`boot_a`, `boot_b`, `dtbo_a`, `dtbo_b`, `vbmeta_a`, `vbmeta_b`, `dsp_a`,
`modem_a`, `modemst1`, `modemst2`, `fsg`, `fsc`, `persist`.

Identidad de radio (modemst1/2, fsg, fsc, persist) capturada de esta unidad.
Firmware stock identificado y guía de restauración en
`docs/RECOVERY.md` y `reports/historical-backup-guide-r8.md`.

## 7. Procedimiento de recuperación

1. **Revertir M6** (fallback sin respaldo adicional): `fastboot flash system_b
   xiaomi-laurel.img` (run 10). `boot_b` nunca se toca → el arranque conocido
   queda garantizado.
2. **Restaurar cualquier partición**: `fastboot flash <part> <part>.img` desde
   `local-private/backups/2026-08-09/` (boot/dtbo/vbmeta A/B incluidas).
3. **Stock completo / brick**: `docs/RECOVERY.md` (EDL/stock firmware) e
   instrucciones históricas en `reports/historical-flash-instructions.md`.

## 8. Procedimiento de flasheo propuesto (NO ejecutado; requiere autorización)

```sh
fastboot getvar current-slot          # verificar b
fastboot flash system_b xiaomi-laurel-ssh.img
fastboot reboot
# host: gadget RNDIS en 172.16.42.2, teléfono 172.16.42.1
ssh -o StrictHostKeyChecking=accept-new root@172.16.42.1
```

Verificación tras arrancar: prompt de login pmOS, `ping 172.16.42.1`, huella
Ed25519 de `/root/.ssh/authorized_keys` en la imagen vs la local
(`ssh-keygen -lf local-private/ssh-laurel/id_ed25519.pub`), `dmesg` sin panic.

## 9. Prueba menos destructiva recomendada

El flasheo de `system_b` es el paso mínimo posible: no toca `boot_b` (el
arranque probado queda intacto) ni las particiones A. No hay ninguna prueba
más pequeña que habilite SSH (el rootfs actual se instaló con `--no-sshd`).
La alternativa previa sin flasheo (boot temporal) sigue prohibida sin
autorización.

## 10. Checklist de autorización (FASE 8 — DETENERSE aquí)

- [ ] Artefactos del run 11 descargados y sha256 verificados.
- [ ] Tamaño sparse ≤ 3 GiB (límite `system_b`).
- [ ] `current-slot = b` reconfirmado inmediatamente antes.
- [ ] Respaldos presentes (2026-08-09, gate §7 cerrado).
- [ ] Recuperación documentada (§7) y probada en seco (comandos listos).
- [ ] Usuario autorizó explícitamente esta prueba: ____________.

> Hasta que los seis puntos estén marcados, no se ejecuta ningún comando.

## Apéndice A — Qué prueba la validación del paso 18 (run 11)

Cuando el run finalice, el paso «Generar xiaomi-laurel-ssh.img (sparse) y
validar el artefacto final» debe imprimir todos los `OK` siguientes (cada
fallo corta con `exit 1`):

1. Firma MBR `0x55aa` en el byte 510 de la imagen final.
2. Particiones MBR `final p1` (boot) y `final p2` (root) extraídas con `dd`
   (`bs=4096`, LBA del deviceinfo).
3. `e2fsck -f -n` de `final-part2.img` limpio (sin errores) — fs ext4 íntegro.
4. `p1` byte-idéntica a la base (hash igual) → el endurecido no tocó boot.
5. `/usr/sbin/sshd` y `/etc/init.d/sshd` presentes como archivos regulares.
6. `/etc/runlevels/default/sshd` es symlink → sshd arrancará en boot.
7. `/root/.ssh/authorized_keys` == clave del secreto, modo `0600`.
8. `sshd_config`: `PermitRootLogin prohibit-password`,
   `PasswordAuthentication no`, `PubkeyAuthentication yes`.
9. Tamaño sparse ≤ 3 GiB (`0xC0000000`) → cabe en `system_b`.

Salida final esperada (paso «Generar manifest»): `manifest.json` con
fingerprint de la clave, `flash_target: "system_b"` y `layout: "MBR (msdos):
p1 /boot ext2, p2 / ext4"`. Con los `OK` 1-9 y el manifest, el artefacto está
listo para el checklist de la sección 10.
