# Prueba física — Kupfer (Arch Linux ARM / Plasma Mobile) en laurel_sprout

- **Fecha:** 2026-10-17
- **Device:** Xiaomi Mi A3 `laurel_sprout` (bootloader unlocked)
- **Artefacto:** workflow `26-build-kupfer` run `39007976354` → `kupfer-laurel-plasma-mobile.zip`
- **Kernel:** `7.2.3-sm61x5 #1 SMP PREEMPT` (fork `sm61x5-mainline` v7.2.3-r0)
- **Método de flasheo:** `docs/FLASH-LAUREL-CACHYOS.md` (slot b + `userdata`; Android intacto en slot a)

> Varios pasos de esta prueba se aplicaron **en vivo sobre el dispositivo** (con `adb root`
> primero por USB y luego `ssh`). Todos los comandos están abajo para reproducirlos y como
> base del arreglo definitivo en el build.

## 1. Artefactos (verificados)

| Imagen | Bytes | SHA-256 | Destino |
|---|---|---|---|
| `boot.img` | 42 209 280 | `7fbf351e…` | `boot_b` |
| `vbmeta.img` | 4 096 | `e9f0f23c…` (idéntico al de pmOS) | `vbmeta_b` |
| `rootfs.img.zst` | 2 111 558 153 → `rootfs.img` 7 285 506 048 | `a93aba13…` | `userdata` |

- `rootfs.img` = **ext4 raw** (NO sparse), label **`kupfer_root`**, sin tabla de particiones.
- `boot.img` = header **v0 + DTB anexado**; cmdline
  `kupfer earlymodules=msm,panel-samsung-s6e8fc0-m1906f9,edt_ft5x06 console=tty0`.
- Initramfs: `etc/kupfer/deviceinfo` con `deviceinfo_partitions_data="/dev/disk/by-partlabel/userdata"`;
  el hook `rootfsdetect` busca `LABEL=kupfer_root` ahí → destino **`userdata`** confirmado.

## 2. Bloqueo 1 — no arrancaba (modo emergencia)

- **Síntoma:** el kernel/panel/root montan, `systemd` llega a la red USB, pero a los 90 s:
  `Timed out waiting for device /dev/disk/by-label/kupfer_boot`, falla `local-fs.target`,
  entra en **emergency mode**, apaga el gadget USB/SSH; root bloqueado → sin consola de rescate.
- **Causa:** `26-build-kupfer.yml` construye la imagen "full" (msdos: p1=`kupfer_boot`,
  p2=`kupfer_root`) pero extrae **solo p2** (`dd if=${LOOP}p2`) y lo flashea suelto en
  `userdata` → **no existe `kupfer_boot`**. El `/etc/fstab` heredado de Kupfer
  (`LABEL=kupfer_boot /boot ext2 rw,noatime`) apunta a esa subpartición ausente.
- **Fix aplicado (a la imagen con `debugfs`, sin montar):**
  ```
  LABEL=kupfer_boot /boot ext2 rw,noatime,nofail,x-systemd.device-timeout=5s 0 0
  ```
  + `/etc/systemd/system/emergency.service.d/override.conf` con
  `[Service] Environment=SYSTEMD_SULOGIN_FORCE=1`. `e2fsck -f` limpio.
  Reflasheado `userdata`.
- **Resultado:** `systemd` `running`, 0 unidades fallidas, SSH operativo
  (`user@172.16.42.1`, pass `changeme`) → luego por red.
- **Arreglo de build propuesto:** parchear ese `fstab` (o quitar la entrada) en el
  workflow antes de comprimir la rootfs (paso añadido en `26-build-kupfer.yml`).

## 3. Bloqueo 2 — GPU en software (KWin → llvmpipe)

- **Síntoma:** KWin elegía `llvmpipe` (CPU) → UI lenta.
- **Causa:** faltaba `qcom/a630_sqe.fw` (`adreno_request_fw failed`, `gpu hw init failed: -2`).
  Kupfer **sí** trae el zap shader (`a610_zap.mbn`, a diferencia del caso pmOS).
- **Fix:** instalado `a630_sqe.fw` de linux-firmware upstream (sha256
  `1c21b527d9183487cc550dabbb3f43e555df5a977a461934fc61f0635a9aa90c`). Carga tarde
  (t≈133 s, "from new location"), igual que en pmOS.
- **Resultado:** `kwin_wayland`/`plasmashell` abren `/dev/dri/renderD128` (GPU real).

## 4. Bloqueo 3 — Plasma no arrancaba (ABI de libPlasma)

- **Síntoma:** `plasma-mobile.service` en bucle, `status=127`:
  `startplasma-wayland: error while loading shared libraries: libPlasma.so.7`.
