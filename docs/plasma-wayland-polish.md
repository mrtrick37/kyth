# Plasma and UI Polish Direction

This note tracks the KythOS desktop polish lane: keep the current interface
coherent first, then use Plasma and Wayland customizations to make the desktop
feel distinct and easier for Windows users to trust.

## Current Baseline

- KythOS branding is present across boot splash, os-release, SDDM background,
  Kickoff icon, wallpaper, app menu defaults, and System Hub.
- New users get KythDark, Papirus-Dark, Inter, Cascadia Code, KythOS wallpaper,
  Windows-style right-side window controls, double-click open, Meta+E,
  Meta+Shift+S, Meta+V clipboard history, and a quieter Discover notifier.
- Fresh users get the Windows Familiar layout preset: a bottom taskbar, KythOS
  launcher, pinned System Hub/App Store/Steam/Brave/Dolphin/Konsole apps,
  system tray, clock, show-desktop target, and KythOS wallpaper.
- Existing users receive versioned comfort migrations through
  `kyth-user-polish`.
- System Hub uses Windows-familiar wording and search aliases for tasks like
  Device Manager, Windows Update, Add or remove programs, Map network drive,
  Snipping Tool, PowerToys, and Xbox Game Bar.

## Consistency Rules

- Keep desktop defaults and the System Hub polish button on the same helper path.
  `kyth-user-polish --force` is the explicit "put the KythOS look back" action.
- Keep shell layout changes behind `kyth-apply-desktop-layout`; use `--initial`
  only for fresh accounts and `--force` only for explicit restore actions.
- Use `/etc/skel` for new-account defaults and versioned user polish for
  migration or repair.
- Avoid automatic visual overrides after every update unless the user has no
  existing theme state. Respect customization by default; make re-apply explicit.
- Prefer one shared visual vocabulary: KythDark shell, KythOS wallpaper and
  icons, compact dark surfaces, high-contrast status colors, Windows-familiar
  interaction patterns.
- Treat System Hub as the control surface for tuning rather than scattering
  advanced toggles across undocumented scripts.

## Gaps To Polish Next

- Several System Hub pages still use inline `setStyleSheet(...)` colors and
  typography. Move repeated badges, section heads, keycaps, warnings, and
  status pills into shared QSS object names.
- The project documents a Wayland-first direction while the current SDDM default
  intentionally starts Plasma X11 for broad VM and hardware stability. Keep the
  product language clear until the Wayland default is ready.
- The current Kyth plasma theme only overrides the panel background. Expand it
  carefully with a small number of distinctive, maintainable assets instead of
  forking Breeze wholesale.
- Role-specific shell presets are described in System Hub but not implemented
  yet beyond the Windows Familiar baseline.

## Plasma/Wayland Customization Path

1. Make the current shell feel finished: consistent panel, wallpaper, icons,
   window controls, Dolphin defaults, clipboard, shortcuts, app menu grouping,
   and desktop repair.
2. Iterate on the Windows Familiar layout preset: panel sizing, tray spacing,
   task manager behavior, multi-monitor behavior, and restore diagnostics.
3. Add opt-in role presets in System Hub:
   Console Mode, Creator Mode, Developer Mode, Laptop Mode, and Docked Mode.
4. Harden Wayland readiness:
   portals, PipeWire capture, VRR policy, fractional scaling notes, NVIDIA
   status, remote desktop/screen sharing repair, and per-app workaround buttons.
5. Flip the default to Wayland only after live ISO, VM, NVIDIA, hybrid laptop,
   screen sharing, and rollback tests stop producing avoidable first-login
   failures.

The north star: a Windows user should recognize the workflow, then notice that
KythOS is calmer, more recoverable, and less noisy.
