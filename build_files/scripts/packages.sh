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
    plasma-nm-openconnect \
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
    qt5-qtwebkit \
    qt6-qtwayland \
    plymouth \
    plymouth-plugin-script \
    distrobox \
    flatpak-builder \
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



# ── GlobalProtect VPN agent + GUI ────────────────────────────────────────────
# Bundled RPMs (proprietary — not available in public repos).
# qt5-qtwebkit (above) satisfies PanGPUI's only non-standard dep.
#
# Root cause of the original /opt install failure: on Fedora Kinoite, /opt is a
# symlink to var/opt, so /proc/PID/exe for any process always shows /var/opt/...
# rather than /opt/... PanGPS does a literal string check that the connecting
# PanGPA's /proc/PID/exe starts with "/opt/paloaltonetworks/globalprotect", which
# always fails. Fix: make /opt a real directory in the image, then mount an
# overlayfs at /opt/paloaltonetworks/globalprotect/ at boot (lower = immutable
# binaries in /usr/lib/, upper = writable data in /var/lib/). Processes exec'd
# through the overlay show /opt/... in /proc/PID/exe, satisfying the check.
rm /opt
mkdir -p /opt

# Extract RPMs into a temp dir.
GP_TMP=$(mktemp -d)
for GP_RPM in \
    /ctx/globalprotect/GlobalProtect_rpm-6.0.10.0-11.rpm \
    /ctx/globalprotect/GlobalProtect_UI_rpm-6.0.10.0-11.rpm; do
    (cd "$GP_TMP" && rpm2cpio "$GP_RPM" | cpio -idm 2>/dev/null)
done

# Install GP binaries to /usr/lib/ (overlay lower layer — immutable, always
# present after upgrades). The overlay mount exposes them at /opt/... at runtime.
mkdir -p /usr/lib/paloaltonetworks/globalprotect
cp -a "$GP_TMP/opt/paloaltonetworks/globalprotect/." /usr/lib/paloaltonetworks/globalprotect/
# UI RPM also ships usr/ (desktop files, icons, man page) and etc/ (autostart)
[[ -d "$GP_TMP/usr" ]] && cp -a "$GP_TMP/usr/." /usr/
[[ -d "$GP_TMP/etc" ]] && cp -a "$GP_TMP/etc/." /etc/
rm -rf "$GP_TMP"

chmod +x /usr/lib/paloaltonetworks/globalprotect/pre_exec_gps.sh

# Create the overlay mount point — an empty real directory at the vendor path.
# The overlayfs mount (see opt-paloaltonetworks-globalprotect.mount below) will
# populate it at boot with binaries from /usr/lib/ and data from /var/lib/.
mkdir -p /opt/paloaltonetworks/globalprotect

# PanGPA autostart — launches the user-side GP agent when KDE/Plasma logs in.
# Must use XDG autostart (not profile.d) because Wayland GUI sessions never
# source /etc/profile.d scripts. The exec path must be under /opt/... so that
# /proc/PID/exe satisfies PanGPS's literal prefix check.
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/PanGPA.desktop <<'PANGPAEOF'
[Desktop Entry]
Name=GlobalProtect Agent
Type=Application
Exec=/opt/paloaltonetworks/globalprotect/PanGPA start
Terminal=false
X-KDE-autostart-condition=PanGPA
PANGPAEOF

# gpd.service: WorkingDirectory is /var/lib/paloaltonetworks/globalprotect so
# PanGPS writes logs and registry there. PanGPS/PanGPA also find data files via
# /opt/... (which the overlay routes to the upper = /var/lib/...).
# init_t SELinux note: semanage permissive -a init_t (below) is required for
# PanGPS to open /dev/net/tun; without it the IPC listener never starts.
cat > /usr/lib/systemd/system/gpd.service <<'GPDSVCEOF'
[Unit]
Description=GlobalProtect VPN client daemon
After=opt-paloaltonetworks-globalprotect.mount
Requires=opt-paloaltonetworks-globalprotect.mount

[Service]
Type=simple
ExecStartPre=/usr/lib/paloaltonetworks/globalprotect/pre_exec_gps.sh
ExecStart=/usr/lib/paloaltonetworks/globalprotect/PanGPS
WorkingDirectory=/var/lib/paloaltonetworks/globalprotect
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
GPDSVCEOF

