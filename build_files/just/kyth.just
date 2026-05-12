# Upgrade the OS and Flatpak apps.
# Pulls the latest KythOS image via bootc and updates all Flatpak apps.

# The OS update is staged — a reboot is required to activate it.
[group('KythOS')]
upgrade:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "━━━ KythOS upgrade ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo

    # ── Check for rpm-ostree layers ───────────────────────────────────────────
    # bootc upgrade fails if any packages have been layered via rpm-ostree.
    # Detect this upfront and give a clear fix rather than a cryptic error.
    layered=$(rpm-ostree status --json 2>/dev/null \
        | python3 -c "import sys,json; d=json.load(sys.stdin).get('deployments', [{}])[0]; pkgs=d.get('requested-local-packages', []) + d.get('layered-commit-packages', []); print(' '.join(pkgs) if pkgs else '')" 2>/dev/null || true)

    if [[ -n "${layered}" ]]; then
        echo "  ERROR: local rpm-ostree packages are layered:" >&2
        echo "    ${layered}" >&2
        echo >&2
        echo "  These conflict with bootc upgrades. To fix:" >&2
        echo "    rpm-ostree reset     # removes all layered packages" >&2
        echo "    ujust upgrade        # then retry" >&2
        echo >&2
        echo "  If you still need those packages, install them via Flatpak instead." >&2
        exit 1
    fi

    # ── OS update via bootc ───────────────────────────────────────────────────
    echo "── OS (bootc) ──────────────────────────────────────────────────────"
    booted_digest=$(bootc status --format json 2>/dev/null \
        | python3 -c "import sys,json; s=json.load(sys.stdin); \
          print(s.get('status',{}).get('booted',{}).get('image',{}) \
                 .get('imageDigest','unknown'))" 2>/dev/null || echo "unknown")

    sudo bootc upgrade

    staged_digest=$(bootc status --format json 2>/dev/null \
        | python3 -c "import sys,json; s=json.load(sys.stdin); \
          print(s.get('status',{}).get('staged',{}).get('image',{}) \
                 .get('imageDigest','') or '')" 2>/dev/null || echo "")

    if [[ -n "${staged_digest}" && "${staged_digest}" != "${booted_digest}" ]]; then
        os_updated=1
        echo "  ✓ New image staged and ready."
    else
        os_updated=0
        echo "  ✓ Already up to date."
    fi
    echo

    # ── Flatpak updates ───────────────────────────────────────────────────────
    echo "── Flatpak apps ────────────────────────────────────────────────────"
    if command -v flatpak >/dev/null 2>&1; then
        flatpak update -y
    else
        echo "  flatpak not available — skipping."
    fi
    echo

    # ── Summary ───────────────────────────────────────────────────────────────
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [[ "${os_updated}" -eq 1 ]]; then
        echo "  OS update staged. Reboot when ready to apply it:"
        echo "    systemctl reboot"
    else
        echo "  Everything is up to date."
    fi

# Show the currently booted image, any staged update, and rollback availability.
[group('KythOS')]
status:
    #!/usr/bin/env bash
    set -euo pipefail
    bootc status

# Rebase to a different KythOS image.
# Usage:
#   ujust rebase kyth:stable
#   ujust rebase kyth:testing
#   ujust rebase kyth:latest
#   ujust rebase                   (defaults to kyth:latest)
#
# Short form "kyth:<tag>" is expanded to ghcr.io/mrtrick37/kyth:<tag>.
# A full image reference (containing '/') is used as-is.

[group('KythOS')]
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

# Switch to a KythOS release channel.
# Channels:
#   stable   — :latest tag (main branch, recommended)
#   testing  — :testing tag (dev branch, may be unstable)
# Usage:
#   ujust switch-channel           (defaults to stable)

# ujust switch-channel testing
[group('KythOS')]
switch-channel channel="stable":
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{ channel }}" in
        stable|latest) tag="latest" ;;
        testing)       tag="testing" ;;
        *)
            echo "Unknown channel: {{ channel }}" >&2
            echo "Valid channels: stable (default), testing" >&2
            exit 1
            ;;
    esac
    echo "Switching to KythOS :${tag}..."
    sudo bootc switch "ghcr.io/mrtrick37/kyth:${tag}"
    echo "Channel switch staged. Reboot to activate."

# Run a game or app with the temporary performance profile wrapper.
[group('KythOS')]
game-performance +args:
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/bin/game-performance {{ args }}

