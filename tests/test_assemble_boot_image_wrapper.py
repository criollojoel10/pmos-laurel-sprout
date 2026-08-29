#!/usr/bin/env python3
#
# Licencia: GPL-3.0-or-later
#
# tests/test_assemble_boot_image_wrapper.py
#
# Pruebas del wrapper shell scripts/assemble-boot-image.sh:
#   - v0 sin append (compatibilidad)
#   - v0 con append (se transmite --append-dtb al builder)
#   - error al combinar --append-dtb con --dtb-offset (campo DTB v2)
#   - error con DTB vacío (valida -s)
#   - ausencia de dtb-offset en modo append (no campo DTB v2)
#   - imagen final no vacía y con límite < 64 MiB
#
# Ejecutar:  python3 -m unittest discover -s tests -v

import os
import subprocess
import struct
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WRAPPER = os.path.join(ROOT, "scripts", "assemble-boot-image.sh")

MAGIC = b"ANDROID!"
DTB_MAGIC = b"\xd0\x0d\xfe\xed"
GZIP_MAGIC = b"\x1f\x8b\x08\x00"
MAX_BOOT = 64 * 1024 * 1024


def fake_bytes(n, seed):
    return bytes(((seed * 251 + i * 7) & 0xFF) for i in range(n))


def synthetic_dtb(n):
    return DTB_MAGIC + struct.pack(">I", n) + b"\x00" * (n - 8)


class AssembleBootImageWrapperTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = self.tmp.name
        self.kernel = GZIP_MAGIC + fake_bytes(2_000_000, 11)
        self.ramdisk = GZIP_MAGIC + fake_bytes(500_000, 22)
        self.dtb = DTB_MAGIC + fake_bytes(50_000, 33)
        self.kernel_path = self._write("Image.gz", self.kernel)
        self.ramdisk_path = self._write("initramfs.cpio.gz", self.ramdisk)
        self.dtb_path = self._write("sm6125-xiaomi-laurel_sprout.dtb", self.dtb)

    def tearDown(self):
        self.tmp.cleanup()

    def _write(self, name, data):
        p = os.path.join(self.dir, name)
        with open(p, "wb") as f:
            f.write(data)
        return p

    def run_wrapper(self, extra_args):
        out = os.path.join(self.dir, "boot.img")
        cmd = ["bash", WRAPPER,
               "--kernel", self.kernel_path,
               "--ramdisk", self.ramdisk_path,
               "--dtb", self.dtb_path,
               "--out", out] + extra_args
        proc = subprocess.run(cmd, capture_output=True, text=True)
        return proc, out

    @staticmethod
    def parse(data):
        kernel_size, _ka, ramdisk_size, _ra, _ss, _sa, _ta, page_size, hver, _ov = \
            struct.unpack("<10I", data[8:48])
        cmdline = data[64:576].rstrip(b"\x00").decode("latin1")
        header_size = 1632 if hver == 0 else 1660
        return {
            "kernel_size": kernel_size, "ramdisk_size": ramdisk_size,
            "page_size": page_size, "header_version": hver,
            "cmdline": cmdline, "header_size": header_size,
        }, header_size

    def test_v0_without_append_compat(self):
        proc, out = self.run_wrapper(["--header-version", "0", "--cmdline", "legacy"])
        self.assertEqual(proc.returncode, 0, proc.stderr)
        with open(out, "rb") as f:
            data = f.read()
        info, hs = self.parse(data)
        self.assertEqual(info["header_version"], 0)
        self.assertGreater(len(data), 0)
        self.assertEqual(info["cmdline"], "legacy")

    def test_v0_append_forwards_flag_and_payload(self):
        proc, out = self.run_wrapper(["--header-version", "0", "--append-dtb"])
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("append_dtb", proc.stderr)  # log del layout
        with open(out, "rb") as f:
            data = f.read()
        info, header_size = self.parse(data)
        self.assertEqual(info["header_version"], 0)
        ps = info["page_size"]
        koff = ((header_size + ps - 1) // ps) * ps
        # kernel payload = kernel + DTB
        self.assertEqual(info["kernel_size"], len(self.kernel) + len(self.dtb))
        payload = data[koff:koff + info["kernel_size"]]
        self.assertEqual(payload[:len(self.kernel)], self.kernel)
        self.assertEqual(payload[len(self.kernel):len(self.kernel) + 4], DTB_MAGIC)
        self.assertGreater(len(data), 0)
        self.assertLess(len(data), MAX_BOOT)

    def test_append_dtb_with_dtb_offset_rejected(self):
        proc, _out = self.run_wrapper(["--append-dtb", "--dtb-offset", "0x01f00000"])
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("append-dtb", proc.stdout + proc.stderr)
        self.assertIn("dtb-offset", proc.stdout + proc.stderr)

    def test_empty_dtb_rejected(self):
        empty = self._write("empty.dtb", b"")
        cmd = ["bash", WRAPPER,
               "--kernel", self.kernel_path,
               "--ramdisk", self.ramdisk_path,
               "--dtb", empty,
               "--out", os.path.join(self.dir, "e.img"),
               "--append-dtb"]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("vacío", proc.stdout + proc.stderr)

    def test_append_dtb_does_not_set_dtb_field(self):
        proc, out = self.run_wrapper(["--header-version", "0", "--append-dtb"])
        self.assertEqual(proc.returncode, 0, proc.stderr)
        with open(out, "rb") as f:
            data = f.read()
        info, header_size = self.parse(data)
        self.assertEqual(header_size, 1632)  # v0: sin sección v2 / sin campo dtb
        # Sin sección DTB: la imagen termina justo tras el ramdisk (sin second)
        ps = info["page_size"]
        koff = ((header_size + ps - 1) // ps) * ps
        kpad = ((info["kernel_size"] + ps - 1) // ps) * ps
        roff = koff + kpad
        rpad = ((info["ramdisk_size"] + ps - 1) // ps) * ps
        self.assertEqual(len(data), roff + rpad)

    def test_final_image_not_empty_all_modes(self):
        for extra in (["--header-version", "0"],
                      ["--header-version", "0", "--append-dtb"],
                      ["--header-version", "2"]):
            with self.subTest(extra=extra):
                proc, out = self.run_wrapper(extra)
                self.assertEqual(proc.returncode, 0, proc.stderr)
                with open(out, "rb") as f:
                    data = f.read()
                self.assertGreater(len(data), 0)
                self.assertEqual(data[:8], MAGIC)

    def test_append_dtb_roundtrip_extraction(self):
        dtb = synthetic_dtb(60_000)
        dtb_path = self._write("dtb-real.dtb", dtb)
        out = os.path.join(self.dir, "boot-rt.img")
        proc = subprocess.run(
            ["bash", WRAPPER,
             "--kernel", self.kernel_path,
             "--ramdisk", self.ramdisk_path,
             "--dtb", dtb_path,
             "--out", out,
             "--header-version", "0", "--append-dtb"],
            capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        result = subprocess.run(
            [sys.executable, os.path.join(ROOT, "scripts", "unpack-boot-image.py"),
             "--boot", out, "--out", os.path.join(self.dir, "unpack"), "--append-dtb"],
            capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        with open(os.path.join(self.dir, "unpack", "kernel"), "rb") as f:
            kernel = f.read()
        with open(os.path.join(self.dir, "unpack", "dtb"), "rb") as f:
            dtb_out = f.read()
        self.assertEqual(kernel, self.kernel + dtb)
        self.assertEqual(dtb_out, dtb)


if __name__ == "__main__":
    unittest.main()