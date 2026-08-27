#!/usr/bin/env bash
#
# Licencia: GPL-3.0-or-later
#
# build-archlinux-rootfs.sh
#
# Builds an Arch Linux ARM rootfs for laurel_sprout using QEMU user-static
# binfmt. Runs in GitHub Actions, NOT locally.
#
# Usage:
#   scripts/build-archlinux-rootfs.sh \
#     --kernel-artifact <dir> \
#     --variant console|gnome|kde \
#     --out <dir>

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

KERNEL_ARTIFACT=""
VARIANT="console"
OUT=""

usage() {
  echo "usage: $0 --kernel-artifact <dir> --variant console|gnome|kde --out <dir>" >&2
  exit 2
}

while (( $# > 0 )); do
  case "$1" in
    --kernel-artifact) KERNEL_ARTIFACT="$2"; shift 2 ;;
    --variant) VARIANT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$KERNEL_ARTIFACT" && -n "$OUT" ]] || usage
[[ "$VARIANT" == "console" || "$VARIANT" == "gnome" || "$VARIANT" == "kde" ]] || usage
[[ -d "$KERNEL_ARTIFACT" ]] || { echo "ERROR: kernel artifact dir not found: $KERNEL_ARTIFACT" >&2; exit 1; }

info() { printf '[archlinux] %s\n' "$*" >&2; }
mkdir -p "$OUT"

# Package lists
CONSOLE_PKGS="$REPO_ROOT/configs/archlinux/console-packages.txt"
GNOME_PKGS="$REPO_ROOT/configs/archlinux/gnome-packages.txt"
KDE_PKGS="$REPO_ROOT/configs/archlinux/kde-packages.txt"

info "variant: $VARIANT"
info "kernel artifact: $KERNEL_ARTIFACT"

# Step 1: Download and extract Arch Linux ARM rootfs
info "downloading Arch Linux ARM rootfs..."
ROOTFS_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
ROOTFS_MD5="23eec86365b24f7913c403e8f4e8719b"
ROOTFS_ARCHIVE="/tmp/archlinuxarm-rootfs.tar.gz"

curl -sSL -o "$ROOTFS_ARCHIVE" "$ROOTFS_URL"

# Verify MD5
echo "${ROOTFS_MD5}  ${ROOTFS_ARCHIVE}" | md5sum -c - || {
  echo "ERROR: rootfs MD5 mismatch" >&2
  exit 1
}

info "extracting rootfs..."
ROOTFS_DIR="/tmp/archlinux-arm-rootfs"
sudo mkdir -p "$ROOTFS_DIR"
# Use bsdtar (from libarchive-tools) or fall back to tar.
# --no-xattrs is required as non-root: bsdtar cannot restore security.capability
# xattrs (EOPNOTSUPP) in the GitHub Actions environment.
if command -v bsdtar >/dev/null 2>&1; then
  sudo bsdtar -xpf "$ROOTFS_ARCHIVE" --no-xattrs -C "$ROOTFS_DIR"
else
  sudo tar -xf "$ROOTFS_ARCHIVE" --no-xattrs -C "$ROOTFS_DIR"
fi

# Step 2: Set up QEMU user-static for cross-arch chroot
info "setting up QEMU user-static..."
sudo apt-get update -qq
sudo apt-get install -y -qq qemu-user-static binfmt-support
sudo update-binfmts --enable qemu-aarch64 || true

# Step 3: Copy kernel artifacts into rootfs
info "installing kernel into rootfs..."
sudo mkdir -p "$ROOTFS_DIR/boot"
sudo cp "$KERNEL_ARTIFACT/Image" "$ROOTFS_DIR/boot/Image"
if [[ -f "$KERNEL_ARTIFACT/Image.gz" ]]; then
  sudo cp "$KERNEL_ARTIFACT/Image.gz" "$ROOTFS_DIR/boot/Image.gz"
fi
if [[ -f "$KERNEL_ARTIFACT/sm6125-xiaomi-laurel-sprout.dtb" ]]; then
  sudo mkdir -p "$ROOTFS_DIR/boot/dtbs"
  sudo cp "$KERNEL_ARTIFACT/sm6125-xiaomi-laurel-sprout.dtb" "$ROOTFS_DIR/boot/dtbs/"
