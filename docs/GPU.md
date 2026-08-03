# GPU

Estado: **inicial**. Sin prueba física aún.

## Objetivo

- Adreno 610 mediante DRM/MSM mainline.
- Mesa Freedreno (y Turnip/Vulkan cuando sea viable).
- Aceleración 3D real, no llvmpipe.

## Criterios de `working` (todos obligatorios)

1. `/dev/dri/card0` existe.
2. `/dev/dri/renderD128` existe.
3. El firmware Adreno se carga correctamente.
4. Sin fallo fatal de IOMMU, GMU, clocks ni regulators.
5. `eglinfo` identifica Freedreno.
6. El renderer no es llvmpipe.
7. `glmark2-es2-wayland` completa una prueba.
8. KWin inicia con aceleración.

## Advertencias

- KGSL Android != DRM/MSM mainline.
- Pantalla funcional != GPU funcional.
- DPU funcional != aceleración 3D funcional.
- llvmpipe != aceleración GPU.

La existencia del nodo GPU en el DTB no implica GPU funcional.

## Parches

En `patches/gpu/`. Verificar upstream/estado antes de aplicar.
