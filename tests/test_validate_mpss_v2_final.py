#!/usr/bin/env python3
#
# Licencia: GPL-3.0-or-later
#
# tests/test_validate_mpss_v2_final.py
#
# Pruebas de scripts/validate-mpss-v2-final.py: validacion SEMANTICA del DTB
# final decompilado (final-v2.dts) de la variante WCN3990 v2 (MPSS transport).
#
# Contexto: el run 31809157048 fallo por falsos negativos del validador:
#   - dtc colapsa interrupts-extended en un solo <...> (contar "<0x" != entradas);
#   - dtc representa ceros como 0x00 y el validador esperaba 0x0;
#   - interrupt-names puede variar en espacios/indentacion/saltos de linea.
# Este validador parsea SEMANTICAMENTE (int(token, 0)) y segmenta
# interrupts-extended por providers (#interrupt-cells), no por texto.
#
# Casos obligatorios:
#   P1-P8 positivos, N1-N15 negativos, mas fixture real DTC 1.7.2.
#
# Ejecutar:  python3 -m unittest discover -s tests -v

import contextlib
import importlib.util
import io
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VALIDATOR = os.path.join(ROOT, "scripts", "validate-mpss-v2-final.py")
FIX_POS = os.path.join(ROOT, "tests", "fixtures", "mpss-v2-final-positive.dts")
FIX_POS_SRC = os.path.join(ROOT, "tests", "fixtures", "mpss-v2-final-positive-source.dts")


def _load_validator():
    spec = importlib.util.spec_from_file_location("validate_mpss_v2_final", VALIDATOR)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


MOD = _load_validator()


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def validate(text):
    """Ejecuta validate() capturando stdout; devuelve lista de labels fallidos."""
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        fails = MOD.validate(text)
    return fails


