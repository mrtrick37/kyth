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
    xorg-x11-drv-amdgpu \
    xorg-x11-drv-nouveau \
    xorg-x11-drv-vmware \
    xorg-x11-drv-qxl \
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

# ── NVIDIA driver (userspace only) ────────────────────────────────────────────
# Kernel module compilation (akmods) is intentionally omitted — it added
# 5–15 min to every build. Only userspace NVIDIA libs are installed here.
dnf5 remove -y nvidia-kmod-common || true
dnf5 install -y --skip-unavailable --allowerasing \
    --disablerepo='*' \
    --enablerepo='fedora*' \
    --enablerepo='updates*' \
    --enablerepo='rpmfusion*' \
    xorg-x11-drv-nvidia \
    xorg-x11-drv-nvidia-cuda \
    xorg-x11-drv-nvidia-libs \
    xorg-x11-drv-nvidia-libs.i686 \
    nvidia-vaapi-driver

# ── Desktop helper, Plymouth, mutable-workspace, and creator tooling ─────────
# These packages all install from the same repo state, so keep them in one
# transaction to cut down on repeated dependency solving.
dnf5 install -y \
    python3-pyqt6 \
    python3-pyqt6-webengine \
    qt6-qtwayland \
    plymouth \
    plymouth-plugin-script \
    distrobox \
    unzip \
    git \
    spice-vdagent \
    virt-viewer \
    kscreen \
    neovim \
    zsh \
    jetbrains-mono-fonts \
    cascadia-code-fonts
# spice-vdagentd is socket/udev-activated — no systemctl enable needed.

# Wire up SDDM and graphical boot via explicit symlinks.
# systemctl enable/set-default are unreliable inside a container build (no
# running systemd bus) and silently no-op when they fail.  Direct symlinks are
# the only guaranteed approach; this matches what Universal Blue and other
# bootc-based distros do.
ln -sf /usr/lib/systemd/system/sddm.service \
    /etc/systemd/system/display-manager.service
ln -sf /usr/lib/systemd/system/graphical.target \
    /etc/systemd/system/default.target


# Remove dnf transaction history and repo solver data from the image layer.
# The download cache is already excluded via --mount=type=cache in the
# Dockerfile, but /var/lib/dnf/ is not on a cache mount and accumulates
# ~30-60 MB of state that serves no purpose in the final OS image.
dnf5 clean all