# Set desktop/system performance mode.

# Modes: max, gaming, performance, balanced, powersave, status
[group('KythOS')]
performance-mode mode="status":
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/bin/kyth-performance-mode "{{ mode }}"

# Quick shortcut: switch to gaming mode (EPP=performance, half-speed animations, no blur).
[group('KythOS')]
gaming-mode:
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/bin/kyth-performance-mode gaming

# Quick shortcut: restore balanced mode (EPP=balance_performance, full animations).
[group('KythOS')]
balanced-mode:
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/bin/kyth-performance-mode balanced

# Run a command with a named temporary profile.
[group('KythOS')]
game-performance-profile profile +args:
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/bin/game-performance --profile "{{ profile }}" {{ args }}

# Run a game or app inside gamescope (adaptive sync + frame pacing, no HDR).
# Useful even without HDR: better VRR, FSR upscaling, frame limiter.
# Usage: ujust gamescope -- %command%
#        ujust gamescope -W 2560 -H 1440 -r 165 -- %command%

# Extra gamescope flags can be passed before the -- separator.
[group('KythOS')]
gamescope +args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec /usr/bin/kyth-gamescope quality {{ args }}

# Run a game or app inside gamescope with HDR enabled.
# Requires an HDR-capable display and a Wayland session.
# Note: --hdr-itm-enable (SDR→HDR tone mapping) is intentionally omitted —
#       it makes SDR content look over-saturated. Add it manually if you want it:
#       ujust game-hdr --hdr-itm-enable -- %command%
# Usage: ujust game-hdr -- %command%

# ujust game-hdr -W 2560 -H 1440 -- %command%
[group('KythOS')]
game-hdr +args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec /usr/bin/kyth-gamescope hdr {{ args }}

# Run a game or app with KythOS Gamescope presets.
# Usage:
#   ujust game-scope quality -- %command%
#   ujust game-scope hdr --fps 120 -- %command%
#   ujust game-scope sharp --fsr --nested 1920x1080 --output 2560x1440 -- %command%
[group('KythOS')]
game-scope preset="quality" +args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec /usr/bin/kyth-gamescope "{{ preset }}" {{ args }}

# Show or change the active sched-ext scheduler.
# Usage: ujust scx status | ujust scx list | ujust scx set lavd
[group('KythOS')]
scx action="status" scheduler="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -n "{{ scheduler }}" ]]; then
        /usr/bin/kyth-scx "{{ action }}" "{{ scheduler }}"
    else
        /usr/bin/kyth-scx "{{ action }}"
    fi

# Run an OpenGL app through Zink.
[group('KythOS')]
zink-run +args:
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/bin/zink-run {{ args }}

# Print a short KythOS system/kernel tuning summary.
[group('KythOS')]
kerver:
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/bin/kyth-kerver

# Print a paste-friendly system support snapshot.
[group('KythOS')]
device-info:
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/bin/kyth-device-info

# Install LACT from Flathub on an immutable system.
[group('KythOS')]
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

# Install GOverlay from Flathub for MangoHud, vkBasalt, and OptiScaler tuning.
[group('KythOS')]
install-goverlay:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub io.github.benjamimgois.goverlay
    echo
    echo "GOverlay installed. Launch it from the app menu."

# Install MangoJuice from Flathub for lightweight MangoHud configuration.
[group('KythOS')]
install-mangojuice:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub io.github.radiolamp.mangojuice
    echo
    echo "MangoJuice installed. Launch it from the app menu."

# Launch CoreCtrl if the image includes it.
[group('KythOS')]
corectrl:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v corectrl >/dev/null 2>&1; then
        echo "CoreCtrl is not installed in this image." >&2
        echo "If Fedora packaging skipped it during build, use LACT instead: ujust install-lact" >&2
        exit 1
    fi
    exec corectrl

# Install BoxBuddy (distrobox GUI) from Flathub.
[group('KythOS')]
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

