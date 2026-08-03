# Auditoría del Device Tree (DTS)

Estado: actualizado con investigación M1 (2026-08-03).

## Hechos verificados (2026-08-03)

- El DTS mainline correcto es
  `arch/arm64/boot/dts/qcom/sm6125-xiaomi-laurel-sprout.dts`
  → DTB `qcom/sm6125-xiaomi-laurel-sprout.dtb` (con guiones, no guion bajo).
- Compatible del panel: `samsung,s6e8fc0-m1906f9` (con CERO).
- El DTS mainline master incluye: `mdss`, `mdss_dsi0`, `panel@0`,
  `mdss_dsi0_out`, `mdss_dsi0_phy`, pinctrl `mdss_default/mdss_sleep`
  (gpio90), reguladores `panel_vdd_1p8` (gpio26) y `panel_vci_3p0`
  (gpio124).

## Hallazgo crítico: typo `s6e8fco` en mainline master

- El DTS en mainline master (v7.2-rc6) usa compatible
  `samsung,s6e8fco-m1906f9` (letra O, bytes `6f`), que **NO coincide** con el
  driver (`samsung,s6e8fc0-m1906f9`, cero, bytes `30`). El panel no se
  bindearía.
- Causa: el commit DTS `493cb869874c` (Enable MDSS + panel) se aplicó desde
  la **v4** del patchset (20260314), que aún tenía el typo; la corrección fue
  en **v5** (2026-03-17). El commit NO está en v7.1 (compare: ahead 1).
- sm61x5 dev usa el compatible correcto `s6e8fc0`. → Nuestro parche
  downstream debe portar ese valor.

## Ramas sm61x5-mainline (verificado 2026-08-03)

- `master` (7a52441d): basada en 6.19, DTS 413 líneas, **sin** panel, GPU
  ni FT3518 (estancada desde 2026-05-25).
- `barni2000/6.19-develop` (ae0eeba9): DTS 664 líneas, todo presente,
  correcto (`s6e8fc0`), pero base 6.19 y con commits `fixup!`/`HACK`
  (no apta como base reproducible).
- `barni2000/7.0-develop` (c41e0655, base **7.0.8 estable**): es el análogo
  exacto del patrón pmaports `linux-postmarketos-qcom-sm6350` (fork
  mainline a 7.0.8). Contiene panel driver, DTS con `s6e8fc0`, GPU
  (`gpu@5900000`), FT3518 y `sm61x5_defconfig`. Tiene commits `fixup!`/`HACK`
  y `temp`; sirve como **fuente autoritativa de parches** (no como base de
  build por sus commits sueltos), a diferencia de 6.19-develop usa
  convenciones modernas (2-cell, `SM6125_VDDCX`) compatibles con mainline
  reciente.
- Consecuencia: el port sobre mainline v7.1 debe tomar el nodo GPU y el
  DTS del árbol **7.0-develop** (no del 6.19-develop), adaptando:
  `SM6125_VDDCX` → `RPMPD_VDDCX` (v7.1 usa el header genérico
  `qcom-rpmpd.h`; el per-SoC `qcom-sm6125-rpmpd.h` NO existe en v7.1),
  `qcom,adreno-gmu-wrapper` (no existe en mainline) → verificar driver
  GMU, y el zap-shader. El gpucc header correcto en v7.1 es
  `qcom,sm6125-gpucc.h` (`qcom,gpucc-sm6125.h` NO existe).

## Estado por árbol (2026-08-03)

| Árbol | DTS laurel | Panel driver | Panel DTS | FT3518 driver | FT3518 DTS | GPU node |
|---|---|---|---|---|---|---|
| mainline v7.1 (base) | presente | **sí** (`49837b6babe7`) | **NO** | **sí** (`5383e76483dc`) | sí | **NO** |
| mainline master v7.2-rc6 | presente | sí | sí (con typo `s6e8fco`) | sí | sí | NO |
| sm61x5 master 7a52441d | presente (413 ln) | no | no | edt-ft5x06 sin FT3518 | no | no |
| sm61x5 dev 6.19-develop | presente (664 ln) | sí | sí (`s6e8fc0`) | sí | sí | **sí** (`gpu@5900000`) |
| sm61x5 dev 7.0-develop (c41e0655) | presente (660 ln) | sí | sí (`s6e8fc0`) | sí | sí | **sí** (`gpu@5900000`) |

## Parches DTS downstream necesarios (base mainline v7.1)

1. **Enable MDSS + panel** (port de `493cb869874c`) con compatible corregido
   `s6e8fc0` (NO el typo `s6e8fco` del mainline master). Incluye
   `mdss_dsi0_phy` power-domain VDD_MX y reguladores panel.
2. **GPU (adreno-610)**: nodo `gpu@5900000` en `sm6125.dtsi` + `&gpu`,
   `&adreno_smmu`, `&gpucc` y zap-shader `qcom/sm6125/xiaomi/laurel/a610_zap.mbn`
   en el DTS laurel. Fuente: sm61x5 dev `92aacc57f7`. Downstream-only.
3. Auditoría en CI de otros cambios sm61x5 dev no presentes en v7.1
   (p. ej. RTC, reserved-memory, extcon removal) → workflow 02.

## Reglas

- No reintroducir el typo `s6e8fco`.
- Todo overlay/parche DTS se audita con `scripts/audit-patches.sh`.
- El DTB se embeberá en `boot.img` (QCDT) para boot no destructivo.
