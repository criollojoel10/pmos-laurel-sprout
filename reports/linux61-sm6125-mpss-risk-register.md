# Registro de riesgos MPSS — v2 WCN3990 (Linux 6.1)

Fecha: 2026-08-13. Riesgos de la prueba física v2 (habilitar MPSS +
transporte para la WCN3990), con estados de AGENTS.md y procedimiento de
rollback. Esta misión NO ejecuta la prueba; solo registra.

## Precondiciones de respaldo (verificadas)

`local-private/backups/2026-08-09/manifest.json` — respaldo COMPLETO:
- `boot_a/b`, `dtbo_a/b`, `vbmeta_a/b`, `persist`, `modemst1/2`, `fsg`,
  `fsc`, `modem_a`, `dsp_a` con SHA-256 registrados (dd directo desde
  `/dev/block/...` en e/OS con root Magisk, slot actual `a`, unlocked).
- Referencias stock y e/OS de boot/dtbo/vbmeta con hashes.
- Metadatos fastboot sanitizados en `device-metadata/fastboot-sanitized.json`.

→ **AGENTS.md §7 SATISFECHO** para la prueba física v2 (condicional a
autorización explícita y a la FASE 8).

## Matriz de riesgos

| # | riesgo | severidad | probabilidad | mitigación | estado |
|---|--------|-----------|--------------|------------|--------|
| 1 | Falta `modem.mdt` (firmware MPSS) | **Crítica** | Alta (confirmado ausente) | Extraer de NON-HLOS.bin (local-private) con autorización; si no → NO-GO | `blocked` |
| 2 | Compatible PAS ausente en fork 6.1 (sm6115/sm6125-pas) | Alta | Segura (confirmado ausente) | Usar `qcom,sm8150-mpss-pas` (mismos params) o parche downstream en v2 | `configured` (diseño) |
| 3 | power-domain con names "cx"/"mss" mismatch | Alta | Evitable | Usar UN solo `<&rpmpd SM6125_VDDCX>` (rama single-domain) | `configured` (diseño) |
| 4 | faltan smp2p-mpss / glink-edge / IRQs | Alta | Evitable | Replicar QCM2290 v6.6 con valores SM6125 (M3) | `configured` (diseño) |
| 5 | QRTR/userspace ausente (qrtr-ns, pd-mapper, rmtfs) | Media | Alta (rootfs sin paquetes) | Instalar `qrtr`, `pd-mapper`, `rmtfs` de aports con autorización | `blocked` (rootfs) |
| 6 | firmware WCN3990 real ausente (stub 60 B) | Alta | Confirmada | Descargar firmware real de linux-firmware fijado | `blocked` |
| 7 | tqftpserv/pd-mapper requieren config SM6125 | Media | Media | Verificar entradas upstream; usar referencia sm7125 | `boot-untested` |
| 8 | SID iommus wifi divergente (0x1a0 vs 0x80) | Baja | Baja | La v1 usa ruta TrustZone sin iommus; MPSS no usa SID wifi | `configured` |
| 9 | Bootloop / no boot tras cambiar DT | Alta | Baja (boot_b intacto) | Arrancar slot `_b` (baseline), restaurar boot_a si es necesario | respaldado |
| 10 | Escritura accidental de particiones de radio | Crítica | Muy baja (misión read-only) | Sin fastboot/adb en esta misión; recovery doc | respaldado |
| 11 | Reinicio/remoteproc start sin autorización | Alta | Evitable | Gates de la v2; FASE 8 detiene | `configured` |
| 12 | Regresión de WCN3990 v1 (probe ok) al tocar DTS | Media | Media | Conservar nodo v1; MPSS es aditivo, no sustitutivo | `boot-untested` |

## Procedimiento de rollback (prueba física futura, autorizada)

1. Detectar no-boot: mantener Power+VolDown → Fastboot.
2. `fastboot getvar current-slot` (revisar slot activo).
3. `fastboot flash boot_<slot> local-private/backups/2026-08-09/boot_<slot>.img`
   (o boot-baseline v1 `boot-linux61-baseline-consoleblank0.img`).
4. Si se tocó dtbo/vbmeta: `fastboot flash dtbo_<slot>` / `flash vbmeta_<slot>`
   desde respaldo (NO tocar persist/modemst/fsg/fsc).
5. Verificar boot con la imagen console v1.
6. NUNCA flashear `persist`, `modemst1/2`, `fsg`, `fsc` sin caso concreto
   (identidad de radio).

## Gates para la prueba (v2, en FASE 8)

- G0: autorización explícita e inmediata.
- G1: respaldo verificado (ya OK).
- G2: firmware modem.mdt + WCN3990 real presentes.
- G3: paquetes userspace instalados y orden de servicios documentado.
- G4: artefacto boot v2 con hash y tamaño ≤ límite boot (0x4000000).
- G5: slot actual y particiones a modificar listadas.
- G6: prueba menos destructiva recomendada (boot temporal `fastboot boot`).

## Conclusión M6

Riesgos 1 y 6 (firmware) son **bloqueantes confirmados**; el resto son de
configuración/diseño con mitigación conocida (M3). Con respaldos completos y
sin operación física en esta misión, no se expone el dispositivo. El
veredicto GO/NO-GO de M8 queda condicionado a resolver firmware y a la
autorización FASE 8.

## Fuentes

- `local-private/backups/2026-08-09/manifest.json` + `SHA256SUMS`
- `device-metadata/fastboot-sanitized.json`
- `docs/RECOVERY.md`
- `local-private/linux61-baseline-31563265029/boot-linux61-baseline-consoleblank0.img`
