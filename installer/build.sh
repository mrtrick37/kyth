#!/usr/bin/bash
# Based directly on Bazzite's installer/build.sh
# Ref: https://github.com/ublue-os/bazzite/blob/main/installer/build.sh

set -exo pipefail

SOURCE_TAG=${SOURCE_TAG:?}

# bwrap tries to write /proc/sys/user/max_user_namespaces which is mounted as ro
mount -o remount,rw /proc/sys

# ── KythOS installer binaries ─────────────────────────────────────────────────
install -Dm755 /src/build_files/kyth-installer        /usr/bin/kyth-installer
install -Dm755 /src/build_files/kyth-launch-installer /usr/bin/kyth-launch-installer
install -Dm755 /src/build_files/kyth-partition-install.sh /usr/bin/kyth-partition-install
install -Dm755 /src/build_files/scripts/plymouth-branding-guard.sh \
    /usr/libexec/kyth-plymouth-branding-guard

cat > /usr/share/applications/kyth-install.desktop <<'EOF'
[Desktop Entry]
Name=Install KythOS
Comment=Install KythOS to this computer
Exec=/usr/bin/kyth-launch-installer
Icon=kyth
Terminal=false
Type=Application
Categories=System;
EOF

printf 'KYTH_SOURCE_IMAGE=ghcr.io/mrtrick37/kyth:%s\nKYTH_TARGET_IMAGE=ghcr.io/mrtrick37/kyth:%s\n' \
    "${SOURCE_TAG}" "${SOURCE_TAG}" > /etc/kyth-installer.env

# Install live-only packages in one transaction so dependency solving and
# repository metadata work happen once. Browsers from the installed image are
# intentionally deferred to Flatpak first-boot setup.
dnf install -y \
    chromium \
    dracut-live \
    grub2-efi-x64-cdboot \
    livesys-scripts

# ── Live desktop: installer shortcut + software rendering (via /etc/skel) ────
# The installed image seeds System Hub for a user's first login. The live
# session should open the installer instead and keep the desktop uncluttered.
rm -f \
    /etc/skel/Desktop/kyth-welcome.desktop \
    /etc/skel/Desktop/system-hub.desktop \
    /etc/skel/.config/autostart/kyth-welcome.desktop
mkdir -p /etc/skel/Desktop /etc/skel/.config/autostart
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

# The live user is ephemeral, so do not interrupt Wi-Fi setup with KWallet's
# first-use encryption wizard. Installed users keep the normal encrypted wallet.
cat > /etc/skel/.config/kwalletrc <<'EOF'
[Wallet]
Enabled=false
First Use=false
EOF

# Plasma normally starts the PAM wallet bridge during login. The live account
# has no persistent secrets, so keep that bridge out of its autologin session.
for pam_file in /etc/pam.d/sddm-autologin /usr/lib/pam.d/plasmalogin-autologin; do
    [ -f "${pam_file}" ] && sed -i '/pam_kwallet/d' "${pam_file}"
done
mkdir -p /etc/xdg/autostart /etc/systemd/user
cat > /etc/xdg/autostart/pam_kwallet_init.desktop <<'EOF'
[Desktop Entry]
Type=Application
Hidden=true
EOF
ln -sf /dev/null /etc/systemd/user/plasma-kwallet-pam.service

cat > /etc/skel/.config/autostart/kyth-installer.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Install KythOS
Exec=/usr/bin/kyth-launch-installer
X-KDE-autostart-after=panel
Hidden=false
NoDisplay=true
EOF

mkdir -p /etc/skel/.config/plasma-workspace/env
cat > /etc/skel/.config/plasma-workspace/env/live.sh <<'EOF'
#!/bin/bash
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export MESA_LOADER_DRIVER_OVERRIDE=llvmpipe
export QT_QUICK_BACKEND=software
EOF
chmod +x /etc/skel/.config/plasma-workspace/env/live.sh

# livesys-session-extra: runs after livesys-kde sets up the KDE session
mkdir -p /var/lib/livesys
cat > /var/lib/livesys/livesys-session-extra <<'EOF'
#!/bin/sh
rm -f \
    /home/liveuser/Desktop/liveinst.desktop \
    /home/liveuser/Desktop/kyth-welcome.desktop \
    /home/liveuser/Desktop/system-hub.desktop \
    /home/liveuser/.config/autostart/kyth-welcome.desktop \
    2>/dev/null || true
mkdir -p /home/liveuser/.config
cat > /home/liveuser/.config/kwalletrc <<'WALLETRC'
[Wallet]
Enabled=false
First Use=false
WALLETRC
cat > /home/liveuser/.config/kscreenlockerrc <<'SCREENLOCKEOF'
[Daemon]
Autolock=false
LockOnResume=false
SCREENLOCKEOF
chown liveuser:liveuser \
    /home/liveuser/.config/kwalletrc \
    /home/liveuser/.config/kscreenlockerrc
[ -f /home/liveuser/Desktop/install-kyth.desktop ] && \
    chmod +x /home/liveuser/Desktop/install-kyth.desktop
EOF
chmod +x /var/lib/livesys/livesys-session-extra

