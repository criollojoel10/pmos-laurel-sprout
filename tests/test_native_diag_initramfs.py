#!/usr/bin/env python3
# Licencia: GPL-3.0-or-later

import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INIT = os.path.join(ROOT, "initramfs", "native-diag-init")


class NativeDiagnosticInitTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(INIT, encoding="utf-8") as stream:
            cls.text = stream.read()
        cls.code = "\n".join(
            line for line in cls.text.splitlines()
            if not line.lstrip().startswith("#")
        )

    def test_required_markers_and_heartbeat(self):
        for marker in (
            "V71_KERNEL_USERSPACE_ENTERED", "V71_PROC_MOUNTED",
            "V71_SYS_MOUNTED", "V71_DEVTMPFS_MOUNTED",
            "V71_INITRAMFS_REACHED", "V71_FB_PRESENT",
            "V71_FB_ABSENT", "V71_UFS_PRESENT", "V71_UFS_ABSENT",
            "V71_UDC_PRESENT", "V71_UDC_ABSENT",
            "V71_GADGET_CONFIGURED", "V71_USB0_PRESENT",
            "V71_REMOTE_SHELL_STARTED", "V71_RESCUE_SHELL_ACTIVE",
            "V71_HEARTBEAT",
        ):
            self.assertIn(marker, self.text)

    def test_no_6_1_modules_or_destructive_commands(self):
        self.assertNotRegex(self.code, r"6\.1\.0-sm6125|/lib/modules/6\.1")
        for command in ("fastboot", "flash", "erase", "mkfs", "wipefs", "reboot", "poweroff"):
            self.assertNotRegex(self.code, rf"\b{command}\b")

    def test_pid1_has_infinite_guard(self):
        self.assertIn("while true; do sleep 3600; done", self.text)


if __name__ == "__main__":
    unittest.main()
