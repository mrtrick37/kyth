# OpenSSF Best Practices: Passing Security Evidence

This document maps the OpenSSF Best Practices Passing security criteria for
KythOS to project evidence. It is intended to support the badge entry at
bestpractices.dev and to keep the justifications reviewable in the repository.

Badge form entries can use the short "Recommended entry" text below. Longer
evidence is included so the answers remain auditable after the form is updated.

## Secure Development Knowledge

### `know_secure_design`

Recommended status: Met

Recommended entry: The primary maintainer documents and applies secure design
practices in `docs/security-model.md`, including trust boundaries, release
integrity, private vulnerability reporting, least-privilege CI permissions,
rollback, signed releases, SBOMs, CVE scanning, and privileged-helper review.

KythOS is maintained with secure design practices documented in
`docs/security-model.md`: release integrity, trust boundaries, least-privilege
CI permissions, private vulnerability reporting, rollback, signed releases,
SBOMs, CVE scanning, and cautious handling of privileged helpers and user
credentials.

### `know_common_errors`

Recommended status: Met

Recommended entry: The project documents common OS-image risks and mitigations:
untrusted artifacts, CI credential exposure, installer disk-writing misuse,
shell injection, credential leakage in diagnostics, insecure downloads, and
update/rollback/Secure Boot regressions.

The project documents common error classes relevant to this OS image:

- Untrusted release artifacts or moving tags.
- CI/CD credential exposure.
- Installer disk-writing misuse.
- Shell injection and unsafe command construction.
- Logging or publishing credentials in diagnostics.
- Insecure downloads or unsigned checksums.
- Regressions in update, rollback, or Secure Boot paths.

Mitigations are documented in `docs/security-model.md`,
`docs/dependency-management.md`, `SECURITY.md`, and `CONTRIBUTING.md`.

## Cryptographic Practices

### `crypto_published`

Recommended status: Met

Recommended entry: KythOS does not define private cryptographic protocols.
Release signing and verification use public, reviewed mechanisms: Sigstore,
Cosign, GitHub OIDC/provenance, SHA-256 checksums, HTTPS, container registry
mechanisms, and Fedora RPM repository signing.

KythOS does not define private cryptographic protocols. Release signing uses
Sigstore/Cosign and GitHub OIDC. Release verification uses SHA-256 checksums,
Cosign bundles, GitHub build provenance attestations, HTTPS, and standard
container registry mechanisms. System package installation relies on Fedora RPM
repository signing and standard TLS-backed distribution channels.

### `crypto_call`

Recommended status: Met

Recommended entry: KythOS is not a cryptography library and does not implement
its own primitives. It delegates cryptographic operations to OpenSSL,
Cosign/Sigstore, GitHub attestation tooling, RPM/GPG verification, TLS-capable
download tools, bootc, skopeo, oras, and platform package managers.

KythOS is not a cryptography library and does not reimplement cryptographic
primitives. It calls standard tools and libraries such as `openssl`, Cosign,
GitHub attestation tooling, RPM/GPG verification, TLS-capable download tools,
and platform package managers.

### `crypto_floss`

Recommended status: Met

Recommended entry: KythOS cryptography-dependent functionality is implemented
with FLOSS tools, including OpenSSL, Cosign/Sigstore, GitHub attestation
verification, RPM/GPG verification, bootc, skopeo, oras, Syft, Grype, and
standard Fedora/Linux components.

The security mechanisms used by KythOS are implementable with FLOSS tools:
Cosign/Sigstore, GitHub attestation verification, OpenSSL, RPM/GPG verification,
bootc, skopeo, oras, Syft, Grype, and standard Linux/Fedora components.

### `crypto_keylength`

Recommended status: Met

Recommended entry: KythOS does not choose custom weak key lengths. It uses
standard upstream cryptographic tooling: Sigstore/Cosign for release signing,
OpenSSL SHA-512 crypt for local Linux account hashes during install, and
standard UEFI/MOK tooling for optional Secure Boot material.

KythOS uses standard upstream cryptographic tooling instead of custom key
selection. Release signing uses Sigstore/Cosign. Password hashing in the
installer uses OpenSSL SHA-512 crypt for local Linux account setup. Optional
Secure Boot material is handled through standard UEFI/MOK tooling and the
documented certificate/key path. KythOS does not intentionally enable weak
default key lengths.

### `crypto_working`

Recommended status: Met

Recommended entry: KythOS does not intentionally depend on broken algorithms
such as MD4, MD5, single DES, RC4, or Dual_EC_DRBG for project security
mechanisms. Legacy protocol support, where present in upstream tools, is not a
KythOS-defined default security mechanism.

KythOS does not intentionally depend on broken algorithms such as MD4, MD5,
single DES, RC4, or Dual_EC_DRBG for its own security mechanisms. When upstream
interoperability tools support legacy protocols, KythOS treats those as upstream
compatibility behavior, not project-defined defaults.

