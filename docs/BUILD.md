# Construcción

Toda la construcción pesada corre en GitHub Actions con `workflow_dispatch`.
Localmente solo se editan archivos y se consulta Fastboot en solo lectura.

## Orden de ejecución

1. **01-research-upstream** — auditoría de fuentes upstream.
2. **02-freeze-sources** — propuesta reproducible de `sources.lock.json`.
3. **03-build-kernel** — kernel `debug` y `release` (una variante por run).
4. **04-build-pmos-console** — rootfs consola (recuperación).
5. **05-build-pmos-plasma** — rootfs Plasma Mobile.
6. **06-validate-images** — validación independiente de artefactos.
7. **07-package-prerelease** — release GitHub experimental.

## Ejecutar un workflow

```
gh workflow run 03-build-kernel.yml -f build_variant=debug
gh run watch
```

Inputs comunes:

- `build_variant` — `debug` | `release`.
- `kernel_commit` — commit del kernel a construir.
- `pmaports_commit` — commit de pmaports.
- `upload_artifacts` — `true` | `false`.
- `run_dtbs_check` — validar `make dtbs_check`.

## Recursos del runner

- Mostrar almacenamiento inicial (`df -h`, `free -h`).
- Limpiar herramientas preinstaladas no necesarias, sin tocar lo crítico.
- Separar kernel y rootfs en jobs.
- Comprimir módulos/imágenes con `xz` o `zstd`.
- Borrar fuentes antes de ensamblar artefactos.
- Retención de artefactos 3-7 días.
- No subir árboles fuente completos ni rootfs sin comprimir.

## Diagnóstico

Todos los workflows guardan logs con `if: always()` y suben archivos de
diagnóstico incluso si la build falla. Si un run falla:

1. `gh run view <run-id>`
2. `gh run download <run-id>`
3. Corregir el workflow COMPLETO, validar YAML, commit, push, re-ejecutar.
