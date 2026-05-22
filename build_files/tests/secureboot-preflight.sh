#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SOURCE_TAG="${SOURCE_TAG:-latest}"
if [[ -z "${LIVE_BUILD_TAG:-}" ]]; then
    if [[ "${SOURCE_TAG}" == "latest" ]]; then
        LIVE_BUILD_TAG="kyth-live:build"
    else
        LIVE_BUILD_TAG="kyth-live:build-${SOURCE_TAG}"
    fi
fi
CERT_PEM="${REPO_ROOT}/build_files/secureboot/kyth-secureboot.cer"
ISO_PATH="${SECUREBOOT_PREFLIGHT_ISO:-${REPO_ROOT}/output/live-iso/kyth-live-${SOURCE_TAG}.iso}"

pass() {
    printf 'ok: %s\n' "$*"
}

warn() {
    printf 'warn: %s\n' "$*" >&2
}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

need_file() {
    local path="$1"
    local label="$2"
    [[ -s "${path}" ]] || fail "${label} missing or empty: ${path}"
    pass "${label} present"
}

need_command_optional() {
    local command_name="$1"
    if command -v "${command_name}" >/dev/null 2>&1; then
        pass "${command_name} available"
        return 0
    fi
    warn "${command_name} not found; skipping checks that require it"
    return 1
}

check_static_sources() {
    bash -n \
        "${REPO_ROOT}/build_files/build-live-iso.sh" \
        "${REPO_ROOT}/build_files/kyth-enroll-mok" \
        "${REPO_ROOT}/build_files/scripts/secureboot.sh" \
        "${REPO_ROOT}/build_files/tests/secureboot-enrollment.sh"
    pass "Secure Boot shell sources parse"

    "${REPO_ROOT}/build_files/tests/secureboot-enrollment.sh" >/dev/null
    pass "MOK enrollment state machine test passed"

    ! grep -q 'SECUREBOOT_SIGN_EFI' \
        "${REPO_ROOT}/build_files/build-live-iso.sh" \
        || fail "live ISO builder must not expose EFI re-signing knobs"
    ! grep -q 'sign_efi_with_kyth_key' "${REPO_ROOT}/build_files/build-live-iso.sh" \
        || fail "live ISO builder must not Kyth-sign BOOTX64.EFI/grubx64.efi/mmx64.efi"
    ! grep -q 'SECUREBOOT_SIGN_EFI: "1"' "${REPO_ROOT}/.github/workflows/build-live-iso.yml" \
        || fail "CI must not re-sign removable EFI boot binaries with the Kyth MOK"
    grep -q 'cp /usr/lib/kyth/efi/shimx64.efi /usr/lib/kyth/efi/BOOTX64.EFI' "${REPO_ROOT}/build_files/Containerfile.live" \
        || fail "live image must stage shimx64.efi as removable-media BOOTX64.EFI"
    grep -q 'BOOTX64.EFI is not Microsoft UEFI-signed' "${REPO_ROOT}/build_files/build-live-iso.sh" \
        || fail "ISO assembler must require Microsoft-signed BOOTX64.EFI for removable media"
    grep -q "grep -Ev 'cachyos|ogc'" "${REPO_ROOT}/build_files/build-live-iso.sh" \
        || fail "ISO assembler must prefer the Fedora-signed live kernel"
    grep -q 'GRUB_DEFAULT=0' "${REPO_ROOT}/build_files/build-live-iso.sh" \
        || fail "Fedora-signed live media should default to the live desktop"
    grep -q 'GRUB_TIMEOUT=10' "${REPO_ROOT}/build_files/build-live-iso.sh" \
        || fail "Fedora-signed live media should not wait indefinitely for MOK enrollment"
    grep -q 'mok_state' "${REPO_ROOT}/build_files/kyth-installer" \
        || fail "installer must report MOK enrollment state to the UI"
    grep -q -- '--list-new' "${REPO_ROOT}/build_files/kyth-installer" \
        || fail "installer must detect already-pending MOK enrollment"
    grep -q '^search --no-floppy --label --set=root' "${REPO_ROOT}/build_files/build-live-iso.sh" \
        || fail "main GRUB menu must force root to the ISO volume before loading vmlinuz"
    grep -q '^configfile (\\$root)/boot/grub2/grub.cfg' "${REPO_ROOT}/build_files/build-live-iso.sh" \
        || fail "EFI GRUB stubs must redirect to the ISO GRUB menu"
    pass "live ISO Secure Boot policy checks passed"
}

