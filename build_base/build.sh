#!/bin/bash
set -euo pipefail

# SELinux: ship enforcing. Docker builds don't preserve security xattrs, but
# that doesn't matter here — bootc/ostree runs restorecon against the deployed
# tree on every deployment using the policy bundled in the image, so all files
# are correctly labeled before the system ever boots.

# Apply KythOS branding to the base image
cat > /etc/os-release <<'EOF' || true
NAME="KythOS"
PRETTY_NAME="KythOS 44"
ID=fedora
VERSION_ID="44"
ANSI_COLOR="0;34"
HOME_URL="https://github.com/mrtrick37/kyth"
SUPPORT_URL="https://github.com/mrtrick37/kyth/discussions"
BUG_REPORT_URL="https://github.com/mrtrick37/kyth/issues"
EOF

echo "KythOS base customization applied"

# ── CachyOS kernel ─────────────────────────────────────────────────────────
# Install with --noscripts to skip the %posttrans that calls rpm-ostree
# kernel-install → dracut, which fails in container builds due to EXDEV errors
# when dracut tries to rename tmp files across the overlay filesystem.
# We run dracut ourselves below with full control over the environment.
dnf5 copr enable -y bieszczaders/kernel-cachyos
dnf5 install -y --setopt=tsflags=noscripts kernel-cachyos-modules

CACHYOS_KVER=$(basename "$(echo /usr/lib/modules/*cachyos*)")
depmod -a "${CACHYOS_KVER}"

dnf5 install -y --setopt=tsflags=noscripts --skip-unavailable \
    kernel-cachyos \
    kernel-cachyos-core

depmod -a "${CACHYOS_KVER}"

# Remove every non-CachyOS kernel from /usr/lib/modules/ so bootc sees
# exactly one kernel (it errors out if multiple subdirectories are present).
for kdir in /usr/lib/modules/*/; do
    kver=$(basename "$kdir")
    if [[ "$kver" != *cachyos* ]]; then
        echo "Removing non-CachyOS kernel: ${kver}"
        rm -rf "$kdir"
    fi
done
rpm -qa | grep -E '^kernel' | grep -v cachyos | xargs -r rpm --nodeps -e 2>/dev/null || true

# Ensure vmlinuz is in the OSTree-expected location
# (kernel RPMs may put it in /boot; bootc needs it at /usr/lib/modules/<kver>/vmlinuz)
if [ ! -f "/usr/lib/modules/${CACHYOS_KVER}/vmlinuz" ]; then
    if [ -f "/boot/vmlinuz-${CACHYOS_KVER}" ]; then
        cp --no-preserve=all "/boot/vmlinuz-${CACHYOS_KVER}" "/usr/lib/modules/${CACHYOS_KVER}/vmlinuz" 2>/dev/null
    fi
fi

# ── Plymouth boot splash ─────────────────────────────────────────────────────
# Install Plymouth here so the initramfs is built with the KythOS theme already
# embedded — eliminating a second dracut run in the branding layer.
# librsvg2-tools is installed temporarily to render the SVG logo to PNG.
dnf5 install -y plymouth plymouth-plugin-script librsvg2-tools

PLYMOUTH_DIR=/usr/share/plymouth/themes/kyth
mkdir -p "${PLYMOUTH_DIR}"
cp /run/plymouth/kyth.plymouth "${PLYMOUTH_DIR}/kyth.plymouth"
cp /run/plymouth/kyth.script   "${PLYMOUTH_DIR}/kyth.script"
rsvg-convert -w 200 /run/plymouth/kyth-logo.svg -o "${PLYMOUTH_DIR}/kyth-logo.png"
plymouth-set-default-theme kyth

dnf5 remove -y librsvg2-tools || true

# Write dracut config — force the ostree and plymouth modules.
# Without ostree the initramfs cannot find or mount the root filesystem.
# Without plymouth the boot splash is not shown.
# DRM module ensures GPU drivers load before Plymouth starts rendering.
mkdir -p /etc/dracut.conf.d
cat > /etc/dracut.conf.d/99-kyth.conf <<'DRACUTEOF'
add_dracutmodules+=" ostree plymouth drm "
# virtio_blk/virtio_scsi/ahci are built into the CachyOS kernel (=y),
# so add_drivers has no effect for them. Kept for documentation.
add_drivers+=" virtio_blk virtio_scsi virtio_pci nvme ahci "
DRACUTEOF

TMPDIR=/var/tmp dracut \
    --no-hostonly \
    --compress "zstd -1" \
    --kver "${CACHYOS_KVER}" \
    --force \
    "/usr/lib/modules/${CACHYOS_KVER}/initramfs" \
    2> >(grep -Ev 'xattr|fail to copy' >&2)

dnf5 copr disable -y bieszczaders/kernel-cachyos

# Set kernel args for the installed system via bootc kargs.d.
# quiet: suppress kernel log spam on the console.
# splash: activate Plymouth so the boot splash is shown.
# iommu=pt: Intel VT-d passthrough mode — prevents strict IOMMU isolation from
#   breaking DRM/KMS on Intel vPro and similar enterprise hardware where VT-d is
#   enabled by default. Transparent/no-op on AMD systems.
mkdir -p /usr/lib/bootc/kargs.d
cat > /usr/lib/bootc/kargs.d/99-kyth.toml <<'KARGSEOF'
kargs = ["quiet", "splash", "threadirqs", "iommu=pt", "pcie_aspm=off"]
KARGSEOF

# ── SDDM — ensure graphical target ───────────────────────────────────────────
systemctl enable sddm 2>/dev/null || true
systemctl set-default graphical.target 2>/dev/null || true

# Mask bootloader-update.service: this ostree/rpm-ostree service tries to
# update the bootloader on every boot but always fails in our bootc image,
# producing noisy FAILED entries in the boot log.
systemctl mask bootloader-update.service 2>/dev/null || true

# Mask systemd-remount-fs.service: on bootc/ostree the root filesystem is
# already mounted correctly by the bootloader; the remount always fails with
# exit code 32 producing a FAILED unit every boot.
systemctl mask systemd-remount-fs.service 2>/dev/null || true

# Force-mask plasmalogin.service at build time. KDE 6.6 ships with plasmalogin
# enabled by default, but it crashes on first boot on systems without hardware GL
# (VMs, some AMD systems). SDDM is the display manager in use. Using an explicit
# symlink to /dev/null ensures it's masked before systemd first reads it on boot.
rm -f /etc/systemd/system/plasmalogin.service
ln -s /dev/null /etc/systemd/system/plasmalogin.service

# ── SDDM display server: Wayland by default ───────────────────────────────────
# Keep the on-disk config aligned with the documented product defaults so
# image behavior is obvious during debugging and CI review.
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-display-server.conf <<'EOF'
[General]
DisplayServer=wayland

[Wayland]
SessionDir=/usr/share/wayland-sessions
CompositorCommand=kwin_wayland --no-global-shortcuts --no-lockscreen --locale1
EOF

