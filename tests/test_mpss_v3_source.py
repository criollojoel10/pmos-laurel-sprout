#!/usr/bin/env python3
#
# Licencia: GPL-3.0-or-later
#
# tests/test_mpss_v3_source.py
#
# Pruebas del modo --tree (fuente) de scripts/verify-wcn3990-mpss-v2.sh para
# la variante v3 (remoteproc_mpss habilitado por override de placa 0003).
#
# Cubre los gates de FASE 4 de la misión workflow 19:
#   P1 v3 okay PASS  (board con override status = "okay");
#   P2 v2 disabled PASS (board sin override);
#   N1 falta 0003 (board sin override + --expect-mpss okay) -> FAIL;
#   N2 0003 aplicado dos veces (dos overrides + --expect-mpss okay) -> FAIL;
#   N3 status "okay" con --expect-mpss disabled -> FAIL;
#   N4 override no tiene status "okay" + --expect-mpss okay -> FAIL.
#
# Ejecutar:  python3 -m unittest discover -s tests -v

import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WRAPPER = os.path.join(ROOT, "scripts", "verify-wcn3990-mpss-v2.sh")
FIX_DIR = os.path.join(ROOT, "tests", "fixtures", "mpss-v3-source")
DTSI = "sm6125.dtsi"
BOARD_V3 = "sm6125-xiaomi-laurel_sprout.dts"
BOARD_V2 = "sm6125-xiaomi-laurel_sprout-v2.dts"


def _make_tree(tmp, board_name):
    """Copia los fixtures de fuente a un árbol kernel mínimo (dts + dtsi)."""
    dts_dir = os.path.join(tmp, "arch", "arm64", "boot", "dts", "qcom")
    os.makedirs(dts_dir, exist_ok=True)
    shutil.copy(os.path.join(FIX_DIR, DTSI), os.path.join(dts_dir, DTSI))
    shutil.copy(os.path.join(FIX_DIR, board_name),
                os.path.join(dts_dir, "sm6125-xiaomi-laurel_sprout.dts"))
    return tmp


def _run_wrapper(tree, expect_mpss):
    out = tempfile.mkdtemp(prefix="mpssv3-")
    proc = subprocess.run(
        ["bash", WRAPPER, "--tree", tree, "--expect-mpss", expect_mpss,
         "--out", out],
        capture_output=True, text=True)
    return proc.returncode, proc.stdout + proc.stderr


class MpssV3SourceWrapperTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="mpssv3-tree-")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_p1_v3_okay_passes(self):
        tree = _make_tree(self.tmp, BOARD_V3)
        rc, log = _run_wrapper(tree, "okay")
        self.assertEqual(rc, 0, "v3 debería PASS\n%s" % log)
        self.assertIn("board override de remoteproc_mpss presente (v3)", log)
        self.assertIn('override status = "okay"', log)
        self.assertNotIn("FAIL", log.replace("PASS", ""))

    def test_p2_v2_disabled_passes(self):
        tree = _make_tree(self.tmp, BOARD_V2)
        rc, log = _run_wrapper(tree, "disabled")
        self.assertEqual(rc, 0, "v2 debería PASS\n%s" % log)
        self.assertIn("board sin override de remoteproc_mpss", log)
        self.assertNotIn("FAIL", log.replace("PASS", ""))

    def test_n1_falta_0003_expect_okay_fails(self):
        # board v2 (sin override) + --expect-mpss okay => falta el enable
        tree = _make_tree(self.tmp, BOARD_V2)
        rc, log = _run_wrapper(tree, "okay")
        self.assertNotEqual(rc, 0, "debería FAIL por falta de override 0003")
        self.assertIn("board override de remoteproc_mpss presente (v3)", log)
        self.assertIn("FAIL", log)

    def test_n2_doble_override_fails(self):
        # board v3 con el override duplicado => gate "maximo un override" FAIL
        tree = _make_tree(self.tmp, BOARD_V3)
        dts = os.path.join(tree, "arch", "arm64", "boot", "dts", "qcom",
                           "sm6125-xiaomi-laurel_sprout.dts")
        with open(dts, encoding="utf-8") as fh:
            text = fh.read()
        dup = text.replace("&remoteproc_mpss {", "&remoteproc_mpss {", 1) \
            + "\n&remoteproc_mpss {\n\tstatus = \"okay\";\n};\n"
        with open(dts, "w", encoding="utf-8") as fh:
            fh.write(dup)
        rc, log = _run_wrapper(tree, "okay")
        self.assertNotEqual(rc, 0, "debería FAIL por override duplicado")
        self.assertIn("maximo un override de remoteproc_mpss en el board", log)
        self.assertIn("FAIL", log)

    def test_n3_status_okay_expect_disabled_fails(self):
        # board v3 (override okay) pero --expect-mpss disabled => FAIL
        tree = _make_tree(self.tmp, BOARD_V3)
        rc, log = _run_wrapper(tree, "disabled")
        self.assertNotEqual(rc, 0, "v3 con expect disabled debería FAIL")
        self.assertIn('override del board no contiene status = "okay"', log)
        self.assertIn("FAIL", log)

    def test_n4_override_sin_okay_fails(self):
        # override presente pero con status distinto de "okay"
        tree = _make_tree(self.tmp, BOARD_V3)
        dts = os.path.join(tree, "arch", "arm64", "boot", "dts", "qcom",
                           "sm6125-xiaomi-laurel_sprout.dts")
        with open(dts, encoding="utf-8") as fh:
            text = fh.read()
        text = text.replace('\tstatus = "okay";\n};',
                            '\tstatus = "disabled";\n};', 1)
        with open(dts, "w", encoding="utf-8") as fh:
            fh.write(text)
        rc, log = _run_wrapper(tree, "okay")
        self.assertNotEqual(rc, 0, "override sin okay debería FAIL")
        self.assertIn('override status = "okay"', log)
        self.assertIn("FAIL", log)


if __name__ == "__main__":
    unittest.main()