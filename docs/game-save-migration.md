# KythOS Game Save Migration

Game saves are more important than game files. Steam, Heroic, Lutris, and cloud
saves all store data in different places, so KythOS treats save migration as a
separate step from copying a Steam library.

## Recommended Flow

1. On Windows, let each launcher finish cloud sync.
2. Back up saves with Ludusavi to an external drive or cloud-synced folder.
3. Install KythOS and launch each game once so its Linux/Proton prefix exists.
4. Restore saves with Ludusavi.
5. Launch the game and confirm the save appears before deleting old backups.

## KythOS Tools

- `ujust install-ludusavi` installs the Ludusavi Flatpak.
- System Hub -> Gaming -> Game Saves opens the same installer and launcher.
- System Hub -> Cloud Storage can sync a save-backup folder through rclone.

## Validation Notes

When validating a release, record whether the save path came from Steam Cloud,
Ludusavi restore, Heroic cloud sync, or manual copy. Some games store settings
and saves separately; do not mark a save migration successful until a loaded
save reaches gameplay.
