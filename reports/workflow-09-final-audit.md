# Auditoría final — workflow 09 (reproduce-historical-boot)

Fecha: 2026-08-07. Run exitoso: 31154700285 (commit `bb4d7dd`).
Artefactos descargados y verificados localmente (read-only) desde
`local-private/workflow-09-artifacts/boot-out/`.

## Objetivo del workflow

Reproducir fielmente el **boot.img histórico de pmaports (dic 2022)**: header
v0, `append_dtb=true`, cmdline `clk_ignore_unused`, vbmeta flags=2, y una
variante de contraste con el kernel 7.1 actual (mismo header v0) para aislar
la hipótesis header v2 vs v0. NO flashea nada; solo genera artefactos
auditables.

## Resultado

| Item | Valor |
|---|---|
| Run | 31154700285 (workflow_dispatch, `main@bb4d7dd`) |
| Jobs | 1 (ensamblado v0 + vbmeta) — kernels reutilizados |
| Kernels reutilizados | run 31147870090 (artifacts `kernel-6-1-historical` #8982373909, `kernel-7-1` #8983143205) |
| Duración | ~1m51s |
| Conclusión | success |

## Cadena de errores previa (cómo se llegó al fix)

| Run | Commit | Fallo | Fix |
|---|---|---|---|
| 31147870090 | 55bad00 | Kernels 6.1/7.1 **compilan OK**; ensamblado falla en `pip install avbtool` → *No matching distribution found for avbtool* (no existe en PyPI) | 430bfc3/3c0b94f/bb4d7dd: avbtool.py desde Googlesource con sha256 fijado; reuso cross-run de kernels; `actions: read` |
| 31151422493, 31152831344 | 55bad00 | Runs fallidos previos al fix (ensamblado) | — |

## Artefactos verificados (run 31154700285)

Verificación local: `sha256sum -c SHA256SUMS` → **OK** (los tres ficheros).

| Archivo | Bytes | SHA-256 |
|---|---|---|
| `boot-laurel-kernel-6.1-historical-v0.img` | 10 461 184 | `ff5f0905282b105c3b17f49c2c07c98971547c29b25ddc75ba19453426b0a8be` |
| `boot-laurel-kernel-7.1-v0-appenddtb.img` | 21 573 632 | `391d40e226ee6a1edbe4a57ea8e94606759665181a0974be69667fc2e6d85849` |
| `vbmeta-historical-flags2.img` | 4 096 | `fe1f4b55088fbc97040bc898d8b076f93c93e203c8ba7a15c8348080351f4ca2` |

## Verificación de la variante histórica (6.1)

`v0-verification.md` (generado en CI) + roundtrip:

| Comprobación | Resultado |
|---|---|
| magic `ANDROID!` | SÍ |
| header_version == 0 | SÍ (header v0, no v2) |
| page_size == 4096 | SÍ |
| cmdline histórica `clk_ignore_unused` | SÍ |
| kernel_size == Image.gz+DTB (9 252 106 B) | SÍ |
| payload kernel byte-idéntico (sha `97b4bff0…`) | SÍ |
| ramdisk gzip (1 202 868 B, `1f8b`) | SÍ |
| encaja en partición boot (64 MiB) | SÍ (10.4 MB ≤ 67 108 864) |

Roundtrip (unpack):
- 6.1: kernel_addr `0x8000`, ramdisk_addr `0x1000000`, tags_addr `0x100`.
- 7.1: mismo layout, kernel 20 364 527 B, cmdline
  `console=ttyMSM0,115200n8 clk_ignore_unused`.

## Estado honesto

- **Generación**: `boot-untested` (imágenes construidas y validadas
  estáticamente; ninguna se ha probado en el dispositivo).
- **Formato**: estructuralmente idéntico al flujo pmbootstrap 1.50.0/2022
  (reporte `reports/historical-pipeline-reproduction.md`).
- **Relación con FASE 3**: estas imágenes v0 son independientes del rootfs
  que genera el workflow 10 (que usa el flujo pmbootstrap real con
  `mkbootimg-osm0sis`/boot-deploy header v0). Ambas líneas convergen en el
  mismo formato histórico; la v0 aquí es el **test de contraste** para la
  hipótesis del header en FASE E.
- Pendiente de decisión (FASE 8): qué variante se probará físicamente y en qué
  slot; no se recomienda flashear hasta confirmar respaldos y slot activo.

## Fuentes fijadas

Kernel histórico 6.1: `sm6125-mainline/linux@77de535b8dbd8f483b5802c8937cb714bab5b485`.
Kernel actual 7.1: `torvalds/linux@b3f94b2b3f3e51ab880a51fc6510e1dafba654ed` (de
`linux-mainline-v7.1` en `sources.lock.json`).
Config congelada: `config-postmarketos-qcom-sm6125.aarch64` @ `7aaee51a`
(sha256 `08bcee71d4164ef3e7c1244cdf4d5a0e4e7e2eedcadd9e5576166f8661417c4a`).
avbtool.py: Googlesource, sha256 fijado en el workflow.
