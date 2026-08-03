# AGENTS.md — pmos-laurel-sprout

Proyecto: port moderno de postmarketOS (Plasma Mobile, systemd) para el
Xiaomi Mi A3 `laurel_sprout` (Qualcomm SM6125 / trinket / Snapdragon 665 /
Adreno 610).

Este archivo es de aplicación obligatoria para cualquier agente (humano,
IA, CI) que trabaje en este repositorio.

---

## 0. Dispositivo conectado: ESTRICTAMENTE DE SOLO LECTURA

El teléfono experimental Xiaomi Mi A3 puede estar conectado en Fastboot.

Hasta que se otorgue una autorización explícita e inmediata ANTES de cada
operación, queda PROHIBIDO:

- `fastboot boot`
- `fastboot flash` / `flashall`
- `fastboot erase`
- `fastboot format`
- `fastboot set_active`
- `fastboot reboot` / `continue` / `update`
- `fastboot -w`
- `fastboot oem` / `fastboot flashing`
- `adb` (mientras el dispositivo está en Fastboot)
- cualquier variante equivalente o llamada indirecta
- escribir, borrar, formatear o cambiar cualquier partición

COMANDOS PERMITIDOS (solo lectura):

```
fastboot devices
fastboot getvar product
fastboot getvar current-slot
fastboot getvar unlocked
fastboot getvar slot-count
fastboot getvar has-slot:boot
fastboot getvar has-slot:dtbo
fastboot getvar has-slot:vbmeta
fastboot getvar partition-size:boot_a
fastboot getvar partition-size:boot_b
fastboot getvar partition-size:dtbo_a
fastboot getvar partition-size:dtbo_b
fastboot getvar partition-size:vbmeta_a
fastboot getvar partition-size:vbmeta_b
fastboot getvar partition-type:boot_a
fastboot getvar partition-type:dtbo_a
fastboot getvar partition-type:vbmeta_a
```

`fastboot getvar all` solo con el flujo de `scripts/read-fastboot-metadata.sh`
(guarda en `local-private/`, sanitiza, NUNCA publicar sin filtrar).

Nunca automatizar Fastboot en workflows o scripts que se ejecuten sin
supervisión humana.

## 1. Información que NUNCA se publica

- Número de serie del dispositivo.
- IMEI.
- Direcciones MAC.
- Tokens, credenciales, claves privadas, claves Android.
- Variables de entorno con secretos.
- Salida sin filtrar de `fastboot getvar all`.
- Respaldos del dispositivo ni imágenes extraídas del teléfono.
- `persist`, `modemst1`, `modemst2`, `fsg`, `fsc`, EFS.
- Archivos de calibración específicos de esta unidad.
- Logs con identificadores únicos.
- Firmware cuya licencia no permita redistribución.
- Información personal del usuario.

Prohibido usar Git LFS para subir respaldos o blobs privados.

Antes de cada `git push` ejecutar `scripts/audit-public-repository.sh`; el push
debe rechazarse si se detecta información sensible.

## 2. Honestidad técnica

No declarar que algo funciona porque compila.

Estados permitidos (únicos):

`not-targeted`, `source-available`, `configured`, `compiled`, `packaged`,
`static-validation-passed`, `boot-untested`, `detected`, `partially-working`,
`working`, `blocked`, `regressed`.

Mantenerlos en `reports/hardware-matrix.json` y `docs/HARDWARE-STATUS.md`.

No confundir:
- KGSL Android con DRM/MSM mainline.
- Pantalla funcional con GPU funcional.
- DPU funcional con aceleración 3D funcional.
- llvmpipe con aceleración GPU.
- Configuración Kconfig con funcionamiento físico.
- Compilación exitosa con port terminado.

## 3. Trabajo local vs GitHub Actions

Local (permitido):
- crear y editar archivos del repositorio;
- Git y GitHub CLI;
- crear el repo y publicar (con autorización);
- iniciar y supervisar GitHub Actions;
- consultas Fastboot de solo lectura;
- descargar artefactos pequeños;
- análisis de texto, YAML, JSON y logs.

Local (PROHIBIDO):
- clonar repositorios upstream grandes;
- compilar kernel, ejecutar pmbootstrap, construir rootfs;
- ejecutar make/ninja, Docker o Podman;
- descomprimir árboles de kernel;
- construir boot.img;
- ADB en Fastboot;
- escribir en el teléfono.

Todo el trabajo pesado se ejecuta EXCLUSIVAMENTE en GitHub Actions.

## 4. Workflows

- Todos los workflows pesados usan `workflow_dispatch`; no compilar en cada
  push.
- `00-quality.yml` puede correr en push/pull_request: solo validación estática
  (YAML, JSON, ShellCheck, formato, secretos, sources.lock.json, comandos
  destructivos, licencias, acciones fijadas por SHA).
- Todos los workflows deben: `permissions` mínimos, `contents: read` por
  defecto, `contents: write` solo en prerelease, no `pull_request_target`,
  `concurrency` con `cancel-in-progress: true`, `timeout-minutes`, `set -Eeuo
  pipefail`, guardar logs con `if: always()`, mostrar `df -h`/`free -h`,
  fijar acciones externas por SHA completo, retención 3-7 días, no subir
  árboles fuente, no subir caches con credenciales, no rootfs sin comprimir.

## 5. Fuentes y reproducibilidad

Toda fuente se registra en `sources.lock.json` con:
`name, url, vcs, branch_informational, commit, commit_date, license, purpose,
verification_status, last_audited, notes`.

Una build reproducible debe rechazar `main`/`master`/`HEAD`/`latest` sin
commit fijado, URLs que cambien silenciosamente y artefactos sin SHA-256.

## 6. Parches

Antes de aplicar un parche: verificar si está upstream, en la rama SM61x5, o
en el commit fijado; comprobar dependencias; `git apply --check`; registrar
origen y licencia; evitar duplicados; conservar autoría y Signed-off-by;
documentar el estado (upstream/accepted/queued/pending/downstream-only/
local-workaround).

## 7. Respaldos y recuperación

Ninguna prueba física que escriba el teléfono sin haber registrado antes:
firmware stock identificado, instrucciones de restauración, slot activo,
tamaños reales de boot/dtbo/vbmeta A y B, estado del bootloader, respaldos de
boot/dtbo/vbmeta (A y B), persist, y particiones de identidad de radio.

Si faltan respaldos: NO flashear; generar guía para respaldar desde
Android/recovery root; detenerse.

## 8. FASE 8 — punto de parada obligatorio

Antes de cualquier prueba física se debe: mostrar artefactos, hashes, tamaño
de boot y límite, slot actual, particiones que se modificarían, procedimiento
de recuperación, confirmar respaldos, recomendar la prueba menos destructiva,
DETENERSE y solicitar autorización explícita. No continuar automáticamente.

## 9. Git

Commits pequeños y descriptivos. Antes de cada push: auditoría pública, `git
status`, `git diff --stat`, lista de commits, y autorización si se publicará
contenido sensible o de gran alcance. Autorización antes del primer push.

## 10. Licencias

GPL-3.0-or-later para integración propia, scripts y workflows salvo razón
documentada. Preservar licencias y autoría de kernel, pmaports, parches,
firmware, Device Trees y documentación upstream. No relicenciar trabajo de
terceros. No incluir firmware bajo GPL si no corresponde.
