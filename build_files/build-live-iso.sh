#!/usr/bin/env bash

# build-live-iso.sh — Build a live desktop ISO for KythOS with the web installer.
#
# Flow:
#   1. Build Containerfile.live (stable live environment + Chromium + kyth-installer)
#   2. Export the container filesystem to a temporary rootfs
#   3. Copy kernel + live initramfs out of the rootfs
#   4. mksquashfs the rootfs → LiveOS/squashfs.img
#   5. Assemble bootable ISO: UEFI (GRUB2) + BIOS (syslinux) via xorriso
#
# By default the OS is pulled from the registry at install time by
# kyth-installer via bootc install to-disk. For local QEMU development,
# EMBED_LOCAL_IMAGE=1 embeds localhost/kyth:latest into the ISO and points the
# installer at that exact image so install tests cannot accidentally use stale
# GHCR builds.
#
# Host requirements:
#   xorriso, squashfs-tools (mksquashfs), mtools, dosfstools
#   Missing packages are installed automatically via rpm-ostree (Atomic) or dnf (classic).

set -euo pipefail

SECONDS=0

# ── Docker group bootstrap ─────────────────────────────────────────────────────
# If docker is inaccessible, add the user to the docker group (if needed) and
# re-exec under `sg docker` to activate it — no logout required.
if ! docker info &>/dev/null 2>&1; then
    if ! id -nG "$USER" | grep -qw docker; then
        echo "==> Adding ${USER} to the docker group (requires sudo)..."
        command sudo usermod -aG docker "$USER"
    fi
    echo "==> Activating docker group for this session via sg — restarting build..."
    exec sg docker -c "bash $(printf '%q' "${BASH_SOURCE[0]}")"
    echo "ERROR: Could not activate the docker group. Try: newgrp docker" >&2
    exit 1
fi

SOURCE_TAG="${SOURCE_TAG:-latest}"
INSTALLER_BASE_IMAGE="${INSTALLER_BASE_IMAGE:-ghcr.io/ublue-os/kinoite-main:44}"
EMBED_LOCAL_IMAGE="${EMBED_LOCAL_IMAGE:-0}"
LOCAL_INSTALL_IMAGE="${LOCAL_INSTALL_IMAGE:-localhost/kyth:latest}"
if [[ "${SOURCE_TAG}" == "latest" ]]; then
    LIVE_BUILD_TAG="kyth-live:build"
else
    LIVE_BUILD_TAG="kyth-live:build-${SOURCE_TAG}"
fi
SECUREBOOT_SIGNING_REQUESTED=0
if [[ -n "${MOK_KEY:-}" ]]; then
    SECUREBOOT_SIGNING_REQUESTED=1
fi

# ── Sudo setup: ask once, then keep sudo's timestamp alive ────────────────────
SUDO_KEEPALIVE_PID=""
if ! command sudo -n true 2>/dev/null; then
    if [[ ! -t 0 ]]; then
        echo "ERROR: sudo credentials are required, but stdin is not interactive." >&2
        echo "       Run 'sudo -v' first or run this ISO build from a terminal." >&2
        exit 1
    fi
    echo "==> Sudo credentials are needed for export, squashfs, and ISO assembly."
    command sudo -v
fi

(
    while command sudo -n true 2>/dev/null; do
        sleep 60
    done
) &
SUDO_KEEPALIVE_PID=$!

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${KYTH_ISO_OUTPUT:-${REPO_ROOT}/output/live-iso}"
ISO_NAME="kyth-live-${SOURCE_TAG}.iso"
VOLID="KythOS-44-Live"

# Hash relevant installer sources so cached container rebuilds when these files
# change (even if the base image timestamp does not).
SOURCE_HASH="$(
    cd "${REPO_ROOT}"
    sha256sum \
        build_files/Containerfile.live \
        build_files/kyth-installer \
        build_files/kyth-launch-installer \
        build_files/plymouth/kyth.plymouth \
        build_files/plymouth/kyth.script \
        build_files/wallpaper/kyth-wallpaper.svg \
        build_files/branding/kyth-logo.svg \
        build_files/branding/kyth-logo-transparent.svg \
    | sha256sum \
    | awk '{print $1}'
)"

# Pick the scratch directory: honour $TMPDIR if set, otherwise prefer whichever
# of /var/tmp or /var/tmp/kyth-root has more free space (kyth-root is the large
# data partition on dev machines that keeps the root filesystem from filling up).
if [[ -n "${TMPDIR:-}" ]]; then
    TMPDIR_BASE="${TMPDIR}"
else
    _root_avail=$(df --output=avail /var/tmp 2>/dev/null | tail -1 || echo 0)
    _data_avail=$(df --output=avail /var/tmp/kyth-root 2>/dev/null | tail -1 || echo 0)
    if [[ "${_data_avail}" -gt "${_root_avail}" ]]; then
        TMPDIR_BASE="/var/tmp/kyth-root"
        echo "==> Using /var/tmp/kyth-root for build scratch (more free space than /var/tmp)"
    else
        TMPDIR_BASE="/var/tmp"
    fi
