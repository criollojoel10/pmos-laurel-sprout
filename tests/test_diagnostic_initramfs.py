#!/usr/bin/env python3
#
# Licencia: GPL-3.0-or-later
#
# tests/test_diagnostic_initramfs.py
#
# Pruebas del initramfs de diagnóstico (scripts/verify-diagnostic-initramfs.sh)
# y del init (initramfs/init), incluyendo la lección del incidente EX3:
# /init murió por "sed: not found" -> Kernel panic: Attempted to kill init!.
#
# Verifica:
#   - initramfs real de CI: shebang #!/bin/busybox sh, sin set -e,
#     INITRAMFS_REACHED, sin operaciones destructivas
#   - verify-diagnostic-initramfs.sh acepta un initramfs bueno (con sed y
#     todos los applets) y rechaza uno sin sed, con set -e, sin
#     INITRAMFS_REACHED, con reboot/format/fsck, o con shebang incorrecto
#
# Ejecutar:  python3 -m unittest discover -s tests -v

import gzip
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERIFIER = os.path.join(ROOT, "scripts", "verify-diagnostic-initramfs.sh")
REPO_INIT = os.path.join(ROOT, "initramfs", "init")

GOOD_INIT = """#!/bin/busybox sh
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
log()  { echo "[diag-init] $*"; }
have() { case " $(/bin/busybox --list 2>/dev/null) " in *" $1 "*) return 0;; *) return 1;; esac; }
log "=== diag ==="
/bin/busybox mount -t proc none /proc 2>&1 || true
/bin/busybox mount 2>/dev/null | (/bin/busybox sed 's/^/  /' || /bin/busybox cat)
log "[diag-init] INITRAMFS_REACHED"
log "[diag-init] entering rescue shell"
PS1='pmos-diag# ' sh </dev/console >/dev/console 2>&1
while true; do sleep 3600; done
"""

REQUIRED_APPLETS = ["sh", "cat", "sed", "grep", "awk", "mount", "umount",
                    "mkdir", "mknod", "sleep", "dmesg", "uptime", "ls", "cp",
                    "sync", "switch_root", "tr", "wc", "setsid", "ifconfig",
                    "telnetd"]


def fake_aarch64_busybox():
    """ELF64 aarch64 estático sintético (solo header; file lo detecta)."""
    hdr = bytearray(64)
    hdr[0:4] = b"\x7fELF"
    hdr[4] = 2
    hdr[5] = 1
    hdr[6] = 1
    struct.pack_into("<H", hdr, 16, 2)
    struct.pack_into("<H", hdr, 18, 183)
    struct.pack_into("<I", hdr, 20, 1)
    struct.pack_into("<Q", hdr, 32, 64)
    struct.pack_into("<H", hdr, 52, 64)
    struct.pack_into("<H", hdr, 54, 56)
    struct.pack_into("<H", hdr, 56, 1)
    ph = bytearray(56)
    struct.pack_into("<I", ph, 0, 1)
    struct.pack_into("<Q", ph, 8, 0)
    struct.pack_into("<Q", ph, 16, 0x400000)
    struct.pack_into("<Q", ph, 24, 0x400000)
    struct.pack_into("<Q", ph, 32, 64)
    struct.pack_into("<Q", ph, 40, 64)
    struct.pack_into("<I", ph, 48, 5)
    struct.pack_into("<I", ph, 52, 0x10000)
    return bytes(hdr) + bytes(ph)


class DiagnosticInitramfsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = self.tmp.name
        self.stage = os.path.join(self.dir, "stage")
        os.makedirs(os.path.join(self.stage, "bin"))
        os.makedirs(os.path.join(self.stage, "sbin"))
        os.makedirs(os.path.join(self.stage, "usr", "bin"))
        os.makedirs(os.path.join(self.stage, "usr", "sbin"))
        bb = os.path.join(self.stage, "bin", "busybox")
        with open(bb, "wb") as f:
            f.write(fake_aarch64_busybox())
        os.chmod(bb, 0o755)
        for a in REQUIRED_APPLETS:
            os.symlink("busybox", os.path.join(self.stage, "bin", a))
        os.symlink("busybox", os.path.join(self.stage, "sbin", "mount"))
        os.symlink("busybox", os.path.join(self.stage, "sbin", "reboot"))
        with open(os.path.join(self.stage, "init"), "w") as f:
            f.write(GOOD_INIT)
        os.chmod(os.path.join(self.stage, "init"), 0o755)

    def tearDown(self):
        self.tmp.cleanup()

    def pack_ramdisk(self, name="initramfs.cpio.gz"):
        out = os.path.join(self.dir, name)
        with open(out, "wb") as f:
            proc = subprocess.run(
                ["cpio", "-o", "-H", "newc"],
                cwd=self.stage, input=b"", capture_output=True)
            # cpio lee la lista de archivos desde stdin; los recogemos con find
            files = subprocess.run(
                ["find", ".", "-print0"], cwd=self.stage,
                capture_output=True, text=False).stdout
            proc = subprocess.run(
                ["cpio", "--null", "-o", "-H", "newc"],
                cwd=self.stage, input=files, capture_output=True)
            f.write(gzip.compress(proc.stdout))
        return out

    def run_verifier(self, ramdisk, expect_fail=False):
        out = os.path.join(self.dir, "verify-out")
        cmd = [VERIFIER,
               "--ramdisk", ramdisk,
               "--init", os.path.join(self.stage, "init"),
               "--busybox-root", self.stage,
               "--out", out]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if expect_fail:
            self.assertNotEqual(proc.returncode, 0,
                                f"debería fallar\n{proc.stdout}{proc.stderr}")
        else:
            self.assertEqual(proc.returncode, 0,
                             f"{proc.stdout}{proc.stderr}")
        report = os.path.join(out, "initramfs-verification.md")
        self.assertTrue(os.path.exists(report), "falta initramfs-verification.md")
        with open(report) as f:
            return f.read()

    def test_repo_init_requirements(self):
        """El init del repo cumple los requisitos de contenido (sin ejecutar)."""
        with open(REPO_INIT) as f:
            src = f.read()
        first = src.splitlines()[0].rstrip("\r")
        self.assertEqual(first, "#!/bin/busybox sh")
        self.assertNotRegex(src, r"^\s*set\s+-e(\s|$)", "no debe usar set -e")
        self.assertIn("INITRAMFS_REACHED", src)
        # Solo líneas de código (no comentarios) y palabra completa.
        code = "\n".join(l for l in src.splitlines()
                         if not l.lstrip().startswith("#"))
        for bad in ("reboot", "format", "mkfs", "fsck", "dd", "flash",
                    "erase", "fastboot", "userdata", "set_active", "wipe"):
            self.assertNotRegex(code, rf"\b{bad}\b",
                                f"init no debe contener {bad!r}")

    def test_good_initramfs_passes(self):
        ramdisk = self.pack_ramdisk()
        report = self.run_verifier(ramdisk)
        self.assertIn("CONCLUSIÓN: PASS", report)

    def test_missing_sed_fails(self):
        os.unlink(os.path.join(self.stage, "bin", "sed"))
        ramdisk = self.pack_ramdisk("nosed.cpio.gz")
        report = self.run_verifier(ramdisk, expect_fail=True)
        self.assertIn("sed", report)
        self.assertIn("CONCLUSIÓN: FAIL", report)

    def test_set_e_fails(self):
        with open(os.path.join(self.stage, "init"), "w") as f:
            f.write("#!/bin/busybox sh\nset -e\nexport PATH=/bin:/sbin:/usr/bin:/usr/sbin\n"
                    "log '[diag-init] INITRAMFS_REACHED'\n")
        os.chmod(os.path.join(self.stage, "init"), 0o755)
        ramdisk = self.pack_ramdisk("sete.cpio.gz")
        report = self.run_verifier(ramdisk, expect_fail=True)
        self.assertIn("CONCLUSIÓN: FAIL", report)

    def test_no_reached_fails(self):
        with open(os.path.join(self.stage, "init"), "w") as f:
            f.write("#!/bin/busybox sh\nexport PATH=/bin:/sbin:/usr/bin:/usr/sbin\n"
                    "log 'sin marca final'\n")
        os.chmod(os.path.join(self.stage, "init"), 0o755)
        ramdisk = self.pack_ramdisk("noreached.cpio.gz")
        report = self.run_verifier(ramdisk, expect_fail=True)
        self.assertIn("INITRAMFS_REACHED", report)

    def test_reboot_present_fails(self):
        with open(os.path.join(self.stage, "init"), "w") as f:
            f.write("#!/bin/busybox sh\nexport PATH=/bin:/sbin:/usr/bin:/usr/sbin\n"
                    "log '[diag-init] INITRAMFS_REACHED'\n"
                    "reboot\n")
        os.chmod(os.path.join(self.stage, "init"), 0o755)
        ramdisk = self.pack_ramdisk("reboot.cpio.gz")
        report = self.run_verifier(ramdisk, expect_fail=True)
        self.assertIn("CONCLUSIÓN: FAIL", report)

    def test_wrong_shebang_fails(self):
        with open(os.path.join(self.stage, "init"), "w") as f:
            f.write("#!/bin/sh\nexport PATH=/bin:/sbin:/usr/bin:/usr/sbin\n"
                    "log '[diag-init] INITRAMFS_REACHED'\n")
        os.chmod(os.path.join(self.stage, "init"), 0o755)
        ramdisk = self.pack_ramdisk("shebang.cpio.gz")
        report = self.run_verifier(ramdisk, expect_fail=True)
        self.assertIn("shebang", report)


if __name__ == "__main__":
    unittest.main()
