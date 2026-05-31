
ARG BASE_IMAGE=localhost/kyth-base:stable

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
ARG ENABLE_MESA_GIT=0

# Layer 1: All RPM package installs (~2-3 GB).
# Stable — only re-run when packages.sh changes or the base image is updated.
RUN --mount=type=bind,source=build_files/scripts/packages.sh,target=/ctx/packages.sh \
    --mount=type=cache,id=s/4a742739-a2e5-48f0-bb03-5d313848ff8e-/var/cache,target=/var/cache \
    --mount=type=cache,id=s/4a742739-a2e5-48f0-bb03-5d313848ff8e-/var/log,target=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    ENABLE_ANANICY=${ENABLE_ANANICY} \
    bash /ctx/packages.sh

# Layer 2: GE-Proton (~700 MB).
# Placed before the daily upgrade layer so its cache is only busted when
# ge-proton.sh changes or GE_PROTON_VER changes — not on every daily dnf
# upgrade run.  GE-Proton is a fully self-contained wine bundle with no system
# library dependencies, so ordering before the upgrade is safe.
ARG GE_PROTON_VER=
RUN --mount=type=bind,source=build_files/scripts/ge-proton.sh,target=/ctx/ge-proton.sh \
    --mount=type=cache,id=s/4a742739-a2e5-48f0-bb03-5d313848ff8e-/var/cache,target=/var/cache \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=github_token \
    GE_PROTON_VER=${GE_PROTON_VER} bash /ctx/ge-proton.sh

# BUILD_DATE busts the cache for Layer 3 and all subsequent layers on every
# daily build, ensuring dnf5 upgrade always runs even when the base image
# digest and build_files/ contents haven't changed.
# Pass as: --build-arg BUILD_DATE="$(date +%Y-%m-%d)"
ARG BUILD_DATE=unset

# Layer 3: Upstream RPM upgrades (~50-500 MB daily delta).
# Isolated so daily package updates don't invalidate the package install layer
# above.  Layers after this one are re-run on every daily build; layers before
# it are cached until their scripts or the base image change.
RUN --mount=type=cache,id=s/4a742739-a2e5-48f0-bb03-5d313848ff8e-/var/cache,target=/var/cache \
    --mount=type=tmpfs,dst=/tmp \
    : "cache-bust=${BUILD_DATE}" && \
    set -euo pipefail; \
    dnf5 upgrade -y --refresh --exclude='akmod-*' --exclude='kmod-*' \
        --exclude='gamescope*' \
        --disablerepo='fedora-multimedia' \
        --exclude='gstreamer1-plugins-bad' \
        --exclude='gstreamer1-plugins-bad.i686' && \
    dnf5 upgrade -y --disablerepo='fedora-multimedia' libdrm && \
    : "── Ensure active kernel has vmlinuz + initramfs for bootc ─────────────────" && \
    KVER="$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V | tail -n 1)" && \
    test -n "${KVER}" \
        || { echo "ERROR: no kernel found in /usr/lib/modules after upgrade; contents: $(ls /usr/lib/modules/ 2>&1)" >&2; exit 1; } && \
    echo "==> kernel: ${KVER}" && \
    if [ ! -s "/usr/lib/modules/${KVER}/vmlinuz" ]; then \
        _src=$(find /boot -name "vmlinuz-${KVER}" 2>/dev/null | head -1); \
        if [ -n "${_src}" ] && [ -s "${_src}" ]; then \
            echo "  Found vmlinuz at ${_src}, copying..."; \
            cp --no-preserve=all "${_src}" "/usr/lib/modules/${KVER}/vmlinuz"; \
        else \
            echo "  vmlinuz not found in /boot, checking /usr/lib/kernel..."; \
            _src=$(find /usr/lib/kernel -name "vmlinuz*" 2>/dev/null | head -1); \
            if [ -n "${_src}" ] && [ -s "${_src}" ]; then \
                echo "  Found vmlinuz at ${_src}, copying..."; \
                cp --no-preserve=all "${_src}" "/usr/lib/modules/${KVER}/vmlinuz"; \
            fi; \
        fi; \
    fi && \
    { depmod -a "${KVER}" 2>/dev/null || true; } && \
    if [ ! -s "/usr/lib/modules/${KVER}/initramfs" ]; then \
        if [ -s "/boot/initramfs-${KVER}.img" ]; then \
            cp --no-preserve=all "/boot/initramfs-${KVER}.img" "/usr/lib/modules/${KVER}/initramfs"; \
        else \
            TMPDIR=/var/tmp dracut \
                --no-hostonly \
                --compress "zstd -1" \
                --kver "${KVER}" \
                --force \
                "/usr/lib/modules/${KVER}/initramfs" \
                2> >(grep -Ev 'xattr|fail to copy' >&2); \
        fi; \
    fi && \
    if [ ! -s "/usr/lib/modules/${KVER}/vmlinuz" ]; then \
        echo "ERROR: vmlinuz missing/empty for ${KVER}"; \
        echo "  Available files in /boot:"; \
        ls -la /boot/vmlinuz* 2>/dev/null || echo "    (none)"; \
        echo "  Contents of /usr/lib/modules/${KVER}:"; \
        ls -la "/usr/lib/modules/${KVER}/" 2>&1 | head -20; \
        exit 1; \
    fi && \
    test -s "/usr/lib/modules/${KVER}/initramfs" \
        || { echo "ERROR: initramfs missing/empty for ${KVER}" >&2; exit 1; } && \
    echo "==> kernel OK: vmlinuz $(du -h "/usr/lib/modules/${KVER}/vmlinuz" | cut -f1), initramfs $(du -h "/usr/lib/modules/${KVER}/initramfs" | cut -f1)" && \
    dnf5 clean all

