# Matrix Audit Report

Date: 2026-08-27

## Distro × Variant Matrix

| Distro | Variant | Workflow | Kernel Source | Rootfs | Boot Image | Artifact Name | Status |
|--------|---------|----------|---------------|--------|------------|---------------|--------|
| postmarketOS | console | 04-build-pmos-console.yml | pmbootstrap | pmbootstrap | pmbootstrap | pmos-console | **scaffold-only** |
| postmarketOS | phosh | 04-build-pmos-phosh.yml | shared (reusable) | pmbootstrap | pmbootstrap | pmos-phosh | **scaffold-only** |
| postmarketOS | plasma | 05-build-pmos-plasma.yml | pmbootstrap | pmbootstrap | pmbootstrap | pmos-plasma | **scaffold-only** |
| Arch Linux ARM | console | 05-build-archlinux.yml | shared (reusable) | build-archlinux-rootfs.sh | manual | archlinux-arm-console | **wired** |
| Arch Linux ARM | phosh | 05-build-archlinux.yml | shared (reusable) | build-archlinux-rootfs.sh | manual | archlinux-arm-phosh | **wired** |
| NixOS | console | 06-build-nixos.yml | shared (reusable) | nix build + manual | build-boot-image.py | nixos-console | **wired** |
| NixOS | phosh | 06-build-nixos.yml | shared (reusable) | nix build + manual | build-boot-image.py | nixos-phosh | **wired** |

## Status Definitions

- **wired**: Workflow exists, calls shared kernel, has build script, produces artifact name, has manifest
- **scaffold-only**: Workflow exists, has placeholder for pmbootstrap integration, no real build yet
- **blocked**: Workflow exists but blocked on external dependency
- **missing**: Workflow does not exist

## Matrix Orchestrator

`07-build-distros.yml` orchestrates all builds:
- Calls reusable-build-kernel.yml once
- Calls each distro workflow with kernel artifact
- Collect job aggregates all artifacts

## Entry Points

### Standalone (workflow_dispatch)
Each workflow can be triggered independently:
- `04-build-pmos-console.yml` — pmOS console
- `04-build-pmos-phosh.yml` — pmOS Phosh
- `05-build-pmos-plasma.yml` — pmOS Plasma
- `05-build-archlinux.yml` — Arch Linux ARM (with variant input)
- `06-build-nixos.yml` — NixOS (with variant input)

### Matrix (07-build-distros.yml)
Dispatches all builds in parallel:
- pmOS: console, phosh (conditional), plasma (conditional)
- Arch Linux ARM: console, phosh (conditional)
- NixOS: console, phosh (conditional)

## Kernel Integration

| Distro | Kernel Method | Shares Artifact? |
|--------|--------------|------------------|
| postmarketOS | pmbootstrap (builds its own) | No (parallel path) |
| Arch Linux ARM | Reusable workflow | Yes |
| NixOS | Reusable workflow | Yes |

Note: postmarketOS uses pmbootstrap's built-in kernel (`linux-postmarketos-qcom-sm6125`). The shared kernel from reusable-build-kernel.yml is used by Arch Linux ARM and NixOS. This is intentional — pmOS manages its kernel via pmaports.

## Artifact Flow

```
reusable-build-kernel.yml
  ├── kernel-debug/ (artifacts)
  │   ├── Image, Image.gz
  │   ├── sm6125-xiaomi-laurel-sprout.dtb
  │   ├── modules.tar.zst, dtb.tar.zst
  │   ├── System.map, kernel.config
  │   ├── SHA256SUMS, manifest.json
  │   └── kernelrelease
  │
  ├── 05-build-archlinux.yml → archlinux-arm-{variant}/
  │   └── rootfs-archlinux-{variant}-laurel.img.xz
  │
  └── 06-build-nixos.yml → nixos-{variant}/
      ├── Image, DTB, modules
      ├── boot.img
      └── flake.nix, nixos-config/

07-build-distros.yml
  └── distro-all-artifacts/
      └── collected-sha256sums
```

## Physical Test Status

All variants: **not-tested-on-hardware**
