#!/usr/bin/env python3
#
# Licencia: GPL-3.0-or-later
#
# build-boot-image.py
#
# Ensambla un boot.img Android (header v2) autocontenido, sin dependencias
# externas (no invoca mkbootimg). El formato se validó contra el boot.img
# de fábrica del Xiaomi Mi A3 (laurel_sprout) y contra la salida de
# mkbootimg (android-tools) byte-por-byte.
#
# Formato boot img v2 (AOSP bootimg.h):
#   magic[8]=ANDROID!, 3o enteros, name[16], cmdline[512], os_version,
#   os_patch_level, id[32], extra_cmdline[1024], y al final del header:
#   recovery_dtbo_size, recovery_dtbo_offset, header_size, dtb_size, dtb_addr.
#   (header_size = 1660).
#
# Encode os_version: major<<25 | minor<<18 | patch<<11 | patch_level,
#   donde patch_level = ((year-2000)<<4) | month.
#
# Uso:
#   scripts/build-boot-image.py \
#     --kernel <Image.gz> \
#     --ramdisk <initramfs.cpio.gz> \
#     --dtb <sm6125-xiaomi-laurel-sprout.dtb> \
#     --out <boot.img> \
#     [--base 0x...] [--pagesize N] [--cmdline "..."] \
#     [--kernel-offset 0x...] [--ramdisk-offset 0x...] [--tags-offset 0x...] \
#     [--dtb-offset 0x...] [--os-version major.minor.patch] \
#     [--os-patch-level YYYY-MM]

import argparse
import hashlib
import os
import struct

MAGIC = b"ANDROID!"
HEADER_SIZE = 1660


def parse_os_version(s):
    parts = s.split(".")
    parts += ["0"] * (3 - len(parts))
    return [int(x) for x in parts[:3]]


def encode_os_version(ver, patch_level):
    major, minor, patch = ver
    return (
        (major << 25)
        | (minor << 18)
        | (patch << 11)
        | (patch_level & 0x7FF)
    )


def encode_patch_level(s):
    year, month = s.split("-")
    return ((int(year) - 2000) << 4) | int(month)


def build_header(
    page_size,
    kernel_size,
    ramdisk_size,
    dtb_size,
    base,
    kernel_addr,
    ramdisk_addr,
    tags_addr,
    dtb_addr,
    cmdline,
    os_version,
    os_patch_level,
):
    cmdline_b = cmdline.encode()[:512]
    if len(cmdline_b) < 512:
        cmdline_b += b"\x00" * (512 - len(cmdline_b))
    else:
        cmdline_b = cmdline_b[:512]

    # Layout header v2 (verificado contra boot.img de fábrica y mkbootimg):
    #   magic[8]@0
    #   kernel_size@8, kernel_addr@12, ramdisk_size@16, ramdisk_addr@20,
    #   second_size@24, second_addr@28, tags_addr@32, page_size@36,
    #   header_version@40, os_version@44 (version<<11 | patch_level),
    #   name[16]@48, cmdline[512]@64, id[32]@576, extra_cmdline[1024]@608,
    #   recovery_dtbo_size@1632, recovery_dtbo_offset@1636,
    #   header_size@1644, dtb_size@1648, dtb_addr@1652.
    hdr = bytearray(HEADER_SIZE)
    hdr[0:8] = MAGIC
    struct.pack_into(
        "<10I",
        hdr,
        8,
        kernel_size,
        base + kernel_addr,
        ramdisk_size,
        base + ramdisk_addr,
        0,
        0,
        base + tags_addr,
        page_size,
        2,
        encode_os_version(os_version, os_patch_level),
    )
    # name[16] en 48 queda en ceros
    hdr[64:64 + 512] = cmdline_b
    # --- seccion v2 (offset 1632) ---
    struct.pack_into("<I", hdr, 1632, 0)            # recovery_dtbo_size
    struct.pack_into("<Q", hdr, 1636, 0)            # recovery_dtbo_offset
    struct.pack_into("<I", hdr, 1644, HEADER_SIZE)  # header_size
    struct.pack_into("<I", hdr, 1648, dtb_size)     # dtb_size
    struct.pack_into("<Q", hdr, 1652, base + dtb_addr)  # dtb_addr
    return bytes(hdr)


def build_id_hash(kernel, ramdisk, dtb):
    # id[0:20] = SHA1 sobre (kernel + ramdisk + second + dtb), como hace
    # mkbootimg; el resto de id[32] queda en ceros.
    h = hashlib.sha1()
    h.update(kernel)
    h.update(ramdisk)
    # second vacio
    h.update(dtb)
    return h.digest() + b"\x00" * 12


def pad(b, page_size):
    rem = len(b) % page_size
    if rem == 0:
        return b
    return b + b"\x00" * (page_size - rem)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kernel", required=True)
    ap.add_argument("--ramdisk", required=True)
    ap.add_argument("--dtb", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--page-size", type=lambda x: int(x, 0), default=4096)
    ap.add_argument("--base", type=lambda x: int(x, 0), default=0)
    ap.add_argument("--kernel-offset", type=lambda x: int(x, 0), default=0x8000)
    ap.add_argument("--ramdisk-offset", type=lambda x: int(x, 0), default=0x1000000)
    ap.add_argument("--tags-offset", type=lambda x: int(x, 0), default=0x100)
    ap.add_argument("--dtb-offset", type=lambda x: int(x, 0), default=0x1F00000)
    ap.add_argument("--cmdline", default="")
    ap.add_argument("--os-version", default="12.0.0")
    ap.add_argument("--os-patch-level", default="2026-08")
    args = ap.parse_args()

    with open(args.kernel, "rb") as f:
        kernel = f.read()
    with open(args.ramdisk, "rb") as f:
        ramdisk = f.read()
    with open(args.dtb, "rb") as f:
        dtb = f.read()

    ver = parse_os_version(args.os_version)
    patch = encode_patch_level(args.os_patch_level)

    page = args.page_size
    header = build_header(
        page,
        len(kernel),
        len(ramdisk),
        len(dtb),
        args.base,
        args.kernel_offset,
        args.ramdisk_offset,
        args.tags_offset,
        args.dtb_offset,
        args.cmdline,
        ver,
        patch,
    )

    out = bytearray()
    out += pad(header, page)
    out += pad(kernel, page)
    out += pad(ramdisk, page)
    # No second
    out += pad(dtb, page)

    # id[8] (32 bytes) en offset 576 = SHA1(kernel+ramdisk+second+dtb)
    out[576:576 + 32] = build_id_hash(kernel, ramdisk, dtb)

    out_dir = os.path.dirname(os.path.abspath(args.out))
    if out_dir and not os.path.isdir(out_dir):
        os.makedirs(out_dir, exist_ok=True)
    with open(args.out, "wb") as f:
        f.write(out)
    print(
        "boot image escrito: %s (%d bytes, header v2, page %d)"
        % (args.out, len(out), page)
    )


if __name__ == "__main__":
    main()