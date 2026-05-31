#!/bin/bash

set -euo pipefail

# ── Display / resolution auto-detection ──────────────────────────────────────
# First-login autostart: run kscreen-doctor to set all outputs to their
# preferred (auto) mode.  Works for both hardware and VMs.  Removes itself
# so it only fires once per user.
mkdir -p /etc/skel/.config/autostart
cat > /etc/skel/.config/autostart/kyth-set-resolution.desktop <<'RESEOF'
[Desktop Entry]
Type=Application
Name=KythOS: Set display resolution
Exec=/usr/bin/kyth-set-resolution
X-KDE-autostart-after=panel
Hidden=false
NoDisplay=true
RESEOF

cat > /usr/bin/kyth-set-resolution <<'SCRIPTEOF'
#!/usr/bin/env python3
# Set every connected output to its preferred (first-listed) mode.
# kscreen-doctor -o output format:
#   Output: 1 Virtual-1 enabled connected
#     Modes: 1:1920x1080@60  2:1280x720@60  ...
# Runs once on first login per user, then removes itself.

import os, re, subprocess, time

# Give KDE's display stack time to fully initialize before querying
time.sleep(3)

result = subprocess.run(['kscreen-doctor', '-o'], capture_output=True, text=True)

current_output = None
for line in result.stdout.splitlines():
    line = line.strip()
    # Match "Output: 1 Virtual-1 enabled connected" — name is the second word
    m = re.match(r'^Output:\s+\d+\s+(\S+)', line)
    if m:
        current_output = m.group(1)
        continue
    # Match "Modes: 1:1920x1080@60  2:..." — first mode is the preferred resolution
    if current_output and re.match(r'^Modes:', line):
        modes = re.findall(r'\d+:(\d+x\d+@[\d.]+)', line)
        if modes:
            subprocess.run([
                'kscreen-doctor',
                f'output.{current_output}.enable',
                f'output.{current_output}.mode.{modes[0]}',
            ], check=False)
        current_output = None

autostart = os.path.expanduser('~/.config/autostart/kyth-set-resolution.desktop')
try:
    os.unlink(autostart)
except OSError:
    pass
SCRIPTEOF
chmod +x /usr/bin/kyth-set-resolution

# Ensure the built image advertises the KythOS product name. Some boot/installer
# menus derive their display strings from `/etc/os-release` or similar metadata.
# We overwrite or create `/etc/os-release` with KythOS values so boot menus show
# "KythOS" instead of upstream branding.
cat > /etc/os-release <<'EOF' || true
NAME="KythOS"
PRETTY_NAME="KythOS 44"
ID=fedora
VERSION="44"
VERSION_ID="44"
ANSI_COLOR="0;34"
LOGO=kyth
HOME_URL="https://github.com/mrtrick37/kyth"
SUPPORT_URL="https://github.com/mrtrick37/kyth/discussions"
BUG_REPORT_URL="https://github.com/mrtrick37/kyth/issues"
EOF

# ── Topgrade config for all new users ────────────────────────────────────────
# Disable rpm-ostree step: on a bootc system rpm-ostree upgrade pulls from the
# upstream Kinoite ostree remote, not the KythOS container registry.
# Replace it with a bootc upgrade custom step so topgrade does the right thing.
mkdir -p /etc/skel/.config
cat > /etc/skel/.config/topgrade.toml <<'TOPGRADEEOF'
[misc]
# system (dnf5) is read-only on bootc — disable it; bootc upgrade is used instead.
# distrobox: disabled because distrobox-upgrade --all fails without a PTY.
#   Update containers manually with: distrobox-upgrade --all
# containers: podman container updates fail on a bootc read-only system.
# toolbx: kyth-dev is managed via ujust, not topgrade; toolbx version-compat
#   checks will fail the whole topgrade run if the container needs recreation.
disable = ["system", "distrobox", "containers", "toolbx"]

[commands]
# -n makes sudo fail fast if it can't run non-interactively, rather than hanging
# waiting for a password. NOPASSWD is granted in /etc/sudoers.d/kyth-bootc.
"KythOS system update" = "sudo -n bootc upgrade"
"KythOS rclone update" = "sudo -n /usr/bin/kyth-rclone-update"
TOPGRADEEOF

# ── Default KDE theme for all new users via /etc/skel ─────────────────────────
mkdir -p /etc/skel/.config
cat > /etc/skel/.config/kdeglobals <<'KDEEOF'
[General]
ColorScheme=BreezeDark