# Set up a Kali Linux security toolbox via distrobox.
#
# The container runs --privileged --network host so security tools (nmap,
# zenmap, wireshark, aircrack-ng, etc.) have full hardware, device, and raw
# socket access on the real host network interfaces.
#
# Usage:
#   ujust setup-kali-box              # headless CLI tools only (kali-linux-headless)
#   ujust setup-kali-box gui          # headless + GUI tools (kali-linux-default)
#   ujust setup-kali-box everything   # every available Kali tool (WARNING: 15-20 GB+)
#
# After setup: distrobox enter kali
[group('KythOS')]
setup-kali-box tools="headless":
    #!/usr/bin/env bash
    set -euo pipefail

    tools="{{ tools }}"
    case "${tools}" in
        headless)   meta="kali-linux-headless"   ;;
        gui)        meta="kali-linux-default"    ;;
        everything) meta="kali-linux-everything" ;;
        *)
            echo "Unknown tools option: ${tools}" >&2
            echo "Valid options: headless (default), gui, everything" >&2
            exit 1
            ;;
    esac

    if [[ "${tools}" == "everything" ]]; then
        echo "━━━ WARNING ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  kali-linux-everything installs every available Kali tool."
        echo "  Expect 15–20 GB or more of downloads and a very long install time."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo
    fi

    if distrobox list --no-color 2>/dev/null | grep -q '^kali\b'; then
        echo "Kali box already exists. To enter it: distrobox enter kali"
        exit 0
    fi

    echo "━━━ Setting up Kali Linux toolbox ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Image:    kalilinux/kali-rolling"
    echo "  Package:  ${meta}"
    echo

    # --network host: security tools (nmap, wireshark, aircrack-ng, etc.) need raw
    # socket access and must see real network interfaces, not a container namespace.
    distrobox create --image kalilinux/kali-rolling --name kali --yes \
        --additional-flags "--privileged --network host"
    distrobox enter kali -- sudo apt-get install -y "${meta}"

    # Grant passwordless sudo inside the container so root-requiring tools
    # (nmap, wireshark, aircrack-ng, etc.) launch from the app menu without a
    # polkit dialog that can't reach the host agent from inside distrobox.
    distrobox enter kali -- bash -c "
        echo '${USER} ALL=(root) NOPASSWD: ALL' \
            | sudo tee /etc/sudoers.d/kali-user-nopasswd > /dev/null
        sudo chmod 0440 /etc/sudoers.d/kali-user-nopasswd
    " && echo "  Configured passwordless sudo for security tools in kali." || true

    if [[ "${tools}" == "gui" || "${tools}" == "everything" ]]; then
        echo
        echo "── Exporting Kali GUI apps to application launcher ─────────────────"

        # Export every .desktop file found in the kali container.
        # distrobox-export is run from *inside* the container; it writes
        # host-side .desktop wrappers to ~/.local/share/applications/.
        distrobox enter kali -- bash -c '
            exported=0
            while IFS= read -r -d "" f; do
                [[ -f "$f" ]] || continue
                app=$(basename "$f" .desktop)
                distrobox-export --app "$app" 2>/dev/null && exported=$((exported+1)) || true
            done < <(find /usr/share/applications -name "*.desktop" -print0)
            echo "  Exported ${exported} desktop entries."
        '

        # Patch the exported wrappers so KDE groups them under "Security Tools".
        # Identify kali-exported entries by the "--name kali" distrobox argument
        # that distrobox-export injects into each Exec= line.
        _appdir="${HOME}/.local/share/applications"
        _patched=0
        for _f in "${_appdir}/"*.desktop; do
            [[ -f "${_f}" ]] || continue
            if grep -qE '\-\-name[[:space:]]+kali|-n[[:space:]]+kali' "${_f}" 2>/dev/null; then
                if grep -q '^Categories=' "${_f}"; then
                    sed -i 's|^Categories=.*|Categories=X-KythSecurity;|' "${_f}"
                else
                    printf '\nCategories=X-KythSecurity;\n' >> "${_f}"
                fi
                _patched=$((_patched+1))
            fi
        done
        echo "  Set Categories=X-KythSecurity; on ${_patched} entries."
        # Strip visibility guards so entries appear in the KDE launcher.
        for _f in "${_appdir}/"*.desktop; do
            [[ -f "${_f}" ]] || continue
            grep -qE '\-\-name[[:space:]]+kali|-n[[:space:]]+kali' "${_f}" 2>/dev/null || continue
            sed -i '/^NoDisplay[[:space:]]*=[[:space:]]*true/Id' "${_f}"
            sed -i '/^OnlyShowIn[[:space:]]*=/d' "${_f}"
            sed -i '/^NotShowIn[[:space:]]*=/d' "${_f}"
        done
        # Replace pkexec/kdesu/gksu with sudo -E for all exported kali apps.
        # polkit agents are unreachable from inside the container on Wayland;
        # passwordless sudo (configured above) is the correct mechanism here.
        _fixed_priv=0
        for _f in "${_appdir}/"*.desktop; do
            [[ -f "${_f}" ]] || continue
            grep -qE '\-\-name[[:space:]]+kali|-n[[:space:]]+kali' "${_f}" 2>/dev/null || continue
            if grep -qE 'pkexec|kdesu|gksu|gksudo' "${_f}" 2>/dev/null; then
                sed -i -E 's/(pkexec|kdesu|gksu|gksudo)[[:space:]]+/sudo -E /g' "${_f}"
                _fixed_priv=$((_fixed_priv+1))
            fi
        done
        [[ "${_fixed_priv}" -gt 0 ]] && echo "  Replaced pkexec/kdesu with sudo -E on ${_fixed_priv} entries."

        # Some tools (zenmap, etc.) declare no pkexec in their Exec= line but
        # self-elevate via pkexec at runtime.  polkit is unreachable from inside
        # the container, so inject sudo -E into the distrobox-enter separator.
        # The pattern ' -- ' only appears once in a distrobox-enter Exec line
        # (as the argument separator), so this replacement is unambiguous.
        _self_elevate=(zenmap)
        for _tool in "${_self_elevate[@]}"; do
            for _f in "${_appdir}/"*"${_tool}"*.desktop; do
                [[ -f "${_f}" ]] || continue
                grep -qE '\-\-name[[:space:]]+kali|-n[[:space:]]+kali' "${_f}" 2>/dev/null || continue
                grep -q ' sudo ' "${_f}" && continue
                sed -i 's| -- | -- sudo -E |' "${_f}"
                echo "  Injected sudo -E into ${_f##*/}."
            done
        done

        update-desktop-database "${_appdir}" 2>/dev/null || true
        # Rebuild KDE's application-launcher cache (update-desktop-database alone
        # is not enough — KDE maintains its own ksycoca index).
        kbuildsycoca6 --noincremental 2>/dev/null || true

        echo "  Done — Kali tools should appear under 'Security Tools' in the app launcher."
    fi

    echo
    echo "━━━ Done ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Kali box ready. Enter it with: distrobox enter kali"

