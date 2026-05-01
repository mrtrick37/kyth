# Pull the upstream Fedora bootc base and apply KythOS branding.
# Build with: docker build -t localhost/kyth-base:stable build_base/
# Override the base via: docker build --build-arg BASE_IMAGE=ghcr.io/ublue-os/kinoite-main:44 build_base/
ARG BASE_IMAGE=ghcr.io/ublue-os/kinoite-main:44
FROM ${BASE_IMAGE}

# Passed at build time so the layer cache is busted whenever a new CachyOS
# kernel version is published. Build scripts resolve the latest version from
# the COPR API and pass it here. Explicitly referenced via the no-op ':'
# builtin so Docker (both classic and BuildKit) includes it in the cache key.
ARG CACHYOS_KERNEL_VER=unset

# Use a bind-mount so the script is never written into any image layer
RUN --mount=type=bind,source=build.sh,target=/run/build.sh \
    --mount=type=bind,source=plymouth,target=/run/plymouth \
    : "cache-bust=${CACHYOS_KERNEL_VER}" \
    && bash /run/build.sh
