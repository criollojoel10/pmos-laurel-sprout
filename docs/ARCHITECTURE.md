# Arquitectura

Visión general del port postmarketOS para el Xiaomi Mi A3 `laurel_sprout`.

## Capas

1. **Kernel** — Linux 6.19.x sobre la base `sm61x5-mainline` (Codeberg),
   fijado por commit, con DTB `qcom/sm6125-xiaomi-laurel-sprout.dtb`.
2. **postmarketOS Edge** — rootfs AArch64 con systemd.
3. **Interfaz** — KDE Plasma Mobile 6 (KWin Wayland, Qt 6); imagen consola de
   recuperación (Weston/Foot) como respaldo.

## Flujo de construcción (GitHub Actions)

```
01-research-upstream → 02-freeze-sources → 03-build-kernel
        └─────────────────────────────────────┼─────────→ 04-console / 05-plasma
                                           06-validate-images → 07-prerelease
08-process-device-logs (post-prueba)
```

- Todo trabajo pesado corre en runners públicos estándar mediante
  `workflow_dispatch`.
- No se compila en cada push; `00-quality` solo valida estáticamente.
- Los artefactos se comprimen con `xz`/`zstd` y se descartan los árboles
  fuente antes de empaquetar.

## Modelo de seguridad

- Permisos mínimos: `contents: read` por defecto; `contents: write` solo en
  `07-package-prerelease`.
- Sin `pull_request_target`; acciones externas fijadas por SHA completo.
- Sin secretos en repositorio; `local-private/` ignorado por Git.
- El teléfono es de SOLO LECTURA; ninguna automatización invoca Fastboot.

## Componentes de hardware y estado

Ver `docs/HARDWARE-STATUS.md` y `reports/hardware-matrix.json` para el estado
honesto de cada componente. La GPU y la pantalla solo se marcan `working` tras
los criterios físicos listados en `docs/HARDWARE-STATUS.md`.

## Documentos relacionados

- `docs/SOURCES.md` — fuentes y reproducibilidad.
- `docs/BUILD.md` — ejecución de workflows.
- `docs/INSTALL.md` — instalación.
- `docs/RECOVERY.md` — recuperación.
