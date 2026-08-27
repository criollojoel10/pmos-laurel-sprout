# Agent Baseline Report

Generated: 2026-08-27 (UTC)
Branch: `agent/multi-distro-mainline`
Commit: started from `303db1f` (main HEAD)

## Repository State

- Name: pmos-laurel-sprout
- Owner: criollojoel10
- Default branch: main
- Language: Shell
- License: GPL-3.0-or-later (integration) + upstream licenses
- Stars: 0, Forks: 0, Open PRs: 1 (Dependabot), Open Issues: 1
- Last push to main: 2026-08-15

## Branches (remote)

16 branches total. Main branch `main` at `303db1f`. Key research branches:
- `research/wcn3990-v4-rmtfs-bringup` (active, wifi rmtfs fix)
- `research/wcn3990-v3-mpss-bringup` (v3 modem bring-up)
- Multiple fix branches for MPSS/DTB validators

## Workflows (26 total)

| # | Workflow | State | Purpose |
|---|---------|-------|---------|
| 00 | 00-quality | active | Static validation (ShellCheck, YAML, JSON, secrets) |
| 01 | 01-research-upstream | active | Upstream source audit |
| 02 | 02-freeze-sources | active | sources.lock.json proposal |
| 02b | 02-m1-reference-audit | active | M1 device reference audit |
| 03 | 03-build-kernel | active | Kernel debug/release build |
| 04a | 04-build-diagnostic-boot | active | Diagnostic boot image build |
| 04b | 04-build-pmos-console | active | postmarketOS console rootfs |
| 05a | 05-build-pmos-plasma | active | postmarketOS Plasma Mobile rootfs |
| 05b | 05-build-pmos-shell-v71 | active | pmos shell v7.1 build |
| 06 | 06-validate-images | active | Artifact validation |
| 07 | 07-package-prerelease | active | GitHub prerelease packaging |
| 08 | 08-process-device-logs | active | Device log analysis |
| 09 | 09-reproduce-historical-boot | active | Historical boot reproduction |
| 10 | 10-build-historical-rootfs | active | Historical rootfs build |
| 11 | 11-build-historical-ssh-rootfs | active | Historical SSH rootfs |
| 12-15 | v71-native-diag variants | active | Diagnostic initramfs variants |
| 16 | 16-build-linux61-baseline | active | Linux 6.1 baseline build |
| 17-20 | wcn3990 v2-v4 variants | active | WiFi bring-up variants |
| 99 | 99-clean-artifacts | active | Artifact cleanup |

**Missing for multi-distro**: reusable kernel workflow, distro matrix workflow, Arch Linux ARM builds, NixOS builds, Phosh variants.

## Recent Run Status (last 20)

- 00-quality: multiple failures (ShellCheck, last 2026-08-15)
- 20-build-linux61-wcn3990-v4-rmtfs: success (2026-08-15)
- 19-build-linux61-wcn3990-v3: success (2026-08-14)
- 05-build-pmos-shell-v71: success (2026-08-11)
- 03-build-kernel: success (2026-08-11)

**Known issue**: ShellCheck fails on main as of 2026-08-15.

## Kernel

- Base: Linux mainline v7.1 (tag v7.1, commit `b3f94b2b3f3e51ab880a51fc6510e1dafba654ed`)
- Downstream patches: 4 patches in `patches/kernel/` (panel, GPU, GPU enable, WiFi WCN3990)
- Historical patches: 4 patches in `patches/kernel-61/` (WCN3990 v1-v4 for 6.1 fork)
- Config fragments: `laurel-base.fragment`, `laurel-debug.fragment`, `laurel-release.fragment`, `laurel-deny.fragment`
- DTB: `qcom/sm6125-xiaomi-laurel-sprout.dtb`
- Build: cross-compiled on x86_64 Ubuntu runners via GitHub Actions

## Hardware State

| Component | Status | Physical? |
|-----------|--------|-----------|
| UFS | working | Yes |
| Display (simplefb) | partially-working | Yes |
| USB gadget RNDIS | partially-working | Yes |
| GPU Adreno 610 | compiled | No |
| Touchscreen FT3518 | compiled | No |
| WiFi WCN3990 | boot-untested | v4 pending physical |
| Bluetooth | configured | No |
| Battery/PMIC | not-targeted | No |
| Thermal | configured | No |
| CPUfreq | configured | No |
| Audio | not-targeted | No |
| Modem | not-targeted | No |
| Camera | not-targeted | No |

## Missing for Multi-Distro Goal

1. No NixOS configuration exists
2. No Arch Linux ARM configuration exists
3. No Phosh variant for any distro
4. Kernel builds are per-workflow, not reusable
5. No distro matrix workflow
6. No shared kernel artifact pipeline
7. `agent-progress.md` did not exist
8. No `MULTI-DISTRO.md` documentation
9. ShellCheck failure on main needs fixing
10. `sources.lock.json` missing entries for Arch Linux ARM and NixOS tooling
