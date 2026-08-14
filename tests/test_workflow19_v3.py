#!/usr/bin/env python3
#
# Licencia: GPL-3.0-or-later
#
# tests/test_workflow19_v3.py
#
# Pruebas de estructura y seguridad de
# .github/workflows/19-build-linux61-wcn3990-v3.yml (FASE 2/4/6/9 de la
# misión workflow 19): solo workflow_dispatch, permisos minimos, sin secretos,
# sin write, sin push/pull_request/schedule, acciones fijadas por SHA,
# parches 0001/0002/0003 en orden, --expect-mpss okay en fuente y final,
# gates de manifest v3 (firmware_in_rootfs=false, userspace_mpss_ready=false,
# mpss_status=okay, physical_status=boot-untested, boot_enabled=true) y
# ausencia de comandos destructivos/firmware/rootfs/local-private.
#
# Ejecutar:  python3 -m unittest discover -s tests -v

import os
import re
import unittest

import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WF19 = os.path.join(ROOT, ".github", "workflows",
                    "19-build-linux61-wcn3990-v3.yml")

FORBIDDEN_PATTERNS = (
    "local-private",
    "modem.mdt",
    "modem.b",        # modem.b00.. modem.b29
    "NON-HLOS",
    "wlanmdsp",
    "firmware-5.bin",
    "board-2.bin",
    "persist",
    "modemst1",
    "modemst2",
    "fsg",
    "fsc",
    "secrets.",
    "write-permissions",
)

# Comandos destructivos o de dispositivo REALES (ejecutables), no menciones
# en comentarios (p.ej. "NO flashea"). Se buscan solo en lineas que no son
# comentarios del workflow.
DESTRUCTIVE_CMDS = re.compile(
    r"\b(fastboot|adb)\b.*\b(boot|flash|erase|format|set_active|reboot|"
    r"continue|update|oem|flashing|-w|push|pull|shell|install)\b")

EXTERNAL_ACTION_SHA = re.compile(r"uses: [^@\s]+@[0-9a-f]{40}")


def _load_wf_yaml(path):
    """safe_load tratando 'on' como string (GitHub Actions usa YAML 1.2)."""
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    # la primera ocurrencia de "on:" es la clave top-level; PyYAML (YAML 1.1)
    # la convierte a booleano True; la entrecomillamos para evitar el conflicto.
    text = text.replace("on:", '"on":', 1)
    return yaml.safe_load(text)


