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

printf 'KYTH_SOURCE_IMAGE=ghcr.io/mrtrick37/kyth:%s\nKYTH_TARGET_IMAGE=ghcr.io/mrtrick37/kyth:%s\n' \
    "${SOURCE_TAG}" "${SOURCE_TAG}" > /etc/kyth-installer.env

# The graphical installer serves its UI locally and opens it in Chromium.
# Browsers from the installed image are intentionally deferred to Flatpak
# first-boot setup, so the live payload must carry its own browser.
dnf install -y chromium

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
[ -f /home/liveuser/Desktop/install-kyth.desktop ] && \
    chmod +x /home/liveuser/Desktop/install-kyth.desktop
EOF
chmod +x /var/lib/livesys/livesys-session-extra

# ── dracut-live + initramfs ───────────────────────────────────────────────────
dnf install -y dracut-live
kernel=$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
    | grep -v cachyos | sort -V | tail -n 1)
DRACUT_NO_XATTR=1 dracut -v --force --zstd --no-hostonly \
    --add "dmsquash-live dmsquash-live-autooverlay" \
    "/usr/lib/modules/${kernel}/initramfs.img" "${kernel}"

# ── livesys-scripts ───────────────────────────────────────────────────────────
dnf install -y livesys-scripts
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
dnf install -y grub2-efi-x64-cdboot
mkdir -p /boot/efi
cp -av /usr/lib/efi/*/*/EFI /boot/efi/
cp -v /boot/efi/EFI/fedora/grubx64.efi /boot/efi/EFI/BOOT/fbx64.efi || true

# ── iso.yaml for the GRUB menu ────────────────────────────────────────────────
mkdir -p /usr/lib/bootc-image-builder
cp /src/installer/iso.yaml /usr/lib/bootc-image-builder/iso.yaml

dnf clean all
