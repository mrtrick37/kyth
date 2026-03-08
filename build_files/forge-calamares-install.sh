#!/usr/bin/bash
# forge-calamares-install — Called by Calamares shellprocess module.
#
# Reads the target disk from /tmp/forge-target-disk (written by
# forge-install-launcher before Calamares was started), then runs
# 'bootc install to-disk' to pull and write Forge to that disk.

set -euo pipefail

DISK_FILE="/tmp/forge-target-disk"
TARGET_IMGREF="ghcr.io/mrtrick37/forge:latest"

if [[ ! -f "${DISK_FILE}" ]]; then
    echo "ERROR: ${DISK_FILE} not found." \
         "Run the installer via the desktop icon, not directly." >&2
    exit 1
fi

DISK=$(tr -d '[:space:]' < "${DISK_FILE}")

if [[ -z "${DISK}" ]]; then
    echo "ERROR: ${DISK_FILE} is empty — no target disk was selected." >&2
    exit 1
fi

if [[ ! -b "${DISK}" ]]; then
    echo "ERROR: ${DISK} is not a block device." >&2
    exit 1
fi

echo "=== Forge 43 Installation ==="
echo "Target disk : ${DISK}"
echo "Image       : ${TARGET_IMGREF}"
echo ""
echo "Pulling image and writing to disk — this will take a while..."
echo ""

bootc install to-disk \
    --target-imgref "${TARGET_IMGREF}" \
    "${DISK}"

echo ""
echo "=== Installation complete ==="
