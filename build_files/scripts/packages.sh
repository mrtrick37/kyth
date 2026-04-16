#!/bin/bash

set -euo pipefail

# ── Locale filtering ──────────────────────────────────────────────────────────
# Strip non-English locale data from every subsequent RPM install.
# Saves 100–300 MB across the full package set with no functional loss
# on an English workstation.
echo '%_install_langs en_US' >> /etc/rpm/macros

# ── DNF parallelism ───────────────────────────────────────────────────────────
# Raise parallel download slots from the default 3 to 10 — same value used by
# UBlue, Bazzite, and recommended in Fedora documentation.
echo 'max_parallel_downloads=10' >> /etc/dnf/dnf.conf

### Install Docker for container operations
# container-selinux provides the SELinux policy module for container runtimes
# (docker_t, container_t, etc.) — required for Docker to work under enforcing.
dnf5 install -y docker container-selinux

# Add rpmfusion free and nonfree repositories for Fedora 44.
# The release RPMs ship and install the GPG key themselves — this is the
# standard RPM Fusion bootstrap pattern; there is no separately hosted key
# URL to pre-import (unlike Brave/Negativo17).
dnf5 install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm \
    || true

# Fedora 44 transitions can leave debug/source repo metalinks unpublished or
# intermittently unavailable. We never install from those repos in image builds,
# so disable them up front to avoid noisy 404s and brittle solver behavior.
python3 - <<'PY'
from pathlib import Path
import configparser

repo_dir = Path("/etc/yum.repos.d")
patterns = ("debug", "source")

for repo_file in repo_dir.glob("*.repo"):
    parser = configparser.RawConfigParser(strict=False)
    parser.optionxform = str
    try:
        with repo_file.open("r", encoding="utf-8") as fh:
            parser.read_file(fh)
    except Exception:
        continue

    changed = False
    for section in parser.sections():
        if any(token in section.lower() for token in patterns):
            if parser.get(section, "enabled", fallback="1").strip() != "0":
                parser.set(section, "enabled", "0")
                changed = True

    if changed:
        with repo_file.open("w", encoding="utf-8") as fh:
            parser.write(fh, space_around_delimiters=False)
PY

# ── Multimedia baseline ───────────────────────────────────────────────────────
# Install a full system codec stack so common local playback, browser media,
# and creator workflows work without extra setup.  RPM Fusion provides the
# patent-encumbered pieces Fedora does not ship by default.
# gstreamer1-plugins-bad-freeworld conflicts with Fedora's
# gstreamer1-plugins-bad; ensure we prefer the RPM Fusion variant.
dnf5 remove -y gstreamer1-plugins-bad || true
dnf5 install -y --allowerasing --skip-unavailable --exclude=gstreamer1-plugins-bad \
    ffmpeg \
    ffmpegthumbnailer \
    gstreamer1-plugin-openh264 \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugins-ugly \
    gstreamer1-libav \
    mozilla-openh264 \
    mpv

# Install baseline tooling in a single transaction to reduce solver and
# metadata overhead before the gaming repos are enabled.
dnf5 install -y --skip-unavailable \
    sddm \
    sddm-breeze \
    irqbalance \
    p7zip \
    p7zip-plugins \
    ntfs-3g \
    ntfsprogs \
    cifs-utils \
    rsync \
    openconnect \
    NetworkManager-openconnect \
    NetworkManager-openconnect-gnome \
    qemu-char-spice \
    qemu-device-display-virtio-gpu \
    qemu-device-display-virtio-vga \
    qemu-device-usb-redirect \
    qemu-img \
    qemu-system-x86-core \
    util-linux-script \
    tmux \
    gh \
    fwupd \
    libburn \
    libisoburn \
    libisofs \
    xorriso

# Enable COPRs for gaming packages
dnf5 copr enable -y ublue-os/bazzite
dnf5 copr enable -y ublue-os/bazzite-multilib
dnf5 copr enable -y ublue-os/staging
dnf5 copr enable -y ublue-os/packages
dnf5 copr enable -y ublue-os/obs-vkcapture
dnf5 copr enable -y ycollet/audinux

