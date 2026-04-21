#!/bin/bash

set -euo pipefail

# ── Kernel sysctl parameters ──────────────────────────────────────────────────
mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-kyth.conf <<'SYSCTLEOF'
# Memory
# swappiness=180: with zram present the kernel should aggressively swap to the
# fast compressed device rather than drop clean pages. The Fedora zram-generator
# project, CachyOS, and Bazzite all recommend 180 for zram systems. The old value
# of 10 caused the kernel to almost never use the zram swap it had set up,
# defeating its purpose and increasing OOM frequency under gaming load.
vm.swappiness = 180
# Keep a larger free-memory reserve so reclaim starts earlier and avoids sudden
# multi-second stall spikes during shader compilation or map loads.
vm.watermark_scale_factor = 125
vm.compaction_proactiveness = 0
# Absolute dirty limits instead of ratios. At 10% ratio a 32 GB machine allows
# 3.2 GB of dirty pages before writeback starts — too much buffering, causes
# visible stutter when the flush finally hits. 256 MB / 64 MB matches
# Bazzite/Nobara and keeps writeback incremental throughout gameplay.
vm.dirty_bytes = 268435456
vm.dirty_background_bytes = 67108864
vm.page_lock_unfairness = 1
# Disable swap read-ahead — on SSDs random I/O is fast; prefetching neighbours
# wastes bandwidth and causes micro-stutter under memory pressure
vm.page-cluster = 0
# Disable watermark boost — prevents burst memory reclaim spikes that cause stutter
vm.watermark_boost_factor = 0
# Reduce VFS cache reclaim aggressiveness — keeps game asset dentries/inodes
# in cache longer (default 100; 50 = half as eager to evict)
vm.vfs_cache_pressure = 50
# Raise memory map limit for games with large numbers of mappings (Star Citizen, etc.)
# 16M is still very high for gaming workloads while avoiding near-INT_MAX values.
vm.max_map_count = 16777216

# Writeback timing — flush dirty pages after 5 s instead of the kernel default
# 30 s. Paired with the absolute dirty_bytes limits above this keeps write bursts
# short and predictable during shader compilation / asset loading.
vm.dirty_expire_centisecs = 500
vm.dirty_writeback_centisecs = 500

# Network — activate BBRv3 (built into CachyOS kernel)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Network socket buffers — raise caps for high-throughput workloads and gaming
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
# TCP Fast Open — reduce connection latency for repeat destinations
net.ipv4.tcp_fastopen = 3

# inotify — raise watch/instance limits for game clients and Electron launchers
# (EA App, Battle.net, etc. watch large directory trees and hit the 8192 default)
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 1024

# Disable NMI watchdog — reduces interrupt overhead on gaming desktops
kernel.nmi_watchdog = 0

# Scheduler
kernel.sched_autogroup_enabled = 1

# Disable split-lock mitigation — some older/ported games use split-lock ops
kernel.split_lock_mitigate = 0

# MTU probing — detect and recover from MTU black holes that can cause online
# game connections to stall silently on some ISPs and VPN paths with BBR.
net.ipv4.tcp_mtu_probing = 1

# Allow unprivileged access to CPU perf counters.
# Fedora defaults to 2 (kernel-only). Setting 1 lets MangoHud report accurate
# CPU frame times, enables GameMode's SCHED_FIFO eligibility checks, and
# allows sysprof/perf without root. Setting 0 would expose raw kernel addresses;
# 1 is the safe middle ground used by most gaming-focused distros.
kernel.perf_event_paranoid = 1

# Kill the task that triggered OOM rather than hunting for the "best victim"
# via a costly process-tree scan. Eliminates multi-second stutter spikes when
# RAM fills up during shader compilation while a game is running.
vm.oom_kill_allocating_task = 1
SYSCTLEOF

# Load tcp_bbr module at boot so the BBRv3 sysctl takes effect
echo 'tcp_bbr' > /etc/modules-load.d/bbr.conf

