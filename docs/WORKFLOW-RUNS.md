# Registro de ejecuciones CI (workflow runs)

Registro manual de runs relevantes. Cada run referencia commit y resultado.

| Run | Workflow | Commit | Resultado | Notas |
|---|---|---|---|---|
| 30785377934 | 02-m1-reference-audit | ef7f375 | success | Audit M1: panel/táctil/GPU/firmware A610 confirmados |
| 30785292893 | 03-build-kernel (debug) | 53e6037 | failure | Doble-apply de parches (build-kernel.sh reaplicaba) |
| 30785546713 | 03-build-kernel (debug) | caafa7d | failure | `qcom_defconfig` no existe en mainline v7.1 |
| 30785769342 | 03-build-kernel (debug) | c1eb868 | failure | Fragmentos no resueltos desde la raíz del repo |
| 30786019666 | 03-build-kernel (debug) | 5e9b1dc | failure | Falta CROSS_COMPILE (gcc host rechazaba -mlittle-endian) |
| 30786551830 | 03-build-kernel (debug) | 99e13d6 | **success** | Image + DTB generados; verify-kconfig/dtb pasan |
| 30789357941 | 03-build-kernel (debug) | 80aca43 | **success** | Artefactos completos (Image 68MB, modules, DTB 37KB, SHA256SUMS OK). verify-kconfig: 4 símbolos no presentes (USB/BT/regulator legacy) |
| 30792773593 | 03-build-kernel (debug) | b36a195 | **success** | Artefactos finales; verify-kconfig **sin avisos** (fragmento validado v7.1); símbolos BT/USB/regulator correctos |
| 30835329663 | 04-build-diagnostic-boot | 776f2ae | success | **INVÁLIDO para boot**: initramfs con busybox-static de Ubuntu (x86-64) → `exec format error` en aarch64. Detección en FASE E0 |
| 30878960010 | 04-build-diagnostic-boot | 57242cd | failure | Paso "Construir BusyBox arm64": make falla (exit 2). Log truncado por `tail -20` |
| 30879227646 | 04-build-diagnostic-boot | f916203 | failure | make falla en `networking/tc.c` (constantes CBQ `TCA_CBQ_*` eliminadas de headers del kernel runner). make.log completo subido como artefacto |
| 30910269044 | 04-build-diagnostic-boot | e45ff43 | failure | `make: No rule to make target 'olddefconfig'` (kconfig de busybox no lo soporta) |
| 30916017707 | 04-build-diagnostic-boot | d7cc191 | **success** | **boot.img válido**: busybox arm64 estático verificado, SHA256 `66e7005f…`, roundtrip kernel/ramdisk/dtb OK |
| 31125804069 | 09-reproduce-historical-boot | ae4e9a8 | failure | **INFRASTRUCTURE_FAILURE_NO_RUNNER_ASSIGNED**: incidencia global de GitHub Actions (2026-08-06, incidente `qcvjkzcs7j74`, crítica). Ambos jobs en `queued`, `runner_name` vacío, `steps=[]`, cancelados a los ~15 min. NO es fallo de código/kernel |
| 31126185358 | 09-reproduce-historical-boot | ae4e9a8 | failure | **INFRASTRUCTURE_FAILURE_NO_RUNNER_ASSIGNED**: mismo incidente (redespacho durante el outage, sin runner asignado). NO es fallo de código/kernel |
| 31127021027 | 00-quality | 91e2085 | success | Canario post-incidencia: confirmado runner asignado, steps ejecutados, success. (31127014052 cancelado por concurrency cancel-in-progress del mismo push) |
| 31147870090 | 09-reproduce-historical-boot | 9b1d7b9 | failure | Kernels 6.1 y 7.1 compilan OK. Job de ensamblado falla en "Instalar dependencias": `pip install avbtool` → `No matching distribution found for avbtool` (no existe en PyPI). Corregido en 55bad00 |
| 31151422493 | 09-reproduce-historical-boot | 430bfc3 | failure | Reutilización cross-run de kernels sin permisos `actions: read` (download-artifact no accede a artefactos de otro run). Corregido en 3c0b94f |
| 31152831344 | 09-reproduce-historical-boot | 3c0b94f | failure | Falta `github-token` en download-artifact para reuso cross-run. Corregido en bb4d7dd |
| 31154700285 | 09-reproduce-historical-boot | bb4d7dd | **success** | Ensamblado v0 + vbmeta flags=2 OK reutilizando kernels de 31147870090. Artefactos `historical-boot-images` (2 boot.img v0 + vbmeta) verificados localmente. Detalle: `reports/workflow-09-final-audit.md` |
| 31210717507 | 10-build-historical-rootfs | 21776b6 | failure | FASE 3. `(native) apk add failed (exit 3)` al instalar el cross-compiler: pmbootstrap 1.52.0 no reindexa el repo local tras compilar gcc-aarch64 r5, mientras g++-aarch64 se resuelve a r4 (pin gcc=r4) → constraints insatisfables. Fix parcial en 21776b6 (index tras build) |
| 31227789300 | 10-build-historical-rootfs | 21776b6 | failure | FASE 3. Causa raíz confirmada en el APKBUILD de cross/gcc-aarch64 @7aaee51a: el subpaquete `gpp()` pinnea `libstdc++=12.2.1_git20220924-r5`, pero Alpine v3.17 actual solo tiene r4 → el r5 es **ininstalable**, independientemente del reindex. Fix definitivo en e23656e (workaround: revertir árbol a pkgrel=4, usar el gcc-aarch64 r4 del repo v22.12) |
| 31229015234 | 10-build-historical-rootfs | f94c6fc | failure | FASE 3. Workaround gcc r4 OK: cross-compiler r4 instalado sin apk error y **kernel 6.1 @77de535b compilado y empaquetado** (`linux-postmarketos-qcom-sm6125-6.1-r0.apk`, 22.6 MB, build 1h07m, DONE!). El paso de build falló solo por el `find` de verificación: recorría el chroot y moría con `Permission denied` (exit 1, set -e). Fix en el workflow: buscar solo en `packages/` con `2>/dev/null \|\| true` |
| 31272665175 | 10-build-historical-rootfs | 97b193b | failure | **`--password` OK** (el hang de passwd desapareció): install llegó a `SET LOGIN PASSWORD`, mkinitfs y formateo ext2/ext4. Fallo: `cp -a ... /mnt/install/` → `No space left on device`. El `du -ks` del chroot dio 553 MB y con extra_space=256 la imagen salió en 1034M (boot 64 + root 970), insuficiente para el contenido real + overhead ext4. Fix: extra_space 256→1024 (e090d25), caso pmbootstrap#1904. Kernel compilado OK de nuevo |
| 31275805110 | 10-build-historical-rootfs | 09a6ea5 | failure | Redespacho con extra_space=1024 (imagen ~1.8 GiB). **Nuevo `No space left on device` en el mismo `cp -a`** con root de 1738M: el root no era el problema. Causa real: p1 (boot) quedaba en solo 56 MiB — con sector size 4096, `parted mkpart ... 2048s 64M` arranca la partición en el byte 8 MiB (2048×4096). El `cp -a dev run opt sbin boot ...` copia `/boot` en 5º lugar y desborda p1. Fix: boot_size 64→256 (378a96b, default de pmbootstrap 1.52.0) |
| 31287053170 | 10-build-historical-rootfs | 378a96b | failure | **boot_size=256 FUNCIONÓ**: imagen de 1994M (boot 256M + root el resto); p1 validada en 236 MiB (offset 8 MiB), p2 1.7 GiB, e2fsck OK en ambas, `copy ... to /mnt/install/` y `make sparse rootfs` DONE. Rootfs exportado y validado. Único fallo: paso "Generar manifest y reporte" por **error de quoting en jq** (comillas simples dentro del filtro con apóstrofes rompían el quoting de shell; filtro truncado en línea 10). Fix: quitar apóstrofes de `fastboot getvar partition-size:system_b` en la cadena `flash_target` (commit a5…) |
| 31320766387 | 10-build-historical-rootfs | 93ffa65 | **success** | **REPRODUCCIÓN COMPLETA del rootfs histórico**: los 21 pasos pasan. Artefactos: `xiaomi-laurel.img` (550,959,944 B sparse, sha256 `754bd35c…`), `part1.img` boot ext2 (247 MB, `e4df9958…`), `part2.img` root ext4 (1.8 GB, `2c763492…`), boot.img/initramfs/initramfs-extra/vmlinuz exportados, manifest.json + reporte (postmarketOS v22.12.2, paquetes device-xiaomi-laurel, linux-postmarketos-qcom-sm6125, mkbootimg-osm0sis, boot-deploy). Checksums verificados localmente OK. Descarga local: `local-private/run31320766387-artifacts/`. Gate FASE 8 listo (R8 completo, system_b=3 GiB confirmado) |

## Notas operativas

- El clonado de torvalds v7.1 (shallow, blob:none) tarda ~3-5 min.
- La compilación completa (Image + dtbs + modules, cross-gcc, 4 CPU) tarda
  ~25-30 min.
- `upload_artifacts` debe evaluarse como `!= 'false'` (los inputs booleanos de
  workflow_dispatch llegan como string).
- El paso "Empaquetar salida" se salta si el input no se pasa y la condición
  es `== true`.
- El initramfs requiere un busybox ESTÁTICO arm64 (dispositivo aarch64). Se
  compila en CI con `scripts/build-busybox-arm64.sh` (crossbuild-essential-arm64).
  NO usar `busybox-static` de Ubuntu (x86-64): rompe el boot del dispositivo.
  El applet `tc` se deshabilita porque los headers del kernel del runner ya no
  incluyen las constantes CBQ; busybox solo soporta `oldconfig`/`defconfig` en
  su kconfig (no `olddefconfig`).