class Workflow19Test(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = _load_wf_yaml(WF19)
        with open(WF19, encoding="utf-8") as fh:
            cls.raw = fh.read()

    def test_yaml_valido(self):
        self.assertIsInstance(self.data, dict)

    def test_solo_workflow_dispatch(self):
        self.assertEqual(list(self.data.get("on", {}).keys()),
                         ["workflow_dispatch"])
        on = self.data["on"]["workflow_dispatch"]
        inputs = on.get("inputs", {})
        self.assertEqual(inputs["rootfs_run_id"]["required"], True)
        self.assertEqual(inputs["rootfs_run_id"]["default"], "31760183247")
        self.assertEqual(inputs["upload_artifacts"]["type"], "boolean")
        self.assertEqual(inputs["upload_artifacts"]["default"], True)

    def test_permisos_minimos(self):
        self.assertEqual(self.data.get("permissions"),
                         {"contents": "read", "actions": "read"})

    def test_no_secrets_ni_write(self):
        self.assertNotIn("secrets", self.raw)
        self.assertNotIn("contents: write", self.raw)
        # "pull_request:" como disparador (clave YAML), no como palabra suelta
        # en comentarios descriptivos.
        self.assertNotRegex(self.raw, r"(?m)^\s*pull_request:")
        self.assertNotIn("schedule:", self.raw)
        self.assertNotIn("release:", self.raw)

    def test_concurrency(self):
        self.assertEqual(self.data["concurrency"]["group"], "linux61-wcn3990-v3")
        self.assertEqual(self.data["concurrency"]["cancel-in-progress"], True)

    def test_parches_0001_0002_0003_en_orden(self):
        # deben aparecer los tres y 0003 despues de 0002
        idx1 = self.raw.index("0001-dts-laurel-wcn3990-first-probe.patch")
        idx2 = self.raw.index("0002-dts-sm6125-add-mpss-transport-v2.patch")
        idx3 = self.raw.index("0003-dts-laurel-enable-mpss.patch")
        self.assertLess(idx1, idx2)
        self.assertLess(idx2, idx3)

    def test_apply_check_antes_de_cada_parche(self):
        self.assertGreaterEqual(self.raw.count("apply --check"), 3)

    def test_expect_mpss_okay_en_fuente_y_final(self):
        # fuente tras parches
        self.assertIn("--tree kernel61 --expect-mpss okay", self.raw)
        # final decompilado (python y wrapper)
        self.assertIn("--expect-mpss okay", self.raw)

    def test_no_usa_expect_mpss_disabled(self):
        self.assertNotIn("--expect-mpss disabled", self.raw)

    def test_manifest_v3_bloqueante(self):
        self.assertIn("firmware_in_rootfs", self.raw)
        self.assertIn("userspace_mpss_ready", self.raw)
        self.assertIn('mpss_status:"okay"', self.raw.replace(" ", ""))
        self.assertIn("physical_status:\"boot-untested\"",
                      self.raw.replace(" ", ""))
        self.assertIn("boot_enabled:true", self.raw.replace(" ", ""))
        # gates bloqueantes explícitos
        self.assertIn("jq -e '.firmware_in_rootfs == false'", self.raw)
        self.assertIn("jq -e '.userspace_mpss_ready == false'", self.raw)
        self.assertIn("jq -e '.mpss_status == \"okay\"'", self.raw)
        self.assertIn("jq -e '.physical_status == \"boot-untested\"'", self.raw)

    def test_cmdline_exacta(self):
        self.assertIn("clk_ignore_unused consoleblank=0", self.raw)

    def test_sin_contenido_prohibido(self):
        for pat in FORBIDDEN_PATTERNS:
            self.assertNotIn(pat, self.raw, "patrón prohibido: %s" % pat)
        # comandos destructivos/de dispositivo en lineas ejecutables
        # (no comentarios: "NO flashea" es descriptivo, no un comando)
        for lineno, line in enumerate(self.raw.splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            if "run:" in line or "sudo " in line or stripped.startswith("-"):
                self.assertNotRegex(
                    line, DESTRUCTIVE_CMDS,
                    "comando destructivo/de dispositivo en línea %d" % lineno)

    def test_acciones_externas_fijadas_por_sha(self):
        for line in self.raw.splitlines():
            line = line.strip()
            if line.startswith("uses:"):
                self.assertRegex(line, EXTERNAL_ACTION_SHA,
                                 "acción sin SHA fijado: %s" % line)

    def test_artefactos_v3(self):
        self.assertIn("boot-linux61-wcn3990-v3", self.raw)
        self.assertIn("linux61-wcn3990-v3-logs", self.raw)
        self.assertIn("retention-days: 7", self.raw)
        self.assertIn("retention-days: 3", self.raw)

    def test_job_nombre(self):
        job = self.data["jobs"]["build"]
        self.assertEqual(job["name"], "WCN3990 v3 DTB+boot (MPSS enabled, firmware absent)")
        self.assertEqual(job["timeout-minutes"], 90)

    def test_no_reutiliza_dtb_historico_ni_doble_dtb(self):
        # el DTB final debe ser byte-identico al construido (no al historico)
        self.assertIn("final-v3.dtb", self.raw)
        self.assertIn("cmp /tmp/boot-out/final-v3.dtb /tmp/new-v3.dtb", self.raw)
        self.assertIn("historical-source.dtb", self.raw)
        self.assertIn("split-appended-dtb.py", self.raw)


if __name__ == "__main__":
    unittest.main()