# ── Locale defaults ──────────────────────────────────────────────────────────
# Force a 12-hour AM/PM clock by default on installed systems.
# LANG keeps the desktop in US English; LC_TIME specifically controls date/time
# formatting for Plasma, Qt, and libc-aware apps.
cat > /etc/locale.conf <<'LOCALEEOF'
LANG=en_US.UTF-8
LC_TIME=en_US.UTF-8
LOCALEEOF

# ── Transparent Huge Pages → madvise ─────────────────────────────────────────
# 'always' (kernel default) forces THP on all allocations and causes stutter.
# 'madvise' lets apps that benefit (e.g. JVMs, some game engines) opt in.
mkdir -p /etc/tmpfiles.d
cat > /etc/tmpfiles.d/kyth-thp.conf <<'THPEOF'
w! /sys/kernel/mm/transparent_hugepage/enabled - - - - madvise
w! /sys/kernel/mm/transparent_hugepage/defrag  - - - - defer+madvise
THPEOF

# ── NVIDIA kernel module options ─────────────────────────────────────────────
# nvidia-drm.modeset=1  — required for Wayland/SDDM to use the NVIDIA KMS driver
#   instead of falling back to fbdev; without it KDE Plasma on Wayland will not
#   start on NVIDIA hardware.
# NVreg_PreserveVideoMemoryAllocations=1 — keeps VRAM contents across suspend/
#   resume cycles, preventing a black screen after wake on NVIDIA systems.
# nouveau is blacklisted: it conflicts with the proprietary driver and must not
#   load.  On AMD/Intel systems nouveau is never triggered anyway (no NVIDIA
#   hardware), so the blacklist is harmless.
cat > /etc/modprobe.d/nvidia-kyth.conf <<'NVEOF'
options nvidia-drm modeset=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
blacklist nouveau
options nouveau modeset=0
NVEOF

# ── NTSYNC ────────────────────────────────────────────────────────────────────
# CachyOS kernel ships the ntsync module. The udev rule gives the 'users' group
# access to /dev/ntsync so Wine/Proton can use NT synchronization primitives
# (faster and lower-latency than esync/fsync for Windows game compatibility).
echo 'KERNEL=="ntsync", GROUP="users", MODE="0660"' \
    > /usr/lib/udev/rules.d/99-ntsync.rules

# Capped at 8 GB so zram doesn't eat all RAM on large-memory systems.
cat > /etc/systemd/zram-generator.conf <<'ZRAMEOF'
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
ZRAMEOF

# ── gamemode configuration ────────────────────────────────────────────────────
# Applied when a game calls gamemoderun or uses the gamemode SDL hook.
# renice/ioprio: game process gets higher CPU + I/O scheduling priority.
# gpu: switches AMD GPU to high-performance power profile during gameplay.
cat > /etc/gamemode.ini <<'GAMEMODEEOF'
[general]
renice = 10
ioprio = 0
# Inhibit screensaver during gameplay — prevents blanking during cutscenes/loads
inhibit_screensaver = 1
# Promote game threads to SCHED_FIFO via rtkit when conditions allow.
# 'auto' only engages when the system is not under memory pressure.
softrealtime = auto
# Switch to the gaming performance profile automatically when a game launches
# via GameMode, and restore the previous state on exit.
# kyth-performance-mode: saves current powerprofile + KWin blur/animation state,
# switches to performance power profile + reduced animations, then restores on exit.
# GameMode runs startscript/endscript via /bin/sh -c as the game user.
# DBUS_SESSION_BUS_ADDRESS may not be inherited (depends on how the game was
# launched), so we set it explicitly via the logind socket path as a fallback.
# unix:path=/run/user/UID/bus is guaranteed present for any logged-in user.
startscript=export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"; /usr/bin/kyth-performance-mode save && /usr/bin/kyth-performance-mode gaming
endscript=DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}" /usr/bin/kyth-performance-mode restore

[cpu]
park_cores = no
pin_cores = yes

