# Prueba física — Kupfer + Phosh en laurel (2026-11-21)

- Artefacto: run `44848808710`, `kupfer-laurel-phosh`
  (`boot.img` sha256 `ce4c7de5…`, `rootfs.img.zst` sha256 `dda2819a…`).
- Flasheo: desde begonia (USB host) con **fastboot 30.0.5** compilado nativo
  (nmeum/android-tools tag `30.0.5`), a slot **b** + `userdata`.
- Comandos de flasheo: `flash vbmeta_b`, `erase dtbo_b`, `flash userdata`,
  `flash boot_b`, `set_active b`, `reboot`.
- Acceso: SSH por RNDIS USB (`172.16.42.1`, interfaz movida a un netns para
  no chocar con el `usb0` de begonia) y por Wi-Fi (LAN).
- Herramientas: `fastboot 30.0.5-android-tools` construido nativo con
  `scripts/build-fastboot-30.0.5.sh`; `adb 37.0.0p1`.
- Runbook reproducible: `docs/FLASH-DESDE-BEGONIA.md`.

## Resultado

| Componente | Estado | Evidencia |
|---|---|---|
| Arranque + systemd | `working` | `Linux laurel 7.2.6-sm61x5`, `systemctl is-system-running` = `running`, 0 unidades fallidas |
| Slot A/B (`qbootctl`) | `working` | `qbootctl`: `Current slot: _b`, `Successful: 1`; el servicio marcó el slot en el arranque |
| Pantalla / DSI | `working` | `card1-DSI-1: connected`, `/dev/fb0`; `msm_dpu` + `msm_dsi` enlazados |
| GPU Adreno 610 | `working` | `/dev/dri/renderD128`; `a630_sqe.fw` cargado; `adreno 5900000.gpu` enlazado a `a3xx_ops` |
| Phosh | `working` | `phosh.service` activo; procesos `phosh` y `phoc` |
| Táctil FT3518 | `working` | `generic ft5x06 (48)` → `event3`; 5 dispositivos input |
| Batería PMI632 | `working` | `/sys/class/power_supply/mia3-qg`: capacidad 55 %, 3,914 V |
| Carga limitable | `working` | `chargectl` activo; `pmi632_chg` con `charging_enabled=0` por objetivo de 50 % |
| Wi‑Fi WCN3990 | `working` | `iw dev wlan0 scan` → 14 BSS; asociada por NetworkManager; ping a Internet OK |
| Audio (altavoz) | `partially-working` | ADSP arriba, APR/Q6 cargados, tarjeta `Mi-A3`, `speaker-test` reproduce; auricular/micrófonos no |
| SSH | `working` | USB RNDIS y Wi‑Fi (LAN) |

## Avisos inofensivos vistos en dmesg/journal

- `ath10k_snoc: chan info: invalid frequency 0 (idx 41 out of bounds)` (conocido
  del DTB k7; no impide escanear/asociar).
- `ath10k_snoc: invalid MAC address; choosing random` (MAC aleatoria por arranque).
- `a630_sqe.fw` falla la primera carga directa y se carga más tarde “from new
  location” (mismo comportamiento que la prueba de referencia; la GPU queda
  operativa).
- `MultiMedia1: ASoC: no backend DAIs enabled` (sonda de PipeWire/ALSA antes de
  que el routing del altavoz esté listo; la reproducción por `MultiMedia3`
  funciona).
- `qcom_q6v5_pas: Handover signaled, but it already happened` (ADSP/MPSS).

## Incidencia posterior: bloqueo de login

Tras la prueba, un cambio/olvido de contraseña y varios intentos fallidos
dejaron el login bloqueado (`pam_faillock`). Procedimiento documentado para
recuperarlo sin perder datos: reiniciar (el contador vive en tmpfs por defecto)
y, ya dentro, `sudo scripts/reset-faillock-laurel.sh user`; si la contraseña se
perdió, reflashear solo `userdata` (vuelve a `changeme`, no toca el slot a).
Detalle en `docs/FLASH-DESDE-BEGONIA.md` §5.2 y `docs/KNOWN-ISSUES.md`.

## Reproducir la verificación

```sh
# en el telefono (solo lectura)
sh scripts/verify-kupfer-laurel.sh

# datos que necesitan root
sudo qbootctl
sudo dmesg | grep -iE 'adsp|ath10k|a630|panel'
```

No se publican serial, IMEI, MAC ni claves Wi‑Fi de esta unidad.
