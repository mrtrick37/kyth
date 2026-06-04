#!/bin/bash
# Plymouth boot splash setup — runs as a standalone Dockerfile layer so Docker
# can cache the expensive dracut rebuild independently of the daily branding layer.
# Source files are COPY'd from the build context to /tmp/kyth-plymouth/ and
# /tmp/kyth-branding/ before this script is called.

set -euo pipefail

PLYMOUTH_THEME_DIR=/usr/share/plymouth/themes/kyth
mkdir -p "${PLYMOUTH_THEME_DIR}"

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

write_kyth_os_release /usr/lib/os-release
rm -f /etc/os-release
write_kyth_os_release /etc/os-release

rsvg-convert -w 256 /tmp/kyth-branding/kyth-logo-transparent.svg \
    -o "${PLYMOUTH_THEME_DIR}/kyth-logo.png"
install -m 0644 /tmp/kyth-plymouth/kyth.plymouth "${PLYMOUTH_THEME_DIR}/"
install -m 0644 /tmp/kyth-plymouth/kyth.script   "${PLYMOUTH_THEME_DIR}/"

# Replace Fedora watermarks in every Plymouth fallback theme with transparent
# assets. This guard is installed permanently and rerun after later package
# transactions because dnf upgrades can restore upstream theme files.
install -Dm0755 /tmp/plymouth-branding-guard.sh \
    /usr/libexec/kyth-plymouth-branding-guard
/usr/libexec/kyth-plymouth-branding-guard \
    /tmp/kyth-branding/transparent-watermark.svg

# Custom dracut module that explicitly forces Plymouth theme + script plugin
# inclusion into the initramfs. Fedora's upstream 45plymouth module only
# installs whichever theme is the default at dracut run time; 46kyth-plymouth
# runs after it and hard-wires the kyth theme so early-boot never falls back
# to upstream artwork.
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
    inst_libdir_file "plymouth/script.so"
    inst_multiple \
        /etc/plymouth/plymouthd.conf \
        /etc/os-release \
        /usr/lib/os-release \
        /usr/libexec/kyth-plymouth-branding-guard \
        /usr/share/plymouth/themes/kyth/kyth.plymouth \
        /usr/share/plymouth/themes/kyth/kyth.script \
        /usr/share/plymouth/themes/kyth/kyth-logo.png
    ln -sfn kyth/kyth.plymouth \
        "${initdir}/usr/share/plymouth/themes/default.plymouth"
    rm -rf \
        "${initdir}/usr/share/plymouth/themes/bgrt-fedora" \
        "${initdir}/usr/share/plymouth/themes/bgrt" \
        "${initdir}/usr/share/plymouth/themes/spinner"
}
KYTHPLYMOUTHEOF
chmod 0755 "${KYTH_PLYMOUTH_DRACUT_DIR}/module-setup.sh"
unset KYTH_PLYMOUTH_DRACUT_DIR

mkdir -p /etc/dracut.conf.d
if [[ -f /etc/dracut.conf.d/99-kyth.conf ]]; then
    if ! grep -q 'kyth-plymouth' /etc/dracut.conf.d/99-kyth.conf; then
        sed -i 's/add_dracutmodules+="\([^"]*\)"/add_dracutmodules+="\1 kyth-plymouth"/' \
            /etc/dracut.conf.d/99-kyth.conf
        grep -q 'kyth-plymouth' /etc/dracut.conf.d/99-kyth.conf || \
            printf '\nadd_dracutmodules+=" kyth-plymouth "\n' >> /etc/dracut.conf.d/99-kyth.conf
    fi
else
    cat > /etc/dracut.conf.d/99-kyth.conf <<'DRACUTEOF'
add_dracutmodules+=" ostree drm plymouth kyth-plymouth "
DRACUTEOF
fi

plymouth-set-default-theme kyth

# Rebuild the initramfs for every installed kernel. dracut exits non-zero on
# any failure, so no separate integrity check is needed.
for _kernel_dir in /usr/lib/modules/*; do
    [ -d "${_kernel_dir}" ] || continue
    _kernel_ver=$(basename "${_kernel_dir}")
    TMPDIR=/var/tmp dracut \
        --no-hostonly \
        --compress "zstd -1" \
        --kver "${_kernel_ver}" \
        --force \
        "${_kernel_dir}/initramfs" \
        2> >(grep -Ev 'xattr|fail to copy' >&2)
done
unset _kernel_dir _kernel_ver
