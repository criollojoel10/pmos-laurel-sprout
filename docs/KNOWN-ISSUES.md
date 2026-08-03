# Problemas conocidos

Lista de problemas conocidos y limitaciones actuales del port.

## Inicial

- Todo el hardware sin validar físicamente: estados en `not-targeted` (ver
  `docs/HARDWARE-STATUS.md`).
- Modelo/bus/firmware de Wi-Fi y Bluetooth pendiente de investigación.
- Formato exacto del boot image (header version, page size, base, DTB append,
  vendor_boot) pendiente de investigación — NO asumido.
- Comportamiento de vbmeta/dtbo pendiente de verificación; no se borra DTBO
  automáticamente.

## Cómo reportar

Abrir un issue con la plantilla correspondiente en `.github/ISSUE_TEMPLATE/`
(build-failure, hardware-test o regression). Los logs se suben sanitizados.
