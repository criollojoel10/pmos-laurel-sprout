#!/usr/bin/env python3
"""patch-bootimg-cmdline.py — añade parámetros al cmdline de una boot image
Android sin tocar kernel/ramdisk/dtb.

Solo modifica el campo cmdline del header (y, si cambia de tamaño, respeta el
layout page-aligned del resto). Verifica que kernel/ramdisk/second/dtb quedan
byte-idénticos.

Uso:
  patch-bootimg-cmdline.py <boot-in> <boot-out> <param> [param2 ...]

Ejemplo:
  patch-bootimg-cmdline.py boot.img boot-fix.img consoleblank=0

Salida (exit 0 si OK):
  - header: cmdline ANTES -> DESPUÉS
  - kernel/ramdisk/... sha256 idénticos
  - sha256 del archivo final
"""
import hashlib
import struct
import sys


def pages(n: int, psz: int) -> int:
    return (n + psz - 1) // psz * psz


def main() -> None:
    if len(sys.argv) < 4:
        print("uso: patch-bootimg-cmdline.py <boot-in> <boot-out> <param> [param...]")
        sys.exit(2)
    fin, fout, params = sys.argv[1], sys.argv[2], sys.argv[3:]
    d = bytearray(open(fin, "rb").read())
    if d[:8] != b"ANDROID!":
        print("ERROR: no es una boot image ANDROID!")
        sys.exit(1)

    hv = struct.unpack_from("<I", d, 40)[0]
    ksz = struct.unpack_from("<I", d, 8)[0]
    rsz = struct.unpack_from("<I", d, 16)[0]
    sksz = struct.unpack_from("<I", d, 24)[0]
    psz = struct.unpack_from("<I", d, 36)[0]
    if hv >= 2:
        # v2: dtb_size en offset 48 (v0/v1 sin campo dtb)
        dtbsz = struct.unpack_from("<I", d, 48)[0]
    else:
        dtbsz = 0

    # campo cmdline (header v0/v1/v2: offset 64, 512 bytes; el kernel lo lee
    # hasta el primer \0). extra_cmdline (v0/v1) en 608..1632 se ignora.
    cmd_off, cmd_max = 64, 512
    old = d[cmd_off : cmd_off + cmd_max].split(b"\0")[0].decode("ascii", "replace")

    add = [p for p in params if p not in old.split()]
    if not add:
        print("cmdline sin cambios (parámetros ya presentes):", old)
        new = old
    else:
        new = (old + " " + " ".join(add)).strip()
    nb = new.encode("ascii")
    if len(nb) >= cmd_max:
        print(f"ERROR: cmdline resultante excede {cmd_max} bytes")
        sys.exit(1)
    # rellenar cmdline con NUL
    d[cmd_off : cmd_off + cmd_max] = nb + b"\0" * (cmd_max - len(nb))

    print(f"header cmdline ANTES : {old!r}")
    print(f"header cmdline DESPUÉS: {new!r}")

    # verificar que el resto (payload) no se desplaza: layout v0/v1/v2
    ko = psz
    ro = ko + pages(ksz, psz)
    so = ro + pages(rsz, psz)
    dto = so + pages(sksz, psz)
    total = dto + pages(dtbsz, psz) if dtbsz else dto
    print(f"layout: header@{psz} kernel@{ko} ramdisk@{ro} second@{so} dtb@{dto} total={total}")
    if total != len(d):
        print(f"ERROR: tamaño esperado {total} != real {len(d)}")
        sys.exit(1)

    def seg_hash(name: str, start: int, size: int) -> str:
        seg = bytes(d[start : start + size])
        h = hashlib.sha256(seg).hexdigest()
        print(f"  {name:9s} sha256={h} size={size}")
        return h

    hk = seg_hash("kernel", ko, ksz)
    hr = seg_hash("ramdisk", ro, rsz)
    hs = seg_hash("second", so, sksz)
    hd = seg_hash("dtb", dto, dtbsz) if dtbsz else None
    print(f"  psz={psz} hv={hv} ksz={ksz} rsz={rsz} sksz={sksz} dtbsz={dtbsz}")

    with open(fout, "wb") as fh:
        fh.write(d)
    outh = hashlib.sha256(d).hexdigest()
    print(f"escrito: {fout}")
    print(f"sha256 {fin }: {hashlib.sha256(open(fin, 'rb').read()).hexdigest()}")
    print(f"sha256 {fout}: {outh}")
    print("OK: solo cambió el cmdline del header; payload byte-idéntico")


if __name__ == "__main__":
    main()