[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
KDEEOF

cat > /etc/skel/.config/plasmarc <<'PLASMAEOF'
[Theme]
name=breeze-dark
PLASMAEOF

# ── Kickoff favorites ─────────────────────────────────────────────────────────
# Pre-populate the Kickoff launcher favorites for new users.
# Brave and Discord are listed here even though they install via
# kyth-default-flatpaks.service at first boot — KDE silently omits entries
# whose desktop files don't exist yet and shows them automatically once the
# flatpak finishes installing.
cat > /etc/skel/.config/kickoffrc <<'KICKOFFEOF'
[Favorites]
FavoriteURLs=applications:steam.desktop,applications:com.brave.Browser.desktop,applications:com.discordapp.Discord.desktop,applications:kyth-welcome.desktop,applications:org.kde.konsole.desktop

[General]
highlightNewlyInstalledApps=false
KICKOFFEOF
mkdir -p /etc/xdg
install -m 0644 /etc/skel/.config/kickoffrc /etc/xdg/kickoffrc

# ── Screen lock timeout ───────────────────────────────────────────────────────
# Default auto-lock after 15 minutes of inactivity. KDE's stock default is 5
# minutes which is too aggressive for a desktop/gaming workstation.
cat > /etc/skel/.config/kscreenlockerrc <<'SCREENLOCKEOF'
[Daemon]
Autolock=true
LockGracePeriod=5
LockOnResume=true
Timeout=15
SCREENLOCKEOF

# ── Plasma / PowerDevil hardening ─────────────────────────────────────────────
# KDE documents POWERDEVIL_NO_DDCUTIL=1 as a supported workaround when
# PowerDevil's DDC/CI monitor integration causes instability. On KythOS's AMD
# laptop targets, repeated libddcutil/backlight activity has correlated with
# display-timeout/pageflip failures, so default to the safer path:
# keep PowerDevil running, but stop it from talking to external monitors via
# ddcutil. Tradeoff: external monitor brightness control via DDC/CI is disabled.
#
# Add a second guardrail at the libddcutil layer as well. This keeps any
# consumer that does load libddcutil from starting display-watch threads, which
# are a known source of instability on some monitor/GPU combinations.
mkdir -p /etc/xdg/plasma-workspace/env /etc/xdg/ddcutil
cat > /etc/environment.d/90-kyth-powerdevil.conf <<'POWERDEVILEOF'
POWERDEVIL_NO_DDCUTIL=1
POWERDEVILEOF
cat > /etc/xdg/plasma-workspace/env/90-kyth-powerdevil.sh <<'POWERDEVILSHEOF'
#!/bin/sh
export POWERDEVIL_NO_DDCUTIL=1
POWERDEVILSHEOF
chmod +x /etc/xdg/plasma-workspace/env/90-kyth-powerdevil.sh
cat > /etc/xdg/ddcutil/ddcutilrc <<'DDCUTILRCEOF'
[libddcutil]
options: --disable-watch-displays
DDCUTILRCEOF

# ── KythOS wallpaper package ────────────────────────────────────────────────────
# Install as a proper KDE wallpaper package so the L&F lookup 'Image=kyth' works.
mkdir -p /usr/share/wallpapers/kyth/contents/images
cp /ctx/wallpaper/kyth-wallpaper.svg \
    /usr/share/wallpapers/kyth/contents/images/1920x1080.svg
printf '{"KPlugin":{"Authors":[{"Name":"KythOS"}],"Id":"kyth","Name":"KythOS","License":"CC-BY-SA-4.0"},"KPackageStructure":"Wallpaper/Images"}\n' \
    > /usr/share/wallpapers/kyth/metadata.json

# Patch all L&F defaults (Fedora variants + Breeze) to use KythOS wallpaper.
# Fedora Kinoite ships org.fedoraproject.fedora*.desktop themes that set
# Image=Fedora; we replace that in every theme so no L&F can restore the
# stock Fedora rocket wallpaper.
find /usr/share/plasma/look-and-feel -name defaults | while read -r f; do
    sed -i 's/^Image=.*/Image=kyth/' "$f"
    grep -q '^Image=' "$f" || printf '\n[Wallpaper]\nImage=kyth\n' >> "$f"
done

# System-wide XDG fallback — applied to every user before their personal
# config exists, so first-boot always shows the KythOS wallpaper.
mkdir -p /etc/xdg
cat > /etc/xdg/plasma-org.kde.plasma.desktop-appletsrc <<'XDGPLASMAEOF'
[Containments][1][Wallpaper][org.kde.image][General]
Image=/usr/share/wallpapers/kyth/contents/images/1920x1080.svg
XDGPLASMAEOF

# ── SDDM session type + login screen background ───────────────────────────────
# Force X11 display server. Kinoite 44 / KDE 6.6 defaults to a Wayland session;
# KWin Wayland requires a working DRM/GBM backend and can crash on VM GPUs
# without 3D acceleration, which drops the SPICE
# connection and makes the VM appear to close. X11 is stable on all hardware
# and VM GPU drivers; users can switch to Wayland from the session picker.
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-kyth.conf <<'SDDMCONFEOF'
[General]
DisplayServer=x11
DefaultSession=plasmax11.desktop

[Theme]
Current=breeze

[X11]
SessionDir=/usr/share/xsessions
SDDMCONFEOF

# Software-rendering fallback for virtual machines: makes Plasma's X11 session
# usable when the VM display has no virgl/3D acceleration. Skipped on bare metal
# (systemd-detect-virt returns non-zero when not in a VM/container) and when
# kyth.hwgl=1 is in the cmdline to force hardware GL inside a VM.
mkdir -p /etc/skel/.config/plasma-workspace/env
cat > /etc/skel/.config/plasma-workspace/env/10-kyth-qemu-safe.sh <<'QEMUSAFEEOF'
#!/bin/sh
if systemd-detect-virt -q 2>/dev/null && ! grep -qw 'kyth.hwgl=1' /proc/cmdline 2>/dev/null; then
    export LIBGL_ALWAYS_SOFTWARE=1
    export GALLIUM_DRIVER=llvmpipe
    export MESA_LOADER_DRIVER_OVERRIDE=llvmpipe
    export QT_QUICK_BACKEND=software
fi
QEMUSAFEEOF
chmod +x /etc/skel/.config/plasma-workspace/env/10-kyth-qemu-safe.sh

# theme.conf.user overrides the breeze SDDM theme defaults without modifying
# the upstream theme files. The wallpaper is already installed above.
mkdir -p /usr/share/sddm/themes/breeze
cat > /usr/share/sddm/themes/breeze/theme.conf.user <<'SDDMEOF'
[General]
type=image
background=/usr/share/wallpapers/kyth/contents/images/1920x1080.svg
SDDMEOF

# ── KythOS icons ───────────────────────────────────────────────────────────────
# KDE Plasma 6 Kickoff looks up icons in this order:
#   start-here-kde-plasma → start-here-kde → start-here
# Two failure modes to defeat:
#   1. fedora-logos ships PNGs at exact pixel sizes; Qt/Plasma prefers an
#      exact-size PNG over a scalable SVG, so the Fedora icon won at lookup.
#   2. The Kickoff plasmoid's default icon is "", which falls back to the theme
#      lookup — so a cached/stale Fedora logo survived into the applet.
# Fix: install PNGs at every standard size AND patch Kickoff's main.xml so the
# compiled-in default is kyth-kickoff, requiring no per-user config at all.

# Scalable SVGs (also used by the kyth-set-kickoff-icon first-login script)
for theme_dir in \
    /usr/share/icons/hicolor/scalable/apps \
    /usr/share/icons/breeze/apps/scalable \
    /usr/share/icons/breeze-dark/apps/scalable; do
    mkdir -p "${theme_dir}"
    cp /ctx/branding/kyth-logo-transparent.svg "${theme_dir}/kyth.svg"
    cp /ctx/branding/kyth-logo-transparent.svg "${theme_dir}/kyth-symbol.svg"
    cp /ctx/branding/kyth-kickoff.svg "${theme_dir}/kyth-kickoff.svg"
    cp /ctx/branding/kyth-kickoff.svg "${theme_dir}/start-here.svg"
    cp /ctx/branding/kyth-kickoff.svg "${theme_dir}/start-here-kde.svg"
    cp /ctx/branding/kyth-kickoff.svg "${theme_dir}/start-here-kde-plasma.svg"
done

# PNGs at every standard size — beats fedora-logos exact-size PNG at lookup
for sz in 16 22 24 32 48 64 128 256; do
    for base in /usr/share/icons/hicolor /usr/share/icons/breeze /usr/share/icons/breeze-dark; do
        dir="${base}/${sz}x${sz}/apps"
        mkdir -p "${dir}"
        rsvg-convert -w "${sz}" -h "${sz}" /ctx/branding/kyth-kickoff.svg \
            -o "${dir}/kyth-kickoff.png"
        rsvg-convert -w "${sz}" -h "${sz}" /ctx/branding/kyth-kickoff.svg \
            -o "${dir}/start-here.png"
        rsvg-convert -w "${sz}" -h "${sz}" /ctx/branding/kyth-kickoff.svg \
            -o "${dir}/start-here-kde.png"
        rsvg-convert -w "${sz}" -h "${sz}" /ctx/branding/kyth-kickoff.svg \
            -o "${dir}/start-here-kde-plasma.png"
    done
done

# Clear any stale caches so the new icons take effect immediately on first boot.
rm -f /usr/share/icons/hicolor/icon-theme.cache
rm -f /usr/share/icons/breeze/icon-theme.cache
rm -f /usr/share/icons/breeze-dark/icon-theme.cache
gtk-update-icon-cache -f /usr/share/icons/hicolor/    2>/dev/null || true
gtk-update-icon-cache -f /usr/share/icons/breeze/      2>/dev/null || true
gtk-update-icon-cache -f /usr/share/icons/breeze-dark/ 2>/dev/null || true

# ── Kickoff plasmoid defaults ─────────────────────────────────────────────────
# Patch Kickoff's KConfig XML so every new widget instance defaults to
# kyth-kickoff and quiet newly-installed app badges before any per-user config
# file or first-login script exists.
# The empty <default></default> is the upstream fallback that causes Kickoff
# to use start-here-kde-plasma from the icon theme; we replace it with the
# named icon so the plasmoid's own default wins unconditionally.
_kickoff_cfg=/usr/share/plasma/plasmoids/org.kde.plasma.kickoff/contents/config/main.xml
if [[ -f "${_kickoff_cfg}" ]]; then
    sed -i \
        '/<entry name="icon" type="String">/,/<\/entry>/ {
            s|<default></default>|<default>kyth-kickoff</default>|
        }' \
        "${_kickoff_cfg}"
    sed -i \
        '/<entry name="highlightNewlyInstalledApps" type="Bool">/,/<\/entry>/ {
            s|<default>true</default>|<default>false</default>|
        }' \
        "${_kickoff_cfg}"
