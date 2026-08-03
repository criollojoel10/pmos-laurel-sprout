# Notas de seguridad

Este proyecto maneja un dispositivo experimental y datos potencialmente
sensibles.

## Reglas principales

1. **Nunca publicar** serial, IMEI, MAC, tokens, claves, respaldos, imágenes
   extraídas, `persist`, `modemst*`, `fsg`, `fsc`, EFS, calibración de unidad
   o logs con identificadores.
2. **Auditoría pre-push** obligatoria: `scripts/audit-public-repository.sh`.
3. **Dispositivo de solo lectura**: ninguna operación destructiva sin
   autorización explícita y respaldos.
4. **Secretos**: no se almacenan secretos ni binarios grandes en GitHub
   Secrets. El firmware propietario se aporta como artifact privado solo en
   fases futuras, sin publicarse.
5. **Workflows**: permisos mínimos, sin `pull_request_target`, acciones por
   SHA, sin caches con credenciales.

## Modelo de confianza

- `local-private/` está ignorado por Git y nunca se sube.
- Los workflows nunca ejecutan Fastboot.
- El firmware clasificado como `prohibited-from-repository` en
  `configs/firmware/firmware-manifest.json` no se incluye.

## Reportar incidentes

Ver `SECURITY.md`.