fi
# If the default ISO output directory's filesystem is low on space (< 6 GB) and
# the scratch partition has more room, redirect output there too.
if [[ -z "${KYTH_ISO_OUTPUT:-}" ]]; then
    _out_avail=$(df --output=avail "${REPO_ROOT}" 2>/dev/null | tail -1 || echo 0)
    if [[ "${_out_avail}" -lt 6291456 && "${TMPDIR_BASE}" != "/var/tmp" ]]; then
        OUTPUT_DIR="${TMPDIR_BASE}/kyth-iso-output/live-iso"
        echo "==> Redirecting ISO output to ${OUTPUT_DIR} (repo filesystem low on space)"
    fi
fi

WORK=$(mktemp -d -p "${TMPDIR_BASE}" kyth-live.XXXXXXXXXX)
ROOTFS="${WORK}/rootfs"
ISO_DIR="${WORK}/iso"

if ! command -v docker &>/dev/null; then
    echo "ERROR: docker not found — install Docker or add it to PATH." >&2
    exit 1
fi
echo "==> Using container engine: docker"
echo "==> Installer runtime base image: ${INSTALLER_BASE_IMAGE}"
if [[ "${EMBED_LOCAL_IMAGE}" == "1" ]]; then
    echo "==> Local install image: ${LOCAL_INSTALL_IMAGE} (will be embedded)"
fi

cleanup() {
    echo "==> Cleaning up ${WORK}"
    if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]]; then
        kill "${SUDO_KEEPALIVE_PID}" 2>/dev/null || true
    fi
    sudo rm -rf "${WORK}" 2>/dev/null || true
    # kyth-live:build is kept intentionally so Docker layer cache is preserved
    # for the next build. Run 'docker rmi kyth-live:build' to force a rebuild.
}
trap cleanup EXIT

_missing_pkgs=()
command -v xorriso    &>/dev/null || _missing_pkgs+=(xorriso)
command -v mksquashfs &>/dev/null || _missing_pkgs+=(squashfs-tools)
command -v mkfs.fat   &>/dev/null || _missing_pkgs+=(dosfstools)
command -v mcopy      &>/dev/null || _missing_pkgs+=(mtools)
command -v mmd        &>/dev/null || [[ " ${_missing_pkgs[*]} " == *mtools* ]] || _missing_pkgs+=(mtools)