# Gaming packages
# libde265.i686 is excluded: it's an HEVC decoder pulled in transitively by
# some gaming libs, but it's frequently unavailable on Fedora mirrors and is not needed.
# steam and lutris are intentionally absent — both are installed as Flatpaks via
# the kyth-welcome Gaming page so users can opt in without bloating the base image.
# umu-launcher is intentionally absent here — not in bazzite COPR for Fedora 44;
# installed from GitHub releases in thirdparty.sh instead.
dnf5 install -y --skip-unavailable --exclude=libde265.i686 \
    gamescope \
    gamescope-shaders \
    mangohud.x86_64 \
    mangohud.i686 \
    vkBasalt.x86_64 \
    vkBasalt.i686 \
    libFAudio.x86_64 \
    libFAudio.i686 \
    libobs_vkcapture.x86_64 \
    libobs_glcapture.x86_64 \
    libobs_vkcapture.i686 \
    libobs_glcapture.i686 \
    xrandr \
    evtest \
    xdg-user-dirs \
    xdg-terminal-exec \
    gamemode \
    gamemode.i686 \
    libXScrnSaver \
    libXScrnSaver.i686 \
    libxcb.i686 \
    libatomic \
    libatomic.i686 \
    mesa-libGL.i686 \
    mesa-dri-drivers.i686 \
    nss \
    nss.i686 \
    steam-devices \
    kdeplasma-addons \
    rom-properties-kf6 \
    input-remapper

