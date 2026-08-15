#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# verify-rmtfs-mem.sh
#
# Verificación estructurada del nodo qcom,rmtfs-mem (EFS) en la variante
# WCN3990 v4 sobre SM6125. Comprueba por BLOQUE de nodo, no por coincidencias
# globales.
#
# El nodo usa la forma DINÁMICA del framework reserved-memory de mainline:
#   size + alloc-ranges (sin reg). No existe dirección estática downstream
#   para rmtfs en SM6125/trinket (verificado en android_kernel_xiaomi_sm6125,
#   lineage-18.1 hasta lineage-23.2 /e/OS A16, y en sm61x5-mainline 6.19):
#   el vendor define qcom,sharedmem-uio con reg = <0x0 0x200000> (2 MiB,
#   client id 1) y asigna dinámicamente. Esta forma mainline equivale a esa
#   asignación dinámica: el driver qcom_rmtfs_mem (77de535b, 6.1) usa
#   of_reserved_mem_lookup() y crea /dev/qcom_rmtfs_mem<client-id>.
#
# qcom,vmid se omite deliberadamente: el binding 6.1 lo trata como opcional
# (dispara qcom_scm_assign_mem) y ningún dtsi downstream de laurel_sprout lo
# usa para rmtfs.
#
# No modifica el árbol. Imprime PASS/FAIL por gate y devuelve código distinto
# de cero ante cualquier fallo.
#
# Dos modos:
#   --tree <árbol-kernel>   verifica los FUENTES tras aplicar 0004
#                           (arch/arm64/boot/dts/qcom/sm6125.dtsi).
#   --final-dts <archivo>   verifica el DTB FINAL decompilado (final-v4.dts).
#
# Uso:
#   scripts/verify-rmtfs-mem.sh --tree <árbol> [--out <dir>]
#   scripts/verify-rmtfs-mem.sh --final-dts <final-v4.dts> [--out <dir>]

set -eu

TREE=""
FINAL_DTS=""
OUT="."

usage() {
  echo "uso: $0 (--tree <árbol> | --final-dts <final-v4.dts>) [--out <dir>]" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --tree) TREE="$2"; shift 2 ;;
    --final-dts) FINAL_DTS="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$TREE" || -n "$FINAL_DTS" ]] || usage
[[ -z "$TREE" || -z "$FINAL_DTS" ]] || usage

mkdir -p "$OUT"
fail=0
total=0

info() { printf '[rmtfs-mem] %s\n' "$*"; }

gate() {
  local label="$1"; shift
  total=$(( total + 1 ))
  if "$@"; then
    info "PASS: $label"
  else
    info "FAIL: $label"
    fail=1
  fi
}

gate_absent() {
  local label="$1"; shift
  total=$(( total + 1 ))
  if "$@"; then
    info "FAIL: $label (se esperaba ausencia)"
    fail=1
  else
    info "PASS: $label"
  fi
}

extract_block() {
  awk -v node="$1" '
    $0 ~ "^[[:space:]]*" node "[[:space:]]*\\{" { found=1 }
    found {
      print
      line=$0
      gsub(/"[^"]*"/, "", line)
      ob=gsub(/\{/, "", line)
      cb=gsub(/\}/, "", line)
      depth+=ob-cb
      if (depth<=0) exit
    }
  ' "$2"
}