check_cert_material() {
    need_file "${CERT_PEM}" "Kyth Secure Boot PEM certificate"

    if need_command_optional openssl; then
        openssl x509 -in "${CERT_PEM}" -noout -subject >/dev/null
        pass "PEM certificate is parseable"

        local tmp_der
        tmp_der="$(mktemp)"
        trap 'rm -f "${tmp_der}"' RETURN
        openssl x509 -in "${CERT_PEM}" -outform DER -out "${tmp_der}"
        [[ -s "${tmp_der}" ]] || fail "DER conversion produced an empty file"
        pass "PEM certificate converts to DER for MokManager"

        if [[ -n "${MOK_KEY_FILE:-}" && ! -f "${MOK_KEY_FILE}" ]]; then
            fail "MOK_KEY_FILE is set but does not exist: ${MOK_KEY_FILE}"
        fi

        if [[ -n "${MOK_KEY:-}" || -n "${MOK_KEY_FILE:-}" ]]; then
            local key_file key_md5 cert_md5
            if [[ -n "${MOK_KEY_FILE:-}" ]]; then
                key_file="${MOK_KEY_FILE}"
            else
                key_file="$(mktemp)"
                trap 'rm -f "${tmp_der}" "${key_file}"' RETURN
                printf '%s\n' "${MOK_KEY}" > "${key_file}"
                chmod 0600 "${key_file}"
            fi
            key_md5=$(openssl rsa -in "${key_file}" -noout -modulus 2>/dev/null | openssl md5 | awk '{print $2}' || true)
            cert_md5=$(openssl x509 -in "${CERT_PEM}" -noout -modulus 2>/dev/null | openssl md5 | awk '{print $2}' || true)
            [[ -n "${key_md5}" && "${key_md5}" == "${cert_md5}" ]] \
                || fail "MOK key does not match ${CERT_PEM}"
            pass "MOK key matches Kyth Secure Boot certificate"
        else
            warn "MOK key not set; skipping private-key match check"
        fi
    fi
}

check_cached_live_image() {
    if ! command -v docker >/dev/null 2>&1; then
        warn "docker not found; skipping cached live image checks"
        return 0
    fi
    if ! docker image inspect "${LIVE_BUILD_TAG}" >/dev/null 2>&1; then
        warn "cached live image not found (${LIVE_BUILD_TAG}); build once to enable image preflight"
        return 0
    fi

    docker run --rm "${LIVE_BUILD_TAG}" bash -euo pipefail -c '
        test -s /usr/lib/kyth/efi/BOOTX64.EFI
        test -s /usr/lib/kyth/efi/shimx64.efi
        test -s /usr/lib/kyth/efi/grubx64.efi
        test -s /usr/lib/kyth/efi/mmx64.efi
        test -s /usr/share/kyth/secureboot/kyth-secureboot.cer || true
        test -s /usr/share/kyth/secureboot/kyth-secureboot.der || true
        fedora_kver=$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | grep -Ev "cachyos|ogc" | sort -V | tail -n 1)
        test -n "${fedora_kver}"
        test -s "/usr/lib/modules/${fedora_kver}/vmlinuz"
        test -s "/usr/lib/modules/${fedora_kver}/initramfs-live"
        ! find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | grep -Eq "cachyos|ogc"
    '
    pass "cached live image contains EFI binaries and only the Fedora live kernel"
}

check_host_secureboot_db() {
    if ! command -v mokutil >/dev/null 2>&1; then
        warn "mokutil not found; skipping host firmware trust database hint"
        return 0
    fi

    local db
    db="$(mokutil --db 2>/dev/null || true)"
    if [[ -z "${db}" ]]; then
        warn "host Secure Boot db unavailable; boot in UEFI mode to inspect firmware trust anchors"
        return 0
    fi

    if grep -q 'Microsoft Corporation UEFI CA 2011' <<<"${db}"; then
        pass "host firmware db includes Microsoft Corporation UEFI CA 2011 for current Linux shim media"
    elif grep -q 'Microsoft UEFI CA 2023' <<<"${db}"; then
        warn "host firmware db has Microsoft UEFI CA 2023 but not Microsoft Corporation UEFI CA 2011"
        warn "current Fedora shim media may still be 2011-signed; firmware can reject it with 'selected boot image did not authenticate'"
    else
        warn "host firmware db does not include Microsoft third-party UEFI CA trust"
        warn "HP/Secured-core systems can reject Linux shim USB media until 'Enable MS UEFI CA key' is enabled or factory keys are restored"
    fi
}

