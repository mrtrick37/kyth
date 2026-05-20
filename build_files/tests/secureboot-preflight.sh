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
CERT_DER="${SECUREBOOT_PREFLIGHT_DER:-${REPO_ROOT}/output/live-iso/kyth-secureboot.der}"
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

    grep -q 'SECUREBOOT_SIGN_EFI is not supported for live installer media' \
        "${REPO_ROOT}/build_files/build-live-iso.sh" \
        || fail "live ISO builder must reject Kyth-signing removable EFI binaries"
    ! grep -q 'sign_efi_with_kyth_key' "${REPO_ROOT}/build_files/build-live-iso.sh" \
        || fail "live ISO builder must not Kyth-sign BOOTX64.EFI/grubx64.efi/mmx64.efi"
    ! grep -q 'SECUREBOOT_SIGN_EFI: "1"' "${REPO_ROOT}/.github/workflows/build-live-iso.yml" \
        || fail "CI must not re-sign removable EFI boot binaries with the Kyth MOK"
    grep -q 'usr/lib/kyth/efi/BOOTX64.EFI' "${REPO_ROOT}/build_files/Containerfile.live" \
        || fail "live image must stage shim package removable-media BOOTX64.EFI"
    grep -q 'usr/lib/kyth/efi/BOOTX64.EFI' "${REPO_ROOT}/build_files/build-live-iso.sh" \
        || fail "ISO assembler must prefer packaged BOOTX64.EFI for removable media"
    grep -q 'GRUB_DEFAULT=3' "${REPO_ROOT}/build_files/build-live-iso.sh" \
        || fail "signed live media should default to the MOK enrollment menu"
    grep -q 'GRUB_TIMEOUT=-1' "${REPO_ROOT}/build_files/build-live-iso.sh" \
        || fail "signed live media should wait at GRUB for MOK enrollment"
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

        if [[ -n "${MOK_KEY:-}" ]]; then
            local key_file key_md5 cert_md5
            key_file="$(mktemp)"
            trap 'rm -f "${tmp_der}" "${key_file}"' RETURN
            printf '%s\n' "${MOK_KEY}" > "${key_file}"
            chmod 0600 "${key_file}"
            key_md5=$(openssl rsa -in "${key_file}" -noout -modulus 2>/dev/null | openssl md5 | awk '{print $2}' || true)
            cert_md5=$(openssl x509 -in "${CERT_PEM}" -noout -modulus 2>/dev/null | openssl md5 | awk '{print $2}' || true)
            [[ -n "${key_md5}" && "${key_md5}" == "${cert_md5}" ]] \
                || fail "MOK_KEY does not match ${CERT_PEM}"
            pass "MOK_KEY matches Kyth Secure Boot certificate"
        else
            warn "MOK_KEY not set; skipping private-key match check"
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
        kver=$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort -V | tail -n 1)
        test -n "${kver}"
        test -s "/usr/lib/modules/${kver}/vmlinuz"
        if test -f /usr/share/kyth/secureboot/live-kernel-signed; then
            command -v sbverify >/dev/null
            sbverify --cert /usr/share/kyth/secureboot/kyth-secureboot.cer "/usr/lib/modules/${kver}/vmlinuz" >/dev/null
        fi
    '
    pass "cached live image contains EFI binaries and kernel signing artifacts"
}

check_existing_iso_artifacts() {
    if [[ -f "${CERT_DER}" ]]; then
        need_file "${CERT_DER}" "exported MOK DER certificate"
    else
        warn "no exported DER certificate found yet: ${CERT_DER}"
    fi

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

    for efi_name in BOOTX64.EFI grubx64.efi; do
        mcopy -n -i "${efi_img}" "::/EFI/BOOT/${efi_name}" "${tmp_dir}/${efi_name}" >/dev/null
        sbverify --list "${tmp_dir}/${efi_name}" >/dev/null
        pass "ISO ${efi_name} has a Secure Boot signature"
    done

    if sbverify --cert "${CERT_PEM}" "${tmp_dir}/BOOTX64.EFI" >/dev/null 2>&1; then
        fail "ISO BOOTX64.EFI is signed by the Kyth MOK; fresh Secure Boot firmware will reject it"
    fi
    pass "ISO BOOTX64.EFI is not Kyth-MOK-signed"

    if mcopy -n -i "${efi_img}" "::/EFI/BOOT/mmx64.efi" "${tmp_dir}/mmx64.efi" >/dev/null 2>&1; then
        sbverify --list "${tmp_dir}/mmx64.efi" >/dev/null
        pass "ISO MokManager has a Secure Boot signature"
    else
        warn "ISO does not contain MokManager; enrollment menu will be unavailable"
    fi

    if mcopy -n -i "${efi_img}" "::/EFI/BOOT/kyth-secureboot.der" "${tmp_dir}/kyth-secureboot.der" >/dev/null 2>&1; then
        need_file "${tmp_dir}/kyth-secureboot.der" "ISO embedded Kyth MOK DER"
    else
        fail "ISO missing EFI/BOOT/kyth-secureboot.der for MokManager enrollment"
    fi
}

check_static_sources
check_cert_material
check_cached_live_image
check_existing_iso_artifacts

echo "secureboot preflight passed"
