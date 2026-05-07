#!/bin/bash
set -euo pipefail

# ── Mesa-git ───────────────────────────────────────────────────────────
# xxmitsu/mesa-git rebuilds Mesa from upstream snapshots every few hours.
# Fedora 44 folds the AMD VA-API backend into mesa-dri-drivers, so this layer
# verifies the radeonsi video driver by provider/file instead of looking for an
# independently installed mesa-va-drivers RPM.

if [[ "${ENABLE_MESA_GIT:-1}" == "0" ]]; then
    echo "Mesa-git COPR layer disabled by ENABLE_MESA_GIT=0"
else
    dnf5 copr enable -y xxmitsu/mesa-git
    trap 'dnf5 copr disable -y xxmitsu/mesa-git >/dev/null 2>&1 || true' EXIT

    if ! dnf5 repoquery --available 'mesa-dri-drivers' --repo='copr:*xxmitsu*' 2>/dev/null | grep -q .; then
        echo "ERROR: xxmitsu/mesa-git COPR has no mesa-dri-drivers for this distro"
        exit 1
    fi

    dnf5 upgrade -y --refresh --allowerasing \
        mesa\* \
        libdrm \
        libva\* \
        vulkan\*

    rpm -q mesa-dri-drivers mesa-vulkan-drivers mesa-libgbm libva libva-utils
    rpm -q --whatprovides mesa-va-drivers
    rpm -q --whatprovides /usr/lib64/dri/radeonsi_drv_video.so
    test -e /usr/lib64/dri/radeonsi_drv_video.so

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