# Layer 4: Optional Mesa-git GPU drivers.
# Disabled by default: the COPR tracks development snapshots and can regress
# VA-API video decode even when Vulkan/OpenGL remain healthy. Set
# ENABLE_MESA_GIT=1 for testing bleeding-edge RADV/RADEONSI.
RUN --mount=type=bind,source=build_files/scripts/mesa-git.sh,target=/ctx/mesa-git.sh \
    --mount=type=cache,id=s/4a742739-a2e5-48f0-bb03-5d313848ff8e-/var/cache,target=/var/cache \
    --mount=type=tmpfs,dst=/tmp \
    ENABLE_MESA_GIT=${ENABLE_MESA_GIT} \
    bash /ctx/mesa-git.sh

# Layer 5: Third-party binaries — topgrade, winetricks, SCX schedulers (~100 MB).
# Re-run on every daily build (sits after the upgrade layer). GitHub API calls
# use the mounted token to avoid unauthenticated rate limits.
RUN --mount=type=bind,source=build_files/scripts/thirdparty.sh,target=/ctx/thirdparty.sh \
    --mount=type=cache,id=s/4a742739-a2e5-48f0-bb03-5d313848ff8e-/var/cache,target=/var/cache \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=github_token \
    ENABLE_SCX=${ENABLE_SCX} bash /ctx/thirdparty.sh

# Layer 6: System configuration — sysctl, audio, gaming tuning, env vars (~few KB).
# Re-run on every daily build.
RUN --mount=type=bind,source=build_files/scripts/sysconfig.sh,target=/ctx/sysconfig.sh \
    --mount=type=bind,source=build_files/kyth-vscode-wallet,target=/ctx/kyth-vscode-wallet \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/sysconfig.sh

# Layer 7: Secure Boot — sign the CachyOS vmlinuz and install the enrollment service.
# Skipped gracefully when MOK_KEY is not set (local builds without a signing key).
# Pass the private key via: --secret id=mok_key,env=MOK_KEY
ARG SECUREBOOT_SIGNING_REQUESTED=0
RUN --mount=type=bind,source=build_files/scripts/secureboot.sh,target=/ctx/secureboot.sh \
    --mount=type=bind,source=build_files/secureboot,target=/ctx/secureboot \
    --mount=type=bind,source=build_files/kyth-enroll-mok,target=/ctx/kyth-enroll-mok \
    --mount=type=bind,source=build_files/kyth-enroll-mok.service,target=/ctx/kyth-enroll-mok.service \
    --mount=type=cache,id=s/4a742739-a2e5-48f0-bb03-5d313848ff8e-/var/cache,target=/var/cache \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=mok_key \
    SECUREBOOT_SIGNING_REQUESTED=${SECUREBOOT_SIGNING_REQUESTED} bash /ctx/secureboot.sh

# Layer 8: Branding, theming, helper app, Plymouth (~10 MB).
# Re-run on every daily build.
RUN --mount=type=bind,source=build_files,target=/ctx \
    --mount=type=cache,id=s/4a742739-a2e5-48f0-bb03-5d313848ff8e-/var/cache,target=/var/cache \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/scripts/branding.sh
