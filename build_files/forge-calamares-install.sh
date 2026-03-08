#!/usr/bin/bash
# forge-calamares-install — Called by Calamares shellprocess module.
#
# The Calamares partition + mount modules have already partitioned the chosen
# disk and mounted it under /tmp/calamares-root.  This script:
#   1. Derives the disk device from those mounts (e.g. /dev/sda2 → /dev/sda)
#   2. Unmounts /tmp/calamares-root so bootc can take over the disk
#   3. Runs 'bootc install to-disk' to pull and write Forge

set -euo pipefail

TARGET_IMGREF="ghcr.io/mrtrick37/forge:latest"
CALAMARES_ROOT="/tmp/calamares-root"

# ── Find the target disk ──────────────────────────────────────────────────────
DISK=""

# Primary method: derive disk from what the mount module mounted to calamares-root
if findmnt -n -o SOURCE "${CALAMARES_ROOT}" &>/dev/null; then
    ROOT_PART=$(findmnt -n -o SOURCE "${CALAMARES_ROOT}" | head -1)
    # lsblk PKNAME gives the parent disk of a partition (e.g. sda1 → sda)
    PARENT=$(lsblk -no PKNAME "${ROOT_PART}" 2>/dev/null | head -1)
    [[ -n "${PARENT}" ]] && DISK="/dev/${PARENT}"
fi

# Fallback: /tmp/forge-target-disk written by the legacy kdialog launcher
if [[ -z "${DISK}" ]] && [[ -f /tmp/forge-target-disk ]]; then
    DISK=$(tr -d '[:space:]' < /tmp/forge-target-disk)
fi

if [[ -z "${DISK}" ]]; then
    echo "ERROR: Could not determine the target disk." >&2
    echo "       Nothing was mounted to ${CALAMARES_ROOT}." >&2
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

# ── Unmount calamares-root so bootc can repartition the disk ─────────────────
echo "Unmounting temporary partitions..."
umount -R -l "${CALAMARES_ROOT}" 2>/dev/null || true

# ── Install ───────────────────────────────────────────────────────────────────
echo "Pulling image and writing to disk — this will take a while..."
echo ""

bootc install to-disk \
    --target-imgref "${TARGET_IMGREF}" \
    "${DISK}"

echo ""
echo "=== Installation complete ==="
