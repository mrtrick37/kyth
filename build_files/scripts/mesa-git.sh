#!/bin/bash
set -euo pipefail

# ── Mesa-git ──────────────────────────────────────────────────────────────────
# xxmitsu/mesa-git COPR rebuilds from upstream Mesa every few hours.
# This lives in its own final image layer so daily mesa updates only require
# re-downloading this layer (~300-500 MB) instead of the full 3+ GB base layer.
dnf5 copr enable -y xxmitsu/mesa-git
dnf5 upgrade -y --skip-unavailable \
    mesa* \
    mesa-dri-drivers \
    mesa-vulkan-drivers \
    mesa-libGL \
    mesa-libGLU \
    mesa-libEGL \
    mesa-libgbm \
    mesa-libOpenCL \
    || true
dnf5 copr disable -y xxmitsu/mesa-git
dnf5 upgrade -y --skip-unavailable \
    xorg-x11-drv-amdgpu \
    xorg-x11-drv-nouveau \
    xorg-x11-drv-intel \
    xorg-x11-drv-vmware \
    xorg-x11-drv-qxl \
    xorg-x11-drv-nvidia \
    || true
dnf5 clean all
