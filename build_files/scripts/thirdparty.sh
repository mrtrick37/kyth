#!/bin/bash

set -euo pipefail

is_enabled() {
    case "${1,,}" in
        1|true|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

# verify_release_asset RELEASE_JSON TARBALL_PATH TARBALL_NAME TMPDIR
#
# Looks for a checksum file in the GitHub release JSON that corresponds to
# TARBALL_NAME, downloads it, and verifies TARBALL_PATH against it.
# Supports common patterns:
#   - <tarball>.sha256 / <tarball>.sha512 (per-file sidecar)
#   - SHA256SUMS / SHA512SUMS / checksums.txt (multi-file manifest)
#
# Returns:
#   0  — checksum verified OK
#   0  — no checksum metadata available (warning printed; caller continues)
#  exit 1 — checksum mismatch (hard failure)
verify_release_asset() {
    local release_json=$1
    local tarball_path=$2
    local tarball_name=$3
    local tmpdir=$4

    local checksum_url="" algo=""

    # 1. Look for a per-file sidecar: <tarball>.sha256, .sha512, .sha256sum, .sha512sum
    # sha256sum/sha512sum extensions cover Winetricks-style naming.
    for ext in sha256 sha512 sha256sum sha512sum SHA256 SHA512; do
        local candidate
        candidate=$(grep -oP "https://[^\"]+" "${release_json}" \
            | grep -F "${tarball_name}.${ext}" | head -n1 || true)
        if [[ -n "${candidate}" ]]; then
            checksum_url="${candidate}"
            # Normalise: sha256sum/SHA256 → sha256; sha512sum/SHA512 → sha512
            case "${ext,,}" in
                *512*) algo="sha512" ;;
                *)     algo="sha256" ;;
            esac
            break
        fi
    done

    # 2. If no sidecar, look for a manifest (SHA256SUMS, checksums.txt, etc.)
    if [[ -z "${checksum_url}" ]]; then
        for pattern in SHA256SUMS SHA512SUMS checksums.txt sha256sums.txt sha512sums.txt; do
            local candidate
            candidate=$(grep -oP "https://[^\"]+" "${release_json}" \
                | grep -iF "${pattern}" | head -n1 || true)
            if [[ -n "${candidate}" ]]; then
                checksum_url="${candidate}"
                # Infer algo from filename
                if echo "${pattern,,}" | grep -q 512; then
                    algo="sha512"
                else
                    algo="sha256"
                fi
                break
            fi
        done
    fi

    if [[ -z "${checksum_url}" ]]; then
        echo "WARNING: No checksum file found for ${tarball_name} in release assets." \
            "The binary has not been integrity-verified." >&2
        echo "WARNING: Proceeding without checksum verification for ${tarball_name}." >&2
        # Non-fatal: some upstream releases do not publish checksums.
        return 0
    fi

    local checksum_file_path="${tmpdir}/checksum_file"
    if ! curl -fsSL "${checksum_url}" -o "${checksum_file_path}"; then
        echo "WARNING: Failed to download checksum file from ${checksum_url}." \
            "The binary has not been integrity-verified." >&2
        echo "WARNING: Proceeding without checksum verification for ${tarball_name}." >&2
        return 0
    fi

    # If this is a multi-file manifest, filter to just the line for our tarball
    local expected_hash=""
    expected_hash=$(grep -F "${tarball_name}" "${checksum_file_path}" \
        | awk '{print $1}' | head -n1 || true)

    # Fallback: if the file contains only a bare hash (sidecar style), use it directly
    if [[ -z "${expected_hash}" ]]; then
        expected_hash=$(awk '{print $1}' "${checksum_file_path}" | head -n1 || true)
    fi

    if [[ -z "${expected_hash}" ]]; then
        echo "WARNING: Could not extract hash for ${tarball_name} from checksum file." >&2
        echo "WARNING: Proceeding without checksum verification for ${tarball_name}." >&2
        return 0
    fi

    local actual_hash=""
    case "${algo}" in
        sha256) actual_hash=$(sha256sum "${tarball_path}" | awk '{print $1}') ;;
        sha512) actual_hash=$(sha512sum "${tarball_path}" | awk '{print $1}') ;;
    esac

    if [[ "${actual_hash}" != "${expected_hash}" ]]; then
        echo "ERROR: ${algo^^} mismatch for ${tarball_name}!" >&2
        echo "  Expected: ${expected_hash}" >&2
        echo "  Got:      ${actual_hash}" >&2
        exit 1
    fi

    echo "${tarball_name}: ${algo^^} verified OK"
    return 0
}