### `crypto_weaknesses`

Recommended status: Met

Recommended entry: KythOS release and update security does not depend on SHA-1
or legacy SSH/CBC-style mechanisms. It uses modern upstream release, TLS,
container registry, and signing tooling.

KythOS release and update mechanisms use modern upstream tooling and do not
depend on SHA-1 or legacy SSH/CBC-style mechanisms for project security. The
project should continue to treat any required upstream legacy compatibility as a
documented exception.

### `crypto_pfs`

Recommended status: N/A

Recommended entry: KythOS does not implement its own key-agreement network
protocol. Network security is delegated to upstream TLS, SSH, VPN, package
manager, and registry implementations.

KythOS does not implement its own key-agreement network protocol. Network
security is delegated to upstream TLS/SSH/VPN implementations and distribution
channels.

### `crypto_password_storage`

Recommended status: Met

Recommended entry: KythOS does not store passwords for external user
authentication. During install, the local Linux account password is converted to
an `/etc/shadow`-compatible salted SHA-512 crypt hash using OpenSSL. Migration
and diagnostic tools avoid exporting passwords, browser sessions, SMB
credentials, and OAuth tokens.

KythOS does not store passwords for external user authentication. During install,
the local Linux account password is converted to an `/etc/shadow`-compatible
SHA-512 crypt hash using OpenSSL before it is written into the target system.
System Hub and migration tools intentionally avoid including passwords, browser
sessions, SMB credentials, and OAuth tokens in exported setup transfer data.

### `crypto_random`

Recommended status: Met

Recommended entry: KythOS uses cryptographically appropriate upstream
mechanisms for security randomness. The installer local session token is created
with Python `secrets.token_urlsafe`; release signing and token generation are
delegated to standard platform tooling.

KythOS uses cryptographically appropriate upstream mechanisms where randomness
is required. The installer generates its local session token with Python's
`secrets.token_urlsafe`, and release signing/token mechanisms are delegated to
standard platform tooling. The project does not use insecure random generators
for cryptographic keys or nonces.

## Delivery Against MITM

### `delivery_mitm`

Recommended status: Met

Recommended entry: Project source, issue tracking, releases, package registry,
direct ISO downloads, and documented verification paths use HTTPS. Release
artifacts also include SHA-256 checksums, Cosign signatures/bundles, and GitHub
provenance attestations.

Project source, issue tracking, release pages, package registry access, direct
ISO downloads, and documented verification paths use HTTPS. Release artifacts
also have SHA-256 checksums, Cosign signatures/bundles, and GitHub provenance
attestations.

### `delivery_unsigned`

Recommended status: Met

Recommended entry: KythOS does not retrieve cryptographic hashes over plain HTTP
and trust them without signatures. Release verification is documented over HTTPS
and combines checksums with Cosign signature bundles and GitHub build
provenance.

KythOS does not retrieve cryptographic hashes over plain HTTP and trust them
without signatures. Release verification is documented over HTTPS and combines
checksums with Cosign signature bundles and GitHub build provenance.

## Publicly Known Vulnerabilities

### `vulnerabilities_fixed_60_days`

Recommended status: Met

Recommended entry: KythOS uses Grype CVE scans for published image SBOMs,
CodeQL for Python, private vulnerability reporting, and a documented response
process. There are no known unpatched medium-or-higher KythOS vulnerabilities
older than 60 days at the time this entry is being updated.

The project has Grype CVE scanning for published image SBOMs, CodeQL for Python,
private vulnerability reporting, and a documented response process. There are no
known unpatched medium-or-higher KythOS vulnerabilities older than 60 days at
the time this document was added.

### `vulnerabilities_critical_fixed`

Recommended status: Met

Recommended entry: `SECURITY.md` documents triage and advisory publication.
Critical KythOS-specific vulnerabilities are prioritized for rapid fix or
mitigation in the stable channel.

`SECURITY.md` documents triage and advisory publication. Critical
KythOS-specific vulnerabilities should be fixed or mitigated rapidly, with
stable-channel updates prioritized.

## Other Security Issues

### `no_leaked_credentials`

Recommended status: Met

Recommended entry: The repository should not contain valid private credentials.
CI secrets are stored in GitHub secrets, and validation checks tracked files for
high-confidence secret patterns. The tracked Secure Boot `.cer` is public
certificate material, not a private key. Issue templates warn users not to
include secrets.

The public repository should not contain valid private credentials. CI uses
GitHub secrets for tokens, R2 credentials, and optional Secure Boot key material.
The tracked Secure Boot certificate is public certificate material, not a
private key. Issue templates and System Hub feedback warn users not to include
passwords, tokens, serial numbers, or private data in reports.
