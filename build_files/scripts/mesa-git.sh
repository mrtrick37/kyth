#!/bin/bash
set -euo pipefail

# ── Mesa-git ───────────────────────────────────────────────────────────
# xxmitsu/mesa-git rebuilds Mesa from upstream snapshots every few hours.
# Keep it opt-in: these snapshots are useful for testing bleeding-edge RADV and
# RADEONSI, but they can regress VA-API video decode while the rest of Mesa
# still appears healthy. Fedora 44 folds the AMD VA-API backend into
# mesa-dri-drivers, so this layer verifies the radeonsi video driver by
# provider/file instead of looking for an independently installed
# mesa-va-drivers RPM.

if [[ "${ENABLE_MESA_GIT:-0}" == "0" ]]; then
    echo "Mesa-git COPR layer disabled by ENABLE_MESA_GIT=0"
else
    dnf5 copr enable -y xxmitsu/mesa-git
    trap 'dnf5 copr disable -y xxmitsu/mesa-git >/dev/null 2>&1 || true' EXIT

    mesa_git_repo="copr:copr.fedorainfracloud.org:xxmitsu:mesa-git"

    if ! dnf5 repoquery --available 'mesa-dri-drivers' --repo="${mesa_git_repo}" 2>/dev/null | grep -q .; then
        echo "ERROR: xxmitsu/mesa-git COPR has no mesa-dri-drivers for this distro"
        exit 1
    fi

    # Some base images carry negativo17 Mesa packages with newer or equal EVRs
    # than Fedora, which can make a normal upgrade leave the intended mesa-git
    # layer unused. Sync the Mesa stack with negativo17 disabled so xxmitsu's
    # COPR wins when this layer is enabled.
    dnf5 distro-sync -y --refresh --allowerasing \
        --disablerepo='fedora-multimedia' \
        mesa\* \
        libdrm \
        libva\* \
        vulkan\*

    rpm -q mesa-dri-drivers mesa-vulkan-drivers mesa-libgbm libva libva-utils
    rpm -q --whatprovides mesa-va-drivers
    rpm -q --whatprovides /usr/lib64/dri/radeonsi_drv_video.so
    test -e /usr/lib64/dri/radeonsi_drv_video.so

    mesa_origin=$(rpm -q --queryformat '%{VENDOR} %{PACKAGER}\n' mesa-dri-drivers 2>/dev/null || true)
    if ! grep -Eiq 'xxmitsu|copr' <<<"${mesa_origin}"; then
        echo "ERROR: mesa-git layer did not install COPR Mesa; installed origin: ${mesa_origin:-unknown}"
        exit 1
    fi

    mesa_ver=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}' mesa-dri-drivers 2>/dev/null || echo "not-installed")
    echo "mesa-dri-drivers version after mesa-git upgrade: ${mesa_ver}"
fi

# Upgrade GPU drivers from stable Fedora repos (amdgpu, nouveau, intel, etc.)
dnf5 upgrade -y --skip-unavailable \
    xorg-x11-drv-amdgpu \
    xorg-x11-drv-nouveau \
    xorg-x11-drv-intel \
    xorg-x11-drv-vmware \
    xorg-x11-drv-qxl \
    xorg-x11-drv-nvidia \
    || true
dnf5 clean all
