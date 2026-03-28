# Rebase to a different Kyth image.
# Usage:
#   ujust rebase kyth:stable
#   ujust rebase kyth:testing
#   ujust rebase kyth:latest
#   ujust rebase                   (defaults to kyth:latest)
#
# Short form "kyth:<tag>" is expanded to ghcr.io/mrtrick37/kyth:<tag>.
# A full image reference (containing '/') is used as-is.

[group('Kyth')]
rebase image_ref="kyth:latest":
    #!/usr/bin/env bash
    set -euo pipefail
    ref="{{ image_ref }}"
    # Expand short form: "kyth:tag" or "kyth" → "ghcr.io/mrtrick37/kyth:tag"
    if [[ "$ref" != *"/"* ]]; then
        ref="ghcr.io/mrtrick37/${ref}"
    fi
    # Default to :latest if no tag was given
    if [[ "$ref" != *":"* ]]; then
        ref="${ref}:latest"
    fi
    echo "Rebasing to: ${ref}"
    echo "This will take effect on next reboot."
    sudo bootc switch "${ref}"

# Run a game or app with the temporary performance profile wrapper.
[group('Kyth')]
game-performance +args:
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/bin/game-performance {{ args }}

# Set desktop/system performance mode.

# Modes: gaming, performance, balanced, powersave, status
[group('Kyth')]
performance-mode mode="status":
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/bin/kyth-performance-mode "{{ mode }}"

# Run a command with a named temporary profile.
[group('Kyth')]
game-performance-profile profile +args:
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/bin/game-performance --profile "{{ profile }}" {{ args }}

# Run a game or app inside gamescope (adaptive sync + frame pacing, no HDR).
# Useful even without HDR: better VRR, FSR upscaling, frame limiter.
# Usage: ujust gamescope -- %command%
#        ujust gamescope -W 2560 -H 1440 -r 165 -- %command%
# Extra gamescope flags can be passed before the -- separator.
[group('Kyth')]
gamescope +args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec gamescope \
        --adaptive-sync \
        {{ args }}

# Run a game or app inside gamescope with HDR enabled.
# Requires an HDR-capable display and a Wayland session.
# Note: --hdr-itm-enable (SDR→HDR tone mapping) is intentionally omitted —
#       it makes SDR content look over-saturated. Add it manually if you want it:
#       ujust game-hdr --hdr-itm-enable -- %command%
# Usage: ujust game-hdr -- %command%
#        ujust game-hdr -W 2560 -H 1440 -- %command%
[group('Kyth')]
game-hdr +args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec gamescope \
        --hdr-enabled \
        --adaptive-sync \
        {{ args }}

# Run an OpenGL app through Zink.
[group('Kyth')]
zink-run +args:
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/bin/zink-run {{ args }}

# Print a short Kyth system/kernel tuning summary.
[group('Kyth')]
kerver:
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/bin/kyth-kerver

# Print a paste-friendly system support snapshot.
[group('Kyth')]
device-info:
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/bin/kyth-device-info

# Install LACT from Flathub on an immutable system.
[group('Kyth')]
install-lact:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v flatpak >/dev/null 2>&1; then
        echo "flatpak is not available on this system." >&2
        exit 1
    fi
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub io.github.ilya_zlobintsev.LACT
    echo
    echo "LACT installed."
    echo "Launch it from the app launcher."
    echo "If you want overclocking/undervolting on AMD, review the official LACT Atomic guidance first."

# Install BoxBuddy (distrobox GUI) from Flathub.
[group('Kyth')]
install-boxbuddy:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v flatpak >/dev/null 2>&1; then
        echo "flatpak is not available on this system." >&2
        exit 1
    fi
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub io.github.dvlv.boxbuddyrs
    echo
    echo "BoxBuddy installed. Launch it from the app launcher to manage your distrobox containers."

# Download and install the latest GE-Proton to /var/lib/kyth/ge-proton/.
[group('Kyth')]
update-ge-proton:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo /usr/bin/kyth-ge-proton-update

