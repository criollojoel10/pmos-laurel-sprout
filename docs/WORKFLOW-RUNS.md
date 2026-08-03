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
| 30792773593 | 03-build-kernel (debug) | b36a195 | en curso | Re-run con fragmento base corregido (USB/BT/regulator validados v7.1) |

## Notas operativas

- El clonado de torvalds v7.1 (shallow, blob:none) tarda ~3-5 min.
- La compilación completa (Image + dtbs + modules, cross-gcc, 4 CPU) tarda
  ~25-30 min.
- `upload_artifacts` debe evaluarse como `!= 'false'` (los inputs booleanos de
  workflow_dispatch llegan como string).
- El paso "Empaquetar salida" se salta si el input no se pasa y la condición
  es `== true`.
