# KythOS Daily-Driver Validation

This checklist is the "make it feel inevitable" gate. A release should not feel
ready just because it boots once. It should survive the normal, boring things a
Windows gamer expects from a daily machine: updates, sleep, Bluetooth, Wi-Fi,
launchers, files, displays, audio, and rollback.

## Smoke Check

Run this after install, after an OS update, and before publishing a release:

```bash
ujust smoke-check
```

For release gating, use strict mode so warnings count:

```bash
ujust smoke-check --strict --verbose
```

Store notable output in the release notes or the matching hardware result. The
check is read-only: it does not install apps, change drivers, run updates, or
mount Windows drives.

## Release Gates

A release candidate should pass these before being called daily-driver ready:

- Fresh install reaches the desktop without manual terminal work.
- `ujust smoke-check --strict` has no failures on at least one AMD or Intel
  system.
- NVIDIA hardware either loads the proprietary module or gives a clear
  reboot/build path.
- `ujust kyth-upgrade` stages an update and rebooting activates it.
- The previous deployment remains visible from the boot menu after update.
- Steam installs or launches, Proton runners are available, and one known-good
  game reaches gameplay.
- Bluetooth pairs a controller or headset, then survives logout/login.
- Wi-Fi reconnects after suspend/resume.
- Audio output and microphone are selectable in KDE settings and work in
  Discord or OBS.
- Dolphin shows expected user folders and removable or mounted drives.
- A dirty or hibernated NTFS drive is detected and treated as a migration
  warning, not a normal writable game library.
- Discover manages Flatpaks without presenting phantom RPM system updates.
- Repair and support paths are visible: System Hub Repair opens, and
  `ujust device-info` produces a paste-friendly report.

## Hardware Coverage

Record at least one pass or known issue for each class:

| Class | What To Prove |
| --- | --- |
| AMD desktop GPU | Vulkan, VRR/high refresh, sleep/wake, MangoHud |
| NVIDIA desktop GPU | akmod build, reboot activation, Vulkan, sleep/wake |
| Intel laptop/iGPU | Wi-Fi, Bluetooth, suspend, fractional scaling if needed |
| Hybrid laptop | iGPU desktop, dGPU game path, external display behavior |
| Xbox controller | USB and Bluetooth or wireless adapter path |
| DualSense | USB, Bluetooth pairing, Steam Input |
| NTFS Windows drive | clean drive migration and dirty-drive warning |
| Printer or scanner | LAN discovery through KDE/CUPS where available |

## Rough-Edge Drills

Do these intentionally. Evangelists are made when recovery works.

1. Stage an update, reboot, confirm the new deployment is active, then boot the
   previous deployment from the boot menu.
2. Disable networking before first login and confirm first-boot services fail
   softly instead of blocking the desktop.
3. Interrupt or fail a Flatpak metadata refresh, then confirm System Hub and
   `ujust smoke-check` explain the missing app state.
4. On NVIDIA hardware, remove `/var/lib/kyth/hw-setup-done`, reboot, and confirm
   the setup path retries instead of silently giving up.
5. Connect a hibernated Windows volume and confirm migration tools warn the user
   to fully shut down Windows.
6. Fill memory pressure with a browser plus a game load screen and confirm the
   desktop survives without killing session-critical services.
7. Suspend and resume with Bluetooth audio or controller connected, then launch
   a game.

## Result Template

```text
Image tag:
Kernel:
Session:
Hardware:
GPU driver/Mesa:
Fresh install or update:
Smoke check:
Steam/game result:
Bluetooth:
Wi-Fi/suspend:
Audio/mic:
Migration path:
Rollback tested:
Rough edges:
Verdict:
```

Use this alongside the gaming matrix. The gaming matrix proves games work; this
document proves the computer around the games is calm enough to live in.
