# Skill Audit: linux-phone-porting

Date: 2026-08-27
Skill URL: https://github.com/angelwzr/linux-phone-porting
License: Check repository (assumed permissive for methodology)

## Audit Summary

The skill provides a structured methodology for porting mainline Linux to phones. It is organized in 4 phases:

### Phase 0: Set up the port
- Establish device identity (marketing name, codename, SoC, variant)
- Choose target distro and init
- Determine boot topology (A/B, slot layout, bootloader unlock)
- Full backup of all partitions except userdata
- Record stock DTB, firmware blobs, vendor kernel cmdline, vendor configs

**Application to this project**: Phase 0 is COMPLETE for this repo. Device identity documented, A/B confirmed, fastboot metadata recorded, stock boot layout analyzed.

### Phase 1: Gather evidence from live device
- Capture dmesg before changing anything
- Use live shell (SSH/USB), pstore, ramoops, USB ACM console
- Confirm what is flashed by reading partition back
- Record rules that get overturned

**Application**: Physical evidence gathered for kernel 6.1 (SSH, dmesg). Display, UFS, USB gadget confirmed. GPU, WiFi, touchscreen not yet physically tested with mainline.

### Phase 2: Research before implementing
- Identify subsystem/driver owning the failure
- Research across 6 source families: mainline, downstream vendor, postmarketOS, Halium/UBports, Mobian, NixOS
- Look up userspace libs and tools

**Application**: Research completed for SM6125 upstream status, postmarketOS, Arch Linux ARM, NixOS. Halium/UBports and Mobian not applicable for this multi-distro approach.

### Phase 3: Implement only with evidence-backed hypothesis
- One variable per flash
- Prefer runtime tests over reflash
- After 3 refuted fixes: stop and return to research

**Application**: Patches are evidence-based (from sm61x5-mainline barni2000/7.0-develop). GPU DTS nodes sourced from community fork. WiFi WCN3990 from multi-version bring-up (v1-v4).

## Skill Integration

The skill is a methodology guide, NOT code to execute. It has been:
1. **Read and audited** (this report)
2. **Applied methodologically** to the existing workflow design
3. **Not copied** into the repository as executable code
4. **Referenced** in upstream-audit.md

The skill's principles are already reflected in this repo's AGENTS.md:
- Evidence-first debugging (AGENTS.md §2)
- Physical test documentation (docs/TESTING.md)
- Honest hardware states (AGENTS.md §2, reports/hardware-matrix.json)
- Backup before flash (AGENTS.md §7)
- Phase 8 stop point (AGENTS.md §8)

## Key Takeaways from Skill

1. **Stock DTB is ground truth** — The decompiled stock boot.img DTB (in reports/dtb-audit/) is the highest-authority reference.
2. **Three refuted fixes = wrong model** — Not yet reached for this project; patches are source-based, not guesses.
3. **USB ACM console** — CONFIG_U_SERIAL_CONSOLE + console=ttyGS0 is the only channel that survives a wedge. Worth enabling in debug builds.
4. **ramoops is lossy** — DRAM charge retention decays across unpowered intervals. Check zone size before assuming hurry.
5. **Debug interface can manufacture symptoms** — DRM/GPU crash-state nodes can synthesize fault lines when sampled. Don't trust blindly.