[gpu]
apply_gpu_optimisations = accept-responsibility
amd_performance_level = high
nv_perf_level = 5
GAMEMODEEOF

# ── WiFi — disable power management ──────────────────────────────────────────
# Linux WiFi power-save throttles the radio when idle, reducing signal
# sensitivity and causing apparent "weak signal" even close to the AP.
# NetworkManager powersave=2 disables it at the connection level (all adapters).
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/wifi-powersave-off.conf <<'NMEOF'
[connection]
wifi.powersave = 2
NMEOF

# ── WiFi driver tweaks ────────────────────────────────────────────────────────
mkdir -p /etc/modprobe.d

# MT7921 PCIe (MediaTek Filogic 330): disable Active State Power Management.
# ASPM puts the PCIe device into a low-power state it may not reliably wake
# from, causing sudden disconnects and requiring a driver reload or reboot.
cat > /etc/modprobe.d/mt7921-kyth.conf <<'MT76EOF'
options mt7921e disable_aspm=1
MT76EOF

# iwlwifi (Intel WiFi): disable driver power-save and BT coexistence.
# bt_coex_active=0 stops the driver from halving WiFi throughput when Bluetooth
# is active (common cause of dropped signal during BT headset/controller use).
cat > /etc/modprobe.d/iwlwifi-kyth.conf <<'IWLEOF'
options iwlwifi power_save=0 bt_coex_active=0
IWLEOF

# cfg80211 regulatory domain: pin to US.
# Without a hint, cfg80211 defaults to the "world" domain which caps txpower at
# ~3 dBm on 5GHz — causing very slow throughput (~20 Mbps) even with a strong
# signal. FCC/US allows up to 30 dBm on channel 149 where most home APs land.
# TODO: make this locale-aware via kyth-welcome on first boot.
cat > /etc/modprobe.d/cfg80211-kyth.conf <<'CFGEOF'
options cfg80211 ieee80211_regdom=US
CFGEOF

# ── I/O schedulers ────────────────────────────────────────────────────────────
# 'none' on NVMe — the drive's own internal queues are better than any kernel
#   scheduler overhead; multi-queue hardware makes mq-deadline redundant.
# 'mq-deadline' on SATA SSD — adds deadline fairness with minimal latency.
# 'bfq' on rotational — budget fair queuing prevents seek storms.
mkdir -p /etc/udev/rules.d
cat > /etc/udev/rules.d/60-ioschedulers.rules <<'IOEOF'
# NVMe: bypass scheduler entirely (DEVTYPE==disk excludes partition nodes which lack queue/scheduler)
ACTION=="add|change", KERNEL=="nvme[0-9]*", DEVTYPE=="disk", ATTR{queue/scheduler}="none"
# SATA SSDs (non-rotational): deadline with low latency
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
# HDDs: BFQ to avoid seek storms
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
# VirtIO block (QEMU/KVM VMs): mq-deadline — BFQ can stall under heavy sequential I/O
ACTION=="add|change", KERNEL=="vd[a-z]*", ATTR{queue/scheduler}="mq-deadline"
IOEOF

# ── PipeWire low-latency audio ─────────────────────────────────────────────────
# 128 samples at 48 kHz = ~2.7 ms latency — low enough to eliminate perceptible
# audio lag in games while staying stable on typical hardware.
# min-quantum=32 lets pro-audio apps request sub-1 ms when needed.
# Apps that need higher buffering (e.g. Bluetooth) negotiate up automatically.
mkdir -p /etc/pipewire/pipewire.conf.d
cat > /etc/pipewire/pipewire.conf.d/99-kyth.conf <<'PWEOF'
context.properties = {
    default.clock.rate          = 48000
    default.clock.quantum       = 128
    default.clock.min-quantum   = 32
    default.clock.max-quantum   = 8192
    # Allow PipeWire to switch between 44100 and 48000 Hz rather than resampling.
    # Without this, a game or app that outputs at 44100 Hz forces the entire graph
    # (mic, desktop audio, etc.) through a sample-rate converter — adding CPU
    # overhead and latency. With it, PipeWire renegotiates the clock rate instead.
    default.clock.allowed-rates = [ 44100 48000 ]
}
PWEOF

