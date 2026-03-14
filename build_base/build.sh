#!/bin/bash
set -euo pipefail

# Apply Kyth branding to the base image
cat > /etc/os-release <<'EOF' || true
NAME="Kyth"
PRETTY_NAME="Kyth 43"
ID=fedora
VERSION_ID="43"
ANSI_COLOR="0;34"
HOME_URL="https://example.com/kyth"
SUPPORT_URL="https://example.com/kyth/support"
BUG_REPORT_URL="https://example.com/kyth/issues"
EOF

# Remove Waydroid artifacts if present
rm -f /usr/share/applications/*waydroid*.desktop || true
rm -f /usr/local/share/applications/*waydroid*.desktop || true
rm -f /usr/share/kservices5/*waydroid* || true
rm -rf /usr/share/waydroid /var/lib/waydroid || true

echo "Kyth base customization applied"

# --- CachyOS kernel installation (copied from build_files/build.sh) ---
echo "Installing CachyOS kernel..."
dnf5 copr enable -y bieszczaders/kernel-cachyos
dnf5 install -y --setopt=tsflags=noscripts kernel-cachyos-modules

CACHYOS_KVER=$(ls /usr/lib/modules/ | grep cachyos | head -1)
depmod -a "${CACHYOS_KVER}"

dnf5 install -y --setopt=tsflags=noscripts --skip-unavailable \
	kernel-cachyos \
	kernel-cachyos-core \
	kernel-cachyos-devel

depmod -a "${CACHYOS_KVER}"

# Remove every non-CachyOS kernel from /usr/lib/modules/ so bootc sees
# exactly one kernel (it errors out if multiple subdirectories are present).
echo "Removing non-CachyOS kernels from /usr/lib/modules/ ..."
for kdir in /usr/lib/modules/*/; do
    kver=$(basename "$kdir")
    if [[ "$kver" != *cachyos* ]]; then
        echo "  removing: $kver"
        rm -rf "$kdir"
    fi
done

# Ensure vmlinuz is in the OSTree-expected location
if [ ! -f "/usr/lib/modules/${CACHYOS_KVER}/vmlinuz" ]; then
	if [ -f "/boot/vmlinuz-${CACHYOS_KVER}" ]; then
		cp --no-preserve=all "/boot/vmlinuz-${CACHYOS_KVER}" "/usr/lib/modules/${CACHYOS_KVER}/vmlinuz" 2>/dev/null
	fi
fi

# Generate a standard disk-boot initramfs at the OSTree-expected location.
# tsflags=noscripts skipped dracut during kernel install, so we run it manually.
# This initramfs is used by bootc when installing the image to disk — without it
# the installed system kernel panics with "Unable to mount root fs on unknown-block(0,0)".
echo "Generating disk-boot initramfs for ${CACHYOS_KVER}..."
TMPDIR=/var/tmp dracut \
    --no-hostonly \
    --kver "${CACHYOS_KVER}" \
    --force \
    "/usr/lib/modules/${CACHYOS_KVER}/initramfs.img"
echo "initramfs.img generated at /usr/lib/modules/${CACHYOS_KVER}/initramfs.img"
