#!/usr/bin/env python3
# Licencia: GPL-3.0-or-later
"""validate-mpss-v2-final.py

Valida el DTB FINAL decompilado (final-v2.dts) de la variante WCN3990 v2
(MPSS transport) de SM6125, resolviendo phandles a sus targets.

Contexto: tras ensamblar el boot.img, el DTB final se decompila con dtc.
dtc sustituye los labels por phandles numericas y resuelve las referencias.
Este script valida la SEMANTICA resultante, no los literales de los labels.

El parser es SEMANTICO, no de coincidencias textuales fragiles:

  - Las propiedades se extraen por nombre hasta el ';' final, soportando
    multiples lineas, tabs, espacios, listas <...> y listas de strings.
  - Las celdas numericas se convierten con int(token, 0): 0, 0x0, 0x00 y
    0x00000000 son equivalentes y NO se comparan como texto.
  - interrupts-extended se SEGMENTA derivando #interrupt-cells de cada
    provider (phandle + N celdas), en vez de contar ocurrencias de "<0x".
  - Las strings se DECODIFICAN (decode_dts_string) y las listas de strings
    se interpretan semanticamente: tanto la forma "a", "b", "c" como la
    forma "a\\0b\\0c" con NUL separador (emitida por dtc en CI).

Nodos validados (phandle-aware):
  - remoteproc@6080000 : compatible qcom,sm8150-mpss-pas, status disabled,
    EXACTAMENTE un power-domain (phandle->rpmpd qcom,sm6125-rpmpd, cell 0),
    sin power-domain-names, seis interrupt-names en orden, memory-region
    -> modem_mem (base 0x4b000000, size 0x7e00000), glink-edge presente.
  - smp2p-mpss           : con entries master-kernel, slave-kernel y wlan.
  - wifi@c800000         : compatible qcom,wcn3990-wifi (v1 conservada).

interrupts-extended se valida por segmentacion por provider:
  - entrada 1 : GIC (intc, arm,gic-v3) con spec (GIC_SPI, SPI 307, EDGE_RISING).
  - entradas 2-6 : modem_smp2p_in (slave-kernel) con bit 0..3 y 7
    (fatal, ready, handover, stop-ack, shutdown-ack), flags EDGE_RISING.

Uso:
  scripts/validate-mpss-v2-final.py --dts <final-v2.dts> [--expect-mpss <disabled|okay>]

El estado MPSS esperado es configurable:
  - disabled (default, variante v2): remoteproc@6080000 con status = "disabled"
    y el board SIN override.
  - okay (variante v3): remoteproc@6080000 con status = "okay" (enable de
    placa &remoteproc_mpss). El resto de la semantica (interrupts, power
    domains, memory-region, glink-edge, smp2p) es identica y sigue validandose.
"""

import argparse
import re
import sys

VDDCX_CELL = 0
MODEM_MEM_BASE = 0x4B000000
MODEM_MEM_SIZE = 0x07E00000
EXPECTED_INTERRUPT_NAMES = [
    "wdog", "fatal", "ready", "handover", "stop-ack", "shutdown-ack",
]
# Entrada 1 (wdog): GIC — (GIC_SPI, SPI, IRQ_TYPE_EDGE_RISING)
EXPECTED_GIC_SPEC = (0, 307, 1)
# Entradas 2-6 (fatal..shutdown-ack): modem_smp2p_in — (bit, IRQ_TYPE_EDGE_RISING)
EXPECTED_SMP2P_BITS = (0, 1, 2, 3, 7)
EXPECTED_SMP2P_FLAGS = 1


# ---------------------------------------------------------------------------
# Parser semantico de DTS decompilado
# ---------------------------------------------------------------------------

def strip_comments(text):
    """Elimina comentarios /* */ y // del texto DTS."""
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"//[^\n]*", "", text)
    return text


