# Problemas conocidos

Lista de problemas conocidos y limitaciones actuales del port. Los estados
canónicos de hardware están en `docs/HARDWARE-STATUS.md`.

## Kupfer + Phosh (2026-11-21)

- **Credenciales por defecto:** el perfil de `26-build-kupfer` crea
  `user` / `changeme` (SSH y sudo). Cámbiala en el primer arranque:
  `passwd` y `sudo passwd`. El repo no guarda contraseñas reales.
- **Bloqueo por intentos fallidos (`pam_faillock`):** si se falla la contraseña
  varias veces, el login (SSH incluido) se bloquea temporalmente. Recuperación:
  1. esperar `unlock_time` (por defecto 600 s) o **reiniciar** (si el estado
     vive en `/var/run/faillock`, que es tmpfs);
  2. ya dentro: `sudo scripts/reset-faillock-laurel.sh user`
     (`faillock --user user --reset`);
  3. si la contraseña se perdió: reflashear `userdata` con el `rootfs.img`
     verificado. Vuelve a `changeme`, borra los cambios desde el flasheo y
     **no toca el slot a/Android**.
- **`fastboot boot` no está soportado** por el ABL del Mi A3. Para pruebas se
  escribe en el slot inactivo. El cliente validado es **fastboot 30.0.5**
  (`scripts/build-fastboot-30.0.5.sh`); con 33/37 el ABL responde
  `unknown command`.
- **Wi‑Fi con MAC aleatoria** en cada arranque: la IP de DHCP puede cambiar.
- **Avisos inofensivos:** `ath10k_snoc: chan info: invalid frequency 0`,
  `invalid MAC address; choosing random`, `a630_sqe.fw` cargando tarde “from new
  location”, `MultiMedia1: no backend DAIs` antes del routing del altavoz.
- **Audio:** el altavoz inferior funciona (ADSP + APR + MAX98937). Auricular y
  micrófonos (WCD937x/LPASS/SoundWire) siguen **not-targeted**.
- **Módem/cámara:** fuera de alcance; el MPSS solo se usa para Wi‑Fi.
- **Privacidad:** no publicar serial, IMEI, MAC, PSK de Wi‑Fi ni logs sin
  sanear.

## Dual-boot XNU/HakiOS y GPT del boot LUN

- HakiOS usa un `qbootctl` parcheado que escribe los GUID de slot y atributos
  del GPT del **boot LUN 4**. Si queda inconsistente, el ABL intenta arrancar
  y cae a fastboot en ambos slots, sin llegar al kernel.
- Vuelta segura: `fastboot set_active b`. Si no basta, restaurar
  `gpt_both4.bin` del ROM oficial con `fastboot flash partition:4` (solo LUN 4;
  nunca `gpt_both0.bin`/LUN 0 con datos) y reflashear boot/vbmeta.
- Procedimiento: `docs/FLASH-DESDE-BEGONIA.md` §9; incidencia:
  `reports/physical-tests/KUPFER-2026-11-21-RECOVERY/result.md`.

## Boot image / ABL

- El ABL de `laurel_sprout` solo arranca **header v0 + DTB concatenado**
  (`append_dtb`), page 4096, base 0x0 (evidencia 6.1 sedfix →
  `INITRAMFS_SHELL_ACTIVE`). Los headers **v2** caen a Fastboot (incluida la
  imagen NixOS v2, `bootloader-rejected`). `vendor_boot` nunca se usa.
- **`fastboot boot` rechazado** con clientes 37.0.0 y 33.0.3
  (`FASTBOOT_BOOT_COMMAND_UNSUPPORTED`): la prueba física se hace flasheando el
  slot inactivo y conservando el otro para recuperación.
- `has-slot:dtbo` y `has-slot:vbmeta` no existen como variables en este ABL,
  aunque las particiones `dtbo_a/b` y `vbmeta_a/b` sí existen.

## pmOS / histórico

- El rootfs histórico 6.1 se reprodujo y validó en CI; el display v7.1 dio
  pantalla negra en la prueba de agosto. El camino activo es Kupfer mainline
  7.2.6 + Phosh.
- `boot-laurel-nixos-console-v0-append.img` validada en CI, sin prueba física:
  sha256 `1043b607ce05515308de5b164f9bbc93667a86a2659f4f9f537f3cfbd94ecd78`.

## Cómo reportar

Abrir un issue con la plantilla correspondiente en `.github/ISSUE_TEMPLATE/`
(build-failure, hardware-test o regression). Los logs se suben sanitizados.