# Export Kali Linux GUI apps to the host application launcher.
#
# Re-run this any time you install new GUI tools inside the kali container or
# if the launchers are missing after a fresh setup.  All exported apps are
# placed under the "Security" category so KDE groups them together.
[group('KythOS')]
export-kali-apps:
    #!/usr/bin/env bash
    set -euo pipefail

    if ! distrobox list --no-color 2>/dev/null | grep -q '^kali\b'; then
        echo "No kali container found." >&2
        echo "Run 'ujust setup-kali-box gui' first." >&2
        exit 1
    fi

    echo "━━━ Exporting Kali GUI apps ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Ensure passwordless sudo is configured inside the container so root-requiring
    # tools launched from the app menu don't silently fail on a polkit prompt.
    distrobox enter kali -- bash -c "
        echo '${USER} ALL=(root) NOPASSWD: ALL' \
            | sudo tee /etc/sudoers.d/kali-user-nopasswd > /dev/null
        sudo chmod 0440 /etc/sudoers.d/kali-user-nopasswd
    " && echo "  Configured passwordless sudo for security tools in kali." || true

    # Export every .desktop file found in the kali container, including subdirs.
    distrobox enter kali -- bash -c '
        exported=0
        while IFS= read -r -d "" f; do
            [[ -f "$f" ]] || continue
            app=$(basename "$f" .desktop)
            distrobox-export --app "$app" 2>/dev/null && exported=$((exported+1)) || true
        done < <(find /usr/share/applications -name "*.desktop" -print0)
        echo "  Exported ${exported} desktop entries."
    '

    # Patch exported wrappers to use the Security category so KDE groups them.
    _appdir="${HOME}/.local/share/applications"
    _patched=0
    for _f in "${_appdir}/"*.desktop; do
        [[ -f "${_f}" ]] || continue
        if grep -qE '\-\-name[[:space:]]+kali|-n[[:space:]]+kali' "${_f}" 2>/dev/null; then
            if grep -q '^Categories=' "${_f}"; then
                sed -i 's|^Categories=.*|Categories=X-KythSecurity;|' "${_f}"
            else
                printf '\nCategories=X-KythSecurity;\n' >> "${_f}"
            fi
            _patched=$((_patched+1))
        fi
    done

    echo "  Set Categories=X-KythSecurity; on ${_patched} entries."
    # Strip visibility guards so entries appear in the KDE launcher.
    for _f in "${_appdir}/"*.desktop; do
        [[ -f "${_f}" ]] || continue
        grep -qE '\-\-name[[:space:]]+kali|-n[[:space:]]+kali' "${_f}" 2>/dev/null || continue
        sed -i '/^NoDisplay[[:space:]]*=[[:space:]]*true/Id' "${_f}"
        sed -i '/^OnlyShowIn[[:space:]]*=/d' "${_f}"
        sed -i '/^NotShowIn[[:space:]]*=/d' "${_f}"
    done
    # Replace pkexec/kdesu/gksu with sudo -E for all exported kali apps.
    _fixed_priv=0
    for _f in "${_appdir}/"*.desktop; do
        [[ -f "${_f}" ]] || continue
        grep -qE '\-\-name[[:space:]]+kali|-n[[:space:]]+kali' "${_f}" 2>/dev/null || continue
        if grep -qE 'pkexec|kdesu|gksu|gksudo' "${_f}" 2>/dev/null; then
            sed -i -E 's/(pkexec|kdesu|gksu|gksudo)[[:space:]]+/sudo -E /g' "${_f}"
            _fixed_priv=$((_fixed_priv+1))
        fi
    done
    [[ "${_fixed_priv}" -gt 0 ]] && echo "  Replaced pkexec/kdesu with sudo -E on ${_fixed_priv} entries."

    # Some tools (zenmap, etc.) declare no pkexec in their Exec= line but
    # self-elevate via pkexec at runtime.  polkit is unreachable from inside
    # the container, so inject sudo -E into the distrobox-enter separator.
    _self_elevate=(zenmap)
    for _tool in "${_self_elevate[@]}"; do
        for _f in "${_appdir}/"*"${_tool}"*.desktop; do
            [[ -f "${_f}" ]] || continue
            grep -qE '\-\-name[[:space:]]+kali|-n[[:space:]]+kali' "${_f}" 2>/dev/null || continue
            grep -q ' sudo ' "${_f}" && continue
            sed -i 's| -- | -- sudo -E |' "${_f}"
            echo "  Injected sudo -E into ${_f##*/}."
        done
    done

    update-desktop-database "${_appdir}" 2>/dev/null || true
    # Rebuild KDE's application-launcher cache (update-desktop-database alone
    # is not enough — KDE maintains its own ksycoca index).
    kbuildsycoca6 --noincremental 2>/dev/null || true

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Kali tools are now exported to the application launcher under 'Security Tools'."

