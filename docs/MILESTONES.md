# Hitos del proyecto

Estado: actualizado (2026-08-03). Cada hito se actualiza en `reports/milestones.json`.

## M0 — Fundación (completado)

- [x] Repositorio local con estructura, scripts y workflows.
- [x] Metadata Fastboot sanitizada.
- [x] Auditoría upstream inicial (URLs, commits, ramas).
- [x] Repositorio GitHub publicado (public).
- [x] Workflow 01 ejecutado y resultados incorporados (run 30775362988).

## M1 — Investigación y fuentes congeladas

- [x] Workflow 01 completo (referencias, firmware, boot layout).
- [ ] Decisión de base del kernel (DECISION-0002).
- [ ] `sources.lock.json` con commits fijados y SHA-256.
- [x] `reports/kernel-candidates.json` y `docs/KERNEL-BASE-COMPARISON.md`.
- [ ] `02-freeze-sources` aprobado.

Pendiente de M1: localizar panel/táctil (H4) en ramas `barni2000/*` y
firmware A610 (H5, no en pmaports main).

## M2 — Kernel

- [ ] APKBUILD preliminar `linux-postmarketos-qcom-sm6125`.
- [ ] Parches auditar y aplicar (PATCH-PLAN).
- [ ] Build de kernel en CI (03-build-kernel) exitosa.
- [ ] DTB embebido en boot.img validado (06/verify-dtb).
- [ ] `static-validation-passed` para kernel.

## M3 — Rootfs

- [ ] Imagen consola (04) y Plasma (05) construidas.
- [ ] Validación de rootfs (06) aprobada.
- [ ] Artefactos con hashes y tamaño de boot dentro del límite.

## M4 — Prueba física (FASE 8 obligatoria)

- [ ] Procedimiento no destructivo listo (`fastboot boot`).
- [ ] Autorización explícita del usuario.
- [ ] Prueba de arranque y recogida de logs.
- [ ] Actualizar hardware-matrix con estados honestos.

## M5 — Release

- [ ] Workflow 07 con `contents: write` (solo prerelease).
- [ ] Publicación de prerelease con hashes.
