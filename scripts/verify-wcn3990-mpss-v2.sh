#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# verify-wcn3990-mpss-v2.sh
#
# Verificación estructurada de la variante WCN3990 v2 (MPSS transport) sobre
# SM6125. Comprueba por BLOQUE de nodo (no por coincidencias globales) y
# resuelve phandles en el DTB final decompilado para evitar falsos positivos
# por labels convertidos a phandles.
#
# No modifica el árbol. Imprime PASS/FAIL por gate y devuelve código distinto
# de cero ante cualquier fallo.
#
# Dos modos:
#   --tree <árbol-kernel>   verifica los FUENTES tras aplicar 0001+0002
#                           (arch/arm64/boot/dts/qcom/sm6125.dtsi y el board).
#   --final-dts <archivo>   verifica el DTB FINAL decompilado (final-v2.dts),
#                           phandle-aware (gates 13 y 14 de M13).
#
# Estado MPSS esperado (variante):
#   --expect-mpss disabled  (default, v2): remoteproc_mpss disabled en el DTSI
#                           y el board SIN override.
#   --expect-mpss okay      (v3): override de placa &remoteproc_mpss con
#                           status = "okay". El resto de la semantica es igual.
#
# Uso:
#   scripts/verify-wcn3990-mpss-v2.sh --tree <árbol> [--expect-mpss <estado>] [--out <dir>]
#   scripts/verify-wcn3990-mpss-v2.sh --final-dts <final-v2.dts> [--expect-mpss <estado>] [--out <dir>]

set -eu

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TREE=""
FINAL_DTS=""
OUT="."
EXPECT_MPSS="disabled"

usage() {
  echo "uso: $0 (--tree <árbol> | --final-dts <final-v2.dts>) [--expect-mpss disabled|okay] [--out <dir>]" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --tree) TREE="$2"; shift 2 ;;
    --final-dts) FINAL_DTS="$2"; shift 2 ;;
    --expect-mpss) EXPECT_MPSS="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ "$EXPECT_MPSS" == "disabled" || "$EXPECT_MPSS" == "okay" ]] || usage

[[ -n "$TREE" || -n "$FINAL_DTS" ]] || usage
[[ -z "$TREE" || -z "$FINAL_DTS" ]] || usage

mkdir -p "$OUT"
fail=0
total=0

info() { printf '[mpss-v2] %s\n' "$*"; }

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

# gate_absent: PASS si la condicion devuelve distinto de cero (ausencia/negacion)
gate_absent() {
  local label="$1"; shift
  total=$(( total + 1 ))
  if "$@"; then
    info "FAIL: $label (se esperaba ausencia/negacion)"
    fail=1
  else
    info "PASS: $label"
  fi
}

# extrae el bloque "nodo { ... };" completo (balanceo de llaves) de un dtsi
extract_block() {
  awk -v node="$1" '
    $0 ~ "^[[:space:]]*" node "[[:space:]]*\\{" { found=1 }
    found {
      print
      # contar llaves ignorando las que estan entre comillas
      line=$0
      gsub(/"[^"]*"/, "", line)
      ob=gsub(/\{/, "", line)
      cb=gsub(/\}/, "", line)
      depth+=ob-cb
      if (depth<=0) exit
    }
  ' "$2"
}

# gate_eq: PASS si $1 == $2 (comparacion exacta de cadenas)
gate_eq() {
  local label="$1" actual="$2" expected="$3"
  total=$(( total + 1 ))
  if [[ "$actual" == "$expected" ]]; then
    info "PASS: $label"
  else
    info "FAIL: $label"
    info "  esperado: [$expected]"
    info "  actual:   [$actual]"
    fail=1
  fi
}

# extrae el valor de una propiedad multi-linea del bloque pasado por stdin:
# "prop = ...;" -> devuelve el texto entre el "=" y el ";" (con saltos de linea).
# Uso: extract_prop "interrupt-names" <<<"$BLOCK"
extract_prop() {
  local prop="$1"
  awk -v prop="$prop" '
    $0 ~ "^[[:space:]]*" prop "[[:space:]]*=" { found=1; sub("^[[:space:]]*" prop "[[:space:]]*=[[:space:]]*", "", $0) }
    found {
      # quitar el ";" final de la linea si la propiedad termina en esta linea
      if ($0 ~ /;[[:space:]]*$/) { sub(/;[[:space:]]*$/, "", $0); found=0 }
      print
    }
  '
}

