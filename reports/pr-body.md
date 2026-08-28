# CI: reproducible multi-distro builds for laurel-sprout (NixOS Fase 3A)

**Estado actual:** PR #15 quedó **MERGED** en `c2c559a` (solo el trabajo temprano
de la rama `agent/multi-distro-mainline`, 29 commits por detrás de `main`). El
trabajo técnico actual vive en `main` y NO está reflejado en esta PR. Pendiente:
decidir entre (a) reabrir esta PR como draft apuntando a la cima de `main`,
(b) crear una PR nueva de tracking, o (c) dejar esta PR merged como referencia
histórica.

## Contexto

Pipeline multi-distro reproducible para Xiaomi Mi A3 (laurel_sprout / SM6125):
kernel 7.1.0 compartido + rootfs builds de [NixOS] (+ Arch aparcado, pmOS
bloqueado aguas arriba). Variante GUI prioritaria: NixOS + Phosh (gnome).

## NixOS Fase 3A — build real de la closure + export reproducible

Estado: ✅ verificado en CI (run `33135793761`).

- **Fail-closed (regresión):** elimina el fallback *blando* que reportaba
  SUCCESS sin construir la closure:
  - `scripts/build-nixos-rootfs.sh` y `06-build-nixos.yml` → `nix build` fallido =
    `exit 1`; artefactos de producto solo con `if: success()`.
  - `scripts/check-no-soft-fallback.sh` exigido por `00-quality.yml` y
    `validate-local.sh`.
  - Runs previos documentados como INVALIDATED:
    `workflow returned success without constructing the NixOS closure.`
    (`reports/nixos-build-invalidation-log.md`).
- **Workflow nuevo** `.github/workflows/nixos-build-console.yml` (dispatch/call):
  flake.lock versionado requerido (nunca auto-generado), `nix build
  ./nixos#nixosConfigurations.laurel-console.config.system.build.toplevel
  --out-link result-console --print-build-logs`, sin `--impure`, sin kernel
  rebuild/download, artefactos solo tras éxito, logs de diagnóstico solo en
  fallo.
- **Export reproducible** `scripts/export-nixos-closure.sh`:
  requisitos ordenados → `nix-store --export | zstd -T0 -19` →
  `nixos-laurel-console-closure.nar.zst`. Verificado:
  - hostPlatform `aarch64-linux`; systemPath + drvPath reales; 663 store paths.
  - `nix store verify` (contenido) OK.
  - Integridad del archivo: `zstd -t` OK, stream `nix-archive-1`, SHA256
    `6b969088ef4ac6bc0c9bdc3376e686bdfe8cfb00219922a97825ed1863faae7a`.
  - `independently-imported=false` (documentado; sin store aislado).
  - Secret scan limpio; sin claves/contrasñas en la config.
  - Detalles: `reports/nixos-closure-validation.md`.

## Cómo reproducir

```
gh workflow run nixos-build-console.yml --ref main
gh run download <RUN_ID> --dir artifacts/<RUN_ID>
```

Artefacto clave: `artifacts/nixos-console/nixos-laurel-console-closure.nar.zst`.

## Notas

- `nixpkgs` fijado en `nixos/flake.lock` (`56c02bc…`, nixos-unstable) — el CI
  nunca actualiza el lock silenciosamente.
- Fixes de módulos initrd para linux 6.12 (`phy_qcom_qmp*`, `ufs_qcom`,
  `dwc3`) — los nombres previos ya no existen y rompían el `modules-shrunk`.
- Pendiente: 3B (árbol rootfs), 3C (ext4 NIXOS_ROOT), 3D (stage-1 real,
  previa investigación del arranque), 3E (boot image; `hardware-tested=false`).