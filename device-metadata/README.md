# device-metadata

Metadata SANITIZADA del dispositivo Xiaomi Mi A3 conectado.

Este directorio solo contiene datos públicos y no identificables:

- `fastboot-sanitized.json` — generado por `scripts/read-fastboot-metadata.sh`.
- `fastboot-sanitized.example.json` — ejemplo para referencia sin datos reales.

NUNCA se publica en este directorio:

- Número de serie.
- IMEI.
- Direcciones MAC.
- Salida cruda de `fastboot getvar all`.
- Respaldos o imágenes extraídas del teléfono.
- Firmware o calibración específica de unidad.

La salida cruda se guarda en `local-private/fastboot-raw.txt`, ignorado por
Git.
