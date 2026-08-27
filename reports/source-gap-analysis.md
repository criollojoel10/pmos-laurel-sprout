# Source Gap Analysis

Date: 2026-08-27

## Current sources.lock.json Coverage

| Source | Present? | Status |
|--------|----------|--------|
| linux-mainline-v7.1 | Yes | Verified, pinned |
| sm61x5-mainline-linux | Yes | Verified, pinned (research reference) |
| pmbootstrap | Yes | Verified, pinned |
| pmaports | Yes | Verified, pinned |
| mesa | Yes | URL verified, commit pending |
| linux-firmware | Yes | URL verified, commit pending |
| LineageOS kernel | Yes | Verified (reference only) |
| Xiaomi firmware | Yes | URL pending |
| busybox-1.38.0 | Yes | Verified, SHA-256 pinned |
| sm6125-mainline-linux | Yes | Verified (historical) |
| Historical port tools | Yes | Verified |

## Gaps for Multi-Distro

| Missing Source | Needed For | Action |
|----------------|------------|--------|
| Arch Linux ARM rootfs | Arch Linux ARM builds | Add: URL, MD5, size, date |
| pacman-static | Arch Linux ARM CI builds | Add: URL, version, SHA-256 |
| NixOS/nixpkgs | NixOS builds | Add: commit, branch, license |
| Mobile NixOS | NixOS device modules | Add: commit (or note absence) |
| postmarketos-ui-phosh | Phosh package reference | Add: pmaports commit covering phosh |
| Nix flake inputs | NixOS reproducibility | Add: nixpkgs, mobile-nixos commits |
| systemd/stable | All distros (systemd) | Note: provided by each distro |

## Proposed Additions

### Arch Linux ARM
```json
{
  "name": "archlinuxarm-rootfs",
  "url": "http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz",
  "vcs": "tarball",
  "branch_informational": "latest (2026-08-05)",
  "commit": null,
  "commit_date": "2026-08-05",
  "license": "custom (Arch Linux)",
  "purpose": "Generic AArch64 rootfs base for Arch Linux ARM builds",
  "verification_status": "verified",
  "last_audited": "2026-08-27",
  "notes": "MD5: 23eec86365b24f7913c403e8f4e8719b. Rebuilt periodically. GPG sig available."
}
```

### NixOS nixpkgs
```json
{
  "name": "nixpkgs",
  "url": "https://github.com/NixOS/nixpkgs",
  "vcs": "git",
  "branch_informational": "nixos-unstable",
  "commit": "PENDIENTE",
  "commit_date": "PENDIENTE",
  "license": "MIT",
  "purpose": "NixOS package set for cross-compilation to aarch64",
  "verification_status": "pending",
  "last_audited": "2026-08-27",
  "notes": "Commit fijado al crear el flake. Phosh 0.54.0 disponible."
}
```

## Impact on Build Pipeline

1. Arch Linux ARM builds need `pacman-static` or `QEMU user-static` for rootfs creation in CI
2. NixOS builds need `nix` installer on CI runner + cross-compilation setup
3. Both need the shared kernel artifacts (Image, DTB, modules) from workflow 03
4. PostmarketOS Phosh needs pmbootstrap with phosh UI selection
