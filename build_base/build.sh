#!/bin/bash
set -euo pipefail

# SELinux: ship enforcing. Docker builds don't preserve security xattrs, but
# that doesn't matter here — bootc/ostree runs restorecon against the deployed
# tree on every deployment using the policy bundled in the image, so all files
# are correctly labeled before the system ever boots.

# Apply KythOS branding to the base image
echo "KythOS base customization applied"

KYTH_KERNEL_FLAVOR="${KYTH_KERNEL_FLAVOR:-fedora}"

write_kernel_flavor() {
    mkdir -p /usr/share/kyth
    printf '%s\n' "${KYTH_KERNEL_FLAVOR}" > /usr/share/kyth/kernel-flavor
}

latest_kernel_version() {
    find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V | tail -n 1
}

remove_kernel_packages_except() {
    local keep_pattern=$1
    rpm -qa | grep -E '^kernel' | grep -Ev "${keep_pattern}" | xargs -r rpm --nodeps -e 2>/dev/null || true
}

install_cachyos_kernel() {
    # Install with --noscripts to skip the %posttrans that calls rpm-ostree
    # kernel-install -> dracut, which fails in container builds due to EXDEV
    # errors when dracut renames tmp files across the overlay filesystem.
    dnf5 copr enable -y bieszczaders/kernel-cachyos
    dnf5 install -y --setopt=tsflags=noscripts kernel-cachyos-modules

    local kver
    kver=$(basename "$(echo /usr/lib/modules/*cachyos*)")
    depmod -a "${kver}"

    dnf5 install -y --setopt=tsflags=noscripts --skip-unavailable \
        kernel-cachyos \
        kernel-cachyos-core

    depmod -a "${kver}"

    # ASUS Linux support depends on newer ASUS Armoury/WMI platform drivers.
    if ! find "/usr/lib/modules/${kver}" -name 'asus-armoury.ko*' -print -quit | grep -q .; then
        echo "WARNING: CachyOS kernel lacks asus-armoury.ko; ASUS Linux support will be reduced." >&2
    fi

    for kdir in /usr/lib/modules/*/; do
        local existing
        existing=$(basename "$kdir")
        if [[ "$existing" != *cachyos* ]]; then
            echo "Removing non-CachyOS kernel: ${existing}"
            rm -rf "$kdir"
        fi
    done
    remove_kernel_packages_except 'cachyos'

    if [ ! -f "/usr/lib/modules/${kver}/vmlinuz" ] && [ -f "/boot/vmlinuz-${kver}" ]; then
        cp --no-preserve=all "/boot/vmlinuz-${kver}" "/usr/lib/modules/${kver}/vmlinuz" 2>/dev/null || true
    fi

    dnf5 copr disable -y bieszczaders/kernel-cachyos
}

case "${KYTH_KERNEL_FLAVOR}" in
    fedora)
        echo "Using Fedora kernel from upstream base image"
        ;;
    cachy|cachyos)
        KYTH_KERNEL_FLAVOR="cachy"
        install_cachyos_kernel
        ;;
    *)
        echo "Unknown KYTH_KERNEL_FLAVOR: ${KYTH_KERNEL_FLAVOR}" >&2
        echo "Valid values: fedora, cachy" >&2
        exit 1
        ;;
esac
write_kernel_flavor

KVER=$(latest_kernel_version)
if [[ -z "${KVER}" ]]; then
    echo "ERROR: no kernel found in /usr/lib/modules" >&2
    exit 1
fi

if [ ! -f "/usr/lib/modules/${KVER}/vmlinuz" ] && [ -f "/boot/vmlinuz-${KVER}" ]; then
    cp --no-preserve=all "/boot/vmlinuz-${KVER}" "/usr/lib/modules/${KVER}/vmlinuz" 2>/dev/null || true
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
# overlayfs: force-include even if check() fails (dracut-ng checks for overlay.ko
# which may be built-in rather than a loadable module on some Fedora kernels).
force_add_dracutmodules+=" overlayfs "
# virtio_gpu/qxl/bochs: QEMU/KVM display paths. Keep all three available early
# so local tests can switch between virtio, SPICE/QXL, and firmware fallback
# without rebuilding the kernel/initramfs layer.
add_drivers+=" virtio_blk virtio_scsi virtio_pci nvme ahci virtio_gpu qxl bochs "
DRACUTEOF

TMPDIR=/var/tmp dracut \
    --no-hostonly \
    --compress "zstd -1" \
    --kver "${KVER}" \
    --force \
    "/usr/lib/modules/${KVER}/initramfs" \
    2> >(grep -Ev 'xattr|fail to copy' >&2)

# Set kernel args for the installed system via bootc kargs.d.
# Keep hardware-specific GPU workarounds out of the baseline. Those are applied
# later only on systems that need them.
# quiet/rhgb/splash: suppress kernel log spam and show the KythOS Plymouth theme.
# threadirqs: keep the low-latency desktop tuning without affecting display.
# rd.plymouth=1/plymouth.enable=1: explicitly keep Plymouth enabled for boot.
# plymouth.ignore-serial-consoles: keep Plymouth active even on machines/VMs
# that expose a serial console.
# systemd.show_status=false/rd.systemd.show_status=false/loglevel=3/
# rd.udev.log_level=3/vt.global_cursor_default=0: avoid text fallback chatter
# while the graphical splash is taking over the framebuffer.
mkdir -p /usr/lib/bootc/kargs.d
cat > /usr/lib/bootc/kargs.d/99-kyth.toml <<'KARGSEOF'
kargs = ["quiet", "rhgb", "splash", "rd.plymouth=1", "plymouth.enable=1", "plymouth.ignore-serial-consoles", "systemd.show_status=false", "rd.systemd.show_status=false", "loglevel=3", "rd.udev.log_level=3", "vt.global_cursor_default=0", "threadirqs"]
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
