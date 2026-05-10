#!/bin/bash
# secureboot.sh — sign the CachyOS vmlinuz with the KythOS MOK key.
#
# Skipped gracefully when no MOK key is provided (local builds without
# a secret configured). CI passes --secret id=mok_key,env=MOK_KEY.

set -euo pipefail

MOK_KEY_FILE="/run/secrets/mok_key"

if [[ ! -f "${MOK_KEY_FILE}" ]]; then
    echo "secureboot: no MOK key provided — Secure Boot signing skipped"
    echo "secureboot: set MOK_KEY env var and pass --secret id=mok_key,env=MOK_KEY to enable"
    exit 0
fi

CERT="/ctx/secureboot/kyth-secureboot.cer"

# ── Find the installed CachyOS kernel ────────────────────────────────────────
KVER=$(basename "$(ls -d /usr/lib/modules/*cachyos* 2>/dev/null | head -1)" 2>/dev/null || true)
if [[ -z "${KVER}" ]]; then
    echo "secureboot: ERROR — no CachyOS kernel found in /usr/lib/modules/" >&2
    exit 1
fi

VMLINUZ="/usr/lib/modules/${KVER}/vmlinuz"
if [[ ! -f "${VMLINUZ}" ]]; then
    echo "secureboot: ERROR — vmlinuz not found at ${VMLINUZ}" >&2
    exit 1
fi

# ── Install sbsigntools, sign, clean up ──────────────────────────────────────
echo "secureboot: installing sbsigntools"
dnf5 install -y sbsigntools

echo "secureboot: signing ${VMLINUZ} (kernel ${KVER})"
sbsign --key "${MOK_KEY_FILE}" \
       --cert "${CERT}" \
       --output "${VMLINUZ}.signed" \
       "${VMLINUZ}"
mv "${VMLINUZ}.signed" "${VMLINUZ}"

dnf5 remove -y sbsigntools
dnf5 clean all

echo "secureboot: vmlinuz signed successfully"

# ── Install runtime artifacts ─────────────────────────────────────────────────
# Public cert — needed by mokutil --import and readable by any user/tool
install -Dm 0644 "${CERT}" /usr/share/kyth/secureboot/kyth-secureboot.cer

# Enrollment script and first-boot service
install -Dm 0755 /ctx/kyth-enroll-mok        /usr/bin/kyth-enroll-mok
install -Dm 0644 /ctx/kyth-enroll-mok.service /usr/lib/systemd/system/kyth-enroll-mok.service
systemctl enable kyth-enroll-mok.service

echo "secureboot: Secure Boot support configured"
