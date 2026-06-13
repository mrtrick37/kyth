# Contributing to KythOS

Thanks for your interest. KythOS is a personal daily-driver OS — contributions
are welcome but the bar is practical: changes need to work on real hardware and
not break the live ISO boot path.

## Branches

| Branch | Purpose |
|---|---|
| `main` | Stable channel — maps to `:latest` image and `iso-latest` |
| `testing` | Development — maps to `:testing` image and `iso-testing` |

Open PRs against `testing`. After validation on real hardware, tested changes
merge to `main`.

## Local Build

You need Docker (or Podman) and [just](https://github.com/casey/just).

```bash
# Build both the base layer and the final OS image
just build

# Build and boot the live ISO in QEMU (requires SPICE client)
just rebuild-live-iso
just run-live-iso-native

# Lint and format shell scripts before pushing
just lint
just format
```

Feature flags let you skip optional build steps:

```bash
ENABLE_ANANICY=0 ENABLE_SCX=0 just build
```

## What Makes a Good PR

- **Packages**: justify why it belongs in a base OS image, not a Flatpak
- **COPRs**: link to the COPR, explain the update cadence, note if it's a
  known-stable maintainer (e.g. `xxmitsu/mesa-git`)
- **Scripts in `build_files/scripts/`**: must pass `shellcheck --severity=error`
  and `shfmt -d` (run `just lint && just format` locally)
- **Python**: must pass `python3 -c "import ast; ast.parse(open('file.py').read())"`
  — syntax only, but CodeQL runs on every PR for security issues
- **Dockerfiles**: must pass `hadolint --failure-threshold error`
- **Breaking changes to the installer or upgrade path**: describe the impact in
  the PR body; include a note if users need to reinstall vs. `bootc upgrade`

## CI Checks

All PRs run:

- **Validation** — actionlint, hadolint, shellcheck, Python AST, TOML/JSON,
  systemd unit verify, Justfile parse
- **Lint** — shellcheck on changed `.sh` files
- **CodeQL** — static analysis of Python code

The build and supply-chain workflows run on merge to `main`/`testing`, not on PRs,
to avoid burning CI minutes on draft work.

## Reporting Bugs

Use the issue templates — they ask for the right information up front. For
security issues, see [SECURITY.md](SECURITY.md).
