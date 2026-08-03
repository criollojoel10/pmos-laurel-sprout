# PMOS-LAUREL-SPROUT

Port moderno de [postmarketOS](https://postmarketos.org/) Edge (Plasma Mobile,
systemd) para el Xiaomi Mi A3 `laurel_sprout`
(Qualcomm SM6125 / trinket / Snapdragon 665 / Adreno 610).

> **ESTADO: EXPERIMENTAL.** Este proyecto no está afiliado con Xiaomi, KDE ni
> postmarketOS. Instalar software experimental en un teléfono puede
> brickearlo, borrar datos o dejar el dispositivo sin arrancar. Toda prueba
> física es responsabilidad del usuario. Ninguna imagen aquí publicada ha sido
> validada sobre hardware real.

## Hardware objetivo

| Componente | Detalle |
|---|---|
| Fabricante | Xiaomi |
| Modelo | Mi A3 |
| Codename Android | `laurel_sprout` |
| Nombre histórico postmarketOS | `xiaomi-laurel` |
| SoC | Qualcomm SM6125 (trinket) |
| CPU | Snapdragon 665 (AArch64) |
| GPU | Adreno 610 |
| RAM | 4 GB |
| Almacenamiento | 128 GB UFS |
| Pantalla | AMOLED 720x1560, Samsung S6E8FC0 (M1906F9) |
| Táctil | FocalTech FT3518 |
| Particiones | Android A/B |
| Uso | Teléfono experimental (no principal) |

## Objetivos

- Kernel **Linux mainline v7.1** (tag `v7.1` = commit
  `b3f94b2b3f3e51ab880a51fc6510e1dafba654ed`), fijado por commit en
  `sources.lock.json`. Referencias históricas a `sm61x5-mainline`/6.19.x solo
  como investigación; la base de build actual es mainline v7.1 (ver
  `docs/DECISIONS/0002-kernel-base.md`).
- DTB `qcom/sm6125-xiaomi-laurel-sprout.dtb`.
- systemd + KDE Plasma Mobile (KWin Wayland, Qt 6).
- DRM/KMS, DPU/MDSS/DSI, panel S6E8FC0, brillo, táctil FT3518.
- GPU Adreno 610 vía DRM/MSM + Mesa Freedreno.
- UFS, USB gadget/networking, SSH, NetworkManager, BlueZ, PipeWire.
- Batería, térmicas, CPUfreq, CPUidle, suspensión cuando sea viable.

Cámara, módem, llamadas, SMS y datos móviles son prioridad **secundaria**.

## Estado de componentes

Mantenido con estados honestos en:

- `reports/hardware-matrix.json`
- `docs/HARDWARE-STATUS.md`

Nada se declara `working` por compilar: cada estado exige verificación física
(ver `docs/HARDWARE-STATUS.md`).

## Uso de este repositorio

Todo el trabajo pesado (kernel, pmbootstrap, rootfs, boot.img) se ejecuta
**exclusivamente en GitHub Actions**. Localmente solo se edita el repositorio
y se hacen consultas Fastboot de solo lectura.

Ver:

- `docs/ARCHITECTURE.md` — arquitectura del port.
- `docs/SOURCES.md` — fuentes y reproducibilidad.
- `docs/BUILD.md` — cómo ejecutar los workflows.
- `docs/INSTALL.md` — instalación (no automatizada).
- `docs/RECOVERY.md` — recuperación.
- `docs/TESTING.md` — pruebas físicas.
- `AGENTS.md` — reglas obligatorias del proyecto.

## Workflows

| Workflow | Propósito | Disparo |
|---|---|---|
| `00-quality` | Validación estática | push / pull_request |
| `01-research-upstream` | Auditoría de fuentes upstream | manual |
| `02-freeze-sources` | Propuesta de `sources.lock.json` | manual |
| `03-build-kernel` | Kernel debug/release | manual |
| `04-build-pmos-console` | Rootfs postmarketOS consola | manual |
| `05-build-pmos-plasma` | Rootfs Plasma Mobile | manual |
| `06-validate-images` | Validación de artefactos | manual |
| `07-package-prerelease` | Prerelease GitHub | manual |
| `08-process-device-logs` | Análisis de logs del dispositivo | manual |

## Descarga de artefactos

Artefactos disponibles en los runs de GitHub Actions o en las releases:

- `boot-laurel-debug.img` / `boot-laurel-release.img`
- `rootfs-laurel-console.img.xz`
- `rootfs-laurel-plasma.img.xz`
- `modules-laurel.tar.zst`, `dtb-laurel.tar.zst`
- `manifest.json`, `SHA256SUMS`

Verifica siempre los hashes antes de usar cualquier imagen.

## Advertencia de riesgo

- No ejecutar Fastboot destructivo sin respaldos previos.
- No borrar `dtbo` ni escribir `vbmeta` sin entender las implicaciones.
- No usar en un teléfono que necesites a diario.
- Tener siempre un plan de recuperación (firmware stock + respaldos).

## Licencias

- Integración propia, scripts y workflows: **GPL-3.0-or-later**.
- Kernel, pmaports, parches, firmware, Device Trees y documentación upstream
  conservan sus propias licencias y autoría.
- No se redistribuye firmware con licencia incierta ni calibración específica
  de unidad.

## Contribución

Ver `CONTRIBUTING.md` y `AGENTS.md`. Antes de publicar cualquier contenido,
pasa la auditoría `scripts/audit-public-repository.sh`.

## Enlaces upstream

- <https://gitlab.com/postmarketOS/pmbootstrap>
- <https://gitlab.com/postmarketOS/pmaports>
- <https://codeberg.org/sm61x5-mainline/linux>
- <https://kernel.org>
- <https://lore.kernel.org/linux-arm-msm/>
- <https://gitlab.freedesktop.org/msm/linux-msm>
- <https://gitlab.freedesktop.org/mesa/mesa>
- <https://kernel.googlesource.com/pub/scm/linux/kernel/git/firmware/linux-firmware>
- <https://github.com/LineageOS/android_kernel_xiaomi_sm6125>
- <https://postmarketos.org>
- <https://plasma-mobile.org>
