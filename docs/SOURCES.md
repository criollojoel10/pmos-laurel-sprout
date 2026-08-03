# Fuentes

Toda fuente del proyecto se registra en `sources.lock.json` con:

`name, url, vcs, branch_informational, commit, commit_date, license, purpose,
verification_status, last_audited, notes`.

## Reglas de reproducibilidad

Una build reproducible DEBE rechazar:

- `main`/`master` sin commit fijado.
- `HEAD`.
- `latest`.
- URLs que cambien silenciosamente (ej. `download/latest`).
- Artefactos sin SHA-256.

## Fuentes mínimas

1. `linux-kernel.org` — base kernel mainline.
2. `sm61x5-mainline/linux` (Codeberg) — soporte SM6125 mainline.
3. `pmbootstrap` — herramienta de construcción postmarketOS.
4. `pmaports` — deviceinfo, APKBUILDs y port archivado `xiaomi-laurel`.
5. `linux-firmware` — blobs de firmware.
6. `mesa` — Freedreno/Turnip.
7. `lineageos/android_kernel_xiaomi_sm6125` — referencia Device Tree Android.
8. Firmware stock del Mi A3 (URL legal a verificar).

## Proceso

1. `01-research-upstream` audita cada fuente y produce `source-candidates.json`.
2. `02-freeze-sources` valida commits, fechas, licencias y checksums, y genera
   `sources.lock.proposed.json`.
3. Tras revisión humana, `sources.lock.json` se actualiza en `main`.

El flujo completo está en `docs/BUILD.md`.
