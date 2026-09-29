# Importing the existing game and daily workflow (Windows)

This repository was imported from a downloaded copy of the existing "Skip a Pebble!"
Studio place on 2026-09-28. Keep the original place authoritative. The default Rojo
project is intentionally narrow because a full-service mapping proposed thousands of
files and GUI replacements during the initial safety check.

## What gets imported (and what doesn't)

Live synced by `default.project.json`:

- `ReplicatedStorage.Modules`, `ReplicatedStorage.Shared`, `ReplicatedStorage.SharedUI`
- `ServerScriptService`
- `StarterPlayer.StarterPlayerScripts`, `StarterPlayer.StarterCharacterScripts`

These contain 186 scripts in the verified import. The other 104 scripts are preserved
as read-only source snapshots under `studio-only/`: 46 in StarterGui, 36 in
ServerStorage, and 22 in Workspace. GUI instances are also saved under
`studio-only/StarterGuiAssets`. `gui-snapshot.project.json` exists only to
refresh that GUI archive with `rojo syncback`; never serve it into the live game.
The downloaded `.rbxl` backup remains the full copy of maps, models, properties,
assets, Lighting, Teams, and all other content. Git source is not a replacement
for that place file.

Mapped nodes use `$ignoreUnknownInstances: true`. Still review every proposed
Rojo change before accepting it, especially after a mapping or import change.

## One-time setup

Git, Rokit, Rojo 7.7.0, and the Rojo Studio plugin were already installed on the
Windows PC during import. The Claude Desktop Roblox Studio MCP configuration was
left intact. Use the existing local clone at
`C:\Users\arush\Documents\ChatGPT\Skip a pebble-rojo`.

## Import the existing game

1. In the original Studio window, choose *File → Download a Copy* and save a new
   dated `.rbxl` under `C:\Users\arush\Documents\RobloxBackups`. Keep it untouched.
   Copy that file to a separate import/test filename. Never import from the only copy.
2. Preview what will be written (writes nothing):
   ```powershell
   .\scripts\import-from-studio.ps1 -Place "C:\RobloxBackups\MyGame-import.rbxl" -DryRun
   ```
   The script reads the place copy and writes only repository files.
3. Run the import:
   ```powershell
   .\scripts\import-from-studio.ps1 -Place "C:\RobloxBackups\MyGame-import.rbxl"
   ```
4. Review, then commit and push:
   ```powershell
   git status
   git add -A
   git commit -m "Import existing game scripts from Roblox Studio"
   git push
   ```
   The live mapped scripts are under `src/`. Studio-only scripts are under
   `studio-only/`; changes there require a separate Studio/MCP update.

## Verify the sync is safe (do this on a copy first)

1. In Studio, open the separate import/test `.rbxl` file.
2. In the repo folder: `rojo serve default.project.json`
3. In Studio: *Plugins → Rojo → Connect*. Rojo shows the changes it wants to make **before**
   applying them. The 2026-09-28 copy test proposed six `Source` updates and zero
   instance additions/deletions. All six source strings matched before the preview;
   Rojo changed line endings on acceptance. If a future preview proposes deleting,
   moving, or replacing substantial game content, click **Abort** and fix the mapping.
4. Play-test the copy. Connect the original only when the latest downloaded copy
   still matches the original and no one else is editing it. The original was
   deliberately left disconnected during this setup because it changed during import.

## Day-to-day loop

1. Make a focused change in Claude Code Cloud and push it to GitHub.
2. On the PC, fetch/pull that branch into this local clone. Review `git diff`
   before starting Rojo.
3. Download a fresh Studio copy and test the branch with Rojo on that copy first.
4. When the preview and play-test pass, connect the original Studio place, test
   there, and publish from Studio as usual.

**Important:** once Rojo is connected, `src/` is the source of truth for the synced services.
If you (or Claude Desktop through Roblox MCP) edit a mapped script directly in
Studio, stop the Rojo server first. Download a fresh copy, preview the import,
then run it and review the diff before the next Rojo sync:

```powershell
git status
.\scripts\import-from-studio.ps1 -Place "C:\Users\arush\Documents\RobloxBackups\MyGame-latest-copy.rbxl" -DryRun
.\scripts\import-from-studio.ps1 -Place "C:\Users\arush\Documents\RobloxBackups\MyGame-latest-copy.rbxl"
git diff
git add -A
git commit -m "Sync Studio edits"
git push
```

Claude Desktop + Roblox MCP can continue to edit the open Studio place. For
Workspace, StarterGui, and ServerStorage, use Studio/MCP and refresh the snapshots
separately; the default Rojo session does not synchronize those areas.
