# Etapa 2 — reserved-memory / rmtfs / ramoops (pstore de diagnóstico)

Fecha: 2026-09-01
Estado del artefacto: `boot-untested` (se declara honestamente hasta prueba
física manual del propietario; el build CI no flashea).

## 1. Contexto

El boot funcional 6.1 (run 21, `boot_b`) arranca y da SSH
(`root@172.16.42.1`), pero dejó sin diagnóstico fiable a bordo: sin
persistencia de panics ni de logs en RAM tras un cuelgue. Esta etapa
reconstruye el kernel 6.1 (fork `sm6125-mainline` @`77de535b`) con
`CONFIG_PSTORE_RAM=y` y con el nodo `ramoops` del board DTS efectivamente
procesado por el kernel, para que `dmesg`/consola/pmsg sobrevivan a un
crash. Además incorpora el transporte `rmtfs-mem` (parche 0004) y un primer
probe WCN3990 (parche 0001) **sin firmware** (inocuo), dejando el MPSS
`disabled` (sin firmware de módem no debe arrancar el remoteproc).

## 2. Hallazgo raíz (bug en el fork)

El board DTS del fork define el contenedor de memoria reservada como

```
/reserved_memory { ... }        (guion bajo)
```

El kernel (`drivers/of/of_reserved_mem.c`) SOLO reconoce el contenedor
canónico `/reserved-memory` (guion). Consecuencia verificada en runtime
sobre el boot funcional:

- `/proc/iomem` muestra las regiones del `sm6125.dtsi` (`reserved-memory`
  con guion: hyp/xbl/smem/modem/venus/.../qseecom_ta) pero NO las del board
  (`debug_mem@ffb00000`, `last_log_mem@ffbc0000`,
  `ramoops/pstore_mem@ffc00000`, `cmdline_mem@ffd00000`).
- `/sys/fs/pstore` existe pero vacío; sin `dmesg` de ramoops.
- El DTB del boot (13536 B, SHA-256 `cb37540db8e8667c4a850c8da34704003f05e5
  c84c7761e58f369b18371c690e`, byte-idéntico al artefacto `kernel-6-1-
  historical` del workflow 09) SÍ contiene `reserved_memory` con los nodos
  hijos — el DTB los llevaba pero el kernel los ignoraba.

Es decir, el bug de nombre de nodo (guion bajo vs guion) inutilizaba
ramoops/pstore, debug_mem, last_log_mem y cmdline_mem en runtime.

## 3. Segundo fallo encontrado: binding de ramoops

El nodo `ramoops` del fork usa `msg-size = <0x20000 0x20000>`, propiedad
que no existe en `Documentation/devicetree/bindings/reserved-memory/
ramoops.yaml`. La correcta es `pmsg-size` con un único cell. Además las
unit-address no coincidían con `reg` (cosmético; el dtc emite warning):

- `ramoops@ffc00000` con `reg = <0x0 0xffc40000 0x0 0xc0000>`
- `cmdline_mem@ffd00000` con `reg = <0x0 0xffd40000 0x0 0x1000>`

## 4. Región elegida (0xffc40000–0xffd00000)

`ramoops` se declara en 0xffc40000 con 0xc0000 bytes; queda libre entre
`adsp_regions@f3400000` (fin: 0xf3c00000) y `qseecom_ta@13fc00000`. No
colisiona con ninguna región del `sm6125.dtsi`.

## 5. Solución (parche 0005)

`patches/kernel-61/0005-dts-sm6125-laurel-fix-reserved-memory-ramoops.patch`
(downstream-only, sobre `77de535b`):

1. Renombra `/reserved_memory` → `/reserved-memory` (guion).
2. Corrige el binding ramoops: `msg-size = <0x20000 0x20000>` →
   `pmsg-size = <0x20000>` (un cell).
3. Alinea unit-address: `ramoops@ffc00000` → `ramoops@ffc40000`;
   `cmdline_mem@ffd00000` → `cmdline_mem@ffd40000`.

El parche se regeneró computacionalmente a partir del DTS real del fork
(descarga vía GitLab API @`77de535b`), con contextos y conteos de hunk
exactos verificados: el primer intento manual falló en CI con
`error: corrupt patch at ...0005...:69` y se corrigió. Los hunks re-aplican
sobre el archivo original sin fricción (validado localmente).

## 6. Config del kernel

Config fuente: pmaports @`7aaee51a`
`config-postmarketos-qcom-sm6125.aarch64` (SHA-256
`08bcee71d4164ef3e7c1244cdf4d5a0e4e7e2eedcadd9e5576166f8661417c4a`).
Dieta honesta de la config del dispositivo (verificado):

