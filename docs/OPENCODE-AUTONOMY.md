# Política de autonomía de OpenCode

Este documento define los límites de autonomía del agente OpenCode al trabajar
en este repositorio. Complementa a `AGENTS.md` y `SECURITY.md`.

## Modelo de permisos

La política se define en `opencode.json` usando la clave **`permission`**
(objeto `PermissionConfig` del schema oficial de OpenCode, no la clave
obsoleta `permissions`, y sin clave `version`).

- `read` / `edit` / `glob` / `grep` / `webfetch` / `websearch` → `allow`.
- `bash` → `ask` por defecto, con listas explícitas de `allow` y `deny`.
- Todo lo no listado explícitamente → `ask` (el usuario decide).
- `external_directory` → `deny` salvo el árbol del repositorio.

## Operaciones SIEMPRE denegadas (por política estática)

`scripts/test-opencode-security-policy.sh` verifica por análisis estático que
la política sigue denegando (nunca ejecuta los comandos):

- `adb *`
- `fastboot boot/flash/erase/format/set_active/reboot/continue/update/flashall`
- `fastboot oem/flashing/-w`
- `dd` (incl. `sudo dd`)
- `mkfs*`, `wipefs*`, `parted*`, `sgdisk*` (incl. `sudo`)
- Acceso a dispositivos de bloque: `/dev/block/*`, `/dev/sd?*`, `/dev/nvme*`,
  `/dev/mmcblk*`
- `git push --force*` / `git push -f*`
- `git reset --hard*` / `git clean -f*`
- `gh repo delete/archive`, `gh release delete`, `gh secret`
- `git clone`, `make`, `ninja`, `pmbootstrap`, `podman`, `docker`
- `sudo *`

## Límites de autonomía (orden de prioridad)

1. **Siempre libre**: editar archivos del repositorio, Git local, consultas
   Fastboot de solo lectura, análisis estático, investigación web.
2. **Autónomo**: crear/corregir workflows, ejecutar y supervisar GitHub
   Actions, descargar artefactos pequeños, corregir y re-ejecutar workflows
   fallidos (siempre que sea seguro y gratuito).
3. **Requiere autorización**: `gh repo create`, primer `git push`, crear
   releases, consumir minutos de pago, y cualquier operación irreversible.
4. **NUNCA sin autorización explícita por operación**: escribir, borrar,
   formatear o reiniciar el Xiaomi Mi A3 (`fastboot boot/flash/erase/...`,
   `adb`).

## Punto de parada antes del hardware

Antes de cualquier prueba física se aplica el procedimiento de la FASE 8 de
`AGENTS.md`: artefactos, hashes, tamaños, slot, particiones, recuperación,
respaldos y autorización explícita. No se continúa automáticamente.

## Cómo ejecutar el test

```
scripts/test-opencode-security-policy.sh
```

Debe pasar antes de cada `git push` y es parte de `00-quality.yml`.