# ── Proton / RADV environment variables ───────────────────────────────────────
# PROTON_FORCE_LARGE_ADDRESS_AWARE / WINE_LARGE_ADDRESS_AWARE:
#   Forces 32-bit Windows games to use the full 4 GB address space, reducing
#   OOM crashes in memory-heavy titles (e.g. Skyrim modded, DayZ).
# mesa_glthread=true:
#   Offloads OpenGL command submission to a second thread, improving CPU-bound
#   framerate in OpenGL games (Minecraft, older Source titles, etc.). Safe
#   system-wide; Vulkan/DXVK games are unaffected.
mkdir -p /etc/environment.d
cat > /etc/environment.d/proton-radv.conf <<'PROTONEOF'
PROTON_FORCE_LARGE_ADDRESS_AWARE=1
WINE_LARGE_ADDRESS_AWARE=1
AMD_VULKAN_ICD=RADV
PROTON_USE_NTSYNC=1
# esync/fsync: fallback sync primitives used when NTSYNC is unavailable (module
# not loaded, older kernel, or non-kyth install). Proton checks in priority order:
# NTSYNC → fsync → esync → default. Having both enabled costs nothing when NTSYNC
# is active, and keeps Wine/Proton fast on any system this image runs on.
WINEFSYNC=1
WINEESYNC=1
# RADV Graphics Pipeline Library — pre-compiles pipeline variants in the background
# instead of stalling the render thread. Eliminates most shader compilation stutter
# in DX11/DX12 games without requiring a warm shader cache. No regressions reported
# on current Mesa-git; disable per-game with RADV_PERFTEST= if needed.
RADV_PERFTEST=gpl
VKD3D_CONFIG=dxr
# Advertise DX12 Ultimate feature level (12_2) so VKD3D-Proton exposes DXR 1.1,
# mesh shaders, and sampler feedback. Must be paired with VKD3D_CONFIG=dxr above.
# Hardware that doesn't support a feature silently skips it; no harm on older GPUs.
VKD3D_FEATURE_LEVEL=12_2
mesa_glthread=true
# FSR upscaling in fullscreen Wine/Proton games — lets older titles that don't
# run at native resolution get AMD FidelityFX Super Resolution upscaling.
# Strength 0 = sharpest, 5 = most blur; 2 is a good balance.
WINE_FULLSCREEN_FSR=1
WINE_FULLSCREEN_FSR_STRENGTH=2
PROTONEOF

# ── NVIDIA NVAPI: detect at login, not at build time ─────────────────────────
# PROTON_ENABLE_NVAPI tells Proton to emulate NVIDIA's API layer.  It is only
# meaningful on systems with NVIDIA hardware; setting it on AMD/Intel causes
# games that check for NVAPI to try NVIDIA-specific paths and silently fail.
# A systemd user-environment generator runs at each login and outputs the
# variable only when an NVIDIA GPU is detected via lspci.
install -m 0755 /dev/stdin /usr/lib/systemd/user-environment-generators/80-kyth-nvapi.sh <<'NVAPIEOF'
#!/bin/bash
if lspci -d ::0300 2>/dev/null | grep -qi nvidia || \
   lspci -d ::0302 2>/dev/null | grep -qi nvidia; then
    echo "PROTON_ENABLE_NVAPI=1"
    # NVIDIA equivalent of mesa_glthread: offloads OpenGL command submission to
    # a second thread. Only meaningful on NVIDIA + OpenGL; Vulkan/DXVK unaffected.
    echo "__GL_THREADED_OPTIMIZATIONS=1"
fi
NVAPIEOF

