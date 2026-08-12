#!/usr/bin/env python3
# Licencia: GPL-3.0-or-later

import os
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INIT = os.path.join(ROOT, "initramfs", "native-diag-init-v3")
VALIDATOR = os.path.join(ROOT, "scripts", "validate-v71-usb-dtb.sh")
WORKFLOW = os.path.join(ROOT, ".github", "workflows", "14-build-v71-usb-dtb-diag-v3.yml")


class UsbV3StaticTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(INIT, encoding="utf-8") as stream:
            cls.init = stream.read()
        with open(VALIDATOR, encoding="utf-8") as stream:
            cls.validator = stream.read()
        with open(WORKFLOW, encoding="utf-8") as stream:
            cls.workflow = stream.read()

    def test_markers_and_probe_stages(self):
        for marker in (
            "V71_V3_PID1_FIRST_INSTRUCTION", "V71_V3_PHY_NODE_PRESENT",
            "V71_V3_DWC3_WRAPPER_PRESENT", "V71_V3_DWC3_CORE_PRESENT",
            "V71_V3_EXTCON_PRESENT", "V71_V3_UDC_FOUND",
            "V71_V3_UDC_TIMEOUT", "V71_V3_GADGET_BIND_SUCCESS",
            "V71_V3_GADGET_BIND_FAILED", "V71_V3_STABLE_LOOP",
            "V71_V3_HEARTBEAT",
        ):
            self.assertIn(marker, self.init)

    def test_no_root_or_old_modules(self):
        self.assertNotRegex(self.init, r"6\.1\.0-sm6125|/lib/modules/6\.1")
        self.assertNotRegex(self.init, r"\b(fastboot|dd|mkfs|wipefs|reboot|poweroff)\b")
        self.assertIn("root:false", self.workflow)
        self.assertIn("skip_initramfs:false", self.workflow)

    def test_dtb_validator_checks_real_usb_nodes(self):
        for text in ("phy@1613000", "usb@4ef8800", "usb@4e00000",
                     "extcon-usb-gpio", "ramoops@ffc00000", "framebuffer@5c000000"):
            self.assertIn(text, self.validator)


if __name__ == "__main__":
    unittest.main()
