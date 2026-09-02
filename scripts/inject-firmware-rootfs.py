#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
#
# inject-firmware-rootfs.py — inyecta un árbol de firmware en la partición
# p2 (rootfs ext4, "/") de la imagen MBR COMPLETA del port xiaomi-laurel.
#
# Uso:
#   scripts/inject-firmware-rootfs.py <raw-mbr> <sector> <firmware-tree-dir>
#
#   <raw-mbr>            imagen MBR RAW (ext2/ext4 p1 boot, p2 /).
#   <sector>             tamaño de sector en bytes (deviceinfo, default 512).
#   <firmware-tree-dir>  directorio con la raíz entendida como "/" del rootfs.
#                        Contenido típico: lib/firmware/...  (ej. un árbol
#                        "root/" en cuyo interior hay lib/firmware/...).
#
# Efecto sobre p2: copia recursivamente el contenido de <firmware-tree-dir>
# (interpretado como "/") sobre p2, creando directorios intermedios y
# preservando permisos (dir 0755, fichero 0644 y +x según el árbol fuente).
# El resto de la imagen queda intacto; el contenido de p2 se escribe en su
# misma posición y tamaño original (NO se redimensiona).
#
# SOLO LECTURA sobre la entrada; escribe en la imagen <raw-mbr> en su lugar.
# Para CI: operar sobre una copia de la raw.
#
# No elimina nada existente: solo añade/sobrescribe rutas bajo "/".

import os
import struct
import subprocess
import sys


def part2_layout(mbr):
    if mbr[510:512] != b"\x55\xaa":
        sys.exit("ERROR: no es una imagen MBR (falta firma 0x55aa)")
    for i in range(4):
        e = mbr[446 + i * 16 : 446 + i * 16 + 16]
        _, _, ptype, _, start, size = struct.unpack("<B3sB3sII", e)
        if ptype and size and i + 1 == 2:
            return start, size
    sys.exit("ERROR: no hay particion p2 en esta imagen MBR")


def run(cmd):
    subprocess.run(cmd, check=True, capture_output=True, text=True)


def stat_mode(dbg_out):
    for line in dbg_out.splitlines():
        if line.startswith("Mode:"):
            # "Mode: <mode> <str>" -> primer campo tras ":"
            mode = line.split()[1]
            return int(mode, 0)
    return None


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    raw, sector_str, tree = sys.argv[1], sys.argv[2], sys.argv[3]
    sector = int(sector_str)
    if not os.path.isdir(tree):
        sys.exit("ERROR: no existe el arbol de firmware: " + tree)

    with open(raw, "rb") as fh:
        mbr = fh.read(512)
    start2, size2 = part2_layout(mbr)
    print("p2: start={} size={} sectores ({} bytes)".format(
        start2, size2, start2 * sector))

    tmp = "/tmp/fw-p2.img"
    run(["dd", "if=" + raw, "of=" + tmp, "bs={}".format(sector),
         "skip={}".format(start2), "count={}".format(size2), "status=none"])

    # Recorrer el árbol e inyectar vía debugfs (write crea dirs intermedios si
    # se usa -w y la ruta existe; para evitar fallos se crean dirs primero).
    injected = []
    for root, dirs, files in os.walk(tree):
        rel = os.path.relpath(root, tree)
        # Crear directorios intermedios (mkdir -p es idempotente en debugfs)
        if rel != ".":
            subprocess.run(
                ["debugfs", "-w", "-R", "mkdir -p /{}".format(rel), tmp],
                check=False)
        for f in files:
            src = os.path.join(root, f)
            dst = "/{}/{}".format(rel, f) if rel != "." else "/" + f
            run(["debugfs", "-w", "-R", "mkdir -p /{}".format(os.path.dirname(dst)), tmp])
            run(["debugfs", "-w", "-R", "write {} {}".format(src, dst), tmp])
            chk = subprocess.run(
                ["debugfs", "-R", "stat {}".format(dst), tmp],
                capture_output=True, text=True)
            mode = stat_mode(chk.stdout)
            if os.access(src, os.X_OK):
                mode = (mode & ~0o777) | 0o755
            else:
                mode = (mode & ~0o777) | 0o644
            run(["debugfs", "-w", "-R",
                 "set_inode_field {} mode {:o}".format(dst, mode), tmp])
            run(["debugfs", "-w", "-R", "set_inode_field {} uid 0".format(dst), tmp])
            run(["debugfs", "-w", "-R", "set_inode_field {} gid 0".format(dst), tmp])
            injected.append((dst, mode))
            print("  + {}".format(dst))

    with open(tmp, "rb") as fh:
        data = fh.read()
    if len(data) != size2 * sector:
        sys.exit("ERROR: longitud de p2 inesperada ({} != {})".format(
            len(data), size2 * sector))

    with open(raw, "r+b") as fh:
        fh.seek(start2 * sector)
        fh.write(data)

    print("OK: inyectados {} archivos de firmware en p2".format(len(injected)))
    for dst, mode in injected:
        print("  {:<45} {:o}".format(dst, mode))


if __name__ == "__main__":
    main()