if [[ ${#_missing_pkgs[@]} -gt 0 ]]; then
    echo "==> Installing missing ISO build tools: ${_missing_pkgs[*]}"
    if command -v rpm-ostree &>/dev/null; then
        sudo rpm-ostree install --apply-live --idempotent "${_missing_pkgs[@]}"
    else
        sudo dnf install -y "${_missing_pkgs[@]}"
    fi
    hash -r
fi

mkdir -p \
    "${ROOTFS}" \
    "${ISO_DIR}/LiveOS" \
    "${ISO_DIR}/images/pxeboot" \
    "${ISO_DIR}/EFI/BOOT" \
    "${ISO_DIR}/EFI/fedora" \
    "${ISO_DIR}/boot/grub2/themes/kyth" \
    "${ISO_DIR}/isolinux"

copy_efi_from_rootfs() {
    local src="$1"
    local dest="$2"
    sudo install -m 0644 "${src}" "${dest}"
}

# ── 1. Build live container ─────────────────────────────────────────
_need_rebuild=0
if [[ "${SKIP_REBUILD:-}" == "1" ]]; then
    echo "==> SKIP_REBUILD=1: using pre-built live container (CI mode)"
elif [[ "${REBUILD_IMAGE:-}" == "1" ]]; then
    echo "==> REBUILD_IMAGE=1: forcing live container rebuild"
    _need_rebuild=1
elif ! docker image inspect "${LIVE_BUILD_TAG}" >/dev/null 2>&1; then
    echo "==> ${LIVE_BUILD_TAG} not found: building live container"
    _need_rebuild=1
else
    _installed_hash=$(docker image inspect "${LIVE_BUILD_TAG}" \
        --format '{{ index .Config.Labels "org.kyth.live.source-hash" }}' \
        2>/dev/null || echo "")
    if [[ "${_installed_hash}" != "${SOURCE_HASH}" ]]; then
        echo "==> Installer sources changed — rebuilding ${LIVE_BUILD_TAG}..."
        _need_rebuild=1
    fi

    _installed_secureboot_signing=$(docker image inspect "${LIVE_BUILD_TAG}" \
        --format '{{ index .Config.Labels "org.kyth.live.secureboot-signing-requested" }}' \
        2>/dev/null || echo "")
    if [[ "${_installed_secureboot_signing}" != "${SECUREBOOT_SIGNING_REQUESTED}" ]]; then
        echo "==> Secure Boot signing state changed — rebuilding ${LIVE_BUILD_TAG}..."
        _need_rebuild=1
    fi

    _base_ts=$(docker image inspect "${INSTALLER_BASE_IMAGE}" \
        --format '{{.Created}}' 2>/dev/null || echo "")
    _live_ts=$(docker image inspect "${LIVE_BUILD_TAG}" \
        --format '{{.Created}}' 2>/dev/null || echo "")
    if [[ -n "${_base_ts}" && "${_base_ts}" > "${_live_ts}" ]]; then
        echo "==> Base image has changed — rebuilding ${LIVE_BUILD_TAG}..."
        _need_rebuild=1
    else
        echo "==> ${LIVE_BUILD_TAG} is up to date — skipping rebuild"
    fi
fi

if [[ "${_need_rebuild}" == "1" ]]; then
    echo "==> Pulling installer runtime base image for rebuild..."
    if ! docker pull "${INSTALLER_BASE_IMAGE}"; then
        echo "ERROR: Failed to pull installer runtime base image: ${INSTALLER_BASE_IMAGE}" >&2
        exit 1
    fi

    echo "==> Building live container (this takes a while)..."
    BUILD_ARGS=()
    if [[ "${SECUREBOOT_SIGNING_REQUESTED}" == "1" ]]; then
        echo "==> Secure Boot: MOK_KEY set — live vmlinuz will be signed"
        BUILD_ARGS+=(--secret id=mok_key,env=MOK_KEY --build-arg SECUREBOOT_SIGNING_REQUESTED=1)
    else
        echo "==> Secure Boot: MOK_KEY not set — live vmlinuz signing skipped"
        BUILD_ARGS+=(--build-arg SECUREBOOT_SIGNING_REQUESTED=0)
    fi
    if [[ -n "${LIVE_BUILD_CACHE_FROM:-}" ]]; then
        echo "==> Using live build cache source: ${LIVE_BUILD_CACHE_FROM}"
        BUILD_ARGS+=(--cache-from "${LIVE_BUILD_CACHE_FROM}")
    fi

    docker build \
        --provenance=false \
        --build-arg BASE_IMAGE="${INSTALLER_BASE_IMAGE}" \
        --build-arg SOURCE_HASH="${SOURCE_HASH}" \
        --build-arg SOURCE_TAG="${SOURCE_TAG}" \
        "${BUILD_ARGS[@]}" \
        -f "${SCRIPT_DIR}/Containerfile.live" \
        -t "${LIVE_BUILD_TAG}" \
        "${REPO_ROOT}"
    echo "==> Live container build complete"
fi

# ── 2. Export container filesystem ───────────────────────────────────────────
echo "==> Exporting container filesystem to ${ROOTFS}"
CONTAINER=$(docker create "${LIVE_BUILD_TAG}" /bin/true)
if command -v pv >/dev/null 2>&1; then
    docker export "${CONTAINER}" | pv | \
        sudo tar -xC "${ROOTFS}" \
            --exclude='proc/*' \
            --exclude='sys/*' \
            --exclude='dev/*' \
            --exclude='run/*'
else
    docker export "${CONTAINER}" | \
        sudo tar -xC "${ROOTFS}" \
            --exclude='proc/*' \
            --exclude='sys/*' \
            --exclude='dev/*' \
            --exclude='run/*'
fi
echo "==> Container export complete."
docker rm "${CONTAINER}" 2>/dev/null || true
echo "==> Timing: export complete at ${SECONDS}s"

# docker export strips xattrs; set the KDE Plasma 6 trust xattr here so the
# installer desktop icon launches without the "Allow Launching" security dialog.
_installer_desktop="${ROOTFS}/home/liveuser/Desktop/install-kyth.desktop"
if [[ -f "${_installer_desktop}" ]]; then
    sudo python3 -c "import os; os.setxattr('${_installer_desktop}', 'user.metadata::trusted', b'yes')" \
        && echo "==> Marked installer desktop file as trusted (KDE Plasma 6)" \
        || echo "WARNING: could not set trusted xattr on installer desktop"
fi

# ── Optional local OS image bundle ───────────────────────────────────────────
# This is the path used for QEMU development. It turns the live ISO into a true
# local installer for the image that was just built on this workstation instead
# of pulling ghcr.io/mrtrick37/kyth:<tag>. The target ref remains the public
# registry ref so the installed system can upgrade normally after first boot.
if [[ "${EMBED_LOCAL_IMAGE}" == "1" ]]; then
    command -v skopeo >/dev/null 2>&1 || {
        echo "ERROR: EMBED_LOCAL_IMAGE=1 requires skopeo on the host." >&2
        exit 1
    }
    docker image inspect "${LOCAL_INSTALL_IMAGE}" >/dev/null 2>&1 || {
        echo "ERROR: local install image not found: ${LOCAL_INSTALL_IMAGE}" >&2
        echo "       Build it first with: just build" >&2
        exit 1
    }

    echo "==> Embedding ${LOCAL_INSTALL_IMAGE} into live ISO rootfs"
    sudo mkdir -p "${ROOTFS}/usr/share/kyth/image"
    sudo chown -R "$(id -u):$(id -g)" "${ROOTFS}/usr/share/kyth"
    rm -rf "${ROOTFS}/usr/share/kyth/image"/*
    skopeo copy \
        "docker-daemon:${LOCAL_INSTALL_IMAGE}" \
        "oci:${ROOTFS}/usr/share/kyth/image:latest"
    sudo chown -R 0:0 "${ROOTFS}/usr/share/kyth"

    sudo tee "${ROOTFS}/etc/kyth-installer.env" >/dev/null <<'INSTALLEOF'
KYTH_SOURCE_IMAGE=oci:/usr/share/kyth/image:latest
KYTH_TARGET_IMAGE=ghcr.io/mrtrick37/kyth:latest
KYTH_INSTALL_SKIP_FETCH_CHECK=1
INSTALLEOF
fi

# Step 3: Kernel and live initramfs
echo "==> Locating kernel and live initramfs"
KVER=$(
    find "${ROOTFS}/usr/lib/modules" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
        | sort -V \
        | tail -n 1
)
echo "    Kernel: ${KVER}"

VMLINUZ="${ROOTFS}/usr/lib/modules/${KVER}/vmlinuz"
INITRD="${ROOTFS}/usr/lib/modules/${KVER}/initramfs-live"

[[ -f "${VMLINUZ}" ]] || { echo "ERROR: vmlinuz not found at ${VMLINUZ}" >&2; exit 1; }
[[ -f "${INITRD}"  ]] || { echo "ERROR: live initramfs not found at ${INITRD}" >&2; exit 1; }

if [[ -f "${ROOTFS}/usr/share/kyth/secureboot/live-kernel-signed" ]]; then
    echo "    Secure Boot: live kernel signing marker present"
elif [[ "${REQUIRE_SECUREBOOT_SIGNING:-0}" == "1" || -n "${MOK_KEY:-}" ]]; then
    echo "ERROR: Secure Boot signing was requested, but the exported live kernel has no signing marker." >&2
    echo "       Rebuild the live container with MOK_KEY available." >&2
    exit 1
else
    echo "WARNING: live kernel is not marked as Secure Boot signed." >&2
    echo "         Secure Boot machines will need signing enabled before booting this ISO." >&2
fi

sudo cp "${VMLINUZ}" "${ISO_DIR}/images/pxeboot/vmlinuz" 2>/dev/null
sudo cp "${INITRD}"  "${ISO_DIR}/images/pxeboot/initrd.img" 2>/dev/null
sudo chmod 644 "${ISO_DIR}/images/pxeboot/"*

# ── 4. Squashfs ───────────────────────────────────────────────────────────────
# No OCI bundle embedded — kyth-installer pulls from the registry at install time
# via bootc install to-disk.
ZSTD_LEVEL="${SQUASHFS_ZSTD_LEVEL:-3}"
echo "==> Creating squashfs (zstd level ${ZSTD_LEVEL}, $(nproc) cores)"
sudo mksquashfs "${ROOTFS}" "${ISO_DIR}/LiveOS/squashfs.img" \
    -comp zstd \
    -Xcompression-level "${ZSTD_LEVEL}" \
    -processors "$(nproc)" \
    -noappend \
    -no-progress \
    -e proc -e sys -e dev -e run
echo "==> Timing: squashfs complete at ${SECONDS}s"

# ── 5a. GRUB config + dark theme ─────────────────────────────────────────────
echo "==> Writing GRUB config and theme"
# Use a temporary OverlayFS upperdir for the live session. Do not set
# rd.live.overlay=tmpfs: dracut treats rd.live.overlay as a persistent overlay
# location, then prints an interactive warning when it cannot find one.
LIVE_ARGS="quiet rhgb splash rd.plymouth=1 plymouth.enable=1 plymouth.ignore-serial-consoles systemd.show_status=false rd.systemd.show_status=false loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0 root=live:CDLABEL=${VOLID} rd.live.image rd.live.overlay.overlayfs=1 rd.retry=60 systemd.crash_reboot=0 inst.nokill random.trust_cpu=on"

cat > "${ISO_DIR}/boot/grub2/themes/kyth/theme.txt" <<THEMEEOF
# KythOS GRUB2 dark theme

title-text: ""
desktop-color: "#0d1117"
terminal-font: "DejaVu Sans Regular 14"
terminal-left: "0%"
terminal-top: "0%"
terminal-width: "100%"
terminal-height: "100%"
terminal-border: "0"

+ boot_menu {
    left   = 30%
    top    = 35%
    width  = 40%
    height = 40%
    item_font               = "DejaVu Sans Regular 14"
    item_color              = "#abb2bf"
    selected_item_color     = "#ffffff"
    item_height             = 36
    item_padding            = 14
    item_spacing            = 4
    scrollbar               = false
}

+ label {
    top    = 25%
    left   = 0%
    width  = 100%
    height = 50
    text   = "KYTH 44"
    font   = "DejaVu Sans Bold 28"
    color  = "#61afef"
    align  = "center"
}
THEMEEOF

for src_font in \
    "${ROOTFS}/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf" \
    "${ROOTFS}/usr/share/fonts/dejavu/DejaVuSans.ttf"; do
    if [[ -f "${src_font}" ]]; then
        grub2-mkfont -s 14 -o "${ISO_DIR}/boot/grub2/themes/kyth/dejavusans14.pf2" "${src_font}" 2>/dev/null || true
        grub2-mkfont -s 28 -o "${ISO_DIR}/boot/grub2/themes/kyth/dejavusansbold28.pf2" "${src_font}" 2>/dev/null || true
        break
    fi
done

for unicode_src in \
    "${ROOTFS}/usr/share/grub/unicode.pf2" \
    "${ROOTFS}/boot/grub2/fonts/unicode.pf2" \
    "/usr/share/grub/unicode.pf2"; do
    if [[ -f "${unicode_src}" ]]; then
        cp "${unicode_src}" "${ISO_DIR}/boot/grub2/unicode.pf2" 2>/dev/null
        break
    fi
done

cat > "${ISO_DIR}/boot/grub2/grub.cfg" << GRUBEOF
set default=0
set timeout=10

# ── Graphical terminal + dark theme ───────────────────────────────────────────
insmod all_video
insmod gfxterm
insmod gfxmenu
insmod png

if loadfont /boot/grub2/unicode.pf2; then
    set gfxmode=auto
    terminal_output gfxterm
    loadfont /boot/grub2/themes/kyth/dejavusans14.pf2 || true
    loadfont /boot/grub2/themes/kyth/dejavusansbold28.pf2 || true
    set theme=/boot/grub2/themes/kyth/theme.txt
else
    set color_normal=light-gray/black
    set color_highlight=black/light-cyan
    set menu_color_normal=light-gray/black
    set menu_color_highlight=black/light-cyan
fi

# ── Boot entries ───────────────────────────────────────────────────────────────
menuentry "Try KythOS Live" --class fedora --class gnu-linux --class os {
    linux /images/pxeboot/vmlinuz ${LIVE_ARGS}
    initrd /images/pxeboot/initrd.img
}

menuentry "Try KythOS Live (Hardware GL Test)" --class fedora --class gnu-linux --class os {
    linux /images/pxeboot/vmlinuz ${LIVE_ARGS} kyth.live.hwgl=1 kyth.installer.hwgl=1
    initrd /images/pxeboot/initrd.img
}

menuentry "Try KythOS Live (Debug — verbose boot)" --class fedora --class gnu-linux --class os {
    linux /images/pxeboot/vmlinuz rd.plymouth=0 plymouth.enable=0 root=live:CDLABEL=${VOLID} rd.live.image rd.retry=60 systemd.crash_reboot=0 rd.debug loglevel=7 console=ttyS0,115200 console=tty0
    initrd /images/pxeboot/initrd.img
}

menuentry "Enroll KythOS Secure Boot Key" --class efi {
    if [ -f /EFI/BOOT/mmx64.efi ]; then
        echo ""
        echo "KythOS uses a custom kernel that must be enrolled once for Secure Boot."
        echo ""
        echo "In MokManager (launching now):"
        echo "  1. Select 'Enroll key from disk'"
        echo "  2. Navigate: EFI -> BOOT -> kyth-secureboot.der"
        echo "  3. Select the file, choose 'Continue', then 'Yes', then 'Reboot'"
        echo "  4. After rebooting, select 'Try KythOS Live'"
        echo ""
        echo "Password prompt: type 'kyth' if asked (or leave blank)."
        echo ""
        sleep 6
        chainloader /EFI/BOOT/mmx64.efi
    else
        echo "MokManager (mmx64.efi) is missing from this ISO."
        echo "Reinstall shim-x64 in the live container and rebuild."
        sleep 4
    fi
}

GRUBEOF

cp "${ISO_DIR}/boot/grub2/grub.cfg" "${ISO_DIR}/EFI/BOOT/grub.cfg" 2>/dev/null

# ── Secure Boot: MOK cert for GRUB enrollment menu ────────────────────────────
# Convert the PEM cert from the repo to DER format. MokManager (mmx64.efi) reads
# DER when the user selects "Enroll key from disk" → EFI/BOOT/kyth-secureboot.der.
_SB_CERT_PEM="${SCRIPT_DIR}/secureboot/kyth-secureboot.cer"
_SB_CERT_DER="${ISO_DIR}/EFI/BOOT/kyth-secureboot.der"
if [[ -f "${_SB_CERT_PEM}" ]] && command -v openssl &>/dev/null; then
    openssl x509 -in "${_SB_CERT_PEM}" -outform DER -out "${_SB_CERT_DER}"
    echo "==> Secure Boot: kyth-secureboot.der added to EFI/BOOT"
else
    echo "WARNING: ${_SB_CERT_PEM} not found — Secure Boot enrollment entry will not work" >&2
fi

# ── 5b. UEFI EFI boot image (FAT) ────────────────────────────────────────────
echo "==> Creating UEFI EFI boot image"

GRUB_EFI_BUILT=false
GRUB_X64_MODS="/usr/lib/grub/x86_64-efi"
if [[ ! -d "${GRUB_X64_MODS}" && -d "${ROOTFS}/usr/lib/grub/x86_64-efi" ]]; then
    GRUB_X64_MODS="${ROOTFS}/usr/lib/grub/x86_64-efi"
fi

if [[ -d "${GRUB_X64_MODS}" ]] && command -v grub2-mkimage &>/dev/null; then
    GRUB_EMBED_CFG="${WORK}/grub-efi-embed.cfg"
    # Note: unquoted heredoc so ${VOLID} expands; $root is a GRUB variable and
    # must be escaped to prevent bash expansion.
    cat > "${GRUB_EMBED_CFG}" << EMBEDEOF
search --no-floppy --label --set=root ${VOLID}
set prefix=(\$root)/boot/grub2
source (\$root)/boot/grub2/grub.cfg
EMBEDEOF

    grub2-mkimage \
        -O x86_64-efi \
        -o "${ISO_DIR}/EFI/BOOT/grubx64.efi" \
        -p /boot/grub2 \
        -c "${GRUB_EMBED_CFG}" \
        -d "${GRUB_X64_MODS}" \
        linux normal iso9660 search search_label all_video gfxterm gfxmenu \
        efi_gop efi_uga font loopback chain \
        png echo test ls part_gpt part_msdos fat
    GRUB_EFI_BUILT=true
    echo "    UEFI GRUB binary: built with grub2-mkimage (x86_64-efi) → grubx64.efi"

    # Override with Fedora's pre-signed grubx64.efi when available.
    # The shim (BOOTX64.EFI) verifies grubx64.efi's signature before chainloading
    # it — our grub2-mkimage output is unsigned and would be rejected with
    # "did not authenticate". Fedora's signed binary is trusted by Fedora's shim
    # (the shim embeds Fedora's UEFI signing key).
    echo "    EFI binary sources in rootfs:"
    ls -la "${ROOTFS}/usr/lib/kyth/efi/" 2>/dev/null || echo "    (no staged EFI binaries at /usr/lib/kyth/efi/)"
    _SIGNED_GRUB_SRC=""
    # Check staged location first (set by Containerfile.live EFI staging step)
    for _grub_path in \
        "${ROOTFS}/usr/lib/kyth/efi/grubx64.efi" \
        "${ROOTFS}/boot/efi/EFI/fedora/grubx64.efi" \
        "${ROOTFS}/boot/efi/EFI/BOOT/grubx64.efi"; do
        if [[ -f "${_grub_path}" ]]; then
            _SIGNED_GRUB_SRC="${_grub_path}"
            break
        fi
    done
    # Versioned path from grub2-efi-x64 RPM: /usr/lib/efi/grub2/<ver>/EFI/fedora/grubx64.efi
    if [[ -z "${_SIGNED_GRUB_SRC}" ]]; then
        _SIGNED_GRUB_SRC=$(find "${ROOTFS}/usr/lib/efi/grub2" -name "grubx64.efi" 2>/dev/null | head -1)
    fi
    if [[ -z "${_SIGNED_GRUB_SRC}" ]]; then
        _SIGNED_GRUB_SRC=$(find "${ROOTFS}" -path "*/EFI/fedora/grubx64.efi" 2>/dev/null | head -1)
    fi
    if [[ -n "${_SIGNED_GRUB_SRC}" ]]; then
        copy_efi_from_rootfs "${_SIGNED_GRUB_SRC}" "${ISO_DIR}/EFI/BOOT/grubx64.efi"
        echo "    Secure Boot GRUB: ${_SIGNED_GRUB_SRC} → grubx64.efi (Fedora-signed)"
        # Fedora's signed grubx64.efi searches for /EFI/fedora/grub.cfg using
        # search.file, then sets prefix=($root)/EFI/fedora and loads that config.
        # Place a redirect there that locates the ISO by volume label and chains
        # to our full menu config (which lives in boot/grub2/grub.cfg on the ISO).
        # Note: unquoted heredoc so ${VOLID} expands; $root is a GRUB variable.
        cat > "${ISO_DIR}/EFI/fedora/grub.cfg" << FEDGRUBEOF
search --no-floppy --label --set=root ${VOLID}
configfile (\$root)/boot/grub2/grub.cfg
FEDGRUBEOF
        echo "    EFI/fedora/grub.cfg: search-by-label redirect written"
    else
        echo "ERROR: Fedora-signed grubx64.efi not found in rootfs." >&2
        echo "       The ISO would not boot on machines with Secure Boot enabled." >&2
        echo "       Ensure grub2-efi-x64 is installed in the live container." >&2
        exit 1
    fi

    # Secure Boot: use Fedora-signed shim as BOOTX64.EFI.
    # The shim (Microsoft-signed) is what UEFI firmware loads first; it then
    # chainloads grubx64.efi (Fedora-signed) from the same directory.
    SHIM_SRC=""
    # Check staged location first (set by Containerfile.live EFI staging step)
    for shim_path in \
        "${ROOTFS}/usr/lib/kyth/efi/shimx64.efi" \
        "${ROOTFS}/boot/efi/EFI/fedora/shimx64.efi" \
        "${ROOTFS}/boot/efi/EFI/BOOT/shimx64.efi"; do
        if [[ -f "${shim_path}" ]]; then
            SHIM_SRC="${shim_path}"
            break
        fi
    done
    # Versioned path from shim-x64 RPM: /usr/lib/efi/shim/<ver>/EFI/fedora/shimx64.efi
    if [[ -z "${SHIM_SRC}" ]]; then
        SHIM_SRC=$(find "${ROOTFS}/usr/lib/efi/shim" -name "shimx64.efi" 2>/dev/null | head -1)
    fi
    # Last resort: any shimx64.efi anywhere in the rootfs
    if [[ -z "${SHIM_SRC}" ]]; then
        SHIM_SRC=$(find "${ROOTFS}" -name "shimx64.efi" 2>/dev/null | head -1)
    fi

    if [[ -n "${SHIM_SRC}" ]]; then
        copy_efi_from_rootfs "${SHIM_SRC}" "${ISO_DIR}/EFI/BOOT/BOOTX64.EFI"
        echo "    Secure Boot shim: ${SHIM_SRC} → BOOTX64.EFI"
        SHIM_DIR="$(dirname "${SHIM_SRC}")"
        # mmx64.efi (MokManager) lives next to shim — copy it for MOK enrollment
        if [[ -f "${SHIM_DIR}/mmx64.efi" ]]; then
            copy_efi_from_rootfs "${SHIM_DIR}/mmx64.efi" "${ISO_DIR}/EFI/BOOT/mmx64.efi"
            echo "    MokManager: ${SHIM_DIR}/mmx64.efi → EFI/BOOT/mmx64.efi"
        else
            MMX=$(find "${ROOTFS}" -name "mmx64.efi" 2>/dev/null | head -1)
            if [[ -n "${MMX}" ]]; then
                copy_efi_from_rootfs "${MMX}" "${ISO_DIR}/EFI/BOOT/mmx64.efi"
                echo "    MokManager: ${MMX} → EFI/BOOT/mmx64.efi"
            fi
        fi
    else
        echo "ERROR: shimx64.efi not found anywhere in rootfs."
        echo "       Ensure shim-x64 is installed in Containerfile.live."
        echo "       Without shim, Secure Boot machines will reject the ISO."
        exit 1
    fi
else
    echo "ERROR: Cannot build BOOTX64.EFI — grub2-mkimage or x86_64-efi modules not found." >&2
    echo "       Install on host: sudo dnf install grub2-tools-minimal" >&2
    exit 1
fi

EFI_IMG="${ISO_DIR}/images/efiboot.img"
truncate -s 15M "${EFI_IMG}"
mkfs.fat -n "EFIBOOT" "${EFI_IMG}"
mmd  -i "${EFI_IMG}" ::/EFI ::/EFI/BOOT ::/EFI/fedora
mcopy -i "${EFI_IMG}" "${ISO_DIR}/EFI/BOOT/BOOTX64.EFI" ::/EFI/BOOT/BOOTX64.EFI
if [[ "${GRUB_EFI_BUILT}" == "true" ]]; then
    mcopy -i "${EFI_IMG}" "${ISO_DIR}/EFI/BOOT/grubx64.efi" ::/EFI/BOOT/grubx64.efi
fi
if [[ -f "${ISO_DIR}/EFI/BOOT/mmx64.efi" ]]; then
    mcopy -i "${EFI_IMG}" "${ISO_DIR}/EFI/BOOT/mmx64.efi" ::/EFI/BOOT/mmx64.efi
fi
mcopy -i "${EFI_IMG}" "${ISO_DIR}/EFI/BOOT/grub.cfg" ::/EFI/BOOT/grub.cfg
if [[ -f "${ISO_DIR}/EFI/fedora/grub.cfg" ]]; then
    mcopy -i "${EFI_IMG}" "${ISO_DIR}/EFI/fedora/grub.cfg" ::/EFI/fedora/grub.cfg
fi
if [[ -f "${ISO_DIR}/EFI/BOOT/kyth-secureboot.der" ]]; then
    mcopy -i "${EFI_IMG}" "${ISO_DIR}/EFI/BOOT/kyth-secureboot.der" ::/EFI/BOOT/kyth-secureboot.der
fi

cat > "${ISO_DIR}/startup.nsh" << 'NSHEOF'
@echo -off
echo Booting KythOS...
fs0:\EFI\BOOT\BOOTX64.EFI
NSHEOF

# ── 5c. BIOS boot ────────────────────────────────────────────────────────────
echo "==> Setting up BIOS boot"
HAVE_ISOLINUX=false
HAVE_BIOS_GRUB=false

GRUB_I386_MODS="${ROOTFS}/usr/lib/grub/i386-pc"
if [[ -d "${GRUB_I386_MODS}" ]] && command -v grub2-mkimage &>/dev/null; then
    echo "    Using GRUB2 BIOS (grub2-mkimage)"
    BIOS_IMG="${ISO_DIR}/boot/grub2/bios.img"
    grub2-mkimage \
        -O i386-pc-eltorito \
        -o "${BIOS_IMG}" \
        -p /boot/grub2 \
        -d "${GRUB_I386_MODS}" \
        linux normal iso9660 biosdisk all_video gfxterm gfxmenu png echo test ls
    HAVE_BIOS_GRUB=true
    echo "    GRUB2 BIOS boot image: OK"
else
    if [[ ! -d "${GRUB_I386_MODS}" ]]; then
        echo "    NOTE: grub2-pc not in rootfs — falling back to syslinux for BIOS" >&2
    fi
fi

ISOLINUX_BIN="${ROOTFS}/usr/share/syslinux/isolinux.bin"
if ! "${HAVE_BIOS_GRUB}" && sudo test -f "${ISOLINUX_BIN}"; then
    echo "    Falling back to syslinux"
    sudo cp "${ISOLINUX_BIN}" "${ISO_DIR}/isolinux/" 2>/dev/null
    for f in ldlinux.c32 vesamenu.c32 libcom32.c32 libutil.c32; do
        src="${ROOTFS}/usr/share/syslinux/${f}"
        if sudo test -f "${src}"; then sudo cp "${src}" "${ISO_DIR}/isolinux/" 2>/dev/null || true; fi
    done

    cat > "${ISO_DIR}/isolinux/isolinux.cfg" << ISOLINUXEOF
default vesamenu.c32
timeout 100
menu title KythOS 44 Live

menu color screen     37;40    #a0000000 #00000000 std
menu color border     30;44    #00000000 #00000000 std
menu color title      1;37;44  #ffffffff #00000000 std
menu color scrollbar  30;44    #40000000 #00000000 std
menu color sel        7;37;40  #e0ffffff #20207fff std
menu color hotsel     1;7;37;40 #e0ffffff #20207fff std
menu color unsel      37;44    #70ffffff #00000000 std
menu color help       37;40    #c0ffffff #00000000 std
menu color timeout_msg 37;40   #80ffffff #00000000 std
menu color timeout    1;37;40  #c0ffffff #00000000 std
menu color cmdline    37;40    #c0ffffff #00000000 std
menu hshift 13
menu margin 8
menu rows 5
menu vshift 12
menu tabmsgrow 18
menu helpmsgrow 20

label live
  menu label Try KythOS Live
  kernel /images/pxeboot/vmlinuz
  append initrd=/images/pxeboot/initrd.img ${LIVE_ARGS}

label hwgl
  menu label Try KythOS Live (Hardware GL Test)
  kernel /images/pxeboot/vmlinuz
  append initrd=/images/pxeboot/initrd.img ${LIVE_ARGS} kyth.live.hwgl=1 kyth.installer.hwgl=1

ISOLINUXEOF
    HAVE_ISOLINUX=true
    echo "    syslinux: OK (fallback)"
fi

# ── 6. Assemble ISO ───────────────────────────────────────────────────────────
echo "==> Assembling ISO: ${OUTPUT_DIR}/${ISO_NAME}"
sudo mkdir -p "${OUTPUT_DIR}"
sudo chown "$(id -u):$(id -g)" "${OUTPUT_DIR}"

XORRISO_ARGS=(
    -as mkisofs
    -o "${OUTPUT_DIR}/${ISO_NAME}"
    -V "${VOLID}"
    -iso-level 3
    -R -J -joliet-long
)

if [[ "${HAVE_BIOS_GRUB}" == "true" ]]; then
    XORRISO_ARGS+=(
        -b boot/grub2/bios.img
        -no-emul-boot -boot-load-size 4 -boot-info-table
        --grub2-boot-info
    )
elif [[ "${HAVE_ISOLINUX}" == "true" ]]; then
    XORRISO_ARGS+=(
        -b isolinux/isolinux.bin
        -c isolinux/boot.cat
        -no-emul-boot -boot-load-size 4 -boot-info-table
    )
fi

XORRISO_ARGS+=(
    -eltorito-alt-boot
    -e images/efiboot.img
    -no-emul-boot
    --efi-boot-part --efi-boot-image
)

XORRISO_ARGS+=("${ISO_DIR}")

sudo xorriso "${XORRISO_ARGS[@]}"
sudo chown "$(id -u):$(id -g)" "${OUTPUT_DIR}/${ISO_NAME}"

ISO_SIZE=$(du -sh "${OUTPUT_DIR}/${ISO_NAME}" | cut -f1)
ISO_PATH=$(readlink -f "${OUTPUT_DIR}/${ISO_NAME}")
elapsed_h=$((SECONDS / 3600))
elapsed_m=$(((SECONDS % 3600) / 60))
elapsed_s=$((SECONDS % 60))
echo ""
echo "==> KythOS live ISO ready"
echo "    ${ISO_PATH} (${ISO_SIZE})"
echo "==> Timing: total elapsed ${elapsed_h}h ${elapsed_m}m ${elapsed_s}s"
