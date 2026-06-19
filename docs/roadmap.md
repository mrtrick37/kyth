# Roadmap

This roadmap describes likely project direction for the next year. It is not a
promise that every item will ship. KythOS prioritizes a reliable daily-driver
desktop over feature volume.

## Current Focus

- Keep the stable channel installable, updateable, and rollback-friendly.
- Keep the live ISO boot path reliable on common AMD, Intel, and NVIDIA systems.
- Make System Hub the primary place for setup, repair, diagnostics, and guided
  daily-driver checks.
- Keep desktop polish coherent while developing the Plasma/Wayland
  customization path documented in
  [Plasma and UI Polish Direction](plasma-wayland-polish.md).
- Preserve signed, attestable, SBOM-backed releases for images and ISOs.

## Next 3 Months

- Expand automated parser and installer tests for System Hub and release helper
  code.
- Document security boundaries, governance, dependency management, and release
  support expectations.
- Tighten validation around shell formatting, Justfile formatting, and release
  metadata consistency.
- Improve post-update and smoke-check diagnostics for common desktop regressions.
- Move repeated System Hub page styling into shared QSS object names so status
  badges, warnings, section heads, keycaps, and action rows look consistent.

## 3-6 Months

- Add more real-hardware validation notes for GPU, controller, suspend/resume,
  audio, Bluetooth, and installer paths.
- Improve recovery guidance for failed installs, failed rebases, and broken
  graphical sessions.
- Continue reducing first-login prompts and fragile manual setup steps.
- Expand the Everyday/Gaming role preset system with creator, developer,
  laptop, and docked workflow presets.
- Add more automated tests around privileged helper command generation.

## 6-12 Months

- Improve release reproducibility documentation and identify any remaining
  sources of non-determinism.
- Strengthen security assessment artifacts, including threat modeling and
  assurance-case updates.
- Evaluate whether optional kernel variants can be maintained with the same
  support expectations as the default Fedora kernel path.
- Expand contributor-friendly tasks once the maintenance surface is clearer.

## Non-Goals

- KythOS will not try to be a general-purpose distribution for every workflow.
- KythOS will not promise Windows-only anti-cheat compatibility.
- KythOS will not carry every useful application in the base image when Flatpak,
  Homebrew, distrobox, or user install paths are better.
- KythOS will not trade update safety and rollback clarity for novelty.
