# Revisión independiente DeepSeek — Wi-Fi Linux 6.1 (WCN3990)

Fecha: 2026-08-12. Revisión de SOLO LECTURA del trabajo Wi-Fi 6.1 producido por
Luna (commit `d72d38b`, parche `0001-dts-laurel-wcn3990-first-probe.patch`,
workflow `17-build-linux61-wifi-debug.yml`). No se ejecutó Fastboot; no se
modificó el teléfono; Linux 7.1 sigue congelado; no se tocaron GPU/DRM/OTG/
audio/pantalla.

## Estado del trabajo revisado

- Run 17 inicial (`31627348618`): **FAILURE** por parche corrupto
  (`error: corrupt patch at ...:65`, `git apply` exit 128).
- Run 17 corregido (`31629258734`): **SUCCESS**. Artefacto
  `boot-linux61-wifi-debug-v1.img` descargado y verificado.
- Corrección aplicada durante esta revisión: `a9d44eb`
  `fix(wifi): regenerar parche DT con contexto git apply valido`.

## 1. Transporte del WCN3990 — veredicto

**TRANSPORTE PROBABLE SNOC, FALTA EVIDENCIA FÍSICA.** Correctamente NO se
confundió SNOC con SDIO:

- `CONFIG_ATH10K_SDIO` no está configurado en el 6.1; ambos nodos
  `mmc@4744000`/`mmc@4784000` están `disabled`; `/sys/class/mmc_host` vacío.
- `ath10k_snoc.ko` existe y anuncia "Driver support for Atheros WCN3990 SNOC
  devices" con alias `qcom,wcn3990-wifi`.
- El DT Android de referencia (`trinket.dtsi` @ `713c1f8d`) usa
  `qcom,icnss@C800000`, `reg 0xC800000 0x800000`, IRQs 358-369, SID IOMMU 0x80.
- Conclusión del informe Luna (`reports/linux61-wcn3990-transport-decision.md`)
  = **TRANSPORTE PROBABLE, FALTA EVIDENCIA FÍSICA DE PROBE**: correcto y honesto.

## 2. Nodo DT y compatible

- Compatible del nodo: `qcom,wcn3990-wifi` (línea 39 del parche). Es el
  compatible exacto que `ath10k_snoc_dt_match[]` espera (snoc.c).
- Dirección `0x0c800000`, tamaño `0x800000` (línea 40): coincide con vendor.
- El nodo se inserta en `/soc` — en el fork 6.1 el nodo es `soc` (sin `@0`),
  confirmado en `final.dts` extraído del DTB instalado. Correcto.
- `memory-region = <&wlan_msa_mem>` (línea 42): `wlan_msa_mem` existe en
  `sm6125.dtsi` @ `77de535b` (`memory@53300000`). Correcto.

## 3. IRQ, clocks, regulators, resets, interconnects, memory-region

- IRQs SPI 358-369 (12 CE): idénticas al vendor. Correcto.
- Clocks: el parche NO declara clocks; el driver 6.1 usa
  `devm_clk_bulk_get_optional` para `cxo_ref_clk_pin`/`qdss`, por lo que su
  ausencia no aborta el probe. Aceptable.
- Regulators: declara **4** (`vdd-0.8-cx-mx`=L8A, `vdd-1.8-xo`=L16A,
  `vdd-1.3-rfa`=L17A, `vdd-3.3-ch0`=L23A). El driver pide **5** (incluye
  `vdd-3.3-ch1`). Ver hallazgo H-M1.
- Resets/interconnects/power-domains: no declarados. El driver 6.1 no los
  exige obligatoriamente en este camino.
- memory-region: `wlan_msa_mem` confirmado. `qcom,msa-fixed-perm` presente.

## 4. remoteproc/QMI/QRTR

- El parche NO activa remoteproc, WCSS, WCNSS_PIL ni ICNSS. El driver
  `ath10k_snoc` con subnodo `wifi-firmware` ausente entra en la ruta
  **TrustZone** (`use_tz = true`, snoc.c línea 1598). La decisión de no portar
  la SMMU en el primer probe es correcta y minimiza regresión de UFS/USB.
- QRTR/QMI/SMEM/GLINK ya están disponibles como módulos en el 6.1.
- Nota: `CONFIG_QCOM_WCNSS_PIL=m` y `QCOM_Q6V5_*` existen pero no se activan;
  el transporte SNOC de WCN3990 no necesita WCSS-PIL en el camino TZ. Correcto.