# ── Open file descriptor limit (esync / general compatibility) ────────────────
# esync requires a high open-file limit; even with NTSYNC some games fall back
# to it. 1048576 matches Bazzite and CachyOS defaults. Applied to both system
# services and user sessions.
mkdir -p /etc/systemd/system.conf.d /etc/systemd/user.conf.d
echo '[Manager]
DefaultLimitNOFILE=1048576' > /etc/systemd/system.conf.d/99-kyth-limits.conf
echo '[Manager]
DefaultLimitNOFILE=1048576' > /etc/systemd/user.conf.d/99-kyth-limits.conf

# ── Baloo file indexer — disabled by default ─────────────────────────────────
# Baloo (KDE's file indexer) runs heavy I/O scans on first boot and after game
# downloads, causing stutter mid-session. Disable it in the skel so new users
# start with indexing off. Users can re-enable it from System Settings → Search.
mkdir -p /etc/skel/.config
cat > /etc/skel/.config/baloofilerc <<'BALOOEOF'
[Basic Settings]
Indexing-Enabled=false
BALOOEOF

# ── journald size cap ─────────────────────────────────────────────────────────
# On a gaming desktop the journal can silently grow to multi-GB over time from
# verbose game/driver output. Cap persistent storage at 500 MB and the in-memory
# runtime journal (current boot) at 128 MB.
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/99-kyth.conf <<'JOURNALDEOF'
[Journal]
SystemMaxUse=500M
RuntimeMaxUse=128M
JOURNALDEOF

# ── MangoHud default config ───────────────────────────────────────────────────
# Pre-configure a curated overlay: useful OOTB without being overwhelming.
# Users can override globally via ~/.config/MangoHud/MangoHud.conf or per-game
# via the MANGOHUD_CONFIG env var / Steam launch options.
mkdir -p /etc/skel/.config/MangoHud
cat > /etc/skel/.config/MangoHud/MangoHud.conf <<'MANGOHUDEOF'
# KythOS default MangoHud overlay — toggle with Shift_R+F12
# Full option reference: https://github.com/flightlessmango/MangoHud

toggle_hud=Shift_R+F12

# Position and style
position=top-left
background_alpha=0.5
font_size=20
text_color=FFFFFF
round_corners=4

# Frame metrics
fps
frametime=1
frame_timing=1

# GPU
gpu_stats
gpu_temp
gpu_core_clock
gpu_mem_clock
vram

# CPU
cpu_stats
cpu_temp
cpu_mhz

# System RAM
ram

# Show Wine/Proton version when running Windows games
wine
MANGOHUDEOF

# ── vkBasalt default config ───────────────────────────────────────────────────
# vkBasalt is only active when ENABLE_VKBASALT=1 is set (per-launch or globally).
# Pre-configure CAS sharpening so there's a sensible default when users opt in.
# casSharpness: 0.0 = maximum sharpening, 1.0 = no sharpening; 0.4 is a clean balance.
cat > /etc/vkBasalt.conf <<'VKBASALTEOF'
effects = cas
casSharpness = 0.4
# Toggle the effect on/off in-game
toggleKey = Home
VKBASALTEOF


# systemd-remount-fs tries to remount the root filesystem, which is immutable
# on bootc/ostree systems and always fails with exit status 32. Mask it.
systemctl mask systemd-remount-fs.service

# plasmalogin is KDE 6.6's new login service (ships enabled in Kinoite 44).
# It conflicts with SDDM and crashes on first boot in VMs (no hardware GL for
# its login renderer). SDDM is the display manager in use — mask plasmalogin.
systemctl mask plasmalogin.service
# Re-enforce display-manager and default target symlinks here (layer 4).
# The dnf5 upgrade in layer 2 can re-apply systemd presets and reset the
# display-manager alias.  Use explicit symlinks — systemctl enable is a
# no-op in a container build (no running systemd bus, silently swallowed
# by 2>/dev/null || true).
ln -sf /usr/lib/systemd/system/sddm.service \
    /etc/systemd/system/display-manager.service
ln -sf /usr/lib/systemd/system/graphical.target \
    /etc/systemd/system/default.target

