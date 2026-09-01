# Línea base reproducible Linux 6.1 — 2026-09-01

## Identidad

- Repositorio: `criollojoel10/pmos-laurel-sprout`
- Commit: `5b486324ead5d48d59d419376e5cdd43e3475492`
- Branch: `main`
- Estado Git: dirty por artefactos de auditoría locales no publicados

## Base de diagnóstico viva

- Kernel: `Linux laziel 6.1.0-sm6125`
- Estado funcional observado: arranque, SSH, framebuffer simple, acceso remoto RNDIS.

## Artefactos a conservar

- `local-private/linux61-dev/export-resolved/boot.img`
- `local-private/linux61-dev/export-resolved/boot-consoleblank0.img`
- `reports/live-device-audit-2026-09-01.md`
- `reports/runtime-6.1-devtools-live.md`

## Requisito de congelación

La congelación es operacional y documental: se conserva el estado actual de artefactos, hashes y documentación sin tocar el teléfono ni modificar la base funcional ya arrancada.
