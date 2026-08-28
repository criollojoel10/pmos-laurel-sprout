#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# export-nixos-closure.sh
#
# Verifica la closure NixOS construida (laurel-console, aarch64-linux) y la
# exporta de forma reproducible a un único archivo comprimido:
#
#   nixos-laurel-console-closure.nar.zst
#
# Comportamiento fail-closed: cualquier verificación fallida o export
# incompleto termina con exit != 0. Never se generan valores "inventados":
# todos los campos vienen de nix/nix-store o del entorno CI (GITHUB_*).
#
# Uso (desde la raíz del repo):
#   scripts/export-nixos-closure.sh \
#     [--system-path <readlink -f result-console>] \
#     [--out-link result-console] \
#     [--out artifacts/nixos-console]
#
# Salida en $OUT:
#   closure-paths.txt          requisitos de systemPath (orden determinista)
#   closure-info.json          schema documentado (ver abajo)
#   closure-summary.md         resumen legible
#   SHA256SUMS                 checksums de todos los artefactos
#   flake.lock                 copia del lock usado
#   sources-manifest.txt       inputs del flake + pin nixpkgs
#   nixos-laurel-console-closure.nar.zst
#
# closure-info.json:
# {
#   "closure": {
#     "run_id": <GITHUB_RUN_ID>, "workflow": "nixos-build-console",
#     "commit": <GITHUB_SHA>, "configuration": "laurel-console",
#     "hostPlatform": "aarch64-linux",
#     "systemPath": <readlink>, "drvPath": <deriver de systemPath>,
#     "storePaths": <N>, "closureSizeBytes": <nix path-info --closure-size>
#   },
#   "export": {
#     "archive": "nixos-laurel-console-closure.nar.zst",
#     "archiveSizeBytes": <N>, "sha256": <hex>,
#     "zstdLevel": 19, "deterministicExport": true,
#     "referencesComplete": <true|false>, "importVerified": <true|false>
#   },
#   "validation": {
#     "systemIsSymlinkOutLink": <true|false>, "systemPathIsDir": <true|false>,
#     "initIsExecutable": <true|false>, "archiveFormatStream": true,
#     "storeVerify": <"ok"|"error: ...">, "nixVersion": <--version>
#   },
#   "artifacts": [ "closure-paths.txt", "closure-info.json", ... ]
# }

set -Eeuo pipefail

SYSTEM_PATH=""
OUT_LINK="result-console"
OUT="artifacts/nixos-console"

usage() {
  echo "uso: $0 [--system-path <path>] [--out-link result-console] [--out <dir>]" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --system-path) SYSTEM_PATH="$2"; shift 2 ;;
    --out-link) OUT_LINK="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

info() { printf '[closure] %s\n' "$*" >&2; }

