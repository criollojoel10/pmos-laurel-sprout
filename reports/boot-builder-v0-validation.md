# Reporte — Builder boot.img v0/v2 + append_dtb: validación automatizada

Fecha: 2026-08-06. Estado: VALIDADO.

## Alcance

`scripts/build-boot-image.py` soporta los tres modos exigidos por el port:

| Modo | Comando | Resultado |
|---|---|---|
| A. v2 actual | `--header-version 2` | DTB como sección separada, header 1660 B |
| B. v2 + append | `--header-version 2 --append-dtb` | kernel = Image.gz+DTB, dtb_size=0 |
| C. v0 histórico | `--header-version 0 --append-dtb` | kernel = Image.gz+DTB, header 1632 B, sin sección DTB |

## Pruebas (`tests/test_build_boot_image.py`, 14 casos)

Ejecución:

```
python3 -m unittest discover -s tests -v
Ran 14 tests in 6.388s
OK
```

| Caso | Verifica |
|---|---|
| test_v2_normal | magic, header_version=2, header_size=1660, DTB como sección separada |
| test_v2_append_dtb | kernel = Image.gz+DTB, dtb_size=0, DTB en la frontera |
| test_v0_append_dtb | header v0 1632 B, kernel = Image.gz+DTB, fin de imagen tras ramdisk |
| test_v0_no_append | v0 sin append aún escribe sección DTB válida |
| test_offsets | kernel_addr=0x8000, ramdisk_addr=0x1000000, tags_addr=0x100 |
| test_page_padding | secciones y total alineadas a page 4096 |
| test_kernel_payload | payload del kernel byte a byte |
| test_ramdisk_payload | payload del ramdisk byte a byte |
| test_dtb_boundary | magic `d0 0d fe ed` en offset = size(Image.gz) |
| test_id_hash | id[0:20] = SHA1(kernel+ramdisk+second+dtb) como mkbootimg |
| test_size_limit | total < 64 MiB |
| test_reject_invalid_header_version | `--header-version 1` rechazado |
| test_cmdline_preserved | `clk_ignore_unused` conservada en header |
| test_os_version_encoded | os_version = major<<25|minor<<18|patch<<11|patch_level |

## Verificación en CI

El paso `Ejecutar unit tests del builder de boot image` se añadió a
`.github/workflows/00-quality.yml` (corre en push/pull_request), de modo que
cualquier cambio futuro del builder queda cubierto por validación estática.

## Conclusión

El builder reproduce el boot.img histórico del port xiaomi-laurel
(postmarketos-mkinitfs 1.5.1 → boot-deploy 0.6.1 → mkbootimg-osm0sis
2021.08.06) con header v0 + append_dtb + cmdline `clk_ignore_unused`,
y mantiene la compatibilidad con header v2 (default) para los artefactos
modernos ya publicados.
