# Linux and Proton Support Checklist for Game Developers

KythOS works best when Windows games avoid assumptions that only hold on a
mutable Windows install. This checklist is the short path to SteamOS, Steam Deck,
KythOS, Bazzite, and other Proton-based players.

## Compatibility

- Enable Proton support in Easy Anti-Cheat or BattlEye if your game uses it.
- Avoid kernel-only anti-cheat requirements for casual and non-ranked modes.
- Do not block Wine/Proton user agents unless there is a confirmed exploit.
- Keep launchers controller-friendly and avoid mandatory webviews that break in
  Proton.
- Support cloud saves without hardcoding Windows-only paths.

## Display and Input

- Support 1280x800, 1280x720, 1920x1080, and ultrawide modes.
- Keep UI text readable at 720p and 800p.
- Support Xbox, PlayStation, and Steam Input controller glyphs.
- Allow launch without a keyboard after first sign-in.

## Validation

- Test Proton Experimental and current GE-Proton.
- Test Gamescope with VRR, an FPS cap, and HDR when applicable.
- Test one AMD, one NVIDIA, and one Intel GPU path.
- Publish known launch options and anti-cheat limitations clearly.
