#!/usr/bin/env bash
# Build a KythOS live payload and delegate ISO assembly to Titanoboa, matching
# Bazzite's live ISO path.

set -euo pipefail

SOURCE_TAG="${SOURCE_TAG:-latest}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${KYTH_ISO_OUTPUT:-${REPO_ROOT}/output/live-iso}"
BASE_IMAGE="${INSTALLER_BASE_IMAGE:-ghcr.io/mrtrick37/kyth:${SOURCE_TAG}}"
LIVE_TAG="${KYTH_LIVE_TAG:-localhost/kyth-live:${SOURCE_TAG}}"
TITANOBOA_REF="7737f4748458252ac827dca14b3d6dd09298472a"
TITANOBOA_DIR="${TITANOBOA_DIR:-${XDG_CACHE_HOME:-${HOME}/.cache}/kyth/titanoboa}"

for cmd in git podman sudo; do
    command -v "${cmd}" >/dev/null || {
        echo "ERROR: missing required command: ${cmd}" >&2
        exit 1
    }
done

if [[ "${BASE_IMAGE}" == localhost/* ]] \
    && ! sudo podman image exists "${BASE_IMAGE}" \
    && command -v docker >/dev/null \
    && docker image inspect "${BASE_IMAGE}" >/dev/null 2>&1; then
    echo "==> Importing Docker image into rootful Podman: ${BASE_IMAGE}"
    docker save "${BASE_IMAGE}" | sudo podman load
fi

if [[ ! -d "${TITANOBOA_DIR}/.git" ]]; then
    echo "==> Initializing Titanoboa cache"
    mkdir -p "$(dirname "${TITANOBOA_DIR}")"
    git init "${TITANOBOA_DIR}"
    git -C "${TITANOBOA_DIR}" remote add origin https://github.com/Zeglius/titanoboa.git
fi

if ! git -C "${TITANOBOA_DIR}" cat-file -e "${TITANOBOA_REF}^{commit}" 2>/dev/null; then
    echo "==> Fetching Titanoboa ${TITANOBOA_REF}"
    git -C "${TITANOBOA_DIR}" fetch --depth 1 origin "${TITANOBOA_REF}"
fi
if [[ "$(git -C "${TITANOBOA_DIR}" rev-parse HEAD 2>/dev/null || true)" != "${TITANOBOA_REF}" ]]; then
    echo "==> Checking out Titanoboa ${TITANOBOA_REF}"
    git -C "${TITANOBOA_DIR}" checkout --detach "${TITANOBOA_REF}"
fi

echo "==> Building KythOS live payload from ${BASE_IMAGE}"
sudo podman build \
    --cap-add SYS_ADMIN \
    --security-opt label=disable \
    --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
    --build-arg "SOURCE_TAG=${SOURCE_TAG}" \
    --tag "${LIVE_TAG}" \
    -f installer/Containerfile \
    "${REPO_ROOT}"

mkdir -p "${OUTPUT_DIR}"
WORK="$(mktemp -d -p "${TMPDIR:-/var/tmp}" kyth-titanoboa.XXXXXXXXXX)"
trap 'rm -rf "${WORK}"' EXIT

echo "==> Assembling ISO with Titanoboa"
TITANOBOA_OUTPUT_DIR="${WORK}" "${TITANOBOA_DIR}/main.sh" "${LIVE_TAG}"
mv "${WORK}/KYTHOS-44-LIVE.iso" "${OUTPUT_DIR}/kyth-live-${SOURCE_TAG}.iso"
echo "==> KythOS live ISO ready: ${OUTPUT_DIR}/kyth-live-${SOURCE_TAG}.iso"