- **Causa (upstream ALARM):** **partial upgrade de Plasma 6.8** en Arch Linux ARM:
  `libplasma`/`kwin`/`plasma-activities` ya son **6.8.0** (aportan `libPlasma.so.8`) pero
  `plasma-workspace`/`plasma-nano`/`plasma-mobile` siguen en **6.7.5** (necesitan
  `libPlasma.so.7` / `libPlasmaQuick.so.7`). ALARM ya compiló `plasma-workspace 6.8.0`
  (2026-10-16 16:41 UTC) pero **aún no lo publicó** en los mirrors (404).
- **Fix aplicado (aditivo y reversible):** `.so.7` de 6.7.5 desde RPMs aarch64 de Fedora
  Koji (`libplasma-6.7.5-1.fc44` + `plasma-activities-6.7.5`) →
  `/usr/lib/libPlasma.so.6.7.5` (+ symlink `.so.7`) y `libPlasmaQuick.so.6.7.5` (+ `.so.7`),
  conservando el `.so.8` de ALARM para los applets/kwin 6.8.0. `ldconfig` + reboot.
- **Resultado:** `plasmashell` + `kwin_wayland` corren, display `card1-DSI-1` 720x1560.
- **Rollback:** cuando ALARM publique `plasma-workspace 6.8.0`, borrar a mano esos 4 ficheros
  de `/usr/lib` (no los posee pacman) y `pacman -Syu`.

## 5. Bloqueo 4 — Wi-Fi (WCN3990)

- **Causa A (DTB sin nodo wifi):** el kernel de Kupfer usa el fork **sin los parches DTS**
  (wifi/cdsp/mpss) que pmOS sí aplica → no había `wifi@c800000` y `ath10k_snoc` ni probaba.
  **Fix:** nuevo `boot.img` = `Image.gz`+ramdisk de Kupfer **+ DTB `k7.dtb`** (de
  `pmaports-overlay/dts/k7.dts`; compila a 44444 B, idéntico al de pmOS, con
  `qcom,wcn3990-wifi`). Escrito directo a `boot_b` con `dd` (sin fastboot).
- **Causa B (userspace del módem):** el WCN3990 necesita el **módem (MPSS)** arriba y el
  módem necesita `rmtfs` + `pd-mapper` + `tqftpserv`. Kupfer no los traía.
  **Fix:** instalados del repo `device` de Kupfer (`pd-mapper-git`, `tqftpserv-git`,
  `q6voiced`, `hexagonrpcd`) y `rmtfs-git`/`qrtr-git` del repo `aur` de ALARM.
