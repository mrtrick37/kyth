#!/bin/bash
set -euo pipefail

# SELinux: ship enforcing. Docker builds don't preserve security xattrs, but
# that doesn't matter here — bootc/ostree runs restorecon against the deployed
# tree on every deployment using the policy bundled in the image, so all files
# are correctly labeled before the system ever boots.

# Apply KythOS branding to the base image
cat > /etc/os-release <<'EOF' || true
NAME="KythOS"
PRETTY_NAME="KythOS 44"
ID=fedora
VERSION_ID="44"
ANSI_COLOR="0;34"
HOME_URL="https://github.com/mrtrick37/kyth"
SUPPORT_URL="https://github.com/mrtrick37/kyth/discussions"
BUG_REPORT_URL="https://github.com/mrtrick37/kyth/issues"
EOF

echo "KythOS base customization applied"

# ── CachyOS kernel ────────────────────────────────────────────────────────────
# Install with --noscripts to skip the %posttrans that calls rpm-ostree
# kernel-install → dracut, which fails in container builds due to EXDEV errors
# when dracut tries to rename tmp files across the overlay filesystem.
# We run dracut ourselves below with full control over the environment.
dnf5 copr enable -y bieszczaders/kernel-cachyos
dnf5 install -y --setopt=tsflags=noscripts kernel-cachyos-modules

CACHYOS_KVER=$(basename "$(echo /usr/lib/modules/*cachyos*)")
depmod -a "${CACHYOS_KVER}"

dnf5 install -y --setopt=tsflags=noscripts --skip-unavailable \
    kernel-cachyos \
    kernel-cachyos-core \
    kernel-cachyos-devel

depmod -a "${CACHYOS_KVER}"