# Overlayfs mount: presents /opt/paloaltonetworks/globalprotect/ as a unified
# view of binaries (lower, read-only) and data (upper, writable). Processes
# exec'd from here show /opt/... in /proc/PID/exe, satisfying PanGPS's check.
# workdir must be on the same fs as upper and outside both upper and lower.
# Explicit dir-creation service — more reliable than After=systemd-tmpfiles-setup.service
# because tmpfiles and the .mount unit race to completion at the same boot second.
cat > /usr/lib/systemd/system/globalprotect-overlay-dirs.service <<'DIRSVCEOF'
[Unit]
Description=Create GlobalProtect overlay writable directories
DefaultDependencies=no
After=local-fs.target
Before=opt-paloaltonetworks-globalprotect.mount

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=mkdir -p /var/lib/paloaltonetworks/globalprotect /var/cache/paloaltonetworks/gpwork

[Install]
WantedBy=opt-paloaltonetworks-globalprotect.mount
DIRSVCEOF

cat > /usr/lib/systemd/system/opt-paloaltonetworks-globalprotect.mount <<'OVLEOF'
[Unit]
Description=GlobalProtect overlay (binaries + writable data at /opt/... path)
After=globalprotect-overlay-dirs.service
Requires=globalprotect-overlay-dirs.service
Before=gpd.service

[Mount]
What=overlay
Where=/opt/paloaltonetworks/globalprotect
Type=overlay
Options=lowerdir=/usr/lib/paloaltonetworks/globalprotect,upperdir=/var/lib/paloaltonetworks/globalprotect,workdir=/var/cache/paloaltonetworks/gpwork

[Install]
WantedBy=multi-user.target
OVLEOF

# Suppress PanGPUI from autostarting on login — it should only launch when the
# user explicitly clicks the GlobalProtect icon in the launcher.
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/PanGPUI.desktop <<'PANGPUIEOF'
[Desktop Entry]
Name=PanGPUI
Type=Application
Exec=/opt/paloaltonetworks/globalprotect/PanGPUI
Terminal=false
Hidden=true
PANGPUIEOF

# Desktop entries: keep /opt paths (correct now that /opt is real + overlay).
# Revert any earlier /usr/lib rewrites if present.
find /usr/share/applications -name '*.desktop' -exec \
    sed -i 's|/usr/lib/paloaltonetworks/globalprotect/|/opt/paloaltonetworks/globalprotect/|g' {} +

# tmpfiles.d: create writable data dir and overlay workdir on every boot.
mkdir -p /usr/lib/tmpfiles.d
cat > /usr/lib/tmpfiles.d/globalprotect.conf <<'TMPFILESEOF'
d  /var/lib/paloaltonetworks                     0755 root root -
d  /var/lib/paloaltonetworks/globalprotect       0755 root root -
d  /var/cache/paloaltonetworks                   0755 root root -
d  /var/cache/paloaltonetworks/gpwork            0755 root root -
TMPFILESEOF

# Install globalprotect CLI into /usr/bin so it is always on PATH.
install -m 0755 /usr/lib/paloaltonetworks/globalprotect/globalprotect \
    /usr/bin/globalprotect

ln -sf /usr/lib/systemd/system/gpd.service \
    /etc/systemd/system/multi-user.target.wants/gpd.service
ln -sf /usr/lib/systemd/system/opt-paloaltonetworks-globalprotect.mount \
    /etc/systemd/system/multi-user.target.wants/opt-paloaltonetworks-globalprotect.mount
ln -sf /usr/lib/systemd/system/globalprotect-overlay-dirs.service \
    /etc/systemd/system/opt-paloaltonetworks-globalprotect.mount.wants/globalprotect-overlay-dirs.service

# PanGPS runs as init_t (no vendor SELinux module). The default targeted policy
# silently blocks TUNSETIFF on /dev/net/tun via dontaudit rules, preventing the
# daemon from starting its IPC listener. Making init_t permissive allows the ioctl
# — denials are logged but not enforced.
#
# Trade-off: init_t covers all systemd-spawned daemons, not just PanGPS. The
# correct fix is a custom .te policy module (allow init_t self:tun_socket create)
# but that requires offline policy compilation and testing. Accepted for now.
semanage permissive -a init_t

# Remove dnf transaction history and repo solver data from the image layer.
# The download cache is already excluded via --mount=type=cache in the
# Dockerfile, but /var/lib/dnf/ is not on a cache mount and accumulates
# ~30-60 MB of state that serves no purpose in the final OS image.
dnf5 clean all
