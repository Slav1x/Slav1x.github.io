# CLAUDE.md

## What this repository is

This is the source-controlled code for an **existing, already-developed Roblox game**.
The game was originally built in Roblox Studio (partly with Claude Desktop + a Roblox Studio MCP)
and is being brought into Git so it can be developed in Claude Code cloud sessions and then
synced into Studio with [Rojo](https://rojo.space) for testing.

**This is not a new or template project.** Anything under `src/` came from the live game and
is part of its working systems.

## Rules for working in this repo

1. **Preserve existing systems.** Do not delete, rename, move, rewrite, or "clean up" existing
   scripts, modules, RemoteEvents/RemoteFunctions, folders, or instances unless the user
   explicitly asks for that exact change.
2. **Do not invent game systems.** Don't scaffold new frameworks, services, data stores, or
   architecture the user didn't ask for. If a request is ambiguous, ask first.
3. **Make minimal, targeted changes.** Edit only what the task needs. Don't reformat or
   mass-restyle existing files (don't run StyLua over the whole tree) — it makes diffs
   unreviewable and risks breaking things.
4. **Keep names and paths stable.** Other scripts reference instances by name and path
   (`ReplicatedStorage.Remotes.X`, `script.Parent.Y`, `require(...)`). Renaming a file or
   folder renames the instance in Studio and can silently break those references.
5. **Respect DataStores.** Never change DataStore names, keys, or saved-data shape without an
   explicit request and a migration plan — that can wipe or corrupt player data.
6. **Only part of the game is live synced.** `default.project.json` deliberately maps 186
   current scripts in ReplicatedStorage, ServerScriptService, and StarterPlayer. The other
   104 current scripts are read-only snapshots under `studio-only/`. GUI layouts, Workspace
   models, ServerStorage backups, Lighting, SoundService, and Teams stay in the Studio
   place file. Code may reference instances absent from the Rojo tree; do not create
   replacements based on those references.
7. **You cannot run Roblox Studio here.** Changes can't be play-tested in the cloud. Say what
   the user should test in Studio after syncing, and don't claim something works in-game.
8. **Rebirths and the Golden Meridian.** Normal rebirths stop at `ProgressionConfig.NormalRebirths`,
   which is derived from the ten meridians in `AwakeningConfig.Nodes`; keep the two in step.
   Golden Meridian progress is saved in `profile.goldenPath` (shape owned by
   `GoldenMeridianState`) and granted only by `GoldenMeridianService`. Treat it like DataStore
   data (rule 5). Install and test notes: `docs/GOLDEN_MERIDIAN.md`.

## How files map to Roblox (Rojo 7)

Project file: `default.project.json`. Mapped nodes set `"$ignoreUnknownInstances": true`.
Always inspect Rojo's proposed changes on a copy before connecting a live place.

| Folder in repo                            | Roblox location                          |
| ----------------------------------------- | ---------------------------------------- |
| `src/ReplicatedStorage/Modules`           | `ReplicatedStorage.Modules`              |
| `src/ReplicatedStorage/Shared`            | `ReplicatedStorage.Shared`               |
| `src/ReplicatedStorage/SharedUI`          | `ReplicatedStorage.SharedUI`             |
| `src/ServerScriptService`                 | `ServerScriptService`                    |
| `src/StarterPlayer/StarterPlayerScripts`  | `StarterPlayer.StarterPlayerScripts`     |
| `src/StarterPlayer/StarterCharacterScripts` | `StarterPlayer.StarterCharacterScripts` |

`studio-only/Workspace`, `studio-only/snapshots`,
`studio-only/ServerStorageScripts`, and `studio-only/StarterGuiAssets` are review
snapshots and are **not** part of the live Rojo project. Changes there need a separately
reviewed Studio/MCP import; editing those files alone will not change the game.

File naming (Rojo conventions):

- `Name.server.luau` → `Script` · `Name.client.luau` → `LocalScript` · `Name.luau` → `ModuleScript`
  (`.lua` is also accepted — keep whichever extension the existing file already uses)
- A folder containing `init.luau` / `init.server.luau` / `init.client.luau` becomes that script,
  with the folder's other contents as its children.
- `*.model.json`, `*.rbxm`, `*.rbxmx` → non-script instances (GUIs, models, values, remotes).
- `*.meta.json` / `init.meta.json` → properties for the matching instance (e.g. `Disabled`,
  `RunContext`, attributes).
- `.gitkeep` files are only there so empty folders exist in Git; Rojo ignores them.

## Tooling

Pinned in `rokit.toml` (install with `rokit install`): **rojo**, **selene** (linter,
`selene.toml`), **stylua** (formatter, `stylua.toml`). Useful checks:

```sh
rojo build default.project.json -o build/test.rbxl   # verifies the project/tree is valid
selene src                                            # lint (report issues; don't mass-fix)
stylua --check <changed files>                        # only on files you touched
```

These tools may not be installed in a cloud session; if they aren't, skip them and say so.

## Workflow

1. Code changes are made on a branch here (cloud or local) and pushed to GitHub.
2. On the Windows PC: `git pull`, `rojo serve`, connect the Rojo plugin in Studio, play-test.
3. If the user or Claude Desktop edits a mapped script directly in Studio, stop Rojo,
   download a fresh copy, and re-run `rojo syncback` from that copy before the next sync.
   Review the diff and proposed Studio changes. See `docs/IMPORTING.md`.

See `docs/IMPORTING.md` for the one-time import of the existing game and the day-to-day loop.
