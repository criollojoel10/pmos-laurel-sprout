#!/usr/bin/env python3
"""Extraer particiones de un payload.bin de Android (formato update_engine CrAU).

Solo lectura: lee payload.bin y escribe las particiones extraídas en out_dir.

Schema DeltaArchiveManifest (delta_archive.proto):
  repeated InstallOperation install_operations = 1;
  optional uint64 minor_version = 9;
  repeated PartitionInfo partitions = 13;
  optional DynamicPartitionMetadata dynamic_partition_metadata = 14;

  PartitionInfo:
    optional string partition_name = 1;
    optional int64 size = 2;
    optional bytes hash = 3;
    repeated InstallOperation operations = 5;
    optional int64 new_partition_signature_size = 7;
    optional bytes new_partition_signature = 8;
    optional string file_path = 10;
    optional string version = 11;
    optional int64 new_size = 18;
    repeated Extent new_extents = 15;
    optional PartitionInfoType ptype = 19;

  InstallOperation:
    enum Type { REPLACE=0; REPLACE_BZ=1; MOVE=2; BSDIFF=3; SOURCE_COPY=4;
                SOURCE_BSDIFF=5; ZERO=6; DISCARD=7; REPLACE_XZ=8;
                PUFFDIFF=9; BROTLI_BSDIFF=10; REPLACE_ZSTD=11; ZUCCHINI=12; }
    required Type type = 1;
    optional uint64 data_offset = 2;
    optional uint64 data_length = 3;
    repeated Extent src_extents = 4;
    optional uint64 src_length = 5;
    repeated Extent dst_extents = 6;
    optional Extent src_extent = 7;
    optional uint64 data_sha256_hash = 8;
    optional uint64 dst_length = 9;
"""
import sys
import struct
import zlib
import bz2
import lzma
import hashlib
import os
import zstandard as zstd

OP_ZERO = 6
OP_DISCARD = 7


def _varint(data, pos):
    result = 0
    shift = 0
    while True:
        b = data[pos]
        pos += 1
        result |= (b & 0x7F) << shift
        if not (b & 0x80):
            break
        shift += 7
    return result, pos


def _field(data, pos):
    key, pos = _varint(data, pos)
    fnum = key >> 3
    wtype = key & 7
    if wtype == 0:
        val, pos = _varint(data, pos)
        return fnum, wtype, val, pos
    if wtype == 2:
        ln, pos = _varint(data, pos)
        return fnum, wtype, data[pos:pos + ln], pos + ln
    if wtype == 5:
        return fnum, wtype, data[pos:pos + 4], pos + 4
    if wtype == 1:
        return fnum, wtype, data[pos:pos + 8], pos + 8
    raise ValueError(f"wire type {wtype}")


def parse_manifest(manifest):
    """Devuelve lista de (name, new_size, operations) donde operations es lista de
    (type, data_offset, data_length, dst_length)."""
    parts = []
    pos = 0
    while pos < len(manifest):
        fnum, wtype, val, pos = _field(manifest, pos)
        if fnum == 13 and wtype == 2:
            parts.append(_parse_partition(val))
    return parts


def _parse_partition(blob):
    name = None
    new_size = None
    ops = []
    pos = 0
    while pos < len(blob):
        fnum, wtype, val, pos = _field(blob, pos)
        if fnum == 1 and wtype == 2:
            name = val.decode()
        elif fnum == 8 and wtype == 2:
            ops.append(_parse_install_op(val))
        elif fnum == 17 and wtype == 2:
            new_size = val
    return name, new_size, ops


def _parse_install_op(blob):
    otype = None
    data_offset = None
    data_length = None
    dst_length = None
    pos = 0
    while pos < len(blob):
        fnum, wtype, val, pos = _field(blob, pos)
        if fnum == 1 and wtype == 0:
            otype = val
        elif fnum == 2 and wtype == 0:
            data_offset = val
        elif fnum == 3 and wtype == 0:
            data_length = val
        elif fnum == 9 and wtype == 0:
            dst_length = val
    return otype, data_offset, data_length, dst_length


def decompress(data, otype):
    if otype in (0, 6, 7):  # REPLACE, ZERO, DISCARD (raw payload)
        return data
    if otype == 1:  # REPLACE_BZ
        return bz2.decompress(data)
    if otype == 8:  # REPLACE_XZ
        return lzma.decompress(data)
    if otype == 11:  # REPLACE_ZSTD
        return zstd.ZstdDecompressor().decompress(data)
    raise ValueError(f"unsupported op type {otype}")


def read_payload(path):
    with open(path, 'rb') as f:
        magic = f.read(4)
        assert magic == b'CrAU', f"bad magic {magic}"
        major, mf_size = struct.unpack('>QQ', f.read(16))
        md_sig_size = struct.unpack('>I', f.read(4))[0]
        manifest = f.read(mf_size)
        f.read(md_sig_size)
        blob = f.read()
    return major, manifest, blob


def main():
    if len(sys.argv) < 4:
        print("uso: payload_extract.py <payload.bin> <out_dir> <part1> [part2 ...]")
        sys.exit(1)
    path, out_dir = sys.argv[1], sys.argv[2]
    want = sys.argv[3:]
    os.makedirs(out_dir, exist_ok=True)
    major, manifest, blob = read_payload(path)
    print(f"payload major={major}")
    parts = parse_manifest(manifest)
    print("particiones:", [p[0] for p in parts])
    for name, new_size, ops in parts:
        if name not in want:
            continue
        print(f"== {name}: new_size={new_size}, ops={len(ops)}")
        out = bytearray()
        for otype, off, ln, dst_len in ops:
            if otype in (6, 7):  # ZERO/DISCARD: destino a ceros
                n = dst_len or 0
                out += b"\x00" * n
                continue
            if off is None or ln is None:
                continue
            chunk = blob[off:off + ln]
            try:
                dec = decompress(chunk, otype)
            except Exception as e:
                print(f"  error op type {otype}: {e}")
                dec = b""
            out += dec
        out = bytes(out)
        fname = os.path.join(out_dir, f"{name}.img")
        with open(fname, 'wb') as f:
            f.write(out)
        print(f"  escrito {fname} ({len(out)} bytes, sha256={hashlib.sha256(out).hexdigest()})")


if __name__ == '__main__':
    main()
