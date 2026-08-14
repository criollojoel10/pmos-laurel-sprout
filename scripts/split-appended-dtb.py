#!/usr/bin/env python3
#
# Licencia: GPL-3.0-or-later
#
# split-appended-dtb.py
#
# Separa estructuralmente un payload kernel histórico (Image.gz + DTB
# appendado, deviceinfo_append_dtb=true) en sus dos partes:
#   - Image.gz puro
#   - DTB appendado
#
# El boot histórico se ensambla con --append-dtb: el kernel lleva el DTB
# incrustado tras el stream gzip, por lo que la región kernel NO es un gzip
# puro. Este script detecta la frontera de forma estructural:
#   1. Localiza el fin del stream gzip (zlib, no busca magics a ciegas).
#   2. Valida que el trailing sea un FDT: magic 0xd00dfeed y totalsize
#      big-endian de la cabecera FDT.
#   3. Exige que la frontera del DTB termine exactamente al final del payload
#      (offset_dtb + totalsize == len(payload)), de modo que cualquier byte
#      posterior (p. ej. un segundo DTB) se rechaza.
#
# Rechaza (rc != 0):
#   - ausencia de DTB (salvo --allow-no-dtb);
#   - DTB truncado (totalsize > bytes disponibles);
#   - totalsize FDT inválido (< 8);
#   - bytes posteriores al DTB (incluye doble DTB);
#   - kernel gzip vacío o inválido (gzip no completo / corrupto).
#
# No modifica el input. Registra offsets, tamaños y SHA-256 en el reporte JSON.
#
# Uso:
#   python3 scripts/split-appended-dtb.py \
#     --input kernel-with-old-dtb \
#     --kernel-out kernel.gz \
#     --dtb-out historical.dtb \
#     --report split-report.json \
#     [--allow-no-dtb]

import argparse
import hashlib
import json
import sys
import zlib

FDT_MAGIC = b"\xd0\x0d\xfe\xed"
GZIP_MAGIC = b"\x1f\x8b"
GZIP_MAGIC_LEN = 4
FDT_HDR_MIN = 8


class SplitError(Exception):
    pass


def sha256_hex(data):
    return hashlib.sha256(data).hexdigest()


def gzip_stream_end(payload):
    """Devuelve (consumed_len, trailing) tras validar el stream gzip."""
    if len(payload) < GZIP_MAGIC_LEN:
        raise SplitError("payload demasiado corto para contener un gzip")
    if payload[:2] != GZIP_MAGIC:
        raise SplitError("el payload no comienza con el magic gzip (1f 8b)")
    d = zlib.decompressobj(16 + zlib.MAX_WBITS)
    try:
        d.decompress(payload)
        if not d.eof:
            raise SplitError("stream gzip incompleto (gzip corrupto o truncado)")
    except zlib.error as exc:
        raise SplitError(f"gzip invalido: {exc}")
    trailing = d.unused_data
    consumed = len(payload) - len(trailing)
    if consumed <= 0:
        raise SplitError("stream gzip vacio")
    return consumed, trailing


def parse_fdt(trailing):
    """Valida el trailing como un FDT y devuelve (dtb, totalsize)."""
    if not trailing:
        raise SplitError("sin DTB appendado")
    if len(trailing) < FDT_HDR_MIN:
        raise SplitError("DTB truncado (menos de 8 bytes de cabecera FDT)")
    if trailing[:4] != FDT_MAGIC:
        raise SplitError("trailing no comienza con FDT magic (d0 0d fe ed)")
    totalsize = int.from_bytes(trailing[4:8], "big")
    if totalsize < FDT_HDR_MIN:
        raise SplitError(f"totalsize FDT invalido ({totalsize} < 8)")
    if totalsize > len(trailing):
        raise SplitError(f"DTB truncado (totalsize {totalsize} > disponibles {len(trailing)})")
    dtb = trailing[:totalsize]
    extra = trailing[totalsize:]
    if extra:
        raise SplitError(
            f"bytes posteriores al DTB ({len(extra)}): posible doble DTB o datos extra"
        )
    return dtb, totalsize


def main():
    parser = argparse.ArgumentParser(
        description="Separar Image.gz y DTB appendado de un payload kernel histórico"
    )
    parser.add_argument("--input", required=True,
                        help="payload kernel (Image.gz + DTB appendado)")
    parser.add_argument("--kernel-out", required=True,
                        help="salida: Image.gz puro")
    parser.add_argument("--dtb-out", required=True,
                        help="salida: DTB appendado")
    parser.add_argument("--report", required=True,
                        help="salida: reporte JSON (offsets, tamaños, SHA-256)")
    parser.add_argument("--allow-no-dtb", action="store_true",
                        help="aceptar gzip puro sin DTB (kernel_out = input)")
    args = parser.parse_args()

    with open(args.input, "rb") as f:
        payload = f.read()

    try:
        gz_end, trailing = gzip_stream_end(payload)
        dtb_present = bool(trailing)
        if dtb_present:
            dtb, totalsize = parse_fdt(trailing)
        else:
            if not args.allow_no_dtb:
                raise SplitError(
                    "gzip puro sin DTB (use --allow-no-dtb para aceptarlo explícitamente)"
                )
            dtb, totalsize = b"", 0
    except SplitError as exc:
        sys.stderr.write(f"split-appended-dtb: ERROR: {exc}\n")
        report = {
            "status": "FAIL",
            "error": str(exc),
            "input": args.input,
            "input_size": len(payload),
            "input_sha256": sha256_hex(payload),
        }
        with open(args.report, "w") as f:
            json.dump(report, f, indent=2)
        return 1

    kernel_gz = payload[:gz_end]
    with open(args.kernel_out, "wb") as f:
        f.write(kernel_gz)
    with open(args.dtb_out, "wb") as f:
        f.write(dtb)

    report = {
        "status": "OK",
        "input": args.input,
        "input_size": len(payload),
        "input_sha256": sha256_hex(payload),
        "kernel_out": args.kernel_out,
        "kernel_size": len(kernel_gz),
        "kernel_sha256": sha256_hex(kernel_gz),
        "kernel_byte_offset": 0,
        "kernel_end_offset": gz_end,
        "dtb_present": dtb_present,
        "dtb_out": args.dtb_out,
        "dtb_size": len(dtb),
        "dtb_sha256": sha256_hex(dtb),
        "dtb_byte_offset": gz_end,
        "fdt_magic": FDT_MAGIC.hex(),
        "fdt_totalsize": totalsize,
        "fdt_boundary_exact": (gz_end + totalsize == len(payload)),
        "allow_no_dtb": bool(args.allow_no_dtb),
    }
    with open(args.report, "w") as f:
        json.dump(report, f, indent=2)

    print(f"kernel.gz {len(kernel_gz)} bytes sha256={report['kernel_sha256']}")
    if dtb_present:
        print(f"dtb {len(dtb)} bytes sha256={report['dtb_sha256']} "
              f"offset={gz_end} totalsize={totalsize}")
    else:
        print("dtb: ausente (--allow-no-dtb)")
    return 0


if __name__ == "__main__":
    sys.exit(main())