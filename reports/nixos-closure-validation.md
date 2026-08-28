# NixOS closure validation (FASE 3A)

Resultado de la subfase 3A del `reports/plan-nixos-phosh.md`: construcción real,
verificación y export reproducible de la closure de `nixosConfigurations.laurel-console`.

## Cierre producido (evidence-based, run 33135793761)

| Campo | Valor | Fuente |
|---|---|---|
| Run ID | `33135793761` | GITHUB_RUN_ID |
| Workflow | `nixos-build-console.yml` | — |
| Commit | `b76d1e f` | GITHUB_SHA |
| Configuración | `laurel-console` | flake |
| hostPlatform | `aarch64-linux` | `nix eval ./nixos#…hostPlatform.system` |
| systemPath | `/nix/store/12zh8s1y1is0mn99hfjwswxfi9d99xkx-nixos-system-laurel-pmos-26.11.20260823.56c02bc` | `readlink -f result-console` |
| drvPath | `/nix/store/9h7hrx7jl0fx8b2z1hl6dccx47ayyga0-nixos-system-laurel-pmos-26.11.20260823.56c02bc.drv` | `nix-store --query --deriver` |
| store paths | 663 (únicos, orden determinista) | `nix-store --query --requisites` |
| Closure size | 1 784 780 632 bytes | `nix path-info --closure-size` |
| nix | Determinate Nix 3.22.2 (2.35.2) | `nix --version` |

## Verificación

- `nix store verify <663 paths>` → `ok` (hashes de contenido de la closure, no
  solo presencia): log `checking '<system>'...` completado sin errores.
- `<systemPath>/init` existe y es ejecutable; `<systemPath>` es directorio.
- Build fue un build REAL del toplevel (`--print-build-logs`, 49 derivaciones
  construidas sobre el caché), sin `--impure`, sin kernel rebuild ni descarga.

## Export reproducible

- Comando: `{ printf '%s\n' "${REQS[@]}" | xargs -d '\n' nix-store --export } | zstd -T0 -19`
  (REQS = `nix-store --query --requisites` ordenado). Orden determinista; el
  stream es `nix-archive-1`; 663/663 paths únicos sin duplicados.
- Archivo: `nixos-laurel-console-closure.nar.zst` (454 945 616 bytes; ~1.78 GB
  descomprimidos).
- `zstd -t` → OK (integridad); re-decompresión inspeccionada.
- SHA256 del artefacto coincide con `closure-info.json` y `SHA256SUMS`:
  `6b969088ef4ac6bc0c9bdc3376e686bdfe8cfb00219922a97825ed1863faae7a`.
- `flake.lock` incorporado = `nixos/flake.lock` del repo (nixpkgs `56c02bc…`);
  `sources-manifest.txt` registra el pin. CI verifica que flake.lock existe
  versionado y nunca regenera.

## Secret scan (3A.7)

- Patrones (BEGIN RSA/OPENSSH/EC/PRIVATE, id_rsa/env_ed25519, tokens GH, PAT de
  GitHub, AKIA, password/secret/token) en `closure-paths.txt`,
  `sources-manifest.txt`, `closure-summary.md`, `SHA256SUMS` → sin coincidencias.
- La config NixOS no incluye claves privadas: `users.users.root.openssh
  .authorizedKeys.keys = []`; sin contraseñas; SSH deshabilitado por password.
  Las claves SSH del host deben generarse en el primer arranque (comportamiento
  systemd/openssh por defecto). `hardware-tested` sigue en `false`.

## Estado de los flags (criterio 3A.6)

| Flag | Valor | Evidencia |
|---|---|---|
| closure-built | **true** | build real, drvPath no vacío, store paths 663 |
| closure-exported | **true** | nar.zst presente (454 945 616 B) |
| archive-integrity-verified | **true** | `zstd -t` OK; sha256 coincide; stream `nix-archive-1` |
| independently-imported | **false** | no disponible store aislado en CI ni local; se documenta en vez de asumir |
| references-complete | **true** | requisitos via `nix-store -qR` (663) |
| seal (ready-for-rootfs-tree) | **false** | sólo tras 3B (importar el export en un árbol rootfs) |
| hardware-tested | **false** | sin hardware; no se flashea nada |

Limitación documentada: la export no fue re-importada en un store aislado
(`independently-imported=false`); la garantía de re-importabilidad descansa en
`nix-store --export`/`--import` (protocolo estable) + integridad + determinismo
del origen de la export.

Artifacts: `artifacts/nixos-console/` (run `33135793761`). Workflow:
`.github/workflows/nixos-build-console.yml`. Exportador:
`scripts/export-nixos-closure.sh`.