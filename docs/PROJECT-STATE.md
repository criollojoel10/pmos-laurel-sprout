# Estado del proyecto — resumen (2026-08-03)

Punto de control para sesiones futuras. Documento canónico de progreso:
`reports/milestones.json`, `reports/hardware-matrix.json`, `docs/HARDWARE-STATUS.md`.

## Base del kernel

- **Decisión: Linux mainline v7.1** (tag `v7.1` = commit `b3f94b2b3f3e51ab880a51fc6510e1dafba654ed`).
  Ref: `docs/DECISIONS/0001-kernel-base.md` (superado), `docs/DECISIONS/0002-kernel-base.md`.
- Fijado en `sources.lock.json` como `linux-mainline-v7.1`.

## Hitos

| ID | Nombre | Estado |
|---|---|---|
| M0 | Fundación (repo, CI, estructura) | completado |
| M1 | Investigación y fuentes congeladas | completado (2026-08-03) |
| M2 | Kernel | en progreso — kernel debug compilado + boot image de diagnóstico en CI |
| M3 | Rootfs | completado (2026-08-09, CI) — rootfs histórico reproducido y verificado |
| M4 | Prueba física | en progreso — EX3 kernel 6.1 slot b: imagen en pantalla + kernel panic (2026-08-09) |
| M5 | Release | pendiente |

## Kernel (M2)

- Workflow `03-build-kernel.yml`: clona torvalds v7.1 en el commit fijado,
  aplica `patches/kernel/*.patch` con `scripts/apply-kernel-patches.sh`,
  compila con `scripts/build-kernel.sh` (defconfig arm64 `defconfig` +
  fragmentos `configs/kernel/laurel-*.fragment`).
- **Build debug exitoso** en CI (run 30786551830): Image + `sm6125-xiaomi-laurel-sprout.dtb`
  (37KB) generados; verify-dtb descompiló y generó informe.
- **Build debug final validado** (run 30792773593): verify-kconfig **sin avisos**;
  todos los símbolos del fragmento base correctos contra v7.1 (BT serdev/H4,
  USB configfs F_FS/F_UVC, REGULATOR_QCOM_RPMH, etc.). Artefactos completos en
  `local-private/kernel-final2/`: Image (68MB), Image.gz (20MB), DTB (37KB),
  modules.tar.zst, System.map, SHA256SUMS (todos verificados OK).
- DTB validado: compatible panel `samsung,s6e8fc0-m1906f9` (typo corregido),
  táctil `focaltech,ft3518`, modelo `Xiaomi Mi A3`/`xiaomi,laurel-sprout`,
  GPU zap `qcom/sm6125/xiaomi/laurel/a610_zap.mbn` (parche K3).
- Correcciones aplicadas en el camino:
  - parches aplicados una sola vez (workflow), no reaplicados por build-kernel.sh;
  - defconfig `defconfig` de mainline (no `qcom_defconfig` del fork);
  - fragmentos resueltos contra la raíz del repo (REPO_ROOT);
  - `CROSS_COMPILE=aarch64-linux-gnu-` en CI;
  - fragmentos validados contra Kconfig v7.1 (ver abajo);
  - verify-kconfig busca Kconfig recursivamente y acepta strings;
  - `upload_artifacts` con `!= 'false'` para que los artefactos se emitan por defecto.

## Parches downstream (patches/kernel/)

| # | Archivo | Contenido |
|---|---|---|
| K1 | 0001-dts-mdss-panel-s6e8fc0.patch | Enable MDSS/DSI + panel s6e8fc0 (compatible corregido) + `&dispcc` |
| K2 | 0002-dtsi-gpu-adreno610.patch | Nodos GPU en sm6125.dtsi (gpu@5900000, gmu_wrapper, gpucc, adreno_smmu) |
| K3 | 0003-dts-enable-gpu.patch | Enable GPU + zap-shader a610_zap.mbn en DTS de placa |

Ref: `docs/PATCH-PLAN.md`, `docs/DTS-AUDIT.md`.

## Fragmentos Kconfig — validados contra v7.1

Cambios clave respecto a la versión inicial (fork sm61x5):
- `UFS_QC_UFSHCD` → `SCSI_UFS_QCOM`.
- `QCOM_BATT_METER`/`QCOM_SPMI_SCHG`: **no existen en v7.1** (fork); PMI632
  sin driver dedicado.
- `PINCTRL_SM6125`: driver presente en Makefile v7.1 pero **Kconfig sin prompt**
  (bug del tag); no habilitable hasta v7.2+.
- `REGULATOR_QCOM_SMPS` → `QCOM_RPM`/`RPMH`/`SMD_RPM`.
- `ARM_QCOM_CPUIDLE` → `DT_IDLE_STATES` (cpuidle-qcom-spm es legacy SPM).
- `MODULE_COMPRESS`, `DRM_MSM_SELFTESTS`: no existen en v7.1.