# Remove every non-CachyOS kernel from /usr/lib/modules/ so bootc sees
# exactly one kernel (it errors out if multiple subdirectories are present).
for kdir in /usr/lib/modules/*/; do
    kver=$(basename "$kdir")
    if [[ "$kver" != *cachyos* ]]; then
        echo "Removing non-CachyOS kernel: ${kver}"
        rm -rf "$kdir"
    fi
done
rpm -qa | grep -E '^kernel' | grep -v cachyos | xargs -r rpm --nodeps -e 2>/dev/null || true

# Ensure vmlinuz is in the OSTree-expected location
# (kernel RPMs may put it in /boot; bootc needs it at /usr/lib/modules/<kver>/vmlinuz)
if [ ! -f "/usr/lib/modules/${CACHYOS_KVER}/vmlinuz" ]; then
    if [ -f "/boot/vmlinuz-${CACHYOS_KVER}" ]; then
        cp --no-preserve=all "/boot/vmlinuz-${CACHYOS_KVER}" "/usr/lib/modules/${CACHYOS_KVER}/vmlinuz" 2>/dev/null
    fi
fi

# Write dracut config — force the ostree module required for bootc deployments.
# Without it the initramfs cannot find or mount the root filesystem.
mkdir -p /etc/dracut.conf.d
cat > /etc/dracut.conf.d/99-kyth.conf <<'DRACUTEOF'
add_dracutmodules+=" ostree "
# virtio_blk/virtio_scsi/ahci are built into the CachyOS kernel (=y),
# so add_drivers has no effect for them. Kept for documentation.
add_drivers+=" virtio_blk virtio_scsi virtio_pci nvme ahci "
DRACUTEOF

TMPDIR=/var/tmp dracut \
    --no-hostonly \
    --kver "${CACHYOS_KVER}" \
    --force \
    "/usr/lib/modules/${CACHYOS_KVER}/initramfs" \
    2> >(grep -Ev 'xattr|fail to copy' >&2)

dnf5 copr disable -y bieszczaders/kernel-cachyos

# Set kernel args for the installed system via bootc kargs.d.
# quiet: suppress kernel log spam on the console.
# splash: activate Plymouth so the boot splash is shown.
# iommu=pt: Intel VT-d passthrough mode — prevents strict IOMMU isolation from
#   breaking DRM/KMS on Intel vPro and similar enterprise hardware where VT-d is
#   enabled by default. Transparent/no-op on AMD systems.
# amdgpu.sg_display=0: disables scatter-gather display on the amdgpu driver.
#   Without this, AMD laptop panels (eDP) blink/flash repeatedly during the
#   Plymouth → SDDM KMS handoff — reproducible on ASUS TUF A16 and other AMD
#   Radeon laptop designs. sg_display uses IOMMU-mapped scatter lists for the
#   display engine; on laptops where the panel is on the iGPU eDP output the
#   IOMMU mapping stalls cause the display controller to blank and re-sync
#   multiple times per second until the driver settles. Setting it to 0 forces
#   the driver to use a contiguous-memory framebuffer for the display engine
#   instead, which is slightly less memory-efficient but eliminates the blink.
mkdir -p /usr/lib/bootc/kargs.d
cat > /usr/lib/bootc/kargs.d/99-kyth.toml <<'KARGSEOF'
kargs = ["quiet", "splash", "threadirqs", "iommu=pt", "pcie_aspm=off", "amdgpu.sg_display=0"]
KARGSEOF

# ── Continue + Code Llama 7B integration ─────────────────────────────────────
echo "==> Downloading Code Llama 7B (Q4_K_M, CPU) GGUF model..."

# Use /var/lib for model storage (always a directory in Fedora/Kinoite/bootc)
MODEL_DIR="/var/lib/llm-models/codellama"
MODEL_FILE="codellama-7b-instruct.Q4_K_M.gguf"
# Robustly create all parent directories
if ! mkdir -p "$MODEL_DIR"; then
    echo "ERROR: Failed to create $MODEL_DIR. Check permissions or parent directories." >&2
    exit 1
fi

# Debug: show disk space and permissions
set -x
df -h "$MODEL_DIR" || df -h /
ls -ld "$MODEL_DIR"
touch "$MODEL_DIR/testfile" && rm "$MODEL_DIR/testfile"

# Remove partial/truncated file if present
if [ -f "$MODEL_DIR/$MODEL_FILE" ] && [ $(stat -c%s "$MODEL_DIR/$MODEL_FILE") -lt 100000000 ]; then
  echo "Partial or truncated model file found, removing: $MODEL_DIR/$MODEL_FILE"
  rm -f "$MODEL_DIR/$MODEL_FILE"
fi

if [ ! -f "$MODEL_DIR/$MODEL_FILE" ]; then
    if [ -z "${HUGGINGFACE_TOKEN:-}" ]; then
        echo "ERROR: HUGGINGFACE_TOKEN environment variable not set. Aborting model download." >&2
        exit 1
    fi
    curl -L --retry 3 -H "Authorization: Bearer $HUGGINGFACE_TOKEN" \
        -o "$MODEL_DIR/$MODEL_FILE" \
        "https://huggingface.co/TheBloke/CodeLlama-7B-Instruct-GGUF/resolve/main/codellama-7b-instruct.Q4_K_M.gguf"
fi
chmod 644 "$MODEL_DIR/$MODEL_FILE"

# Write default Continue config (system-wide, user can override in ~/.continue/config.json)
mkdir -p /etc/continue
cat > /etc/continue/config.json <<'CONTINUEEOF'
{
    "models": [
        {
            "title": "Code Llama 7B (CPU, local)",
            "model": "llama.cpp",
            "apiBase": "http://localhost:8080",
            "modelPath": "/var/lib/llm-models/codellama/codellama-7b-instruct.Q4_K_M.gguf",
            "contextLength": 4096,
            "temperature": 0.2
        }
    ]
}
CONTINUEEOF
chmod 644 /etc/continue/config.json

# ── Install llama.cpp and systemd service for model API ─────────────────────
echo "==> Installing llama.cpp for local LLM serving..."
# Ensure kernel headers and glibc-devel are present for CachyOS/Fedora builds
dnf5 install -y kernel-headers glibc-devel git cmake make gcc-c++
cd /tmp
git clone --depth 1 https://github.com/ggerganov/llama.cpp.git

# Robust binary install for immutable/ostree systems
if [ -d /opt ]; then
    INSTALL_BIN_DIR="/opt/llama.cpp/bin"
    mkdir -p "$INSTALL_BIN_DIR"
else
    INSTALL_BIN_DIR="/usr/libexec/llama.cpp/bin"
    mkdir -p "$INSTALL_BIN_DIR"
fi
cd /tmp/llama.cpp
cmake -S . -B build
cmake --build build -- -j$(nproc)
cp ./build/bin/llama-server "$INSTALL_BIN_DIR/llama-cpp-server"
chmod 755 "$INSTALL_BIN_DIR/llama-cpp-server"
cd / && rm -rf /tmp/llama.cpp

# Create systemd service to run llama.cpp server at boot
cat > /etc/systemd/system/llama-cpp-server.service <<LLAMASVC
[Unit]
Description=llama.cpp server for Code Llama 7B (API for Continue)
After=network.target
# Do not start if the model file was not downloaded during image build
# (network timeout, disk full, etc.). Without this guard the service
# crashes immediately and restarts indefinitely, delaying graphical.target.
ConditionPathExists=/var/lib/llm-models/codellama/codellama-7b-instruct.Q4_K_M.gguf

[Service]
Type=simple
ExecStart=$INSTALL_BIN_DIR/llama-cpp-server --model /var/lib/llm-models/codellama/codellama-7b-instruct.Q4_K_M.gguf --host 127.0.0.1 --port 8080 --ctx-size 4096 --threads $(nproc)
Restart=on-failure
RestartSec=10
# Cap retries: stop hammering after 3 failures in 60 s. Prevents a corrupt
# model file or missing binary from filling the journal and stalling boot.
StartLimitBurst=3
StartLimitIntervalSec=60
User=root

[Install]
# graphical.target, not multi-user.target — this is a developer tool that
# should not block the text-mode boot path or delay sddm startup.
WantedBy=graphical.target
LLAMASVC
systemctl enable llama-cpp-server.service

# ── SDDM — ensure graphical target ───────────────────────────────────────────
systemctl enable sddm 2>/dev/null || true
systemctl set-default graphical.target 2>/dev/null || true

# Mask bootloader-update.service: this ostree/rpm-ostree service tries to
# update the bootloader on every boot but always fails in our bootc image,
# producing noisy FAILED entries in the boot log.
systemctl mask bootloader-update.service 2>/dev/null || true

# Mask systemd-remount-fs.service: on bootc/ostree the root filesystem is
# already mounted correctly by the bootloader; the remount always fails with
# exit code 32 producing a FAILED unit every boot.
systemctl mask systemd-remount-fs.service 2>/dev/null || true

# ── SDDM display server: Wayland by default ───────────────────────────────────
# Keep the on-disk config aligned with the documented product defaults so
# image behavior is obvious during debugging and CI review.
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-display-server.conf <<'EOF'
[General]
DisplayServer=wayland

[Wayland]
SessionDir=/usr/share/wayland-sessions
CompositorCommand=kwin_wayland --no-global-shortcuts --no-lockscreen --locale1
EOF