# Set up Waydroid (Android in a container) on Kyth.
#
# First run:  installs the waydroid package via rpm-ostree, then prompts for a reboot.
# Second run: downloads the Android system image and starts the container service.
#
# Usage:
#   ujust setup-waydroid            # vanilla AOSP (no Google Play)
#   ujust setup-waydroid microg     # with MicroG (open-source Play Services substitute)
[group('Kyth')]
setup-waydroid image="vanilla":
    #!/usr/bin/env bash
    set -euo pipefail

    image="{{ image }}"
    case "${image}" in
        vanilla|microg) ;;
        *)
            echo "Unknown image type: ${image}" >&2
            echo "Valid options: vanilla (default), microg" >&2
            exit 1
            ;;
    esac

    # ── Step 1: install waydroid if it's not layered yet ─────────────────────
    if ! command -v waydroid >/dev/null 2>&1; then
        echo "Waydroid is not installed — layering it via rpm-ostree."
        echo "A reboot is required to activate the new layer."
        echo
        sudo rpm-ostree install --idempotent waydroid
        echo
        echo "Done. Reboot and then run 'ujust setup-waydroid' again to finish setup."
        exit 0
    fi

    # ── Step 2: check binder is available ────────────────────────────────────
    if [[ ! -e /dev/binder && ! -e /dev/anbox-binder ]]; then
        echo "WARNING: /dev/binder not found." >&2
        echo "Loading binder_linux kernel module..." >&2
        sudo modprobe binder_linux devices="binder,hwbinder,vndbinder" || {
            echo "ERROR: Could not load binder_linux. Waydroid requires binder support." >&2
            echo "The CachyOS kernel ships binder_linux — if you see this, please report it." >&2
            exit 1
        }
    fi

    # ── Step 3: initialise if not already done ───────────────────────────────
    if [[ ! -f /var/lib/waydroid/images/system.img ]]; then
        echo "Initialising Waydroid (downloading Android image ~600 MB)..."
        echo "Image type: ${image}"
        echo
        case "${image}" in
            microg)
                sudo waydroid init -s MICROG
                ;;
            *)
                sudo waydroid init
                ;;
        esac
    else
        echo "Waydroid image already present — skipping download."
    fi

    # ── Step 4: enable and start the container service ───────────────────────
    echo "Enabling waydroid-container service..."
    sudo systemctl enable --now waydroid-container

    echo
    echo "Waydroid is ready."
    echo
    echo "  waydroid show-full-ui              # launch Android full-screen"
    echo "  waydroid app install <file.apk>    # sideload an APK"
    echo "  waydroid session stop              # end the Android session"
    echo "  sudo systemctl stop waydroid-container  # shut down the container"
    echo
    if [[ "${image}" == "vanilla" ]]; then
        echo "Tip: rerun with 'ujust setup-waydroid microg' to reinstall with"
        echo "MicroG for app store access (Aurora Store, F-Droid)."
    fi

# Install Heroic Games Launcher — Epic Games, GOG and Amazon Games library.
[group('Kyth')]
install-heroic:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub com.heroicgameslauncher.hgl
    echo
    echo "Heroic installed. Launch it from the app menu."

# Install OBS Studio — screen recording and live streaming.
[group('Kyth')]
install-obs:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub com.obsproject.Studio
    echo
    echo "OBS Studio installed. Launch it from the app menu."
    echo "Tip: run OBS under Wayland with: OBS_USE_EGL=1 obs"

# Install the Itch.io desktop app — indie game store and library manager.
[group('Kyth')]
install-itch:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub io.itch.itch
    echo
    echo "Itch.io installed. Launch it from the app menu."

# Install RetroArch — multi-system emulator frontend (NES, SNES, PS1, N64, ...).
[group('Kyth')]
install-retroarch:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub org.libretro.RetroArch
    echo
    echo "RetroArch installed. Launch it from the app menu."
    echo "Tip: download cores from inside RetroArch: Main Menu → Load Core → Download a Core."

# Install Piper — GUI for configuring gaming mice (DPI, buttons, LEDs).
# Requires libratbag (ratbagd daemon) for device communication.
# A reboot is needed to activate the rpm-ostree layer; ratbagd is then
# enabled automatically on first use via D-Bus activation.
[group('Kyth')]
install-piper:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v piper >/dev/null 2>&1; then
        echo "Piper is already installed."
        echo "Launch it from the app menu, or run: piper"
        exit 0
    fi
    echo "Installing piper and libratbag via rpm-ostree..."
    sudo rpm-ostree install --idempotent piper libratbag
    echo
    echo "Done. Reboot to activate, then launch Piper from the app menu."
    echo "ratbagd starts automatically via D-Bus when Piper opens."

# Install OpenRGB — unified RGB lighting control for motherboards, RAM, GPUs,
# fans and peripherals. Installed natively (not Flatpak) so it can reach
# SMBus/i2c controllers that Flatpak sandboxing blocks.
[group('Kyth')]
install-openrgb:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v openrgb >/dev/null 2>&1; then
        echo "OpenRGB is already installed."
        echo "Launch it from the app menu, or run: openrgb"
        exit 0
    fi
    echo "Installing openrgb via rpm-ostree..."
    sudo rpm-ostree install --idempotent openrgb
    echo
    echo "Done. Reboot to activate."
    echo
    echo "Tip: to let OpenRGB talk to SMBus devices (RAM, some motherboard headers)"
    echo "without running as root, add yourself to the 'i2c' group after rebooting:"
    echo "  sudo usermod -aG i2c \$USER   (then log out and back in)"

# Check for and apply firmware updates via fwupd.
[group('Kyth')]
firmware-update:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Refreshing firmware metadata..."
    fwupdmgr refresh --force
    echo
    echo "Checking for firmware updates..."
    fwupdmgr get-updates || true
    echo
    echo "Applying available firmware updates..."
    fwupdmgr update
