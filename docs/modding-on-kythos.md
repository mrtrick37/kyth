# Modding on KythOS

KythOS should make the common modding paths discoverable without pretending
every Windows mod manager is native Linux software.

## Default Recommendations

- Steam Workshop: use it first when a game supports it.
- Native game mod managers: use the game's own tool when available.
- Minecraft: use Prism Launcher.
- Standalone patchers or `.exe` tools: use Bottles.
- Bethesda-style load orders: use SteamTinkerLaunch to install Mod Organizer 2
  for the specific Steam game.
- Nexus/Vortex workflows: prefer Mod Organizer 2 where possible; Vortex can work
  through Wine/Bottles for some games, but it should be treated as advanced.

## KythOS Tools

- `ujust install-bottles`
- `ujust install-prismlauncher`
- ProtonUp-Qt for SteamTinkerLaunch and extra compatibility tools
- Ludusavi before and after large modding changes

## Release Validation Targets

Record at least one result for:

- Skyrim Special Edition with Mod Organizer 2
- Fallout 4 with Mod Organizer 2
- Cyberpunk 2077 with a simple REDmod or manual mod
- Stardew Valley with SMAPI
- Baldur's Gate 3 with a common mod manager path

Each result should include game version, runner, mod manager version, install
location, and whether saves still load after enabling mods.
