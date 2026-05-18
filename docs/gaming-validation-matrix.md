# KythOS Gaming Validation Matrix

This matrix keeps the project honest: KythOS should feel fast, predictable, and recoverable for Windows gamers moving to Linux. Test results should note the image tag, kernel, Mesa or NVIDIA driver version, Proton runner, launch options, desktop session, and whether an OS update was staged.

## Health Gates

Before recording a game result, the System Hub gaming health check should be mostly green:

- Steam installed and launches
- GE-Proton installed
- Vulkan device detected
- `/dev/ntsync` present or documented fallback noted
- `umu-run` available for launcher flows
- Gamescope and MangoHud installed
- No staged OS update before benchmark runs
- Controller detected when testing controller-heavy games
- Windows Steam library copied to a Linux filesystem before performance testing
- Save backup/restore path verified for migration-sensitive games
- Mod manager path documented when testing heavily modded titles
- Compatibility source checked date recorded for anti-cheat-sensitive games

## Runner Policy

Use this order unless a game-specific ProtonDB report suggests otherwise:

1. Valve Proton Experimental
2. GE-Proton latest
3. Proton-CachyOS SLR
4. Per-game workaround launch options

GE-Proton remains the default recommendation. Proton-CachyOS SLR is an optional fallback runner for games with launcher, anti-cheat, or bleeding-edge compatibility issues.

## Smoke Test Games

| Game | Why It Matters | Expected Path | Pass Criteria |
| --- | --- | --- | --- |
| Counter-Strike 2 | Native Linux, VAC, high-FPS input feel | Native | Launches, matchmaking works, controller/mouse input stable |
| Cyberpunk 2077 | Heavy VKD3D/DX12 workload, HDR/FSR testing | Proton/GE-Proton | Launches, loads save, MangoHud visible, no obvious frame pacing issue |
| Elden Ring | Popular Proton title with online checks | Proton/GE-Proton | Launches online, controller works, no Easy Anti-Cheat failure |
| Baldur's Gate 3 | Large modern title, native vs Proton comparison | Native and Proton | Both paths documented; preferred path marked |
| Red Dead Redemption 2 | Third-party launcher stress test | GE-Proton or Proton-CachyOS SLR | Rockstar Launcher signs in and game reaches menu |
| Overwatch 2 | Battle.net and competitive online flow | Lutris/Heroic via umu | Battle.net signs in and game reaches practice range |
| Warframe | Online game that sometimes needs runner changes | GE-Proton or Proton-CachyOS SLR | Launcher updates and game reaches orbiter |
| Apex Legends | Anti-cheat status can change | Blocked unless publisher support returns | Launch result recorded with anti-cheat status date |
| Fortnite | Known blocked title | Blocked | User-facing explanation points to anti-cheat/vendor decision |
| Valorant | Known blocked title | Blocked | User-facing explanation points to Vanguard/kernel driver |

## Hardware Classes

Record at least one result per class before calling a release "gaming validated":

- AMD Radeon desktop GPU, high-refresh VRR monitor
- NVIDIA desktop GPU with proprietary driver active
- Intel Arc or recent Intel iGPU
- Hybrid laptop with AMD or Intel iGPU plus NVIDIA dGPU
- Xbox controller over USB
- Xbox wireless dongle
- DualSense over Bluetooth
- NTFS Windows Steam library migration to Btrfs/ext4

## Result Template

```text
Image:
Kernel:
GPU:
Driver/Mesa:
Session:
Game:
Store/Launcher:
Runner:
Launch options:
Filesystem:
Controller:
Save path:
Mods:
Result:
Compatibility source checked:
Notes:
```

Store completed results in [`docs/gaming-results/`](gaming-results/). Keep the
System Hub compatibility list conservative: publisher-blocked games stay blocked
until a current release result proves otherwise.
