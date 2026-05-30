#!/usr/bin/env bash
# build-live-iso.sh — assemble the KythOS live ISO from a pre-built installer container.
#
# Flow:
#   1. Build installer container (installer/Containerfile) unless SKIP_REBUILD=1
#   2. Export the container filesystem to a temp rootfs
#   3. mksquashfs the rootfs → LiveOS/squashfs.img
#   4. Assemble bootable ISO: UEFI (GRUB2) + BIOS (syslinux/grub-pc) via xorriso
#
# Host requirements (apt): xorriso squashfs-tools mtools dosfstools grub-common grub-efi-amd64-bin
# Host requirements (dnf): xorriso squashfs-tools mtools dosfstools grub2-tools grub2-efi-x64
# Container build: podman (with SYS_ADMIN cap) or docker

set -euo pipefail
SECONDS=0

SOURCE_TAG="${SOURCE_TAG:-latest}"
SKIP_REBUILD="${SKIP_REBUILD:-0}"

if [[ "${SOURCE_TAG}" == "latest" ]]; then
    LIVE_TAG="kyth-live:build"
else
    LIVE_TAG="kyth-live:build-${SOURCE_TAG}"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${KYTH_ISO_OUTPUT:-${REPO_ROOT}/output/live-iso}"
ISO_NAME="kyth-live-${SOURCE_TAG}.iso"
VOLID="KYTHOS-44-LIVE"

# Pick build scratch directory
TMPDIR_BASE="${TMPDIR:-/var/tmp}"
WORK=$(mktemp -d -p "${TMPDIR_BASE}" kyth-live.XXXXXXXXXX)
ROOTFS="${WORK}/rootfs"
ISO_DIR="${WORK}/iso"

cleanup() {
    echo "==> Cleaning up ${WORK}"
    sudo rm -rf "${WORK}" 2>/dev/null || true
}
trap cleanup EXIT

# ── Dependency check ──────────────────────────────────────────────────────────
missing=()
for cmd in xorriso mksquashfs mkfs.fat mcopy mmd; do
    command -v "${cmd}" &>/dev/null || missing+=("${cmd}")
done
if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: missing ISO build tools: ${missing[*]}" >&2
    echo "  Ubuntu/Debian: sudo apt-get install xorriso squashfs-tools mtools dosfstools" >&2
    echo "  Fedora (in toolbox): sudo dnf install xorriso squashfs-tools mtools dosfstools" >&2
    exit 1
fi

# Pick container engine — prefer podman (supports --cap-add without daemon config)
if command -v podman &>/dev/null; then
    CONTAINER_ENGINE="podman"
elif command -v docker &>/dev/null; then
    CONTAINER_ENGINE="docker"
else
    echo "ERROR: neither podman nor docker found" >&2
    exit 1
fi
echo "==> Container engine: ${CONTAINER_ENGINE}"
echo "==> Source tag: ${SOURCE_TAG}  →  image tag: ${LIVE_TAG}"

mkdir -p "${ROOTFS}" "${ISO_DIR}/LiveOS" "${ISO_DIR}/images/pxeboot" \
         "${ISO_DIR}/boot/grub2" "${ISO_DIR}/EFI/BOOT" \
         "${ISO_DIR}/isolinux"

# ── 1. Build installer container ─────────────────────────────────────────────
BASE_IMAGE="${INSTALLER_BASE_IMAGE:-ghcr.io/mrtrick37/kyth:${SOURCE_TAG}}"

if [[ "${SKIP_REBUILD}" == "1" ]]; then
    echo "==> SKIP_REBUILD=1: using pre-built container ${LIVE_TAG}"
else
    echo "==> Building installer container from ${BASE_IMAGE}"
    # SYS_ADMIN is required by dracut and /proc/sys remount inside the build
    BUILD_ARGS=(
        --cap-add SYS_ADMIN
        --security-opt label=disable
        --build-arg "BASE_IMAGE=${BASE_IMAGE}"
        --build-arg "SOURCE_TAG=${SOURCE_TAG}"
        --tag "${LIVE_TAG}"
        -f installer/Containerfile
        .
    )
    if [[ "${CONTAINER_ENGINE}" == "podman" ]]; then
        sudo podman build "${BUILD_ARGS[@]}"
    else
        # docker build (not buildx) supports --cap-add for RUN steps
        docker build "${BUILD_ARGS[@]}"
    fi
fi
echo "==> Timing: container ready at ${SECONDS}s"

