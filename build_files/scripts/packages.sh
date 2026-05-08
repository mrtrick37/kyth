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
#
# Also disable negativo17's fedora-multimedia repo when it is inherited from an
# upstream base image. RPM Fusion supplies the codec stack we need, while
# negativo17's Mesa builds have caused AMD VA-API to fail initialization.
python3 - <<'PY'
from pathlib import Path
import configparser

repo_dir = Path("/etc/yum.repos.d")
patterns = ("debug", "source")
disabled_repo_ids = {"fedora-multimedia"}
disabled_repo_tokens = ("negativo17",)

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
        section_lower = section.lower()
        repo_name = parser.get(section, "name", fallback="").lower()
        repo_baseurl = parser.get(section, "baseurl", fallback="").lower()
        repo_metalink = parser.get(section, "metalink", fallback="").lower()
        repo_mirrorlist = parser.get(section, "mirrorlist", fallback="").lower()
        repo_text = "\n".join((section_lower, repo_name, repo_baseurl, repo_metalink, repo_mirrorlist))
        should_disable = (
            any(token in section_lower for token in patterns)
            or section_lower in disabled_repo_ids
            or any(token in repo_text for token in disabled_repo_tokens)
        )
        if should_disable:
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
    kwallet-pam \
    skopeo \
    plasma-workspace-x11 \
    xorg-x11-server-Xorg \
    xorg-x11-xinit \
    xorg-x11-drv-libinput \
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
    fwupd

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
# steam and lutris are intentionally absent as RPMs — both are installed as
# Flatpaks by kyth-default-flatpaks.service so the immutable base stays lean
# while the first-boot gaming experience is ready out of the box.
# umu-launcher is intentionally absent here — not in bazzite COPR for Fedora 44;
# installed from GitHub releases in thirdparty.sh instead.
#
# Keep native libatomic aligned before adding libatomic.i686. Fedora mirror/COPR
# timing can expose a newer i686 build while the base image still carries the
# previous x86_64 build; mismatched multilib RPMs conflict on shared doc files.
dnf5 upgrade -y libatomic.x86_64 || true

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


# ── AMD GPU ───────────────────────────────────────────────────────────────────
# amdgpu is in the CachyOS kernel; RADV (Vulkan) comes from mesa (Fedora repos).
# linux-firmware provides the baseline firmware set.  The AMD subpackages are
# listed explicitly so future Fedora packaging splits cannot accidentally drop
# GPU firmware or CPU microcode from AMD bare-metal installs.
#
# mesa-vulkan-drivers: RADV — the Mesa AMD Vulkan driver. Required for Vulkan
#   on AMD hardware (RDNA/GCN).
# vulkan-loader: the Vulkan ICD loader that dispatches calls to RADV/others.
# mesa-libgbm: Generic Buffer Management — used by DRM/KMS, Wayland, EGL.
# libdrm: Direct Rendering Manager userspace library.
# mesa-dri-drivers: OpenGL/DRI Gallium drivers, also provides radeonsi_drv_video.so
#   (AMD VA-API decode backend used by libva).
# xorg-x11-drv-amdgpu: X11 DDX driver for AMD. Required for SDDM X11 greeter
#   and Xwayland; relies on the in-kernel amdgpu KMS driver.
# xorg-x11-drv-ati: fallback DDX for older Radeon GPUs.
#
# ── QEMU/KVM guest ────────────────────────────────────────────────────────────
# qemu-guest-agent: graceful shutdown, snapshot freeze, guest state queries.
#   spice-vdagent handles clipboard and display resize in SPICE sessions.
dnf5 install -y --skip-unavailable \
    linux-firmware \
    amd-gpu-firmware \
    amd-ucode-firmware \
    libva-utils \
    mesa-vulkan-drivers \
    vulkan-loader \
    mesa-dri-drivers \
    mesa-libgbm \
    libdrm \
    xorg-x11-drv-amdgpu \
    xorg-x11-drv-ati \
    radeontop \
    libclc \
    qemu-guest-agent

# Fedora 44's Mesa split makes `rpm -q mesa-va-drivers` look absent even when
# the VA-API driver is installed. Verify the capability and file ownership
# directly so build logs catch a genuinely broken AMD video decode stack.
rpm -q --whatprovides mesa-va-drivers
rpm -q --whatprovides /usr/lib64/dri/radeonsi_drv_video.so
test -e /usr/lib64/dri/radeonsi_drv_video.so
# qemu-guest-agent is socket-activated on Fedora but the socket is only
# created when running inside a VM. Enable it unconditionally — systemd
# no-ops it on bare metal when the virtio-serial device is absent.
systemctl enable qemu-guest-agent.service 2>/dev/null || true

# Remove plasma-welcome — plasma-login handles first-boot setup instead.
dnf5 remove -y --no-autoremove plasma-welcome plasma-welcome-fedora 2>/dev/null || true

# Remove Firefox — Brave Browser is installed as a Flatpak on first boot
# via kyth-default-flatpaks.service (avoids baking external repo keys into
# the build and eliminates DNS-dependent rpm --import calls in CI).
dnf5 remove -y firefox || true

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
mkdir -p /etc/systemd/system/graphical.target.wants
ln -sf /etc/systemd/system/display-manager.service \
    /etc/systemd/system/graphical.target.wants/display-manager.service
ln -sf /usr/lib/systemd/system/graphical.target \
    /etc/systemd/system/default.target


# Remove dnf transaction history and repo solver data from the image layer.
# The download cache is already excluded via --mount=type=cache in the
# Dockerfile, but /var/lib/dnf/ is not on a cache mount and accumulates
# ~30-60 MB of state that serves no purpose in the final OS image.
dnf5 clean all