# ── topgrade ─────────────────────────────────────────────────────────────────
# Not in Fedora 44 repos — install pre-built binary from GitHub releases.
# Uses the musl-linked build for maximum compatibility across libc versions.
TOPGRADE_REPO_API="https://api.github.com/repos/topgrade-rs/topgrade/releases/latest"
TMPDIR_TG=$(mktemp -d)
release_json="${TMPDIR_TG}/release.json"
if curl -fsSL "${TOPGRADE_REPO_API}" -o "${release_json}" 2>/dev/null; then
    TOPGRADE_URL=$(
        grep -oP 'https://[^"]+\.tar\.(gz|zst)' "${release_json}" \
        | grep -i 'x86.64\|x86_64\|amd64' \
        | grep -i 'musl\|linux' \
        | grep -iv 'source' \
        | head -n1
    ) || true
    if [[ -n "${TOPGRADE_URL}" ]]; then
        TOPGRADE_TARBALL=$(basename "${TOPGRADE_URL}")
        curl -fsSL "${TOPGRADE_URL}" -o "${TMPDIR_TG}/${TOPGRADE_TARBALL}"
        verify_release_asset "${release_json}" "${TMPDIR_TG}/${TOPGRADE_TARBALL}" \
            "${TOPGRADE_TARBALL}" "${TMPDIR_TG}"
        tar -xf "${TMPDIR_TG}/${TOPGRADE_TARBALL}" -C "${TMPDIR_TG}/"
        find "${TMPDIR_TG}" -name 'topgrade' -type f \
            -exec install -m 0755 {} /usr/bin/topgrade \;
        echo "topgrade installed: $(topgrade --version 2>/dev/null || echo 'unknown version')"
    else
        echo "topgrade: no musl x86_64 tarball found in release assets; skipping."
    fi
else
    echo "topgrade: failed to fetch release info from GitHub; skipping."
fi
rm -rf "${TMPDIR_TG}"

# Download winetricks from the latest upstream release and verify integrity.
# Always fetches the current latest release from GitHub — no version pin to bump.
# Winetricks publishes a .sha256sum sidecar for every release asset.
# /usr/local is a symlink to /var/usrlocal on ostree/bootc roots; mkdir -p
# won't traverse a symlink, so resolve it first.
WINETRICKS_REPO_API="https://api.github.com/repos/Winetricks/winetricks/releases/latest"
TMPDIR_WTX=$(mktemp -d)
release_json="${TMPDIR_WTX}/release.json"
mkdir -p "$(realpath -m /usr/local)/bin"
if curl -fsSL "${WINETRICKS_REPO_API}" -o "${release_json}" 2>/dev/null; then
    WTX_SCRIPT_URL=$(
        grep -oP 'https://[^"]+' "${release_json}" \
        | grep '/releases/download/' \
        | grep -v '\.sha256sum\|\.asc\|\.sig\|source' \
        | grep 'winetricks$' | head -n1 || true
    )
    if [[ -n "${WTX_SCRIPT_URL}" ]]; then
        curl -fsSL "${WTX_SCRIPT_URL}" -o "${TMPDIR_WTX}/winetricks"
        verify_release_asset "${release_json}" "${TMPDIR_WTX}/winetricks" \
            "winetricks" "${TMPDIR_WTX}"
        # Extra sanity: must still be a shell script after hash verification
        head -1 "${TMPDIR_WTX}/winetricks" | grep -q '^#!' \
            || { echo "ERROR: winetricks does not look like a shell script after hash verification"; exit 1; }
        install -m 0755 "${TMPDIR_WTX}/winetricks" /usr/local/bin/winetricks
        echo "winetricks installed: $(winetricks --version 2>/dev/null || echo 'unknown version')"
    else
        echo "winetricks: no release asset found in GitHub response; skipping."
    fi
else
    echo "winetricks: failed to fetch release info from GitHub; skipping."