## 5. Firmware, board/calibration, MAC

- Matriz (`reports/linux61-wcn3990-firmware-matrix.md`) correcta: faltan
  `firmware-5.bin` y `board-2.bin` en el rootfs; no fueron instalados
  (workflow marca `firmware_in_rootfs: false`). Correcto para un primer probe
  que solo busca observación del driver.
- MAC/cal: `cal-snoc-<device>.bin` y `pre-cal-snoc-<device>.bin` son privados;
  el inventario correctamente NO los publica.
- Riesgo correctamente documentado: si el board-id de laurel no está en
  `board-2.bin`, no habrá interfaz.

## 6. Kconfig y vermagic

- `ATH10K=m`, `ATH10K_SNOC=m`, `QRTR*`, `QCOM_QMI_HELPERS=y`, `SMEM=y` ya
  presentes en el kernel 6.1 del baseline. El workflow reutiliza kernel y
  módulos del run `31355730519` (vermagic `6.1.0-sm6125`); no recompila kernel
  ni módulos. La variante es coherente (mismos kernel/ramdisk; solo cambia DTB).

## 7. Artefacto final — extracción y verificación (independiente)

`local-private/wifi-v1-31629258734/` (run `31629258734`):

- `boot-linux61-wifi-debug-v1.img`, 12,402,688 B (< 64 MiB), SHA-256
  `ba26d5c68b14afb82e326edbf727b407e70d53fa87c3d4e79dee7e0ae88fa74e`.
- Cmdline: `clk_ignore_unused consoleblank=0` (conservada).
- Ramdisk: SHA-256 `089e344a...` idéntico al baseline (`ebc828...` rootfs).
- Kernel `Image.gz` (sin DTB): SHA-256 `a8cb9a39...`; DTB nuevo
  `sm6125-xiaomi-laurel_sprout-wifi.dtb` SHA-256 `bcfa495d...`.
- `final-wifi.dts`: contiene `qcom,wcn3990-wifi`, `c800000`, `GIC_SPI 358`,
  `vdd-3.3-ch0`, `53300000` (6 coincidencias validadas).
- `SHA256SUMS` verificado OK.

## 8. Ausencia de regresiones en USB/UFS/SSH

- El parche solo añade un nodo; no modifica USB, UFS, DWC3, QUSB2 ni display.
- El workflow usa el mismo kernel/ramdisk; el DTB nuevo conserva el resto del
  árbol (USB/ufshc/simplefb) intacto.
- Riesgo de regresión mínimo y acotado. (La prueba física real aún no se ha
  hecho; el estado es `boot-untested`.)

## 9. Secretos y firmware

- No se commiteó firmware ni blobs (verificado con `git ls-files` y audit).
- Los blobs de prueba (`firmware-5.bin` 60 B, `board-2.bin` 893,528 B) están
  en `local-private/`, fuera del repo. Correcto.
- La auditoría pública pasa. No hay MAC, seriales, claves ni fingerprints
  publicados.

## 10. wlan0/scan/asociación — NO demostrado físicamente

- No existe evidencia física de `wlan0`, `phy`, scan, asociación, DHCP, DNS ni
  SSH por Wi-Fi. El artefacto está `physical_status: boot-untested` y el
  manifest lo declara explícitamente. **No se marca working.** Correcto.

## Hallazgos

### CRÍTICO

- **H-C1 — run 17 inicial falló por parche corrupto.** El parche original
  (`d72d38b`) tenía hunks sin contexto (`@@ -9,0 +10,2 @@` y
  `@@ -251,0 +253,32 @@`), que `git apply` rechaza como "corrupt patch".
  Impacto: ninguna variante Wi-Fi válida quedó lista en el primer intento.
  **Corrección aplicada** (`a9d44eb`): parche regenerado con `git diff` canónico
  (con contexto) y verificado con `git apply --check` + aplicación completa en
  repo de prueba; resultado byte-idéntico al diseño. Requiere rebuild: ya se
  relanzó y completó con éxito.

### ALTO