| símbolo | valor | significado |
|---|---|---|
| `CONFIG_PSTORE=y` | `y` | base pstore (presente de fábrica) |
| `CONFIG_PSTORE_RAM/CONSOLE/PMSG` | no set | backend RAM/consola/pmsg AUSENTES → ramoops inútil |
| `CONFIG_QCOM_RMTFS_MEM=y` | `y` | driver built-in (transport rmtfs) |
| `CONFIG_ATH10K_SNOC=m` / `QCOM_WCNSS_PIL=m` | `m` | módulos Wi-Fi (presentes en rootfs) |

Fix aplicado en el workflow 22 (sed + `make olddefconfig`, idempotente):

```
CONFIG_PSTORE_RAM=y
CONFIG_PSTORE_CONSOLE=y
CONFIG_PSTORE_PMSG=y
```

Con gates bloqueantes en el propio workflow si no quedan `=y`.

## 7. Parches aplicados en la Etapa 2 (orden estricto)

| parche | contenido | estado |
|---|---|---|
| 0001-dts-laurel-wcn3990-first-probe | nodo `wifi@c800000` (qcom,wcn3990-wifi), primero sin SMMU/firmware | aplica limpio sobre `77de535b` |
| 0004-dts-sm6125-add-rmtfs-mem | nodo `rmtfs-mem` en sm6125.dtsi | aplica limpio (validado en workflow 20) |
| 0005-dts-sm6125-laurel-fix-reserved-memory-ramoops | fix pstore (nodo/ guion + binding) | aplica limpio tras 0001/0004 |

NO se aplican 0002/0003 (MPSS transport/enable): sin firmware de módem en
el rootfs, el remoteproc del MPSS debe permanecer `disabled`.

## 8. Boot ensamblado

- Mismo header boot v0 del boot funcional: `androidboot.hardware=laurel
  clk_ignore_unused` (cmdline), page 4096, kernel offset 0x8000, ramdisk
  0x1000000, tags 0x100.
- Nuevo kernel `Image.gz`: fork `77de535b` + PSTORE_RAM/CONSOLE/PMSG=y +
  parches 0001/0004/0005.
- DTB appendado: `sm6125-xiaomi-laurel_sprout.dtb` recompilado, validado en
  workflow (ramoops hijo de `/reserved-memory` con guion, `pmsg-size`,
  ausencia de `reserved_memory` con guion bajo).
- Ramdisk: el MISMO del boot funcional (run 21), extraído del propio
  `boot.img` (fuente de verdad), replicado byte a byte.
- `--os-version 0.0.0 --os-patch-level 2000-00` → `os_version field = 0x0`
  (idéntico al boot funcional).
- NO flashea, NO escribe el teléfono, NO sube firmware ni rootfs.

## 9. Resultados esperados al probar

1. Arranque idéntico al boot funcional (SSH `/sys/fs/pstore` presente).
2. `/sys/fs/pstore` con `dmesg-ramoops-0`/`console-ramoops-0`/`pmsg` tras
   un panic simulado (echo c > /proc/sysrq-trigger) o reinicio suave.
3. `/dev/qcom_rmtfs_mem1` existente (driver =y + nodo) — SIN userspace
   rmtfs, no se espera EFS funcional.
4. Tras reboot: pstore muesta los registros previos.

## 10. Criterios de éxito / no estándar

- Éxito si: boot + SSH siguen funcionando, pstore se rellena, kernel no
  toca errores graves nuevos de ramoops/rmtfs.
- NO se declara Wi-Fi: el parche 0001 solo verifica el probe; sin firmware
  `wlanmdsp.mbn`/`board-2.bin` el `ath10k_snoc` no pasará de probe fallida.
  Estado provisional: Wi-Fi `blocked` (falta firmware en rootfs), MPSS
  `disabled` (sin firmware de módem).
- `boot-untested` se actualizará tras la prueba física manual.

## 11. Regresión / rollback

- Rollback: el slot activo se mantiene; el artefacto de recuperación es el
  boot funcional original (boot.img run 21) ya respaldado en
  `local-private/linux61-dev/export-resolved/boot.img`. Disponibles
  respaldos boot/dtbo/vbmeta A y B (documentados en `docs/BACKUP-GUIDE.md`).
- Deriva mínima del boot funcional: solo kernel (mismo commit + PSTORE_RAM
  built-in + DTS fijado). El ramdisk es idéntico byte a byte.

## 12. Estado del artefacto

| ítem | valor |
|---|---|
| workflow | 22-build-linux61-stage2 |
| artefacto | `boot-linux61-stage2` (con DTB, config, manifest, SHA256SUMS) |
| kernel | `linux-postmarketos-qcom-sm6125` 6.1 @`77de535b` + [0001][0004][0005] |
| config | pmaports @`7aaee51a` + PSTORE_RAM/CONSOLE/PMSG=y |
| estado | `boot-untested` |