# ── dracut-live + initramfs ───────────────────────────────────────────────────
kernel=$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
    | grep -v cachyos | sort -V | tail -n 1)
/usr/libexec/kyth-plymouth-branding-guard
plymouth-set-default-theme kyth
mkdir -p /etc/plymouth /usr/share/plymouth
cat > /etc/plymouth/plymouthd.conf <<'EOF'
[Daemon]
Theme=kyth
ShowDelay=0
EOF
install -m 0644 /etc/plymouth/plymouthd.conf /usr/share/plymouth/plymouthd.defaults
DRACUT_NO_XATTR=1 dracut -v --force --zstd --no-hostonly \
    --add "kyth-plymouth plymouth dmsquash-live dmsquash-live-autooverlay" \
    --include /etc/plymouth/plymouthd.conf /etc/plymouth/plymouthd.conf \
    --include /usr/share/plymouth/plymouthd.defaults /usr/share/plymouth/plymouthd.defaults \
    "/usr/lib/modules/${kernel}/initramfs.img" "${kernel}"

initrd_listing="$(mktemp)"
if command -v lsinitrd >/dev/null 2>&1; then
    lsinitrd "/usr/lib/modules/${kernel}/initramfs.img" > "${initrd_listing}"
    grep -q 'usr/share/plymouth/themes/kyth/kyth.plymouth' "${initrd_listing}" || {
        echo "ERROR: live initramfs does not contain KythOS Plymouth theme" >&2
        exit 1
    }
    grep -q 'usr/share/plymouth/themes/default.plymouth' "${initrd_listing}" || {
        echo "ERROR: live initramfs does not force the KythOS Plymouth default theme" >&2
        exit 1
    }
    lsinitrd -f /etc/plymouth/plymouthd.conf "/usr/lib/modules/${kernel}/initramfs.img" | grep -q '^Theme=kyth$' || {
        echo "ERROR: live initramfs Plymouth daemon config does not force Theme=kyth" >&2
        exit 1
    }
    lsinitrd -f /usr/share/plymouth/plymouthd.defaults "/usr/lib/modules/${kernel}/initramfs.img" | grep -q '^Theme=kyth$' || {
        echo "ERROR: live initramfs Plymouth defaults do not force Theme=kyth" >&2
        exit 1
    }
    if grep -Ei 'usr/share/plymouth/themes/(bgrt-fedora|bgrt|spinner)/.*(fedora|watermark|logo)' "${initrd_listing}" >&2; then
        echo "ERROR: Fedora Plymouth fallback branding leaked into live initramfs" >&2
        exit 1
    fi
fi
rm -f "${initrd_listing}"

# ── livesys-scripts ───────────────────────────────────────────────────────────
sed -i 's/^livesys_session=.*/livesys_session="kde"/' /etc/sysconfig/livesys
systemctl enable livesys.service livesys-late.service

# ── Log straight into the live desktop ────────────────────────────────────────
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/20-kyth-live-autologin.conf <<'EOF'
[Autologin]
User=liveuser
Session=plasmax11.desktop
Relogin=false
EOF

# ── Disable services inappropriate for live ───────────────────────────────────
for unit in \
    ostree-remount.service \
    rpm-ostree-countme.service rpm-ostree-countme.timer \
    bootc-fetch-apply-updates.service bootc-fetch-apply-updates.timer \
    systemd-firstboot.service systemd-oomd.service \
    kyth-default-flatpaks.service kyth-flathub-setup.service \
    kyth-ge-proton-update.service kyth-ge-proton-update.timer \
    kyth-hw-setup.service kyth-local-bin-migrate.service \
    kyth-topgrade-migrate.service kyth-duperemove.service kyth-duperemove.timer \
    kyth-enroll-mok.service plasmalogin.service akmods.service \
    plasma-setup.service com.system76.Scheduler.service \
    scxd.service ananicy-cpp.service \
    fwupd.service fwupd-refresh.service fwupd-refresh.timer; do
    systemctl disable "${unit}" 2>/dev/null || true
    ln -sf /dev/null "/etc/systemd/system/${unit}"
done

# ── Larger /var/tmp for bootc install to-disk ─────────────────────────────────
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

# ── Passwordless sudo for liveuser ────────────────────────────────────────────
install -Dm440 /dev/stdin /etc/sudoers.d/liveuser-live <<'EOF'
liveuser ALL=(ALL) NOPASSWD: ALL
EOF

# ── Timezone + machine-id (same as Bazzite) ───────────────────────────────────
rm -f /etc/localtime
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
echo "uninitialized" > /etc/machine-id

# ── EFI binaries for ISO boot (exactly as Bazzite does it) ───────────────────
mkdir -p /boot/efi
cp -av /usr/lib/efi/*/*/EFI /boot/efi/
cp -v /boot/efi/EFI/fedora/grubx64.efi /boot/efi/EFI/BOOT/fbx64.efi || true

# ── iso.yaml for the GRUB menu ────────────────────────────────────────────────
mkdir -p /usr/lib/bootc-image-builder
cp /src/installer/iso.yaml /usr/lib/bootc-image-builder/iso.yaml

dnf clean all