# Download and install the latest GE-Proton to /var/lib/kyth/ge-proton/.
[group('KythOS')]
update-ge-proton:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo /usr/bin/kyth-ge-proton-update

# Create a Fedora development container for KythOS work.
#
# This is intentionally self-contained so it does not depend on any imported
# justfiles that may not exist on end-user systems.
#
# It also installs VS Code from Flatpak when missing, since the RPM is no
# longer baked into KythOS images.
[group('KythOS')]
setup-kyth-dev-box:
    #!/usr/bin/env bash
    set -euo pipefail

    box="kyth-dev"
    image="${KYTH_DEV_IMAGE:-registry.fedoraproject.org/fedora-toolbox:44}"
    packages=(
        git gh just jq yq skopeo podman buildah
        python3 python3-pip python3-virtualenv
        ShellCheck shfmt ripgrep fd-find
        vim-enhanced neovim
    )

    if ! command -v distrobox >/dev/null 2>&1; then
        echo "ERROR: distrobox is not installed." >&2
        echo "Install it first, then rerun this recipe." >&2
        exit 1
    fi

    if ! flatpak info com.visualstudio.code >/dev/null 2>&1; then
        echo "VS Code not found. Installing com.visualstudio.code from Flathub..."
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        flatpak install -y flathub com.visualstudio.code
    else
        echo "VS Code already installed."
    fi
    kyth-vscode-wallet

    if distrobox list --no-color 2>/dev/null | grep -q "^${box}\b"; then
        echo "${box} already exists."
        echo "Enter it with: distrobox enter ${box}"
        exit 0
    fi

    echo "━━━ Setting up KythOS development box ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Image: ${image}"
    echo
    distrobox create --image "${image}" --name "${box}" --yes
    distrobox enter "${box}" -- sudo dnf install -y "${packages[@]}"
    echo
    echo "Done. Enter it with: distrobox enter ${box}"
    echo "VS Code launch command: flatpak run com.visualstudio.code"

