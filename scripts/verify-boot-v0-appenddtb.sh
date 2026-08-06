#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# verify-boot-v0-appenddtb.sh
#
# Verifica un boot.img Android de header v0 con DTB apendado al kernel
# (modo histórico postmarketOS: deviceinfo_append_dtb=true, header v0):
#   - magic ANDROID!, header_version == 0
#   - payload de kernel == Image.gz + DTB (byte a byte)
#   - cmdline esperada (por defecto 'clk_ignore_unused')
#   - cabe en el límite de partición (por defecto 64 MiB)
#
# Uso:
#   scripts/verify-boot-v0-appenddtb.sh \
#     --boot <boot.img> \
#     --kernel <Image.gz> \
#     --dtb <sm6125-....dtb> \
#     [--cmdline "..."] \
#     [--boot-limit <bytes>] \
#     [--out <dir>]

set -Eeuo pipefail

BOOT=""
KERNEL=""
DTB=""
CMDLINE="clk_ignore_unused"
LIMIT="67108864"
OUT="."

while (( $# > 0 )); do
  case "$1" in
    --boot) BOOT="$2"; shift 2 ;;
    --kernel) KERNEL="$2"; shift 2 ;;
    --dtb) DTB="$2"; shift 2 ;;
    --cmdline) CMDLINE="$2"; shift 2 ;;
    --boot-limit) LIMIT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) echo "uso: $0 --boot <img> --kernel <Image.gz> --dtb <dtb> [--cmdline] [--boot-limit] [--out]" >&2; exit 2 ;;
  esac
done

[[ -n "$BOOT" && -n "$KERNEL" && -n "$DTB" ]] || { echo "ERROR: faltan --boot/--kernel/--dtb" >&2; exit 2; }
for f in "$BOOT" "$KERNEL" "$DTB"; do [[ -f "$f" ]] || { echo "ERROR: no existe: $f" >&2; exit 2; }; done

mkdir -p "$OUT"
python3 - "$BOOT" "$KERNEL" "$DTB" "$CMDLINE" "$LIMIT" "$OUT" <<'PY'
import struct, sys, os, hashlib

boot, kernel, dtb, cmdline_exp, limit, outdir = sys.argv[1:]
limit = int(limit)

data = open(boot, "rb").read()
kgz = open(kernel, "rb").read()
dtb_b = open(dtb, "rb").read()

report = []
fail = []
def check(name, ok, detail=""):
    report.append(f"| {name} | {'SÍ' if ok else 'NO'} | {detail} |")
    if not ok:
        fail.append(name)

magic = data[:8]
check("magic ANDROID!", magic == b"ANDROID!", magic.decode("latin1"))
if len(data) < 48:
    check("tamaño mínimo", False, f"{len(data)} bytes")
    open(os.path.join(outdir, "v0-verification.md"), "w").write("\n".join(report))
    sys.exit(1)

ks, ka, rs, ra, ss, sa, ta, ps, hv = struct.unpack("<9I", data[8:44])
check("header_version == 0", hv == 0, f"header_version={hv}")
check("page_size == 4096", ps == 4096, f"page={ps}")

cmdline = data[64:576].rstrip(b"\x00").decode("latin1")
check("cmdline histórica", cmdline == cmdline_exp, f"{cmdline!r} vs {cmdline_exp!r}")

# payload de kernel en offset de página
koff = ps
kpayload = data[koff:koff + ks]
concat = kgz + dtb_b
check("kernel_size == Image.gz+DTB", ks == len(concat), f"{ks} vs {len(concat)}")
check("kernel payload byte-idéntico",
      hashlib.sha256(kpayload).digest() == hashlib.sha256(concat).digest(),
      f"sha={hashlib.sha256(kpayload).hexdigest()[:16]}")

# ramdisk
roff = koff + ((ks + ps - 1) // ps) * ps
rsize = rs
check("ramdisk_size > 0", rsize > 0, f"{rsize} bytes")
check("ramdisk comienza gzip", data[roff:roff + 2] in (b"\x1f\x8b", b"\x02\x21", b"\x71\xc7"),
      data[roff:roff + 2].hex())

# sin sección dtb (v0 no tiene campos); tamaño total
check("cabe en partición (64 MiB)", len(data) <= limit, f"{len(data)} <= {limit}")

with open(os.path.join(outdir, "v0-verification.md"), "w") as fh:
    fh.write(f"# Verificación boot v0 append_dtb\n\n")
    fh.write(f"Archivo: {os.path.basename(boot)}  ({len(data)} bytes)\n\n")
    fh.write("| Comprobación | Resultado | Detalle |\n|---|---|---|\n")
    fh.write("\n".join(report))
    fh.write(f"\n\nCONCLUSIÓN: {'PASS' if not fail else 'FAIL (' + ', '.join(fail) + ')'}\n")

print(f"boot: {os.path.basename(boot)} ({len(data)} B, header v{hv})")
for line in report:
    print("  " + line)
if fail:
    sys.exit(1)
PY
