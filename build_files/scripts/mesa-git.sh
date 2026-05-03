#!/bin/bash
set -euo pipefail

# ── Mesa-git ───────────────────────────────────────────────────────────
# xxmitsu/mesa-git COPR rebuilds from upstream Mesa every few hours.
# DISABLED for AMD RDNA3 systems: bleeding-edge Mesa-git can have GPU initialization
# issues causing boot hangs / display flicker. AMD users should test with stable Mesa
# from Fedora repos. Re-enable if needed for specific use cases, but verify on target
# hardware first: https://github.com/mrtrick37/kyth/issues/new
#
# To re-enable this layer, uncomment the section below and rebuild the image.
# Note: If you have a working GPU configuration with mesa-git, please file an issue
# with your hardware details so we can add proper hardware-specific detection.

# COPR enable block (DISABLED):
# dnf5 copr enable -y xxmitsu/mesa-git
# if ! dnf5 repoquery --available 'mesa-libGL' --repo='copr:*xxmitsu*' 2>/dev/null | grep -q .; then
#     echo "WARNING: xxmitsu/mesa-git COPR has no mesa-libGL for this distro — skipping mesa-git upgrade"
#     dnf5 copr disable -y xxmitsu/mesa-git
# else
#     dnf5 upgrade -y --skip-unavailable \
#         mesa* \
#         mesa-dri-drivers \
#         mesa-vulkan-drivers \
#         mesa-libGL \
#         mesa-libGLU \
#         mesa-libEGL \
#         mesa-libgbm \
#         mesa-libOpenCL \
#         || true
#     mesa_ver=$(rpm -q --queryformat '%{VERSION}' mesa-libGL 2>/dev/null || echo "not-installed")
#     echo "mesa-libGL version after upgrade: ${mesa_ver}"
#     dnf5 copr disable -y xxmitsu/mesa-git
# fi

echo "Mesa-git COPR layer disabled (see mesa-git.sh comments for details)"

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
