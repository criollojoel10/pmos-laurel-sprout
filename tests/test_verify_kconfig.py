#!/usr/bin/env python3
#
# Licencia: GPL-3.0-or-later
#
# tests/test_verify_kconfig.py
#
# Pruebas de scripts/verify-kconfig.sh:
#   - símbolo existente en Kconfig con valor exacto =y  -> OK
#   - degradación silenciosa pedido =y resultado =m     -> MISMATCH
#   - pedido =m resultado =n                            -> MISMATCH
#   - pedido no-set (ausente) y resultado =y            -> MISMATCH
#   - símbolo inexistente en el árbol Kconfig           -> MISSING
#   - string (CONFIG_X="...") que coincide             -> OK
#   - deny-list: max=m y resultado =y                   -> violación
#   - deny-list: no-set y resultado =y                  -> violación
#   - --fail-missing / --fail-deny provocan exit != 0
#   - sin --fail-*, las violaciones se reportan pero no fallan
#
# Ejecutar:  python3 -m unittest discover -s tests -v

import os
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERIFY = os.path.join(ROOT, "scripts", "verify-kconfig.sh")


def make_tree(dirpath):
    """Árbol Kconfig sintético con símbolos DRM_MSM, BT, STR_OPT y DENY."""
    os.makedirs(dirpath, exist_ok=True)
    kconfig = os.path.join(dirpath, "Kconfig")
    with open(kconfig, "w") as f:
        f.write("""mainmenu "test"

config DRM_MSM
\ttristate "MSM DRM"
\tdepends on DRM

config DRM
\ttristate "DRM"

config BT
\ttristate "Bluetooth"

config STR_OPT
\tstring "a string option"

config DENY_ME
\ttristate "deny me"

config TURN_OFF
\ttristate "turn off"
""")
    return dirpath


class VerifyKconfigTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = self.tmp.name
        self.tree = make_tree(os.path.join(self.dir, "tree"))
        self.frag = os.path.join(self.dir, "test.fragment")
        self.deny = os.path.join(self.dir, "deny.fragment")
        self.cfg = os.path.join(self.dir, ".config")

    def tearDown(self):
        self.tmp.cleanup()

    def write_frag(self, content):
        with open(self.frag, "w") as f:
            f.write(content)

    def write_deny(self, content):
        with open(self.deny, "w") as f:
            f.write(content)

    def write_cfg(self, content):
        with open(self.cfg, "w") as f:
            f.write(content)

    def run_verify(self, extra_args, expect_fail=False):
        cmd = [VERIFY, "--config", self.cfg, "--tree", self.tree,
               "--fragments", self.frag] + extra_args
        proc = subprocess.run(cmd, capture_output=True, text=True)
        combined = proc.stdout + proc.stderr
        if expect_fail:
            self.assertNotEqual(proc.returncode, 0,
                                f"debería fallar\n{combined}")
        else:
            self.assertEqual(proc.returncode, 0, f"{combined}")
        return combined

    def test_exact_y_ok(self):
        self.write_frag("CONFIG_DRM=y\nCONFIG_DRM_MSM=y\n")
        self.write_cfg("CONFIG_DRM=y\nCONFIG_DRM_MSM=y\n")
        out = self.run_verify([])
        self.assertIn("OK: CONFIG_DRM_MSM =y", out)

    def test_silent_degradation_y_to_m_detected(self):
        self.write_frag("CONFIG_DRM_MSM=y\n")
        self.write_cfg("CONFIG_DRM_MSM=m\n")
        out = self.run_verify([])
        self.assertIn("MISMATCH", out)
        self.assertIn("esperado =y, resultado =m", out)

    def test_degradation_fails_with_fail_missing(self):
        self.write_frag("CONFIG_DRM_MSM=y\n")
        self.write_cfg("CONFIG_DRM_MSM=m\n")
        self.run_verify(["--fail-missing"], expect_fail=True)

    def test_m_to_n_detected(self):
        self.write_frag("CONFIG_BT=m\n")
        self.write_cfg("CONFIG_DRM=y\n")
        out = self.run_verify([])
        self.assertIn("MISMATCH: CONFIG_BT esperado =m, resultado =n", out)

    def test_requested_not_set_but_enabled(self):
        # Un fragmento puede listar un símbolo como # CONFIG_X is not set
        self.write_frag("# CONFIG_TURN_OFF is not set\n")
        self.write_cfg("CONFIG_TURN_OFF=y\n")
        out = self.run_verify([])
        self.assertIn("MISMATCH: CONFIG_TURN_OFF esperado no-set", out)

    def test_missing_symbol_reported(self):
        self.write_frag("CONFIG_NOT_IN_TREE=y\n")
        self.write_cfg("CONFIG_DRM=y\n")
        out = self.run_verify([])
        self.assertIn("MISSING en Kconfig: CONFIG_NOT_IN_TREE", out)

    def test_missing_symbol_fails_with_fail_missing(self):
        self.write_frag("CONFIG_NOT_IN_TREE=y\n")
        self.write_cfg("CONFIG_DRM=y\n")
        self.run_verify(["--fail-missing"], expect_fail=True)

    def test_string_option_match_ok(self):
        self.write_frag('CONFIG_STR_OPT="abc"\n')
        self.write_cfg('CONFIG_STR_OPT="abc"\n')
        out = self.run_verify([])
        self.assertIn('OK: CONFIG_STR_OPT ="abc"', out)

    def test_string_option_mismatch(self):
        self.write_frag('CONFIG_STR_OPT="abc"\n')
        self.write_cfg('CONFIG_STR_OPT="def"\n')
        out = self.run_verify([])
        self.assertIn("MISMATCH: CONFIG_STR_OPT", out)

    def test_deny_list_max_m_violated(self):
        self.write_frag("CONFIG_DRM=y\n")
        self.write_cfg("CONFIG_DRM=y\nCONFIG_DENY_ME=y\n")
        self.write_deny("CONFIG_DENY_ME=m\n")
        out = self.run_verify(["--deny-list", self.deny])
        self.assertIn("DENY: CONFIG_DENY_ME debe quedar como máximo =m", out)

    def test_deny_list_max_m_ok(self):
        self.write_frag("CONFIG_DRM=y\n")
        self.write_cfg("CONFIG_DRM=y\nCONFIG_DENY_ME=m\n")
        self.write_deny("CONFIG_DENY_ME=m\n")
        out = self.run_verify(["--deny-list", self.deny])
        self.assertNotIn("DENY", out)

    def test_deny_list_not_set_violated(self):
        self.write_frag("CONFIG_DRM=y\n")
        self.write_cfg("CONFIG_DRM=y\nCONFIG_TURN_OFF=m\n")
        self.write_deny("# CONFIG_TURN_OFF is not set\n")
        out = self.run_verify(["--deny-list", self.deny])
        self.assertIn("DENY: CONFIG_TURN_OFF debe quedar no-set", out)

    def test_deny_list_fails_with_fail_deny(self):
        self.write_frag("CONFIG_DRM=y\n")
        self.write_cfg("CONFIG_DRM=y\nCONFIG_DENY_ME=y\n")
        self.write_deny("CONFIG_DENY_ME=m\n")
        self.run_verify(["--deny-list", self.deny, "--fail-deny"],
                        expect_fail=True)

    def test_single_missing_option(self):
        # Opciones con un solo "-" no se aceptan
        proc = subprocess.run([VERIFY, "-h"], capture_output=True, text=True)
        self.assertNotEqual(proc.returncode, 0)


if __name__ == "__main__":
    unittest.main()
