# NixOS build invalidations (false-positive)

Historial de runs cuya parte "NixOS closure" NO construyó la closure aunque el
workflow terminó con SUCCESS. Registrar como:

```
INVALIDATED: workflow returned success without constructing the NixOS closure.
```

Causa técnica: `scripts/build-nixos-rootfs.sh` y `06-build-nixos.yml` usaban un
fallback *blando*: `if ! nix build ...toplevel; then NOTE ... (sin exit)`.
Un fallo real de `nix build` no abortaba el job; se seguían copiando kernel/dtb/
initramfs/boot.img y se publicaba un artefacto que *parecía* un build de NixOS
pero NO contenía la closure. El 06+ y 07+ reportaban `conclusion: success`.

Corrección: contratos fail-closed en `scripts/build-nixos-rootfs.sh`
(`nix build` fallido -> `exit 1`), gates `if: success()` en los artículos de
producto de 06/07 y test de regresión `scripts/check-no-soft-fallback.sh`.
Esto se corrige en el commit `fix(nixos): fail closed when closure build fails`.

## Runs invalidados (estado: false-positive-invalidated)

| Workflow | Run ID | Distro/Variante | Estado | Evidencia |
|---|---|---|---|---|
| 07-build-distros | 33093698708 | nixos console/gnome/kde | false-positive-invalidated | closure no construida (fallback blando); resultado "success" |
| 07-build-distros | 33104029709 | nixos console/gnome/kde | false-positive-invalidated | ídem |
| 07-build-distros | 33108497125 | nixos console/gnome/kde | false-positive-invalidated | ídem |
| 06-build-nixos | 33088227815 | nixos console | false-positive-invalidated | ídem |

Estos runs NO se eliminan del historial; quedan documentados para auditoría.
Los artefactos kernel/boot asociados siguen siendo válidos como diagnóstico
(no como producto NixOS).