fi
# Extract modules from tar.zst if available
if [[ -f "$KERNEL_ARTIFACT/modules.tar.zst" ]]; then
  info "extracting kernel modules..."
  sudo mkdir -p "$ROOTFS_DIR/lib/modules"
  tar --zstd -xf "$KERNEL_ARTIFACT/modules.tar.zst" -C "$ROOTFS_DIR/lib/modules/" 2>/dev/null || true
fi

# Step 4: Install packages via pacman in QEMU chroot
info "installing base packages..."
PACKAGES=$(grep -v '^#' "$CONSOLE_PKGS" | tr '\n' ' ')
if [[ "$VARIANT" == "gnome" ]]; then
  GNOME_PACKAGES=$(grep -v '^#' "$GNOME_PKGS" | tr '\n' ' ')
  PACKAGES="$PACKAGES $GNOME_PACKAGES"
elif [[ "$VARIANT" == "kde" ]]; then
  KDE_PACKAGES=$(grep -v '^#' "$KDE_PKGS" | tr '\n' ' ')
  PACKAGES="$PACKAGES $KDE_PACKAGES"
fi

# Configure pacman mirror
sudo tee "$ROOTFS_DIR/etc/pacman.d/mirrorlist" > /dev/null <<'MIRROR'
Server = http://mirror.archlinuxarm.org/$arch/$repo
MIRROR

# pacman requires the cache dir to exist to determine its mount point at
# transaction commit; the ALARM tarball may omit it, which makes the
# emulated pacman fail with "could not determine cachedir mount point" and a
# misleading "not enough free disk space" (both from the same failed stat).
sudo mkdir -p "$ROOTFS_DIR/var/cache/pacman/pkg"

# Mount necessary filesystems for chroot
sudo mount --bind /dev "$ROOTFS_DIR/dev" 2>/dev/null || true
sudo mount --bind /dev/pts "$ROOTFS_DIR/dev/pts" 2>/dev/null || true
sudo mount -t proc proc "$ROOTFS_DIR/proc" 2>/dev/null || true
sudo mount -t sysfs sysfs "$ROOTFS_DIR/sys" 2>/dev/null || true

# pacman's disk-space check resolves the cache dir's mountpoint via /proc;
# when the chroot root is NOT itself a mount point, the emulated pacman fails
# with "could not determine cachedir mount point /var/cache/pacman/pkg" +
# "failed to commit transaction (not enough free disk space)". Bind-mounting
# the rootfs to itself gives it a real top-level mount point (canonical fix).
sudo mount --bind "$ROOTFS_DIR" "$ROOTFS_DIR" 2>/dev/null || true

# Copy QEMU binary for cross-arch
sudo cp /usr/bin/qemu-aarch64-static "$ROOTFS_DIR/usr/bin/" 2>/dev/null || true

# DNS for chroot: the runner's /etc/resolv.conf usually points to the
# systemd-resolved stub (127.0.0.53) which is unreachable from inside the
# qemu-emulated chroot. The Arch Linux ARM rootfs ships /etc/resolv.conf as a
# symlink to /run/systemd/resolve/stub-resolv.conf (nonexistent in chroot);
# a plain file is REQUIRED for glibc to read it inside the emulated chroot.
sudo rm -f "$ROOTFS_DIR/etc/resolv.conf"
printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' | sudo tee "$ROOTFS_DIR/etc/resolv.conf" > /dev/null

# Diagnostic: confirm the plain resolv.conf landed inside the chroot (the
# tarball ships a symlink into /run/systemd/resolve which does not exist in
# the chroot; glibc/pacman will silently fail DNS otherwise).
echo "::group::chroot /etc/resolv.conf"
sudo chroot "$ROOTFS_DIR" /usr/bin/qemu-aarch64-static /bin/bash -c \
  "test -f /etc/resolv.conf && ls -l /etc/resolv.conf && cat /etc/resolv.conf" \
  2>/dev/null || echo "ERROR: no se pudo leer /etc/resolv.conf dentro del chroot"
echo "::endgroup::"

