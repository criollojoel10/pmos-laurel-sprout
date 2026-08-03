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
| M2 | Kernel | en progreso — kernel debug compilado en CI |
| M3 | Rootfs | pendiente (bloquea M2) |
| M4 | Prueba física | pendiente (FASE 8 + respaldos) |
| M5 | Release | pendiente |

## Kernel (M2)

- Workflow `03-build-kernel.yml`: clona torvalds v7.1 en el commit fijado,
  aplica `patches/kernel/*.patch` con `scripts/apply-kernel-patches.sh`,
  compila con `scripts/build-kernel.sh` (defconfig arm64 `defconfig` +
  fragmentos `configs/kernel/laurel-*.fragment`).
- **Build debug exitoso** en CI (run 30786551830): Image + `sm6125-xiaomi-laurel-sprout.dtb`
  (37KB) generados; verify-dtb descompiló y generó informe.
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

1. Recolectar artefactos del build debug (run 30789357941) y validar
   SHA256SUMS + DTB.
2. Construir boot image (`boot.img`) no destructiva en CI.
3. FASE 5: rootfs consola/Plasma (workflows 04/05), deviceinfo real.
4. Prueba física bajo FASE 8 (solo `fastboot boot`, previa autorización).