# --- MODO FUENTE ---
if [[ -n "$TREE" ]]; then
  DTSI="$TREE/arch/arm64/boot/dts/qcom/sm6125.dtsi"
  [[ -f "$DTSI" ]] || { echo "ERROR: no existe $DTSI" >&2; exit 1; }

  info "Modo fuente: verificando tras aplicar 0004"

  # El nodo no lleva unit-address (forma dinámica): rmtfs_mem: rmtfs-mem { ... }
  RMTFS=$(extract_block "rmtfs_mem: rmtfs-mem" "$DTSI" || true)
  [[ -n "$RMTFS" ]] || RMTFS=$(extract_block "rmtfs-mem" "$DTSI" || true)

  gate "nodo rmtfs-mem presente (0004)" test -n "$RMTFS"
  if [[ -n "$RMTFS" ]]; then
    gate 'compatible = "qcom,rmtfs-mem"' grep -q 'compatible = "qcom,rmtfs-mem"' <<<"$RMTFS"
    gate_absent 'sin reg (forma dinámica)' grep -Eq '^[[:space:]]*reg[[:space:]]*=' <<<"$RMTFS"
    gate 'size = <0x0 0x200000> (2 MiB)' grep -q 'size = <0x0 0x200000>' <<<"$RMTFS"
    gate 'alloc-ranges presente (asignación dinámica)' grep -q 'alloc-ranges = ' <<<"$RMTFS"
    gate 'no-map presente' grep -q 'no-map' <<<"$RMTFS"
    gate 'qcom,client-id = <1> (-> /dev/qcom_rmtfs_mem1)' grep -q 'qcom,client-id = <1>' <<<"$RMTFS"
    gate_absent 'sin qcom,vmid (opcional, omitido por diseño)' grep -q 'qcom,vmid' <<<"$RMTFS"
  else
    for l in 'compatible = "qcom,rmtfs-mem"' 'sin reg (forma dinámica)' \
             'size = <0x0 0x200000> (2 MiB)' 'alloc-ranges presente (asignación dinámica)' \
             'no-map presente' 'qcom,client-id = <1>' 'sin qcom,vmid'; do
      gate "$l" false
    done
  fi

  gate "exactamente un nodo rmtfs-mem { en el dtsi" \
    test "$(grep -c 'rmtfs-mem[[:space:]]*{' "$DTSI" || true)" -eq 1
  gate "sin rmtfs residual en el board" \
    test "$(grep -c 'rmtfs' "$TREE/arch/arm64/boot/dts/qcom/sm6125-xiaomi-laurel_sprout.dts" || true)" -eq 0

  # Las regiones reservadas vecinas deben conservar su reg EXACTO (0004 no
  # debe tocar modem_mem / wlan_msa_mem / smem / cont_splash / qseecom_ta).
  MODEM=$(extract_block "modem_mem: memory@4b000000" "$DTSI" || true)
  WLAN=$(extract_block "wlan_msa_mem: memory@53300000" "$DTSI" || true)
  SMEM=$(extract_block "smem_mem: memory@46000000" "$DTSI" || true)
  SPLASH=$(extract_block "cont_splash_mem: memory@5c000000" "$DTSI" || true)
  QSEE=$(extract_block "qseecom_ta_mem: memory@13fc00000" "$DTSI" || true)
  gate "modem_mem reg intacto" grep -q 'reg = <0x0 0x4b000000 0x0 0x7e00000>' <<<"$MODEM"
  gate "wlan_msa_mem reg intacto" grep -q 'reg = <0x0 0x53300000 0x0 0x200000>' <<<"$WLAN"
  gate "smem_mem reg intacto" grep -q 'reg = <0x0 0x46000000 0x0 0x200000>' <<<"$SMEM"
  gate "cont_splash_mem reg intacto" grep -q 'reg = <0x0 0x5c000000 0x0 0x00f00000>' <<<"$SPLASH"
  gate "qseecom_ta_mem reg intacto" grep -q 'reg = <0x1 0x3fc00000 0x0 0x400000>' <<<"$QSEE"
fi

# --- MODO DTB FINAL ---
if [[ -n "$FINAL_DTS" ]]; then
  [[ -f "$FINAL_DTS" ]] || { echo "ERROR: no existe $FINAL_DTS" >&2; exit 1; }
  info "Modo final: verificando DTB decompilado"

  RMTFS=$(extract_block "rmtfs-mem" "$FINAL_DTS" || true)

  gate "nodo rmtfs-mem presente en el DTB final" test -n "$RMTFS"
  if [[ -n "$RMTFS" ]]; then
    gate 'compatible = "qcom,rmtfs-mem"' grep -q 'compatible = "qcom,rmtfs-mem"' <<<"$RMTFS"
    gate_absent 'sin reg (forma dinámica)' grep -Eq '^[[:space:]]*reg[[:space:]]*=' <<<"$RMTFS"
    gate 'size = <0x0 0x200000> (2 MiB)' grep -q 'size = <0x0 0x200000>' <<<"$RMTFS"
    gate 'alloc-ranges presente' grep -q 'alloc-ranges = ' <<<"$RMTFS"
    gate 'no-map presente' grep -q 'no-map' <<<"$RMTFS"
    gate 'qcom,client-id = <1>' grep -q 'qcom,client-id = <1>' <<<"$RMTFS"
    gate_absent 'sin qcom,vmid' grep -q 'qcom,vmid' <<<"$RMTFS"
  else
    for l in 'compatible = "qcom,rmtfs-mem"' 'sin reg (forma dinámica)' \
             'size = <0x0 0x200000> (2 MiB)' 'alloc-ranges presente' \
             'no-map presente' 'qcom,client-id = <1>' 'sin qcom,vmid'; do
      gate "$l" false
    done
  fi
fi

# reporte
cat > "$OUT/rmtfs-verification.md" <<EOF
# Verificación rmtfs-mem (EFS) — SM6125

Modo: ${TREE:+fuente ($TREE)}${FINAL_DTS:+final-dts ($FINAL_DTS)}
Gates: $total total.
Resultado: $([ "$fail" -eq 0 ] && echo PASS || echo FAIL)
EOF
info "Verificación completa: $total gates, resultado $([ "$fail" -eq 0 ] && echo PASS || echo FAIL)"
[[ "$fail" -eq 0 ]] || { echo "ERROR: la verificación falló" >&2; exit 1; }
exit 0