# Install packages (skip linux-aarch64: we use our custom kernel).
# --disable-sandbox: GitHub Actions kernels lack Landlock support, and pacman
# cannot switch to the 'alpm' sandbox user inside an emulated chroot.
sudo chroot "$ROOTFS_DIR" /usr/bin/qemu-aarch64-static /bin/bash -c "
  set -Eeuo pipefail
  pacman --disable-sandbox -Syy --noconfirm
  pacman --disable-sandbox -Syu --noconfirm --needed $PACKAGES
" 2>&1 | tail -60

# Drop the package download cache to slim the final image and reduce disk
# pressure (each matrix job runs on its own runner).
sudo rm -rf "$ROOTFS_DIR/var/cache/pacman/pkg"/* 2>/dev/null || true

# Step 5: Configure system
info "configuring system..."
sudo tee "$ROOTFS_DIR/etc/hostname" > /dev/null <<'EOF'
laurel-pmos
EOF

# Verify the base system was actually installed (pacman may silently fail
# without resolv.conf/DNS in the chroot, leaving an unusable rootfs).
for BIN in "$ROOTFS_DIR/bin/bash" "$ROOTFS_DIR/usr/bin/pacman" "$ROOTFS_DIR/usr/bin/systemctl"; do
  if [[ ! -e "$BIN" ]]; then
    echo "ERROR: base system incomplete, missing $BIN" >&2
    echo "HINT: check pacman sync output; DNS/resolv.conf or mirror may have failed." >&2
    exit 1
  fi
done
info "base system verified: bash, pacman, systemctl present"

sudo tee "$ROOTFS_DIR/etc/fstab" > /dev/null <<'FSTAB'
# <file system>  <mount point>  <type>  <options>  <dump>  <pass>
/dev/disk/by-label/ARCHLINUX_ROOT  /  ext4  errors=remount-ro  0  1
FSTAB

# Enable systemd services
sudo chroot "$ROOTFS_DIR" /usr/bin/qemu-aarch64-static /bin/bash -c "
  systemctl enable NetworkManager.service 2>/dev/null || true
  systemctl enable sshd.service 2>/dev/null || true
" 2>&1 || true

# Step 6: Unmount
sudo umount "$ROOTFS_DIR/dev/pts" 2>/dev/null || true
sudo umount "$ROOTFS_DIR/dev" 2>/dev/null || true
sudo umount "$ROOTFS_DIR/proc" 2>/dev/null || true
sudo umount "$ROOTFS_DIR/sys" 2>/dev/null || true
sudo umount "$ROOTFS_DIR" 2>/dev/null || true

# Step 7: Create rootfs image
info "creating rootfs image..."
ROOTFS_IMAGE="$OUT/rootfs-archlinux-${VARIANT}-laurel.img"
# Calculate size (add 200MB headroom)
ROOTFS_SIZE=$(sudo du -sm "$ROOTFS_DIR" | awk '{print int($1 * 1.2 + 200)}')
qemu-img create -f raw "$ROOTFS_IMAGE" "${ROOTFS_SIZE}M"

# Create filesystem and copy
sudo mkfs.ext4 -F -L ARCHLINUX_ROOT "$ROOTFS_IMAGE"
MOUNT_DIR="/tmp/archlinux-mount"
sudo mkdir -p "$MOUNT_DIR"
sudo mount -o loop "$ROOTFS_IMAGE" "$MOUNT_DIR"
sudo cp -a "$ROOTFS_DIR"/. "$MOUNT_DIR"/
sudo umount "$MOUNT_DIR"

# Compress
xz -T0 "$ROOTFS_IMAGE"
info "rootfs image created: ${ROOTFS_IMAGE}.xz"

# Generate checksums
cd "$OUT"
sha256sum ./*.img.xz > SHA256SUMS 2>/dev/null || true
cat SHA256SUMS

# Generate manifest
KERNELRELEASE="$(strings "$ROOTFS_DIR/boot/Image" 2>/dev/null | grep -m1 '^Linux version' | sed 's/^Linux version \([^ ]*\).*/\1/' || echo 'unknown')"
jq -n \
  --arg variant "$VARIANT" \
  --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg rootfs_url "$ROOTFS_URL" \
  --arg kernelrelease "$KERNELRELEASE" \
  '{distro:"archlinux", variant:$variant, rootfs_url:$rootfs_url, kernelrelease:$kernelrelease, generated_at:$date}' > manifest.json
cat manifest.json

info "Arch Linux ARM $VARIANT rootfs build completed"
