#!/usr/bin/env python3
# Licencia: GPL-3.0-or-later
"""validate-mpss-v2-final.py

Valida el DTB FINAL decompilado (final-v2.dts) de la variante WCN3990 v2
(MPSS transport) de SM6125, resolviendo phandles a sus targets.

Contexto: tras ensamblar el boot.img, el DTB final se decompila con dtc.
dtc sustituye los labels por phandles numericas y resuelve las referencias.
Este script valida la SEMANTICA resultante, no los literales de los labels.

Nodos validados (phandle-aware):
  - remoteproc@6080000 : compatible qcom,sm8150-mpss-pas, status disabled,
    EXACTAMENTE un power-domain (phandle->rpmpd qcom,sm6125-rpmpd, cell 0),
    sin power-domain-names, seis interrupt-names en orden, memory-region
    -> modem_mem (reg 0x4b000000), glink-edge presente.
  - smp2p-mpss           : con entries master-kernel, slave-kernel y wlan.
  - wifi@c800000         : compatible qcom,wcn3990-wifi (v1 conservada).

Uso:
  scripts/validate-mpss-v2-final.py --dts <final-v2.dts>
"""

import argparse
import re
import sys

VDDCX_CELL = 0
MODEM_MEM_REG = 0x4B000000
EXPECTED_INTERRUPT_NAMES = [
    "wdog", "fatal", "ready", "handover", "stop-ack", "shutdown-ack",
]


def parse_nodes(text):
    """Devuelve {addressable_name: {phandle, body}} para nodos con phandle.

    Soporta el formato decompilado 'label: nodename { ... };' y nodos
    anidados (bloque completo con balanceo de llaves vía extract_block).
    """
    nodes = {}
    for m in re.finditer(r"(?m)^\s*(?:[\w@.-]+:\s*)?([\w@.-]+)\s*\{", text):
        name = m.group(1)
        if name in nodes:
            continue
        block = extract_block(text, name)
        if block is None:
            continue
        ph = re.search(r"phandle = <(0x[0-9a-f]+)>;", block)
        nodes[name] = {
            "phandle": int(ph.group(1), 16) if ph else None,
            "body": block,
        }
    return nodes


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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dts", required=True)
    args = ap.parse_args()
    text = open(args.dts, encoding="utf-8").read()

    nodes = parse_nodes(text)
    by_ph = {v["phandle"]: (k, v) for k, v in nodes.items() if v["phandle"]}

    fail = []

    def ok(label, cond):
        print(f"[mpss-v2-final] {'OK' if cond else 'FALLO'}: {label}")
        if not cond:
            fail.append(label)

    # --- wifi v1 (0001) conservada ---
    wifi = re.search(r"\bwifi@c800000\s*\{([^}]*)\};", text, re.M)
    ok("wifi@c800000 presente (v1)", wifi is not None)
    if wifi:
        ok('compatible "qcom,wcn3990-wifi"', 'compatible = "qcom,wcn3990-wifi"' in wifi.group(1))
        ok("wifi status = \"okay\"", re.search(r'status = "okay"', wifi.group(1)) is not None)

    # --- smp2p-mpss y entries ---
    smp = extract_block(text, "smp2p-mpss")
    ok("smp2p-mpss presente", smp is not None)
    if smp:
        ok('entry "master-kernel"', 'qcom,entry-name = "master-kernel"' in smp)
        ok('entry "slave-kernel"', 'qcom,entry-name = "slave-kernel"' in smp)
        ok('entry "wlan"', 'qcom,entry-name = "wlan"' in smp)

    # --- remoteproc@6080000 ---
    rp = extract_block(text, "remoteproc@6080000")
    ok("remoteproc@6080000 presente", rp is not None)
    if not rp:
        ok("resto de gates remoteproc", False)
        _finish(fail)
        return

    ok('compatible "qcom,sm8150-mpss-pas"',
       'compatible = "qcom,sm8150-mpss-pas"' in rp)

    # status: debe quedar disabled (0002 lo deja disabled; board no lo habilita)
    st = re.search(r'status = "([^"]+)";', rp)
    ok("remoteproc status = \"disabled\"", st is not None and st.group(1) == "disabled")

    # power-domains: exactamente un par (phandle, cell) -> rpmpd VDDCX=0
    pd = re.search(r"power-domains = <([^>]+)>;", rp)
    if pd:
        vals = pd.group(1).split()
        ph_int = int(vals[0], 0)
        target = by_ph.get(ph_int, (None, None))[1]
        ok("exactamente un power-domain (2 celdas)",
           len(vals) == 2)
        ok("power-domain -> rpmpd qcom,sm6125-rpmpd",
           target is not None
           and 'compatible = "qcom,sm6125-rpmpd"' in target["body"])
        ok("power-domain cell = VDDCX (0)",
           len(vals) == 2 and int(vals[1], 0) == VDDCX_CELL)
    else:
        ok("power-domains presente", False)

    ok("sin power-domain-names", "power-domain-names" not in rp)

    # interrupt-names en orden
    inm = re.search(r"interrupt-names = ([^;]+);", rp)
    if inm:
        names = [x.strip().strip('"') for x in inm.group(1).split(",")]
        ok("seis interrupt-names en orden",
           names == EXPECTED_INTERRUPT_NAMES)
        # debe haber exactamente 6 entradas interrupts-extended
        # (la propiedad abarca varias lineas con entradas <0x..> separadas por comas)
        iem = re.search(r"interrupts-extended = (.*?);", rp, re.S)
        if iem:
            # cada entrada empieza por "<0x" (una por phandle/target)
            entries = re.findall(r"<0x", iem.group(1))
            ok("seis entradas interrupts-extended", len(entries) == 6)
        else:
            ok("seis entradas interrupts-extended", False)
    else:
        ok("interrupt-names en orden", False)

    # memory-region -> modem_mem (reg 0x4b000000)
    mr = re.search(r"memory-region = <(0x[0-9a-f]+)>;", rp)
    if mr:
        target = by_ph.get(int(mr.group(1), 16), (None, None))[1]
        reg = re.search(r"reg = <0x0 0x([0-9a-f]+) 0x0 0x([0-9a-f]+)>;", target["body"]) if target else None
        ok("memory-region -> modem_mem (0x4b000000)",
           target is not None and reg is not None
           and int(reg.group(1), 16) == MODEM_MEM_REG)
    else:
        ok("memory-region -> modem_mem (0x4b000000)", False)

    # glink-edge presente
    ok("glink-edge presente", "glink-edge" in rp)

    _finish(fail)


def _finish(fail):
    if fail:
        print("ERROR: validación DTB final MPSS v2 falló:", ", ".join(fail))
        sys.exit(1)
    print("OK: DTB final MPSS v2 validado (semántica y phandles)")


if __name__ == "__main__":
    main()
