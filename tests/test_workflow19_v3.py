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
PATCH3 = os.path.join(ROOT, "patches", "kernel-61",
                      "0003-dts-laurel-enable-mpss.patch")
BOARD_V3 = os.path.join(ROOT, "tests", "fixtures", "mpss-v3-source",
                        "sm6125-xiaomi-laurel_sprout.dts")
BOARD_V2 = os.path.join(ROOT, "tests", "fixtures", "mpss-v3-source",
                        "sm6125-xiaomi-laurel_sprout-v2.dts")

# Replica fiel del gate de fuente del workflow 19 (solo lineas ANNADIDAS
# con prefijo '+' del diff). El patron viejo (sin '+') no contaba el
# override en el patch y abortaba falsamente (run 31834844873).
P3_OVERRIDE_RE = re.compile(r"^\+[ \t]*&remoteproc_mpss[ \t]*\{")
P3_OKAY_RE = re.compile(r'^\+[ \t]*status[ \t]*=[ \t]*"okay";')
BOARD_OVERRIDE_RE = re.compile(r"^[ \t]*&remoteproc_mpss[ \t]*\{")
LEGACY_P3_OVERRIDE_RE = re.compile(r"^[ \t]*&remoteproc_mpss[ \t]*\{")

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


class Workflow19PatchGateTest(unittest.TestCase):
    """Gate de fuente v3 sobre el patch real 0003 y el board (regresión)."""

    @classmethod
    def setUpClass(cls):
        with open(PATCH3, encoding="utf-8") as fh:
            cls.patch3 = fh.read()
        with open(BOARD_V3, encoding="utf-8") as fh:
            cls.board_v3 = fh.read()
        with open(BOARD_V2, encoding="utf-8") as fh:
            cls.board_v2 = fh.read()
        with open(WF19, encoding="utf-8") as fh:
            cls.wf19 = fh.read()

    def _added_overrides(self, text):
        return sum(1 for ln in text.splitlines()
                   if P3_OVERRIDE_RE.match(ln))

    def _added_okays(self, text):
        return sum(1 for ln in text.splitlines() if P3_OKAY_RE.match(ln))

    def _board_overrides(self, text):
        return sum(1 for ln in text.splitlines()
                   if BOARD_OVERRIDE_RE.match(ln))

    # 1. patch real 0003 -> override=1, status=1, PASS
    def test_1_patch_real_override_y_status_okay(self):
        self.assertEqual(self._added_overrides(self.patch3), 1)
        self.assertEqual(self._added_okays(self.patch3), 1)

    # 2. patron viejo sobre patch real -> 0 (reproduccion del bug 31834844873)
    def test_2_patron_viejo_reproduccion_bug(self):
        self.assertEqual(sum(1 for ln in self.patch3.splitlines()
                             if LEGACY_P3_OVERRIDE_RE.match(ln)), 0)

    # 3. patch sin prefijo '+' -> no cuenta (debe fallar el gate)
    def test_3_sin_prefijo_mas_no_cuenta(self):
        fake = "+&remoteproc_mpss {\n+    status = \"okay\";\n"
        stripped = fake.replace("+", "", 1).replace("\n+", "\n", 1)
        self.assertEqual(self._added_overrides(stripped), 0)

    # 4. commit message con &remoteproc_mpss -> no cuenta
    def test_4_commit_message_no_cuenta(self):
        fake = "enablement flips &remoteproc_mpss to \"okay\"\n" \
               "remoteproc_mpss added with status = \"disabled\"\n"
        self.assertEqual(self._added_overrides(fake), 0)
        self.assertEqual(self._added_okays(fake), 0)

    # 5. linea eliminada '-' -> no cuenta
    def test_5_linea_eliminada_no_cuenta(self):
        fake = "-&remoteproc_mpss {\n-    status = \"okay\";\n"
        self.assertEqual(self._added_overrides(fake), 0)
        self.assertEqual(self._added_okays(fake), 0)

    # 6. dos overrides anadidos -> FAIL
    def test_6_dos_overrides_fail(self):
        fake = self.patch3 + "\n+&remoteproc_mpss {\n+    status = \"okay\";\n"
        self.assertEqual(self._added_overrides(fake), 2)

    # 7. dos status okay anadidos -> FAIL
    def test_7_dos_status_okay_fail(self):
        fake = self.patch3 + "\n+\tstatus = \"okay\";\n"
        self.assertEqual(self._added_okays(fake), 2)

    # 8. override anadido con status disabled -> FAIL
    def test_8_override_con_disabled_fail(self):
        fake = ("+&remoteproc_mpss {\n"
                "+    status = \"disabled\";\n+};\n")
        self.assertEqual(self._added_overrides(fake), 1)
        self.assertEqual(self._added_okays(fake), 0)

    # 9. board resultante con un override -> PASS
    def test_9_board_v3_un_override(self):
        self.assertEqual(self._board_overrides(self.board_v3), 1)

    # 10. board resultante con dos overrides -> FAIL
    def test_10_board_dos_overrides_fail(self):
        fake = self.board_v3 + "\n&remoteproc_mpss {\n\tstatus = \"okay\";\n};\n"
        self.assertEqual(self._board_overrides(fake), 2)

    # el workflow 19 usa el nuevo patron '+' para el patch y mantiene el
    # gate del board resultante
    def test_workflow_usa_patron_nuevo_y_no_el_viejo(self):
        self.assertIn("P3_OVERRIDE_COUNT", self.wf19)
        self.assertIn("P3_OKAY_COUNT", self.wf19)
        self.assertIn("BOARD_OVERRIDE_COUNT", self.wf19)
        self.assertIn("^\\+", self.wf19)
        self.assertNotIn("grep -c '^[[:space:]]*&remoteproc_mpss", self.wf19)


if __name__ == "__main__":
    unittest.main()