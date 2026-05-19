# KythOS Gaming Results

This directory stores release validation results. The matrix in
`docs/gaming-validation-matrix.md` defines what to test; files here record what
actually happened on a specific image.

## Filename

Use:

```text
YYYY-MM-DD-image-tag-hardware.md
```

Example:

```text
2026-05-18-latest-radeon-7800xt.md
```

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

## Pass Rules

- A game is not "validated" until it reaches gameplay, not just the launcher.
- Online games must reach a multiplayer-safe screen or matchmaking path.
- Anti-cheat status must include a check date and source.
- Save migration tests must load an existing save.
- Modding tests must load with the selected mod enabled.