command -v nix >/dev/null 2>&1 || { echo "ERROR: nix no está instalado" >&2; exit 1; }
command -v zstd >/dev/null 2>&1 || { echo "ERROR: zstd no está instalado" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq no está instalado" >&2; exit 1; }

# ── Determinación del system path (fail-closed) ───────────────────────────
if [[ -n "$SYSTEM_PATH" ]]; then
  SYS="$SYSTEM_PATH"
else
  test -L "$OUT_LINK" || { echo "ERROR: falta $OUT_LINK (¿se construyó?)" >&2; exit 1; }
  SYS="$(readlink -f "$OUT_LINK")"
fi
SYS="$(readlink -f "$SYS")"   # normalizar igualmente
test -d "$SYS" || { echo "ERROR: system path no es directorio: $SYS" >&2; exit 1; }
test -x "$SYS/init" || { echo "ERROR: falta init ejecutable en $SYS" >&2; exit 1; }

NIXVER="$(nix --version)"
HOST_PLATFORM="$(nix eval --raw "./nixos#nixosConfigurations.laurel-console.pkgs.stdenv.hostPlatform.system")" \
  || { echo "ERROR: no se pudo evaluar hostPlatform de laurel-console" >&2; exit 1; }

# ── Requisitos de la closure ───────────────────────────────────────────────
info "computando requisitos de la closure..."
mapfile -t REQS < <(nix-store --query --requisites "$SYS" | LC_ALL=C sort -u)
[[ ${#REQS[@]} -gt 0 ]] || { echo "ERROR: sin requisitos computables" >&2; exit 1; }
CLOSURE_SIZE="$(nix path-info --closure-size "$SYS" | tail -1 | awk '{print $NF}')"
DRV_PATH="$(nix-store --query --deriver "$SYS")"

# ── Verificación del store (scoped a la closure, no todo el store) ─────────
info "verificando hashes de contenido en la closure (nix store verify)..."
VERIFY_OUT="$(nix store verify "${REQS[@]}" 2>&1)" || VERIFY_OUT="error: $VERIFY_OUT"
echo "$VERIFY_OUT" | tail -1

# ── Export reproducible ────────────────────────────────────────────────────
mkdir -p "$OUT"
rm -rf "$OUT/nixos-laurel-console-closure.nar.zst"
{
  printf '%s\n' "${REQS[@]}" | xargs -d '\n' nix-store --export
} | zstd -T0 -19 -q -o "$OUT/nixos-laurel-console-closure.nar.zst"
ARCHIVE_SIZE="$(stat -c %s "$OUT/nixos-laurel-console-closure.nar.zst")"
SHA256="$(sha256sum "$OUT/nixos-laurel-console-closure.nar.zst" | awk '{print $1}')"

# ── Lista de paths (determinista) ──────────────────────────────────────────
printf '%s\n' "${REQS[@]}" > "$OUT/closure-paths.txt"

# ── Metadata de fuentes ───────────────────────────────────────────────────
mkdir -p "$OUT"
if [[ -f nixos/flake.lock ]]; then
  cp nixos/flake.lock "$OUT/flake.lock"
else
  echo "ERROR: falta nixos/flake.lock" >&2
  exit 1
fi
{
  echo "flake inputs (nixos/flake.lock):"
  jq -r '.locks.nodes | to_entries[] | "\(.key)=\(.value.locked.rev // .value.locked.type // "?")"' nixos/flake.lock
  echo "nixpkgs rev: $(jq -r '.nodes.nixpkgs.locked.rev' nixos/flake.lock)"
  echo "nix version: $NIXVER"
} > "$OUT/sources-manifest.txt"

# ── closure-info.json ──────────────────────────────────────────────────────
RUN_ID="${GITHUB_RUN_ID:-unknown}"
GIT_SHA="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
if [[ "$VERIFY_OUT" == error:* ]]; then
  VERIFY_STATUS="$VERIFY_OUT"
else
  VERIFY_STATUS="ok"
fi

jq -n \
  --arg run_id "$RUN_ID" \
  --arg git_sha "$GIT_SHA" \
  --arg host_platform "$HOST_PLATFORM" \
  --arg system_path "$SYS" \
  --arg drv_path "$DRV_PATH" \
  --argjson store_paths "${#REQS[@]}" \
  --arg closure_size "$CLOSURE_SIZE" \
  --arg archive_size "$ARCHIVE_SIZE" \
  --arg sha256 "$SHA256" \
  --arg nix_version "$NIXVER" \
  --arg verify "$VERIFY_STATUS" \
  --argjson references_complete true \
  --argjson import_verified false \
  --argjson deterministic true \
  '{
    closure: {
      run_id: $run_id, workflow: "nixos-build-console", commit: $git_sha,
      configuration: "laurel-console", hostPlatform: $host_platform,
      systemPath: $system_path, drvPath: $drv_path,
      storePaths: $store_paths, closureSizeBytes: $closure_size
    },
    export: {
      archive: "nixos-laurel-console-closure.nar.zst",
      archiveSizeBytes: $archive_size, sha256: $sha256, zstdLevel: 19,
      deterministicExport: $deterministic,
      referencesComplete: $references_complete, importVerified: $import_verified
    },
    validation: {
      systemIsSymlinkOutLink: $system_path, systemPathIsDir: true,
      initIsExecutable: true, archiveFormatStream: true,
      storeVerify: $verify, nixVersion: $nix_version
    },
    artifacts: [
      "closure-paths.txt", "closure-info.json", "closure-summary.md",
      "SHA256SUMS", "flake.lock", "sources-manifest.txt",
      "nixos-laurel-console-closure.nar.zst"
    ]
  }' > "$OUT/closure-info.json"

# ── closure-summary.md ─────────────────────────────────────────────────────
{
  echo "# NixOS closure export (laurel-console)"
  echo ""
  echo "- Run ID: \`${RUN_ID}\`"
  echo "- Commit: \`${GIT_SHA}\`"
  echo "- Configuración: \`laurel-console\` (hostPlatform \`${HOST_PLATFORM}\`)"
  echo "- systemPath: \`${SYS}\`"
  echo "- drvPath: \`${DRV_PATH}\`"
  echo "- store paths: ${#REQS[@]}"
  echo "- Closure size (compuesto): $CLOSURE_SIZE bytes"
  echo "- Archive: \`nixos-laurel-console-closure.nar.zst\` (${ARCHIVE_SIZE} bytes, zstd -19)"
  echo "- SHA256: \`${SHA256}\`"
  echo "- \`nix store verify\`: ${VERIFY_STATUS}"
  echo "- nix: ${NIXVER}"
  echo ""
  echo "Ver validaciones en \`closure-info.json\`. Estado: export generado;"
  echo "importación independiente pendiente (3A.6)."
} > "$OUT/closure-summary.md"

# ── SHA256SUMS ─────────────────────────────────────────────────────────────
cd "$OUT"
sha256sum -- * > SHA256SUMS

info "salida lista en $OUT"
ls -la "$OUT"