fi

# ── First-login script: polish Kickoff launcher defaults ──────────────────────
# Belt-and-suspenders: the icon theme install above should be enough, but this
# also writes the icon key directly into each user's Kickoff applet config in
# case the theme lookup is overridden by a previously cached value. It also
# disables Plasma's newly-installed app badges so KythOS launchers land in
# their categories without green dots or "New!" labels.
cat > /usr/bin/kyth-set-kickoff-icon <<'KICKOFEOF'
#!/usr/bin/env python3
import os, re, shutil, subprocess

aprc = os.path.expanduser("~/.config/plasma-org.kde.plasma.desktop-appletsrc")
autostart = os.path.expanduser("~/.config/autostart/kyth-set-kickoff-icon.desktop")
kwriteconfig = shutil.which('kwriteconfig6')

if kwriteconfig:
    subprocess.run([
        kwriteconfig, '--file', 'kickoffrc',
        '--group', 'General',
        '--key', 'highlightNewlyInstalledApps',
        '--type', 'bool', 'false',
    ], check=False)

if kwriteconfig and os.path.exists(aprc):
    content = open(aprc).read()
    for m in re.finditer(
        r'^\[Containments\]\[(\d+)\]\[Applets\]\[(\d+)\]',
        content, re.MULTILINE
    ):
        cont, applet = m.group(1), m.group(2)
        body_start = m.end()
        nxt = re.search(r'^\[', content[body_start:], re.MULTILINE)
        body = content[body_start: body_start + nxt.start()] if nxt else content[body_start:]
        if 'plugin=org.kde.plasma.kickoff' in body:
            subprocess.run([
                kwriteconfig, '--file', aprc,
                '--group', 'Containments', '--group', cont,
                '--group', 'Applets', '--group', applet,
                '--group', 'Configuration', '--group', 'General',
                '--key', 'icon', 'kyth-kickoff',
            ], check=False)
            subprocess.run([
                kwriteconfig, '--file', aprc,
                '--group', 'Containments', '--group', cont,
                '--group', 'Applets', '--group', applet,
                '--group', 'Configuration', '--group', 'General',
                '--key', 'highlightNewlyInstalledApps',
                '--type', 'bool', 'false',
            ], check=False)

try:
    os.unlink(autostart)
except OSError:
    pass
KICKOFEOF
chmod +x /usr/bin/kyth-set-kickoff-icon

mkdir -p /etc/skel/.config/autostart
cat > /etc/skel/.config/autostart/kyth-set-kickoff-icon.desktop <<'AUTOSTARTEOF'
[Desktop Entry]
Type=Application
Name=KythOS: Set Kickoff Icon
Exec=/usr/bin/kyth-set-kickoff-icon
X-KDE-autostart-after=panel
Hidden=false
NoDisplay=true
AUTOSTARTEOF

mkdir -p /etc/xdg/autostart
install -m 0644 /etc/skel/.config/autostart/kyth-set-kickoff-icon.desktop \
    /etc/xdg/autostart/kyth-set-kickoff-icon.desktop

# ── User comfort polish ───────────────────────────────────────────────────────
# KDE stores several "Windows users expect this" preferences per-user. Bake a
# versioned, automatic polish pass into the image so new accounts get it from
# /etc/skel and existing accounts receive it once after an OS update.
cat > /usr/bin/kyth-user-polish <<'POLISHEOF'
#!/usr/bin/env bash
set -euo pipefail

version="v4"
stamp_dir="${HOME}/.local/share/kyth"
stamp="${stamp_dir}/user-polish-${version}"
old_autostart="${HOME}/.config/autostart/kyth-windows-friendly-defaults.desktop"

if [[ -f "${stamp}" ]]; then
    rm -f "${old_autostart}" "${HOME}/.config/autostart/kyth-user-polish.desktop" 2>/dev/null || true
    exit 0
fi

mkdir -p "${stamp_dir}"

# Ensure common folders exist even when xdg-user-dirs did not run yet. Games is
# intentionally non-standard but important for a Windows-style "where do I put
# my game stuff?" mental model.
if command -v xdg-user-dirs-update >/dev/null 2>&1; then
    xdg-user-dirs-update >/dev/null 2>&1 || true
fi
mkdir -p \
    "${HOME}/Desktop" \
    "${HOME}/Documents" \
    "${HOME}/Downloads" \
    "${HOME}/Games" \
    "${HOME}/Music" \
    "${HOME}/Pictures" \
    "${HOME}/Public" \
    "${HOME}/Templates" \
    "${HOME}/Videos"

if [[ ! -f "${HOME}/Games/.directory" ]]; then
    cat > "${HOME}/Games/.directory" <<'GAMESDIREEOF'
[Desktop Entry]
Icon=applications-games
Name=Games
GAMESDIREEOF
fi

if [[ ! -f "${HOME}/Templates/Plain Text.txt" ]]; then
    printf '' > "${HOME}/Templates/Plain Text.txt"
fi

