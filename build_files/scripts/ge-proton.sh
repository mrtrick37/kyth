#!/bin/bash
set -euo pipefail

# ── GE-Proton ────────────────────────────────────────────────────────────────
# Installed system-wide so Steam picks it up for all users without manual setup.
# Steam looks in /usr/share/steam/compatibilitytools.d/ in addition to ~/.steam.
# This lives in its own image layer so bumping GE_PROTON_VER only re-downloads
# this layer (~700 MB), not the full 3+ GB package layer.
GE_PROTON_VER="GE-Proton10-33"
mkdir -p /usr/share/steam/compatibilitytools.d
curl -fsSL "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${GE_PROTON_VER}/${GE_PROTON_VER}.tar.gz" \
    | tar -xz -C /usr/share/steam/compatibilitytools.d/
