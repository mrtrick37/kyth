#!/bin/bash

set -euo pipefail

# systemd-remount-fs tries to remount the root filesystem, which is immutable
# on bootc/ostree systems and always fails with exit status 32. Mask it.
systemctl mask systemd-remount-fs.service

# Re-enforce display-manager and default target symlinks here (layer 6).
# The dnf5 upgrade in layer 3 can re-apply systemd presets and reset the
# display-manager alias.  Use explicit symlinks — systemctl enable is a
# no-op in a container build (no running systemd bus, silently swallowed
# by 2>/dev/null || true).
ln -sf /usr/lib/systemd/system/sddm.service \
	/etc/systemd/system/display-manager.service
mkdir -p /etc/systemd/system/graphical.target.wants
ln -sf /etc/systemd/system/display-manager.service \
	/etc/systemd/system/graphical.target.wants/display-manager.service
ln -sf /usr/lib/systemd/system/graphical.target \
	/etc/systemd/system/default.target


systemctl enable rtkit-daemon.service 2>/dev/null || true
systemctl enable input-remapper.service 2>/dev/null || true
# joycond: pairs left + right Joy-Cons into a single virtual controller.
# Only active when Joy-Con hardware is detected; no-op on other systems.
systemctl enable joycond.service 2>/dev/null || true
# Periodic SSD TRIM — reclaims blocks marked free by the filesystem. Safe on
# all modern SSDs and NVMe drives; the timer runs weekly by default.
systemctl enable fstrim.timer 2>/dev/null || true
# Distribute hardware IRQs across all CPU cores. Without this all IRQs land on
# cpu0, causing it to spike during heavy I/O or network activity mid-game.
systemctl enable irqbalance.service 2>/dev/null || true
# Fedora/libvirt can expose either legacy libvirtd or modular virtqemud units.
# Enable whichever socket exists so image builds stay portable across releases.
if systemctl list-unit-files --type=socket --no-legend 2>/dev/null | grep -q '^libvirtd\.socket'; then
	systemctl enable libvirtd.socket 2>/dev/null || true
elif systemctl list-unit-files --type=socket --no-legend 2>/dev/null | grep -q '^virtqemud\.socket'; then
	systemctl enable virtqemud.socket 2>/dev/null || true
else
	echo "libvirt socket unit not found; skipping enable."
fi
systemctl enable docker.socket 2>/dev/null || true
systemctl enable fwupd 2>/dev/null || true

# ── Automatic updates: use bootc, not rpm-ostree ──────────────────────────────
# rpm-ostreed-automatic conflicts with bootc over the sysroot lock.
# Disable it entirely — bootc-fetch-apply-updates.timer is also disabled because
# its default behaviour (bootc upgrade --apply) reboots the system automatically
# whenever a new image is available, causing unexpected reboots ~1h after boot.
# Users should update manually: sudo bootc upgrade && sudo systemctl reboot
systemctl disable rpm-ostreed-automatic.timer rpm-ostreed-automatic.service 2>/dev/null || true
systemctl disable bootc-fetch-apply-updates.timer bootc-fetch-apply-updates.service 2>/dev/null || true
# Keep Fedora's standalone CountMe timer enabled on installed atomic systems.
# bootc upgrades do not normally fetch RPM repository metadata, so DNF's
# countme=True setting alone is not enough to report active installed systems.
if systemctl list-unit-files --type=timer --no-legend 2>/dev/null | grep -q '^rpm-ostree-countme\.timer'; then
	systemctl enable rpm-ostree-countme.timer 2>/dev/null || true
fi
# Mask packagekitd so Plasma Discover cannot query it for RPM-level updates.
# plasma-discover-rpm-ostree is removed in packages.sh; this masks the generic
# DNF/PackageKit backend as a belt-and-suspenders measure. Discover's Flatpak
# backend does not use PackageKit and is unaffected.
systemctl mask packagekit.service 2>/dev/null || true

# ── Boot-time noise reduction ─────────────────────────────────────────────────
# NetworkManager-wait-online blocks network-online.target (and thus multi-user
# and graphical targets) until the network is fully up — adds ~5s on every
# boot. Desktop systems don't need the network ready before the login screen;
# services that genuinely need network declare their own After=network-online.
systemctl disable NetworkManager-wait-online.service 2>/dev/null || true

# flatpak-system-update runs on every boot and takes 20+ seconds fetching
# Flatpak metadata. Flatpaks are updated explicitly via topgrade or ujust.
systemctl disable flatpak-system-update.service flatpak-system-update.timer 2>/dev/null || true

# fedora-atomic-desktop-appstream-cache-refresh regenerates the AppStream cache
# on every boot (~4s). Runs on-demand when the software center needs it.
systemctl disable fedora-atomic-desktop-appstream-cache-refresh.service 2>/dev/null || true

# serial-getty@ttyS0 waits 45s for a serial device that doesn't exist on this
# hardware before timing out. Mask it so the timeout doesn't hold up boot.
systemctl mask serial-getty@ttyS0.service 2>/dev/null || true

# Apply the same account repair in the image now so the deployed /etc starts
# correct, then keep the enabled service as a boot-time guardrail.
/usr/libexec/kyth-fix-system-accounts || true

# useradd only reads /etc/group, but Fedora system groups live in /usr/lib/group.
# Copy any missing groups into /etc/group; create with groupadd if absent entirely.
for grp in users video audio gamemode docker disk kvm tty clock kmem input render lp utmp plugdev dbus sddm polkitd; do
	if ! grep -q "^${grp}:" /etc/group; then
		if getent group "$grp" >/dev/null 2>&1; then
			getent group "$grp" >>/etc/group
		else
			groupadd "$grp"
		fi
	fi
done
