# Auditoría estructurada del DTB — sm6125-xiaomi-laurel-sprout

Generado: 2026-08-03 (dtc 1.7.2 sobre `local-private/kernel-final2/sm6125-xiaomi-laurel-sprout.dtb`,
build run 30792773593, kernel mainline v7.1 commit `b3f94b2b3f3e51ab880a51fc6510e1dafba654ed`).

## Nodos de cabecera

| Nodo / propiedad | Valor |
|---|---|
| `/model` | `Xiaomi Mi A3` |
| `/compatible` | `xiaomi,laurel-sprout`, `qcom,sm6125` |
| `/chassis-type` | `handset` |
| `/chosen` | `framebuffer@5c000000` (simple-framebuffer a8r8g8b8 720x1560) — **no hay `/chosen/stdout-path`** |
| `/memory@40000000` | `reg = <0x0 0x40000000 0x0 0x0>` (tamaño a determinar en runtime) |
| `/aliases` | **ausente** |
| CPU | 8× `qcom,kryo260` (4× A75 clúster0 + 4× A55 clúster1), enable-method `psci` |

## Memoria reservada (`/reserved-memory`) — 23 regiones

- Todas `no-map`, sin solapes (rango ascendente).
- `smem@46000000` (0x200000) con phandle 0x10 (usado por `/smem`).
- `ramoops@ffc00000`: `reg = <0x0 0xffc40000 0x0 0xc0000>`, `record-size=0x1000`,
  `console-size=0x40000`, `pmsg-size=0x20000`, `compatible="ramoops"`, status okay.
- `debug@ffb00000` (0xc0000) y `lastlog@ffbc0000` (0x80000): regiones de diagnóstico previas.
- A610 zap-shader usa `memory@57115000` (phandle 0x57, 0x2000) como `memory-region`.

## Nodos de dispositivos (soc@0) — status efectivo

| Nodo | Compatible | Status |
|---|---|---|
| `gcc@1400000` | `qcom,gcc-sm6125` | okay |
| `pinctrl@500000` | `qcom,sm6125-tlmm` | okay |
| `qcom,spmi-pmic-arb@1c40000` | `qcom,spmi-pmic-arb` | okay |
| `qcom,ufshc@4804000` | `qcom,sm6125-ufshc`, `jedec,ufs-2.0` | okay |
| `phy@4807000` (UFS) | `qcom,sm6125-qmp-ufs-phy` | okay |
| `dwc3@4ef8800` | `qcom,sm6125-dwc3`, `qcom,dwc3` | okay |
| `dwc3@4e00000` | `snps,dwc3` (`dr_mode="peripheral"`, HS only) | okay |
| `phy@1613000` (USB2) | `qcom,msm8996-qusb2-phy` | okay |
| `mdss@5e00000` | `qcom,sm6125-mdss` | okay |
| `dpu@5e01000` | `qcom,sm6125-dpu` | okay |
| `dsi@5e94000` | `qcom,sm6125-dsi-ctrl`, `qcom,mdss-dsi-ctrl` | okay |
| `phy@5e94400` (DSI) | `qcom,sm6125-dsi-phy-14nm` | okay |
| panel `panel@0` | `samsung,s6e8fc0-m1906f9` | okay (4 data-lanes) |
| `touchscreen@38` | `focaltech,ft3518` | okay (sin status explícito) |
| `gpu@5900000` | `qcom,adreno-610.0`, `qcom,adreno` | okay |
| `gmu@596a000` | `qcom,adreno-gmu-wrapper` | okay |
| `gpucc@5990000` | `qcom,sm6125-gpucc` | okay |
| `smmu@59a0000` (GPU) | `qcom,sm6125-smmu-500`, `qcom,adreno-smmu` | okay |
| `smmu@c600000` (apps) | `qcom,sm6125-smmu-500` | **disabled** |
| `sdhci@4784000` | `qcom,sm6125-sdhci` | okay |
| `sdhci@4744000` | `qcom,sm6125-sdhci` | disabled |
| `gpi-dma@4a00000`/`@4c00000` | `qcom,sm6125-gpi-dma` | disabled (habilitadas por uso) |

## Verificaciones específicas (puntos de la FASE A)

1. **Panel** `samsung,s6e8fc0-m1906f9` presente con `reset-gpios`, `vdd-supply`,
   `vci-supply`, pinctrl default/sleep y puerto DSI 4-lane. El driver
   `DRM_PANEL_SAMSUNG_S6E8FC0` existe en v7.1 y está `=m` en el config actual.