# ── 2. Export rootfs ──────────────────────────────────────────────────────────
echo "==> Exporting container filesystem to ${ROOTFS}"
if [[ "${CONTAINER_ENGINE}" == "podman" ]]; then
    CID=$(sudo podman create "${LIVE_TAG}" /bin/true)
    sudo podman export "${CID}" | sudo tar -x -C "${ROOTFS}"
    sudo podman rm "${CID}"
else
    CID=$(docker create "${LIVE_TAG}" /bin/true)
    docker export "${CID}" | sudo tar -x -C "${ROOTFS}"
    docker rm "${CID}"
fi
echo "==> Timing: export complete at ${SECONDS}s"

# ── 3. Locate kernel and live initramfs ───────────────────────────────────────
echo "==> Locating kernel and live initramfs"
KVER=$(find "${ROOTFS}/usr/lib/modules" -mindepth 1 -maxdepth 1 -type d \
    -printf '%f\n' | grep -v cachyos | sort -V | tail -n 1)
test -n "${KVER}" || { echo "ERROR: no kernel found in rootfs" >&2; exit 1; }

VMLINUZ="${ROOTFS}/usr/lib/modules/${KVER}/vmlinuz"
INITRAMFS="${ROOTFS}/usr/lib/modules/${KVER}/initramfs.img"
test -s "${VMLINUZ}"   || { echo "ERROR: vmlinuz missing for ${KVER}" >&2; exit 1; }
test -s "${INITRAMFS}" || { echo "ERROR: initramfs.img missing for ${KVER} (build.sh dracut step failed?)" >&2; exit 1; }

echo "    Kernel:    ${KVER}"
echo "    vmlinuz:   $(du -sh "${VMLINUZ}" | cut -f1)"
echo "    initramfs: $(du -sh "${INITRAMFS}" | cut -f1)"

sudo cp "${VMLINUZ}"   "${ISO_DIR}/images/pxeboot/vmlinuz"
sudo cp "${INITRAMFS}" "${ISO_DIR}/images/pxeboot/initrd.img"

# ── 4. squashfs ───────────────────────────────────────────────────────────────
echo "==> Creating squashfs (zstd, $(nproc) cores)"
ZSTD_LEVEL="${ZSTD_LEVEL:-3}"
sudo mksquashfs "${ROOTFS}" "${ISO_DIR}/LiveOS/squashfs.img" \
    -comp zstd \
    -Xcompression-level "${ZSTD_LEVEL}" \
    -processors "$(nproc)" \
    -noappend \
    -no-progress \
    -e proc -e sys -e dev -e run
echo "==> Timing: squashfs complete at ${SECONDS}s"

# ── 5. GRUB config ────────────────────────────────────────────────────────────
# Read entries from iso.yaml baked into the container; fall back to defaults
ISO_YAML="${ROOTFS}/usr/lib/bootc-image-builder/iso.yaml"
ENTRY1_ARGS="quiet rhgb splash root=live:CDLABEL=${VOLID} rd.live.image rd.live.overlay.overlayfs=1 kyth.live=1 enforcing=0"
ENTRY2_ARGS="${ENTRY1_ARGS} nomodeset"
GRUB_TIMEOUT=10

if [[ -f "${ISO_YAML}" ]]; then
    # Extract the first linux= line from iso.yaml (everything after 'vmlinuz ')
    _line=$(grep 'linux:' "${ISO_YAML}" | head -1 | sed 's/.*vmlinuz //')
    [[ -n "${_line}" ]] && ENTRY1_ARGS="${_line}"
    _line2=$(grep 'linux:' "${ISO_YAML}" | sed -n '2p' | sed 's/.*vmlinuz //')
    [[ -n "${_line2}" ]] && ENTRY2_ARGS="${_line2}"
    _timeout=$(grep 'timeout:' "${ISO_YAML}" | head -1 | awk '{print $2}')
    [[ "${_timeout}" =~ ^[0-9]+$ ]] && GRUB_TIMEOUT="${_timeout}"
fi

cat > "${ISO_DIR}/boot/grub2/grub.cfg" << GRUBEOF
search --no-floppy --label --set=root ${VOLID}
set default=0
set timeout=${GRUB_TIMEOUT}

insmod all_video
insmod gfxterm
if loadfont /boot/grub2/unicode.pf2; then
    set gfxmode=auto
    terminal_output gfxterm
fi

menuentry "Try KythOS Live" --class fedora --class gnu-linux --class os {
    linux /images/pxeboot/vmlinuz ${ENTRY1_ARGS}
    initrd /images/pxeboot/initrd.img
}

