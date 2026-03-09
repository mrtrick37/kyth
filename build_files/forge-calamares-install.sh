#!/usr/bin/bash
# forge-calamares-install — Called by Calamares shellprocess module.
#
# Arguments (passed via shellprocess @@@@ substitution from globalStorage):
#   $1 — bootLoaderInstallPath (e.g. /dev/sda1 for EFI, /dev/sda for BIOS)
#   $2 — timezone              (e.g. "America/New_York"; empty if locale skipped)
#
# Steps:
#   1. Derive the whole disk from $1 (strip partition number)
#   2. Run 'bootc install to-disk' to pull and write Forge
#   3. Mount the installed root and apply the selected timezone

set -euo pipefail

TARGET_IMGREF="ghcr.io/mrtrick37/forge:latest"

# ── Arguments ─────────────────────────────────────────────────────────────────
BOOT_DEVICE="${1:-}"
TIMEZONE="${2:-}"

# Guard against literal Calamares placeholder (module skipped / substitution failed)
[[ "${BOOT_DEVICE}" == *"@@"* ]] && BOOT_DEVICE=""
[[ "${TIMEZONE}"    == *"@@"* ]] && TIMEZONE=""

# ── Derive whole-disk device from the EFI/boot partition path ─────────────────
# partition module sets bootLoaderInstallPath to the ESP (/dev/sda1, /dev/nvme0n1p1)
# or the disk itself (/dev/sda) for BIOS.  lsblk PKNAME gives the parent disk;
# if PKNAME is empty the device is already a whole disk.
DISK=""
if [[ -b "${BOOT_DEVICE}" ]]; then
    PARENT=$(lsblk -no PKNAME "${BOOT_DEVICE}" 2>/dev/null | head -1)
    if [[ -n "${PARENT}" ]]; then
        DISK="/dev/${PARENT}"
    else
        DISK="${BOOT_DEVICE}"
    fi
fi

# Fallback: legacy file written by older launcher variants
if [[ -z "${DISK}" ]] && [[ -f /tmp/forge-target-disk ]]; then
    DISK=$(tr -d '[:space:]' < /tmp/forge-target-disk)
fi

if [[ -z "${DISK}" ]]; then
    echo "ERROR: Could not determine the target disk." >&2
    echo "       bootLoaderInstallPath was: '${BOOT_DEVICE}'" >&2
    exit 1
fi

if [[ ! -b "${DISK}" ]]; then
    echo "ERROR: ${DISK} is not a block device." >&2
    exit 1
fi

echo "=== Forge 43 Installation ==="
echo "Target disk  : ${DISK}"
echo "Boot device  : ${BOOT_DEVICE}"
echo "Image        : ${TARGET_IMGREF}"
[[ -n "${TIMEZONE}" ]] && echo "Timezone     : ${TIMEZONE}"
echo ""

# ── Install ───────────────────────────────────────────────────────────────────
echo "Pulling image and writing to disk — this will take a while..."
echo ""

bootc install to-disk \
    --target-imgref "${TARGET_IMGREF}" \
    "${DISK}"

echo ""
echo "=== Installation complete ==="

# ── Apply timezone to the installed ostree deployment ─────────────────────────
# bootc creates: EFI | /boot | root (xfs — the largest).
# Mount the root (last xfs partition on the disk) and write /etc/localtime
# into the ostree deployment's /etc directory.
if [[ -n "${TIMEZONE}" ]]; then
    echo "Applying timezone: ${TIMEZONE}"

    if [[ ! -f "/usr/share/zoneinfo/${TIMEZONE}" ]]; then
        echo "WARNING: Unknown timezone '${TIMEZONE}' — skipping." >&2
    else
        ROOT_PART=$(lsblk -no NAME,FSTYPE "${DISK}" | \
            awk '$2=="xfs" {last=$1} END { if (last) print "/dev/"last }')

        if [[ -n "${ROOT_PART}" ]] && [[ -b "${ROOT_PART}" ]]; then
            SYSROOT=/tmp/forge-installed-sysroot
            mkdir -p "${SYSROOT}"
            mount "${ROOT_PART}" "${SYSROOT}"

            DEPLOY_ETC=$(find "${SYSROOT}/ostree/deploy"/*/deploy/*/etc \
                -maxdepth 0 -type d 2>/dev/null | head -1)

            if [[ -n "${DEPLOY_ETC}" ]]; then
                ln -sf "/usr/share/zoneinfo/${TIMEZONE}" "${DEPLOY_ETC}/localtime"
                echo "Timezone written to ${DEPLOY_ETC}/localtime"
            else
                echo "WARNING: Could not locate ostree deployment etc — timezone not applied." >&2
            fi

            umount "${SYSROOT}"
        else
            echo "WARNING: Could not find root xfs partition on ${DISK} — timezone not applied." >&2
        fi
    fi
fi