class MpssV2FinalValidatorTest(unittest.TestCase):
    def setUp(self):
        self.base = read(FIX_POS)

    def assert_pass(self, text, msg=None):
        fails = validate(text)
        self.assertEqual(fails, [], msg or ("gates que fallaron: %r" % fails))

    def assert_fail_contains(self, text, label, msg=None):
        fails = validate(text)
        self.assertIn(label, fails, msg or ("label no presente en: %r" % fails))
        return fails

    # ------------------------------------------------------------------
    # Helpers del parser (unit)
    # ------------------------------------------------------------------

    def test_parse_cells_normaliza_ceros(self):
        self.assertEqual(MOD.parse_cells("<0>"), [0])
        self.assertEqual(MOD.parse_cells("<0x0>"), [0])
        self.assertEqual(MOD.parse_cells("<0x00>"), [0])
        self.assertEqual(MOD.parse_cells("<0x00000000>"), [0])
        self.assertEqual(MOD.parse_cells("<0x00 0x4b000000 0x00 0x7e00000>"),
                         [0, 0x4B000000, 0, 0x07E00000])
        self.assertEqual(MOD.parse_cells("<0x0 0x4b000000 0x0 0x07e00000>"),
                         [0, 0x4B000000, 0, 0x07E00000])
        self.assertEqual(MOD.parse_cells("<0x4b000000>"), [0x4B000000])

    def test_parse_cells_multiple_groups(self):
        self.assertEqual(MOD.parse_cells("<0x1b3>, <0x1ac>"), [0x1B3, 0x1AC])

    def test_parse_strings_multiline(self):
        val = ('"wdog", "fatal", "ready",\n'
               '                  "handover", "stop-ack", "shutdown-ack"')
        self.assertEqual(MOD.parse_strings(val), MOD.EXPECTED_INTERRUPT_NAMES)

    def test_parse_strings_single_line(self):
        self.assertEqual(
            MOD.parse_strings('"wdog", "fatal", "ready", "handover", "stop-ack", "shutdown-ack"'),
            MOD.EXPECTED_INTERRUPT_NAMES)

    def test_extract_property_multiline(self):
        block = ('remoteproc@6080000 {\n'
                 '\tinterrupt-names = "wdog", "fatal", "ready",\n'
                 '\t                  "handover", "stop-ack", "shutdown-ack";\n'
                 '\tstatus = "disabled";\n'
                 '};')
        self.assertIsNotNone(MOD.extract_property(block, "interrupt-names"))
        self.assertEqual(MOD.extract_property(block, "status"), '"disabled"')

    def test_extract_block_balanced(self):
        block = MOD.extract_block(self.base, "remoteproc@6080000")
        self.assertIsNotNone(block)
        self.assertIn("glink-edge", block)
        self.assertIn('compatible = "qcom,sm8150-mpss-pas"', block)

    # ------------------------------------------------------------------
    # P: casos positivos
    # ------------------------------------------------------------------

    def test_p1_dtc_0x00_reg(self):
        # formato de dtc: ceros con padding 0x00
        self.assertTrue("<0x00 0x4b000000 0x00 0x7e00000>" in self.base)
        self.assert_pass(self.base)

    def test_p2_0x0_y_0x07e00000(self):
        text = self.base.replace(
            "reg = <0x00 0x4b000000 0x00 0x7e00000>;",
            "reg = <0x0 0x4b000000 0x0 0x07e00000>;")
        self.assert_pass(text)

    def test_p3_interrupt_names_multiline(self):
        text = self.base.replace(
            'interrupt-names = "wdog", "fatal", "ready", "handover", "stop-ack", "shutdown-ack";',
            'interrupt-names = "wdog", "fatal", "ready",\n'
            '\t\t\t"handover", "stop-ack", "shutdown-ack";')
        self.assert_pass(text)

    def test_p4_interrupt_names_single_line(self):
        # el fixture ya esta en una sola linea
        self.assert_pass(self.base)

    def test_p5_interrupts_extended_single_bracket(self):
        # dtc colapsa todas las entradas en un unico <...> (falso negativo #1)
        self.assertTrue(
            re_search_single_bracket(self.base, "interrupts-extended"))
        self.assert_pass(self.base)

    def test_p6_espacios_tabs_variables(self):
        text = self.base.replace(
            "interrupts-extended = <0x02 0x00 0x133 0x01 0x03 0x00 0x01 0x03 0x01 0x01 0x03 0x02 0x01 0x03 0x03 0x01 0x03 0x07 0x01>;",
            "interrupts-extended =\n"
            "\t<0x02 0x00  0x133 0x01\n"
            "\t 0x03 0x00 0x01\n"
            "\t 0x03 0x01 0x01\n"
            "\t 0x03 0x02 0x01\n"
            "\t 0x03 0x03 0x01\n"
            "\t 0x03 0x07 0x01>;")
        self.assert_pass(text)

    def test_p7_phandles_diferentes_semantica_equivalente(self):
        # renumerar phandles (declaraciones + referencias) de forma consistente,
        # sin tocar #interrupt-cells ni otras celdas numericas.
        decl = {
            "phandle = <0x01>;": "phandle = <0x11>;",  # rpmcc
            "phandle = <0x02>;": "phandle = <0x12>;",  # intc
            "phandle = <0x03>;": "phandle = <0x13>;",  # slave-kernel
            "phandle = <0x04>;": "phandle = <0x14>;",  # rpmpd
            "phandle = <0x05>;": "phandle = <0x15>;",  # master-kernel
            "phandle = <0x06>;": "phandle = <0x16>;",  # wlan
            "phandle = <0x07>;": "phandle = <0x17>;",  # modem_mem
            "phandle = <0x08>;": "phandle = <0x18>;",  # wlan-msa-mem
        }
        refs = {
            "interrupts-extended = <0x02 0x00": "interrupts-extended = <0x12 0x00",
            "0x03 0x00 0x01 0x03 0x01 0x01 0x03 0x02 0x01 0x03 0x03 0x01 0x03 0x07 0x01>;":
                "0x13 0x00 0x01 0x13 0x01 0x01 0x13 0x02 0x01 0x13 0x03 0x01 0x13 0x07 0x01>;",
            "power-domains = <0x04 0x00>;": "power-domains = <0x14 0x00>;",
            "memory-region = <0x07>;": "memory-region = <0x17>;",
            "memory-region = <0x08>;": "memory-region = <0x18>;",
            "clocks = <0x01 0x04>;": "clocks = <0x11 0x04>;",
            "mboxes = <0x01 0x0e>;": "mboxes = <0x11 0x0e>;",
            "mboxes = <0x01 0x0c>;": "mboxes = <0x11 0x0c>;",
            "qcom,smem-states = <0x05 0x00>;": "qcom,smem-states = <0x15 0x00>;",
            "interrupts = <0x02 0x00 0x46 0x04>;": "interrupts = <0x12 0x00 0x46 0x04>;",
            "interrupts = <0x02 0x00 0x00 0x44 0x01>;": "interrupts = <0x12 0x00 0x00 0x44 0x01>;",
            "interrupts = <0x02 0x00 0x00 0x08 0x04>;": "interrupts = <0x12 0x00 0x00 0x08 0x04>;",
        }
        text = self.base
        for old, new in decl.items():
            self.assertIn(old, text, old)
            text = text.replace(old, new)
        for old, new in refs.items():
            self.assertIn(old, text, old)
            text = text.replace(old, new)
        # #interrupt-cells debe permanecer intacto (0x02/0x03)
        self.assertIn("#interrupt-cells = <0x02>;", text)
        self.assertIn("#interrupt-cells = <0x03>;", text)
        self.assert_pass(text)

    def test_p8_fixture_dtc_compile_decompile(self):
        dtc = shutil.which("dtc")
        if dtc is None:
            self.skipTest("dtc no disponible")
        tmp = tempfile.mkdtemp(prefix="mpssv2-fixture-")
        dtb = os.path.join(tmp, "positive.dtb")
        dts_out = os.path.join(tmp, "positive-decompiled.dts")
        subprocess.run([dtc, "-I", "dts", "-O", "dtb", "-o", dtb, FIX_POS_SRC],
                       check=True, capture_output=True)
        subprocess.run([dtc, "-I", "dtb", "-O", "dts", "-o", dts_out, dtb],
                       check=True, capture_output=True)
        text = read(dts_out)
        self.assert_pass(text)

    # ------------------------------------------------------------------
    # N: casos negativos
    # ------------------------------------------------------------------

    def test_n1_memory_region_nodo_incorrecto(self):
        # memory-region -> wlan-msa-mem (phandle 0x08, base 0x95500000)
        text = self.base.replace(
            "\t\t\tmemory-region = <0x07>;", "\t\t\tmemory-region = <0x08>;")
        self.assert_fail_contains(text, "memory-region -> modem_mem (0x4b000000)")

    def test_n2_memory_region_base_incorrecta(self):
        text = self.base.replace(
            "reg = <0x00 0x4b000000 0x00 0x7e00000>;",
            "reg = <0x00 0x4c000000 0x00 0x7e00000>;")
        self.assert_fail_contains(text, "memory-region -> modem_mem (0x4b000000)")

    def test_n3_memory_region_size_incorrecto(self):
        text = self.base.replace(
            "reg = <0x00 0x4b000000 0x00 0x7e00000>;",
            "reg = <0x00 0x4b000000 0x00 0x7e00001>;")
        self.assert_fail_contains(text, "memory-region -> modem_mem (0x4b000000)")

    def test_n4_memory_region_phandle_no_resoluble(self):
        text = self.base.replace(
            "\t\t\tmemory-region = <0x07>;", "\t\t\tmemory-region = <0x63>;")
        self.assert_fail_contains(text, "memory-region -> modem_mem (0x4b000000)")

    def test_n5_interrupt_names_orden_incorrecto(self):
        text = self.base.replace(
            '"wdog", "fatal", "ready", "handover", "stop-ack", "shutdown-ack"',
            '"fatal", "wdog", "ready", "handover", "stop-ack", "shutdown-ack"')
        self.assert_fail_contains(text, "seis interrupt-names en orden")

    def test_n6_interrupt_names_falta_shutdown_ack(self):
        text = self.base.replace(
            '"wdog", "fatal", "ready", "handover", "stop-ack", "shutdown-ack"',
            '"wdog", "fatal", "ready", "handover", "stop-ack"')
        self.assert_fail_contains(text, "seis interrupt-names en orden")

    def test_n7_interrupt_names_duplicado(self):
        text = self.base.replace(
            '"wdog", "fatal", "ready", "handover", "stop-ack", "shutdown-ack"',
            '"wdog", "fatal", "ready", "handover", "stop-ack", "stop-ack"')
        self.assert_fail_contains(text, "seis interrupt-names en orden")

    def test_n8_cinco_entradas_interrupts_extended(self):
        # quitar la entrada 6 (shutdown-ack: 0x03 0x07 0x01)
        text = self.base.replace(
            "0x03 0x03 0x01 0x03 0x07 0x01>;",
            "0x03 0x03 0x01>;")
        self.assert_fail_contains(text, "seis entradas interrupts-extended")

    def test_n9_siete_entradas_interrupts_extended(self):
        # anadir una entrada extra (0x03 0x08 0x01)
        text = self.base.replace(
            "0x03 0x07 0x01>;",
            "0x03 0x07 0x01 0x03 0x08 0x01>;")
        self.assert_fail_contains(text, "seis entradas interrupts-extended")

    def test_n10_provider_sin_interrupt_cells(self):
        text = self.base.replace(
            "\t\t\t#interrupt-cells = <0x02>;\n\t\t\tphandle = <0x03>;",
            "\t\t\tphandle = <0x03>;")
        self.assert_fail_contains(text, "seis entradas interrupts-extended")

    def test_n11_trailing_cells_incompletas(self):
        # anadir una celda suelta despues de la ultima entrada
        text = self.base.replace(
            "0x03 0x07 0x01>;",
            "0x03 0x07 0x01 0x03 0x09>;")
        self.assert_fail_contains(text, "seis entradas interrupts-extended")

    def test_n12_provider_smp2p_equivocado(self):
        # slave-kernel deja de llamarse slave-kernel (ya no es SMP2P esperado)
        text = self.base.replace(
            'qcom,entry-name = "slave-kernel";',
            'qcom,entry-name = "other-name";')
        fails = self.assert_fail_contains(
            text, "entrada 2 = modem_smp2p_in bit 0 (fatal)")
        self.assertIn("entrada 6 = modem_smp2p_in bit 7 (shutdown-ack)", fails)

    def test_n13_bit_no_corresponde_nombre(self):
        # "handover" espera bit 2; ponemos bit 5
        text = self.base.replace(
            "0x03 0x02 0x01",
            "0x03 0x05 0x01")
        self.assert_fail_contains(text, "entrada 4 = modem_smp2p_in bit 2 (handover)")

    def test_n14_remoteproc_status_okay(self):
        text = self.base.replace(
            '\t\t\tstatus = "disabled";', '\t\t\tstatus = "okay";')
        self.assert_fail_contains(text, 'remoteproc status = "disabled"')

    def test_n15_dos_power_domains(self):
        text = self.base.replace(
            "\t\t\tpower-domains = <0x04 0x00>;",
            "\t\t\tpower-domains = <0x04 0x00 0x04 0x00>;")
        self.assert_fail_contains(text, "exactamente un power-domain (2 celdas)")


def re_search_single_bracket(text, prop):
    """True si la propiedad aparece en un unico <...> (formato dtc colapsado)."""
    block = MOD.extract_block(text, "remoteproc@6080000")
    val = MOD.extract_property(block, prop)
    return val is not None and val.count("<") == 1


if __name__ == "__main__":
    unittest.main()