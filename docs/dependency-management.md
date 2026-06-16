# Dependency Management

KythOS is an OS image integration project. Most dependencies are operating
system packages, container base images, GitHub Actions, Python standard-library
code, and selected third-party release artifacts.

## Selection Principles

- Prefer Fedora, KDE, Universal Blue, bootc, Flatpak, and other maintained
  upstream packaging channels.
- Prefer signed package repositories and HTTPS distribution.
- Prefer standard system components over vendored code.
- Keep base-image additions justified by daily-driver value.
- Use Flatpak, Homebrew, distrobox, or user-installed tools when a package does
  not need to be in the immutable base image.

## Tracking

- GitHub Actions dependencies are tracked by Dependabot and Renovate.
- Container, package, and release metadata is recorded in build labels and
  release notes where practical.
- Image SBOMs are generated with Syft and attached to published images.
- Important RPM package changes are summarized in image release notes.

## Vulnerability Monitoring

- Grype scans published SBOMs daily and uploads SARIF to GitHub code scanning.
- CodeQL scans Python code.
- OpenSSF Scorecard monitors repository and supply-chain posture.
- Renovate vulnerability alerts are enabled, but automatic merging is disabled
  for security changes because OS image updates can create boot regressions.

## Updating

- Routine dependency updates should go through `testing` first.
- Security updates should be triaged by severity, exploitability, upstream
  availability, and daily-driver regression risk.
- Base OS image and kernel updates should preserve install, update, rollback,
  Secure Boot, and live ISO behavior.
- Optional third-party tools should have a clear source, update cadence, and
  fallback path.

## Suppression and Non-Exploitability

If a scanner finding does not affect KythOS, the project should document why it
is not exploitable before suppressing it. For recurring non-exploitable findings,
prefer a VEX-style note or release/security note that identifies the package,
finding, affected channel, and rationale.

## Release Gate

Before a stable release, maintainers should confirm that:

- Validation workflows pass.
- The image has an attached SBOM.
- The current CVE scan has no known actionable critical or high-severity issue
  without a documented mitigation or upstream limitation.
- Release notes identify security-relevant fixes when they are known.
