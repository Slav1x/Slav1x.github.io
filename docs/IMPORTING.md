# Importing the existing game & daily workflow (Windows)

This repo is set up with Rojo 7.7 so the **existing** Roblox Studio game can be pulled into Git
without changing the game itself. The import works from a *saved copy* of the place file, so
Studio and the published game are never touched during it.

## What gets imported (and what doesn't)

Synced into `src/` (see `default.project.json`):

- `ReplicatedFirst`, `ReplicatedStorage`, `ServerScriptService`, `ServerStorage`,
  `StarterGui`, `StarterPack`, `StarterPlayer.StarterPlayerScripts`,
  `StarterPlayer.StarterCharacterScripts`

Not synced (stays only in the place file / Studio):

- `Workspace` (maps, parts, **and any scripts inside parts/models in Workspace**), `Lighting`,
  `SoundService`, `Teams`, `Chat`/`TextChatService`, etc.

Every service is marked `$ignoreUnknownInstances: true`, so when Rojo syncs into Studio it will
**add or update** things from `src/` but will **not delete** anything that only exists in Studio.

How things are written to disk:

- Scripts → `.luau` files (`.server.luau` = Script, `.client.luau` = LocalScript, plain = ModuleScript)
- Folders → folders
- RemoteEvents/RemoteFunctions/Values → `.model.json`
- GUIs, Models, Tools' parts, etc. → `.rbxmx` (XML text). Scripts nested inside a GUI or model
  live *inside* that `.rbxmx` file.

## One-time setup

1. **Back up the game.**
   - In Studio: *File → Save to File As…* → e.g. `C:\RobloxBackups\MyGame-original.rbxl`.
     Keep this file untouched forever.
   - Your published place also keeps version history on Roblox (Creator Dashboard →
     the place → *Version History*).
2. **Install Git for Windows**: https://git-scm.com/download/win (defaults are fine).
3. **Install Rokit** (tool manager): download the latest `rokit-…-windows-x86_64.zip` from
   https://github.com/rojo-rbx/rokit/releases, extract it, and run in a terminal:
   ```powershell
   .\rokit.exe self-install
   ```
   Close and reopen the terminal.
4. **Clone this repo and install the pinned tools**:
   ```powershell
   cd C:\Dev
   git clone https://github.com/Slav1x/Slav1x.github.io.git
   cd Slav1x.github.io
   rokit install          # installs rojo, selene, stylua from rokit.toml (answer "yes" to trust)
   rojo --version         # should print Rojo 7.7.0
   rojo plugin install    # installs the matching Rojo plugin into Roblox Studio
   ```
5. (Optional) Install VS Code + the **Luau Language Server** extension for editing locally.

## Import the existing game

1. In Studio, open the game and *File → Save to File As…* → `C:\RobloxBackups\MyGame-import.rbxl`.
   (A separate copy just for importing.)
2. Preview what will be written (writes nothing):
   ```powershell
   .\scripts\import-from-studio.ps1 -Place "C:\RobloxBackups\MyGame-import.rbxl" -DryRun
   ```
   If PowerShell blocks the script, run once:
   `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
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
   Check the import on GitHub: every script you expect should be under `src/`.

## Verify the sync is safe (do this on a copy first)

1. In Studio, open the **file** `C:\RobloxBackups\MyGame-import.rbxl` (not the published game).
2. In the repo folder: `rojo serve`
3. In Studio: *Plugins → Rojo → Connect*. Rojo shows the changes it wants to make **before**
   applying them. Right after an import this should be empty or nearly empty
   (small property/format differences are normal). If it wants to delete or replace large
   parts of the game, click **Abort** and stop there.
4. Play-test. If everything works, you can connect Rojo to the real game the same way.

## Day-to-day loop

1. Make changes (Claude Code cloud session, or locally) and push to a branch on GitHub.
2. On your PC: `git pull` (or `git checkout <branch>`), then `rojo serve`, connect in Studio.
3. Play-test in Studio, then publish from Studio as usual.

**Important:** once Rojo is connected, `src/` is the source of truth for the synced services.
If you (or Claude Desktop via the Studio MCP) edit a synced script directly in Studio, bring it
back into the repo before the next sync or it will be overwritten. The easy way:

```powershell
git pull                      # latest repo state, and let Rojo sync it into Studio first,
                              # otherwise the import would revert repo changes Studio hasn't received
# Studio: File → Save to File As… C:\RobloxBackups\MyGame-latest.rbxl
.\scripts\import-from-studio.ps1 -Place "C:\RobloxBackups\MyGame-latest.rbxl"
git diff                      # review what changed
git add -A; git commit -m "Sync Studio edits"; git push
```

Things that aren't synced (Workspace, Lighting, …) are still edited in Studio as usual and are
saved by publishing the place, not by Git.