fi
rm -rf "${TMPDIR_WTX}"

# ── umu-launcher ─────────────────────────────────────────────────────────────
# Not in bazzite COPR for Fedora 44 — install from GitHub releases.
# Provides umu-run, which Lutris uses to launch Battle.net, EA App, and
# other installers via Proton.
UMU_REPO_API="https://api.github.com/repos/Open-Wine-Components/umu-launcher/releases/latest"
TMPDIR_UMU=$(mktemp -d)
release_json="${TMPDIR_UMU}/release.json"
if curl -fsSL "${UMU_REPO_API}" -o "${release_json}" 2>/dev/null; then
    # Match release assets (path contains /releases/download/) — arch suffix not
    # required because umu-launcher tarballs (e.g. umu-launcher-1.1.4.tar.gz)
    # carry no x86_64 indicator in the filename.
    UMU_URL=$(
        grep -oP 'https://[^"]+/releases/download/[^"]+\.tar\.(gz|zst)' "${release_json}" \
        | grep -iv 'source\|src' \
        | head -n1
    ) || true
    if [[ -n "${UMU_URL}" ]]; then
        UMU_TARBALL=$(basename "${UMU_URL}")
        echo "umu-launcher: downloading ${UMU_TARBALL}"
        curl -fsSL "${UMU_URL}" -o "${TMPDIR_UMU}/${UMU_TARBALL}"
        verify_release_asset "${release_json}" "${TMPDIR_UMU}/${UMU_TARBALL}" \
            "${UMU_TARBALL}" "${TMPDIR_UMU}"
        tar -xf "${TMPDIR_UMU}/${UMU_TARBALL}" -C "${TMPDIR_UMU}/"
        # Install umu-run binary
        UMU_BIN=$(find "${TMPDIR_UMU}" -name 'umu-run' -type f | head -n1)
        if [[ -n "${UMU_BIN}" ]]; then
            install -m 0755 "${UMU_BIN}" /usr/bin/umu-run
            # Install any bundled Python package files (umu/ directory)
            UMU_PKGDIR=$(find "${TMPDIR_UMU}" -maxdepth 3 -name 'umu' -type d | grep -v '__pycache__' | head -n1)
            if [[ -n "${UMU_PKGDIR}" ]]; then
                PY_SITEPKG=$(python3 -c "import sysconfig; print(sysconfig.get_paths()['purelib'])")
                mkdir -p "${PY_SITEPKG}"
                cp -r "${UMU_PKGDIR}" "${PY_SITEPKG}/"
            fi
            echo "umu-launcher: installed $(umu-run --version 2>/dev/null || echo 'unknown version')"
        else
            echo "umu-launcher: umu-run binary not found in archive; trying setup.sh"
            SETUP=$(find "${TMPDIR_UMU}" -name 'setup.sh' | head -n1)
            [[ -n "${SETUP}" ]] && bash "${SETUP}" || echo "umu-launcher: no setup.sh either; skipping."
        fi
    else
        echo "umu-launcher: no x86_64 tarball found in release assets; skipping."
    fi
else
    echo "umu-launcher: failed to fetch release info from GitHub; skipping."
fi
rm -rf "${TMPDIR_UMU}"

