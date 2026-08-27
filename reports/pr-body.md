# ci: add reproducible multi-distro builds for laurel-sprout

> **EXPERIMENTAL** — UNTESTED ON PHYSICAL HARDWARE

## Architecture

```
┌─────────────────────────────────────────────────┐
│           Shared Kernel (Linux mainline v7.1)    │
│  Image.gz, DTB, modules, System.map, .config    │
│  Commit: b3f94b2b3f3e51ab880a51fc6510e1dafba654ed│
│  Tag v7.1 verified via GitHub API ✓              │
└──────────────┬──────────────┬───────────────────┘
               │              │
    ┌──────────▼──┐  ┌───────▼──────┐  ┌──────────▼──┐
    │ postmarketOS│  │ Arch Linux   │  │    NixOS    │
    │ console/    │  │    ARM       │  │ console/    │
    │ Phosh/Plasma│  │ console/Phosh│  │ Phosh       │
    └─────────────┘  └──────────────┘  └─────────────┘
```

## What This PR Adds

### Workflows (5 new)
- `reusable-build-kernel.yml` — parameterized shared kernel build
- `04-build-pmos-phosh.yml` — postmarketOS Phosh variant
- `05-build-archlinux.yml` — Arch Linux ARM (console + Phosh)
- `06-build-nixos.yml` — NixOS flake (console + Phosh)
- `07-build-distros.yml` — full distro matrix orchestrator

### Modified Workflows (2)
- `04-build-pmos-console.yml` — added `workflow_call` + `build_variant` input
- `05-build-pmos-plasma.yml` — added `workflow_call` + `build_variant` input

### Configs (3 new)
- `configs/pmos/phosh-packages.txt` — Phosh UI package list
- `configs/archlinux/console-packages.txt` — Arch Linux base packages
- `configs/archlinux/phosh-packages.txt` — Arch Linux Phosh packages

### NixOS (4 new)
- `nixos/flake.nix` — cross-compilation flake (console + Phosh)
- `nixos/devices/laurel-sprout/default.nix` — SM6125 device config
- `nixos/configurations/console.nix` — text-only system
- `nixos/configurations/phosh.nix` — Phosh + Wayland

### Scripts (3 new)
- `scripts/build-archlinux-rootfs.sh` — Arch Linux ARM rootfs builder
- `scripts/build-manifest.sh` — unified build manifest generator
- `scripts/validate-local.sh` — local validation suite

### Reports (6 new)
- `reports/upstream-audit.md` — kernel SM6125 upstream status
- `reports/skill-audit.md` — linux-phone-porting methodology audit
- `reports/source-gap-analysis.md` — missing sources analysis
- `reports/matrix-audit.md` — distro × variant implementation matrix

### Modified
- `sources.lock.json` — added archlinuxarm-rootfs + linux-phone-porting-skill entries

## Kernel
- **Source**: Linux mainline v7.1
- **Commit**: `b3f94b2b3f3e51ab880a51fc6510e1dafba654ed`
- **Tag verification**: GitHub API confirms `torvalds/linux` tag v7.1 = this commit ✓
- **Patches**: 4 downstream patches (panel, GPU, WiFi WCN3990)
- **DTS**: `sm6125-xiaomi-laurel-sprout.dtb` merged upstream since v6.3

## Skill
- **Repository**: https://github.com/angelwzr/linux-phone-porting
- **Commit**: `f0a60ccfb4764bb0d0295b57ce743a800fb43bee` (2026-08-24)
- **License**: CC BY 4.0
- **Applied as**: methodology reference only (no scripts executed)

## CI Status
- `00-quality.yml`: ✓ GREEN (ShellCheck, YAML, JSON, security, licenses all pass)
- `03-build-kernel.yml`: dispatched, in progress (run 33030495004)

## Known Limitations
1. **NixOS**: No `flake.lock` (requires nix + network). Not reproducible until locked.
2. **Arch Linux ARM**: rootfs MD5 (`23eec86...`) reported by upstream, not independently verified.
3. **postmarketOS Phosh/Plasma**: scaffold-only (pmbootstrap integration placeholder).
4. **No physical hardware testing**: All builds are image-validated only.
5. **GPU**: Adreno 610 requires firmware `a610_zap.mbn` not yet packaged.
6. **ShellCheck pre-existing**: `ssh-harden-rootfs.sh` SC2016 warnings fixed with disable directive (intentional regex pattern).

## Recovery
If this branch causes issues: `git checkout main && git branch -D agent/multi-distro-mainline`

## Checklist
- [x] Quality CI green
- [x] Kernel source verified (tag v7.1 = correct commit)
- [x] All workflows support `workflow_call` for matrix
- [x] No secrets in repository
- [x] No destructive commands in workflows
- [x] All external actions pinned by SHA
- [ ] NixOS flake.lock (blocked on nix availability)
- [ ] Arch Linux ARM rootfs checksum independently verified
- [ ] Physical hardware testing
