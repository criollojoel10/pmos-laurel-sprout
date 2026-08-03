# Kupfer — estado de investigación (2026-08-03)

Kupfer es una distribución móvil derivada de **Arch Linux ARM**: "es a Arch
lo que postmarketOS es a Alpine". Proyecto: https://kupfer.gitlab.io/
Infraestructura: https://gitlab.com/kupfer (kupferbootstrap, packages/pkgbuilds).

## Relación con este proyecto

El usuario pidió investigar/avanzar **en paralelo** la construcción de Kupfer
para `laurel_sprout`. Este informe documenta el estado y los próximos pasos.

## Hallazgos clave

### 1. Kupfer es el equivalente Arch de postmarketOS
- CLI: `kupferbootstrap` (inspirado en pmbootstrap): `config init`,
  `packages init`, `image build`.
- Usa `deviceinfo` (mismo esquema que pmaports) y PKGBUILDs.
- Soporta arranque `aboot` (boot.img de Android) vía `kbs image flash`.

### 2. Paquetes existentes (rama `dev`, arch aarch64)
- **device/** (28): msm8916 (paella, common), msm8953 (mido, rosy, tissot,
  kuntao, common), sdm670 (sargo, common), sdm845 (enchilada, fajita,
  beryllium, oneplus-common, common), + utilidades Qualcomm (rmtfs-git,
  pd-mapper-git, qrtr-git, tqftpserv-git, q6voiced, hexagonrpcd,
  meta-modem-qcom, reboot-mode, bootmac, msm-modem-uim-selection).
- **linux/**: msm8916 (6.0.2), msm8953 (6.19.5), sdm670, sdm845.
- **firmware/**: firmware-msm8953-xiaomi-mido, etc.
- **No existe** ningún paquete SM6125/SM6115 ni laurel.

### 3. Patrón de port (device PKGBUILD, ej. device-msm8953-xiaomi-mido)
- `_mode=cross`, `_nodeps=true`.
- Descarga el `deviceinfo` y `modules-initfs` **directamente de pmaports**
  por commit fijado (`${_commit}`), añade overrides de Kupfer
  (`deviceinfo_partitions_*`, `deviceinfo_lk2nd`,
  `deviceinfo_modules_initfs`) y lo instala en `/etc/kupfer/deviceinfo`.
- Depende de `device-<soc>-common`, `firmware-<soc>-<device>`, `qbootctl`,
  `q6voiced`.

### 4. Patrón de kernel (linux/msm8953)
- `_mode=cross`, fuente del fork msm8953-mainline (commit fijado),
  config de pmaports (`config-postmarketos-qcom-msm8953.aarch64`) + `extra_config`.
- `makedepends`: xmlto, docbook-xsl, kmod, inetutils, bc, dtc, cpio, python.
- `prepare()`: copia el config, `make olddefconfig`, parchea `scripts/depmod.sh`.
- Patrón muy similar a nuestro APKBUILD/laurel-*.fragment.

## Limitación crítica: sin deviceinfo de referencia

- El port pmaports `xiaomi-laurel` **fue eliminado por completo** de
  pmaports `main` (búsqueda 2026-08-03): ni `device/community/device-xiaomi-laurel`,
  ni `device/testing/...`, ni `device/community/xiaomi-laurel`. Tampoco
  `linux-postmarketos-qcom-sm6125` (archivado antes).
- El MR 3105 ("xiaomi-laurel: new device (and sm6125 mainline kernel)") fue
  mergeado (sha 22e6d12c) pero su contenido ya no está en la rama.
- Consecuencia: para portar a Kupfer hay que **reconstruir el deviceinfo**
  (particiones, módulos initfs, flashes, etc.) desde cero, o reutilizar el
  que podamos generar en este proyecto.

## Camino recomendado para Kupfer

1. Crear `device/device-sm6125-xiaomi-laurel`:
   - deviceinfo (reconstruido desde el trabajo de este repo).
   - Dependencias: `device-sm6125-common` (crear), `firmware-sm6125-xiaomi-laurel`
     (crear), `qbootctl`, `q6voiced`.
2. Crear `linux/linux-sm6125`:
   - Base mainline v7.1 + nuestros parches `patches/kernel/*.patch`.
   - Config desde nuestros `configs/kernel/laurel-*.fragment`.
3. Crear `device/device-sm6125-common` y `firmware/firmware-sm6125-xiaomi-laurel`
   (firmware A610: a610_zap.mbn + a630_sqe.fw; ver reports/firmware-a610-audit.json).
4. Enviar PKGBUILDs vía MR al repo `kupfer/packages/pkgbuilds`.

## Notas

- SoC SM6125 (trinket) ≠ msm8953: aunque ambos usan Adreno 610, los
  msm8953 (SDM630/636/660) no son SM6125; el ejemplo sirve solo como patrón
  estructural.
- Kupfer está en `dev` (beta); los ports de referencia son msm8953/sdm845.
- Bloqueante: reconstruir el deviceinfo de laurel (particiones exactas A/B,
  slot-active, vbmeta, módulos initfs). Ver docs/NON-DESTRUCTIVE-BOOT.md.

## Referencias

- Web: https://kupfer.gitlab.io/
- Porting: https://kupfer.gitlab.io/kupferbootstrap/main/usage/porting/
- PKGBUILDs: https://gitlab.com/kupfer/packages/pkgbuilds (rama dev)
- kupferbootstrap: https://gitlab.com/kupfer/kupferbootstrap
