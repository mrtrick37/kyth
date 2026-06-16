## What does this change?

<!-- One or two sentences. What problem does it solve or what does it add? -->

## How was it tested?

<!-- How did you verify the change works? e.g. local build, booted ISO, checked a game, ran just lint -->

## Checklist

- [ ] `just lint` passes (shellcheck + shfmt)
- [ ] `python3 -m unittest discover -s tests` passes
- [ ] Changes to build scripts tested with `just build` or `just build-live-iso`
- [ ] Major behavior changes include automated tests or a documented rationale
- [ ] New packages or COPRs justified in the PR description
- [ ] Breaking changes to the installer or upgrade path noted above
