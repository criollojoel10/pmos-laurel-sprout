#!/usr/bin/env python3
# Licencia: GPL-3.0-or-later
"""Compara propiedades USB/display/ramos del DTS de Laurel 6.1 y 7.1."""

import argparse
import re


NODES = {
    "qusb2_phy": ("phy@1613000", "phy@1613000"),
    "dwc3_wrapper": ("usb@4ef8800", "usb@4ef8800"),
    "dwc3_core": ("usb@4e00000", "usb@4e00000"),
    "extcon": ("usb-id", "usb-id"),
    "framebuffer": ("framebuffer@5c000000", "framebuffer@5c000000"),
    "ramoops": ("ramoops@ffc00000", "ramoops@ffc00000"),
}


def node_body(text, name):
    match = re.search(rf"(?:^|\n)\s*{re.escape(name)}\s*\{{", text)
    if not match:
        return None
    start = match.end()
    depth = 1
    pos = start
    while depth and pos < len(text):
        if text[pos] == "{":
            depth += 1
        elif text[pos] == "}":
            depth -= 1
        pos += 1
    return text[start:pos - 1] if depth == 0 else None


def props(body):
    if body is None:
        return {}
    result = {}
    for line in body.splitlines():
        match = re.match(r"\s*([\w,#.-]+)\s*=\s*(.*?);\s*$", line)
        if match:
            result[match.group(1)] = match.group(2)
    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--six-one", required=True)
    ap.add_argument("--seven-one", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    old = open(args.six_one, encoding="utf-8").read()
    new = open(args.seven_one, encoding="utf-8").read()
    lines = ["# Comparación semántica Laurel 6.1 → 7.1", ""]
    for label, (old_name, new_name) in NODES.items():
        old_props = props(node_body(old, old_name))
        new_props = props(node_body(new, new_name))
        lines.append(f"## {label}")
        if not old_props:
            lines.append("- 6.1: nodo no encontrado en el DTS suministrado")
        if not new_props:
            lines.append("- 7.1: nodo no encontrado")
        for key in sorted(set(old_props) | set(new_props)):
            if old_props.get(key) == new_props.get(key):
                continue
            lines.append(f"- `{key}`: 6.1=`{old_props.get(key, '<ausente>')}`; "
                         f"7.1=`{new_props.get(key, '<ausente>')}`")
        if old_props and new_props and all(old_props.get(k) == new_props.get(k)
                                           for k in set(old_props) | set(new_props)):
            lines.append("- sin diferencias textuales de propiedades")
        lines.append("")
    with open(args.out, "w", encoding="utf-8") as stream:
        stream.write("\n".join(lines))
    print(open(args.out, encoding="utf-8").read(), end="")


if __name__ == "__main__":
    main()
