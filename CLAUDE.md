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
6. **Not everything is in this repo.** Only the services listed below are synced. Workspace
   (maps/parts), Lighting, SoundService, Teams, etc. live only in the Studio place file.
   Code may reference instances that don't exist here; that is expected — don't "fix" it by
   creating them.
7. **You cannot run Roblox Studio here.** Changes can't be play-tested in the cloud. Say what
   the user should test in Studio after syncing, and don't claim something works in-game.

## How files map to Roblox (Rojo 7)

Project file: `default.project.json`. Every service node sets `"$ignoreUnknownInstances": true`,
so Rojo **adds/updates** instances that exist in `src/` but **never deletes** instances that
exist only in Studio.

| Folder in repo                            | Roblox location                          |
| ----------------------------------------- | ---------------------------------------- |
| `src/ReplicatedFirst`                     | `ReplicatedFirst`                        |
| `src/ReplicatedStorage`                   | `ReplicatedStorage`                      |
| `src/ServerScriptService`                 | `ServerScriptService`                    |
| `src/ServerStorage`                       | `ServerStorage`                          |
| `src/StarterGui`                          | `StarterGui`                             |
| `src/StarterPack`                         | `StarterPack`                            |
| `src/StarterPlayer/StarterPlayerScripts`  | `StarterPlayer.StarterPlayerScripts`     |
| `src/StarterPlayer/StarterCharacterScripts` | `StarterPlayer.StarterCharacterScripts` |

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
3. If the user edits a script directly in Studio, that change must be brought back into
   `src/` (edit the file, or re-run `rojo syncback`) or the next Rojo sync will overwrite it.

See `docs/IMPORTING.md` for the one-time import of the existing game and the day-to-day loop.