check_existing_iso_artifacts() {
    if [[ ! -f "${ISO_PATH}" ]]; then
        warn "no existing ISO found to inspect: ${ISO_PATH}"
        return 0
    fi
    pass "existing ISO found: ${ISO_PATH}"

    if ! need_command_optional xorriso || ! need_command_optional mcopy || ! need_command_optional sbverify; then
        warn "install xorriso, mtools, and sbsigntools to inspect ISO EFI signatures locally"
        return 0
    fi

    local tmp_dir efi_img
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "${tmp_dir}"' RETURN
    efi_img="${tmp_dir}/efiboot.img"

    xorriso -osirrox on -indev "${ISO_PATH}" -extract /images/efiboot.img "${efi_img}" >/dev/null 2>&1
    need_file "${efi_img}" "ISO embedded EFI image"
    xorriso -osirrox on -indev "${ISO_PATH}" \
        -extract /images/pxeboot/vmlinuz "${tmp_dir}/vmlinuz" \
        -extract /images/pxeboot/initrd.img "${tmp_dir}/initrd.img" >/dev/null 2>&1
    [[ -s "${tmp_dir}/vmlinuz" && -s "${tmp_dir}/initrd.img" ]] \
        || fail "ISO missing live kernel or initramfs under /images/pxeboot"
    pass "ISO contains live kernel and initramfs under /images/pxeboot"
    if sbverify --cert "${CERT_PEM}" "${tmp_dir}/vmlinuz" >/dev/null 2>&1; then
        warn "ISO live kernel is still Kyth-signed; expected Fedora-signed live kernel path"
    else
        pass "ISO live kernel is not Kyth-signed; Fedora shim should trust the Fedora-signed kernel"
    fi

    mcopy -n -i "${efi_img}" "::/EFI/BOOT/BOOTX64.EFI" "${tmp_dir}/BOOTX64.EFI" >/dev/null
    boot_sig="$(sbverify --list "${tmp_dir}/BOOTX64.EFI" 2>&1)"
    grep -Eqi 'Microsoft (Corporation|Windows|UEFI)' <<<"${boot_sig}" \
        || fail "ISO BOOTX64.EFI is signed, but not by a Microsoft UEFI trust chain"
    pass "ISO BOOTX64.EFI has a Microsoft UEFI Secure Boot signature"

    mcopy -n -i "${efi_img}" "::/EFI/BOOT/grubx64.efi" "${tmp_dir}/grubx64.efi" >/dev/null
    sbverify --list "${tmp_dir}/grubx64.efi" >/dev/null
    pass "ISO grubx64.efi has a Secure Boot signature"

    mcopy -n -i "${efi_img}" "::/EFI/BOOT/grub.cfg" "${tmp_dir}/efi-boot-grub.cfg" >/dev/null
    grep -q 'configfile .*boot/grub2/grub.cfg' "${tmp_dir}/efi-boot-grub.cfg" \
        || fail "EFI/BOOT/grub.cfg must redirect to the ISO GRUB config, not contain the live menu"
    ! grep -q '^menuentry ' "${tmp_dir}/efi-boot-grub.cfg" \
        || fail "EFI/BOOT/grub.cfg contains live menu entries; GRUB would look for vmlinuz inside the FAT image"
    pass "EFI/BOOT/grub.cfg redirects to ISO GRUB config"

    xorriso -osirrox on -indev "${ISO_PATH}" -extract /boot/grub2/grub.cfg "${tmp_dir}/iso-grub.cfg" >/dev/null 2>&1
    grep -q '^search --no-floppy --label --set=root' "${tmp_dir}/iso-grub.cfg" \
        || fail "ISO GRUB menu does not force root to the ISO volume"
    grep -q '/images/pxeboot/vmlinuz' "${tmp_dir}/iso-grub.cfg" \
        || fail "ISO GRUB menu does not reference the live kernel"
    pass "ISO GRUB menu roots itself on the ISO and references the live kernel"

    if mcopy -n -i "${efi_img}" "::/EFI/BOOT/mmx64.efi" "${tmp_dir}/mmx64.efi" >/dev/null 2>&1; then
        sbverify --list "${tmp_dir}/mmx64.efi" >/dev/null
        pass "ISO MokManager has a Secure Boot signature"
    else
        warn "ISO does not contain MokManager; enrollment menu will be unavailable"
    fi

    if mcopy -n -i "${efi_img}" "::/EFI/BOOT/kyth-secureboot.der" "${tmp_dir}/kyth-secureboot.der" >/dev/null 2>&1; then
        fail "ISO should not expose Kyth MOK enrollment material on the normal live media"
    fi
}

check_static_sources
check_cert_material
check_cached_live_image
check_host_secureboot_db
check_existing_iso_artifacts

echo "secureboot preflight passed"