## Firmware A610 (M1, confirmado en CI)

- Zap-shader obligatorio: `qcom/sm6125/xiaomi/laurel/a610_zap.mbn` (NO se
  distribuye en pmaports; dispositivo-específico).
- `qcom/a630_sqe.fw`: linux-firmware tag 20260110, sha256
  `1c21b527d9183487cc550dabbb3f43e555df5a977a461934fc61f0635a9aa90c`.
- pmaports `firmware-qcom-adreno-a610` = metapaquete vacío + dependencia
  `-a630-sqe`. A610 no tiene GMU.

## Kupfer (Arch Linux ARM)

- `docs/KUPFER.md`: investigación completa. Kupfer usa deviceinfo de pmaports
  por commit fijado; no hay paquete SM6125/laurel aún; el port pmaports de
  laurel fue eliminado (deviceinfo a reconstruir). Camino recomendado:
  `device-sm6125-xiaomi-laurel` + `linux-sm6125` + firmware.
- Estado: investigación documentada; sin implementación.

## Próximos pasos

1. ✅ **FASE B0 (auditoría de boot layout)**: stock V12.0.26.0 y /e/OS 4.1.1
   analizados (header v2, page 4096, offsets verificados; vbmeta /e/OS
   flags=3). Referencias en `local-private/rom-analysis/`, informes en
   `reports/`.
2. ✅ **FASE B1 (contraste histórico)**: guía postmarketOS 2022 recuperada vía
   Wayback; deviceinfo/APKBUILD históricos de pmaports (fork SM61x5). Informe
   `reports/postmarketos-history-analysis.md`.
3. ✅ **FASE C (initramfs de diagnóstico)**: `initramfs/init` (busybox, serial
   ttyMSM0, sin tocar flash) + `scripts/build-diagnostic-initramfs.sh`.
4. ✅ **FASE D (boot image de diagnóstico)**: `scripts/build-boot-image.py`
   (builder autocontenido, header v2 verificado byte-por-byte vs mkbootimg) +
   workflow `04-build-diagnostic-boot.yml`. **Boot image construido y validado
   en CI** (run 30916017707, 21.5 MB < 64 MiB, round-trip kernel/ramdisk/dtb
   OK, busybox arm64 estático). Artefacto `boot-laurel-diagnostic`.
   [2026-08-04] El artefacto previo (run 30835329663) tenía busybox x86-64;
   se reconstruyó con busybox 1.38.0 arm64 compilado en CI
   (`scripts/build-busybox-arm64.sh`).
5. **FASE E (prueba física, REQUIERE autorización)**: el intento no destructivo
   `fastboot boot` (2026-08-04) quedó bloqueado por ESTE bootloader
   (`FAILED remote: 'unknown command'`, `FASTBOOT_BOOT_COMMAND_UNSUPPORTED`).
   No hubo ejecución de kernel/initramfs ni rechazo del contenido del boot.img.
   Estrategia planificada: prueba persistente controlada escribiendo el boot
   image de diagnóstico en `boot_<TARGET_SLOT>` (slot inactivo) **solo** bajo
   FASE 8, con recovery-kit preparado en `local-private/phase-e-flash/recovery-kit/`
   (TEST_IMG, KNOWN_GOOD_BOOT /e/OS 4.1.1, SHA256SUMS, recovery-manifest.json,
   recovery-commands.txt, preflight sanitizado). ORIGINAL_SLOT=a, TARGET_SLOT=b.
6. FASE 5: rootfs consola/Plasma (workflows 04/05), deviceinfo real.
7. Prueba física bajo FASE 8 (solo `fastboot boot`, previa autorización).

## Prueba física EX3 (2026-08-09) — kernel 6.1 slot b

- Preparación slot b ejecutada con autorización: `dtbo_b` borrado,
  `vbmeta_b` flags=2, `system_b` = rootfs pmOS MBR completo
  (`xiaomi-laurel.img`), `boot_b` = boot v0 kernel 6.1 @77de535b + initramfs
  diagnóstico. `current-slot: b` confirmado. Registro:
  `local-private/phase-e-flash/preflight/historical-6.1/ejecucion-slot-b-2026-08-09.md`.
- Resultado: **imagen en pantalla + KERNEL PANIC**. El kernel 6.1 arrancó y
  mostró vídeo (señal positiva de MDSS/panel), pero paniqueó. USB host:
  desconexión 12:44:23 sin re-enumeración (panic antes de initramfs/USB).
- Pendiente: capturar texto del panic (foto de pantalla), diagnóstico del
  panic, y autorización para `set_active a` (recuperación) o seguir
  depurando en slot b.
