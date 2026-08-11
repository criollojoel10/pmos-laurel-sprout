#!/usr/bin/env python3
# Licencia: GPL-3.0-or-later
"""Extrae y valida un boot.img v2 sin depender de unpack_bootimg."""

import argparse
import gzip
import hashlib
import os
import struct
import subprocess
import tempfile


def aligned(value, page):
    return (value + page - 1) // page * page


def sha(path):
    digest = hashlib.sha256()
    with open(path, "rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def extract_newc(ramdisk, out):
    with gzip.open(ramdisk, "rb") as source, tempfile.NamedTemporaryFile() as cpio:
        cpio.write(source.read())
        cpio.flush()
        subprocess.run(["cpio", "-idm", "--no-absolute-filenames"], cwd=out,
                       stdin=open(cpio.name, "rb"), check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--boot", required=True)
    parser.add_argument("--kernel", required=True)
    parser.add_argument("--ramdisk", required=True)
    parser.add_argument("--dtb", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)
    boot = open(args.boot, "rb").read()
    if boot[:8] != b"ANDROID!":
        raise SystemExit("ERROR: boot.img sin magic ANDROID!")
    kernel_size, _, ramdisk_size, _, _, _, _, page, version, _ = struct.unpack_from("<10I", boot, 8)
    if version != 2 or page != 4096:
        raise SystemExit(f"ERROR: header esperado v2/page4096, recibido v{version}/page{page}")
    dtb_size = struct.unpack_from("<I", boot, 1648)[0]
    cmdline = (boot[64:576] + boot[608:1632]).split(b"\0", 1)[0].decode("ascii")
    offset = aligned(1660, page)
    kernel = boot[offset:offset + kernel_size]
    offset += aligned(kernel_size, page)
    ramdisk = boot[offset:offset + ramdisk_size]
    offset += aligned(ramdisk_size, page)
    dtb = boot[offset:offset + dtb_size]
    if len(kernel) != kernel_size or len(ramdisk) != ramdisk_size or len(dtb) != dtb_size:
        raise SystemExit("ERROR: payload truncado en boot.img")
    if len(boot) > 67108864:
        raise SystemExit("ERROR: boot.img excede 64 MiB")
    required = ["console=ttyMSM0,115200n8", "console=tty0", "consoleblank=0"]
    missing = [item for item in required if item not in cmdline]
    if missing:
        raise SystemExit(f"ERROR: cmdline sin {', '.join(missing)}")
    extracted_kernel = os.path.join(args.out, "kernel")
    extracted_ramdisk = os.path.join(args.out, "ramdisk.cpio.gz")
    extracted_dtb = os.path.join(args.out, "dtb")
    for path, data in ((extracted_kernel, kernel), (extracted_ramdisk, ramdisk), (extracted_dtb, dtb)):
        with open(path, "wb") as stream:
            stream.write(data)
    if sha(extracted_kernel) != sha(args.kernel):
        raise SystemExit("ERROR: kernel extraído difiere de Image.gz")
    if sha(extracted_ramdisk) != sha(args.ramdisk):
        raise SystemExit("ERROR: ramdisk extraído difiere del original")
    if sha(extracted_dtb) != sha(args.dtb):
        raise SystemExit("ERROR: DTB extraído difiere del original")
    dts = os.path.join(args.out, "dtb.dts")
    subprocess.run(["dtc", "-I", "dtb", "-O", "dts", "-o", dts, extracted_dtb], check=True)
    dts_text = open(dts, encoding="utf-8").read()
    for token in ("framebuffer@5c000000", "width = <0x2d0>", "height = <0x618>",
                  "stride = <0xb40>", 'format = "a8r8g8b8"', "memory@5c000000"):
        if token not in dts_text:
            raise SystemExit(f"ERROR: DTB extraído sin {token}")
    initramfs_dir = os.path.join(args.out, "initramfs")
    os.makedirs(initramfs_dir)
    extract_newc(extracted_ramdisk, initramfs_dir)
    for path in ("init", "bin/busybox", "etc/issue"):
        if not os.path.lexists(os.path.join(initramfs_dir, path)):
            raise SystemExit(f"ERROR: initramfs sin {path}")
    for applet in ("ifconfig", "telnetd"):
        candidates = [os.path.join(initramfs_dir, directory, applet)
                      for directory in ("bin", "sbin", "usr/bin", "usr/sbin")]
        if not any(os.path.lexists(path) for path in candidates):
            raise SystemExit(f"ERROR: initramfs sin applet {applet}")
    busybox_path = os.path.join(initramfs_dir, "bin/busybox")
    busybox_info = subprocess.check_output(["file", busybox_path], text=True)
    if "ARM aarch64" not in busybox_info or "static" not in busybox_info:
        raise SystemExit(f"ERROR: BusyBox no es aarch64 estático: {busybox_info.strip()}")
    report = os.path.join(args.out, "diagnostic-boot-validation.md")
    with open(report, "w", encoding="utf-8") as stream:
        stream.write("# Validación boot diagnóstico\n\n")
        stream.write(f"- boot bytes: {len(boot)} / 67108864\n")
        stream.write(f"- boot SHA-256: {sha(args.boot)}\n")
        stream.write(f"- cmdline: {cmdline}\n")
        stream.write("- kernel/ramdisk/DTB: extracción y hashes idénticos\n")
        stream.write("- DTB: framebuffer@5c000000 validado\n")
        stream.write("- initramfs: init, BusyBox, ifconfig, telnetd, issue presentes\n")
        stream.write(f"- BusyBox: {busybox_info.strip()}\n")
    print(open(report, encoding="utf-8").read(), end="")


if __name__ == "__main__":
    main()
