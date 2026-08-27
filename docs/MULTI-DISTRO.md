# Multi-Distro Architecture

Date: 2026-08-27

## Overview

This project builds three Linux variants for the Xiaomi Mi A3 (`laurel_sprout`):

1. **postmarketOS** — Console, Phosh, Plasma Mobile
2. **Arch Linux ARM** — Console, Phosh
3. **NixOS** — Console, Phosh

All three share a **single kernel build** produced once per source configuration.

## Layer Architecture

```
┌─────────────────────────────────────────────────┐
│           Shared Kernel Artifacts               │
│  Image.gz, DTB, modules, System.map, .config    │
│  Built once per {commit, config, variant}        │
└──────────────┬──────────────┬───────────────────┘
               │              │
    ┌──────────▼──┐  ┌───────▼──────┐  ┌──────────▼──┐
    │ postmarketOS│  │ Arch Linux   │  │    NixOS    │
    │             │  │    ARM       │  │             │
    │  pmbootstrap│  │  rootfs +    │  │  nix build  │
    │  install    │  │  mkinitcpio  │  │  cross-     │
    │             │  │              │  │  compile    │
    └──────┬──────┘  └──────┬───────┘  └──────┬──────┘
           │                │                  │
    ┌──────▼──────┐  ┌──────▼───────┐  ┌──────▼──────┐
    │ boot.img    │  │ boot.img     │  │ boot.img    │
    │ (Android    │  │ (Android     │  │ (Android    │
    │  header v2) │  │  header v2)  │  │  header v2) │
    └─────────────┘  └──────────────┘  └─────────────┘
```

## Kernel Interface Contract

The shared kernel produces these artifacts:

| Artifact | Description | Used By |
|----------|-------------|---------|
| `Image.gz` | Compressed kernel image | All distros |
| `sm6125-xiaomi-laurel-sprout.dtb` | Device tree blob | All distros |
| `modules/` | Kernel modules (stripped) | All distros |
| `System.map` | Kernel symbol map | Debug |
| `kernel.config` | Final .config | Debug/reproducibility |
| `kernelrelease` | Version string | Module matching |
| `SHA256SUMS` | Checksums | All distros |
| `manifest.json` | Build metadata | All distros |

## Distro-Specific Build

### postmarketOS
- **Tool**: pmbootstrap
- **Kernel integration**: Custom kernel package APKBUILD
- **Boot image**: pmbootstrap export → boot.img
- **Variants**: console (Weston/foot), phosh (phoc/phosh), plasma (kwin_wayland)
- **Init**: systemd (recommended) or OpenRC

### Arch Linux ARM
- **Tool**: Generic AArch64 rootfs + pacman-static + chroot
- **Kernel integration**: Manual install to /boot/ + custom mkinitcpio preset
- **Boot image**: Custom assembly (build-boot-image.py)
- **Variants**: console (no UI), phosh (phoc/phosh)
- **Init**: systemd
- **Cross-build**: QEMU user-static binfmt on x86_64 runner

### NixOS
- **Tool**: nix build with cross-compilation
- **Kernel integration**: Custom nix derivation for kernel + DTB
- **Boot image**: Custom assembly from NixOS closure + initramfs
- **Variants**: console (minimal), phosh (phoc/phosh)
- **Init**: systemd
- **Cross-build**: nixpkgs cross-compilation (x86_64-linux → aarch64-linux)
- **Blocker**: No Mobile NixOS SM6125 device module; manual boot configuration required

## Workflow Structure

```
00-quality.yml                    (static validation, push/PR trigger)
├── reusable-build-kernel.yml     (shared kernel, workflow_call)
├── 04-build-pmos-console.yml     (pmbootstrap console)
├── 04-build-pmos-phosh.yml       (pmbootstrap phosh)
├── 05-build-pmos-plasma.yml      (pmbootstrap plasma)
├── 05-build-archlinux.yml        (Arch Linux ARM rootfs)
├── 06-build-nixos.yml            (NixOS flake build)
├── 06-validate-images.yml        (artifact validation)
└── 07-package-prerelease.yml     (GitHub release)
```

## Artifact Naming Convention

```
{distro}-{variant}-laurel-{kernel_commit_short}.img[.xz]
kernel-laurel-{variant}-{kernel_commit_short}.tar.zst
dtb-laurel-{kernel_commit_short}.tar.zst
modules-laurel-{kernel_commit_short}.tar.zst
```

## Matrix of Combinations

| Distro | Console | Phosh | Plasma Mobile |
|--------|---------|-------|---------------|
| postmarketOS | Yes | Yes | Yes |
| Arch Linux ARM | Yes | Yes | No (evaluated: viable but deferred) |
| NixOS | Yes | Yes | No (evaluated: not viable without Mobile NixOS port) |

## Known Limitations

1. **NixOS**: No Mobile NixOS SM6125 device module exists. Boot configuration is manual. This variant produces a NixOS system closure but requires manual boot image assembly.
2. **Arch Linux ARM**: Cross-build requires QEMU user-static. First builds are slow (no binary cache for custom packages).
3. **All distros**: GPU (Adreno 610) requires firmware `a610_zap.mbn` not yet packaged. Display works via simplefb/fbcon; DRM/KMS is boot-untested.
4. **Physical hardware**: None of these images have been tested on physical hardware. All validations are static/artifact-level.
