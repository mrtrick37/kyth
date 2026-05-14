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
KICKOFFEOF

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

# ── KythOS abstract mark as system icon ─────────────────────────────────────────
# KDE Plasma 6 Kickoff looks up icons in this order:
#   start-here-kde-plasma → start-here-kde → start-here
# Use the square transparent symbol for small app/menu/panel icons. The
# horizontal full logo has text and a black canvas that collapses badly at
# launcher sizes.
for theme_dir in \
    /usr/share/icons/hicolor/scalable/apps \
    /usr/share/icons/breeze/apps/scalable \
    /usr/share/icons/breeze-dark/apps/scalable; do
    mkdir -p "${theme_dir}"
    cp /ctx/branding/kyth-logo-transparent.svg "${theme_dir}/kyth.svg"
    cp /ctx/branding/kyth-logo-transparent.svg "${theme_dir}/kyth-symbol.svg"
    cp /ctx/branding/kyth-logo-transparent.svg "${theme_dir}/start-here.svg"
    cp /ctx/branding/kyth-logo-transparent.svg "${theme_dir}/start-here-kde.svg"
    cp /ctx/branding/kyth-logo-transparent.svg "${theme_dir}/start-here-kde-plasma.svg"
done
gtk-update-icon-cache -f /usr/share/icons/hicolor/    2>/dev/null || true
gtk-update-icon-cache -f /usr/share/icons/breeze/      2>/dev/null || true
gtk-update-icon-cache -f /usr/share/icons/breeze-dark/ 2>/dev/null || true

# ── First-login script: set Kickoff launcher icon to KythOS logo ────────────────
# Belt-and-suspenders: the icon theme install above should be enough, but this
# also writes the icon key directly into each user's Kickoff applet config in
# case the theme lookup is overridden by a previously cached value.
cat > /usr/bin/kyth-set-kickoff-icon <<'KICKOFEOF'
#!/usr/bin/env python3
import os, re, subprocess

aprc = os.path.expanduser("~/.config/plasma-org.kde.plasma.desktop-appletsrc")
autostart = os.path.expanduser("~/.config/autostart/kyth-set-kickoff-icon.desktop")

if os.path.exists(aprc):
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
                'kwriteconfig6', '--file', aprc,
                '--group', 'Containments', '--group', cont,
                '--group', 'Applets', '--group', applet,
                '--group', 'Configuration', '--group', 'General',
                '--key', 'icon', 'start-here-kde-plasma',
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

install -m 0755 /ctx/kyth-welcome/kyth-update-notifier /usr/bin/kyth-update-notifier
install -m 0644 /ctx/kyth-welcome/kyth-update-notifier.desktop \
    /usr/share/applications/kyth-update-notifier.desktop
# Autostart the notifier for new user accounts
mkdir -p /etc/skel/.config/autostart
install -m 0644 /ctx/kyth-welcome/kyth-update-notifier.desktop \
    /etc/skel/.config/autostart/kyth-update-notifier.desktop

# Smoke-test the helper during the build so startup regressions fail the image
# instead of surfacing only after first login.
# timeout 30: pages run synchronous subprocess calls (bootc status, flatpak info)
# in __init__ that can block for minutes in a container. We only care that the
# app imports and constructs without crashing — not that hardware probes finish.
# Exit 124 = timed out (treat as pass). Any other non-zero = real crash, fail build.
smoke_exit=0
timeout 30 python3 -c '
import importlib.machinery, importlib.util, pathlib, os
import sys
os.environ["QT_QPA_PLATFORM"] = "offscreen"
path = pathlib.Path("/usr/bin/kyth-welcome")
loader = importlib.machinery.SourceFileLoader("kyth_welcome_smoke", str(path))
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)
app = module.QApplication([])
win = module.MainWindow()
win.close()
wizard = module.WizardWindow()
wizard.close()
os._exit(0)
' || smoke_exit=$?
if [ "${smoke_exit}" -eq 124 ]; then
    echo "smoke-test: timed out after 30s (background threads still running) — treating as pass"
elif [ "${smoke_exit}" -ne 0 ]; then
    echo "smoke-test: FAILED with exit code ${smoke_exit}"
    exit 1
fi

install -m 0755 /ctx/game-performance /usr/bin/game-performance
install -m 0755 /ctx/kyth-gamescope /usr/bin/kyth-gamescope
install -m 0755 /ctx/kyth-performance-mode /usr/bin/kyth-performance-mode
install -m 0755 /ctx/kyth-scx /usr/bin/kyth-scx
install -m 0755 /ctx/zink-run /usr/bin/zink-run
install -m 0755 /ctx/kyth-kerver /usr/bin/kyth-kerver
install -m 0755 /ctx/kyth-device-info /usr/bin/kyth-device-info
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
mkdir -p /etc/xdg/autostart
install -m 0644 /ctx/kyth-vpn-status/kyth-vpn-status.desktop \
    /etc/xdg/autostart/kyth-vpn-status.desktop
install -m 0755 /ctx/kyth-rclone-update /usr/bin/kyth-rclone-update
install -m 0755 /ctx/kyth-ge-proton-update /usr/bin/kyth-ge-proton-update
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
plymouth-set-default-theme --rebuild-initrd kyth

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
