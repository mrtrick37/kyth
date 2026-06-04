#!/bin/bash
set -euo pipefail

KYTH_KERNEL_FLAVOR="${KYTH_KERNEL_FLAVOR:-fedora}"

write_kernel_flavor() {
    mkdir -p /usr/share/kyth
    printf '%s\n' "${KYTH_KERNEL_FLAVOR}" > /usr/share/kyth/kernel-flavor
}

write_kyth_os_release() {
    local target=$1
    mkdir -p "$(dirname "${target}")"
    cat > "${target}" <<'EOF'
NAME="KythOS"
PRETTY_NAME="KythOS 44"
ID=kythos
VERSION="44"
VERSION_ID="44"
ANSI_COLOR="0;34"
LOGO=kyth
HOME_URL="https://github.com/mrtrick37/kyth"
SUPPORT_URL="https://github.com/mrtrick37/kyth/discussions"
BUG_REPORT_URL="https://github.com/mrtrick37/kyth/issues"
EOF
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

write_kyth_os_release /usr/lib/os-release
rm -f /etc/os-release
write_kyth_os_release /etc/os-release

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

# CachyOS rebuilds its initramfs in this base layer, before the main image layer
# installs the reusable KythOS Plymouth guard. Provide the same dracut module
# locally so dracut can resolve kyth-plymouth here too.
KYTH_PLYMOUTH_DRACUT_DIR=/usr/lib/dracut/modules.d/46kyth-plymouth
mkdir -p "${KYTH_PLYMOUTH_DRACUT_DIR}"
cat > "${KYTH_PLYMOUTH_DRACUT_DIR}/module-setup.sh" <<'KYTHPLYMOUTHEOF'
#!/usr/bin/bash

check() {
    return 0
}

depends() {
    echo plymouth
    return 0
}

install() {
    mkdir -p \
        "${initdir}/etc/plymouth" \
        "${initdir}/usr/share/plymouth/themes"
    cat > "${initdir}/etc/plymouth/plymouthd.conf" <<'PLYMOUTHCONF'
[Daemon]
Theme=kyth
ShowDelay=0
PLYMOUTHCONF
    cat > "${initdir}/usr/share/plymouth/plymouthd.defaults" <<'PLYMOUTHDEFAULTS'
[Daemon]
Theme=kyth
ShowDelay=0
PLYMOUTHDEFAULTS
    ln -sfn kyth/kyth.plymouth \
        "${initdir}/usr/share/plymouth/themes/default.plymouth"
    rm -rf \
        "${initdir}/usr/share/plymouth/themes/bgrt-fedora" \
        "${initdir}/usr/share/plymouth/themes/bgrt" \
        "${initdir}/usr/share/plymouth/themes/spinner"
    inst_libdir_file "plymouth/script.so"
    inst_multiple \
        /usr/share/plymouth/themes/kyth/kyth.plymouth \
        /usr/share/plymouth/themes/kyth/kyth.script \
        /usr/share/plymouth/themes/kyth/kyth-logo.png
    inst_multiple -o \
        /etc/os-release \
        /usr/lib/os-release
}
KYTHPLYMOUTHEOF
chmod 0755 "${KYTH_PLYMOUTH_DRACUT_DIR}/module-setup.sh"
unset KYTH_PLYMOUTH_DRACUT_DIR

# Write dracut config — applies on next initramfs regeneration (bootc deploy,
# or dracut run in the cachy path below).
mkdir -p /etc/dracut.conf.d
cat > /etc/dracut.conf.d/99-kyth.conf <<'DRACUTEOF'
add_dracutmodules+=" ostree drm plymouth kyth-plymouth "
add_drivers+=" virtio_blk virtio_scsi virtio_pci nvme ahci virtio_gpu qxl bochs overlay "
DRACUTEOF

# For the CachyOS kernel we must rebuild the initramfs at image-build time
# because the kernel itself was just replaced.  For the stock Fedora kernel
# the upstream base image already ships a valid initramfs; bootc regenerates
# it on first deployment using the dracut.conf.d above.
if [[ "${KYTH_KERNEL_FLAVOR}" == "cachy" ]]; then
    mkdir -p /etc/plymouth /usr/share/plymouth
    cat > /etc/plymouth/plymouthd.conf <<'PLYMOUTHCONF'
[Daemon]
Theme=kyth
ShowDelay=0
PLYMOUTHCONF
    install -m 0644 /etc/plymouth/plymouthd.conf /usr/share/plymouth/plymouthd.defaults
    TMPDIR=/var/tmp dracut \
        --no-hostonly \
        --compress "zstd -1" \
        --kver "${KVER}" \
        --force \
        --add kyth-plymouth \
        --install "/etc/plymouth/plymouthd.conf /usr/share/plymouth/plymouthd.defaults" \
        "/usr/lib/modules/${KVER}/initramfs" \
        2> >(grep -Ev 'xattr|fail to copy' >&2)
    if command -v lsinitrd >/dev/null 2>&1; then
        _initrd_listing="$(mktemp)"
        lsinitrd "/usr/lib/modules/${KVER}/initramfs" > "${_initrd_listing}"
        grep -q 'usr/share/plymouth/themes/kyth/kyth.plymouth' "${_initrd_listing}" || {
            echo "ERROR: CachyOS initramfs does not contain KythOS Plymouth theme" >&2
            exit 1
        }
        if ! lsinitrd -f /etc/plymouth/plymouthd.conf "/usr/lib/modules/${KVER}/initramfs" | grep -q '^Theme=kyth$'; then
            echo "ERROR: CachyOS initramfs Plymouth daemon config does not force Theme=kyth" >&2
            echo "---- /etc/plymouth/plymouthd.conf from initramfs ----" >&2
            lsinitrd -f /etc/plymouth/plymouthd.conf "/usr/lib/modules/${KVER}/initramfs" >&2 || true
            exit 1
        fi
        if ! lsinitrd -f /usr/share/plymouth/plymouthd.defaults "/usr/lib/modules/${KVER}/initramfs" | grep -q '^Theme=kyth$'; then
            echo "ERROR: CachyOS initramfs Plymouth defaults do not force Theme=kyth" >&2
            echo "---- /usr/share/plymouth/plymouthd.defaults from initramfs ----" >&2
            lsinitrd -f /usr/share/plymouth/plymouthd.defaults "/usr/lib/modules/${KVER}/initramfs" >&2 || true
            exit 1
        fi
        if grep -Ei 'usr/share/plymouth/themes/(bgrt-fedora|bgrt|spinner)/.*(fedora|watermark|logo)' "${_initrd_listing}" >&2; then
            echo "ERROR: Fedora Plymouth fallback branding leaked into CachyOS initramfs" >&2
            exit 1
        fi
        rm -f "${_initrd_listing}"
    fi
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