2. **Touchscreen** `focaltech,ft3518` en `i2c@4a88000` (GENI), `reg=<0x38>`,
   `reset-gpios`, `touchscreen-size-x=0x2d0 (720)`, `touchscreen-size-y=0x618 (1560)`.
   El driver mainline es `TOUCHSCREEN_EDT_FT5X06` (`=y`). Coincide.
3. **GPU A610**: `qcom,adreno-610.0` — chip ID correcto (0x610). OPP 320–950 MHz
   con `required-opps` de RPMh. Zap-shader `firmware-name =
   "qcom/sm6125/xiaomi/laurel/a610_zap.mbn"`.
4. **Firmware**: solo se solicita `a610_zap.mbn` en el DTB (no `a630_sqe.fw` en
   DTB; SQE se carga por el driver de la GMU wrapper). `a630_sqe.fw` debe estar
   presente en el initramfs/rootfs para GPU funcional (M1).
5. **reserved-memory**: sin solapes; ramoops región válida 0xffc40000–0xffd00000
   (0xc0000). Ojo: el nodo se llama `ramoops@ffc00000` pero el reg empieza en
   `0xffc40000` (unidad de dirección no coincide exactamente — inofensivo).
6. **pinctrl**: `qcom,sm6125-tlmm` está seleccionado (`CONFIG_PINCTRL_SM6125=y`,
   `pinctrl-sm6125.o` compilado). El Kconfig del tag v7.1 NO expone prompt pero el
   driver se compila y vincula por compatible del DTB.
7. **stdout-path** ausente en `/chosen`; consola por cmdline (`console=ttyMSM0,115200n8`).

## Drivers críticos para el primer initramfs (built-in vs módulo)

| Driver | Símbolo | Estado actual | ¿Afecta initramfs? | Acción |
|---|---|---|---|---|
| UFS controller | `SCSI_UFS_QCOM` | =y | Sí (UFS/rootfs) | built-in OK |
| UFS PHY (QMP) | `PHY_QCOM_QMP_UFS` | =m | **Sí** | **→ =y (fragmento corregido)** |
| USB DWC3 + QCOM | `USB_DWC3`/`USB_DWC3_QCOM` | =y | Sí (gadget) | built-in OK |
| USB2 PHY (QUSB2) | `PHY_QCOM_QUSB2` | =m | **Sí** | **→ =y (fragmento corregido)** |
| USB gadget/configfs | `USB_CONFIGFS`/`F_FS`/`F_UVC` | =y | Sí | built-in OK |
| Input/EVDEV | `INPUT_EVDEV` | =y | Sí | built-in OK |
| I2C GENI | `I2C_QCOM_GENI` | =y | Sí (touch) | built-in OK |
| Serial consola | `SERIAL_MSM`/`SERIAL_QCOM_GENI` | =y | Sí | built-in OK |
| pstore/ramoops | `PSTORE_RAM` | =m | **Sí (evidencia)** | **→ =y (fragmento corregido)** |
| Reguladores RPMh/SPMI | `REGULATOR_QCOM_RPMH`/`SPMI` | =y | Sí | built-in OK |
| Interconnect | `INTERCONNECT_QCOM` | =y | Sí | built-in OK |
| DRM/MSM + panel | `DRM_MSM`/`DRM_PANEL_SAMSUNG_S6E8FC0` | =m | No (fase G) | dejar módulo |
| Touch | `TOUCHSCREEN_EDT_FT5X06` | =y | Sí | built-in OK |
| Initramfs | `BLK_DEV_INITRD` + `RD_GZIP/XZ/ZSTD` | =y | Sí | built-in OK |

## Hallazgos / riesgos

- `/chosen/stdout-path` ausente: la salida temprana depende de `console=` en cmdline.
- El framebuffer `simple-framebuffer` en `/chosen` coexiste con DRM/MSM: si el
  bootloader deja el display inicializado, simpledrm puede mostrarlo; con DRM/MSM
  presente el panel real tomará el control (fase G).
- `DRM_MSM=m`: para la primera prueba (H0/H1) no es necesario display; se mantiene
  módulo y se decide en FASE G si pasar a `=y`.
- El tamaño de `Image` (68MB) supera los 64 MiB; se debe usar `Image.gz` (20MB) en
  el boot image (margen holgado).
