# Pull the upstream Fedora bootc base and apply KythOS branding.
# Build with: docker build -t localhost/kyth-base:stable build_base/
# Override the base via: docker build --build-arg BASE_IMAGE=ghcr.io/ublue-os/kinoite-main:44 build_base/
ARG BASE_IMAGE=ghcr.io/ublue-os/kinoite-main:44
FROM ${BASE_IMAGE}

# Passed at build time so the layer cache is busted whenever a new CachyOS
# kernel version is published. Build scripts resolve the latest version from
# the COPR API and pass it here; the value itself is unused inside build.sh —
# it only controls whether Docker re-runs the RUN layer.
ARG CACHYOS_KERNEL_VER=unset

# Use a bind-mount so the script is never written into any image layer
RUN --mount=type=bind,source=build.sh,target=/run/build.sh \
    bash /run/build.sh
