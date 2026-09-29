# Slav1x.github.io — Roblox game (Rojo project)

Source-controlled code for an existing Roblox game, synced into Roblox Studio with
[Rojo](https://rojo.space) 7.7.

- `default.project.json` — Rojo project: maps `src/` folders onto Roblox services.
  Studio-only instances are never deleted by a sync (`$ignoreUnknownInstances`).
- `src/` — game code/instances, one folder per Roblox service.
- `rokit.toml` — pinned tools (rojo, selene, stylua). Run `rokit install`.
- `scripts/import-from-studio.ps1` — pulls scripts from a saved `.rbxl` into `src/`.
- `docs/IMPORTING.md` — **start here**: one-time import of the existing game and the daily workflow.
- `CLAUDE.md` — rules for Claude Code when working in this repo.

Quick start (after the import is done):

```powershell
rokit install
rojo serve      # then Plugins → Rojo → Connect in Studio
```
