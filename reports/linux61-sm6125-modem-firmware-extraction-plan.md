# Plan de extracción de firmware MPSS (modem) — SM6125

Estado: `source-available` (procedimiento listo; NO ejecutado)
Fecha: 2026-08-13
Fase: M10 de la misión MPSS v2
Método: extracción PRIVADA del firmware propietario del modem; sin ninguna
operación física; sin publicar blobs.

---

## 1. Objetivo

Disponer de un procedimiento documentado y un script listo para extraer el
firmware MPSS (`modem.mdt` + `modem.bXX`) desde la ROM stock ya descargada
en `local-private`, de modo que cuando haya autorización humana explícita
(AGENTS.md §0, §7, §8) se pueda preparar `/lib/firmware/qcom/sm6125/`
sin errores.

## 2. Origen (ya disponible en local-private)

| ítem | valor |
|------|-------|
| Archivo | `local-private/rom-references/laurel_sprout_global_images_V12.0.26.0.RFQMIXM_11.0/images/NON-HLOS.bin` |
| Tamaño | 117,198,848 B |
| SHA-256 | `ed5279f2595f98ecc86ebc8c1d5e5017033bfc0d3384f144ae8de773cabe24bf` |
| Formato | imagen FAT16 (dosfs), Bytes/sector 4096 (no montada en ningún momento) |
| ROM | MIUI 12.0.26.0 (global), imagen oficial Xiaomi |
| ver_info | modem = `MPSS.AT.4.3.1-00206.2-NICOBAR_GEN_PACK-1`; wlan = `WLAN.HL.3.0.2-00215-QCAHLSWMTPLZ-1` |

## 3. Contenido inspeccionado (solo lectura, sin extraer)

El volumen FAT16 tiene dos directorios raíz: `image/` y `verinfo/`.

Dentro de `image/`:
- `modem.mdt` — 9,100 B (ELF header/MBN del modem, table de segmentos)
- 28 segmentos `modem.bXX`: b00..b12, b14..b18, b20..b29
  (no existen b13 ni b19; los segmentos se mapean por índice del mdt)
- Otros subsistemas presentes: `adsp.mdt`+segments, `cdsp`, `venus`,
  `tz`, `cmnlib`, `widevine`, etc. — NO relevantes para la v2.
- `verinfo/ver_info.txt` — IDs de build (no firmware).

## 4. Mecanismo de extracción

Herramientas: `mtools` (`mdir`, `mcopy`, `mtype`). La imagen FAT NO se
monta (evita tocar el host con blobs privados y reduce riesgo de escritura
accidental).

Pasos (los ejecuta el script, no este plan):
1. Validar SHA-256 del `NON-HLOS.bin` contra `ed5279f2...` (detección de
   datos inesperados).
2. Verificar `file` = FAT.
3. Listar `/image` con `mdir` y comprobar `modem.mdt` + ≥20 segmentos.
4. Copiar con `mcopy` `::/image/modem.mdt` y cada `modem.bXX` a un
   directorio SOLO en `local-private`.
5. Generar `sha256-after.txt` con los hashes de lo extraído.
6. Detenerse ante cualquier anomalía (hash distinto, estructura distinta).

Destino previsto de instalación (futuro, NO realizado aquí):
`/lib/firmware/qcom/sm6125/modem.mdt` + `modem.bXX` — ruta que el driver
PAS (`qcom_mdt_load`) espera con el `fw_name` "modem" (ver
`kernel-driver-flow.md`, punto 2).

## 5. Seguridad y licencia

- `NON-HLOS.bin`, `modem.mdt`, `modem.bXX` son firmware propietario
  Qualcomm/Xiaomi. **NO redistribuible** (AGENTS.md §1, §10). Uso SOLO
  privado para este dispositivo.
- El script `tools/private/prepare-sm6125-modem-firmware.sh`:
  - Requiere `--i-understand-private-firmware` obligatorio.
  - Modo `--dry-run` por defecto; `--run` solo con autorización.
  - Valida que input y output estén dentro de `local-private/`.
  - Calcula SHA-256 del input y registra hashes de salida.
  - `bash -n` OK y ShellCheck en CI de calidad (00-quality).
  - **NO se ejecuta en esta misión**; se deja listo y revisado.

## 6. Estado

- `modem.mdt` y segmentos: **`unavailable` / `unextracted`** (se mantienen
  dentro de NON-HLOS.bin, sin extraer). Extracción requiere autorización
  física explícita posterior.
- Procedimiento: `source-available` (script revisado, dry-run validado).
- Sin prueba física. Nada se publica.

## 7. Puerta de fase M10

- Script presente y validado (`bash -n`, ShellCheck, dry-run OK): **PASS**
- Requisito `--i-understand-private-firmware` probado (falla sin él): **PASS**
- Restricción a `local-private/` implementada y comprobable: **PASS**
- `modem.mdt` sigue sin extraer (requisito de la misión): **CUMPLIDO**

Consecuencia de misión: BUILD-READY para kernel/DT/rootfs packaging es
posible (M9-PASS, M10-PASS), pero **PHYSICAL-TEST queda BLOCKED** hasta la
extracción autorizada del firmware del modem.
