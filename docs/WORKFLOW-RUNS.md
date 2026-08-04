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
