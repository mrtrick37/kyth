
# Allow build scripts to be referenced without being copied into the final image
ARG BASE_IMAGE=localhost/kyth-base:stable
FROM scratch AS ctx
COPY build_files /

# Base Image
ARG BASE_IMAGE
FROM ${BASE_IMAGE}
# Override upstream OCI labels so downstream tooling (lorax/bootc) sees KythOS product metadata
LABEL org.opencontainers.image.title="KythOS"
LABEL org.opencontainers.image.version="44"
LABEL org.opencontainers.image.description="KythOS — atomic gaming and dev workstation built on Fedora Kinoite"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.source="https://github.com/mrtrick37/kyth"
LABEL org.opencontainers.image.documentation="https://github.com/mrtrick37/kyth"
LABEL org.osbuild.product="KythOS"
LABEL org.osbuild.version="44"
LABEL org.osbuild.branding.release="KythOS 44"

### MODIFICATIONS
ARG ENABLE_ANANICY=1
ARG ENABLE_SCX=1

# Layer 1: All RPM package installs (~2-3 GB).
# Stable — only re-run when packages.sh changes or the base image is updated.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    ENABLE_ANANICY=${ENABLE_ANANICY} \
    /ctx/scripts/packages.sh

# Layer 2: GE-Proton (~700 MB).
# Placed before the daily upgrade layer so its cache is only busted when
# ge-proton.sh changes or a new release is detected — not on every daily dnf
# upgrade run.  GE-Proton is a fully self-contained wine bundle with no
# system library dependencies, so ordering before the upgrade is safe.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=github_token \
    /ctx/scripts/ge-proton.sh

# BUILD_DATE busts the cache for Layer 3 and all subsequent layers on every
# daily build, ensuring dnf5 upgrade always runs even when the base image
# digest and build_files/ contents haven't changed.
# Pass as: --build-arg BUILD_DATE="$(date +%Y-%m-%d)"
ARG BUILD_DATE=unset

# Layer 3: Upstream RPM upgrades (~50-500 MB daily delta).
# Isolated so daily package updates don't invalidate the package install layer
# above.  Layers after this one are re-run on every daily build; layers before
# it are cached until their scripts or the base image change.
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/tmp \
    : "cache-bust=${BUILD_DATE}" && \
    set -euo pipefail; \
    _drv_ver=$(rpm -q --qf '%{version}' xorg-x11-drv-nvidia 2>/dev/null || true); \
    _common_ver=$(dnf5 repoquery --available --qf '%{version}' nvidia-kmod-common 2>/dev/null | sort -V | tail -1 || true); \
    if [ -n "${_drv_ver}" ] && [ -n "${_common_ver}" ] && [ "${_drv_ver}" = "${_common_ver}" ]; then \
        echo "NVIDIA packages consistent (${_drv_ver}); upgrading freely."; \
        dnf5 upgrade -y --refresh --exclude='kernel*' --exclude='gamescope*' \
            --exclude='gstreamer1-plugins-bad' \
            --exclude='gstreamer1-plugins-bad.i686'; \
    else \
        echo "NVIDIA version mismatch (installed xorg-x11-drv-nvidia=${_drv_ver}, available nvidia-kmod-common=${_common_ver}); holding NVIDIA packages."; \
        dnf5 upgrade -y --refresh --exclude='kernel*' --exclude='gamescope*' \
            --exclude='gstreamer1-plugins-bad' \
            --exclude='gstreamer1-plugins-bad.i686' \
            --exclude='nvidia-kmod-common' \
            --exclude='akmod-nvidia*' \
            --exclude='xorg-x11-drv-nvidia*'; \
    fi && \
    dnf5 upgrade -y libdrm && \
    dnf5 clean all

# Layer 4: Third-party binaries — topgrade, winetricks, SCX schedulers, Homebrew (~400 MB).
# Re-run on every daily build (sits after the upgrade layer). GitHub API calls
# use the mounted token to avoid unauthenticated rate limits.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=github_token \
    ENABLE_SCX=${ENABLE_SCX} /ctx/scripts/thirdparty.sh

# Layer 5: System configuration — sysctl, audio, gaming tuning, env vars (~few KB).
# Re-run on every daily build.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/scripts/sysconfig.sh

# Layer 6: Branding, theming, helper app, Plymouth (~10 MB).
# Re-run on every daily build.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/scripts/branding.sh

# Layer 7: Mesa-git (~300-500 MB). Re-run on every daily build.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/scripts/mesa-git.sh
