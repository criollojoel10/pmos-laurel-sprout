import pathlib
import unittest


ROOT = pathlib.Path(__file__).parents[1]


class Linux61BaselineTests(unittest.TestCase):
    def test_authoritative_reports_separate_artifacts(self):
        report = (ROOT / "reports/linux-61-authoritative-baseline.md").read_text()
        for token in ("31320766387", "31355730519", "3b692fefa", "ebc8287f"):
            self.assertIn(token, report)
        self.assertIn("no se deben describir como una\nsola imagen ya probada", report)

    def test_preflight_is_non_executing(self):
        preflight = (ROOT / "docs/FASE8-PREFLIGHT-LINUX61-BASELINE.md").read_text()
        self.assertIn("PREPARADO, NO EJECUTADO", preflight)
        self.assertIn("COMANDO PREPARADO, NO EJECUTADO", preflight)

    def test_workflow_is_dispatch_only_and_pinned(self):
        workflow = (ROOT / ".github/workflows/16-build-linux61-baseline.yml").read_text()
        self.assertIn("workflow_dispatch:", workflow)
        self.assertNotIn("push:", workflow)
        self.assertIn("@3d3c42e5aac5ba805825da76410c181273ba90b1", workflow)
        self.assertIn("@d3f86a106a0bac45b974a628896c90dbdf5c8093", workflow)
        self.assertIn("@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a", workflow)
        self.assertIn("physical_status:\"boot-untested\"", workflow)

    def test_runtime_scripts_are_read_only(self):
        for name in (
            "scripts/v61-health-report.sh",
            "scripts/v61-collect-logs.sh",
            "scripts/v61-verify-runtime.sh",
        ):
            code = (ROOT / name).read_text()
            self.assertNotRegex(code, r"\b(fastboot|adb|reboot|mkfs|wipefs|dd)\b")


if __name__ == "__main__":
    unittest.main()
