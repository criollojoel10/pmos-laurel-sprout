#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
#
# inject-opencode-rootfs.py — inyecta el binario opencode en el rootfs
# (particion p2, ext4) de la imagen MBR COMPLETA del port xiaomi-laurel.
#
# Uso:
#   scripts/inject-opencode-rootfs.py <raw-mbr> <sector> <opencode-bin>
#
#   <raw-mbr>    imagen MBR RAW (losetup aun no necesario; se lee el primer
#                sector para localizar la particion p2).
#   <sector>     tamano de sector en bytes (deviceinfo_rootfs_image_sector_size,
#                default 512).
#   <opencode-bin>  ruta al binario opencode (musl linux-arm64).
#
# Efecto sobre p2 (rootfs ext4):
#   - /usr/local/bin/opencode   (0755 root:root)
#   - /usr/local/bin           se crea si no existe
#
# SOLO LECTURA sobre la entrada; escribe la imagen de salida ESPECIFICADA por
# el usuario en <raw-mbr> (misma imagen, en su lugar). Para CI: copiar la raw
# antes si se quiere preservar la original.
#
# El binario opencode es unico — solo un archivo plano — asi que nos basta
# debugfs (write/set_inode_field); NO resuelve dependencias de paquetes (para
# eso usar 'apk add' en el chroot, como con tailscale).

import struct
import subprocess
import sys


def part2_index(part0, part1):
    return part0 if part0 is not None else part1


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    raw, sector_str, bin_path = sys.argv[1], sys.argv[2], sys.argv[3]
    sector = int(sector_str)

    if not __import__("os").path.exists(bin_path):
        sys.exit("ERROR: no existe el binario opencode: " + bin_path)

    # Localizar particiones en el MBR
    with open(raw, "rb") as fh:
        mbr = fh.read(512)
    if mbr[510:512] != b"\x55\xaa":
        sys.exit("ERROR: no es una imagen MBR (falta firma 0x55aa)")

    parts = {}
    for i in range(4):
        e = mbr[446 + i * 16 : 446 + i * 16 + 16]
        _, _, ptype, _, start, size = struct.unpack("<B3sB3sII", e)
        if ptype and size:
            parts[i + 1] = (ptype, start, size)

    if 2 not in parts:
        sys.exit("ERROR: no hay particion p2 en esta imagen MBR")

    ptype2, start2, size2 = parts[2]
    print("p2: type=0x{:02x} start={} size={} sectores".format(
        ptype2, start2, size2))

    # Extraer p2 a un archivo temporal
    tmp = "/tmp/oc-p2.img"
    subprocess.run(
        ["dd", "if=" + raw, "of=" + tmp, "bs={}".format(sector),
         "skip={}".format(start2), "count={}".format(size2), "status=none"],
        check=True)

    # debugfs: asegurar /usr/local/bin y copiar opencode
    subprocess.run(
        ["debugfs", "-w", "-R", "mkdir /usr/local/bin", tmp], check=False)
    subprocess.run(
        ["debugfs", "-w", "-R",
         "write {} /usr/local/bin/opencode".format(bin_path), tmp], check=True)
    subprocess.run(
        ["debugfs", "-w", "-R",
         "set_inode_field /usr/local/bin/opencode mode 0x81ed", tmp],
        check=True)  # 0x81ed = regular + 0755
    subprocess.run(
        ["debugfs", "-w", "-R",
         "set_inode_field /usr/local/bin/opencode uid 0", tmp], check=True)
    subprocess.run(
        ["debugfs", "-w", "-R",
         "set_inode_field /usr/local/bin/opencode gid 0", tmp], check=True)

    # Verificar
    check = subprocess.run(
        ["debugfs", "-R", "stat /usr/local/bin/opencode", tmp],
        capture_output=True, text=True)
    if "Type: regular" not in check.stdout:
        sys.exit("ERROR: no se pudo confirmar opencode en p2")

    # Escribir de vuelta p2 a la imagen (misma posicion, mismo tamano)
    p2 = tmp
    with open(p2, "rb") as fh:
        data = fh.read()
    if len(data) != size2 * sector:
        sys.exit("ERROR: longitud de p2 inesperada")

    with open(raw, "r+b") as fh:
        fh.seek(start2 * sector)
        fh.write(data)

    print("OK: opencode inyectado en /usr/local/bin/opencode (0755 root:root)")


if __name__ == "__main__":
    main()
