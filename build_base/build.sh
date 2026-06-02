#!/bin/bash
set -euo pipefail

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
    dnf5 copr enable -y bieszczaders/kernel-cachyos
    dnf5 install -y --setopt=tsflags=noscripts kernel-cachyos-modules

    local kver
    kver=$(basename "$(echo /usr/lib/modules/*cachyos*)")

    dnf5 install -y --setopt=tsflags=noscripts --skip-unavailable \
        kernel-cachyos \
        kernel-cachyos-core

    depmod -a "${kver}"

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

# ── Plymouth boot splash ──────────────────────────────────────────────────────
dnf5 install -y --exclude='kernel*' plymouth plymouth-plugin-script librsvg2-tools

PLYMOUTH_DIR=/usr/share/plymouth/themes/kyth
mkdir -p "${PLYMOUTH_DIR}"
cp /run/plymouth/kyth.plymouth "${PLYMOUTH_DIR}/kyth.plymouth"
cp /run/plymouth/kyth.script   "${PLYMOUTH_DIR}/kyth.script"
rsvg-convert -w 200 /run/plymouth/kyth-logo.svg -o "${PLYMOUTH_DIR}/kyth-logo.png"
plymouth-set-default-theme kyth

dnf5 remove -y librsvg2-tools || true

# Write dracut config — applies on next initramfs regeneration (bootc deploy,
# or dracut run in the cachy path below).
mkdir -p /etc/dracut.conf.d
cat > /etc/dracut.conf.d/99-kyth.conf <<'DRACUTEOF'
add_dracutmodules+=" ostree drm plymouth "
add_drivers+=" virtio_blk virtio_scsi virtio_pci nvme ahci virtio_gpu qxl bochs overlay "
DRACUTEOF

# For the CachyOS kernel we must rebuild the initramfs at image-build time
# because the kernel itself was just replaced.  For the stock Fedora kernel
# the upstream base image already ships a valid initramfs; bootc regenerates
# it on first deployment using the dracut.conf.d above.
if [[ "${KYTH_KERNEL_FLAVOR}" == "cachy" ]]; then
    TMPDIR=/var/tmp dracut \
        --no-hostonly \
        --compress "zstd -1" \
        --kver "${KVER}" \
        --force \
        "/usr/lib/modules/${KVER}/initramfs" \
        2> >(grep -Ev 'xattr|fail to copy' >&2)
fi

# ── Kernel args (bootc kargs.d) ───────────────────────────────────────────────
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

systemctl mask bootloader-update.service 2>/dev/null || true
systemctl mask systemd-remount-fs.service 2>/dev/null || true

rm -f /etc/systemd/system/plasmalogin.service
ln -s /dev/null /etc/systemd/system/plasmalogin.service