# File associations that make double-click behavior feel normal on day one.
# Use xdg-mime so existing user choices are updated per MIME type without
# clobbering unrelated custom associations.
mkdir -p "${HOME}/.config"
if command -v xdg-mime >/dev/null 2>&1; then
    while IFS='|' read -r desktop mime; do
        [[ -n "${desktop}" && -n "${mime}" ]] || continue
        xdg-mime default "${desktop}" "${mime}" >/dev/null 2>&1 || true
    done <<'MIMEDEFAULTS'
org.kde.okular.desktop|application/pdf
org.kde.okular.desktop|application/epub+zip
org.kde.gwenview.desktop|image/jpeg
org.kde.gwenview.desktop|image/png
org.kde.gwenview.desktop|image/gif
org.kde.gwenview.desktop|image/webp
org.videolan.VLC.desktop|video/mp4
org.videolan.VLC.desktop|video/x-matroska
org.videolan.VLC.desktop|video/x-msvideo
org.videolan.VLC.desktop|audio/mpeg
org.videolan.VLC.desktop|audio/flac
org.kde.kwrite.desktop|text/plain
org.kde.kwrite.desktop|text/markdown
org.kde.ark.desktop|application/zip
org.kde.ark.desktop|application/x-7z-compressed
org.kde.ark.desktop|application/x-rar
org.kde.ark.desktop|application/x-tar
kyth-exe-handler.desktop|application/x-ms-dos-executable
kyth-exe-handler.desktop|application/x-msdos-program
kyth-exe-handler.desktop|application/x-dosexec
kyth-exe-handler.desktop|application/x-msi
kyth-exe-handler.desktop|application/x-msdownload
kyth-exe-handler.desktop|application/vnd.microsoft.portable-executable
com.brave.Browser.desktop|x-scheme-handler/http
com.brave.Browser.desktop|x-scheme-handler/https
com.getmailspring.Mailspring.desktop|x-scheme-handler/mailto
org.kde.dolphin.desktop|inode/directory
MIMEDEFAULTS
fi

# Dolphin Places sidebar: seed a Windows-familiar set without depending on
# fragile GUI state. Preserve existing customized places; add Games when absent.
mkdir -p "${HOME}/.local/share"
places_file="${HOME}/.local/share/user-places.xbel"
if [[ ! -f "${places_file}" ]]; then
    cat > "${places_file}" <<PLACESXBELEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE xbel>
<xbel version="1.0">
 <bookmark href="file://${HOME}">
  <title>Home</title>
  <info><metadata owner="http://freedesktop.org"><bookmark:icon name="user-home" xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks"/></metadata></info>
 </bookmark>
 <bookmark href="file://${HOME}/Desktop">
  <title>Desktop</title>
  <info><metadata owner="http://freedesktop.org"><bookmark:icon name="user-desktop" xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks"/></metadata></info>
 </bookmark>
 <bookmark href="file://${HOME}/Documents">
  <title>Documents</title>
  <info><metadata owner="http://freedesktop.org"><bookmark:icon name="folder-documents" xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks"/></metadata></info>
 </bookmark>
 <bookmark href="file://${HOME}/Downloads">
  <title>Downloads</title>
  <info><metadata owner="http://freedesktop.org"><bookmark:icon name="folder-download" xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks"/></metadata></info>
 </bookmark>
 <bookmark href="file://${HOME}/Games">
  <title>Games</title>
  <info><metadata owner="http://freedesktop.org"><bookmark:icon name="applications-games" xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks"/></metadata></info>
 </bookmark>
 <bookmark href="file://${HOME}/Pictures">
  <title>Pictures</title>
  <info><metadata owner="http://freedesktop.org"><bookmark:icon name="folder-pictures" xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks"/></metadata></info>
 </bookmark>
 <bookmark href="file://${HOME}/Videos">
  <title>Videos</title>
  <info><metadata owner="http://freedesktop.org"><bookmark:icon name="folder-videos" xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks"/></metadata></info>
 </bookmark>
 <bookmark href="trash:/">
  <title>Trash</title>
  <info><metadata owner="http://freedesktop.org"><bookmark:icon name="user-trash" xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks"/></metadata></info>
 </bookmark>
 <bookmark href="network:/">
  <title>Network</title>
  <info><metadata owner="http://freedesktop.org"><bookmark:icon name="network-workgroup" xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks"/></metadata></info>
 </bookmark>
</xbel>
PLACESXBELEOF
elif ! grep -Fq "file://${HOME}/Games" "${places_file}"; then
    tmp_places="${places_file}.kyth-tmp"
    awk -v home="${HOME}" '
        /<\/xbel>/ && !done {
            print " <bookmark href=\"file://" home "/Games\">"
            print "  <title>Games</title>"
            print "  <info><metadata owner=\"http://freedesktop.org\"><bookmark:icon name=\"applications-games\" xmlns:bookmark=\"http://www.freedesktop.org/standards/desktop-bookmarks\"/></metadata></info>"
            print " </bookmark>"
            done=1
        }
        { print }
    ' "${places_file}" > "${tmp_places}" && mv "${tmp_places}" "${places_file}"
fi

if command -v kwriteconfig6 >/dev/null 2>&1; then
    # Ctrl+Shift+Esc → System Monitor (Task Manager equivalent)
    kwriteconfig6 --file kglobalshortcutsrc \
        --group org.kde.plasma-systemmonitor.desktop \
        --key _launch 'Ctrl+Shift+Esc,none,System Monitor'

    # Double-click to open files — KDE defaults to single-click; Windows users
    # expect double-click everywhere (Dolphin, desktop, file dialogs).
    kwriteconfig6 --file kdeglobals --group KDE --key SingleClick --type bool false

    # Keep Kickoff categories quiet after first-boot Flatpak/app installs.
    kwriteconfig6 --file kickoffrc \
        --group General \
        --key highlightNewlyInstalledApps \
        --type bool false

    # Clipboard history — Win+V equivalent. Klipper ships enabled but history
    # is off by default; turn it on with a 25-item buffer.
    kwriteconfig6 --file klipperrc --group General --key KeepClipboardContents --type bool true
    kwriteconfig6 --file klipperrc --group General --key MaxClipItems 25

    # Dolphin/File Explorer comfort: remember view properties per folder, keep
    # previews available, and use a visible location bar instead of breadcrumbs
    # for easier path copy/paste during support and migration.
    kwriteconfig6 --file dolphinrc --group General --key RememberOpenedTabs --type bool true
    kwriteconfig6 --file dolphinrc --group General --key ShowFullPath --type bool true
    kwriteconfig6 --file dolphinrc --group General --key UseTabForSplitViewSwitch --type bool true
    kwriteconfig6 --file dolphinrc --group General --key ShowSpaceInfo --type bool true
    kwriteconfig6 --file dolphinrc --group DetailsMode --key PreviewSize 32
fi

