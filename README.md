# Kyth

**Kyth** is a custom atomic desktop Linux image, focused on gaming and development, built for container-native workflows. It leverages Fedora Kinoite, swaps in the CachyOS kernel, and adds a curated set of tools for both gamers and developers.

> ⚠️ Work in progress! ⚠️
> Don't install on anything you care about. Chaotic enthusiasm encouraged.

## Project Highlights

- **Base:** Fedora 43 KDE Plasma (via bootc, ublue-os/kinoite-main)
- **Kernel:** CachyOS (BORE scheduler, sched-ext, BBRv3, NTSYNC)
- **Theme:** Breeze Dark
- **Browser:** Brave
- **Gaming:** Steam, Lutris, GameMode, gamescope, mangohud, vkBasalt, umu-launcher, winetricks, libFAudio, openxr, xrandr, evtest
- **Dev Tools:** Cockpit, Visual Studio Code, Homebrew, podman-compose/tui/machine, incus/lxc, libvirt/virt-manager/virt-viewer/virt-v2v/QEMU
- **Observability:** bcc, bpftop, bpftrace, tiptop, trace-cmd, sysprof
- **AMD GPU Compute:** rocm-hip, rocm-opencl, rocm-smi
- **Flatpak/KDE:** flatpak-builder, kdeconnect, kdeplasma-addons, rom-properties-kf6

## Repo Structure

```
build_base/              Base image layer (branding, os-release)
build_files/             Main build scripts, kernel swap, package installs
  build.sh               Main build logic
  build-live-iso.sh      Live ISO assembly (squashfs, GRUB2, UEFI/BIOS boot)
  Containerfile.live     Live session container config
disk_config/             Disk image configs (TOML)
iso_overlay/             Branding overlays for installer ISOs
Justfile                 Local build recipes
Containerfile            Main image container config
```

## Build & Install

### Build Locally

Requires: `podman`, `just`, plus ISO tools for live builds (`xorriso`, `squashfs-tools`, `mtools`, `dosfstools`, `grub2-tools-minimal`).

```bash
# Build base layer
just build-base
# Build main image
just build
# Build live desktop ISO
just build-live-iso
# Run live ISO in VM
just run-live-iso
# Build Anaconda installer ISO
just build-iso
# Build QCOW2 VM image
just build-qcow2
```

List all recipes:

```bash
just --list
```

### Install via Live ISO (Recommended)

Boot the live ISO (KDE desktop runs from RAM). Click **Install Kyth** to launch the graphical installer.

Installer steps:
1. Timezone selection (GeoIP auto-detect)
2. Disk selection (auto erase/manual partitioning)
3. Pulls `ghcr.io/mrtrick37/kyth:latest` and installs via `bootc`

GParted is available for partition management.

Download from [GitHub Releases](https://github.com/mrtrick37/kyth/releases) or build locally.

### Rebase from Existing Fedora Atomic System

```bash
bootc switch ghcr.io/mrtrick37/kyth:latest
```

### Traditional Installer ISO

For classic Anaconda installer, use the installer ISO.

## Updates

Update like any bootc system:

```bash
ujust update
# or
bootc upgrade
```

Latest image is published on every push to `main`.

---
### KDE Integrations
- kdeconnect, kdeplasma-addons, rom-properties-kf6

## Installation

### Live ISO (recommended)

Boot the live ISO to try Kyth without installing. The full KDE desktop runs from RAM. Click **Install Kyth** on the desktop to launch the graphical installer.

The installer wizard walks through:
1. **Timezone** — interactive world map with GeoIP auto-detection
2. **Disk selection** — automatic erase-disk mode by default; manual partitioning available
3. **Install** — pulls `ghcr.io/mrtrick37/kyth:latest` and writes it to disk via `bootc`

GParted is available in the live session for pre-install partition management.

Grab the live ISO from [GitHub Releases](https://github.com/mrtrick37/kyth/releases) or build it locally (see below).

### Rebase from an existing Fedora atomic system

```bash
bootc switch ghcr.io/mrtrick37/kyth:latest
```

### Installer ISO

For a traditional Anaconda installer experience, use the installer ISO instead.

## Building Locally

Requires `podman`, `just`.

```bash
# 1. Build the base layer
just build-base

# 2. Build the main image
just build

# 3a. Build the live desktop ISO
#     Also requires: xorriso squashfs-tools mtools dosfstools grub2-tools-minimal
just build-live-iso

# 3b. Run the live ISO in a VM (UEFI, web UI)
just run-live-iso

# 3c. Build the Anaconda installer ISO
just build-iso

# 3d. Build a QCOW2 VM image
just build-qcow2
```

```bash
# All recipes
just --list
```

## Project Structure

```
build_base/              Base image layer (pulls kinoite-main:43, applies branding)
Containerfile            Main image (runs build_files/build.sh on top of base)
build_files/
  build.sh               Kernel swap, package installs, branding, tweaks
  Containerfile.live     Live ISO variant (adds live session, Calamares installer)
  build-live-iso.sh      Assembles the live ISO (squashfs + GRUB2 + UEFI/BIOS boot)
  kyth-calamares-install.sh   Calamares shellprocess: runs bootc install, applies timezone
  kyth-install-launcher       Launches Calamares as root from the live desktop
  kyth-install.sh       Fallback terminal installer
  calamares/             Calamares wizard config (settings, modules, branding)
disk_config/
  iso-kde.toml           BIB config for the Anaconda KDE installer ISO
  iso.toml               BIB config for the Anaconda installer ISO
  disk.toml              BIB config for qcow2/raw disk images
iso_overlay/             GRUB/isolinux/os-release branding for installer ISOs
Justfile                 Local build recipes
.github/workflows/       CI: builds and publishes the container image
```

## Updates

Once installed, Kyth updates like any bootc system:

```bash
ujust update
# or
bootc upgrade
```

Updates pull the latest image from `ghcr.io/mrtrick37/kyth:latest`. The CI rebuilds and publishes a fresh image (including all upstream package updates) on every push to `main`.

## Why

Stock Kinoite is great. I wanted my own thing. [Universal Blue](https://universal-blue.org/) and [Bazzite](https://bazzite.gg/) showed that rolling your own atomic image is reasonable. So here we are.

---

*Kyth is not affiliated with Universal Blue, Fedora, CachyOS, or anyone who actually knows what they're doing.*