menuentry "Try KythOS Live (Basic Graphics)" --class fedora --class gnu-linux --class os {
    linux /images/pxeboot/vmlinuz ${ENTRY2_ARGS}
    initrd /images/pxeboot/initrd.img
}
GRUBEOF

# Copy unicode font if available in rootfs
for font_src in \
    "${ROOTFS}/usr/share/grub/unicode.pf2" \
    "${ROOTFS}/boot/grub2/fonts/unicode.pf2" \
    "/usr/share/grub/unicode.pf2"; do
    if [[ -f "${font_src}" ]]; then
        sudo cp "${font_src}" "${ISO_DIR}/boot/grub2/unicode.pf2"
        break
    fi
done

# ── 6. UEFI EFI boot image ────────────────────────────────────────────────────
echo "==> Creating UEFI EFI boot image"
EFI_IMG="${WORK}/efiboot.img"
EFI_SIZE_MB=20
dd if=/dev/zero of="${EFI_IMG}" bs=1M count="${EFI_SIZE_MB}" 2>/dev/null
mkfs.fat -F 12 "${EFI_IMG}" >/dev/null

# EFI boot stub grub.cfg: redirect to the ISO GRUB menu
cat > "${WORK}/efi-stub.cfg" << STUBEOF
search --no-floppy --label --set=root ${VOLID}
configfile (\$root)/boot/grub2/grub.cfg
STUBEOF

mmd    -i "${EFI_IMG}" ::/EFI ::/EFI/BOOT
mcopy  -i "${EFI_IMG}" "${WORK}/efi-stub.cfg" ::/EFI/BOOT/grub.cfg

# Copy EFI binaries from the container (staged by installer/build.sh)
EFI_SRC="${ROOTFS}/boot/efi/EFI"
GRUB_EFI_BUILT=false

if [[ -d "${EFI_SRC}/BOOT" ]]; then
    for f in BOOTX64.EFI grubx64.efi mmx64.efi shimx64.efi; do
        src="${EFI_SRC}/BOOT/${f}"
        [[ -f "${src}" ]] && mcopy -i "${EFI_IMG}" "${src}" "::/EFI/BOOT/${f}" || true
    done
    GRUB_EFI_BUILT=true
fi

if [[ -d "${EFI_SRC}/fedora" ]]; then
    mmd -i "${EFI_IMG}" ::/EFI/fedora 2>/dev/null || true
    for f in grubx64.efi gcdx64.efi shim.efi; do
        src="${EFI_SRC}/fedora/${f}"
        [[ -f "${src}" ]] && mcopy -i "${EFI_IMG}" "${src}" "::/EFI/fedora/${f}" || true
    done
    # EFI/fedora/grub.cfg redirect
    cat > "${WORK}/fedora-grub.cfg" << FEDGRAEOF
search --no-floppy --label --set=root ${VOLID}
configfile (\$root)/boot/grub2/grub.cfg
FEDGRAEOF
    mcopy -i "${EFI_IMG}" "${WORK}/fedora-grub.cfg" ::/EFI/fedora/grub.cfg || true
fi

# Fallback: build grubx64.efi with grub2-mkimage if the container didn't stage it
if [[ "${GRUB_EFI_BUILT}" == "false" ]]; then
    echo "==> WARNING: no EFI binaries found in rootfs; attempting grub2-mkimage fallback"
    GRUB_MK=$(command -v grub2-mkimage || command -v grub-mkimage || echo "")
    GRUB_MODS=$(find /usr/lib/grub/x86_64-efi \
        "${ROOTFS}/usr/lib/grub/x86_64-efi" \
        -maxdepth 1 -name "*.mod" 2>/dev/null | head -1 | xargs dirname 2>/dev/null || echo "")
    if [[ -n "${GRUB_MK}" && -n "${GRUB_MODS}" ]]; then
        "${GRUB_MK}" \
            -d "${GRUB_MODS}" \
            -O x86_64-efi \
            -p /boot/grub2 \
            -o "${WORK}/grubx64.efi" \
            part_gpt part_msdos fat iso9660 normal boot linux echo configfile \
            search search_fs_uuid search_fs_file search_label gfxterm \
            gfxterm_background all_video video_bochs video_cirrus
        mmd  -i "${EFI_IMG}" ::/EFI ::/EFI/BOOT 2>/dev/null || true
        mcopy -i "${EFI_IMG}" "${WORK}/grubx64.efi"   ::/EFI/BOOT/grubx64.efi
        mcopy -i "${EFI_IMG}" "${WORK}/grubx64.efi"   ::/EFI/BOOT/BOOTX64.EFI
        mcopy -i "${EFI_IMG}" "${WORK}/efi-stub.cfg"  ::/EFI/BOOT/grub.cfg
    else
        echo "==> WARNING: grub2-mkimage not available; UEFI boot may not work"
    fi