if command -v /usr/bin/kyth-set-kickoff-icon >/dev/null 2>&1; then
    /usr/bin/kyth-set-kickoff-icon >/dev/null 2>&1 || true
fi

if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
fi

if command -v /usr/bin/kyth-steam-game-export >/dev/null 2>&1; then
    /usr/bin/kyth-steam-game-export >/dev/null 2>&1 || true
fi

touch "${stamp}"
rm -f "${old_autostart}" "${HOME}/.config/autostart/kyth-user-polish.desktop" 2>/dev/null || true
POLISHEOF
chmod +x /usr/bin/kyth-user-polish

# Backward-compatible command name used by existing docs, support notes, and
# old smoke-check output. It now runs the same build-integrated polish pass.
cat > /usr/bin/kyth-windows-friendly-defaults <<'WINDEFAULTEOF'
#!/usr/bin/env bash
exec /usr/bin/kyth-user-polish "$@"
WINDEFAULTEOF
chmod +x /usr/bin/kyth-windows-friendly-defaults

cat > /etc/skel/.config/autostart/kyth-user-polish.desktop <<'POLISHDESKTOPEOF'
[Desktop Entry]
Type=Application
Name=KythOS: User Comfort Polish
Exec=/usr/bin/kyth-user-polish
X-KDE-autostart-after=panel
Hidden=false
NoDisplay=true
POLISHDESKTOPEOF

# Global autostart means existing users receive new polish migrations after an
# OS update too; the version stamp above prevents repeated preference churn.
install -m 0644 /etc/skel/.config/autostart/kyth-user-polish.desktop \
    /etc/xdg/autostart/kyth-user-polish.desktop

# Seed the same familiar folder layout into fresh homes. The autostart helper
# repairs these for existing users and for accounts created by unusual tools.
mkdir -p \
    /etc/skel/Desktop \
    /etc/skel/Documents \
    /etc/skel/Downloads \
    /etc/skel/Games \
    /etc/skel/Music \
    /etc/skel/Pictures \
    /etc/skel/Public \
    /etc/skel/Templates \
    /etc/skel/Videos

cat > /etc/skel/Games/.directory <<'GAMESDIREEOF'
[Desktop Entry]
Icon=applications-games
Name=Games
GAMESDIREEOF

cat > /etc/skel/.config/user-dirs.dirs <<'USERDIRSEOF'
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_TEMPLATES_DIR="$HOME/Templates"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"
USERDIRSEOF

cat > /etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc <<'PLASMADESKTOPEOF'
[Containments][1]
wallpaperplugin=org.kde.image

[Containments][1][Wallpaper][org.kde.image][General]
Image=/usr/share/wallpapers/kyth/contents/images/1920x1080.svg
PLASMADESKTOPEOF

# ── MangoHud defaults ─────────────────────────────────────────────────────────
# Ship a sensible system-wide config so MangoHud shows useful info out of the box.
# Users can override in ~/.config/MangoHud/MangoHud.conf or per-app.
mkdir -p /etc/MangoHud
install -m 0644 /ctx/MangoHud.conf /etc/MangoHud/MangoHud.conf

# ── vkBasalt defaults ─────────────────────────────────────────────────────────
# vkBasalt is inactive unless ENABLE_VKBASALT=1 is set per-game.
# Ship a default config (CAS sharpening) so it works correctly when enabled.
# Users can override with ~/.config/vkBasalt/vkBasalt.conf
install -m 0644 /ctx/vkBasalt.conf /etc/vkBasalt.conf


# ── KythOS Helper app — /ctx file installs ──────────────────────────────────────
install -m 0755 /ctx/kyth-welcome/kyth-welcome /usr/bin/kyth-welcome
install -m 0755 /ctx/kyth-welcome/kyth-welcome-launch /usr/bin/kyth-welcome-launch
install -m 0644 /ctx/kyth-welcome/kyth-welcome.desktop \
    /usr/share/applications/kyth-welcome.desktop
install -m 0755 /ctx/kyth-installer /usr/bin/kyth-installer
install -m 0755 /ctx/kyth-launch-installer /usr/bin/kyth-launch-installer
install -m 0755 /ctx/kyth-partition-install.sh /usr/bin/kyth-partition-install

cat > /usr/share/applications/kyth-install.desktop <<'INSTALLDESKTOPEOF'
[Desktop Entry]
Name=Install or Reinstall KythOS
Comment=Install KythOS to a disk using the guided installer
Exec=/usr/bin/kyth-launch-installer
Icon=kyth
Terminal=false
Type=Application
Categories=System;
INSTALLDESKTOPEOF

# Place System Hub on the desktop for all new users. The executable bit is
# required so KDE Plasma 6 treats it as trusted without prompting the user.
mkdir -p /etc/skel/Desktop
install -m 0755 /ctx/kyth-welcome/kyth-welcome.desktop \
    /etc/skel/Desktop/kyth-welcome.desktop

install -m 0755 /ctx/kyth-welcome/kyth-update-notifier /usr/bin/kyth-update-notifier
install -m 0644 /ctx/kyth-welcome/kyth-update-notifier.desktop \
    /usr/share/applications/kyth-update-notifier.desktop
# Autostart the notifier for new user accounts
mkdir -p /etc/skel/.config/autostart
install -m 0644 /ctx/kyth-welcome/kyth-update-notifier.desktop \
    /etc/skel/.config/autostart/kyth-update-notifier.desktop

# User-session confidence checks. These show friendly notifications and are
# version/deployment-gated so they do not nag on every login.
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/kyth-post-update-check.desktop <<'POSTUPDATEAUTOSTARTEOF'
[Desktop Entry]
Type=Application
Name=KythOS Post-Update Check
Exec=/usr/bin/kyth-post-update-check
NoDisplay=true
X-KDE-autostart-after=panel
POSTUPDATEAUTOSTARTEOF

cat > /etc/xdg/autostart/kyth-firstboot-app-status.desktop <<'APPSTATUSAUTOSTARTEOF'
[Desktop Entry]
Type=Application
Name=KythOS App Setup Status
Exec=/usr/bin/kyth-firstboot-app-status
NoDisplay=true
X-KDE-autostart-after=panel
APPSTATUSAUTOSTARTEOF

# Steam Flatpak writes game shortcuts inside its sandbox. Refresh host menu
# exports quietly at login so installed games appear under Games in KDE.
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/kyth-steam-game-export.desktop <<'STEAMEXPORTAUTOSTARTEOF'
[Desktop Entry]
Type=Application
Name=KythOS Steam Game Menu Export
Exec=/usr/bin/kyth-steam-game-export
NoDisplay=true
X-KDE-autostart-after=panel
STEAMEXPORTAUTOSTARTEOF

