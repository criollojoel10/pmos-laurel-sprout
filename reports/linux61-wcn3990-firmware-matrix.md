# Matriz firmware WCN3990 — Linux 6.1

Captura runtime: `/lib/firmware` solo contenía `regulatory.db` y
`regulatory.db.p7s`; no había firmware ath10k. No se escribió el rootfs.

| Archivo solicitado | Ruta esperada | Encontrado en dispositivo | Origen/hash local | Licencia/estado | Primer probe |
|---|---|---|---|---|---|
| `firmware-5.bin` | `ath10k/WCN3990/hw1.0/firmware-5.bin` | No | linux-firmware @ `e3c0c4b70f50ae77bea557b4a44be04413d3f3ed`; 60 B, SHA-256 `fef6539e0127579536bc977be57a90d018b83f2931fedc3a8870fbe38d6c4127` | redistribuible según inventario; validar contenido/commit antes de publicar | Sí |
| `board-2.bin` | `ath10k/WCN3990/hw1.0/board-2.bin` | No | linux-firmware @ `e3c0c4b70f50ae77bea557b4a44be04413d3f3ed`; 893,528 B, SHA-256 `c49d2f1894de6edc0ab0c8c9a17ca0328703747c49b6e9428f1de501c2c02c1d` | redistribuible según inventario; board-id de laurel aún no demostrado | Sí |
| `board.bin` | misma ruta | No | fallback linux-firmware, no descargado | redistribuibilidad pendiente; no renombrar al azar | Solo si el driver lo solicita |
| `cal-snoc-<device>.bin` | vendor/persist | No accesible | específico de unidad; no publicar | privado, extracción requerida | Pendiente |
| `pre-cal-snoc-<device>.bin` | vendor/persist | No accesible | específico de unidad; no publicar | privado, extracción requerida | Pendiente |

## Riesgos

- La entrada adecuada para `board-2.bin` debe confirmarse leyendo el board-id
  exacto en dmesg después del probe.
- La ausencia de calibración privada puede impedir asociación o reducir la
  calidad RF aunque el driver cree `wlan0`.
- Los blobs locales se mantienen en `local-private/` y no se añaden al repo.
- El `firmware-5.bin` descargado desde la API tiene 60 B y empieza con `QCA-ATH10K`;
  debe verificarse contra la distribución linux-firmware fijada antes de usarlo
  como artefacto final, porque el tamaño es inusual para un firmware ejecutable.