# ── SELinux: relabel /var/home after each new deployment ──────────────────────
# bootc/ostree relabels the OS tree (/usr, /etc) on every deployment, but /var
# is writable state — it is never touched. On enforcing systems, /var/home
# files with missing labels cause PAM and dbus-broker to be denied, making
# login impossible.
#
# Running restorecon -RF /var/home on every boot adds ~45s to startup. Instead,
# gate it on a per-deployment sentinel: only relabel when the booted deployment
# checksum (from /run/ostree-booted or `ostree admin status`) differs from the
# last one we relabeled for. After first boot of a new deployment, subsequent
# reboots skip it entirely. If a user needs to force a relabel, they can remove
# /var/lib/kyth/selinux-relabel-home.stamp.
cat > /usr/lib/systemd/system/kyth-selinux-relabel-home.service <<'RELABELEOF'
[Unit]
Description=SELinux relabel /var/home (once per deployment)
DefaultDependencies=no
After=local-fs.target
Before=sddm.service
ConditionSecurity=selinux

[Service]
Type=oneshot
ExecStart=/usr/libexec/kyth-selinux-relabel-home
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
RELABELEOF

install -d -m 0755 /usr/libexec
cat > /usr/libexec/kyth-selinux-relabel-home <<'SCRIPTEOF'
#!/usr/bin/bash
# Relabel /var/home only once per ostree/bootc deployment.
# Keyed on the booted deployment checksum so a fresh deployment triggers one
# relabel, then all subsequent reboots of the same deployment skip it.
set -euo pipefail

STAMP_DIR=/var/lib/kyth
STAMP_FILE="${STAMP_DIR}/selinux-relabel-home.stamp"

# Derive a stable deployment identifier. Prefer `ostree admin status --json`
# if available; fall back to parsing the booted checksum from plain output;
# finally fall back to the kernel cmdline ostree= argument.
deployment_id=""
if command -v ostree >/dev/null 2>&1; then
    deployment_id="$(ostree admin status 2>/dev/null \
        | awk '/^\* /{print $2" "$3; exit}')"
fi
if [ -z "$deployment_id" ] && [ -r /proc/cmdline ]; then
    deployment_id="$(tr ' ' '\n' < /proc/cmdline | grep '^ostree=' || true)"
fi
# Last-resort fingerprint: mtime of the active deployment root.
if [ -z "$deployment_id" ]; then
    deployment_id="fallback-$(stat -c %Y /usr 2>/dev/null || echo 0)"
fi

if [ -r "$STAMP_FILE" ] && [ "$(cat "$STAMP_FILE")" = "$deployment_id" ]; then
    echo "kyth-selinux-relabel-home: already relabeled for this deployment, skipping"
    exit 0
fi

echo "kyth-selinux-relabel-home: relabeling /var/home for deployment ${deployment_id}"
/sbin/restorecon -RF /var/home

mkdir -p "$STAMP_DIR"
printf '%s' "$deployment_id" > "$STAMP_FILE"
SCRIPTEOF
chmod 0755 /usr/libexec/kyth-selinux-relabel-home

systemctl enable kyth-selinux-relabel-home.service 2>/dev/null || true

# ── First-boot Plymouth message ───────────────────────────────────────────────
# On the very first boot after install, the SELinux relabel and other setup
# tasks add a few extra seconds before login. Show a message on the boot splash
# so the user knows something is happening. The sentinel file ensures this only
# ever runs once — after first boot it is a no-op for all future reboots.
cat > /usr/lib/systemd/system/kyth-first-boot-message.service <<'FIRSTBOOTEOF'
[Unit]
Description=KythOS first-boot splash message
DefaultDependencies=no
After=plymouth-start.service local-fs.target
Before=sddm.service
ConditionPathExists=!/var/lib/kyth/.first-boot-complete

[Service]
Type=oneshot
ExecStart=/usr/bin/plymouth message --text="Running first boot setup, this may take a few moments..."
ExecStart=/bin/bash -c 'mkdir -p /var/lib/kyth && touch /var/lib/kyth/.first-boot-complete'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
FIRSTBOOTEOF
systemctl enable kyth-first-boot-message.service 2>/dev/null || true