# Import-smoke the helper during the build so syntax errors, missing Python
# dependencies, and top-level failures fail the image without running slow
# desktop and hardware probes inside the build container.
python3 -c '
import importlib.machinery, importlib.util, pathlib
path = pathlib.Path("/usr/bin/kyth-welcome")
loader = importlib.machinery.SourceFileLoader("kyth_welcome_smoke", str(path))
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)
'

install -m 0755 /ctx/game-performance /usr/bin/game-performance
install -m 0755 /ctx/kyth-gamescope /usr/bin/kyth-gamescope
install -m 0755 /ctx/kyth-performance-mode /usr/bin/kyth-performance-mode
install -m 0755 /ctx/kyth-scx /usr/bin/kyth-scx
install -m 0755 /ctx/zink-run /usr/bin/zink-run
install -m 0755 /ctx/kyth-kerver /usr/bin/kyth-kerver
install -m 0755 /ctx/kyth-device-info /usr/bin/kyth-device-info
install -m 0755 /ctx/kyth-smoke-check /usr/bin/kyth-smoke-check
install -m 0755 /ctx/kyth-post-update-check /usr/bin/kyth-post-update-check
install -m 0755 /ctx/kyth-firstboot-app-status /usr/bin/kyth-firstboot-app-status
install -m 0755 /ctx/kyth-controller-check /usr/bin/kyth-controller-check
install -m 0755 /ctx/kyth-resume-check /usr/bin/kyth-resume-check
install -m 0755 /ctx/kyth-nvidia-status /usr/bin/kyth-nvidia-status
install -m 0755 /ctx/kyth-creator-check /usr/bin/kyth-creator-check
install -m 0755 /ctx/kyth-davinci-install /usr/bin/kyth-davinci-install
install -m 0755 /ctx/kyth-duperemove /usr/bin/kyth-duperemove
install -m 0755 /ctx/kyth-distrobox-root-launch /usr/bin/kyth-distrobox-root-launch
install -m 0755 /ctx/kyth-local-bin-migrate /usr/bin/kyth-local-bin-migrate
install -m 0644 /ctx/kyth-duperemove.service /usr/lib/systemd/system/kyth-duperemove.service
install -m 0644 /ctx/kyth-duperemove.timer /usr/lib/systemd/system/kyth-duperemove.timer
install -m 0644 /ctx/kyth-local-bin-migrate.service /usr/lib/systemd/system/kyth-local-bin-migrate.service
install -m 0755 /ctx/kyth-topgrade-migrate        /usr/bin/kyth-topgrade-migrate
install -m 0755 /ctx/kyth-vscode-wallet /usr/bin/kyth-vscode-wallet
install -m 0644 /ctx/kyth-topgrade-migrate.service /usr/lib/systemd/system/kyth-topgrade-migrate.service
install -m 0755 /ctx/kyth-vpn-connect/kyth-vpn-connect /usr/bin/kyth-vpn-connect
install -m 0644 /ctx/kyth-vpn-connect/kyth-vpn-connect.desktop \
    /usr/share/applications/kyth-vpn-connect.desktop
install -m 0755 /ctx/kyth-vpnc-script /usr/libexec/kyth-vpnc-script
install -m 0755 /ctx/kyth-vpn-status/kyth-vpn-status /usr/bin/kyth-vpn-status
# ── .exe / .msi MIME interception ─────────────────────────────────────────────
# When a Windows user double-clicks a .exe installer in Dolphin, show a dialog
# that suggests the best Linux equivalent instead of opening a hex editor.
# The handler is registered as the system-wide default for the Windows executable
# MIME types; users can override per-app via Dolphin's "Open With" dialog.
install -m 0755 /ctx/kyth-exe-handler /usr/bin/kyth-exe-handler
install -m 0644 /ctx/kyth-exe-handler.desktop \
    /usr/share/applications/kyth-exe-handler.desktop

# Register as system-wide default for Windows executable MIME types.
# /etc/xdg/mimeapps.list is the XDG-standard location for system defaults;
# it is read before per-user ~/.config/mimeapps.list so new users get it
# automatically, and existing users can still override per-app.
mkdir -p /etc/xdg
cat >> /etc/xdg/mimeapps.list <<'MIMEAPPSEOF'
[Default Applications]
application/pdf=org.kde.okular.desktop;okularApplication_pdf.desktop;
application/epub+zip=org.kde.okular.desktop;okularApplication_epub.desktop;
image/jpeg=org.kde.gwenview.desktop;gwenview.desktop;
image/png=org.kde.gwenview.desktop;gwenview.desktop;
image/gif=org.kde.gwenview.desktop;gwenview.desktop;
image/webp=org.kde.gwenview.desktop;gwenview.desktop;
video/mp4=org.videolan.VLC.desktop;mpv.desktop;org.kde.haruna.desktop;
video/x-matroska=org.videolan.VLC.desktop;mpv.desktop;org.kde.haruna.desktop;
video/x-msvideo=org.videolan.VLC.desktop;mpv.desktop;org.kde.haruna.desktop;
audio/mpeg=org.videolan.VLC.desktop;mpv.desktop;org.kde.elisa.desktop;
audio/flac=org.videolan.VLC.desktop;mpv.desktop;org.kde.elisa.desktop;
text/plain=org.kde.kwrite.desktop;org.kde.kate.desktop;
text/markdown=org.kde.kwrite.desktop;org.kde.kate.desktop;
application/zip=org.kde.ark.desktop;ark.desktop;
application/x-7z-compressed=org.kde.ark.desktop;ark.desktop;
application/x-rar=org.kde.ark.desktop;ark.desktop;
application/x-tar=org.kde.ark.desktop;ark.desktop;
application/x-ms-dos-executable=kyth-exe-handler.desktop
application/x-msdos-program=kyth-exe-handler.desktop
application/x-dosexec=kyth-exe-handler.desktop
application/x-msi=kyth-exe-handler.desktop
application/x-msdownload=kyth-exe-handler.desktop
application/vnd.microsoft.portable-executable=kyth-exe-handler.desktop
x-scheme-handler/http=com.brave.Browser.desktop;chromium-browser.desktop
x-scheme-handler/https=com.brave.Browser.desktop;chromium-browser.desktop
x-scheme-handler/mailto=com.getmailspring.Mailspring.desktop
inode/directory=org.kde.dolphin.desktop
MIMEAPPSEOF

# Rebuild the MIME/desktop database so KDE picks up the new handler immediately.
update-desktop-database /usr/share/applications/ 2>/dev/null || true

# ── Right-click "New Document" templates for Dolphin ─────────────────────────
# Any file placed in ~/Templates appears in Dolphin's right-click → Create New
# → Document menu — the same behaviour as Windows Explorer's "New" submenu.
# Seeding /etc/skel ensures every new user gets the templates on first login.
mkdir -p /etc/skel/Templates
printf ''                                          > "/etc/skel/Templates/Plain Text.txt"
printf '# Title\n\n'                               > "/etc/skel/Templates/Markdown.md"
printf '#!/usr/bin/env bash\nset -euo pipefail\n\n' > "/etc/skel/Templates/Shell Script.sh"
printf '#!/usr/bin/env python3\n\n\ndef main():\n    pass\n\n\nif __name__ == "__main__":\n    main()\n' \
                                                   > "/etc/skel/Templates/Python Script.py"
