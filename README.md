<div align="center">

<img src="build_files/branding/kyth-logo-transparent.svg" alt="KythOS" width="200">

# KythOS

**A Linux desktop that's actually ready when you sit down.**<br>
Built on Fedora Kinoite · KDE Plasma 6 · Shipped as a container image · Atomic updates

<br>

[Download Stable ISO](https://pub-9a3cc72972ea44c4ae7504ee7cda1fa6.r2.dev/kyth-live-latest.iso) · [Download Testing ISO](https://pub-9a3cc72972ea44c4ae7504ee7cda1fa6.r2.dev/kyth-live-testing.iso) · [Report a Bug](https://github.com/mrtrick37/kyth/issues) · [Discussions](https://github.com/mrtrick37/kyth/discussions)

<br>

[![Build](https://github.com/mrtrick37/kyth/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/mrtrick37/kyth/actions/workflows/build.yml)
[![Build ISO](https://github.com/mrtrick37/kyth/actions/workflows/build-live-iso.yml/badge.svg)](https://github.com/mrtrick37/kyth/actions/workflows/build-live-iso.yml)
[![CVE Scan](https://github.com/mrtrick37/kyth/actions/workflows/cve-scan.yml/badge.svg)](https://github.com/mrtrick37/kyth/actions/workflows/cve-scan.yml)
[![Scorecard](https://api.securityscorecardcards.dev/projects/github.com/mrtrick37/kyth/badge)](https://securityscorecards.dev/viewer/?uri=github.com/mrtrick37/kyth)
[![Container](https://img.shields.io/badge/GHCR-ghcr.io%2Fmrtrick37%2Fkyth-73daca?logo=github)](https://github.com/mrtrick37/kyth/pkgs/container/kyth)
[![Fedora KDE](https://img.shields.io/badge/Fedora_Kinoite-44-7dcfff?logo=fedora)](https://fedoraproject.org/atomic-desktops/kinoite/)
[![bootc](https://img.shields.io/badge/bootc-atomic_updates-bb9af7)](https://containers.github.io/bootc/)

<br>

<img src="build_files/wallpaper/kyth-wallpaper.svg" alt="KythOS desktop" width="100%">

</div>

---

KythOS is a ready-to-install Linux desktop for gaming, creating, and daily use. Boot from a USB drive, install through a real graphical installer, and open into a KDE Plasma 6 desktop that's already configured — launchers, tuning tools, hardware helpers, and a first-run **System Hub** included.

Updates are atomic. Stage a new deployment, reboot into it, and roll back from the boot menu if something breaks. The whole OS ships as a container image. Every build is reproducible, signed, and verifiable.

---

## Download

| Channel | Best for | Direct download |
|---|---|---|
| **Stable** `latest` | Daily use — recommended | [kyth-live-latest.iso](https://pub-9a3cc72972ea44c4ae7504ee7cda1fa6.r2.dev/kyth-live-latest.iso) |
| **Testing** `testing` | New features, active dev | [kyth-live-testing.iso](https://pub-9a3cc72972ea44c4ae7504ee7cda1fa6.r2.dev/kyth-live-testing.iso) |

Archived releases with checksums and provenance: [Stable](https://github.com/mrtrick37/kyth/releases/tag/iso-latest) · [Testing](https://github.com/mrtrick37/kyth/releases/tag/iso-testing)

> **Minimum requirements:** 8 GB RAM for the live session · USB drive · internet connection during install

<details>
<summary>Verify your download</summary>

Each release ships a SHA-256 checksum, a keyless Cosign signature bundle, and GitHub build provenance. Replace `CHANNEL` with `latest` or `testing`:

```bash
sha256sum -c kyth-live-CHANNEL.iso-CHECKSUM

cosign verify-blob \
  --bundle kyth-live-CHANNEL.iso.bundle \
  --certificate-identity-regexp '^https://github\.com/mrtrick37/kyth/\.github/workflows/build-live-iso\.yml@refs/heads/(main|testing)$' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  kyth-live-CHANNEL.iso

gh attestation verify kyth-live-CHANNEL.iso \
  --repo mrtrick37/kyth \
  --signer-workflow mrtrick37/kyth/.github/workflows/build-live-iso.yml
```

Channel URLs move forward over time. For archival or reproducible use, grab the timestamped immutable release linked from the channel release page.

</details>

---

## Gaming

KythOS doesn't promise every game works on Linux. It makes the games that can work feel less fragile to set up, tune, and recover from.

| | What's included |
|---|---|
| **Launchers** | Steam, Lutris, Heroic Games Launcher |
| **Proton** | ProtonUp-Qt, GE-Proton, protontricks, winetricks, umu-launcher, libFAudio |
| **Overlay & capture** | MangoHud (pre-configured overlay), vkBasalt (sharpening on by default), obs-vkcapture |
| **Performance** | GameMode, Gamescope presets, sched-ext, ananicy-cpp, system76-scheduler |
| **Controllers** | steam-devices, xpadneo, xone, OpenRazer, OpenTabletDriver, Piper, OpenRGB, input-remapper |
| **Wine/Proton defaults** | NTSYNC, fsync/esync fallbacks, DXR, VKD3D feature level 12_2, RADV GPL, Mesa GL threading |
| **Helper commands** | `kyth-gamescope`, `game-performance`, `kyth-scx`, `kyth-smoke-check`, `ujust post-update-check` |

### What to expect

| Usually works great | Worth checking first | Often blocked |
|---|---|---|
| Steam + Proton, native Linux titles, single-player, many co-op games | External launchers, heavy modding, unusual codecs, anti-cheat that changes policy | Games whose publishers require Windows-only kernel anti-cheat |

KythOS keeps that reality visible instead of burying it under hype. The [gaming validation matrix](docs/gaming-validation-matrix.md) and [gaming results](docs/gaming-results/) track what's been tested.

---

## Beyond Gaming

Gaming-first doesn't mean gaming-only.

- **Video & streaming:** OBS Studio with Vulkan/OpenGL capture, Kdenlive, DaVinci Resolve helper
- **Audio:** Audacity, PipeWire tuned for low latency
- **Graphics:** GIMP, full media codec stack including thumbnails
- **Dev tools:** VS Code, GitHub CLI, Docker, Homebrew, Distrobox, QEMU/libvirt, Incus/LXC
- **Productivity:** Brave, KDE Connect, OpenDeck, rclone cloud storage mounts
- **Security:** Optional Kali Linux toolbox container, Wireshark, Burp Suite Community
- **VPN:** Standalone VPN Connect app with GlobalProtect SAML flow

---

## System Hub

<div align="center">
<img src="build_files/branding/kyth-logo-transparent.svg" alt="KythOS mark" width="90">
</div>

**System Hub** is the KythOS control room. First login walks you through setup. After that, it's where you stage updates, check hardware, install tools, and run repairs — all in one place, no terminal required.

| Tab | What it does |
|---|---|
| **Home** | First-run checklist, branch selector, hardware check, firmware check, gaming setup |
| **Updates** | Stage system updates, view what's pending reboot |
| **Hardware** | GPU probe, device info, firmware and driver status |
| **Gaming** | Launchers, Proton tools, MangoHud, vkBasalt, save backup, Windows game-drive migration |
| **Creator** | OBS, Kdenlive, Audacity, GIMP, OpenDeck, DaVinci Resolve helper |
| **Software** | Flatpak apps, Homebrew, Distrobox, common app installs |
| **Network** | VPN Connect, GlobalProtect SAML, SMB shares, rclone cloud storage |
| **Security** | Kali toolbox, Wireshark, Burp Suite Community |
| **Repair** | SELinux relabel, Flatpak repair, diagnostics |

---

## Install

1. Flash the ISO with Balena Etcher, Ventoy, or `dd`.
2. Boot from the USB drive.
3. Click **Install KythOS** on the live desktop.
4. Choose **Erase disk** or **Install alongside**.
5. Set your disk, timezone, hostname, and user account.
6. Start the install — the OS image downloads and writes automatically.
7. Reboot, open System Hub, finish setup.

### Updates & Rollback

```bash
sudo bootc upgrade                                    # stage a new deployment
sudo bootc switch ghcr.io/mrtrick37/kyth:testing     # move to testing channel
sudo bootc switch ghcr.io/mrtrick37/kyth:latest      # move back to stable
```

The previous deployment stays available in the boot menu. Rollback is just choosing it at boot — no recovery USB, no reinstall.

### Advanced Install

```bash
# Install into an existing blank partition from the live ISO
sudo kyth-partition-install /dev/nvme0n1p5

# With explicit EFI System Partition
sudo kyth-partition-install /dev/nvme0n1p5 /dev/nvme0n1p1

# Rebase from any Fedora atomic system
sudo bootc switch ghcr.io/mrtrick37/kyth:latest
```

<details>
<summary>Secure Boot</summary>

The default install uses Fedora-signed kernel artifacts with Fedora's Microsoft-signed shim. Secure Boot works without any extra steps.

If you switch to the **CachyOS kernel variant**, enroll the KythOS Machine Owner Key (MOK) before enabling Secure Boot:

1. Update and reboot with Secure Boot still disabled:
   ```bash
   sudo bootc upgrade && systemctl reboot
   ```
2. Stage the KythOS key:
   ```bash
   ujust enroll-secureboot
   ```
3. At the blue MokManager screen: **Enroll MOK → Continue → Yes → enter your password → reboot**.
4. Enable Secure Boot in firmware.
5. Validate:
   ```bash
   ujust secureboot-status && mokutil --sb-state
   ```

**Common errors:**

| Error | What it means |
|---|---|
| `Selected boot image did not authenticate` | Firmware missing MS UEFI CA key — restore factory Secure Boot keys |
| `vmlinuz not found` | GRUB can't find the live kernel — use a current ISO |
| `bad shim signature` | ISO using wrong boot artifacts — rebuild from the Fedora-kernel image |
| Black screen after "Try KythOS" | Normal — the live entry intentionally uses basic graphics for maximum hardware compatibility |

</details>

---

## Under the Hood

| Layer | Detail |
|---|---|
| Base | Fedora 44 · `ublue-os/kinoite-main:44` |
| Kernel | Fedora-signed by default · optional CachyOS variant (BORE scheduler, BBRv3, NTSYNC, sched-ext) |
| Desktop | KDE Plasma 6 · Wayland-first |
| GPU | Mesa from xxmitsu/mesa-git COPR available for bleeding-edge RADV/RADEONSI |
| Image model | Container image built and distributed through GitHub Container Registry |
| Deployment | Installed and updated atomically with [bootc](https://containers.github.io/bootc/) |
| Installer | Custom PySide6 + Chromium kiosk · `bootc install to-disk` |
| Security | SELinux enforcing · keyless Cosign signing · SBOM attached in GHCR · GitHub provenance attestations |

<details>
<summary>System tuning highlights</summary>

- zram with zstd compression, swappiness tuned for zram, THP set to `madvise`, high `vm.max_map_count`, fast OOM recovery, capped dirty pages
- TCP BBRv3, larger socket buffers, TCP Fast Open, MTU probing, raised inotify limits
- Storage scheduler by device type, weekly `fstrim.timer`, optional weekly `duperemove`, journald caps
- KDE Baloo disabled by default to avoid I/O spikes after large game downloads

</details>

---

## Build Locally

Requirements: `docker`, `podman`, `git`, `just`.

```bash
just build-base           # Layer 1: CachyOS kernel + Fedora Kinoite base
just build                # Full OS image → localhost/kyth:latest
just build-live-iso       # Bootable ISO
just run-live-iso-native  # Boot the ISO in QEMU with SPICE
```

Optional build flags:

```bash
ENABLE_ANANICY=0 ENABLE_SCX=0 just build
```

If Docker returns a permission error after joining the `docker` group, run `newgrp docker`. `just build-base` handles this automatically.

<details>
<summary>Full recipe list</summary>

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

</details>

---

## Active Installs

![KythOS reported user count](docs/metrics/kythos-users.svg)

Estimated via DNF CountMe — aggregate repository metadata requests only. No accounts, no per-machine IDs.

---

## Docs

- [Daily-driver validation](docs/daily-driver-validation.md)
- [Stability principles](docs/stability-principles.md)
- [Gaming validation matrix](docs/gaming-validation-matrix.md)
- [Gaming results](docs/gaming-results/)
- [Modding on KythOS](docs/modding-on-kythos.md)
- [Game save migration](docs/game-save-migration.md)
- [Developer Linux support checklist](docs/developer-linux-support-checklist.md)
- [Why this works better here](docs/works-better-here.md)

---

<div align="center">

Not affiliated with Fedora, Universal Blue, CachyOS, Valve, KDE, or any game publisher.<br>
**KythOS just wants your games to have a good home.**

</div>
