# Governance

KythOS uses a maintainer-led governance model. The project optimizes for a
small, reviewable daily-driver OS where changes can be validated on real
hardware before they reach the stable channel.

## Roles

### Maintainer

The maintainer owns release decisions, repository settings, CI/CD credentials,
security advisories, and the stable channel. The current maintainer is
`@mrtrick37`.

Responsibilities:

- Review and merge pull requests.
- Keep `main` and `testing` aligned with their documented purposes.
- Triage security reports and coordinate disclosure.
- Publish signed image and ISO releases.
- Maintain release, build, validation, and supply-chain workflows.

### Contributor

Contributors propose changes through pull requests against `testing`.

Responsibilities:

- Follow `CONTRIBUTING.md`.
- Explain user impact, testing, and rollback implications.
- Add or update tests for major behavior changes.
- Assert that they are allowed to contribute the work they submit.

### Security Reporter

Security reporters privately report suspected vulnerabilities through the GitHub
private vulnerability reporting flow described in `SECURITY.md`.

Responsibilities:

- Avoid public disclosure until the issue is triaged.
- Include enough detail for reproduction and impact analysis.
- Avoid testing against systems or accounts they do not control.

## Decision Making

Changes are accepted when they fit the project scope, pass validation, and do
not create unacceptable daily-driver, installation, update, or supply-chain
risk. The maintainer may reject changes that are useful in isolation but too
large, fragile, hard to maintain, or better delivered as Flatpaks, distrobox
recipes, or user-installed tools.

The stable channel (`main` / `latest`) is conservative. The testing channel
(`testing`) is where larger changes soak before promotion.

## Access Continuity

The project should be able to continue if the current maintainer is unavailable.
At minimum, continuity requires access to:

- The GitHub repository and package publishing controls.
- Release signing and attestation workflows.
- Cloudflare R2 release storage credentials.
- Any Secure Boot signing material used for optional kernel variants.

The maintainer is responsible for keeping an out-of-band recovery plan for these
assets. New maintainers should receive the least privilege needed for their
role, and elevated access should be reviewed before it is granted.

## Sensitive Resources

Sensitive resources include repository administration, GitHub environments,
private vulnerability reports, release publishing, package registry publishing,
R2 release storage, and signing material. Contributors do not need access to
these resources to submit code.

## Related Policy

- `CONTRIBUTING.md` describes contribution and review expectations.
- `SECURITY.md` describes vulnerability reporting and response.
- `docs/security-model.md` describes trust boundaries and security assumptions.