- **Orden crítico:** `rmtfs`/`tqftpserv` → **módem** → `pd-mapper` → `ath10k_snoc`.
  `pd-mapper` solo encuentra los PD maps con el módem ya corriendo (si no: "no pd maps
  available" y sale). El PD mapper es además in-kernel (`qcom_pd_mapper`).
- **Automatización (versionada en `kupfer-overlay/mia3-support/`):**
  `mia3-wifi-up.sh` + `mia3-wifi.service` (oneshot: espera `remoteproc0`, arranca el módem,
  `systemctl restart pd-mapper`, recarga `ath10k_snoc`).
- **Resultado:** tras reinicio, `wlan0` up, NM la ve, conectada a la red local
  (IP por DHCP), internet OK. Avisos inofensivos: `invalid MAC address; choosing random`,
  `chan info: invalid frequency 0`.

## 6. Batería (PMI632) — implementada

- No hay driver mainline del fuel gauge/cargador PMI632 → módulos **out-of-tree**.
- **Módulos compilados** (vermagic `7.2.3-sm61x5 SMP preempt mod_unload aarch64`):
  - `mia3_qg.ko` — fuel gauge read-only → `/sys/class/power_supply/mia3-qg`
  - `pmi632_chg.ko` — cargador con parámetros (`charging_enabled`, `usb_suspend`, `usb_icl_ma`)
  - `mia3_dtbo.ko` — cargador de overlays de DT
  - `mia3-qg.dtbo` — overlay `fuel-gauge@4800` (tabla OCV Sunwoda 4030 mAh)
- **Compilación:** en el host con **clang 23** (`ARCH=arm64 LLVM=1 KBUILD_MODPOST_WARN=1`)
  contra el árbol `sm61x5-mainline` v7.2.3-r0 con el **`/proc/config.gz` del teléfono**.
  Nota: el kernel del teléfono se compiló con **GCC**; los módulos con clang cargan igual
  (`CONFIG_LTO_NONE`, `CONFIG_RANDSTRUCT_NONE`, sin `MODVERSIONS`, sin `MODULE_SIG_FORCE`).
- Gotcha del overlay: `k7.dtb` **no tiene `__symbols__`**, así que el `.dtbo` debe compilarse
  **sin `-@`** (las referencias `&{/ruta}` se resuelven por path). Con `-@` el kernel falla
  con `symbols in overlay, but not in live tree`.
- **Userspace:** `mia3-qg.service` (aplica el overlay + `modprobe mia3_qg`) y
  `chargectl.service` + `chargectl.py` (mantiene la carga en el objetivo, por defecto 50 %,
  `/var/lib/chargectl/chargectl.json`), con salvaguardas térmicas y failsafe de batería baja.
- **Resultado verificado (tras reinicio, persistente):**
  `mia3-qg: cap=86% v=4.14 V i≈-0.5 A`; servicios `mia3-qg` y `chargectl` `active`.
- **Pendiente menor:** `chg_temp` (iio:device1) lee un valor absurdo (~377 °C) y chargectl lo
  descarta, usando `quiet_therm`/`xo_therm` (~30 °C) que sí leen; `rf-pa0-thermal` no tiene
  termistor. `thermal-sensors/` (TSENS CPU/GPU) aún sin instalar (opcional, mejora el
  thermal-guard). Ver `kupfer-overlay/mia3-support/README.md`.

## 7. Tailscale + SSH bidireccional

- `tailscale` instalado y autenticado → laurel `100.120.97.92` (en la tailnet del usuario,
  con `begonia` 100.112.2.11, `cachyos` 100.111.14.21).
- Claves cruzadas instaladas en `authorized_keys`; SSH **bidireccional** funcionando por
  Tailscale y por LAN: `ssh begonia` (desde laurel) y `ssh laurel` (desde begonia/cachyos).
- `sudo` sin contraseña configurado en laurel (`/etc/sudoers.d/zz-user-nopasswd`, que debe
  ordenar **después** de `sudoers.d/wheel` porque gana la última regla).
- **Aviso de `connmark` — RESUELTO.** El kernel no traía `CONFIG_NETFILTER_XT_*_CONNMARK`,
  así que `tailscaled` avisaba (`Extension connmark revision 0 not supported`) y no instalaba
  sus reglas `-j CONNMARK`. Se compiló `xt_connmark.ko` contra el kernel exacto
  (`make … net/netfilter/xt_connmark.ko`, vermagic `7.2.3-sm61x5 SMP preempt mod_unload aarch64`,
  alias `ipt_connmark`/`ipt_CONNMARK`), se instaló en
  `/usr/lib/modules/$(uname -r)/kernel/net/netfilter/` + `depmod`, y se reinició `tailscaled`.
  **Verificado:** `tailscale status --json` → `"Health": []`, 0 avisos, reglas `CONNMARK`
  presentes en el ruleset (`xt target "CONNMARK"`), autoload por alias OK, SSH intacto.
  **Arreglo duradero:** las tres opciones se añadieron a
  `kupfer-overlay/linux/sm61x5/extra_config` (reconstruir kernel); el parche inmediato
  (módulo compilado) está documentado en `docs/KUPFER-BRINGUP.md` §7.
  *(El test de persistencia con reinicio quedó sin confirmar: el teléfono no reapareció en
  la red tras el reboot — ver nota al final del §7 de la guía.)*

## 8. Estado resultante

| Componente | Estado | Evidencia |
|---|---|---|
| Boot + systemd | `working` | 0 unidades fallidas |
| Pantalla (DSI panel) | `working` | 720x1560, backlight |
| GPU Adreno 610 (DRM) | `working` | renderD128 usado por kwin/plasmashell |
| Plasma Mobile | `partially-working` | plasmashell + kwin OK (con drop-in 6.7.5) |
| Táctil FT3518 | `working` | edt_ft5x06 |
| Wi-Fi WCN3990 | `working` | `wlan0` conectada + internet |
| Módem/CDSP | `partially-working` | remoteproc up (sin llamadas/SMS/datos) |
| Batería (fuel gauge) | `working` | cap% / V / I vía `mia3-qg` |
| Carga limitable | `detected` | `chargectl` activo |
| Tailscale | `working` | `100.120.97.92`, SSH bidireccional |
| Thermal CPU/GPU (TSENS) | `not-targeted` | overlay disponible sin instalar |

## 9. Arreglos de build pendientes (resumen para CI)

1. `26-build-kupfer.yml`: parchear el `fstab` de la rootfs (`nofail`) + override de emergencia.
2. `26-build-kupfer.yml` (perfil): incluir el userspace del módem
   (`rmtfs-git`, `qrtr-git`, `pd-mapper-git`, `tqftpserv-git`) y `mia3-support`.
3. `kupfer-overlay/linux/sm61x5/`: usar `k7.dts` como DTB de laurel (wifi) o aplicar los
   parches DTS de `pmaports-overlay/linux-nura-qcom-sm61x5/`.
4. `mia3-support` (nuevo PKGBUILD): compilar los 3 módulos contra `linux-sm61x5-headers`,
   instalar `.dtbo`, unidades y `chargectl`; habilitar `mia3-qg`/`chargectl`/`mia3-wifi`.
5. pmOS: `firmware-xiaomi-laurel-cdsp` → añadir `a610_zap.mbn` a `source=` (GPU).