is_enabled() {
    case "${1,,}" in
        1|true|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

# ── system76-scheduler ────────────────────────────────────────────────────────
# Dynamically adjusts CFS nice values and I/O priority based on which window
# is focused and whether a game is running.  Gives a noticeable responsiveness
# boost during gaming without requiring per-app configuration.
if dnf5 repoquery --available system76-scheduler 2>/dev/null | grep -q .; then
  dnf5 install -y --skip-unavailable system76-scheduler || true
  if rpm -q system76-scheduler >/dev/null 2>&1; then
    systemctl enable com.system76.Scheduler 2>/dev/null || true
  fi
else
  echo "system76-scheduler is unavailable in configured repos; skipping."
fi

# ── ananicy-cpp process priority rules ───────────────────────────────────────
# Applies static per-process CPU/I/O priorities (browser, game launchers,
# compilers, etc.) to smooth desktop responsiveness under mixed load.
if is_enabled "${ENABLE_ANANICY:-1}"; then
    if dnf5 repoquery --available ananicy-cpp 2>/dev/null | grep -q .; then
        dnf5 install -y --skip-unavailable \
                ananicy-cpp \
                ananicy-cpp-rules \
                ananicy-cpp-rules-git || true
        if rpm -q ananicy-cpp >/dev/null 2>&1; then
            systemctl enable ananicy-cpp.service 2>/dev/null || true
        fi
    else
        echo "ananicy-cpp is unavailable in configured repos; skipping."
    fi
else
    echo "ENABLE_ANANICY is off; skipping ananicy-cpp install."
fi

# Disable COPRs so they don't persist in the final image
dnf5 copr disable -y ublue-os/bazzite
dnf5 copr disable -y ublue-os/bazzite-multilib
dnf5 copr disable -y ublue-os/staging
dnf5 copr disable -y ublue-os/packages
dnf5 copr disable -y ublue-os/obs-vkcapture
dnf5 copr disable -y ycollet/audinux

### GPU drivers


# ── AMD ───────────────────────────────────────────────────────────────────────
# amdgpu is in the CachyOS kernel; RADV (Vulkan) comes from mesa (Fedora repos).
# linux-firmware provides the GPU firmware blobs that amdgpu loads at runtime —
# without them the driver falls back to basic/non-accelerated mode.
# libva-mesa-driver/mesa-vdpau-drivers provide AMD decode backends.
# intel-media-driver/libva-intel-driver cover newer + older Intel iGPUs.
# nvidia-vaapi-driver enables VA-API translation on supported NVIDIA systems.
dnf5 install -y --skip-unavailable \
    linux-firmware \
    libva-utils \
    mesa-va-drivers \
    mesa-vdpau-drivers \
    intel-media-driver \
    libva-intel-driver \
    xorg-x11-drv-intel \
    radeontop \
    libclc

# Remove plasma-welcome — plasma-login handles first-boot setup instead.
dnf5 remove -y --no-autoremove plasma-welcome plasma-welcome-fedora 2>/dev/null || true

# Remove Firefox — Brave Browser is installed as a Flatpak on first boot
# via kyth-default-flatpaks.service (avoids baking external repo keys into
# the build and eliminates DNS-dependent rpm --import calls in CI).
dnf5 remove -y firefox || true

# Visual Studio Code (repo added but disabled by default)
tee /etc/yum.repos.d/vscode.repo <<'REPOEOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
REPOEOF
sed -i "s/enabled=.*/enabled=0/g" /etc/yum.repos.d/vscode.repo
dnf5 -y install --enablerepo=code code

# Install Claude Code VS Code extension into /etc/skel so every new user gets
# it pre-populated in ~/.vscode/extensions/ — the location VS Code checks by
# default. Downloading the VSIX directly avoids running Electron headlessly in
# the container build, which fails without a display even with --no-sandbox.
# flags=531: IncludeVersions(0x1) | IncludeFiles(0x2) | IncludeVersionProperties(0x10) | IncludeLatestVersionOnly(0x200)
# IncludeFiles is needed to get the per-asset SHA256 hash URL for integrity verification.
# The version and hash URL are always fetched live from the marketplace API, so there
# is nothing to pin or manually update — they reflect the current latest on every build.
CLAUDE_CODE_API_JSON=$(curl -fsSL -X POST \
    "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json;api-version=3.0-preview.1" \
    -d '{"filters":[{"criteria":[{"filterType":7,"value":"anthropic.claude-code"}]}],"flags":531}')

CLAUDE_CODE_VER=$(echo "${CLAUDE_CODE_API_JSON}" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d['results'][0]['extensions'][0]['versions'][0]['version'])")
if [[ -z "${CLAUDE_CODE_VER}" || ! "${CLAUDE_CODE_VER}" =~ ^[0-9]+(\.[0-9]+){1,3}([-.][0-9A-Za-z]+)?$ ]]; then
    echo "ERROR: Could not resolve a valid Claude Code extension version. Got: '${CLAUDE_CODE_VER}'" >&2
    exit 1
fi

# Extract the SHA256 hash URL for the VSIX from the marketplace API response.
# The marketplace publishes a per-version hash under the
# Microsoft.VisualStudio.Services.VSIXPackage.Sha256Hash assetType.
CLAUDE_CODE_SHA256_URL=$(echo "${CLAUDE_CODE_API_JSON}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
files = d['results'][0]['extensions'][0]['versions'][0].get('files', [])
for f in files:
    if f.get('assetType') == 'Microsoft.VisualStudio.Services.VSIXPackage.Sha256Hash':
        print(f.get('source', ''))
        break
" 2>/dev/null || echo "")

echo "Installing Claude Code extension ${CLAUDE_CODE_VER}"
curl -fL --retry 5 --retry-delay 2 --retry-all-errors \
    -H "User-Agent: kyth-image-build/1.0" \
    -H "Accept: application/octet-stream" \
    "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/anthropic/vsextensions/claude-code/${CLAUDE_CODE_VER}/vspackage" \
    -o /tmp/claude-code.vsix

# Verify the downloaded VSIX against the marketplace-published SHA256.
# Hard failure on mismatch; warning-only if the API did not return a hash URL
# (which would indicate an API change, not an attack).
if [[ -n "${CLAUDE_CODE_SHA256_URL}" ]]; then
    EXPECTED_SHA256=$(curl -fsSL "${CLAUDE_CODE_SHA256_URL}" | tr -dc '0-9a-fA-F' | head -c 64 || echo "")
    ACTUAL_SHA256=$(sha256sum /tmp/claude-code.vsix | awk '{print $1}')
    if [[ -z "${EXPECTED_SHA256}" || ${#EXPECTED_SHA256} -ne 64 ]]; then
        echo "WARNING: Could not retrieve SHA256 from marketplace; skipping content verification" >&2
    elif [[ "${ACTUAL_SHA256}" != "${EXPECTED_SHA256,,}" ]]; then
        echo "ERROR: Claude Code VSIX SHA256 mismatch for ${CLAUDE_CODE_VER}!" >&2
        echo "  Expected: ${EXPECTED_SHA256}" >&2
        echo "  Got:      ${ACTUAL_SHA256}" >&2
        exit 1
    else
        echo "Claude Code VSIX SHA256 verified (${ACTUAL_SHA256:0:16}...)"
    fi
else
    echo "WARNING: No SHA256 hash URL in marketplace API response; skipping content verification" >&2
fi
python3 - <<'PY'
import zipfile
import pathlib
import gzip
import sys

vsix = pathlib.Path('/tmp/claude-code.vsix')
if not vsix.exists() or vsix.stat().st_size == 0:
    print("ERROR: Claude Code VSIX download is missing or empty.", file=sys.stderr)
    sys.exit(1)

vsix_bytes = vsix.read_bytes()

# Some CDN paths return the VSIX payload gzip-wrapped.
if not zipfile.is_zipfile(vsix):
    if vsix_bytes.startswith(b"\x1f\x8b"):
        try:
            decompressed = gzip.decompress(vsix_bytes)
        except Exception as exc:
            print(f"ERROR: Failed to gunzip Claude Code artifact: {exc}", file=sys.stderr)
            sys.exit(1)
        if decompressed.startswith(b"PK\x03\x04"):
            vsix.write_bytes(decompressed)
        else:
            sample = decompressed[:240].decode("utf-8", errors="replace").replace("\n", " ")
            print("ERROR: Gzip payload is not a ZIP/VSIX.", file=sys.stderr)
            print(f"First bytes after gunzip: {sample}", file=sys.stderr)
            sys.exit(1)
    else:
        sample = vsix_bytes[:240].decode("utf-8", errors="replace").replace("\n", " ")
        print("ERROR: Downloaded Claude Code artifact is not a ZIP/VSIX.", file=sys.stderr)
        print(f"First bytes: {sample}", file=sys.stderr)
        sys.exit(1)

if not zipfile.is_zipfile(vsix):
    print("ERROR: Claude Code artifact still is not a valid ZIP after normalization.", file=sys.stderr)
    sys.exit(1)
PY
mkdir -p /etc/skel/.vscode/extensions
python3 -c "
import zipfile
with zipfile.ZipFile('/tmp/claude-code.vsix', 'r') as z:
    for member in z.namelist():
        if member.startswith('extension/'):
            z.extract(member, '/tmp/claude-code-ext/')
"
mv /tmp/claude-code-ext/extension \
    "/etc/skel/.vscode/extensions/anthropic.claude-code-${CLAUDE_CODE_VER}"
rm -rf /tmp/claude-code.vsix /tmp/claude-code-ext

# ── NVIDIA driver ─────────────────────────────────────────────────────────────
# The NVIDIA kernel module must be baked into /usr/lib/modules/ at image build
# time — bootc/ostree roots are read-only at runtime so modules cannot be
# compiled or installed post-boot.  kernel-cachyos-devel is installed in
# build_base while the CachyOS COPR is active, so the headers are present here.
# On AMD/Intel systems these packages are inert: the nvidia module exists in the
# image but udev never loads it without NVIDIA hardware present.
# If another repo pulled in a different NVIDIA family (for example negativo17),
# remove its shared-common package to avoid file conflicts with RPM Fusion.
dnf5 remove -y nvidia-kmod-common || true
# Keep this install constrained to Fedora + RPM Fusion repos so solver doesn't
# mix incompatible NVIDIA package streams from third-party repos.
# Install NVIDIA packages.  RPM Fusion sometimes ships nvidia-kmod-common at a
# newer driver version than xorg-x11-drv-nvidia during a release wave; both
# packages own /usr/bin/nvidia-bug-report.sh in different driver series, causing
# a file conflict in the same transaction.  Check available versions first and
# exclude nvidia-kmod-common when they would mismatch.
_xorg_ver=$(dnf5 repoquery --available \
    --disablerepo='*' --enablerepo='fedora*' --enablerepo='updates*' --enablerepo='rpmfusion*' \
    --qf '%{version}' xorg-x11-drv-nvidia 2>/dev/null | sort -V | tail -1 || true)
_common_ver=$(dnf5 repoquery --available \
    --disablerepo='*' --enablerepo='fedora*' --enablerepo='updates*' --enablerepo='rpmfusion*' \
    --qf '%{version}' nvidia-kmod-common 2>/dev/null | sort -V | tail -1 || true)
if [ -n "${_xorg_ver}" ] && [ -n "${_common_ver}" ] && [ "${_xorg_ver}" != "${_common_ver}" ]; then
    echo "NVIDIA version mismatch (xorg-x11-drv-nvidia=${_xorg_ver}, nvidia-kmod-common=${_common_ver}); excluding nvidia-kmod-common from install."
    _nvidia_excludes="--exclude=nvidia-kmod-common"
else
    echo "NVIDIA packages consistent (${_xorg_ver}); installing without exclusions."
    _nvidia_excludes=""
fi
# shellcheck disable=SC2086
dnf5 install -y --skip-unavailable --allowerasing \
    --disablerepo='*' \
    --enablerepo='fedora*' \
    --enablerepo='updates*' \
    --enablerepo='rpmfusion*' \
    ${_nvidia_excludes} \
    akmods \
    akmod-nvidia \
    xorg-x11-drv-nvidia \
    xorg-x11-drv-nvidia-cuda \
    xorg-x11-drv-nvidia-libs \
    xorg-x11-drv-nvidia-libs.i686 \
    nvidia-vaapi-driver
unset _xorg_ver _common_ver _nvidia_excludes

# Compile the NVIDIA kernel module against the installed CachyOS kernel.
# akmods writes the .ko files to /usr/lib/modules/<kver>/extra/.
NVIDIA_KVER=$(basename "$(echo /usr/lib/modules/*cachyos*)")
echo "Building NVIDIA module for kernel ${NVIDIA_KVER}"
akmods --force --kernels "${NVIDIA_KVER}"
# Fail loudly if the module was not produced — a silent miss here means NVIDIA
# users get a black screen with no obvious cause.
modinfo -k "${NVIDIA_KVER}" nvidia > /dev/null \
    || { echo "ERROR: NVIDIA module failed to build for ${NVIDIA_KVER}"; exit 1; }

# ── Desktop helper, Plymouth, mutable-workspace, and creator tooling ─────────
# These packages all install from the same repo state, so keep them in one
# transaction to cut down on repeated dependency solving.
dnf5 install -y \
    python3-pyqt6 \
    qt6-qtwayland \
    plymouth \
    plymouth-plugin-script \
    distrobox \
    flatpak-builder \
    unzip \
    git \
    spice-vdagent \
    virt-viewer \
    kscreen
# spice-vdagentd is socket/udev-activated — no systemctl enable needed.

# Homebrew RPM deps
# Clean cached packages before this install: libxcrypt-compat has been showing
# corrupt RPM files in the persistent DNF cache. Remove once mirror stabilises.
dnf5 clean packages
dnf5 install -y gcc glibc-devel libxcrypt-compat patch ruby

# Wire up SDDM and graphical boot via explicit symlinks.
# systemctl enable/set-default are unreliable inside a container build (no
# running systemd bus) and silently no-op when they fail.  Direct symlinks are
# the only guaranteed approach; this matches what Universal Blue and other
# bootc-based distros do.
ln -sf /usr/lib/systemd/system/sddm.service \
    /etc/systemd/system/display-manager.service
ln -sf /usr/lib/systemd/system/graphical.target \
    /etc/systemd/system/default.target


# ── openconnect-sso ──────────────────────────────────────────────────────────
# Palo Alto GlobalProtect VPNs that use SAML/Azure AD auth require a browser-
# based flow that the NetworkManager openconnect plugin cannot handle.
# openconnect-sso wraps openconnect with an embedded Qt WebEngine browser that
# completes the SAML redirect loop and hands the resulting cookie to openconnect.
# Usage: openconnect-sso --server <host>
pip3 install --break-system-packages openconnect-sso

# Remove dnf transaction history and repo solver data from the image layer.
# The download cache is already excluded via --mount=type=cache in the
# Dockerfile, but /var/lib/dnf/ is not on a cache mount and accumulates
# ~30-60 MB of state that serves no purpose in the final OS image.
dnf5 clean all
