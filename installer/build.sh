#!/usr/bin/bash
# installer/build.sh — builds the KythOS live ISO image layer on top of the
# base KythOS image. Modelled on Bazzite's installer/build.sh.
#
# Requires SYS_ADMIN capability (dracut + /proc/sys remount):
#   sudo podman build --cap-add SYS_ADMIN --security-opt label=disable ...

set -exo pipefail

SOURCE_TAG=${SOURCE_TAG:?}

# bwrap / dracut write /proc/sys; remount rw so they don't fail
mount -o remount,rw /proc/sys

# ── Packages ──────────────────────────────────────────────────────────────────
dnf5 install -y \
    dracut-live \
    livesys-scripts \
    grub2-efi-x64-cdboot \
    grub2-efi-x64 \
    shim-x64

# ── Configure livesys for KDE ─────────────────────────────────────────────────
sed -i 's/^livesys_session=.*/livesys_session="kde"/' /etc/sysconfig/livesys
systemctl enable livesys.service livesys-late.service

# ── Rebuild initramfs with live-boot modules ──────────────────────────────────
KVER=$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
    | grep -v cachyos | sort -V | tail -n 1)
test -n "${KVER}" || { echo "ERROR: no Fedora kernel found" >&2; exit 1; }
test -s "/usr/lib/modules/${KVER}/vmlinuz" \
    || { echo "ERROR: vmlinuz missing for ${KVER}" >&2; exit 1; }

echo "==> Building live initramfs for ${KVER}"
DRACUT_NO_XATTR=1 dracut \
    --verbose \
    --force \
    --no-hostonly \
    --zstd \
    --add "dmsquash-live dmsquash-live-autooverlay plymouth" \
    --add-drivers "overlay squashfs iso9660 loop" \
    "/usr/lib/modules/${KVER}/initramfs.img" \
    "${KVER}"

# ── KythOS installer binaries ─────────────────────────────────────────────────
install -Dm755 /src/build_files/kyth-installer        /usr/bin/kyth-installer
install -Dm755 /src/build_files/kyth-launch-installer /usr/bin/kyth-launch-installer
install -Dm755 /src/build_files/kyth-partition-install.sh /usr/bin/kyth-partition-install

# Source image the installer pulls at install time
printf 'KYTH_SOURCE_IMAGE=ghcr.io/mrtrick37/kyth:%s\nKYTH_TARGET_IMAGE=ghcr.io/mrtrick37/kyth:%s\n' \
    "${SOURCE_TAG}" "${SOURCE_TAG}" > /etc/kyth-installer.env

# ── Passwordless sudo for liveuser ────────────────────────────────────────────
# livesys-main adds liveuser to wheel at boot; we need NOPASSWD for the installer
install -Dm440 /dev/stdin /etc/sudoers.d/liveuser-live <<'EOF'
liveuser ALL=(ALL) NOPASSWD: ALL
EOF

# ── Installer shortcut on the live desktop (via /etc/skel) ───────────────────
# livesys useradd copies /etc/skel → /home/liveuser at boot
mkdir -p /etc/skel/Desktop
cat > /etc/skel/Desktop/install-kyth.desktop <<'EOF'
[Desktop Entry]
Name=Install KythOS
Comment=Install KythOS to this computer
Exec=/usr/bin/kyth-launch-installer
Icon=kyth
Terminal=false
Type=Application
Categories=System;
EOF
chmod +x /etc/skel/Desktop/install-kyth.desktop

# Software rendering hook — live session boots with nomodeset so hardware GL
# is unavailable; llvmpipe ensures Plasma and Chromium both get a working renderer
mkdir -p /etc/skel/.config/plasma-workspace/env
cat > /etc/skel/.config/plasma-workspace/env/live.sh <<'EOF'
#!/bin/bash
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export MESA_LOADER_DRIVER_OVERRIDE=llvmpipe
export QT_QUICK_BACKEND=software
EOF
chmod +x /etc/skel/.config/plasma-workspace/env/live.sh

