#!/usr/bin/env python3
# Licencia: GPL-3.0-or-later

import os
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATCH = os.path.join(ROOT, "patches", "kernel", "0004-dts-enable-wifi-wcn3990.patch")
WORKFLOW = os.path.join(ROOT, ".github", "workflows", "05-build-pmos-shell-v71.yml")


class WifiPatchTest(unittest.TestCase):
    def test_wcn3990_snoc_properties_are_explicit(self):
        with open(PATCH, encoding="utf-8") as stream:
            text = stream.read()
        for value in (
            'compatible = "qcom,wcn3990-wifi"',
            "reg = <0x0c800000 0x800000>",
            "memory-region = <&wlan_msa_mem>",
            "iommus = <&apps_smmu 0x1a0 0x1>",
            "qcom,msa-fixed-perm",
            "GIC_SPI 358",
            "GIC_SPI 369",
            "vdd-0.8-cx-mx-supply = <&vreg_l8a>",
            "vdd-1.8-xo-supply = <&vreg_l16a>",
            "vdd-1.3-rfa-supply = <&vreg_l17a>",
            "vdd-3.3-ch0-supply = <&vreg_l23a>",
        ):
            self.assertIn(value, text)
        self.assertNotIn("+\t\t\tno-sdio", text)
        self.assertNotIn("+\t\t\tno-mmc", text)

    def test_pmos_shell_cmdline_does_not_skip_initramfs(self):
        with open(WORKFLOW, encoding="utf-8") as stream:
            text = stream.read()
        self.assertIn("root=PARTUUID=dd9c45fe-41b1-02a1-ed69-58eb218e5043", text)
        self.assertIn("console=tty0", text)
        self.assertIn("consoleblank=0", text)
        self.assertIn('default: false', text)
        self.assertIn('if grep -q "skip_initramfs"', text)


if __name__ == "__main__":
    unittest.main()