# ── LatencyFleX ──────────────────────────────────────────────────────────────
# Frame-pacing / latency-flexibility layer for Wine/Proton. Games that implement
# the LatencyFleX API (via GE-Proton or natively) can report their ideal frame
# schedule to the runtime, eliminating the latency penalty of vsync without
# tearing. Installs the Vulkan implicit layer system-wide; it activates only in
# games that call into the API, and is a no-op everywhere else.
LFX_REPO_API="https://api.github.com/repos/ishitatsuyuki/LatencyFleX/releases/latest"
TMPDIR_LFX=$(mktemp -d)
release_json="${TMPDIR_LFX}/release.json"
if curl -fsSL "${LFX_REPO_API}" -o "${release_json}" 2>/dev/null; then
    LFX_URL=$(
        grep -oP 'https://[^"]+\.tar\.(gz|xz|zst)' "${release_json}" \
        | grep -iv 'source' \
        | head -n1
    ) || true
    if [[ -n "${LFX_URL}" ]]; then
        LFX_TARBALL=$(basename "${LFX_URL}")
        echo "latencyflex: downloading ${LFX_TARBALL}"
        curl -fsSL "${LFX_URL}" -o "${TMPDIR_LFX}/${LFX_TARBALL}"
        verify_release_asset "${release_json}" "${TMPDIR_LFX}/${LFX_TARBALL}" \
            "${LFX_TARBALL}" "${TMPDIR_LFX}"
        tar -xf "${TMPDIR_LFX}/${LFX_TARBALL}" -C "${TMPDIR_LFX}/"

        LFX_SO=$(find "${TMPDIR_LFX}" -name 'liblatencyflex_layer.so' | head -n1)
        LFX_JSON=$(find "${TMPDIR_LFX}" -name '*.json' | grep -i 'latencyflex' | head -n1)

        if [[ -n "${LFX_SO}" && -n "${LFX_JSON}" ]]; then
            install -m 0755 "${LFX_SO}" /usr/lib64/liblatencyflex_layer.so
            mkdir -p /usr/share/vulkan/implicit_layer.d
            install -m 0644 "${LFX_JSON}" \
                /usr/share/vulkan/implicit_layer.d/latencyflex_layer.json
            # Ensure the JSON points to the installed library path
            sed -i 's|"library_path":.*|"library_path": "/usr/lib64/liblatencyflex_layer.so"|' \
                /usr/share/vulkan/implicit_layer.d/latencyflex_layer.json
            echo "latencyflex: Vulkan layer installed"
        else
            echo "latencyflex: could not find layer .so or .json in archive; skipping."
        fi
    else
        echo "latencyflex: no tarball found in release assets; skipping."
    fi
else
    echo "latencyflex: failed to fetch release info from GitHub; skipping."
fi
rm -rf "${TMPDIR_LFX}"

# ── scx userspace schedulers ──────────────────────────────────────────────────
# sched-ext (scx) is a BPF-based scheduler framework in the CachyOS kernel.
# scx_lavd is optimised for interactive + gaming — it prioritises latency-
# sensitive threads (audio, input, render) while keeping throughput tasks warm.
#
# We pull pre-built binaries directly from the upstream GitHub release rather
# than relying on a COPR that may not have a Fedora 44 build available.
if is_enabled "${ENABLE_SCX:-1}"; then
    SCX_REPO_API="https://api.github.com/repos/sched-ext/scx/releases/latest"
    TMPDIR_SCX=$(mktemp -d)

    release_json="${TMPDIR_SCX}/release.json"
    if curl -fsSL "${SCX_REPO_API}" -o "${release_json}" 2>/dev/null; then
        # Find a Linux x86_64 binary tarball in the release assets.
        # Accept .tar.gz and .tar.zst (SCX releases have used both formats).
        SCX_TARBALL_URL=$(
            grep -oP 'https://[^"]+\.tar\.(gz|zst)' "${release_json}" \
            | grep -i 'x86.64\|x86_64\|amd64' \
            | grep -iv 'source' \
            | head -n1
        ) || true

        if [[ -n "${SCX_TARBALL_URL}" ]]; then
            SCX_TARBALL=$(basename "${SCX_TARBALL_URL}")
            echo "scx: downloading ${SCX_TARBALL}"
            curl -fsSL "${SCX_TARBALL_URL}" -o "${TMPDIR_SCX}/${SCX_TARBALL}"
            verify_release_asset "${release_json}" "${TMPDIR_SCX}/${SCX_TARBALL}" \
                "${SCX_TARBALL}" "${TMPDIR_SCX}"
            tar -xf "${TMPDIR_SCX}/${SCX_TARBALL}" -C "${TMPDIR_SCX}/"

            # Install scx_* scheduler binaries and scxd
            find "${TMPDIR_SCX}" \( -name 'scx_*' -o -name 'scxd' \) -type f \
                -exec install -m 0755 {} /usr/bin/ \;

            if command -v scxd >/dev/null 2>&1; then
                # Provide scxd.service — not present without the RPM
                mkdir -p /usr/lib/systemd/system
                cat > /usr/lib/systemd/system/scxd.service <<'SCXSVCEOF'
[Unit]
Description=sched-ext userspace scheduler daemon
Documentation=https://github.com/sched-ext/scx
After=basic.target

