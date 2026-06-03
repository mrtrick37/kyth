#!/bin/bash
# Plymouth boot splash setup — runs as a standalone Dockerfile layer so Docker
# can cache the expensive dracut rebuild independently of the daily branding layer.
# Source files are COPY'd from the build context to /tmp/kyth-plymouth/ and
# /tmp/kyth-branding/ before this script is called.

set -euo pipefail

PLYMOUTH_THEME_DIR=/usr/share/plymouth/themes/kyth
mkdir -p "${PLYMOUTH_THEME_DIR}"

rsvg-convert -w 256 /tmp/kyth-branding/kyth-logo-transparent.svg \
    -o "${PLYMOUTH_THEME_DIR}/kyth-logo.png"
install -m 0644 /tmp/kyth-plymouth/kyth.plymouth "${PLYMOUTH_THEME_DIR}/"
install -m 0644 /tmp/kyth-plymouth/kyth.script   "${PLYMOUTH_THEME_DIR}/"

# Replace the Fedora watermark in bgrt/spinner fallback themes with a transparent
# PNG so the ASUS firmware logo is not followed by distro branding during the
# brief window before Plymouth loads the kyth theme.
rsvg-convert /tmp/kyth-branding/transparent-watermark.svg \
    -o /tmp/kyth-transparent-watermark.png
for _spinner_dir in \
    /usr/share/plymouth/themes/spinner \
    /usr/share/plymouth/themes/bgrt \
    /usr/share/plymouth/themes/bgrt-fedora; do
    if [ -d "${_spinner_dir}" ]; then
        install -m 0644 /tmp/kyth-transparent-watermark.png \
            "${_spinner_dir}/watermark.png"
    fi
done
rm -f /tmp/kyth-transparent-watermark.png
unset _spinner_dir

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
        /usr/share/plymouth/themes/kyth/kyth.plymouth \
        /usr/share/plymouth/themes/kyth/kyth.script \
        /usr/share/plymouth/themes/kyth/kyth-logo.png
    ln -sfn kyth/kyth.plymouth \
        "${initdir}/usr/share/plymouth/themes/default.plymouth"
}
KYTHPLYMOUTHEOF
chmod 0755 "${KYTH_PLYMOUTH_DRACUT_DIR}/module-setup.sh"
unset KYTH_PLYMOUTH_DRACUT_DIR

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