# ── livesys-session-extra: runs after livesys-kde, before chown ───────────────
# Override the Anaconda-centric defaults livesys-kde sets up
mkdir -p /var/lib/livesys
cat > /var/lib/livesys/livesys-session-extra <<'EOF'
#!/bin/sh
# Remove liveinst.desktop if Anaconda isn't present (it isn't in KythOS)
rm -f /home/liveuser/Desktop/liveinst.desktop \
      /home/liveuser/.local/share/applications/liveinst.desktop 2>/dev/null || true

# Installer shortcut on Desktop (copied from /etc/skel at useradd time, but
# livesys-kde may also recreate Desktop — make sure the shortcut is trusted)
if [ -f /home/liveuser/Desktop/install-kyth.desktop ]; then
    chmod +x /home/liveuser/Desktop/install-kyth.desktop
fi

# Kickoff favourites
mkdir -p /home/liveuser/.config
cat > /home/liveuser/.config/kickoffrc <<'KICKOFFEOF'
[Favorites]
FavoriteURLs=/usr/share/applications/kyth-welcome.desktop,/usr/share/applications/kyth-install.desktop,/usr/share/applications/code.desktop,/usr/share/applications/chromium-browser.desktop,/usr/share/applications/org.kde.dolphin.desktop,/usr/share/applications/systemsettings.desktop,/usr/share/applications/org.kde.konsole.desktop

[General]
highlightNewlyInstalledApps=false
KICKOFFEOF

# Disable KWallet
cat > /home/liveuser/.config/kwalletrc <<'KWALLETEOF'
[Wallet]
Enabled=false
First Use=false
KWALLETEOF

# Disable compositing for live session (no GPU)
cat > /home/liveuser/.config/kwinrc <<'KWINEOF'
[Compositing]
Enabled=false
KWINEOF

# Disable Plasma Welcome
cat > /home/liveuser/.config/plasma-welcomerc <<'WELCOMEEOF'
[General]
LastSeenVersion=99.0
ShowUpdatePage=false
WELCOMEEOF
EOF
chmod +x /var/lib/livesys/livesys-session-extra

# System-level kwallet disable (for apps that don't respect the user config)
mkdir -p /etc/xdg
cat > /etc/xdg/kwalletrc <<'EOF'
[Wallet]
Enabled=false
First Use=false
EOF

# ── Install application desktop files ────────────────────────────────────────
install -Dm644 /dev/stdin /usr/share/applications/kyth-install.desktop <<'EOF'
[Desktop Entry]
Name=Install KythOS
Comment=Install KythOS to this computer
Exec=/usr/bin/kyth-launch-installer
Icon=kyth
Terminal=false
Type=Application
Categories=System;
EOF

# ── Disable services inappropriate for a live session ────────────────────────
for unit in \
    ostree-remount.service \
    rpm-ostree-countme.service \
    rpm-ostree-countme.timer \
    bootc-fetch-apply-updates.service \
    bootc-fetch-apply-updates.timer \
    systemd-firstboot.service \
    systemd-oomd.service \
    kyth-default-flatpaks.service \
    kyth-flathub-setup.service \
    kyth-ge-proton-update.service \
    kyth-ge-proton-update.timer \
    kyth-hw-setup.service \
    kyth-local-bin-migrate.service \
    kyth-topgrade-migrate.service \
    kyth-duperemove.service \
    kyth-duperemove.timer \
    kyth-enroll-mok.service \
    kyth-first-boot-message.service \
    kyth-firstboot-notice.service \
    kyth-selinux-relabel-home.service \
    plasmalogin.service \
    akmods.service \
    akmods-keygen@akmods-keygen.service \
    plasma-setup.service \
    com.system76.Scheduler.service \
    input-remapper.service \
    docker.service docker.socket \
    libvirtd.socket virtqemud.socket \
    scxd.service ananicy-cpp.service \
    fwupd.service fwupd-refresh.service fwupd-refresh.timer \
    kdump.service sssd.service accounts-daemon.service; do
    systemctl disable "${unit}" 2>/dev/null || true
    ln -sf /dev/null "/etc/systemd/system/${unit}" 2>/dev/null || true
