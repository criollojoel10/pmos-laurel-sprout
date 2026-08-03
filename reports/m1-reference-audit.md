# Auditoría de referencia M1 — panel, táctil y firmware

Generado: 2026-08-03
Rama: research/m1-panel-touch-firmware
Fuentes: Codeberg, GitLab postmarketOS, GitHub (torvalds/linux), lore/patchew,
índice pkgs.postmarketos.org.

## Resumen ejecutivo

1. **Panel S6E8FC0/M1906F9**: soporte completo **aceptado upstream** y
   presente en Linux mainline **v7.1** (2026-06-14). Commit del driver:
   `49837b6babe7`. El typo `s6e8fco`→`s6e8fc0` se corrigió en **v5** del
   patchset (2026-03-17), no en junio como indicaba un resumen previo.
2. **FT3518**: soporte **aceptado upstream** y presente en Linux mainline
   **v7.0** (2026-04-12). Commit del driver: `5383e76483dc` (aplicado por
   Dmitry Torokhov). DTS del touch: `8cbbb339048a` (Bjorn Andersson).
3. **Árboles**: sm61x5-mainline master (7a52441d, 2026-05-25) NO tiene
   panel/táctil; la rama `barni2000/6.19-develop` SÍ los tiene (backports
   upstream). SzczurekYT/linux rama `laurel` los tiene (2026-03-10).
4. **sm61x5_defconfig**: no existe en master pero SÍ en
   `barni2000/6.19-develop` (commit 727f79bb9ca0, 2026-03-30).
5. **Firmware A610**: subpackage de `firmware-qcom-adreno` en pmaports
   (metapaquete vacío + dependencia `-a630-sqe` con `a630_sqe.fw`).
6. **Implicación para la base del kernel**: mainline actual (v7.x) ya
   contiene panel, táctil, MDSS y GPU SM6125. Esto reduce drásticamente el
   conjunto de parches externos y debe sopesarse contra sm61x5-mainline.

## Árboles investigados

| Árbol | URL | Ramas | Estado |
|---|---|---|---|
| sm61x5-mainline/linux | codeberg.org/sm61x5-mainline/linux | master, barni2000/6.19-develop, barni2000/7.0-develop | master sin panel/touch; dev con backports |
| barni2000/linux | codeberg.org/barni2000/linux | master, barni2000/7.0-develop, b4/sdm632-rpmpd | WIP patches before submission |
| SzczurekYT/linux | gitlab.postmarketos.org/SzczurekYT/linux | master, laurel, feat/panel, laurel-connectivity | laurel (2026-03-10) contiene panel/touch/GPU |
| torvalds/linux | github.com/torvalds/linux | master (7.x) | panel v7.1, touch v7.0 |

## Commits upstream clave

| Componente | Commit | Versión mainline | Árbol aplicado |
|---|---|---|---|
| dt-bindings panel | f4693b88bc730 | v7.1 | drm-misc-next |
| driver panel | 49837b6babe7 | v7.1 | drm-misc-next |
| DTS Enable MDSS + panel | 493cb869874c | v7.1 | mainline |
| dt-bindings FT3518 | 9b352327add1 | v7.0 | mainline |
| driver FT3518 (edt-ft5x06) | 5383e76483dc | v7.0 | mainline (D. Torokhov) |
| DTS FT3518 | 8cbbb339048a | v7.0 | mainline (B. Andersson) |

## Dependencias del panel (MDSS resets)

Aplicadas upstream (2026-03-03): `arm64: dts: qcom: sm6125/sm6115: Add
missing MDSS core reset`, `clk: qcom: dispcc-sm6125/sm6115: Add missing MDSS
resets`, bindings correspondientes.

## Firmware Adreno A610

- Paquete padre: `device/community/firmware-qcom-adreno/APKBUILD` en
  pmaports main.
- Subpackage `firmware-qcom-adreno-a610`: metapaquete vacío, depende de
  `firmware-qcom-adreno-a630-sqe` (instala `qcom/a630_sqe.fw`).
- pkgver=20260110, arch=aarch64 armv7, license=custom.
- linux-firmware tag 20260110 (commit 06a743fd69999590e88199bb9edba9d5b73d6ad1):
  `qcom/a630_sqe.fw` presente (sha256
  1c21b527d9183487cc550dabbb3f43e555df5a977a461934fc61f0635a9aa90c).
- El A610 no tiene GMU; el driver MSM carga `a630_sqe.fw` como SQE.

## Confirmación CI (workflow 02-m1-reference-audit, run 30785377934)

Ejecutado el 2026-08-03 sobre árboles reales (mainline master v7.2-rc6
`075b7484`, sm61x5 master `7a52441d`, sm61x5 dev `barni2000/6.19-develop`
`ae0eeba9`):

| Árbol | Driver panel | Compatible DTS | FT3518 | gpu@5900000 |
|---|---|---|---|---|
| mainline master (v7.2-rc6) | sí | `s6e8fco-m1906f9` (typo) | sí (3) | no |
| sm61x5 master | no | — | no | no |
| sm61x5 dev (6.19-develop) | sí | `s6e8fc0-m1906f9` | sí (3) | sí |

- La matriz CI (`device-reference-matrix.json`) registra la decisión de base
  como **`mainline-v7.1`** (consistente con DECISION-0002).
- `firmware-a610-audit.json` confirma: `a610_zap.mbn` obligatorio
  (`qcom/sm6125/xiaomi/laurel/a610_zap.mbn`), `a630_sqe.fw` (sha256
  `1c21b527…aa90c`, linux-firmware tag 20260110), H5 confirmado (A610 sin GMU).
- `pmaports-subpackage-audit.json` confirma que el subpackage A610 es un
  metapaquete vacío que depende de `-a630-sqe`; el zap-shader no se distribuye
  (es específico del dispositivo).

## Pendientes

- Verificar el contenido exacto de `sm61x5_defconfig` en barni2000/6.19-develop.
- Decidir la base del kernel (mainline v7.x vs sm61x5-mainline vs LTS).
- Confirmar GPU (a610) config en la base elegida.
- Verificar WCN3990/WLAN/BT (H6).
