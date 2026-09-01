# Estructura del boot image — audit 2026-09-01

## Evidencia

Se inspeccionó ambas imágenes con `file` y con la herramienta del repositorio `scripts/patch-bootimg-cmdline.py`.

## Observación

Ambas imágenes son Android boot images v0, page size 4096, kernel + ramdisk concatenados en la estructura estándar.

| Campo | `boot.img` | `boot-consoleblank0.img` |
|---|---|---|
| Header version | 0 | 0 |
| Page size | 4096 | 4096 |
| Kernel size | 9,422,366 B | 9,422,366 B |
| Ramdisk size | 2,974,573 B | 2,974,573 B |
| Second size | 0 | 0 |
| DTB size | 0 | 0 |
| Cmdline | `clk_ignore_unused` | `clk_ignore_unused consoleblank=0` |
| Tamaño total | 12,406,784 B | 12,406,784 B |

## Interpretación

- La diferencia observada está limitada al cmdline del header del boot image.
- El payload del kernel y el ramdisk es byte-idéntico.
- No se observan desplazamientos ni cambios del contenido del kernel/ramdisk.
- El boot image no incluye un DTB separado en el header; la validación de DTB real debe hacerse extrayendo los nodos del vendor tree y comparando el DTB de la ROM o del build actual.

## Estado

PASS_WITH_EXPLAINED_BINARY_DIFFERENCES