fi

sudo cp "${EFI_IMG}" "${ISO_DIR}/images/efiboot.img"
echo "==> UEFI EFI image: $(du -sh "${EFI_IMG}" | cut -f1)"

# ── 7. BIOS boot (isolinux / grub-pc) ────────────────────────────────────────
HAVE_ISOLINUX=false
ISOLINUX_SRC=""
for d in \
    "${ROOTFS}/usr/share/syslinux" \
    "/usr/share/syslinux" \
    "/usr/lib/syslinux/modules/bios"; do
    if [[ -f "${d}/isolinux.bin" ]]; then
        ISOLINUX_SRC="${d}"
        break
    fi
done

if [[ -n "${ISOLINUX_SRC}" ]]; then
    for f in isolinux.bin ldlinux.c32 vesamenu.c32 libutil.c32 libcom32.c32; do
        [[ -f "${ISOLINUX_SRC}/${f}" ]] && cp "${ISOLINUX_SRC}/${f}" "${ISO_DIR}/isolinux/" || true
    done
    cat > "${ISO_DIR}/isolinux/isolinux.cfg" << ISOLINUXEOF
default vesamenu.c32
timeout 100
menu title KythOS 44 Live

label live
  menu label Try KythOS Live
  kernel /images/pxeboot/vmlinuz
  append initrd=/images/pxeboot/initrd.img ${ENTRY1_ARGS}

label live-basic
  menu label Try KythOS Live (Basic Graphics)
  kernel /images/pxeboot/vmlinuz
  append initrd=/images/pxeboot/initrd.img ${ENTRY2_ARGS}
ISOLINUXEOF
    HAVE_ISOLINUX=true
    echo "==> syslinux BIOS boot: OK"
fi

# grub2-pc BIOS fallback (used on Ubuntu CI runners where syslinux isn't in rootfs)
GRUB_PC_ELTORITO=""
for eltorito in \
    "${ROOTFS}/usr/lib/grub/i386-pc/eltorito.img" \
    "/usr/lib/grub/i386-pc/eltorito.img" \
    "$(find /usr/lib/grub2 /usr/lib/grub -name eltorito.img 2>/dev/null | head -1)"; do
    if [[ -f "${eltorito}" ]]; then
        GRUB_PC_ELTORITO="${eltorito}"
        break
    fi
done

# ── 8. Assemble ISO ───────────────────────────────────────────────────────────
echo "==> Assembling ISO: ${OUTPUT_DIR}/${ISO_NAME}"
sudo mkdir -p "${OUTPUT_DIR}"
sudo chown "$(id -u):$(id -g)" "${OUTPUT_DIR}"

XORRISO_ARGS=(
    -as mkisofs
    -o "${OUTPUT_DIR}/${ISO_NAME}"
    -V "${VOLID}"
    -iso-level 3
    -rock
    -joliet
    # UEFI
    -eltorito-alt-boot
    -e images/efiboot.img
    -no-emul-boot
    -append_partition 2 0xef "${ISO_DIR}/images/efiboot.img"
    -partition_offset 16
)

if [[ "${HAVE_ISOLINUX}" == "true" && -f "${ISO_DIR}/isolinux/isolinux.bin" ]]; then
    XORRISO_ARGS+=(
        # BIOS isolinux
        -b isolinux/isolinux.bin
        -c isolinux/boot.cat
        -no-emul-boot
        -boot-load-size 4
        -boot-info-table
        --grub2-mbr "${ISO_DIR}/isolinux/isolinux.bin"
    )
elif [[ -n "${GRUB_PC_ELTORITO}" ]]; then
    XORRISO_ARGS+=(
        -b boot/grub2/i386-pc/eltorito.img
        -no-emul-boot
        -boot-load-size 4
        -boot-info-table
        --grub2-mbr "${GRUB_PC_ELTORITO}"
    )
fi

XORRISO_ARGS+=("${ISO_DIR}")

sudo xorriso "${XORRISO_ARGS[@]}"

ISO_PATH="${OUTPUT_DIR}/${ISO_NAME}"
ISO_SIZE=$(du -sh "${ISO_PATH}" | cut -f1)
echo "==> KythOS live ISO ready"
echo "    ${ISO_PATH} (${ISO_SIZE})"
echo "==> Timing: total elapsed $(( SECONDS / 60 ))m $(( SECONDS % 60 ))s"
