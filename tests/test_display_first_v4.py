#!/usr/bin/env python3
# Licencia: GPL-3.0-or-later

import os
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INIT = os.path.join(ROOT, "initramfs", "native-diag-init-v4")
WORKFLOW = os.path.join(ROOT, ".github", "workflows", "15-build-v71-display-first-diag-v4.yml")


class DisplayFirstV4Test(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(INIT, encoding="utf-8") as stream:
            cls.init = stream.read()
        with open(WORKFLOW, encoding="utf-8") as stream:
            cls.workflow = stream.read()

    def test_display_markers_precede_usb(self):
        self.assertLess(self.init.index("V71_V4_PID1_FIRST_INSTRUCTION"),
                        self.init.index("V71_V4_USB_AUDIT_BEGIN"))
        for marker in ("V71_V4_FB_CHECKPOINT_GREEN", "V71_V4_FB_CHECKPOINT_BLUE",
                       "V71_V4_FB_CHECKPOINT_RED", "V71_V4_HEARTBEAT"):
            self.assertIn(marker, self.init)

    def test_safe_cmdline(self):
        self.assertIn("panic=0", self.workflow)
        cmdline = next(line for line in self.workflow.splitlines()
                       if line.lstrip().startswith('CMDLINE="'))
        for forbidden in ("initcall_debug", "panic=10", "panic_on_warn=1",
                          "root=", "skip_initramfs", "quiet", "splash",
                          "vt.global_cursor_default=0"):
            self.assertNotIn(forbidden, cmdline)
        self.assertIn("consoleblank=0", cmdline)
        self.assertIn("panic=0", cmdline)
        for required in ("clk_ignore_unused", "pd_ignore_unused", "regulator_ignore_unused"):
            self.assertIn(required, self.workflow)

    def test_no_old_modules_or_destructive_commands(self):
        code = "\n".join(line for line in self.init.splitlines()
                         if not line.lstrip().startswith("#"))
        self.assertNotRegex(code, r"6\.1\.0-sm6125|/lib/modules/6\.1|vermagic.*6\.1")
        for bad in ("fastboot", "flash", "erase", "mkfs", "wipefs", "reboot", "poweroff", "clear", "reset", "chvt"):
            self.assertNotRegex(code, rf"\b{bad}\b")


if __name__ == "__main__":
    unittest.main()
