# Problemas conocidos

Lista de problemas conocidos y limitaciones actuales del port.

## Inicial

- Todo el hardware sin validar físicamente: estados en `not-targeted` (ver
  `docs/HARDWARE-STATUS.md`).
- Modelo/bus/firmware de Wi-Fi y Bluetooth pendiente de investigación.
- Formato exacto del boot image (header version, page size, base, DTB append,
  vendor_boot) **RESUELTO parcialmente**: el ABL de laurel_sprout solo arranca
  **header v0 + DTB concatenado (append_dtb)**, page 4096, base 0x0 (evidencia
  H61 6.1 sedfix → INITRAMFS_SHELL_ACTIVE). Todo header **v2** → fallback a
  Fastboot (incluida la imagen NixOS v2, `bootloader-rejected`). La variante
  recomendada es `--boot-layout v0-append`; `vendor_boot` nunca usado.
- Comportamiento de vbmeta/dtbo pendiente de verificación; no se borra DTBO
  automáticamente.

## Boot image NixOS (2026-08-29)

- `boot-laurel-nixos-console-v0-append.img` (v0-append) validada en CI,
  `hardwareTested=false` — TEST FÍSICO PENDIENTE (FASE 8, requiere autorización).
  sha256 `1043b607ce05515308de5b164f9bbc93667a86a2659f4f9f537f3cfbd94ecd78`,
  detalle en `reports/nixos-v0-append-ci-validation.md`.

## Cómo reportar

Abrir un issue con la plantilla correspondiente en `.github/ISSUE_TEMPLATE/`
(build-failure, hardware-test o regression). Los logs se suben sanitizados.
