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

# ASUS Linux support depends on the newer ASUS Armoury/WMI platform drivers.
# CachyOS mainline kernels currently carry these; warn loudly if the Fedora
# COPR ever drops them so the userspace tools do not silently become half-useful.
if ! find "/usr/lib/modules/${CACHYOS_KVER}" -name 'asus-armoury.ko*' -print -quit | grep -q .; then
    echo "WARNING: CachyOS kernel lacks asus-armoury.ko; ASUS Linux support will be reduced." >&2
fi

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

# Write dracut config.
# ostree module is required — without it the initramfs cannot find or mount
# the ostree deployment root.
# drm module pulls in KMS drivers so the display is available early.
# plymouth is included so the KythOS splash theme is visible during boot.
mkdir -p /etc/dracut.conf.d
cat > /etc/dracut.conf.d/99-kyth.conf <<'DRACUTEOF'
add_dracutmodules+=" ostree drm plymouth "
# virtio_gpu/qxl/bochs: QEMU/KVM display paths. Keep all three available early
# so local tests can switch between virtio, SPICE/QXL, and firmware fallback
# without rebuilding the kernel/initramfs layer.
add_drivers+=" virtio_blk virtio_scsi virtio_pci nvme ahci virtio_gpu qxl bochs "
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
# Keep hardware-specific GPU workarounds out of the baseline. Those are applied
# later only on systems that need them.
# quiet/rhgb/splash: suppress kernel log spam and show the KythOS Plymouth theme.
# threadirqs: keep the low-latency desktop tuning without affecting display.
# rd.plymouth=1/plymouth.enable=1: explicitly keep Plymouth enabled for boot.
mkdir -p /usr/lib/bootc/kargs.d
cat > /usr/lib/bootc/kargs.d/99-kyth.toml <<'KARGSEOF'
kargs = ["quiet", "rhgb", "splash", "rd.plymouth=1", "plymouth.enable=1", "threadirqs", "console=tty0", "console=ttyS0,115200"]
KARGSEOF

# ── SDDM — ensure graphical target ───────────────────────────────────────────
systemctl enable sddm 2>/dev/null || true
systemctl set-default graphical.target 2>/dev/null || true
ln -sf /usr/lib/systemd/system/sddm.service \
    /etc/systemd/system/display-manager.service
mkdir -p /etc/systemd/system/graphical.target.wants
ln -sf /etc/systemd/system/display-manager.service \
    /etc/systemd/system/graphical.target.wants/display-manager.service
ln -sf /usr/lib/systemd/system/graphical.target \
    /etc/systemd/system/default.target

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
