# Workflow 19 — build Linux 6.1 WCN3990 v3 (MPSS enabled)

Estado: `configured-ci-ready` (sin build todavía).
Artefacto objetivo: `boot-linux61-wcn3990-v3`.
Base: main `364c167d1155cb044f2f5ea7ed9a2e20a3e36fee` (merge PR #8).

---

## 1. Objetivo

Construir un boot Linux 6.1 con la cadena WCN3990 v3 completa:

- `0001` WCN3990 SNOC (wifi@c800000, v1 conservada);
- `0002` infraestructura MPSS/GLINK/SMP2P (remoteproc@6080000 en dtsi,
  `status = "disabled"`);
- `0003` enable de placa `&remoteproc_mpss { status = "okay"; }` (v3).

El DTB v3 queda con `remoteproc_mpss` efectivo `okay`. El firmware del
modem NO está en el rootfs y el userspace NO está integrado: el artefacto
solo valida DTB/empaquetado y **NO debe bootearse** hasta autorización
(FASE 8) con firmware privado + userspace instalados.

## 2. Diseño (diferencias vs workflow 18)

Workflow `19-build-linux61-wcn3990-v3.yml`, disparo manual
(`workflow_dispatch`) con inputs `rootfs_run_id` (default
`31760183247`) y `upload_artifacts` (default true). Permisos
`contents: read` + `actions: read`; sin secrets, sin write, sin
push/pull_request/schedule. Concurrency `linux61-wcn3990-v3`.

Cadena de build idéntica a 18 (validada en v2) con estos cambios:

1. Aplica `0003` después de `0001` y `0002`, cada uno precedido de
   `git apply --check`.
2. Gate de fuente v3: el parche 0003 debe contener exactamente un
   override `&remoteproc_mpss` con `status = "okay"`; el board resultante
   debe tener exactamente un override (rechaza doble aplicación).
3. Validación de fuente con `--expect-mpss okay`.
4. El DTB v3 (`new-v3.dtb`) se ensambla al Image.gz puro y el boot final
   se separa estructuralmente (`split-appended-dtb.py`): el payload debe
   ser exactamente `Image.gz + DTB v3` único (rechaza doble DTB y DTB
   histórico reutilizado). `final-v3.dtb` byte-idéntico a `new-v3.dtb`;
   `kernel.gz` del boot byte-idéntico al fuente.
5. `dtc` decompila el DTB final a `final-v3.dts` y se valida con:
   - `validate-mpss-v2-final.py --dts final-v3.dts --expect-mpss okay`;
   - `verify-wcn3990-mpss-v2.sh --final-dts final-v3.dts --expect-mpss okay`.
6. Manifest v3 con campos explícitos y gates bloqueantes (ver abajo).
7. Artefactos: `boot-linux61-wcn3990-v3` (7 días) y
   `linux61-wcn3990-v3-logs` (3 días).

## 3. Gates de fuente (workflow falla si falta)

- `wifi@c800000` con `compatible = "qcom,wcn3990-wifi"`, `status = "okay"`,
  memory-region WLAN, supplies y IRQ CE 358–369 (0001).
- `remoteproc@6080000` con `compatible = "qcom,sm8150-mpss-pas"`,
  `memory-region = <&modem_mem>`, exactamente un power-domain
  `SM6125_VDDCX`, sin power-domain-names, seis interrupt-names exactos,
  seis interrupts-extended, glink-edge, smp2p-mpss con entries
  master-kernel/slave-kernel/wlan (0002).
- 0003 aplicado: board override presente exactamente una vez con
  `status = "okay"`; ningún segundo override; `remoteproc_mpss` efectivo
  `okay`. El modo `disabled` no se usa en workflow 19.

## 4. Manifest v3

```json
{
  "artifact": "boot-linux61-wcn3990-v3",
  "source_rootfs_run": "31760183247",
  "kernel_commit": "77de535b8dbd8f483b5802c8937cb714bab5b485",
  "patches": [
    "0001-dts-laurel-wcn3990-first-probe",
    "0002-dts-sm6125-add-mpss-transport-v2",
    "0003-dts-laurel-enable-mpss"
  ],
  "cmdline": "clk_ignore_unused consoleblank=0",
  "mpss_status": "okay",
  "boot_enabled": true,
  "firmware_in_rootfs": false,
  "userspace_mpss_ready": false,
  "physical_status": "boot-untested",
  "status": "configured-ci-ready",
  "risk": "MPSS enabled without firmware; do not boot until private firmware and userspace are installed"
}
```

Gates bloqueantes en el workflow (`jq -e`): `firmware_in_rootfs == false`,
`userspace_mpss_ready == false`, `mpss_status == "okay"`,
`physical_status == "boot-untested"`, `boot_enabled == true`.

## 5. Pruebas locales (FASE 8)

Ejecutadas antes del commit:

- YAML válido (todos los workflows, incluido 19).
- `bash -n`/`shellcheck -x` sobre el wrapper (sin cambios).
- `py_compile` y unittest completo: **154 tests OK**.
- Tests nuevos:
  - `tests/test_mpss_v3_source.py`: wrapper en modo fuente con fixtures
    (P1 v3 okay, P2 v2 disabled, N1 falta 0003, N2 doble override,
    N3 status okay con expect disabled, N4 override sin okay).
  - `tests/test_workflow19_v3.py`: estructura/seguridad del workflow 19
    (solo workflow_dispatch, permisos mínimos, sin secretos/write,
    acciones por SHA, parches en orden, `--expect-mpss okay`, manifest,
    artefactos, sin comandos destructivos).
- `git diff --check` limpio y auditoría pública superada.
- Validadores v3 positivos/negativos verificados directamente.

## 6. Estado

El commit de este reporte incluye únicamente:

- `.github/workflows/19-build-linux61-wcn3990-v3.yml`;
- `tests/test_mpss_v3_source.py`;
- `tests/test_workflow19_v3.py`;
- fixtures `tests/fixtures/mpss-v3-source/` (sm6125.dtsi, board v3, board v2);
- este reporte.

No modifica 0001/0002/0003, firmware, rootfs, workflow 18 ni la hardware
matrix. Tras merge y 00-quality se dispara el workflow 19 una sola vez
con `rootfs_run_id=31760183247`.