# Install VS Code as a Flatpak instead of baking the Microsoft RPM into KythOS.
[group('KythOS')]
install-vscode:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub com.visualstudio.code
    kyth-vscode-wallet
    echo
    echo "VS Code installed. Launch it from the app menu."

# Set up Waydroid (Android in a container) on KythOS.
#
# First run:  installs the waydroid package via rpm-ostree, then prompts for a reboot.
# Second run: downloads the Android system image and starts the container service.
#
# Usage:
#   ujust setup-waydroid            # vanilla AOSP (no Google Play)

# ujust setup-waydroid microg     # with MicroG (open-source Play Services substitute)
[group('KythOS')]
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

# Install Steam — Valve's gaming platform with Proton for Windows games.
[group('KythOS')]
install-steam:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub com.valvesoftware.Steam
    echo
    echo "Steam installed. Launch it from the app menu."

# Install Lutris — open gaming platform for Battle.net, EA App, Ubisoft Connect, and more.
[group('KythOS')]
install-lutris:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub net.lutris.Lutris
    echo
    echo "Lutris installed. Launch it from the app menu."

# Install Heroic Games Launcher — Epic Games, GOG and Amazon Games library.
[group('KythOS')]
install-heroic:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub com.heroicgameslauncher.hgl
    echo
    echo "Heroic installed. Launch it from the app menu."

# Install or reinstall umu-launcher (umu-run) from the latest GitHub release.
# Run this if Lutris says "Install umu to use Proton".
[group('KythOS')]
install-umu:
    #!/usr/bin/env bash
    set -euo pipefail
    UMU_REPO_API="https://api.github.com/repos/Open-Wine-Components/umu-launcher/releases/latest"
    TMPDIR_UMU=$(mktemp -d)
    trap 'rm -rf "${TMPDIR_UMU}"' EXIT
    release_json="${TMPDIR_UMU}/release.json"
    echo "Fetching latest umu-launcher release info…"
    curl -fsSL "${UMU_REPO_API}" -o "${release_json}"
    UMU_URL=$(
        grep -oP 'https://[^"]+/releases/download/[^"]+\.tar\.(gz|zst)' "${release_json}" \
        | grep -iv 'source\|src' \
        | head -n1
    ) || true
    if [[ -z "${UMU_URL}" ]]; then
        echo "Could not find a release tarball. Check https://github.com/Open-Wine-Components/umu-launcher/releases" >&2
        exit 1
    fi
    UMU_TARBALL=$(basename "${UMU_URL}")
    echo "Downloading ${UMU_TARBALL}…"
    curl -fsSL "${UMU_URL}" -o "${TMPDIR_UMU}/${UMU_TARBALL}"
    tar -xf "${TMPDIR_UMU}/${UMU_TARBALL}" -C "${TMPDIR_UMU}/"
    UMU_BIN=$(find "${TMPDIR_UMU}" -name 'umu-run' -type f | head -n1)
    if [[ -z "${UMU_BIN}" ]]; then
        echo "umu-run binary not found in archive." >&2
        exit 1
    fi
    sudo install -m 0755 "${UMU_BIN}" /usr/local/bin/umu-run
    UMU_PKGDIR=$(find "${TMPDIR_UMU}" -maxdepth 3 -name 'umu' -type d | grep -v '__pycache__' | head -n1)
    if [[ -n "${UMU_PKGDIR}" ]]; then
        PY_SITEPKG=$(python3 -c "import sysconfig; print(sysconfig.get_paths()['purelib'])")
        sudo mkdir -p "${PY_SITEPKG}"
        sudo cp -r "${UMU_PKGDIR}" "${PY_SITEPKG}/"
    fi
    echo "umu-launcher installed: $(umu-run --version 2>/dev/null || echo 'ok')"

# Open the Lutris one-click installer for Battle.net.
[group('KythOS')]
install-battlenet:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v lutris >/dev/null 2>&1; then
        echo "Lutris is not installed on this system." >&2
        exit 1
    fi
    nohup lutris "lutris:install/battlenet" >/dev/null 2>&1 &
    echo
    echo "Opened the Battle.net installer in Lutris."