- **H-A1 — la expectativa del 5º regulator es incorrecta y debe corregirse en
  la documentación.** El parche y su mensaje afirman que omitir `vdd-3.3-ch1`
  producirá "un fallo de regulator esperado". Verificación del código 6.1:
  - `regulator_bulk_get()` (core.c 6.1) falla solo si `regulator_get()` falla.
  - `_regulator_get()` con DT poblada: `have_full_constraints()` = true
    (`of_have_populated_dt()`), y `dummy_regulator_rdev` **siempre existe**
    porque `dummy.o` se compila con `CONFIG_REGULATOR=y` y
    `regulator_dummy_init()` se llama incondicionalmente en `regulator_init`.
  - Por tanto, un supply ausente en DT con DT poblada → **dummy regulator** con
    warning, NO fallo de probe ni crash.
  - Impacto: el primer probe probablemente NO fallará por el 5º supply; el
    driver continuará. La afirmación "regulator failure is expected evidence"
    en el parche y el informe es incorrecta y debe corregirse para no
    interpretar mal el resultado físico.
  - Corrección mínima: texto del parche + informe (pendiente; no bloquea).
  - No requiere rebuild del artefacto (el comportamiento real es más tolerante
    de lo esperado).

### MEDIO

- **H-M1 — documentar la ruta TrustZone como decisión, no como suposición.**
  El parche no añade SMMU ni `iommus`. En el camino `use_tz=true` del driver
  6.1 esto es correcto y evita regresión, pero `use_tz` significa que el
  firmware se carga vía TrustZone/QMI; el resultado físico debe confirmar que
  esa ruta existe en este bootloader. Si no, la siguiente variante requerirá el
  subnodo `wifi-firmware` con SMMU (port `apps_smmu` + SID 0x80). Recomendado
  dejarlo explícito en el informe de transporte. Sin corrección de código.

- **H-M2 — sin firmware en el rootfs, el primer probe no superará la carga.**
  Es intencional (`firmware_in_rootfs: false`), pero el gate físico 2/3 de la
  misión solo se alcanzará con firmware instalado. El workflow no instala
  firmware; el preflight físico debe indicar que el probe observará solo la
  inicialización del driver y la solicitud de firmware, no asociación. Esto ya
  está implícito en el manifest; recomendado explicitar en preflight.

- **H-M3 — `board-2.bin` puede no tener el board-id de laurel.** Correctamente
  documentado como riesgo principal por Luna. No corregible sin dmesg físico.

### BAJO

- **H-L1 — mensaje del parche impreciso respecto al tamaño de
  `firmware-5.bin` (60 B).** El blob de 60 B de linux-firmware @ `e3c0c4b7`
  empieza con `QCA-ATH10K` y parece un descriptor/cabecera, no el firmware
  ejecutable completo; debe validarse contra la distribución oficial antes de
  usarlo como artefacto final. Ya señalado por Luna en la matriz.

- **H-L2 — redundancia de directorios locales** (`linux61-baseline/` y
  `linux61-baseline-31563265029/`) y ahora `wifi-v1-31629258734/`: no afecta
  al repositorio (local-private), solo a la ergonomía.

## Correcciones aplicadas

1. `a9d44eb` — regenerado el parche DT con contexto válido para `git apply`;
   verificado con `git apply --check` y aplicación completa en repo de prueba
   (resultado byte-idéntico). Rebuild CI relanzado y **success** (`31629258734`).

Correcciones de texto pendientes (no bloquean): H-A1 (5º regulator/dummy),
H-M1 (TrustZone como decisión), H-M3 (firmware ausente en primer probe).

## ¿Baseline Wi-Fi listo para prueba física?

Sí, con las siguientes salvedades:

- El artefacto `boot-linux61-wifi-debug-v1.img` es un **primer probe** que solo
  añade el nodo DT `qcom,wcn3990-wifi` sobre el kernel/ramdisk del baseline.
- No instalará wlan0 ni conectará a ninguna red sin firmware; el resultado
  esperado es observar el probe de `ath10k_snoc` (o su ausencia) en dmesg.
- La pantalla no bloquea: SSH USB sigue operativo.

## Confirmaciones

- No se ejecutó Fastboot durante esta revisión.
- No se modificaron particiones ni el teléfono.
- No se trabajó en GPU/DRM/OTG/audio/pantalla.
- Linux 7.1 continúa congelado.
- Wi-Fi NO se marca working: no hay evidencia física de wlan0/scan/asociación/
  DHCP/DNS/SSH; el artefacto está `boot-untested`.
