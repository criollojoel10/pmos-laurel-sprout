#!/usr/bin/env python3
# Licencia: GPL-3.0-or-later

import os
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VALIDATOR = os.path.join(ROOT, "scripts", "validate-wifi-dtb.py")

GOOD_DTS = """/dts-v1/;
/ {
	memory@53300000 { reg = <0x0 0x53300000 0x0 0x200000>; no-map; phandle = <0x6d>; };
	iommu@c600000 { reg = <0xc600000 0x80000>; #iommu-cells = <0x02>; phandle = <0x1d>; };
	l8 { regulator-min-microvolt = <0x61a80>; regulator-max-microvolt = <0xb1bc0>; phandle = <0x6e>; };
	l16 { regulator-min-microvolt = <0x1b7740>; regulator-max-microvolt = <0x1d0d80>; phandle = <0x6f>; };
	l17 { regulator-min-microvolt = <0x130b00>; regulator-max-microvolt = <0x13e5c0>; phandle = <0x70>; };
	l23 { regulator-min-microvolt = <0x2dc6c0>; regulator-max-microvolt = <0x33e140>; phandle = <0x71>; };
	chosen { framebuffer@5c000000 { reg = <0 0x5c000000 0 0x448e00>; }; };
	wifi@c800000 {
		compatible = "qcom,wcn3990-wifi";
		reg = <0xc800000 0x800000>;
		reg-names = "membase";
		memory-region = <0x6d>;
		iommus = <0x1d 0x80 0x01>;
		qcom,msa-fixed-perm;
		interrupts = <0x00 0x166 0x04 0x00 0x167 0x04 0x00 0x168 0x04 0x00 0x169 0x04 0x00 0x16a 0x04 0x00 0x16b 0x04 0x00 0x16c 0x04 0x00 0x16d 0x04 0x00 0x16e 0x04 0x00 0x16f 0x04 0x00 0x170 0x04 0x00 0x171 0x04>;
		vdd-0.8-cx-mx-supply = <0x6e>;
		vdd-1.8-xo-supply = <0x6f>;
		vdd-1.3-rfa-supply = <0x70>;
		vdd-3.3-ch0-supply = <0x71>;
		status = "okay";
	};
};
"""


class ValidateWifiDtbTest(unittest.TestCase):
    def run_validator(self, content):
        with tempfile.TemporaryDirectory() as tmp:
            dts = os.path.join(tmp, "x.dts")
            with open(dts, "w", encoding="utf-8") as stream:
                stream.write(content)
            return subprocess.run([sys.executable, VALIDATOR, "--dts", dts],
                                  capture_output=True, text=True)

    def test_good_dtb_passes(self):
        proc = self.run_validator(GOOD_DTS)
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("OK: DTB WCN3990 validado", proc.stdout)

    def test_wrong_sid_fails(self):
        proc = self.run_validator(GOOD_DTS.replace("0x1d 0x80 0x01", "0x1d 0x1a0 0x01"))
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("iommus SID 0x80", proc.stdout)

    def test_wrong_regulator_fails(self):
        proc = self.run_validator(GOOD_DTS.replace(
            "vdd-3.3-ch0-supply = <0x71>;", "vdd-3.3-ch0-supply = <0x6f>;"))
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("vdd-3.3-ch0-supply", proc.stdout)


if __name__ == "__main__":
    unittest.main()
