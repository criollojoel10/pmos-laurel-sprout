#!/usr/bin/env bash
#
# audit-public-repository.sh
#
# Audita el árbol del repositorio antes de cada push para rechazarlo si
# encuentra información sensible o artefactos que nunca deben publicarse.
#
# Uso: scripts/audit-public-repository.sh
# Salida: 0 = seguro para publicar; 1 = se encontró contenido bloqueado.
#
# Licencia: GPL-3.0-or-later

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Fichero de estado en stderr para no mezclarlo con la salida del script
info() { printf '[audit] %s\n' "$*" >&2; }
fail() { printf '[audit] BLOQUEADO: %s\n' "$*" >&2; }

FOUND=0

# Solo auditoría sobre archivos versionados (o a punto de versionarse).
# `git ls-files --others --exclude-standard` listaría también archivos sin
# seguimiento, pero para la auditoría pre-push lo relevante es lo ya
# agregado al índice.
FILES="$(git ls-files --cached; git ls-files --others --exclude-standard)"
if [[ -z "$FILES" ]]; then
  info "no hay archivos versionados ni pendientes; nada que auditar"
  exit 0
fi

# Los archivos binarios grandes (imágenes, dtb, respaldos) nunca deben
# aparecer en un repositorio público de este proyecto.
check_big_files() {
  local f
  while IFS= read -r f; do
    [[ -z "$f" || ! -f "$f" ]] && continue
    if git check-ignore -q "$f" 2>/dev/null; then
      continue
    fi
    local size
    size="$(stat -c %s "$f" 2>/dev/null || echo 0)"
    if (( size > 5242880 )); then
      fail "archivo grande inesperado (>5 MB): $f ($size bytes)"
      FOUND=1
    fi
  done <<< "$FILES"
}

check_extension_blacklist() {
  local f
  while IFS= read -r f; do
    [[ -z "$f" || ! -f "$f" ]] && continue
    case "$f" in
      *.img|*.img.xz|*.img.gz|*.raw|*.dtb|*.dtbo|*.vbmeta|*.bin)
        fail "extensión bloqueada: $f"
        FOUND=1
        ;;
    esac
  done <<< "$FILES"
}

check_secret_patterns() {
  local f content
  while IFS= read -r f; do
    [[ -z "$f" || ! -f "$f" ]] && continue
    # Solo auditamos texto
    case "$f" in
      *.png|*.jpg|*.jpeg|*.gif|*.ico|*.woff|*.woff2|*.ttf|*.otf|*.zst|*.gz|*.xz|*.zip|*.tar) continue ;;
    esac
    content="$(tr -d '\0' < "$f" 2>/dev/null || true)"
    if printf '%s' "$content" | grep -aqE 'ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|ghs_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}'; then
      fail "posible token GitHub en: $f"
      FOUND=1
    fi
    if printf '%s' "$content" | grep -aqE 'BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY'; then
      fail "clave privada en: $f"
      FOUND=1
    fi
    if printf '%s' "$content" | grep -aqE 'AKIA[0-9A-Z]{16}'; then
      fail "posible clave AWS en: $f"
      FOUND=1
    fi
    if [[ "$f" == *.env* ]] || printf '%s' "$content" | grep -aqE '^(PASSWORD|PASSWD|SECRET|TOKEN|API_KEY|AWS_SECRET)[A-Z_]*='; then
      fail "posible secreto en variables en: $f"
      FOUND=1
    fi
  done <<< "$FILES"
}

# Identificadores de unidad que nunca deben aparecer.
check_device_identifiers() {
  local f content
  while IFS= read -r f; do
    [[ -z "$f" || ! -f "$f" ]] && continue
    case "$f" in
      *.png|*.jpg|*.jpeg|*.gif|*.ico|*.woff|*.woff2|*.ttf|*.otf|*.zst|*.gz|*.xz|*.zip|*.tar) continue ;;
    esac
    content="$(tr -d '\0' < "$f" 2>/dev/null || true)"
    # Salida real de `fastboot devices`: token hex (serial) seguido de
    # "fastboot". Menciones de la palabra comando en docs no disparan.
    if printf '%s' "$content" | grep -aqE '[0-9a-fA-F]{8,16}[[:space:]]+fastboot'; then
      fail "serial en salida sin filtrar de fastboot devices en: $f"
      FOUND=1
    fi
    # IMEI con dígitos reales; la palabra "IMEI" en guías no dispara.
    if printf '%s' "$content" | grep -aqE '\bIMEI[=: ][0-9]{15}\b|imei[=: ][0-9]{15}\b'; then
      fail "posible IMEI en: $f"
      FOUND=1
    fi
    if printf '%s' "$content" | grep -aqE '([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}'; then
      fail "posible dirección MAC en: $f"
      FOUND=1
    fi
    if printf '%s' "$content" | grep -aqE 'getvar all|partition-type:|partition-size:' && [[ "$f" == local-private/* ]]; then
      fail "datos Fastboot privados en archivo versionado: $f"
      FOUND=1
    fi
  done <<< "$FILES"
}

check_forbidden_paths() {
  local f
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    case "$f" in
      local-private/*|persist*|modemst*|fsg*|fsc*|efs*)
        fail "ruta prohibida en seguimiento Git: $f"
        FOUND=1
        ;;
    esac
  done <<< "$FILES"
}

check_forbidden_paths
check_big_files
check_extension_blacklist
check_secret_patterns
check_device_identifiers

if (( FOUND != 0 )); then
  fail "auditoría con hallazgos. Corrige antes de hacer push."
  exit 1
fi

info "auditoría superada: contenido seguro para publicar."
exit 0
