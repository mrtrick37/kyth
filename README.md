# Forge

> **⚠️ Don't install this on anything you care about. You've been warned. Proceed with chaotic enthusiasm.**

Forge is a custom atomic desktop Linux image built on [Universal Blue Kinoite](https://universal-blue.org/) (Fedora 43, KDE Plasma). It's an opinionated gaming and development workstation OS — immutable, container-native, and perpetually a work in progress.

## What's in it

**Base:** `ghcr.io/ublue-os/kinoite-main:43` — Fedora 43 KDE Plasma via bootc
**Kernel:** [CachyOS kernel](https://github.com/CachyOS/linux-cachyos) — BORE scheduler, sched-ext, BBRv3, NTSYNC
**Theme:** Breeze Dark by default
**Browser:** Brave

### Gaming
- Steam, Lutris, GameMode
- gamescope, mangohud (x86_64 + i686), vkBasalt (x86_64 + i686)
- umu-launcher, winetricks (always latest from upstream)
- libFAudio, libobs_vkcapture/glcapture, openxr, xrandr, evtest

### Developer Tooling
- **Cockpit** — machines, podman, networkmanager, ostree, selinux, storaged
- **Visual Studio Code** — repo added, disabled by default; enable with `--enablerepo=code`
- **Homebrew** — system-wide install at `/home/linuxbrew/.linuxbrew`; any wheel user can run `brew`
- **podman-compose**, **podman-tui**, **podman-machine**
- **incus**, **lxc** — system containers
- **libvirt**, **virt-manager**, **virt-viewer**, **virt-v2v**, **QEMU** — full VM stack
- **bcc**, **bpftop**, **bpftrace**, **tiptop**, **trace-cmd**, **sysprof** — system observability
- **rocm-hip**, **rocm-opencl**, **rocm-smi** — AMD GPU compute
- **flatpak-builder**, **git-subtree**, **git-svn**, **p7zip**, **tmux**

### KDE Integrations
- kdeconnect, kdeplasma-addons, rom-properties-kf6

## Installation

### Rebase from an existing Fedora atomic system

```bash
bootc switch ghcr.io/mrtrick37/forge:latest
```

### Live ISO

Boot the live ISO to try Forge without installing. The full KDE desktop with all packages runs from RAM. Click **Install Forge** on the desktop to install.

See [Building Locally](#building-locally) to build the live ISO, or grab it from [GitHub Releases](https://github.com/mrtrick37/forge/releases).

### Installer ISO

For a traditional installer experience (Anaconda), use the installer ISO instead of the live ISO.

## Building Locally

Requires `podman`, `just`.

```bash
# 1. Build the base layer
just build-base

# 2. Build the main image
just build

# 3a. Build the live desktop ISO (boots to full KDE; "Install Forge" icon on desktop)
#     Also requires: xorriso squashfs-tools mtools dosfstools
just build-live-iso

# 3b. Build the Anaconda installer ISO instead
just build-iso

# 3c. Build a QCOW2 VM image
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
  Containerfile.live     Live ISO variant (adds dracut-live, liveuser, auto-login)
  build-live-iso.sh      Builds the live ISO from the container image
  forge-install.sh       bootc-based installer launched from the live ISO desktop
disk_config/
  forge-install.ks       Anaconda kickstart used by the live ISO installer
  iso-kde.toml           BIB config for the Anaconda KDE installer ISO
  iso.toml               BIB config for the Anaconda installer ISO
  disk.toml              BIB config for qcow2/raw disk images
iso_overlay/             GRUB/isolinux/os-release branding for installer ISOs
Justfile                 Local build recipes
.github/workflows/       CI: builds and publishes the container image
```

## Updates

Once installed, Forge updates like any bootc system:

```bash
bootc upgrade
```

Or let it update automatically via the `bootc-fetch-apply-updates` timer.

## Why

Stock Kinoite is great. I wanted my own thing. [Universal Blue](https://universal-blue.org/) and [Bazzite](https://bazzite.gg/) showed that rolling your own atomic image is reasonable. So here we are.

---

*Forge is not affiliated with Universal Blue, Fedora, CachyOS, or anyone who actually knows what they're doing.*