[Service]
Type=simple
EnvironmentFile=-/etc/scx/config
ExecStart=/usr/bin/scxd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SCXSVCEOF

                # Pick the best available scheduler: lavd > rusty > bpfland
                SCX_SCHEDULER=""
                for sched in scx_lavd scx_rusty scx_bpfland; do
                    if command -v "$sched" >/dev/null 2>&1; then
                        SCX_SCHEDULER="$sched"
                        break
                    fi
                done

                if [[ -n "$SCX_SCHEDULER" ]]; then
                    mkdir -p /etc/scx
                    cat > /etc/scx/config <<SCXEOF
SCX_SCHEDULER=${SCX_SCHEDULER}
SCX_FLAGS=--auto-mode
SCXEOF
                    systemctl enable scxd.service 2>/dev/null || true
                    echo "scx: enabled ${SCX_SCHEDULER}"
                else
                    echo "scx: no scheduler binaries found in archive"
                fi
            else
                echo "scx: scxd not found after extraction"
            fi
        else
            echo "scx: no x86_64 tarball found in release assets; skipping."
        fi
    else
        echo "scx: failed to fetch release info from GitHub; skipping."
    fi

    rm -rf "${TMPDIR_SCX}"
else
    echo "ENABLE_SCX is off; skipping scx scheduler install."
fi

# Homebrew — system-wide install to /home/linuxbrew (= /var/home/linuxbrew at runtime)
# Owned by a dedicated non-root 'linuxbrew' system user so topgrade does not invoke
# brew via sudo (which brew refuses). Wheel group gets write access so any wheel
# user can install/update formulae without privilege escalation.
#
# Resolved live from the GitHub releases API so every build gets the current
# latest Homebrew without a version pin to manually maintain.
HOMEBREW_TAG=$(
    curl -fsSL "https://api.github.com/repos/Homebrew/brew/releases/latest" 2>/dev/null \
    | grep -oP '"tag_name":\s*"\K[^"]+' | head -n1 || echo ""
)
if [[ -z "${HOMEBREW_TAG}" ]]; then
    echo "ERROR: Could not determine latest Homebrew release tag" >&2
    exit 1
fi
echo "Homebrew: installing latest release ${HOMEBREW_TAG}"
LINUXBREW_HOME="/var/home/linuxbrew"
# Use /var/home explicitly on ostree/bootc roots; /home may be a symlink that
# some useradd implementations attempt to re-create and fail on.
mkdir -p "${LINUXBREW_HOME}"
if ! id -u linuxbrew >/dev/null 2>&1; then
    useradd -r -d "${LINUXBREW_HOME}" -M -s /sbin/nologin linuxbrew
fi
if [ -d "${LINUXBREW_HOME}/.linuxbrew/.git" ]; then
    git -C "${LINUXBREW_HOME}/.linuxbrew" fetch --depth 1 origin "refs/tags/${HOMEBREW_TAG}:refs/tags/${HOMEBREW_TAG}" \
        || { echo "ERROR: Homebrew git fetch failed"; exit 1; }
    git -C "${LINUXBREW_HOME}/.linuxbrew" checkout -f "${HOMEBREW_TAG}" \
        || { echo "ERROR: Homebrew checkout failed"; exit 1; }
else
    git clone --depth 1 --branch "${HOMEBREW_TAG}" \
        https://github.com/Homebrew/brew "${LINUXBREW_HOME}/.linuxbrew" \
        || { echo "ERROR: Homebrew git clone failed"; exit 1; }
fi
[ -f "${LINUXBREW_HOME}/.linuxbrew/bin/brew" ] \
    || { echo "ERROR: Homebrew clone appears empty"; exit 1; }
chown -R linuxbrew:wheel "${LINUXBREW_HOME}"
chmod -R g+w "${LINUXBREW_HOME}"
find "${LINUXBREW_HOME}" -type d -exec chmod g+s {} \;
# Add brew to PATH for all login shells
cat > /etc/profile.d/homebrew.sh <<'BREWEOF'
if [ -d /var/home/linuxbrew/.linuxbrew ]; then
    eval "$(/var/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -d /home/linuxbrew/.linuxbrew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
BREWEOF
chmod +x /etc/profile.d/homebrew.sh
