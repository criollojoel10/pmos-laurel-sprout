#!/usr/bin/env python3
# Licencia: GPL-3.0-or-later
"""unpack-boot-image.py

Extrae kernel, ramdisk y DTB de un boot.img Android (header v0 o v2) sin
depender de unpack_bootimg. Imprime el cmdline y el tamaño.

Uso:
  scripts/unpack-boot-image.py --boot <boot.img> --out <dir> [--print-cmdline]
"""

import argparse
import os
import struct


def aligned(value, page):
    return (value + page - 1) // page * page


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--boot", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--print-cmdline", action="store_true")
    args = ap.parse_args()

    with open(args.boot, "rb") as fh:
        boot = fh.read()
    if boot[:8] != b"ANDROID!":
        raise SystemExit("ERROR: boot.img sin magic ANDROID!")

    kernel_size, kernel_addr, ramdisk_size, ramdisk_addr, second_size, \
        second_addr, tags_addr, page, version, _ = struct.unpack_from("<10I", boot, 8)
    cmdline = (boot[64:576] + boot[608:1632]).split(b"\0", 1)[0].decode("ascii", "replace")
    if version not in (0, 2):
        raise SystemExit(f"ERROR: header v{version} no soportado")

    header_size = 1660 if version == 2 else 1632
    dtb_size = struct.unpack_from("<I", boot, 1648)[0] if version == 2 else 0

    offset = aligned(header_size, page)
    kernel = boot[offset:offset + kernel_size]
    offset += aligned(kernel_size, page)
    ramdisk = boot[offset:offset + ramdisk_size]
    offset += aligned(ramdisk_size, page)
    dtb = boot[offset:offset + dtb_size] if dtb_size else b""

    if len(kernel) != kernel_size or len(ramdisk) != ramdisk_size:
        raise SystemExit("ERROR: payload truncado")

    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, "kernel"), "wb") as fh:
        fh.write(kernel)
    with open(os.path.join(args.out, "ramdisk"), "wb") as fh:
        fh.write(ramdisk)
    if dtb:
        with open(os.path.join(args.out, "dtb"), "wb") as fh:
            fh.write(dtb)
    if args.print_cmdline:
        print(cmdline)
    else:
        if dtb:
            print(f"dtb: {len(dtb)} bytes")
        print(f"header v{version} page {page} kernel {kernel_size} ramdisk {ramdisk_size}")
        print(f"cmdline: {cmdline}")


if __name__ == "__main__":
    main()
