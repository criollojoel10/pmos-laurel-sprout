# Upstream Audit Report

Date: 2026-08-27
Auditor: agent (automated)
Branch: `agent/multi-distro-mainline`

## Kernel Sources

### Linux mainline (torvalds/linux)
- **URL**: https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
- **Tag audited**: v7.1 (commit `b3f94b2b3f3e51ab880a51fc6510e1dafba654ed`, 2026-06-14)
- **SM6125 status**: DTS merged since v6.3. `sm6125-xiaomi-laurel-sprout.dts` present in mainline.
- **Panel driver**: `s6e8fc0` merged in v7.1 (`49837b6babe7`)
- **Touchscreen**: FT3518 via edt-ft5x06 merged in v7.0 (`5383e76483dc`)
- **License**: GPL-2.0-only

### sm61x5-mainline/linux (Codeberg)
- **URL**: https://codeberg.org/sm61x5-mainline/linux
- **Branches**: `master` (6.19), `barni2000/7.2-develop`, `barni2000/7.0-develop`
- **Status**: Active, feeds patches upstream to mainline
- **Key patches NOT in mainline**: GPU DTS nodes (adreno610), WCN3990 WiFi, additional thermal, reserved memory
- **License**: GPL-2.0

### LineageOS android_kernel_xiaomi_sm6125
- **URL**: https://github.com/LineageOS/android_kernel_xiaomi_sm6125
- **Branch**: lineage-23.2 (kernel 4.14, downstream Android)
- **Purpose**: Reference DTB, firmware layout, GPIO/clock documentation
- **NOT for mainline use** — downstream Android kernel

## Local Patches Status

| Patch | Target | Status | Upstream? |
|-------|--------|--------|-----------|
| 0001-dts-mdss-panel-s6e8fc0 | v7.1 | downstream-needed | Panel driver merged; DTS enable not yet in mainline DTS for laurel board |
| 0002-dtsi-gpu-adreno610 | v7.1 | downstream-only | GPU DTS nodes for SM6125 not in mainline |
| 0003-dts-enable-gpu | v7.1 | downstream-only | GPU enable + zap-shader path, downstream |
| 0004-dts-enable-wifi-wcn3990 | v7.1 | downstream-only | WCN3990 SNOC node, not upstream |

### New upstream patches (not yet merged)
- **2026-08-21**: Thermal TSENS v2 for SM6125 (Roman Linev) — not merged
- **2026-08-24**: Reserved memory fix for laurel-sprout (Roman Linev) — not merged
- **2026-03-20**: Display panel v7 series (Yedaya Katsman) — merged in v7.1

## Distro Sources

### postmarketOS
- **pmaports URL**: https://gitlab.postmarketos.org/postmarketOS/pmaports
- **xiaomi-laurel status**: ARCHIVED (moved to device/archived/)
- **Kernel package**: linux-postmarketos-qcom-sm6125 (v6.1-r3)
- **Phosh**: postmarketos-ui-phosh (v33-r0, Phosh 0.55.0) — fully supported
- **Plasma Mobile**: postmarketos-ui-plasma-mobile — fully supported, systemd only
- **pmbootstrap**: https://gitlab.postmarketos.org/postmarketOS/pmbootstrap

### Arch Linux ARM
- **URL**: https://archlinuxarm.org
- **Rootfs**: ArchLinuxARM-aarch64-latest.tar.gz (~791 MiB, rebuilt 2026-08-05)
- **Phosh**: 0.54.0-1 (extra repo)
- **Plasma Mobile**: 6.7.4-1 (extra repo)
- **Build method**: Extract generic rootfs + custom kernel + mkinitcpio

### NixOS / Mobile NixOS
- **Mobile NixOS**: https://github.com/NixOS/mobile-nixos — active (1322 stars)
- **SM6125 support**: NOT available. No device port exists.
- **Closest**: qualcomm-sdm845 devices
- **Phosh in nixpkgs**: 0.54.0, NixOS module available
- **Build**: Flake-based cross-compilation from x86_64 to aarch64
- **Blocker**: No Mobile NixOS module for SM6125/trinket. Would require creating a new device port.
- **Alternative**: Vanilla Mobile NixOS (https://github.com/vanilla-mobile-nixos/vanilla-mobile-nixos) — also no SM6125

## Conclusions

1. **Kernel base v7.1 is correct** — SM6125 DTS is upstream; panel/touchscreen drivers merged. Local patches are needed only for GPU DTS nodes and WiFi WCN3990.
2. **postmarketOS Phosh is viable** — first-class pmbootstrap option, systemd recommended.
3. **Arch Linux ARM is immediately viable** — generic rootfs + custom kernel + mkinitcpio. Phosh and Plasma Mobile both available.
4. **NixOS is blocked** — Mobile NixOS has no SM6125 port. A minimal NixOS flake can be created using nixpkgs cross-compilation + custom kernel derivation, but without Mobile NixOS device module, boot configuration must be manual.
5. **New upstream patches pending**: thermal TSENS v2 and reserved memory fix for laurel-sprout are under review (Aug 2026).
