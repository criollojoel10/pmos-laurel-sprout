#!/usr/bin/env python3
# Licencia: GPL-3.0-or-later

import os
import struct
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UNPACK = os.path.join(ROOT, "scripts", "unpack-boot-image.py")


def pad(data, page):
    return data + b"\0" * ((-len(data)) % page)


def synthetic_boot(version):
    page = 4096
    kernel = b"kernel-payload"
    ramdisk = b"ramdisk-payload"
    dtb = b"dtb-payload" if version == 2 else b""
    header_size = 1660 if version == 2 else 1632
    header = bytearray(header_size)
    header[:8] = b"ANDROID!"
    struct.pack_into("<10I", header, 8, len(kernel), 0, len(ramdisk), 0,
                     0, 0, 0, page, version, 0)
    cmdline = b"console=tty0 rootwait"
    header[64:64 + len(cmdline)] = cmdline
    if version == 2:
        struct.pack_into("<I", header, 1648, len(dtb))
    return pad(bytes(header), page) + pad(kernel, page) + pad(ramdisk, page) + pad(dtb, page)


class UnpackBootImageTest(unittest.TestCase):
    def check_version(self, version):
        with tempfile.TemporaryDirectory() as tmp:
            boot = os.path.join(tmp, "boot.img")
            out = os.path.join(tmp, "out")
            with open(boot, "wb") as stream:
                stream.write(synthetic_boot(version))
            proc = subprocess.run([sys.executable, UNPACK, "--boot", boot, "--out", out,
                                   "--print-cmdline"], capture_output=True,
                                  text=True, check=True)
            self.assertEqual(proc.stdout.strip(), "console=tty0 rootwait")
            with open(os.path.join(out, "kernel"), "rb") as stream:
                self.assertEqual(stream.read(), b"kernel-payload")
            with open(os.path.join(out, "ramdisk"), "rb") as stream:
                self.assertEqual(stream.read(), b"ramdisk-payload")
            if version == 2:
                with open(os.path.join(out, "dtb"), "rb") as stream:
                    self.assertEqual(stream.read(), b"dtb-payload")
            else:
                self.assertFalse(os.path.exists(os.path.join(out, "dtb")))

    def test_header_v0(self):
        self.check_version(0)

    def test_header_v2(self):
        self.check_version(2)


if __name__ == "__main__":
    unittest.main()