chmod +x /etc/skel/Templates/"Shell Script.sh"
chmod +x /etc/skel/Templates/"Python Script.py"

install -m 0755 /ctx/kyth-rclone-update /usr/bin/kyth-rclone-update
install -m 0755 /ctx/kyth-session-snapshot /usr/bin/kyth-session-snapshot
install -m 0755 /ctx/kyth-ge-proton-update /usr/bin/kyth-ge-proton-update
install -m 0755 /ctx/kyth-steam-game-export /usr/bin/kyth-steam-game-export
install -m 0644 /ctx/kyth-ge-proton-update.service /usr/lib/systemd/system/kyth-ge-proton-update.service
install -m 0644 /ctx/kyth-ge-proton-update.timer /usr/lib/systemd/system/kyth-ge-proton-update.timer
install -m 0644 /ctx/kyth-flathub-setup.service /usr/lib/systemd/system/kyth-flathub-setup.service
install -m 0644 /ctx/kyth-default-flatpaks.service /usr/lib/systemd/system/kyth-default-flatpaks.service
install -m 0440 /ctx/kyth-bootc-sudo /etc/sudoers.d/kyth-bootc
install -m 0755 /ctx/kyth-hw-setup /usr/bin/kyth-hw-setup
install -m 0644 /ctx/kyth-hw-setup.service /usr/lib/systemd/system/kyth-hw-setup.service
install -m 0644 /ctx/kyth-asus-supergfxd.rules /usr/lib/udev/rules.d/98-kyth-asus-supergfxd.rules

# Autostart on first login — removes itself after running once (like kyth-set-resolution).
mkdir -p /etc/skel/.config/autostart
cat > /etc/skel/.config/autostart/kyth-welcome.desktop <<'WELCOMEEOF'
[Desktop Entry]
Type=Application
Name=KythOS Helper
Exec=/usr/bin/kyth-welcome-launch
X-KDE-autostart-after=panel
Hidden=false
NoDisplay=true
WELCOMEEOF

# ── Bootc kernel arguments ────────────────────────────────────────────────────
# bootc reads kargs.d entries and adds them to the BLS boot entry at install time.
mkdir -p /usr/lib/bootc/kargs.d
cat > /usr/lib/bootc/kargs.d/10-kyth.toml <<'KARGSEOF'
kargs = ["quiet", "rhgb", "splash", "rd.plymouth=1", "plymouth.enable=1", "plymouth.ignore-serial-consoles", "systemd.show_status=false", "rd.systemd.show_status=false", "loglevel=3", "rd.udev.log_level=3", "vt.global_cursor_default=0"]
KARGSEOF

# Existing installs may still have older KythOS boot entries with serial/TTY
# console arguments that make Plymouth fall back to visible boot text. This
# one-shot migration fixes the bootloader entries after the updated image boots;
# the freshly staged deployment gets the clean kargs above at install/update time.
cat > /usr/lib/systemd/system/kyth-boot-splash-kargs.service <<'SPLASHKARGSEOF'
[Unit]
Description=KythOS boot splash kernel argument migration
ConditionPathExists=!/var/lib/kyth/boot-splash-kargs-v2
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'set -e; mkdir -p /var/lib/kyth; if command -v grubby >/dev/null 2>&1; then grubby --update-kernel=ALL --remove-args="console=tty0 console=ttyS0,115200"; grubby --update-kernel=ALL --args="quiet rhgb splash rd.plymouth=1 plymouth.enable=1 plymouth.ignore-serial-consoles systemd.show_status=false rd.systemd.show_status=false loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0"; fi; touch /var/lib/kyth/boot-splash-kargs-v2'

[Install]
WantedBy=multi-user.target
SPLASHKARGSEOF
systemctl enable kyth-boot-splash-kargs.service 2>/dev/null || true

# ── Plymouth boot splash ───────────────────────────────────────────────────────
PLYMOUTH_THEME_DIR=/usr/share/plymouth/themes/kyth
mkdir -p "${PLYMOUTH_THEME_DIR}"
rsvg-convert -w 256 /ctx/branding/kyth-logo-transparent.svg \
    -o "${PLYMOUTH_THEME_DIR}/kyth-logo.png"
install -m 0644 /ctx/plymouth/kyth.plymouth "${PLYMOUTH_THEME_DIR}/"
install -m 0644 /ctx/plymouth/kyth.script   "${PLYMOUTH_THEME_DIR}/"

# Replace the Fedora badge in the bgrt/spinner fallback theme so the ASUS
# firmware logo ("In search of incredible") is followed by the KythOS lockup
# rather than a Fedora logo during early-boot BGRT rendering. Fedora's bgrt
# theme reads its watermark from the shared spinner image directory.
for _spinner_dir in \
    /usr/share/plymouth/themes/spinner \
    /usr/share/plymouth/themes/bgrt \
    /usr/share/plymouth/themes/bgrt-fedora; do
    if [ -d "${_spinner_dir}" ]; then
        rsvg-convert -w 260 /ctx/branding/kyth-boot-badge.svg \
            -o "${_spinner_dir}/watermark.png"
    fi
done
unset _spinner_dir

plymouth-set-default-theme --rebuild-initrd kyth

