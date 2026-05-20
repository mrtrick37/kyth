<div align="center">

<img src="build_files/branding/kyth-logo.svg" alt="KythOS logo" width="360">

# KythOS

### A friendly Linux desktop image for games, creative work, tinkering, and daily use.

[Download Stable ISO](https://github.com/mrtrick37/kyth/releases/tag/iso-latest) |
[Try Testing ISO](https://github.com/mrtrick37/kyth/releases/tag/iso-testing) |
[How It Works](#under-the-hood) |
[Report A Bug](https://github.com/mrtrick37/kyth/issues)

<img src="build_files/wallpaper/kyth-wallpaper.svg" alt="KythOS desktop wallpaper with glowing bloom mark" width="100%">

</div>

KythOS is a ready-to-try desktop OS with a polished KDE Plasma experience, a custom installer, and a first-run System Hub that helps you set up the stuff people actually care about: games, launchers, drivers, updates, creative apps, VPN, cloud storage, and repair tools.

It is for people who want Linux to feel less like a weekend project and more like a machine they can boot, explore, and enjoy.

## Try It

| Channel | Best for | Download |
|---|---|---|
| Stable | Trying KythOS, showing friends, or installing when you want the calmest option | [Stable ISO release](https://github.com/mrtrick37/kyth/releases/tag/iso-latest) |
| Testing | New features, active development, and helping catch rough edges | [Testing ISO release](https://github.com/mrtrick37/kyth/releases/tag/iso-testing) |

Direct ISO links:

- Stable: [kyth-live-latest.iso](https://pub-9a3cc72972ea44c4ae7504ee7cda1fa6.r2.dev/kyth-live-latest.iso)
- Testing: [kyth-live-testing.iso](https://pub-9a3cc72972ea44c4ae7504ee7cda1fa6.r2.dev/kyth-live-testing.iso)
- Extra verification files are linked from each GitHub release.

**You will need:** 8 GB RAM minimum, a USB drive, and an active internet connection during install.

## Why Try It

| Play | Create | Tinker | Relax |
|---|---|---|---|
| Steam, Lutris, Heroic, Proton helpers, overlays, controller support, and game migration guidance are ready to go. | Recording, video editing, audio work, image editing, media codecs, and a DaVinci Resolve helper are close at hand. | Developer tools, virtual machines, containers, and optional security toolboxes are built into the workflow. | Updates are staged safely, older system versions stay available, and the System Hub gives you repair tools when something feels off. |

## First Boot

The live ISO drops you into a KDE Plasma desktop. Click **Install KythOS**, choose whether to erase a disk or install alongside another OS, set your user account, and let the installer do the heavy lifting.

After reboot, **KythOS System Hub** opens automatically. It is the control room for updates, hardware checks, firmware, gaming setup, creator apps, VPN, cloud storage, repair tools, NVIDIA setup, security toolboxes, and optional extras.

```text
Boot USB
  -> Install KythOS
  -> Reboot
  -> System Hub
  -> Play, create, build, break things safely
```

## What Makes It Feel Different

- **Games feel first-class:** launchers, Proton helpers, overlays, controller support, save tools, and game-readiness checks are all part of the experience.
- **Creative work is invited:** recording, editing, audio, image work, thumbnails, codecs, and DaVinci Resolve setup all get attention.
- **It is kind to curious people:** install apps, create dev containers, try security tools, switch branches, and still have a way back if an experiment goes sideways.
- **It helps Windows users find their footing:** game migration notes, save backup guidance, ProtonDB and anti-cheat references, and guided checks live in System Hub.
- **It avoids surprise maintenance:** no forced reboot rhythm. Update when you are ready.

## System Hub

<div align="center">
<img src="build_files/branding/kyth-logo-transparent.svg" alt="KythOS bloom mark" width="160">
</div>

KythOS System Hub is the thing you open when you do not want to remember a dozen commands.

| Section | What it helps with |
|---|---|
| Home | First-run wizard, channel selection, hardware check, firmware check, gaming setup |
| Update | Check for system updates, view pending changes, switch channels |
| Hardware | GPU probe, system info, firmware and driver status |
| Gaming | Launchers, Proton tools, overlays, game checks, save tools, migration helpers |
| Creation | OBS, Kdenlive, Audacity, GIMP, OpenDeck, DaVinci Resolve helper |
| Security | Optional security toolboxes and network analysis apps |
| Software | App installs, developer tools, and container workspaces |
| Network | VPN Connect, GlobalProtect SAML flow, SMB shares, cloud storage through rclone |
| Repair | SELinux relabel, Flatpak repair, diagnostics |

## Install From USB

1. Flash the ISO with Balena Etcher, Ventoy, `dd`, or your favorite USB writer.
2. Boot it. KythOS opens straight into the live desktop.
3. Click **Install KythOS**.
4. Pick an install mode:
   - **Erase disk:** wipe the selected disk and install KythOS.
   - **Install alongside:** shrink the largest existing partition and install KythOS in the freed space.
5. Configure disk, timezone, hostname, and user account.
6. Click **Install** and wait for the image to download and write to disk.
7. Reboot into KythOS.

## Under The Hood

[![Build image](https://github.com/mrtrick37/kyth/actions/workflows/build.yml/badge.svg)](https://github.com/mrtrick37/kyth/actions/workflows/build.yml)
[![Build live ISO](https://github.com/mrtrick37/kyth/actions/workflows/build-live-iso.yml/badge.svg)](https://github.com/mrtrick37/kyth/actions/workflows/build-live-iso.yml)
[![Container](https://img.shields.io/badge/GHCR-ghcr.io%2Fmrtrick37%2Fkyth-73daca?logo=github)](https://github.com/mrtrick37/kyth/pkgs/container/kyth)
[![Fedora KDE](https://img.shields.io/badge/Fedora_Kinoite-44-7dcfff?logo=fedora)](https://fedoraproject.org/atomic-desktops/kinoite/)
[![bootc](https://img.shields.io/badge/bootc-atomic_updates-bb9af7)](https://containers.github.io/bootc/)

The friendly version is above. This section is for the people who want the wiring diagram.

<details>
<summary><strong>Core stack</strong></summary>

| Layer | Choice |
|---|---|
| Base | Fedora 44 KDE Plasma, `ublue-os/kinoite-main:44` |
| Kernel | CachyOS kernel with BORE scheduler, sched-ext, BBRv3, NTSYNC, latency tuning |
| Desktop | KDE Plasma 6 |
| Display | Wayland by default, with X11 live-session compatibility where needed |
| Installer | Custom PySide6 + Chromium kiosk using `bootc install to-disk` |
| Theme | Breeze Dark with KythOS branding, wallpaper, icon mark, and Plymouth splash |
| Security | SELinux enforcing, relabel services for bootc/ostree deployments |
| Image | `ghcr.io/mrtrick37/kyth:latest` and `ghcr.io/mrtrick37/kyth:testing` |

</details>

<details>
<summary><strong>Advanced install, update, and rollback commands</strong></summary>

Install into a partition you already created from the live ISO:

```bash
sudo kyth-partition-install /dev/nvme0n1p5
```

Pass an EFI System Partition explicitly if needed:

```bash
sudo kyth-partition-install /dev/nvme0n1p5 /dev/nvme0n1p1
```

Rebase from an existing Fedora atomic system:

```bash
sudo bootc switch ghcr.io/mrtrick37/kyth:latest
```

Switch to testing later:

```bash
sudo bootc switch ghcr.io/mrtrick37/kyth:testing
```

Update an installed system:

```bash
sudo bootc upgrade
```

Updates are atomic. The running system is not mutated in place, and the previous deployment remains available from GRUB. Applications should generally come from Flatpak, Homebrew, Distrobox, or project containers.

</details>

<details>
<summary><strong>Gaming loadout</strong></summary>

- Steam, Lutris, Heroic Games Launcher, ProtonUp-Qt, protontricks, GE-Proton, umu-launcher, winetricks, and libFAudio.
- GameMode, Gamescope, MangoHud, vkBasalt, LatencyFleX, obs-vkcapture, scx schedulers, system76-scheduler, and ananicy-cpp.
- Controller and peripheral stack: steam-devices, game-devices rules, xpadneo/xone, OpenRazer, OpenTabletDriver, Piper, OpenRGB, and input-remapper.
- Helper commands: `kyth-gamescope`, `game-performance`, `kyth-performance-mode`, `zink-run`, `kyth-kerver`, and `kyth-device-info`.
- Guides: [gaming validation matrix](docs/gaming-validation-matrix.md), [modding](docs/modding-on-kythos.md), [save migration](docs/game-save-migration.md), [developer support checklist](docs/developer-linux-support-checklist.md), and [why games work better here](docs/works-better-here.md).

</details>

<details>
<summary><strong>Creator, developer, and network tools</strong></summary>

- Creator apps: OBS Studio, Kdenlive, Audacity, GIMP, OpenDeck, DaVinci Resolve helper, mpv, ffmpeg, GStreamer plugins, OpenH264, ffmpegthumbnailer, and low-latency PipeWire defaults.
- Developer tools: VS Code, GitHub CLI, Homebrew, topgrade, Docker, Distrobox, libvirt/QEMU, Incus/LXC, NVIDIA kernel module support, and KDE Connect.
- Network tools: standalone VPN Connect app, OpenConnect protocols, GlobalProtect SAML support, tray status helper, SMB/CIFS setup, and rclone cloud storage setup.
- Security tools: optional Kali Linux Distrobox tiers plus optional Wireshark and Burp Suite Flatpaks.

</details>

<details>
<summary><strong>System tuning highlights</strong></summary>

- zram with zstd compression, swappiness tuned for zram, THP set to `madvise`, high `vm.max_map_count`, fast OOM recovery, and capped dirty pages.
- TCP BBRv3, larger socket buffers, TCP Fast Open, MTU probing, and raised inotify limits.
- Storage scheduler by device type, weekly `fstrim.timer`, optional weekly `duperemove`, and journald caps.
- Wine/Proton defaults for NTSYNC, fsync/esync fallbacks, DXR, VKD3D feature level 12_2, RADV GPL, Mesa GL threading, and NVIDIA NVAPI/threaded optimizations when relevant.
- KDE Baloo disabled by default to reduce I/O churn after large game downloads.

</details>

<details>
<summary><strong>Build locally</strong></summary>

Requirements: `docker` and `just`.

```bash
just build-base
just build
just build-live-iso
just run-live-iso-native
```

Useful recipes:

```bash
just build-base
just build
just build-live-iso
just build-live-iso testing
just rebuild-live-iso
just run-live-iso
just run-live-iso-native
just build-qcow2
just disk-usage
just clean
just clean-docker
just lint && just format
```

`just build` produces `localhost/kyth:latest`. The live ISO lands at `output/live-iso/kyth-live-latest.iso`.

Feature flags:

```bash
ENABLE_ANANICY=0 ENABLE_SCX=0 just build
```

</details>

<details>
<summary><strong>Repository map</strong></summary>

```text
Dockerfile                        Main OS image
Justfile                          Build orchestration

build_base/                       Fedora Kinoite base plus CachyOS kernel
build_files/
  build-live-iso.sh               Live ISO assembler
  Containerfile.live              Live session image
  kyth-installer                  Graphical installer
  kyth-install.sh                 bootc disk installer
  kyth-partition-install.sh       Existing-partition installer
  branding/                       Logo, transparent mark, installer CSS
  wallpaper/                      KythOS wallpaper
  scripts/                        Package, tuning, branding, third-party setup
  kyth-welcome/                   KythOS System Hub
  kyth-vpn-connect/               Standalone OpenConnect VPN app
  kyth-vpn-status/                KDE VPN tray helper
  just/kyth.just                  ujust recipes shipped in the OS

disk_config/                      Bootc Image Builder configs
.github/workflows/                Image, ISO, lint, scorecard, supply chain
docs/                             Gaming, migration, modding, validation docs
```

</details>

<details>
<summary><strong>Verification and release files</strong></summary>

Container images are signed with keyless Sigstore/Cosign, include attached Syft SBOMs in GHCR, and publish GitHub build provenance attestations.

Live ISO releases publish the ISO, SHA256 checksum, Cosign signature, Cosign bundle, JSON metadata, and provenance.

</details>

## Links

- [Issues](https://github.com/mrtrick37/kyth/issues)
- [Discussions](https://github.com/mrtrick37/kyth/discussions)
- [Actions](https://github.com/mrtrick37/kyth/actions)
- [Container package](https://github.com/mrtrick37/kyth/pkgs/container/kyth)

<div align="center">

**KythOS is not affiliated with Fedora, Universal Blue, CachyOS, Valve, or KDE. It just really likes their work.**

</div>

<!-- AUTO-README-START -->
## Auto Project Snapshot

- Last refreshed (UTC): 2026-05-20 00:19:54 UTC
- Current branch: testing
- HEAD commit: f9062f1
- Last commit title: f
- Last commit date: 2026-05-19T19:50:59-04:00
- CI workflow files: 5
- Build script files: 8

<!-- AUTO-README-END -->