# Open the Lutris one-click installer for the Epic Games Launcher.
[group('KythOS')]
install-epic-launcher:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v lutris >/dev/null 2>&1; then
        echo "Lutris is not installed on this system." >&2
        exit 1
    fi

    prefix="$HOME/Games/epic-games-store"
    cache="$HOME/.cache/lutris/installer/epic-games-store"
    timestamp="$(date +%Y%m%d-%H%M%S)"
    for path in "$prefix" "$cache"; do
        if [[ -e "$path" ]]; then
            backup="${path}.bak-${timestamp}"
            mv "$path" "$backup"
            echo "Moved previous Epic installer state to: $backup"
        fi
    done

    nohup lutris "lutris:install/epic-games-store" >/dev/null 2>&1 &
    echo
    echo "Opened the Epic Games Launcher installer in Lutris."

# Open the Lutris one-click installer for the EA App.
[group('KythOS')]
install-ea-app:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v lutris >/dev/null 2>&1; then
        echo "Lutris is not installed on this system." >&2
        exit 1
    fi
    nohup lutris "lutris:ea-app-standard" >/dev/null 2>&1 &
    echo
    echo "Opened the EA App installer in Lutris."

# Open the Lutris one-click installer for Ubisoft Connect.
[group('KythOS')]
install-ubisoft-connect:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v lutris >/dev/null 2>&1; then
        echo "Lutris is not installed on this system." >&2
        exit 1
    fi
    nohup lutris "lutris:ubisoft-connect-latest" >/dev/null 2>&1 &
    echo
    echo "Opened the Ubisoft Connect installer in Lutris."

# Install Prism Launcher — Minecraft with modpacks and multiple instances.
[group('KythOS')]
install-prismlauncher:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub org.prismlauncher.PrismLauncher
    echo
    echo "Prism Launcher installed. Launch it from the app menu."

# Install Bottles — easiest GUI for running standalone Windows .exe/.msi apps.
[group('KythOS')]
install-bottles:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub com.usebottles.bottles
    echo
    echo "Bottles installed. Launch it from the app menu to open .exe or .msi files."

# Install OBS Studio — screen recording and live streaming.
[group('KythOS')]
install-obs:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub com.obsproject.Studio
    flatpak override --user --env=OBS_VKCAPTURE=1 com.obsproject.Studio || true
    echo
    echo "OBS Studio installed. Launch it from the app menu."
    echo "obs-vkcapture is enabled for Vulkan/OpenGL game capture."

# Install the Itch.io desktop app — indie game store and library manager.
[group('KythOS')]
install-itch:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub io.itch.itch
    echo
    echo "Itch.io installed. Launch it from the app menu."

# Install RetroArch — multi-system emulator frontend (NES, SNES, PS1, N64, ...).
[group('KythOS')]
install-retroarch:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub org.libretro.RetroArch
    echo
    echo "RetroArch installed. Launch it from the app menu."
    echo "Tip: download cores from inside RetroArch: Main Menu → Load Core → Download a Core."

# Install Piper — GUI for configuring gaming mice (DPI, buttons, LEDs).

# Uses the Flatpak which bundles ratbagd — no rpm-ostree layering required.
[group('KythOS')]
install-piper:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub org.freedesktop.Piper
    echo
    echo "Piper installed. Launch it from the app menu."

# Install OpenRGB — unified RGB lighting control for motherboards, RAM, GPUs,
# fans and peripherals. Uses the Flatpak with --device=all for hardware access.
# Note: SMBus/i2c access (RAM RGB, some motherboard headers) may need the i2c
# kernel modules loaded. If devices are missing, run:

# sudo modprobe i2c-dev i2c-piix4    (or the appropriate module for your board)
[group('KythOS')]
install-openrgb:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub org.openrgb.OpenRGB
    # Grant access to USB and i2c/SMBus devices
    flatpak override --user --device=all org.openrgb.OpenRGB
    echo
    echo "OpenRGB installed. Launch it from the app menu."
    echo "If RGB RAM or motherboard headers are missing, load i2c kernel modules:"
    echo "  sudo modprobe i2c-dev i2c-piix4"

