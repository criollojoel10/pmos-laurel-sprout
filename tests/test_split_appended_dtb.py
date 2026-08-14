#!/usr/bin/env python3
#
# Licencia: GPL-3.0-or-later
#
# tests/test_split_appended_dtb.py
#
# Pruebas de scripts/split-appended-dtb.py: separación estructural de un
# payload kernel histórico (Image.gz + DTB appendado).
#
# Casos obligatorios:
#   - gzip + DTB válido → PASS
#   - gzip puro sin DTB → FAIL, salvo --allow-no-dtb
#   - DTB truncado → FAIL
#   - totalsize inválido → FAIL
#   - bytes posteriores al DTB → FAIL
#   - gzip corrupto → FAIL
#   - doble DTB → detectar y FAIL
#   - boot final con un solo DTB nuevo → PASS
#   - boot final con DTB antiguo + nuevo → FAIL
#
# Ejecutar:  python3 -m unittest discover -s tests -v

import hashlib
import json
import os
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPLITTER = os.path.join(ROOT, "scripts", "split-appended-dtb.py")

FDT_MAGIC = b"\xd0\x0d\xfe\xed"


def make_gzip(data, seed=0):
    """Comprime data con gzip determinista (nivel fijo) para fixtures."""
    co = zlib.compressobj(9, zlib.DEFLATED, 16 + zlib.MAX_WBITS)
    return co.compress(data) + co.flush()


def make_dtb(size=13536, seed=7):
    """Construye un FDT sintético con magic y totalsize coherentes."""
    assert size >= 8
    magic = FDT_MAGIC
    totalsize = struct.pack(">I", size)
    body = bytes(((seed * 251 + i * 7) & 0xFF) for i in range(size - 8))
    return magic + totalsize + body


def run_split(args, expect_fail=False):
    """Ejecuta split-appended-dtb.py; devuelve (rc, stdout, stderr, report)."""
    cmd = [sys.executable, SPLITTER] + args
    proc = subprocess.run(cmd, capture_output=True, text=True)
    report = None
    for a in args:
        if a == "--report":
            rp = args[args.index(a) + 1]
            if os.path.exists(rp):
                with open(rp) as f:
                    report = json.load(f)
    if expect_fail:
        assert proc.returncode != 0, f"debería fallar: {args}\n{proc.stdout}{proc.stderr}"
    else:
        assert proc.returncode == 0, f"{args}\n{proc.stdout}{proc.stderr}"
    return proc.returncode, proc.stdout, proc.stderr, report


class SplitAppendedDtbTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = self.tmp.name
        self.kernel_data = bytes(0x1000)  # 4 KiB de contenido
        self.gz = make_gzip(self.kernel_data)
        self.dtb = make_dtb(13536)
        self.payload = self.gz + self.dtb
        self.input_path = os.path.join(self.dir, "kernel-with-old-dtb")
        self.kernel_out = os.path.join(self.dir, "kernel.gz")
        self.dtb_out = os.path.join(self.dir, "historical.dtb")
        self.report = os.path.join(self.dir, "split-report.json")
        with open(self.input_path, "wb") as f:
            f.write(self.payload)

    def tearDown(self):
        self.tmp.cleanup()

    def split(self, extra=None, expect_fail=False, input_path=None, kernel_out=None,
              dtb_out=None, report=None):
        args = [
            "--input", input_path or self.input_path,
            "--kernel-out", kernel_out or self.kernel_out,
            "--dtb-out", dtb_out or self.dtb_out,
            "--report", report or self.report,
        ] + (extra or [])
        return run_split(args, expect_fail=expect_fail)

    # ---- casos obligatorios ----

    def test_gzip_plus_valid_dtb_pass(self):
        rc, _, _, rep = self.split()
        self.assertEqual(rep["status"], "OK")
        self.assertEqual(rep["kernel_size"], len(self.gz))
        self.assertEqual(rep["dtb_size"], len(self.dtb))
        self.assertEqual(rep["fdt_totalsize"], len(self.dtb))
        self.assertTrue(rep["fdt_boundary_exact"])
        with open(self.kernel_out, "rb") as f:
            self.assertEqual(f.read(), self.gz)
        with open(self.dtb_out, "rb") as f:
            self.assertEqual(f.read(), self.dtb)

    def test_pure_gzip_without_dtb_fails(self):
        pure = self.gz
        with open(self.input_path, "wb") as f:
            f.write(pure)
        rc, _, stderr, rep = self.split(expect_fail=True)
        self.assertEqual(rep["status"], "FAIL")
        self.assertIn("sin DTB", stderr)

    def test_pure_gzip_allow_no_dtb(self):
        pure = self.gz
        with open(self.input_path, "wb") as f:
            f.write(pure)
        rc, _, _, rep = self.split(extra=["--allow-no-dtb"])
        self.assertEqual(rep["status"], "OK")
        self.assertFalse(rep["dtb_present"])
        with open(self.kernel_out, "rb") as f:
            self.assertEqual(f.read(), pure)

    def test_truncated_dtb_fails(self):
        bad = self.gz + self.dtb[:100]  # totalsize anuncia 13536 pero solo hay 100
        with open(self.input_path, "wb") as f:
            f.write(bad)
        _, _, stderr, rep = self.split(expect_fail=True)
        self.assertEqual(rep["status"], "FAIL")
        self.assertIn("truncad", stderr)

    def test_invalid_totalsize_fails(self):
        header = FDT_MAGIC + struct.pack(">I", 4)  # totalsize 4 < 8
        bad = self.gz + header
        with open(self.input_path, "wb") as f:
            f.write(bad)
        _, _, stderr, rep = self.split(expect_fail=True)
        self.assertEqual(rep["status"], "FAIL")
        self.assertIn("totalsize", stderr)

    def test_trailing_bytes_after_dtb_fails(self):
        bad = self.gz + self.dtb + b"\x00" * 32  # bytes posteriores al DTB
        with open(self.input_path, "wb") as f:
            f.write(bad)
        _, _, stderr, rep = self.split(expect_fail=True)
        self.assertEqual(rep["status"], "FAIL")
        self.assertIn("posteriores", stderr)

    def test_corrupt_gzip_fails(self):
        bad = self.gz[:-8] + b"\x00" * 8  # corrompe el final del stream gzip
        with open(self.input_path, "wb") as f:
            f.write(bad)
        _, _, stderr, rep = self.split(expect_fail=True)
        self.assertEqual(rep["status"], "FAIL")

    def test_double_dtb_fails(self):
        bad = self.gz + self.dtb + make_dtb(2048, seed=99)  # DTB1 + DTB2
        with open(self.input_path, "wb") as f:
            f.write(bad)
        _, _, stderr, rep = self.split(expect_fail=True)
        self.assertEqual(rep["status"], "FAIL")
        self.assertIn("posteriores", stderr)

    def test_final_boot_single_new_dtb_pass(self):
        # Simula el boot final v2: Image.gz puro + DTB v2 (nuevo, sin DTB viejo)
        new_dtb = make_dtb(4096, seed=5)
        final = self.gz + new_dtb
        with open(self.input_path, "wb") as f:
            f.write(final)
        rc, _, _, rep = self.split()
        self.assertEqual(rep["status"], "OK")
        self.assertEqual(rep["dtb_size"], len(new_dtb))
        self.assertTrue(rep["fdt_boundary_exact"])
        with open(self.dtb_out, "rb") as f:
            self.assertEqual(f.read(), new_dtb)

    def test_final_boot_old_plus_new_dtb_fails(self):
        # Simula el ensamblado INCORRECTO: Image.gz + DTB viejo + DTB nuevo
        old_dtb = make_dtb(13536, seed=7)
        new_dtb = make_dtb(4096, seed=5)
        bad = self.gz + old_dtb + new_dtb
        with open(self.input_path, "wb") as f:
            f.write(bad)
        _, _, stderr, rep = self.split(expect_fail=True)
        self.assertEqual(rep["status"], "FAIL")
        self.assertIn("posteriores", stderr)

    # ---- casos adicionales de robustez ----

    def test_empty_input_fails(self):
        with open(self.input_path, "wb") as f:
            f.write(b"")
        _, _, _, rep = self.split(expect_fail=True)
        self.assertEqual(rep["status"], "FAIL")

    def test_non_gzip_payload_fails(self):
        with open(self.input_path, "wb") as f:
            f.write(b"NOTAGZIP" + self.dtb)
        _, _, stderr, _ = self.split(expect_fail=True)
        self.assertIn("gzip", stderr)

    def test_non_fdt_trailing_fails(self):
        bad = self.gz + b"\xde\xad\xbe\xef" + b"\x00" * 64
        with open(self.input_path, "wb") as f:
            f.write(bad)
        _, _, stderr, _ = self.split(expect_fail=True)
        self.assertIn("FDT magic", stderr)

    def test_report_records_hashes(self):
        rc, _, _, rep = self.split()
        with open(self.kernel_out, "rb") as f:
            kdata = f.read()
        with open(self.dtb_out, "rb") as f:
            ddata = f.read()
        self.assertEqual(rep["kernel_sha256"], hashlib.sha256(kdata).hexdigest())
        self.assertEqual(rep["dtb_sha256"], hashlib.sha256(ddata).hexdigest())
        with open(self.input_path, "rb") as f:
            self.assertEqual(rep["input_sha256"], hashlib.sha256(f.read()).hexdigest())

    def test_input_not_modified(self):
        with open(self.input_path, "rb") as f:
            before = f.read()
        self.split()
        with open(self.input_path, "rb") as f:
            after = f.read()
        self.assertEqual(after, before)


if __name__ == "__main__":
    unittest.main()