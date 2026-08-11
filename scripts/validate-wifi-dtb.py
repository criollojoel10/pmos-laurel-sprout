#!/usr/bin/env python3
# Licencia: GPL-3.0-or-later
"""validate-wifi-dtb.py

Valida el nodo wifi@c800000 (qcom,wcn3990-wifi) en un DTS decompilado de
SM6125, resolviendo phandles a sus targets (MSA, apps_smmu, reguladores).

Uso:
  scripts/validate-wifi-dtb.py --dts <laurel.dts>
"""

import argparse
import re
import sys


def parse_nodes(text):
    """Devuelve {name: {phandle, reg, compat, vmin, vmax, iommu_cells}}."""
    nodes = {}
    # Cada nodo: "name { ... phandle = <0x..>; ... }" (no anidado, basta para
    # nuestro caso: los targets referenciados son nodos hoja).
    for m in re.finditer(r"^\s*([\w@.-]+)\s*\{([^}]*)\};", text, re.M):
        name, body = m.group(1), m.group(2)
        ph = re.search(r"phandle = <(0x[0-9a-f]+)>;", body)
        reg = re.search(r"reg = <([^>]+)>;", body)
        compat = re.search(r'compatible = "([^"]+)";', body)
        vmin = re.search(r"regulator-min-microvolt = <(0x[0-9a-f]+)>;", body)
        vmax = re.search(r"regulator-max-microvolt = <(0x[0-9a-f]+)>;", body)
        cells = re.search(r"#iommu-cells = <(0x[0-9a-f]+)>;", body)
        nodes[name] = {
            "phandle": int(ph.group(1), 16) if ph else None,
            "reg": [int(x, 0) for x in reg.group(1).split()] if reg else None,
            "compat": compat.group(1) if compat else None,
            "vmin": int(vmin.group(1), 16) if vmin else None,
            "vmax": int(vmax.group(1), 16) if vmax else None,
            "iommu_cells": int(cells.group(1), 16) if cells else None,
        }
    return nodes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dts", required=True)
    args = ap.parse_args()
    text = open(args.dts, encoding="utf-8").read()

    nodes = parse_nodes(text)
    by_ph = {v["phandle"]: (k, v) for k, v in nodes.items() if v["phandle"]}

    fail = []
    def ok(label, cond):
        print(f"[wifi-dtb] {'OK' if cond else 'FALLO'}: {label}")
        if not cond:
            fail.append(label)

    m = re.search(r"\bwifi@c800000\s*\{([^}]*)\};", text, re.M)
    ok("nodo wifi@c800000", m is not None)
    if not m:
        sys.exit("ERROR: sin nodo wifi@c800000")
    body = m.group(1)

    ok('compatible "qcom,wcn3990-wifi"', 'compatible = "qcom,wcn3990-wifi"' in body)
    reg = re.search(r"reg = <0x0?c800000 0x800000>;", body)
    ok("reg 0xc800000 0x800000", reg is not None)

    msa = re.search(r"memory-region = <(0x[0-9a-f]+)>;", body)
    if msa:
        target = by_ph.get(int(msa.group(1), 16), (None, None))[1]
        ok("memory-region -> memory@53300000 (2 MiB)",
           target is not None and target["reg"] is not None
           and 0x53300000 in target["reg"] and 0x200000 in target["reg"])
    else:
        ok("memory-region -> memory@53300000", False)

    iom = re.search(r"iommus = <(0x[0-9a-f]+) (0x[0-9a-f]+) (0x[0-9a-f]+)>;", body)
    if iom:
        sid = int(iom.group(2), 16)
        target = by_ph.get(int(iom.group(1), 16), (None, None))[1]
        ok("iommus SID 0x80", sid == 0x80)
        ok("iommus -> apps_smmu (iommu@c600000, cells=2)",
           target is not None and target["reg"] and target["reg"][0] == 0xC600000
           and target["iommu_cells"] == 2)
    else:
        ok("iommus SID 0x80 / apps_smmu", False)

    irqs = re.search(r"interrupts = <([^>]+)>;", body)
    if irqs:
        vals = irqs.group(1).split()
        spi = vals[1::3] if len(vals) >= 36 else []
        spi = [int(x, 0) for x in spi]
        ok("12 CE IRQ 358..369 LEVEL_HIGH",
           len(spi) == 12 and spi == list(range(358, 370))
           and all(int(t, 0) == 4 for t in vals[2::3]))
    else:
        ok("12 CE IRQ 358..369 LEVEL_HIGH", False)

    supplies = {
        "vdd-0.8-cx-mx-supply": ("L8A", 400000, 728000),
        "vdd-1.8-xo-supply": ("L16A", 1800000, 1904000),
        "vdd-1.3-rfa-supply": ("L17A", 1248000, 1304000),
        "vdd-3.3-ch0-supply": ("L23A", 3000000, 3400000),
    }
    for prop, (label, vmin, vmax) in supplies.items():
        m2 = re.search(rf"{re.escape(prop)} = <(0x[0-9a-f]+)>;", body)
        if m2:
            target = by_ph.get(int(m2.group(1), 16), (None, None))[1]
            ok(f"{prop} -> {label}",
               target is not None and target["vmin"] == vmin
               and target["vmax"] == vmax)
        else:
            ok(f"{prop} -> {label}", False)

    ok("framebuffer@5c000000", "framebuffer@5c000000" in text)

    if fail:
        print("ERROR: validación DTB WCN3990 falló:", ", ".join(fail))
        sys.exit(1)
    print("OK: DTB WCN3990 validado (phandles resueltas)")


if __name__ == "__main__":
    main()
