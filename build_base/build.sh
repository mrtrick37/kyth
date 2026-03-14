#!/bin/bash
set -euo pipefail

# Apply mt-OS branding to the base image
cat > /etc/os-release <<'EOF' || true
NAME="mt-OS"
PRETTY_NAME="mt-OS 43"
ID=fedora
VERSION_ID="43"
ANSI_COLOR="0;34"
HOME_URL="https://example.com/mt-os"
SUPPORT_URL="https://example.com/mt-os/support"
BUG_REPORT_URL="https://example.com/mt-os/issues"
EOF

# Remove Waydroid artifacts if present
rm -f /usr/share/applications/*waydroid*.desktop || true
rm -f /usr/local/share/applications/*waydroid*.desktop || true
rm -f /usr/share/kservices5/*waydroid* || true
rm -rf /usr/share/waydroid /var/lib/waydroid || true

echo "mt-OS base customization applied"

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

# Ensure vmlinuz is in the OSTree-expected location
if [ ! -f "/usr/lib/modules/${CACHYOS_KVER}/vmlinuz" ]; then
	if [ -f "/boot/vmlinuz-${CACHYOS_KVER}" ]; then
		cp --no-preserve=all "/boot/vmlinuz-${CACHYOS_KVER}" "/usr/lib/modules/${CACHYOS_KVER}/vmlinuz" 2>/dev/null
	fi
fi