# SDDM greeter software-rendering fallback — mirrors the live ISO's drop-in.
# SDDM renders its own QML greeter with Mesa; on certain hardware (Intel vPro
# with VT-d, VMs without virgl) the GL context creation fails and SDDM crashes
# before showing the login screen.  QT_QUICK_BACKEND=software makes SDDM itself
# render via llvmpipe, which works on all hardware.  This does NOT affect KWin
# or the KDE session — those inherit neither this service env var nor software
# rendering, so gaming performance is completely unaffected.
mkdir -p /etc/systemd/system/sddm.service.d
cat > /etc/systemd/system/sddm.service.d/greeter-rendering.conf <<'SDDMDROPINEOF'
[Service]
Environment="QT_QUICK_BACKEND=software"
SDDMDROPINEOF

# ── AMD CPU Energy Performance Preference helper ─────────────────────────────
# kyth-performance-mode calls this via sudo to set EPP on all CPU cores.
# On amd_pstate=active systems (default on CachyOS kernel), EPP is the primary
# frequency/voltage scaling knob — more direct than powerprofilesctl alone.
# Valid values: performance, balance_performance, balance_power, power, default
install -m 0755 /dev/stdin /usr/bin/kyth-set-epp <<'EPPEOF'
#!/bin/bash
EPP="${1:-balance_performance}"
case "$EPP" in
    performance|balance_performance|balance_power|power|default) ;;
    *)
        echo "kyth-set-epp: invalid EPP value: ${EPP}" >&2
        echo "Valid values: performance, balance_performance, balance_power, power, default" >&2
        exit 1
        ;;
esac
changed=0
for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
    [[ -f "$f" ]] || continue
    echo "$EPP" > "$f" 2>/dev/null && changed=1 || true
done
[[ $changed -eq 1 ]] || echo "kyth-set-epp: no EPP sysfs nodes found (non-AMD or pstate inactive)" >&2
EPPEOF

# ── Sudoers: passwordless safe upgrade/firmware operations ────────────────────
# bootc upgrade/switch stages a new image but does not modify the running system —
# a reboot is always required to activate it. fwupdmgr operations are similarly
# safe (refresh = metadata fetch; get-updates/update = firmware staging).
# Allowing these without a password lets 'ujust upgrade' run without a mid-stream
# sudo prompt that breaks the terminal flow.
# The 0440 mode (owner+group read, no write) is required by sudo's NOPASSWD check.
install -m 0440 /dev/stdin /etc/sudoers.d/kyth-upgrade <<'SUDOEOF'
# KythOS: wheel group may run safe update/firmware commands without a password.
%wheel ALL=(root) NOPASSWD: /usr/bin/bootc upgrade
%wheel ALL=(root) NOPASSWD: /usr/bin/bootc switch ghcr.io/mrtrick37/kyth\:*
%wheel ALL=(root) NOPASSWD: /usr/bin/fwupdmgr refresh
%wheel ALL=(root) NOPASSWD: /usr/bin/fwupdmgr update
%wheel ALL=(root) NOPASSWD: /usr/bin/fwupdmgr get-updates
%wheel ALL=(root) NOPASSWD: /usr/bin/kyth-set-epp *
%wheel ALL=(root) NOPASSWD: /usr/bin/kyth-rclone-update
SUDOEOF

systemctl enable rtkit-daemon.service 2>/dev/null || true
systemctl enable input-remapper.service 2>/dev/null || true
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

# useradd only reads /etc/group, but Fedora system groups live in /usr/lib/group.
# Copy any missing groups into /etc/group; create with groupadd if absent entirely.
for grp in users video audio gamemode docker disk kvm tty clock kmem input render lp utmp plugdev; do
    if ! grep -q "^${grp}:" /etc/group; then
        if getent group "$grp" > /dev/null 2>&1; then
            getent group "$grp" >> /etc/group
        else
            groupadd "$grp"
        fi
    fi
done
