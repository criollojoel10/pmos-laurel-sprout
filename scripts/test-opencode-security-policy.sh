#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# test-opencode-security-policy.sh
#
# Verifica POR ANÁLISIS ESTÁTICO que la política de permisos de opencode
# (opencode.json) sigue denegando todas las operaciones peligrosas del
# dispositivo y del sistema.
#
# Este script NUNCA ejecuta ninguno de los comandos que comprueba: solo
# inspecciona el texto de opencode.json.
#
# Uso: scripts/test-opencode-security-policy.sh
# Salida: 0 = política correcta; 1 = política rota.

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

CONFIG="opencode.json"

info() { printf '[policy] %s\n' "$*" >&2; }
fail() { printf '[policy] FALLO: %s\n' "$*" >&2; FAILED=1; }

[[ -f "$CONFIG" ]] || { echo "ERROR: $CONFIG no existe" >&2; exit 1; }

# Validar JSON y estructura mínima con la clave `permission` (singular).
python3 - "$CONFIG" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1]))
perm = cfg.get("permission")
if perm is None:
    sys.exit("opencode.json no contiene la clave 'permission'")
bash = perm.get("bash") if isinstance(perm, dict) else None
if not isinstance(bash, dict):
    sys.exit("opencode.json.permission.bash no es un objeto de reglas")
PY
info "opencode.json válido y contiene permission.bash"

FAILED=0

# Cada operación peligrosa debe tener una regla DENY (comando) en permission.bash.
# Formato: "patrón" -> "deny"
DENIED_PATTERNS=(
  'adb *'
  'fastboot boot *'
  'fastboot flash *'
  'fastboot erase *'
  'fastboot format *'
  'fastboot set_active *'
  'fastboot reboot*'
  'fastboot continue*'
  'fastboot update*'
  'fastboot flashall*'
  'fastboot oem *'
  'fastboot flashing *'
  'fastboot -w*'
  'dd *'
  'sudo dd *'
  'mkfs*'
  'sudo mkfs*'
  'wipefs *'
  'sudo wipefs *'
  'parted *'
  'sudo parted *'
  'sgdisk *'
  'sudo sgdisk *'
  'git push --force*'
  'git push -f*'
)

for pat in "${DENIED_PATTERNS[@]}"; do
  # Comprobar que permission.bash contiene "pat" mapeado a deny
  if ! python3 - "$CONFIG" "$pat" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1]))
bash = cfg["permission"]["bash"]
pat = sys.argv[2]
val = None
for k, v in bash.items():
    if k == pat:
        val = v
        break
if val != "deny":
    sys.exit(1)
PY
  then
    fail "falta regla deny para: $pat"
  else
    info "deny OK: $pat"
  fi
done

# Acceso a /dev/block y dispositivos de bloque (cualquier permiso).
DENIED_DEV_PATTERNS=(
  '* /dev/block/*'
  '* /dev/sd?*'
  '* /dev/nvme*'
  '* /dev/mmcblk*'
)
for pat in "${DENIED_DEV_PATTERNS[@]}"; do
  if ! python3 - "$CONFIG" "$pat" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1]))
bash = cfg["permission"]["bash"]
pat = sys.argv[2]
val = None
for k, v in bash.items():
    if k == pat:
        val = v
        break
if val != "deny":
    sys.exit(1)
PY
  then
    fail "falta regla deny para acceso a dispositivo de bloque: $pat"
  else
    info "deny OK: $pat"
  fi
done

# Eliminación del repositorio / secretos / archivar.
DENIED_GH_PATTERNS=(
  'gh repo delete *'
  'gh repo archive *'
  'gh release delete *'
  'gh secret *'
)
for pat in "${DENIED_GH_PATTERNS[@]}"; do
  if ! python3 - "$CONFIG" "$pat" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1]))
bash = cfg["permission"]["bash"]
pat = sys.argv[2]
val = None
for k, v in bash.items():
    if k == pat:
        val = v
        break
if val != "deny":
    sys.exit(1)
PY
  then
    fail "falta regla deny para: $pat"
  else
    info "deny OK: $pat"
  fi
done

# Los comandos de SOLO LECTURA de Fastboot deben seguir permitidos.
ALLOWED_FASTBOOT=(
  'fastboot devices'
  'fastboot getvar product'
  'fastboot getvar current-slot'
  'fastboot getvar unlocked'
  'fastboot getvar slot-count'
  'fastboot getvar partition-size:boot_a'
  'fastboot getvar partition-size:boot_b'
  'fastboot getvar partition-size:dtbo_a'
  'fastboot getvar partition-size:dtbo_b'
  'fastboot getvar partition-size:vbmeta_a'
  'fastboot getvar partition-size:vbmeta_b'
  'fastboot getvar partition-type:boot_a'
  'fastboot getvar partition-type:dtbo_a'
  'fastboot getvar partition-type:vbmeta_a'
)
for cmd in "${ALLOWED_FASTBOOT[@]}"; do
  if ! python3 - "$CONFIG" "$cmd" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1]))
bash = cfg["permission"]["bash"]
cmd = sys.argv[2]
val = None
for k, v in bash.items():
    if k == cmd:
        val = v
        break
if val != "allow":
    sys.exit(1)
PY
  then
    fail "comando de solo lectura no permitido: $cmd"
  else
    info "allow OK: $cmd"
  fi
done

if (( FAILED != 0 )); then
  fail "política de seguridad INCORRECTA. Revisa opencode.json."
  exit 1
fi

info "política de seguridad verificada correctamente."
info "NOTA: este test es análisis estático; nunca ejecutó los comandos peligrosos."
exit 0
