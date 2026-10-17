# pmaports-overlay — cambios locales sobre pmaports

Overlay que se aplica al árbol de pmaports en GitHub Actions cuando el
workflow `25-build-pmos-laurel` se lanza con `apply_overlay=true`
(`scripts/build-pmos-laurel.sh --apply-overlay`). No se aplica por defecto: la
base se construye con pmaports tal cual.

## Origen

Todo el contenido procede del recetario de referencia
`philipplinux/mia3-postmarketos` (commit `0b5f6221919b1bab641f9d07be6849ce1c661f5a`,
2026-10-16), registrado en `sources.lock.json` como
`philipplinux-mia3-postmarketos`. El repo de origen no declara licencia
(`NOASSERTION`), así que aquí se conserva la autoría y se usa solo como
referencia técnica; no se relicencia.

pmaports upstream fija el commit `ec98dddc8d525c874603a8e91ae6113d2b0c66d1`
(`sources.lock.json: pmaports`).

## Contenido

| Fichero | Qué es | Estado |
|---|---|---|
| `pmaports-ec98ddd.diff` | Diff contra pmaports@ec98ddd: sube `pkgrel` del kernel (0→5) y del device (0→2) y añade los 3 parches DTS + las dependencias `firmware-xiaomi-laurel-cdsp`, `qrtr`, `rmtfs`, `tqftpserv` | downstream-only |
| `linux-nura-qcom-sm61x5/0001-*wcn3990-wifi.patch` | DTS: añade nodo Wi-Fi WCN3990 (`arm64: dts: qcom: sm6125`) | downstream-only (candidato upstream) |
| `linux-nura-qcom-sm61x5/0002-*enable-cdsp.patch` | DTS: habilita el CDSP remoteproc | downstream-only |
| `linux-nura-qcom-sm61x5/0003-*enable-mpss-for-wifi.patch` | DTS: habilita MPSS + SMP2P + `rmtfs_mem` (el servicio `msm/modem/wlan_pd` corre en el modem DSP) | downstream-only |
| `dts/k7.dts` | Device Tree de laurel con cpufreq, Bluetooth, IR y Wi-Fi; sustituye el DTB que instala el kernel. El `.dts` es un DTB decompilado con phandles crudos: solo válido para este build. `k7.dtb` **no** se versiona (`*.dtb` está en la lista negra del audit): se compila aquí con `dtc` | local-workaround |
| `firmware-xiaomi-laurel-cdsp/APKBUILD` | Paquete de firmware (modem/CDSP/ADSP/ath10k/BT/zap). Los blobs NO están aquí: se extraen del ROM en la CI | downstream-only |
| `firmware/extract-firmware.sh` + `ath10k-bdenc.py` | Extractor de blobs desde las particiones stock (o desde el ROM) y encoder `board-2.bin` de ath10k | upstream-tool |
| `device/*` | Copia de los ficheros de `device-xiaomi-laurel` y `linux-nura-qcom-sm61x5` de pmaports@ec98ddd, solo para referencia/contraste | referencia |

## Reglas

- Los parches se aplican con `git apply` sobre un pmaports limpio en el commit
  fijado; si alguno no aplica, el build debe fallar (no se ignora en silencio).
- El firmware propietario se mantiene fuera de este árbol y solo entra en el
  artefacto privado de CI (AGENTS.md §1: no se publica firmware sin licencia).
- `k7.dtb` **no** se versiona: `*.dtb` está en la lista negra de
  `scripts/audit-public-repository.sh`. Se genera desde `k7.dts` con `dtc`
  durante el build.
