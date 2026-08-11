#!/usr/bin/env python3
# Licencia: GPL-3.0-or-later

import os
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INIT_V2 = os.path.join(ROOT, "initramfs", "native-diag-init-v2")
WORKFLOW = os.path.join(ROOT, ".github", "workflows", "13-build-v71-native-diag-v2.yml")


class NativeDiagV2Test(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(INIT_V2, encoding="utf-8") as stream:
            cls.init = stream.read()
        with open(WORKFLOW, encoding="utf-8") as stream:
            cls.wf = stream.read()

    def test_all_v2_markers_present(self):
        markers = [
            "V71_V2_PID1_FIRST_INSTRUCTION",
            "V71_V2_PROC_READY", "V71_V2_SYS_READY", "V71_V2_DEVTMPFS_READY",
            "V71_V2_FB_STATUS_BEGIN", "V71_V2_FB_STATUS_END",
            "V71_V2_USB_PHY_STATUS_BEGIN", "V71_V2_USB_PHY_STATUS_END",
            "V71_V2_DWC3_STATUS_BEGIN", "V71_V2_DWC3_STATUS_END",
            "V71_V2_UDC_SCAN_BEGIN", "V71_V2_UDC_SCAN_END",
            "V71_V2_CONFIGFS_BEGIN", "V71_V2_CONFIGFS_END",
            "V71_V2_GADGET_BIND_BEGIN", "V71_V2_GADGET_BIND_SUCCESS",
            "V71_V2_GADGET_BIND_FAILED", "V71_V2_USB0_PRESENT",
            "V71_V2_USB0_ABSENT", "V71_V2_TELNET_STARTED",
            "V71_V2_TELNET_FAILED", "V71_V2_STABLE_LOOP",
            "V71_V2_HEARTBEAT", "V71_V2_UDC_WAIT", "V71_V2_UDC_TIMEOUT",
        ]
        for marker in markers:
            self.assertIn(marker, self.init)

    def test_first_instruction_is_marker(self):
        lines = [l for l in self.init.splitlines() if l.strip()]
        self.assertEqual(lines[0].strip(), "#!/bin/busybox sh")
        # La primera llamada de nivel superior 'mark ...' es el marcador PID1.
        calls = [l for l in lines if l.startswith("mark ")
                 and "V71_V2_PID1_FIRST_INSTRUCTION" in l]
        self.assertTrue(calls)
        first_call_index = min(self.init.splitlines().index(l)
                               for l in self.init.splitlines() if l.startswith("mark "))
        self.assertEqual(self.init.splitlines()[first_call_index].strip(),
                         'mark "V71_V2_PID1_FIRST_INSTRUCTION"')

    def test_heartbeat_and_never_exit(self):
        self.assertIn("V71_V2_HEARTBEAT", self.init)
        self.assertIn("while true; do sleep 3600; done", self.init)
        self.assertNotIn("set -e", self.init)

    def test_no_6_1_modules_or_destructive_commands(self):
        code = "\n".join(l for l in self.init.splitlines()
                         if l.strip() and not l.strip().startswith("#"))
        self.assertNotRegex(code, r"6\.1\.0-sm6125|/lib/modules/6\.1")
        for command in ("fastboot", "flash", "erase", "mkfs", "wipefs", "reboot", "poweroff"):
            self.assertNotRegex(code, rf"\b{command}\b")

    def test_workflow_cmdline_preserves_resources(self):
        self.assertIn("clk_ignore_unused", self.wf)
        self.assertIn("pd_ignore_unused", self.wf)
        self.assertIn("regulator_ignore_unused", self.wf)
        # La línea CMDLINE literal no debe incluir root= ni skip_initramfs.
        cmdline_line = next(line for line in self.wf.splitlines()
                            if "CMDLINE=\"" in line)
        self.assertNotIn("root=", cmdline_line)
        self.assertNotIn("skip_initramfs", cmdline_line)


if __name__ == "__main__":
    unittest.main()