done

# ── Larger /var/tmp for bootc install to-disk ─────────────────────────────────
# bootc pulls OCI layers into /var/tmp; the default tmpfs is too small
rm -rf /var/tmp
mkdir /var/tmp
cat > /etc/systemd/system/var-tmp.mount <<'EOF'
[Unit]
Description=Larger tmpfs for /var/tmp on live system

[Mount]
What=tmpfs
Where=/var/tmp
Type=tmpfs
Options=size=50%,nr_inodes=1m

[Install]
WantedBy=local-fs.target
EOF
systemctl enable var-tmp.mount

# ── EFI files for ISO boot ────────────────────────────────────────────────────
# bootc-image-builder / build-live-iso.sh expects EFI binaries under /boot/efi
mkdir -p /boot/efi
for efi_src in \
    /usr/lib/efi \
    /usr/share/efi/x86_64 \
    /usr/share/grub; do
    if [ -d "${efi_src}" ]; then
        find "${efi_src}" -name 'EFI' -type d \
            | xargs -r -I{} cp -av {}/ /boot/efi/EFI/ 2>/dev/null || true
    fi
done
# Fallback: grub2-efi-x64-cdboot installs to /usr/lib/grub/x86_64-efi-signed
find /usr/lib/grub /usr/share/grub2-efi-x64 \
    \( -name 'grubx64.efi' -o -name 'gcdx64.efi' \) 2>/dev/null \
    | head -1 | xargs -r -I{} install -Dm644 {} /boot/efi/EFI/fedora/grubx64.efi

find /usr/share/shim /usr/lib/shim /usr/lib/efi/shim \
    -name 'shimx64.efi' 2>/dev/null | head -1 \
    | xargs -r -I{} install -Dm644 {} /boot/efi/EFI/BOOT/BOOTX64.EFI

find /usr/share/shim /usr/lib/shim /usr/lib/efi/shim \
    -name 'mmx64.efi' 2>/dev/null | head -1 \
    | xargs -r -I{} install -Dm644 {} /boot/efi/EFI/BOOT/mmx64.efi

echo "==> EFI layout:"
find /boot/efi -type f | sort

# ── GRUB ISO config ───────────────────────────────────────────────────────────
mkdir -p /usr/lib/bootc-image-builder
cp /src/installer/iso.yaml /usr/lib/bootc-image-builder/iso.yaml

# ── Misc live session setup ───────────────────────────────────────────────────
# Volatile machine-id — systemd generates a fresh one on every boot
echo "uninitialized" > /etc/machine-id

# zram swap — installer pulls large OCI images; avoid OOM kills under pressure
cat > /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = min(ram*2, 16384)
compression-algorithm = zstd
EOF

# WiFi power-save off — helps connect during install
mkdir -p /etc/NetworkManager/conf.d
printf '[connection]\nwifi.powersave = 2\n' \
    > /etc/NetworkManager/conf.d/wifi-powersave-off.conf

# BFQ can deadlock when reading squashfs + writing btrfs simultaneously on VirtIO
mkdir -p /etc/udev/rules.d
printf 'ACTION=="add|change", KERNEL=="vd[a-z]*", ATTR{queue/scheduler}="mq-deadline"\n' \
    > /etc/udev/rules.d/61-live-ioschedulers.rules

# SELinux: enforcing=0 in kernel cmdline handles this, but belt-and-suspenders
sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true

# Suppress drkonqi crash reporter in live session
printf '[drkonqi]\nEnabled=false\n' > /etc/xdg/drkonqirc

# ── Clean up ──────────────────────────────────────────────────────────────────
dnf5 clean all
