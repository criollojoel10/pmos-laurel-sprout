# Pantalla

Estado: **inicial**. Se documenta tras la investigación upstream
(`01-research-upstream`) y las pruebas físicas.

## Objetivo

- DRM/KMS con DPU (Display Processing Unit) mainline.
- MDSS (Mobile Display Subsystem).
- DSI + DSI PHY.
- Panel Samsung S6E8FC0, compatible `samsung,s6e8fc0-m1906f9`.
- Control de brillo.
- Apagado/encendido de pantalla.
- Orientación correcta (720x1560).

## Criterios de `working`

Ver `docs/HARDWARE-STATUS.md`. La presencia de un nodo de panel en el DTB no
implica pantalla funcional.

## Parches

En `patches/display/`. Antes de aplicar cada parche se verifica si está
upstream, en la rama sm61x5, o en el commit fijado; se comprueba con
`git apply --check` y se documenta origen y licencia.

## Referencias

- `qcom/sm6125-xiaomi-laurel-sprout.dtb`
- DTS del panel S6E8FC0 M1906F9.
- MDSS/DPU/DSI en `sm61x5-mainline`.