# extrae estructuralmente un bloque override de placa "&label { ... };"
# (puede ocupar varias lineas). Devuelve vacio si no existe.
extract_override_block() {
  awk -v label="$1" '
    $0 ~ "^[[:space:]]*&" label "[[:space:]]*\\{" { found=1 }
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
  BOARD="$TREE/arch/arm64/boot/dts/qcom/sm6125-xiaomi-laurel_sprout.dts"
  [[ -f "$DTSI" ]] || { echo "ERROR: no existe $DTSI" >&2; exit 1; }
  [[ -f "$BOARD" ]] || { echo "ERROR: no existe $BOARD" >&2; exit 1; }

  info "Modo fuente: verificando tras aplicar 0001+0002"

  RP=$(extract_block "remoteproc_mpss: remoteproc@6080000" "$DTSI" || true)
  [[ -n "$RP" ]] || RP=$(extract_block "remoteproc@6080000" "$DTSI" || true)
  SMP=$(extract_block "smp2p-mpss" "$DTSI" || true)
  WIFI=$(extract_block "wifi@c800000" "$BOARD" || true)
  MODEM_MEM=$(extract_block "modem_mem: memory@4b000000" "$DTSI" || true)
  [[ -n "$MODEM_MEM" ]] || MODEM_MEM=$(extract_block "memory@4b000000" "$DTSI" || true)
  WLAN_MSA=$(extract_block "wlan_msa_mem: memory@53300000" "$DTSI" || true)
  [[ -n "$WLAN_MSA" ]] || WLAN_MSA=$(extract_block "memory@53300000" "$DTSI" || true)

  gate "nodo wifi@c800000 presente (v1/0001)" test -n "$WIFI"
  if [[ -n "$WIFI" ]]; then
    gate 'compatible "qcom,wcn3990-wifi"' grep -q 'compatible = "qcom,wcn3990-wifi"' <<<"$WIFI"
    gate 'wifi status = "okay"' grep -q 'status = "okay"' <<<"$WIFI"
  else
    gate 'compatible "qcom,wcn3990-wifi"' false
    gate 'wifi status = "okay"' false
  fi

  gate "nodo smp2p-mpss presente" test -n "$SMP"
  if [[ -n "$SMP" ]]; then
    gate 'qcom,smem = <435>, <428>' grep -q 'qcom,smem = <435>, <428>' <<<"$SMP"
    gate 'mboxes = <&apcs_glb 14>' grep -q 'mboxes = <&apcs_glb 14>' <<<"$SMP"
    gate 'entry "master-kernel"' grep -q 'qcom,entry-name = "master-kernel"' <<<"$SMP"
    gate 'entry "slave-kernel"' grep -q 'qcom,entry-name = "slave-kernel"' <<<"$SMP"
    gate 'entry "wlan"' grep -q 'qcom,entry-name = "wlan"' <<<"$SMP"
  else
    for l in 'qcom,smem = <435>, <428>' 'mboxes = <&apcs_glb 14>' \
             'entry "master-kernel"' 'entry "slave-kernel"' 'entry "wlan"'; do
      gate "$l" false
    done
  fi

  gate "nodo remoteproc@6080000 presente" test -n "$RP"
  if [[ -n "$RP" ]]; then
    gate 'compatible "qcom,sm8150-mpss-pas"' grep -q 'compatible = "qcom,sm8150-mpss-pas"' <<<"$RP"
    # El nodo del DTSI queda "disabled" siempre; el estado efectivo lo decide
    # el override de placa (ausente en v2, status="okay" en v3), validado abajo.
    gate 'dtsi status = "disabled" (override de placa decide el efectivo)' grep -q 'status = "disabled"' <<<"$RP"
    gate "glink-edge presente" grep -q 'glink-edge' <<<"$RP"
    gate 'mboxes = <&apcs_glb 12> (glink-edge)' grep -q 'mboxes = <&apcs_glb 12>' <<<"$RP"
    gate 'memory-region = <&modem_mem>' grep -q 'memory-region = <&modem_mem>' <<<"$RP"
    gate 'power-domains = <&rpmpd SM6125_VDDCX>' grep -q 'power-domains = <&rpmpd SM6125_VDDCX>' <<<"$RP"
    gate 'qcom,smem-state-names = "stop"' grep -q 'qcom,smem-state-names = "stop"' <<<"$RP"

    # 9A/9B: exactamente UNA propiedad power-domains con exactamente
    # UN dominio <&rpmpd SM6125_VDDCX> (una sola entrada en la celda)
    gate "exactamente una propiedad power-domains" \
      test "$(grep -c '^[[:space:]]*power-domains[[:space:]]*=' <<<"$RP")" -eq 1
    gate "power-domains contiene exactamente una entrada VDDCX" \
      test "$(grep -o 'SM6125_VDDCX' <<<"$RP" | wc -l)" -eq 1
    gate 'power-domains = <&rpmpd SM6125_VDDCX>' \
      grep -q 'power-domains = <&rpmpd SM6125_VDDCX>' <<<"$RP"
    # 9C: sin power-domain-names
    gate_absent "sin power-domain-names" grep -q 'power-domain-names' <<<"$RP"
    # 9F: interrupt-names EXACTOS y en orden (extrae la propiedad completa,
    # aunque ocupe varias lineas, y compara la lista exacta)
    IN_RAW=$(extract_prop "interrupt-names" <<<"$RP" | tr -d '\t"' | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ //;s/ $//')
    EXPECTED_IN='wdog, fatal, ready, handover, stop-ack, shutdown-ack'
    gate_eq 'interrupt-names exactos en orden' "$IN_RAW" "$EXPECTED_IN"
    # 9G: seis entradas interrupts-extended
    gate "seis entradas interrupts-extended" \
      test "$(grep -o 'GIC_SPI 307' <<<"$RP" | wc -l)" -eq 1 \
        -a "$(grep -o 'modem_smp2p_in' <<<"$RP" | wc -l)" -eq 5
  else
    for l in 'compatible "qcom,sm8150-mpss-pas"' 'dtsi status = "disabled" (override de placa decide el efectivo)' 'glink-edge' \
             'mboxes = <&apcs_glb 12> (glink-edge)' 'memory-region = <&modem_mem>' \
             'power-domains = <&rpmpd SM6125_VDDCX>' 'qcom,smem-state-names = "stop"' \
             'exactamente una propiedad power-domains' 'power-domains contiene exactamente una entrada VDDCX' \
             'sin power-domain-names' \
             'interrupt-names orden' 'seis entradas interrupts-extended'; do
      gate "$l" false
    done
  fi

  # 9E: override del board segun variante. En v2 (disabled) el board NO debe
  # sobrescribir remoteproc_mpss. En v3 (okay) el override de placa con
  # status = "okay" ES el habilitador; se valida su contenido exacto.
  # En ambas variantes se rechaza MÁS de un override (duplicado).
  RP_OVR_COUNT=$(grep -c '^[[:space:]]*&remoteproc_mpss[[:space:]]*{' "$BOARD" || true)
  gate "maximo un override de remoteproc_mpss en el board" \
    test "$RP_OVR_COUNT" -le 1
  RP_OVR=$(extract_override_block "remoteproc_mpss" "$BOARD" || true)
  if [[ "$EXPECT_MPSS" == "okay" ]]; then
    if [[ -n "$RP_OVR" ]]; then
      gate "board override de remoteproc_mpss presente (v3)" true
      gate 'override status = "okay"' grep -q 'status = "okay"' <<<"$RP_OVR"
      gate_absent "override no contiene power-domains" grep -q 'power-domains' <<<"$RP_OVR"
      gate_absent "override no contiene memory-region" grep -q 'memory-region' <<<"$RP_OVR"
      gate_absent "override no contiene interrupts" grep -q 'interrupts' <<<"$RP_OVR"
    else
      gate "board override de remoteproc_mpss presente (v3)" false
    fi
  else
    if [[ -z "$RP_OVR" ]]; then
      gate "board sin override de remoteproc_mpss" true
    else
      gate "board sin override de remoteproc_mpss" false
      # si existe, ademas comprobar que NO contenga status = "okay" (por claridad)
      if grep -q 'status = "okay"' <<<"$RP_OVR"; then
        gate "override del board no contiene status = \"okay\"" false
      else
        gate "override del board no contiene status = \"okay\"" true
      fi
    fi
  fi

  # 9I: regiones reservadas modem_mem y wlan_msa_mem con reg EXACTO
  # (base y tamaño), extraidas por bloque, no solo por nombre.
  MODEM_REG=$(extract_prop "reg" <<<"$MODEM_MEM" | tr -d '\t' | sed 's/  */ /g;s/^ //;s/ $//')
  WLAN_REG=$(extract_prop "reg" <<<"$WLAN_MSA" | tr -d '\t' | sed 's/  */ /g;s/^ //;s/ $//')
  gate_eq "modem_mem reg = <0x0 0x4b000000 0x0 0x7e00000>" "$MODEM_REG" "<0x0 0x4b000000 0x0 0x7e00000>"
  gate_eq "wlan_msa_mem reg = <0x0 0x53300000 0x0 0x200000>" "$WLAN_REG" "<0x0 0x53300000 0x0 0x200000>"
fi

# --- MODO DTB FINAL ---
if [[ -n "$FINAL_DTS" ]]; then
  [[ -f "$FINAL_DTS" ]] || { echo "ERROR: no existe $FINAL_DTS" >&2; exit 1; }
  info "Modo final: verificando DTB decompilado (phandle-aware, mpss=$EXPECT_MPSS)"
  if python3 "$REPO_ROOT/scripts/validate-mpss-v2-final.py" --dts "$FINAL_DTS" --expect-mpss "$EXPECT_MPSS"; then
    info "PASS: gates DTB final (semántica y phandles)"
  else
    info "FAIL: gates DTB final"
    fail=1
  fi
fi

# reporte
cat > "$OUT/mpss-v2-verification.md" <<EOF
# Verificación WCN3990 v2 (MPSS transport) — SM6125

Modo: ${TREE:+fuente ($TREE)}${FINAL_DTS:+final-dts ($FINAL_DTS)}
MPSS esperado: $EXPECT_MPSS
Gates: $total total.
Resultado: $([ "$fail" -eq 0 ] && echo PASS || echo FAIL)
EOF
info "Verificación completa: $total gates, mpss=$EXPECT_MPSS, resultado $([ "$fail" -eq 0 ] && echo PASS || echo FAIL)"
[[ "$fail" -eq 0 ]] || { echo "ERROR: la verificación falló" >&2; exit 1; }
exit 0
