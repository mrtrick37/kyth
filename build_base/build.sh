#!/bin/bash
set -euo pipefail

# SELinux: ship enforcing. Docker builds don't preserve security xattrs, but
# that doesn't matter here — bootc/ostree runs restorecon against the deployed
# tree on every deployment using the policy bundled in the image, so all files
# are correctly labeled before the system ever boots.

# Apply KythOS branding to the base image
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
# amdgpu.sg_display=0: disables scatter-gather display on the amdgpu driver.
#   Without this, AMD laptop panels (eDP) blink/flash repeatedly during the
#   SDDM KMS handoff on AMD Radeon laptop designs (confirmed ASUS TUF A16).
#   Forces contiguous-memory framebuffer for the display engine.
# amdgpu.runpm=0: disables GPU runtime power management on AMD.
#   RDNA2/3 GPUs can enter low-power states during the initramfs→SDDM
#   display handoff, resetting the display engine mid-transition and causing
#   the persistent blink loop seen on AMD laptops. Keeping the GPU fully
#   powered during boot eliminates the race.
# video=efifb:off: disables the EFI/UEFI GOP framebuffer (efifb/simpledrm).
#   Without this the kernel creates a simpledrm device over the UEFI framebuffer
#   during early boot. When amdgpu then takes DRM master the two drivers fight
#   over the display output. Disabling efifb lets amdgpu own the display from
#   the start with no conflict.
# splash is intentionally absent: Plymouth holds the amdgpu DRM master and the
#   Plymouth→Xorg handoff races on RDNA3, causing Xorg to fail and SDDM to
#   restart it repeatedly (the blink loop). Boot goes directly to SDDM instead.
mkdir -p /usr/lib/bootc/kargs.d
cat > /usr/lib/bootc/kargs.d/99-kyth.toml <<'KARGSEOF'
kargs = ["quiet", "threadirqs", "iommu=pt", "pcie_aspm=off", "amdgpu.sg_display=0", "amdgpu.runpm=0", "video=efifb:off"]
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


