# Recuperación tras la instalación de XNU/HakiOS (2026-11-21)

- Estado: **recuperado y funcionando** (Kupfer + Phosh, slot b).
- No se publican serial, IMEI, MAC, PSK ni la contraseña elegida.

## Qué pasó

Tras el trabajo de HakiOS (`hakios-sm6125`) en el **slot a**, el ABL quedó
intentando arrancar y cayendo a fastboot en **ambos** slots. El `boot_a` tenía
la imagen UEFI y el trabajo de dual-boot había usado el `qbootctl` parcheado
para escribir los **GUID de slot y atributos del GPT del boot LUN (LUN 4)**.

Síntomas:

- `fastboot getvar current-slot` → `b`; `slot-unbootable:b` pasaba a `yes` y
  `slot-retry-count` bajaba hasta 0.
- Reflashear `boot_a/b`, `vbmeta_a/b`, borrar `dtbo`, `misc` y `set_active` no
  cambiaba nada: el ABL **intentaba** (bajaba el contador) pero el kernel no
  llegaba al initramfs.
- Se probaron tres initramfs (normal 31,5 MB, rescate 32,6 MB y rescate mínimo
  5,9 MB): ninguno levantó USB/panel. El `boot.img` y el DTB k7 eran correctos
  (sha256 verificado), así que el fallo estaba antes del kernel.
- Los tamaños/labels de las 89 particiones eran idénticos a los de antes de
  XNU: la tabla no estaba rota, solo la **metadata de slot del boot LUN**.

## Recuperación

1. Workflow `28-extract-stock-gpt` (CI, red rápida) descarga el ROM oficial
   `V12.0.26.0.RFQMIXM` y publica solo los ficheros pequeños:
   `gpt_both*.bin`, `prog_firehose_ddr.elf`, `flash-all`, `boot.img`,
   `vbmeta.img`.
2. Se restaura **solo el GPT del boot LUN 4** con fastboot 30.0.5:

   ```sh
   fastboot flash partition:4 gpt_both4.bin
   ```

   **No** se toca `gpt_both0.bin` (LUN 0 / datos) ni `userdata`.
3. Se reflashan `boot_a/b` (Linux), `vbmeta_a/b` (flags=2), se borran
   `dtbo_a/b` y se marca `set_active b`.
4. Se reflasheó `userdata` con el `rootfs.img` verificado (autorizado por el
   operador; se perdió el backup de XNU que vivía dentro).
5. El teléfono arrancó Linux; el gadget RNDIS (`Arch Linux ARM`) apareció y
   SSH respondió tras el primer arranque (generación de claves/reajuste de la
   rootfs, ~3 min).

## Estado tras recuperar (medido)

- `qbootctl`: `Current slot _b`, `SLOT _b Successful 1`.
- 0 unidades fallidas; `mia3-qg`, `mia3-audio`, `mia3-wifi`, `chargectl`,
  `tailscaled` y `laurel-performance` activos.
- Pantalla `card1-DSI-1 connected`, táctil FT5x06, `renderD128`, tarjeta
  `Mi-A3`, batería 98 %.
- Wi‑Fi `CLARO_JOEL` conectada; perfiles `Joel` y `SKYLIFE_ALEJANDRA_5G`
  copiados desde begonia.
- CPU `performance` (1,80/2,02 GHz) y GPU `performance`, persistente con
  `laurel-performance.service`.
- `sudo` sin contraseña (`/etc/sudoers.d/zz-user-nopasswd`).
- Sistema actualizado (`pacman -Syu`); Tailscale 1.104.7 instalado y
  `tailscaled` activo (la autenticación la hace el operador).

## Lección para el dual-boot

El `qbootctl` de HakiOS escribe metadata del boot LUN; si se interrumpe o deja
los GUIDs inconsistentes, el ABL puede intentar arrancar y fallar sin llegar al
kernel. La vuelta segura es `fastboot set_active b`; si eso no basta,
**restaurar `gpt_both4.bin` del ROM oficial** con `fastboot flash partition:4`
(no el LUN 0) y reflashear boot/vbmeta. El procedimiento está en
`docs/FLASH-DESDE-BEGONIA.md`.
