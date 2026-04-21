# KythOS

A bleeding-edge atomic desktop OS built on Fedora Kinoite (KDE Plasma) with the CachyOS kernel. The entire OS ships as a container image — immutable base, atomic updates, one-command rollback. Installed from a live ISO via a custom graphical installer.

> Work in progress. Don't install on anything you care about.

---

## What it is

KythOS is a personal, opinionated desktop OS built for performance, gaming, content creation, and development — with no compromises on bleeding-edge hardware support. The system is built with Docker, distributed as a container image via GitHub Container Registry, and deployed atomically via [bootc](https://containers.github.io/bootc/). Rolling back to a previous deployment is one command.

| | |
|---|---|
| **Base** | Fedora 44 KDE Plasma (`ublue-os/kinoite-main:44`) |
| **Kernel** | CachyOS — BORE scheduler, sched-ext, BBRv3, NTSYNC, latency-tuned |
| **GPU drivers** | Mesa-git (bleeding-edge RADV/RADEONSI from `xxmitsu/mesa-git` COPR) |
| **Display** | KDE Plasma 6 on Wayland |
| **Installer** | Custom PySide6 + Chromium kiosk — pulls the OS image from the registry at install time via `bootc install to-disk`; supports full-disk wipe or dual-boot alongside an existing OS |
| **Theme** | Breeze Dark with KythOS branding, custom Plymouth boot splash |
| **SELinux** | Enforcing — bootc/ostree runs `restorecon` on the full tree every deployment; `/var/home` is relabeled via a first-boot service before SDDM starts |

---

## System Hub

**KythOS System Hub** (`kyth-welcome`) is the post-install management app — opens on first login and always available from the app menu. It covers every major aspect of the system in one place:

| Section | What it does |
|---------|-------------|
| **Home** | First-boot wizard: branch selection, hardware check, firmware check, gaming setup |
| **Update** | Trigger `bootc upgrade`, view staged deployment status |
| **Hardware** | System info, GPU probe, firmware/driver status |
| **Firmware** | fwupdmgr integration — check and apply BIOS and peripheral firmware |
| **Content Creation** | Install/launch OBS, Kdenlive, Audacity, GIMP, OpenDeck; DaVinci Resolve installer |
| **Gaming** | Gaming tool installs, GE-Proton management, MangoHud/vkBasalt config, launcher setup |
| **Security** | Kali Linux distrobox — headless, default, or full toolset tier |
| **Software** | Flatpak, Homebrew, and Distrobox explained with install shortcuts |
| **Cloud Storage** | rclone setup (`kyth-rclone-update` installs/updates rclone to `/usr/local/bin`) |
| **Network Shares** | CIFS/SMB mount configuration (backed by `cifs-utils`) |
| **NVIDIA Drivers** | NVIDIA driver setup (shown only when NVIDIA GPU is detected) |
| **Repair** | SELinux relabel, Flatpak repair, diagnostics |

---

## What's included

### Gaming

- Steam, Lutris, Heroic Games Launcher, Bottles — via Flatpak (optional installs)
- Prism Launcher (Minecraft), RetroArch (multi-system emulator), Itch.io, Piper, OpenRGB
- GameMode, gamescope, MangoHud, vkBasalt, umu-launcher, winetricks, libFAudio
- GE-Proton — pre-installed at build time, updated weekly via systemd timer
- OBS Studio + obs-vkcapture (GPU capture without display compositor overhead)
- scx schedulers (scx_lavd / scx_rusty / scx_bpfland via scxd, auto-mode) — prioritises latency-sensitive threads during gaming
- system76-scheduler — dynamically adjusts process priorities based on focused window
- ananicy-cpp — static per-process CPU/IO priority rules
- NTSYNC udev rules (faster Wine sync primitives, lower latency than esync/fsync)
- GameMode auto performance profile — switches to `performance` + reduces KWin animations on game launch; restores on exit
- GameMode soft-realtime (`SCHED_FIFO` via rtkit) + screensaver inhibit
- MangoHud pre-configured with a curated overlay (fps, frametimes, GPU/CPU temp/clock, VRAM — toggle `Shift_R+F12`)
- vkBasalt pre-configured with CAS sharpening (strength 0.4, `Home` to toggle) — active when `ENABLE_VKBASALT=1`
- FSR upscaling in fullscreen Wine/Proton games (`WINE_FULLSCREEN_FSR=1`, strength 2)
- LatencyFleX — Vulkan implicit layer for frame-pacing in supported Wine/Proton games
- steam-devices — Valve's udev rules for PS/Xbox/Switch/third-party controllers
- input-remapper (remap controllers, mice, keyboards at the kernel level)
- `game-performance` and `zink-run` helper wrappers
- Weekly `duperemove` timer for reclaiming duplicate blocks on supported filesystems
- First-boot Flatpaks (auto-installed on first login): Heroic, protontricks, ProtonUp-Qt, Discord, Flatseal, Gearlever, OBS Studio, MediaWriter

### Content Creation

- OBS Studio + obs-vkcapture, Kdenlive, Audacity, GIMP, OpenDeck (Stream Deck for Linux)
- DaVinci Resolve — installer helper packages the Blackmagic ZIP as a local Flatpak; AMD GPU + Mesa-git gives excellent hardware acceleration
- Full codec stack: ffmpeg, GStreamer (OpenH264, libav, ugly, bad-freeworld), mpv
- ffmpegthumbnailer for video thumbnail previews
- PipeWire at 48 kHz / 128-sample quantum (~2.7 ms latency), min-quantum=32

### Security

- **Kali Linux Toolbox** — one-click distrobox setup; choose headless (~150 CLI tools: nmap, metasploit, hashcat, john, hydra), default (adds GUI tools: Zenmap, Autopsy, Faraday, legion), or everything (full Kali catalog)
- Shared home directory — Kali tools see your files, keys, and configs natively
- No impact on the base OS — remove the container without touching anything else

### Development

- Visual Studio Code with the Claude Code extension pre-installed system-wide
- Brave browser
- GitHub CLI (`gh`)
- Homebrew — system-wide, wheel group owns `/home/linuxbrew`; persists across OS updates
- topgrade (latest musl release — upgrades Flatpaks, Homebrew, and more in one command)
- Docker
- distrobox (run any-distro containers alongside the immutable base)
- libvirt / QEMU / incus + LXC
- NVIDIA kernel module support (akmod-nvidia pre-installed for on-demand build)
- KDE Connect

### Observability

- trace-cmd, tiptop, sysprof, radeontop

### System tuning

- **Memory:** vm.swappiness=180 (correct for zram), THP=madvise, vm.max_map_count=2147483642 (Star Citizen etc.), fast OOM recovery, 5 s dirty-page flush, 256 MB dirty cap
- **Network:** TCP BBRv3, 64 MB socket buffers, TCP Fast Open, MTU probing, raised inotify limits
- **Audio:** PipeWire at 48 kHz / 128-sample quantum (~2.7 ms), allowed-rates=[44100 48000]
- **Storage:** I/O scheduler per device type — `none` on NVMe, `mq-deadline` on SATA SSD, `bfq` on HDD; weekly `fstrim.timer`
- **Gaming:** split-lock mitigation disabled, sched_autogroup, NMI watchdog off, perf_event_paranoid=1; irqbalance on
- **Wine/Proton:** full 4 GB address space, NTSYNC + fsync/esync fallbacks, VKD3D DXR + feature level 12_2, RADV_PERFTEST=gpl (reduces shader stutter), mesa_glthread; NVIDIA: NVAPI + threaded optimisations auto-enabled on NVIDIA GPU
- zram (min(RAM/2, 8 GB), zstd compression)
- WiFi power-save disabled; Intel BT coexistence disabled; MT7921 ASPM disabled
- KDE Baloo disabled by default (I/O stutter after large game downloads) — re-enable in System Settings → Search
- journald capped at 500 MB persistent / 128 MB runtime
- spice-vdagent for automatic display resize in QEMU/KVM VMs
- Automatic updates disabled — no surprise reboots; update manually via `sudo bootc upgrade` (passwordless for `wheel` group)
- First boot: Plymouth shows "Running first boot setup…" while SELinux relabeling and one-shot services complete

---

## Branches and image tags

| Branch | Image tag | Purpose |
|--------|-----------|---------|
| `main` | `:latest` | Stable (relatively speaking) |
| `testing` | `:testing` | Active development — may be unstable |

Both branches rebuild daily at 10:05 UTC and on every push.

Switch between them on an installed system:

```bash
sudo bootc switch ghcr.io/mrtrick37/kyth:testing
sudo bootc switch ghcr.io/mrtrick37/kyth:latest
```

---

## Install

### Download the Live ISO

1. Flash to USB (`dd`, Balena Etcher, Ventoy, etc.)
2. Boot — KDE Plasma autologins as `liveuser`, no password required
3. Click **Install KythOS** on the desktop
4. Choose your install mode:
   - **Erase disk** — wipes the selected disk and installs KythOS
   - **Install alongside** — shrinks your largest existing partition and installs KythOS in the freed space (dual boot)
5. Configure disk, timezone, hostname, and user account
6. Click **Install** — the OS image (~4 GB) is pulled from the container registry and written to disk via `bootc install to-disk`
7. Reboot into the installed system

**Requirements:** 8 GB RAM minimum for the live session. Active network connection required (netinstall).

### Rebase from an existing Fedora atomic system

```bash
sudo bootc switch ghcr.io/mrtrick37/kyth:latest
```

---

## Updates

```bash
sudo bootc upgrade
```

Updates are atomic — the previous deployment is kept as a fallback selectable at the GRUB menu. There is no package manager on the running system; all changes go through the image build. For user applications, use Flatpak (via Discover) or Homebrew.

---

## Build locally

**Requirements:** `docker`, `just`

```bash
# Step 1 — build the base image (CachyOS kernel + Fedora Kinoite)
just build-base

# Step 2 — build the full KythOS OS image
just build

# Step 3 — build the live ISO
just build-live-iso

# Boot the ISO in QEMU (native, SPICE window)
just run-live-iso-native
```

`just build` produces `localhost/kyth:latest`. The live ISO is written to `output/live-iso/kyth-live-latest.iso`.

### Build recipes

```bash
just build-base                           # Build kyth-base layer (CachyOS kernel)
just build                                # Build full OS image on top of kyth-base
just build-live-iso                       # Build live ISO (from :latest)
just build-live-iso testing               # Build ISO targeting the :testing image
just rebuild-live-iso                     # Full rebuild, ignores cached container layer
just run-live-iso                         # Boot ISO in Docker-wrapped QEMU (noVNC)
just run-live-iso-native                  # Boot ISO in native QEMU + SPICE
just build-qcow2                          # Build QCOW2 VM image via Bootc Image Builder
just disk-usage                           # Show Docker + output/ disk usage
just clean                                # Remove build output artefacts
just clean-docker                         # Prune Docker build cache and dangling layers
just clean-all                            # clean-output + clean-docker
just purge                                # Nuclear: reclaim maximum disk space
just lint && just format                  # shellcheck + shfmt on all .sh files
```

### Feature flags

Both default to enabled. Pass `0` to skip:

```bash
ENABLE_ANANICY=0 ENABLE_SCX=0 just build
```

### Docker group

If you get a permission denied error on the Docker socket after being added to the `docker` group:

```bash
newgrp docker
```

---

## CI

| Workflow | Trigger | Output |
|----------|---------|--------|
| Build container image | Push to `main`/`testing`, daily at 10:05 UTC, PR | `ghcr.io/mrtrick37/kyth:latest` and `:testing` |
| Build Live ISO | Automatic after successful container-image pushes, or manual dispatch | `kyth-live-latest.iso` / `kyth-live-testing.iso` on Cloudflare R2 |

---

## Project layout

```text
Dockerfile                        Main OS image (layers on top of kyth-base)
Justfile                          Build orchestration — all recipes

build_base/
  Dockerfile                      Pulls kinoite-main:44, installs CachyOS kernel
  build.sh                        Kernel, initramfs, Plymouth, kargs, SDDM

build_files/
  build-live-iso.sh               Assembles squashfs + GRUB2 + UEFI/BIOS bootable ISO
  Containerfile.live              Live session container (X11 autologin, custom installer)
  kyth-installer                  Graphical installer (PySide6 + Chromium kiosk)
  kyth-launch-installer           Desktop launcher for the installer
  kyth-install.sh                 CLI install script (bootc install to-disk)
  kyth-manual-install.sh          Manual/fallback install script
  branding/
    kyth-logo.svg                 KythOS logo (with background and wordmark)
    kyth-logo-transparent.svg     KythOS K mark (transparent)
    cockpit-branding.css          Themed CSS for the installer UI
  scripts/
    packages.sh                   RPM packages, repos, dnf upgrade (Layer 1)
    thirdparty.sh                 topgrade, winetricks, LatencyFleX, scx schedulers, Homebrew (Layer 2)
    sysconfig.sh                  sysctl, audio, gaming tuning, env vars (Layer 3)
    branding.sh                   Icons, themes, Plymouth, wallpaper, welcome app (Layer 4)
    ge-proton.sh                  GE-Proton installer (Layer 5)
    mesa-git.sh                   Mesa-git GPU drivers (Layer 6)
  game-performance                CPU/GPU performance helper script
  zink-run                        Run OpenGL apps via Zink (Vulkan-backed GL)
  just/kyth.just                  ujust recipes shipped in the installed OS
  kyth-welcome/                   KythOS System Hub (PyQt6) — first-run wizard + management app
  MangoHud.conf                   System-wide MangoHud defaults
  vkBasalt.conf                   System-wide vkBasalt defaults
  plymouth/                       Boot splash theme (pulsating KythOS logo)
  wallpaper/                      Desktop wallpaper (SVG)
  kyth-ge-proton-update           Weekly GE-Proton update script (+ .service/.timer)
  kyth-rclone-update              Install/update latest rclone release into /usr/local/bin
  kyth-duperemove                 Weekly deduplication script (+ .service/.timer)
  kyth-performance-mode           Toggle system performance profile (max/gaming/performance/balanced/powersave)
  kyth-kerver                     Print kernel/scheduler info
  kyth-device-info                Print hardware summary
  kyth-creator-check              Diagnostics dump for content-creation session issues
  kyth-davinci-install            DaVinci Resolve installer helper
  kyth-bootc-sudo                 Wrapper for bootc operations with sudo
  kyth-nvidia-setup               NVIDIA driver setup helper (+ .service)
  kyth-default-flatpaks.service   First-boot Flatpak installation
  kyth-flathub-setup.service      Flathub repo configuration

disk_config/
  disk.toml                       BIB config for qcow2/raw images
  iso.toml                        BIB config for installer ISO

.github/workflows/
  build.yml                       CI: builds and publishes OS image
  build-live-iso.yml              CI: builds and publishes live ISO
```

---

## Links

- [Issues](https://github.com/mrtrick37/kyth/issues)
- [Discussions](https://github.com/mrtrick37/kyth/discussions)
- [Actions](https://github.com/mrtrick37/kyth/actions)

---

*Not affiliated with Universal Blue, Fedora, CachyOS, or anyone who actually knows what they're doing.*

<!-- AUTO-README-START -->
## Auto Project Snapshot

- Last refreshed (UTC): 2026-04-21 18:58:12 UTC
- Current branch: testing
- HEAD commit: 1015360
- Last commit title: chore: trigger build [testing]
- Last commit date: 2026-04-17T12:23:55-04:00
- CI workflow files: 3
- Build script files: 7

<!-- AUTO-README-END -->
