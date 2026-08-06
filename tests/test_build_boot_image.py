#!/usr/bin/env python3
#
# Licencia: GPL-3.0-or-later
#
# tests/test_build_boot_image.py
#
# Pruebas del builder scripts/build-boot-image.py:
#   - header v2 normal (DTB como sección separada)
#   - header v2 + --append-dtb (kernel = Image.gz+DTB, dtb_size=0)
#   - header v0 histórico (1632 B, append_dtb, sin sección DTB)
#   - offsets, page padding, payloads byte a byte
#   - DTB en la frontera size(Image.gz) con magic d00dfeed
#   - id hash SHA1(kernel+ramdisk+second+dtb) como mkbootimg
#   - límite de tamaño < 64 MiB
#   - rechazo de header versions no soportadas
#
# Ejecutar:  python3 -m unittest discover -s tests -v

import hashlib
import os
import struct
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILDER = os.path.join(ROOT, "scripts", "build-boot-image.py")

MAGIC = b"ANDROID!"
DTB_MAGIC = b"\xd0\x0d\xfe\xed"
GZIP_MAGIC = b"\x1f\x8b\x08\x00"
MAX_BOOT = 64 * 1024 * 1024


def fake_bytes(n, seed):
    return bytes(((seed * 251 + i * 7) & 0xFF) for i in range(n))


class BootImageTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = self.tmp.name
        self.kernel = GZIP_MAGIC + fake_bytes(2_000_000, 11)
        self.ramdisk = GZIP_MAGIC + fake_bytes(500_000, 22)
        self.dtb = DTB_MAGIC + fake_bytes(50_000, 33)
        self.kernel_path = os.path.join(self.dir, "Image.gz")
        self.ramdisk_path = os.path.join(self.dir, "initramfs.cpio.gz")
        self.dtb_path = os.path.join(self.dir, "sm6125-xiaomi-laurel_sprout.dtb")
        for p, data in ((self.kernel_path, self.kernel),
                        (self.ramdisk_path, self.ramdisk),
                        (self.dtb_path, self.dtb)):
            with open(p, "wb") as f:
                f.write(data)

    def tearDown(self):
        self.tmp.cleanup()

    def run_builder(self, extra_args, expect_fail=False):
        cmd = [sys.executable, BUILDER,
               "--kernel", self.kernel_path,
               "--ramdisk", self.ramdisk_path,
               "--dtb", self.dtb_path,
               "--out", os.path.join(self.dir, "boot.img")] + extra_args
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if expect_fail:
            self.assertNotEqual(proc.returncode, 0,
                                f"debería fallar: {extra_args}\n{proc.stdout}{proc.stderr}")
            return None
        self.assertEqual(proc.returncode, 0, f"{extra_args}\n{proc.stderr}")
        with open(os.path.join(self.dir, "boot.img"), "rb") as f:
            return f.read()

    @staticmethod
    def parse(data):
        kernel_size, kernel_addr, ramdisk_size, ramdisk_addr, second_size, \
            second_addr, tags_addr, page_size, header_version, os_version = \
            struct.unpack("<10I", data[8:48])
        cmdline = data[64:576].rstrip(b"\x00").decode("latin1")
        header_size = 1632 if header_version == 0 else 1660
        return {
            "kernel_size": kernel_size, "kernel_addr": kernel_addr,
            "ramdisk_size": ramdisk_size, "ramdisk_addr": ramdisk_addr,
            "second_size": second_size, "second_addr": second_addr,
            "tags_addr": tags_addr, "page_size": page_size,
            "header_version": header_version, "os_version": os_version,
            "cmdline": cmdline, "header_size": header_size,
            "magic": data[:8],
        }

    @staticmethod
    def sections(data, info):
        ps = info["page_size"]
        header_pages = (info["header_size"] + ps - 1) // ps
        koff = header_pages * ps
        ksize = (info["kernel_size"] + ps - 1) // ps * ps
        roff = koff + ksize
        rsize = (info["ramdisk_size"] + ps - 1) // ps * ps
        return koff, ksize, roff, rsize, header_pages

    def test_v2_normal(self):
        data = self.run_builder(["--header-version", "2"])
        info = self.parse(data)
        self.assertEqual(info["magic"], MAGIC)
        self.assertEqual(info["header_version"], 2)
        self.assertEqual(info["header_size"], 1660)
        self.assertEqual(info["kernel_size"], len(self.kernel))
        self.assertEqual(info["ramdisk_size"], len(self.ramdisk))
        self.assertEqual(struct.unpack("<I", data[1644:1648])[0], 1660)  # header_size v2
        # DTB como sección separada: dtb_size == len(dtb)
        self.assertEqual(struct.unpack("<I", data[1648:1652])[0], len(self.dtb))
        koff, ksize, roff, rsize, _ = self.sections(data, info)
        self.assertEqual(data[koff:koff + info["kernel_size"]], self.kernel)
        # sección DTB tras el ramdisk (sin second)
        doff = roff + rsize
        self.assertEqual(data[doff:doff + len(self.dtb)], self.dtb)

    def test_v2_append_dtb(self):
        data = self.run_builder(["--header-version", "2", "--append-dtb"])
        info = self.parse(data)
        self.assertEqual(info["header_version"], 2)
        concat = self.kernel + self.dtb
        self.assertEqual(info["kernel_size"], len(concat))
        # dtb_size = 0 con append_dtb
        self.assertEqual(struct.unpack("<I", data[1648:1652])[0], 0)
        koff, ksize, roff, rsize, _ = self.sections(data, info)
        self.assertEqual(data[koff:koff + len(concat)], concat)
        # DTB en la frontera
        self.assertEqual(data[koff + len(self.kernel):koff + len(self.kernel) + 4], DTB_MAGIC)

    def test_v0_append_dtb(self):
        data = self.run_builder(["--header-version", "0", "--append-dtb"])
        info = self.parse(data)
        self.assertEqual(info["magic"], MAGIC)
        self.assertEqual(info["header_version"], 0)
        self.assertEqual(info["header_size"], 1632)
        concat = self.kernel + self.dtb
        self.assertEqual(info["kernel_size"], len(concat))
        self.assertEqual(info["ramdisk_size"], len(self.ramdisk))
        koff, ksize, roff, rsize, _ = self.sections(data, info)
        self.assertEqual(data[koff:koff + len(concat)], concat)
        # Después del ramdisk no hay sección DTB: se acaba la imagen (sin second)
        expected_total = koff + ksize + rsize
        self.assertEqual(len(data), expected_total)
        # DTB en la frontera
        self.assertEqual(data[koff + len(self.kernel):koff + len(self.kernel) + 4], DTB_MAGIC)

    def test_v0_no_append_rejected_dtb_still_valid(self):
        # v0 sin append: DTB no tiene dónde ir (históricamente no se usaba).
        # El builder con v0 y sin append escribe sección DTB igualmente.
        data = self.run_builder(["--header-version", "0"])
        info = self.parse(data)
        self.assertEqual(info["header_version"], 0)
        koff, ksize, roff, rsize, _ = self.sections(data, info)
        doff = roff + rsize
        self.assertEqual(data[doff:doff + len(self.dtb)], self.dtb)

    def test_offsets(self):
        data = self.run_builder([
            "--header-version", "2",
            "--base", "0x00000000",
            "--kernel-offset", "0x00008000",
            "--ramdisk-offset", "0x01000000",
            "--tags-offset", "0x00000100",
        ])
        info = self.parse(data)
        self.assertEqual(info["kernel_addr"], 0x8000)
        self.assertEqual(info["ramdisk_addr"], 0x1000000)
        self.assertEqual(info["tags_addr"], 0x100)

    def test_page_padding(self):
        data = self.run_builder(["--header-version", "2", "--page-size", "4096"])
        info = self.parse(data)
        self.assertEqual(info["page_size"], 4096)
        ps = info["page_size"]
        self.assertEqual(len(data) % ps, 0)
        koff, ksize, roff, rsize, _ = self.sections(data, info)
        self.assertEqual(koff % ps, 0)
        self.assertEqual(roff % ps, 0)
        self.assertEqual(ksize % ps, 0)
        self.assertEqual(rsize % ps, 0)

    def test_kernel_payload_byte_identical(self):
        for extra in (["--header-version", "2"], ["--header-version", "0", "--append-dtb"]):
            data = self.run_builder(extra)
            info = self.parse(data)
            koff, _, _, _, _ = self.sections(data, info)
            if "--append-dtb" in extra:
                self.assertEqual(data[koff:koff + info["kernel_size"]], self.kernel + self.dtb)
            else:
                self.assertEqual(data[koff:koff + info["kernel_size"]], self.kernel)

    def test_ramdisk_payload_byte_identical(self):
        for extra in (["--header-version", "2"], ["--header-version", "0", "--append-dtb"]):
            data = self.run_builder(extra)
            info = self.parse(data)
            koff, ksize, roff, _, _ = self.sections(data, info)
            self.assertEqual(data[roff:roff + info["ramdisk_size"]], self.ramdisk)

    def test_dtb_boundary(self):
        data = self.run_builder(["--header-version", "0", "--append-dtb"])
        info = self.parse(data)
        koff, _, _, _, _ = self.sections(data, info)
        boundary = koff + len(self.kernel)
        self.assertEqual(data[boundary:boundary + 4], DTB_MAGIC)

    def test_id_hash(self):
        for extra in (["--header-version", "2"], ["--header-version", "0", "--append-dtb"]):
            data = self.run_builder(extra)
            info = self.parse(data)
            koff, ksize, roff, rsize, _ = self.sections(data, info)
            kpayload = data[koff:koff + info["kernel_size"]]
            rpayload = data[roff:roff + info["ramdisk_size"]]
            if "--append-dtb" in extra:
                dtb_section = b""
            else:
                doff = roff + rsize
                dtb_section = data[doff:doff + len(self.dtb)]
            expected = hashlib.sha1(kpayload + rpayload + dtb_section).digest()
            self.assertEqual(data[576:596], expected)

    def test_size_limit_64MiB(self):
        data = self.run_builder(["--header-version", "0", "--append-dtb"])
        self.assertLess(len(data), MAX_BOOT)
        self.assertLess(2_000_000 + 500_000 + 50_000, MAX_BOOT)

    def test_reject_invalid_header_version(self):
        self.run_builder(["--header-version", "1"], expect_fail=True)

    def test_cmdline_preserved(self):
        data = self.run_builder([
            "--header-version", "0", "--append-dtb",
            "--cmdline", "clk_ignore_unused",
        ])
        info = self.parse(data)
        self.assertEqual(info["cmdline"], "clk_ignore_unused")

    def test_os_version_encoded(self):
        data = self.run_builder([
            "--header-version", "2",
            "--os-version", "12.0.0",
            "--os-patch-level", "2026-08",
        ])
        info = self.parse(data)
        # os_version = major<<25 | minor<<18 | patch<<11 | patch_level
        patch_level = ((2026 - 2000) << 4) | 8
        expected = (12 << 25) | (0 << 18) | (0 << 11) | patch_level
        self.assertEqual(info["os_version"], expected)


if __name__ == "__main__":
    unittest.main()