def extract_block(text, name):
    """Devuelve el bloque 'name { ... }' completo (con balanceo de llaves)."""
    m = re.search(r"(?m)^(\s*)(?:[\w@.-]+:\s*)?" + re.escape(name) + r"\s*\{", text)
    if not m:
        return None
    i = m.end()
    depth = 1
    while i < len(text) and depth > 0:
        c = text[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        i += 1
    return text[m.start():i]


def extract_property(block, name):
    """Devuelve el valor crudo de 'name = ...;' dentro de block.

    Lee desde 'name = ' hasta el ';' final, ignorando ';' dentro de strings
    y saltando comentarios. Soporta multiline y listas <...>.
    """
    m = re.search(r"(?m)^\s*" + re.escape(name) + r"\s*=\s*", block)
    if not m:
        return None
    out = []
    i = m.end()
    n = len(block)
    while i < n:
        c = block[i]
        if c == '"':
            j = block.find('"', i + 1)
            if j == -1:
                return None
            out.append(block[i:j + 1])
            i = j + 1
            continue
        if c == "/":
            if block.startswith("/*", i):
                j = block.find("*/", i + 2)
                i = j + 2 if j != -1 else n
                continue
            if block.startswith("//", i):
                j = block.find("\n", i + 2)
                i = j + 1 if j != -1 else n
                continue
        if c == ";":
            break
        if c == "{":
            return None
        out.append(c)
        i += 1
    return "".join(out)


def parse_cells(value):
    """Celdas numericas DTS -> lista de ints.

    0, 0x0, 0x00 y 0x00000000 se consideran equivalentes (int(token, 0)).
    Ignora strings y cualquier no-numero.
    """
    if value is None:
        return []
    no_strings = re.sub(r'"[^"]*"', "", value)
    toks = re.findall(r"0[xX][0-9a-fA-F]+|\d+", no_strings)
    return [int(t, 0) for t in toks]


_DTS_ESCAPES = {
    "\\": "\\",
    '"': '"',
    "n": "\n",
    "r": "\r",
    "t": "\t",
}


def decode_dts_string(raw):
    r"""Decodifica una string DTS (sin comillas) a su valor real.

    Soporta de forma controlada los escapes que dtc puede emitir:
      \\  -> backslash
      \"  -> comilla
      \n, \r, \t  -> control
      \0  -> NUL (1-3 digitos octales: \0 .. \377)
      \xHH -> byte hexadecimal (exactamente dos digitos)

    Rechaza (ValueError):
      - escape incompleto al final de la string;
      - \x sin dos digitos hexadecimales validos;
      - octal con digitos fuera de rango (8/9) o > 3 digitos;
      - secuencia de escape desconocida.
    """
    out = []
    i = 0
    n = len(raw)
    while i < n:
        c = raw[i]
        if c != "\\":
            out.append(c)
            i += 1
            continue
        if i + 1 >= n:
            raise ValueError("escape incompleto al final: %r" % raw)
        e = raw[i + 1]
        if e in _DTS_ESCAPES:
            out.append(_DTS_ESCAPES[e])
            i += 2
            continue
        if e == "x":
            hexd = raw[i + 2:i + 4]
            if len(hexd) != 2 or not re.fullmatch(r"[0-9a-fA-F]{2}", hexd):
                raise ValueError("\\x sin dos digitos hex validos en %r" % raw)
            out.append(chr(int(hexd, 16)))
            i += 4
            continue
        if e in "01234567":
            m = re.match(r"[0-7]{1,3}", raw[i + 1:])
            octal = m.group(0)
            if octal[0] not in "01234567" or int(octal, 8) > 0o377:
                raise ValueError("octal fuera de rango en %r" % raw)
            out.append(chr(int(octal, 8)))
            i += 1 + len(octal)
            continue
        raise ValueError("secuencia de escape desconocida \\%s en %r" % (e, raw))
    return "".join(out)


def parse_strings(value):
    """Lista de strings DTS -> lista de str decodificadas.

    Soporta las dos representaciones reales de dtc:
      - forma estandar:  "a", "b", "c"  (multiline, tabs, espacios, comentarios);
      - forma NUL:       "a\\0b\\0c"    (una string con NUL separador).

    Cada string quoted se decodifica con decode_dts_string() y se divide por
    el NUL real (\"\\x00\"). Se rechaza (ValueError) si la division por NUL
    produce elementos vacios (NUL inicial, doble NUL o NUL final) o si una
    string no puede decodificarse.
    """
    if value is None:
        return []
    result = []
    for raw in re.findall(r'"([^"]*)"', value):
        decoded = decode_dts_string(raw)
        parts = decoded.split("\x00")
        if any(p == "" for p in parts):
            raise ValueError("string con NUL inicial/doble/final: %r" % raw)
        result.extend(parts)
    return result


def safe_parse_strings(value):
    """parse_strings() que nunca lanza: ante un valor invalido devuelve []."""
    try:
        return parse_strings(value)
    except ValueError:
        return []


def parse_nodes(text):
    """Todos los nodos con phandle -> [(phandle, nombre, bloque), ...]."""
    text = strip_comments(text)
    nodes = []
    for m in re.finditer(r"(?m)^\s*(?:[\w@.-]+:\s*)?([\w@.-]+)\s*\{", text):
        start = m.start()
        i = m.end()
        depth = 1
        while i < len(text) and depth > 0:
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
            i += 1
        block = text[start:i]
        ph = re.search(r"phandle\s*=\s*<(0x[0-9a-fA-F]+)>;", block)
        if ph:
            nodes.append((int(ph.group(1), 16), m.group(1), block))
    return nodes


def segment_interrupts(cells, by_ph):
    """Segmenta la lista plana de celdas de interrupts-extended en entradas.

    Cada entrada = 1 celda de phandle + N celdas segun '#interrupt-cells'
    del provider. Devuelve lista de (phandle, nombre_provider, spec|None).
    Si un phandle no resuelve o el provider no define #interrupt-cells,
    la entrada queda marcada con spec=None (semantica no validable).
    """
    entries = []
    pos = 0
    n = len(cells)
    while pos < n:
        ph = cells[pos]
        prov = by_ph.get(ph)
        if prov is None:
            entries.append((ph, None, None))
            break
        ic = parse_cells(extract_property(prov[1], "#interrupt-cells"))
        if not ic:
            entries.append((ph, prov[0], None))
            break
        icn = ic[0]
        if pos + 1 + icn > n:
            entries.append((ph, prov[0], cells[pos + 1:]))
            break
        entries.append((ph, prov[0], cells[pos + 1:pos + 1 + icn]))
        pos += 1 + icn
    return entries


# ---------------------------------------------------------------------------
# Validacion
# ---------------------------------------------------------------------------

def validate(text, expect_mpss="disabled"):
    """Ejecuta todos los gates; devuelve lista de labels fallidos (vacia si OK)."""
    by_ph = {ph: (name, block) for ph, name, block in parse_nodes(text)}
    fail = []

    def ok(label, cond, raw=None, parsed=None, expected=None, node=None):
        status = "OK" if cond else "FALLO"
        line = "[mpss-v2-final] {0}: {1}".format(status, label)
        if not cond:
            if raw is not None:
                line += "\n    raw: {0}".format(str(raw).strip()[:300])
            if parsed is not None:
                line += "\n    parsed: {0}".format(parsed)
            if expected is not None:
                line += "\n    expected: {0}".format(expected)
            if node is not None:
                line += "\n    node: {0}".format(node)
            fail.append(label)
        print(line)

    # --- wifi v1 (0001) conservada ---
    wifi = extract_block(text, "wifi@c800000")
    ok("wifi@c800000 presente (v1)", wifi is not None, node="wifi@c800000")
    if wifi:
        ok('compatible "qcom,wcn3990-wifi"',
           'compatible = "qcom,wcn3990-wifi"' in wifi,
           node="wifi@c800000")
        st = safe_parse_strings(extract_property(wifi, "status"))
        ok('wifi status = "okay"', st == ["okay"],
           parsed=st, expected=["okay"], node="wifi@c800000")

    # --- smp2p-mpss y entries ---
    smp = extract_block(text, "smp2p-mpss")
    ok("smp2p-mpss presente", smp is not None, node="smp2p-mpss")
    if smp:
        ok('entry "master-kernel"', 'qcom,entry-name = "master-kernel"' in smp,
           node="smp2p-mpss")
        ok('entry "slave-kernel"', 'qcom,entry-name = "slave-kernel"' in smp,
           node="smp2p-mpss")
        ok('entry "wlan"', 'qcom,entry-name = "wlan"' in smp,
           node="smp2p-mpss")

    # --- remoteproc@6080000 ---
    rp = extract_block(text, "remoteproc@6080000")
    ok("remoteproc@6080000 presente", rp is not None, node="remoteproc@6080000")
    if not rp:
        return fail

    ok('compatible "qcom,sm8150-mpss-pas"',
       'compatible = "qcom,sm8150-mpss-pas"' in rp,
       node="remoteproc@6080000")

    st = safe_parse_strings(extract_property(rp, "status"))
    ok('remoteproc status = "%s"' % expect_mpss, st == [expect_mpss],
       parsed=st, expected=[expect_mpss], node="remoteproc@6080000")

    # power-domains: exactamente un par (phandle, cell) -> rpmpd VDDCX=0
    pd = parse_cells(extract_property(rp, "power-domains"))
    pd_ok = len(pd) == 2
    target = by_ph.get(pd[0], (None, None))[1] if pd else None
    ok("exactamente un power-domain (2 celdas)", pd_ok,
       parsed=pd, expected="<phandle cell>", node="remoteproc@6080000")
    ok("power-domain -> rpmpd qcom,sm6125-rpmpd",
       pd_ok and target is not None
       and 'compatible = "qcom,sm6125-rpmpd"' in target,
       parsed=pd, expected="phandle -> qcom,sm6125-rpmpd",
       node="remoteproc@6080000")
    ok("power-domain cell = VDDCX (0)",
       pd_ok and pd[1] == VDDCX_CELL,
       parsed=pd, expected="cell[1] == %d" % VDDCX_CELL,
       node="remoteproc@6080000")

    ok("sin power-domain-names",
       extract_property(rp, "power-domain-names") is None,
       node="remoteproc@6080000")

    # interrupt-names: lista semantica exacta (multiline/espacios/NUL no afectan)
    inm_raw = extract_property(rp, "interrupt-names")
    inm = []
    inm_err = None
    inm_quoted = []
    inm_decoded = []
    if inm_raw is not None:
        inm_quoted = re.findall(r'"([^"]*)"', inm_raw)
        try:
            for raw in inm_quoted:
                inm_decoded.append(decode_dts_string(raw))
            inm = parse_strings(inm_raw)
        except ValueError as exc:
            inm_err = str(exc)
    inm_ok = inm == EXPECTED_INTERRUPT_NAMES and inm_err is None
    ok("seis interrupt-names en orden", inm_ok,
       raw=inm_raw, parsed=inm, expected=EXPECTED_INTERRUPT_NAMES,
       node="remoteproc@6080000")
    if not inm_ok:
        print("    quoted:   {0}".format(inm_quoted))
        print("    decoded:  {0}".format(inm_decoded))
        if inm_err:
            print("    error:    {0}".format(inm_err))

    # interrupts-extended: segmentacion por provider, no por "<0x"
    ie_raw = extract_property(rp, "interrupts-extended")
    ie = parse_cells(ie_raw)
    entries = segment_interrupts(ie, by_ph)
    ok("seis entradas interrupts-extended", len(entries) == 6,
       raw=ie_raw, parsed=[(e[0], e[1], e[2]) for e in entries],
       expected="6 entradas", node="remoteproc@6080000")

    # entrada 1 -> GIC (wdog, SPI 307)
    e1 = entries[0] if entries else (None, None, None)
    gic_prov = by_ph.get(e1[0], (None, None))[1] if e1[0] is not None else None
    ok("entrada 1 = GIC (wdog, SPI 307)",
       e1[2] is not None and list(e1[2]) == list(EXPECTED_GIC_SPEC)
       and gic_prov is not None and 'compatible = "arm,gic' in gic_prov,
       parsed=(e1[1], e1[2]), expected=("intc/arm,gic-v3", list(EXPECTED_GIC_SPEC)),
       node="intc")

    # entradas 2-6 -> modem_smp2p_in (slave-kernel) con bits 0..3,7
    if len(entries) >= 6:
        for idx, (ph, pname, spec) in enumerate(entries[1:6], start=1):
            exp_bit = EXPECTED_SMP2P_BITS[idx - 1]
            prov = by_ph.get(ph, (None, None))[1] or ""
            is_smp2p = 'qcom,entry-name = "slave-kernel"' in prov
            bit_ok = (spec is not None and len(spec) == 2
                      and spec[0] == exp_bit and spec[1] == EXPECTED_SMP2P_FLAGS)
            ok("entrada %d = modem_smp2p_in bit %d (%s)"
               % (idx + 1, exp_bit, EXPECTED_INTERRUPT_NAMES[idx]),
               is_smp2p and bit_ok,
               parsed=(pname, spec),
               expected=("slave-kernel", [exp_bit, EXPECTED_SMP2P_FLAGS]),
               node="slave-kernel")

    # memory-region -> modem_mem (base 0x4b000000, size 0x7e00000)
    mr_raw = extract_property(rp, "memory-region")
    mr = parse_cells(mr_raw)
    mr_ok = len(mr) == 1
    mtarget = by_ph.get(mr[0], (None, None))[1] if mr_ok else None
    mreg = parse_cells(extract_property(mtarget, "reg")) if mtarget else []
    reg_ok = (len(mreg) == 4 and mreg[0] == 0 and mreg[1] == MODEM_MEM_BASE
              and mreg[2] == 0 and mreg[3] == MODEM_MEM_SIZE)
    ok("memory-region -> modem_mem (0x4b000000)",
       mr_ok and mtarget is not None and reg_ok,
       raw=mr_raw,
       parsed={"memory-region": mr, "target_reg": mreg},
       expected={"memory-region": ["phandle"],
                 "target_reg": [0, 0x4b000000, 0, 0x7e00000]},
       node="memory@4b000000")

    # glink-edge presente
    ok("glink-edge presente", "glink-edge" in rp, node="remoteproc@6080000")

    return fail


def _finish(fail, expect_mpss="disabled"):
    if fail:
        print("ERROR: validación DTB final MPSS v2 falló:", ", ".join(fail))
        sys.exit(1)
    print("OK: DTB final MPSS v2 validado (semántica y phandles, status=%s)"
          % expect_mpss)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dts", required=True)
    ap.add_argument("--expect-mpss", choices=("disabled", "okay"),
                    default="disabled",
                    help="estado MPSS esperado en remoteproc@6080000")
    args = ap.parse_args()
    text = open(args.dts, encoding="utf-8").read()
    fail = validate(text, expect_mpss=args.expect_mpss)
    _finish(fail, expect_mpss=args.expect_mpss)


if __name__ == "__main__":
    main()