# Manually enroll the KythOS Secure Boot key (MOK) into UEFI firmware.
#
# The first-boot service (kyth-enroll-mok.service) handles this automatically
# when Secure Boot is active at install time. Use this recipe if you:
#   - enabled Secure Boot after installing KythOS
#   - need to re-enroll after a firmware reset
#
# After running, reboot and enter the password you chose at the MokManager screen.
[group('KythOS')]
enroll-secureboot:
    #!/usr/bin/env bash
    set -euo pipefail

    CERT="/usr/share/kyth/secureboot/kyth-secureboot.cer"

    if [[ ! -f "${CERT}" ]]; then
        echo "KythOS Secure Boot certificate not found." >&2
        echo "This image was built without Secure Boot support." >&2
        exit 1
    fi

    echo "━━━ KythOS Secure Boot Enrollment ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo

    if ! mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
        echo "  Secure Boot is not currently enabled in your firmware."
        echo "  Enable it in your UEFI/BIOS settings, reboot, then run this again."
        exit 0
    fi

    if mokutil --list-enrolled 2>/dev/null | grep -q "KythOS Secure Boot"; then
        echo "  KythOS Secure Boot key is already enrolled. Nothing to do."
        exit 0
    fi

    echo "  Enrolling KythOS Secure Boot certificate."
    echo "  Choose a one-time confirmation password — you will enter it at the"
    echo "  MokManager screen on next reboot to complete enrollment."
    echo
    read -rsp "  Enrollment password: " MOK_PASS
    echo
    read -rsp "  Confirm password:    " MOK_PASS2
    echo
    if [[ "${MOK_PASS}" != "${MOK_PASS2}" ]]; then
        echo "  Passwords do not match." >&2
        exit 1
    fi

    echo "${MOK_PASS}" | sudo mokutil --import "${CERT}" --stdin-passwd

    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  MOK enrollment staged."
    echo "  Reboot and enter your password at the blue MokManager screen."
    echo "    systemctl reboot"

# Install NVIDIA proprietary drivers on KythOS.
#
# Runs in two phases — just re-run after each reboot prompt:
#
#   Phase 1: Layers akmod-nvidia via rpm-ostree (requires a reboot).
#   Phase 2: Compiles the kernel module via akmods (requires a final reboot).
#
# Usage:
#   ujust install-nvidia-driver          # run once, reboot when prompted, repeat
[group('KythOS')]
install-nvidia-driver:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "━━━ KythOS NVIDIA Driver Wizard ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo

    # ── GPU detection ─────────────────────────────────────────────────────────
    if ! lspci | grep -qi nvidia; then
        echo "  No NVIDIA GPU detected. Nothing to install."
        exit 0
    fi
    echo "  NVIDIA GPU detected."
    echo

    # ── Already active ────────────────────────────────────────────────────────
    if modinfo nvidia &>/dev/null && lsmod | grep -q "^nvidia "; then
        echo "  NVIDIA driver is already active. Nothing to do."
        exit 0
    fi

    # ── Phase 1: layer the source package ────────────────────────────────────
    if ! rpm -q akmod-nvidia &>/dev/null; then
        echo "  Phase 1/2 — Layering akmod-nvidia via rpm-ostree."
        echo "  A reboot is required after this step."
        echo
        sudo rpm-ostree install --idempotent akmod-nvidia
        echo
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  akmod-nvidia has been staged."
        echo
        echo "  Next steps:"
        echo "    1. Reboot:             systemctl reboot"
        echo "    2. After reboot, run:  ujust install-nvidia-driver"
        exit 0
    fi

    # ── Module already built — reboot to activate ─────────────────────────────
    if modinfo nvidia &>/dev/null; then
        echo "  Kernel module is already built. Reboot to activate the driver."
        echo "    systemctl reboot"
        exit 0
    fi

    # ── Phase 2: compile the kernel module ───────────────────────────────────
    echo "  Phase 2/2 — Compiling kernel module via akmods."
    echo "  This may take 5–15 minutes on first compile…"
    echo

    KARGS="rd.driver.blacklist=nouveau,nova_core modprobe.blacklist=nouveau,nova_core nvidia-drm.modeset=1"
    sudo grubby --update-kernel=ALL --args="${KARGS}" 2>/dev/null || \
        echo "  (grubby: non-fatal — kargs.d applies on next deployment)"

    sudo rm -f /var/lib/kyth/hw-setup-done
    sudo akmods --force --kernels "$(uname -r)"
    sudo touch /var/lib/kyth/hw-setup-done

    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  NVIDIA driver compiled successfully."
    echo "  Reboot to activate:"
    echo "    systemctl reboot"

# Check for and apply firmware updates via fwupd.
[group('KythOS')]
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