# bootc installs the initramfs payload stored beside the kernel under
# /usr/lib/modules. Rebuild that exact payload after installing the KythOS
# theme; otherwise a fresh install can inherit Fedora's upstream BGRT splash.
for _kernel_dir in /usr/lib/modules/*; do
    [ -d "${_kernel_dir}" ] || continue
    _kernel_ver=$(basename "${_kernel_dir}")
    TMPDIR=/var/tmp dracut \
        --no-hostonly \
        --compress "zstd -1" \
        --kver "${_kernel_ver}" \
        --force \
        "${_kernel_dir}/initramfs" \
        2> >(grep -Ev 'xattr|fail to copy' >&2)
    lsinitrd "${_kernel_dir}/initramfs" \
        | grep 'usr/share/plymouth/themes/kyth/kyth-logo.png' >/dev/null
done
unset _kernel_dir _kernel_ver

# Existing deployments already have an initramfs in /boot. Repair it once
# after the updated image boots so subsequent reboots use KythOS branding too.
cat > /usr/lib/systemd/system/kyth-boot-splash-initramfs.service <<'SPLASHINITRDEOF'
[Unit]
Description=Refresh KythOS boot splash initramfs
ConditionPathExists=!/var/lib/kyth/boot-splash-initramfs-v1
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'set -e; plymouth-set-default-theme kyth; dracut --regenerate-all --force; mkdir -p /var/lib/kyth; touch /var/lib/kyth/boot-splash-initramfs-v1'

[Install]
WantedBy=multi-user.target
SPLASHINITRDEOF
systemctl enable kyth-boot-splash-initramfs.service 2>/dev/null || true

# First-boot notice: shown once via Plymouth message_callback, then sentinel
# gates it so subsequent boots skip the message.
cat > /usr/lib/systemd/system/kyth-firstboot-notice.service <<'FBOOTEOF'
[Unit]
Description=KythOS first-boot Plymouth notice
After=plymouth-start.service
Before=plymouth-quit.service
DefaultDependencies=no
ConditionPathExists=!/var/lib/kyth/first-boot-done

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'mkdir -p /var/lib/kyth && touch /var/lib/kyth/first-boot-done && plymouth message --text="Setting up KythOS for the first time — this may take a minute…"'

[Install]
WantedBy=sysinit.target
FBOOTEOF
systemctl enable kyth-firstboot-notice.service 2>/dev/null || true

# ── Security Tools menu group ──────────────────────────────────────────────────
# Define a custom "Security Tools" group in the XDG application menu so that
# Kali tools exported via distrobox-export land there instead of "Lost and Found".
# "Security" alone is not a recognized XDG main category, so apps without a main
# category fall through to KDE's catch-all bucket.  X-KythSecurity is our custom
# main category; the .menu merge file teaches KDE what group it belongs to.
mkdir -p /usr/share/desktop-directories
cat > /usr/share/desktop-directories/kyth-security.directory <<'SECDIREF'
[Desktop Entry]
Version=1.0
Type=Directory
Name=Security Tools
Comment=Security and penetration testing tools
Icon=security-high
SECDIREF

mkdir -p /etc/xdg/menus/applications-merged
cat > /etc/xdg/menus/applications-merged/kyth-security.menu <<'SECMENUEOF'
<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
  "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
<Menu>
  <Name>Applications</Name>
  <!-- Explicit layout so Security Tools sorts alphabetically with standard categories.
       Merge files are processed last, so this Layout overrides the default ordering.
       <Merge type="menus"/> at the end catches any non-standard categories. -->
  <Layout>
    <Merge type="files"/>
    <Menuname>AudioVideo</Menuname>
    <Menuname>Development</Menuname>
    <Menuname>Education</Menuname>
    <Menuname>Game</Menuname>
    <Menuname>Graphics</Menuname>
    <Menuname>Internet</Menuname>
    <Menuname>Network</Menuname>
    <Menuname>Office</Menuname>
    <Menuname>Science</Menuname>
    <Menuname>Security Tools</Menuname>
    <Menuname>Settings</Menuname>
    <Menuname>System</Menuname>
    <Menuname>Utility</Menuname>
    <Merge type="menus"/>
  </Layout>
  <Menu>
    <Name>Security Tools</Name>
    <Directory>kyth-security.directory</Directory>
    <Include>
      <Category>X-KythSecurity</Category>
    </Include>
  </Menu>
</Menu>
SECMENUEOF

# ── ujust recipes ─────────────────────────────────────────────────────────────
# Install KythOS-specific ujust recipes so users can run e.g. "ujust rebase kyth:stable".
mkdir -p /usr/share/ublue-os/just
cp /ctx/just/kyth.just /usr/share/ublue-os/just/75-kyth.just
# The upstream justfile only imports up to 60-custom.just; wire in our file.
printf '\nimport? "/usr/share/ublue-os/just/75-kyth.just"\n' >> /usr/share/ublue-os/justfile
systemctl enable kyth-local-bin-migrate.service 2>/dev/null || true
systemctl enable kyth-topgrade-migrate.service 2>/dev/null || true
systemctl enable kyth-duperemove.timer 2>/dev/null || true
systemctl enable kyth-ge-proton-update.timer 2>/dev/null || true
systemctl enable kyth-flathub-setup.service 2>/dev/null || true
systemctl enable kyth-default-flatpaks.service 2>/dev/null || true
systemctl enable kyth-hw-setup.service 2>/dev/null || true

# ── Steam first-run notification ─────────────────────────────────────────────
# Wrap the Steam launcher so that on the very first launch, a passive popup
# appears telling the user setup may take a few minutes.  The flag file is
# written only after the notification attempt completes so a silent failure
# doesn't permanently suppress the message on the next launch attempt.
# To reset: rm ~/.local/share/kyth-steam-initialized
cat > /usr/bin/kyth-steam <<'STEAMEOF'
#!/bin/bash
FLAG="${HOME}/.local/share/kyth-steam-initialized"
if [[ ! -f "${FLAG}" ]]; then
    mkdir -p "$(dirname "${FLAG}")"
    (
        if command -v kdialog &>/dev/null; then
            kdialog --title "KythOS" --passivepopup \
                "Steam is setting up for the first time. This may take a few minutes — please be patient." \
                30
        elif command -v notify-send &>/dev/null; then
            notify-send --urgency=normal --expire-time=30000 \
                "Steam First Start" \
                "Steam is setting up for the first time. This may take a few minutes — please be patient."
        fi
        touch "${FLAG}"
    ) &
fi
exec /usr/bin/steam "$@"
STEAMEOF
chmod +x /usr/bin/kyth-steam

# Override the Steam .desktop Exec line to use the wrapper.
# sysconfig.sh (Layer 3) already wrote a patched copy to /usr/local/share/applications/
# to strip PrefersNonDefaultGPU/X-KDE-RunOnDiscreteGpu. XDG gives /usr/local priority,
# so that copy is what KDE and launchers actually see — patch both to ensure the
# kyth-steam wrapper takes effect regardless of which path wins.
for desktop in \
    /usr/share/applications/steam.desktop \
    /usr/local/share/applications/steam.desktop; do
    if [[ -f "${desktop}" ]]; then
        sed -i 's|^Exec=/usr/bin/steam|Exec=/usr/bin/kyth-steam|g' "${desktop}"
    fi
done

# ── GE-Proton runtime update path ─────────────────────────────────────────────
# The weekly timer installs new GE-Proton to /var/lib/kyth/ge-proton/ (/var is
# writable on an immutable system). Tell Steam to check this path in addition to
# the build-time install in /usr/share/steam/compatibilitytools.d/.
# The directory must exist at first boot — Lutris (and Steam) call os.stat() on
# every path in STEAM_EXTRA_COMPAT_TOOLS_PATHS and crash with FileNotFoundError
# if any are missing, even before the update service has run for the first time.
mkdir -p /var/lib/kyth/ge-proton
echo 'STEAM_EXTRA_COMPAT_TOOLS_PATHS=/var/lib/kyth/ge-proton' > /etc/environment.d/ge-proton.conf
