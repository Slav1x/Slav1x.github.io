# Rebirths 1–10 and the Golden Meridian: install guide

This adds the 10-meridian rebirth cutscene, the rebirth-10 finale, the Golden Rock, the
Spirit Realm, the Pebble God, the Divine Skip Trial, the Golden Meridian and the
"To Be Continued" ending. Your live game is newer than this repo, so **copy only the files
listed here**, and for the three existing core files make the small edits by hand instead
of replacing them.

**Back up first:** in Studio, use *File → Save to File As…*.

## 1. New files (create them)

| Studio location | Type | File in this repo |
| --- | --- | --- |
| ReplicatedStorage › Shared | ModuleScript `GoldenMeridianConfig` | `src/ReplicatedStorage/Shared/GoldenMeridianConfig.luau` |
| ServerScriptService | **Script** `GoldenMeridian` (next to `Server`) | `src/ServerScriptService/GoldenMeridian.server.luau` |
| ServerScriptService › Server (inside the `Server` script) | ModuleScript `GoldenMeridianService` | `src/ServerScriptService/Server/GoldenMeridianService.luau` |
| ServerScriptService › Server | ModuleScript `GoldenMeridianState` | `src/ServerScriptService/Server/GoldenMeridianState.luau` |
| ServerScriptService › Server | ModuleScript `World2Gateway` | `src/ServerScriptService/Server/World2Gateway.luau` |
| ServerScriptService › Server | ModuleScript `GoldenDevTools` (Studio only) | `src/ServerScriptService/Server/GoldenDevTools.luau` |
| StarterPlayer › StarterPlayerScripts | **LocalScript** `GoldenMeridianClient` | `src/StarterPlayer/StarterPlayerScripts/GoldenMeridianClient.client.luau` |
| StarterPlayer › StarterPlayerScripts | **LocalScript** `GoldenDevPanel` (Studio only) | `…/GoldenDevPanel.client.luau` |
| StarterPlayer › StarterPlayerScripts | ModuleScript `GoldenDirector` | `…/GoldenDirector.luau` |
| StarterPlayer › StarterPlayerScripts | ModuleScript `GoldenAudio` | `…/GoldenAudio.luau` |
| StarterPlayer › StarterPlayerScripts | ModuleScript `GoldenDialogue` | `…/GoldenDialogue.luau` |
| StarterPlayer › StarterPlayerScripts | ModuleScript `GoldenRock` | `…/GoldenRock.luau` |
| StarterPlayer › StarterPlayerScripts | ModuleScript `GoldenRockCinematic` | `…/GoldenRockCinematic.luau` |
| StarterPlayer › StarterPlayerScripts | ModuleScript `SpiritRealm` | `…/SpiritRealm.luau` |
| StarterPlayer › StarterPlayerScripts | ModuleScript `PebbleGod` | `…/PebbleGod.luau` |
| StarterPlayer › StarterPlayerScripts | ModuleScript `DivineTrial` | `…/DivineTrial.luau` |
| StarterPlayer › StarterPlayerScripts | ModuleScript `GoldenBlessing` | `…/GoldenBlessing.luau` |
| StarterPlayer › StarterPlayerScripts | ModuleScript `GoldenEnding` | `…/GoldenEnding.luau` |

Names must match exactly; the scripts find each other by name.

## 2. Replace these (whole file)

These belong to the rebirth cutscene I built. If you edited any of them in Studio after
the import, send me your version first.

| Studio location | Script |
| --- | --- |
| ReplicatedStorage › Shared | `AwakeningConfig` (now 10 meridians) |
| StarterPlayer › StarterPlayerScripts | `AwakeningCinematic` |
| StarterPlayer › StarterPlayerScripts | `AwakeningMeridians` |
| StarterPlayer › StarterPlayerScripts | `AwakeningVFX` |

## 3. Small edits to your existing core scripts (paste, don't replace)

**ReplicatedStorage › Shared › ProgressionConfig**

After the line `P.MaxRebirths=24`, add:
```lua
-- Normal rebirths end at the tenth meridian; the Golden Meridian follows (GoldenMeridianService).
-- Derived from the meridian map so the rebirth count and the cutscene always agree.
P.NormalRebirths=#require(script.Parent.AwakeningConfig).Nodes
```
In `P.canRebirth`, right after the line containing `"Maximum rebirth potential reached"`, add:
```lua
 if r>=P.NormalRebirths then
  local golden=type(profile.goldenPath)=="table" and profile.goldenPath.unlocked==true
  return false,golden and "The Golden Meridian has awakened" or "Ten paths awakened · return to the Magical Rock"
 end
```

**ServerScriptService › Server › Persistence**

In `serialise`, after `quests = profile.quests,` add:
```lua
		goldenPath = require(script.Parent.GoldenMeridianState).serialise(profile),
```
In `deserialise`, after `profile.tutorialSkipped = data.tutorialSkipped == true` add:
```lua
	require(script.Parent.GoldenMeridianState).deserialise(profile, data.goldenPath)
```

**ServerScriptService › Server › Profiles** (only needed for Studio's type checker)

In `export type Profile = {`, before `loaded: boolean,` add:
```lua
	goldenPath: {[string]: any}?,
```

Nothing else changes. `AwakeningAudio`, `AwakeningPose`, `AwakeningService` and your new
rebirth UI (`RebirthClient`) are untouched. The UI only needs to keep starting the cutscene
the same way (`Cinematic.begin(data, onFinished)`, then forwarding Play/Complete/Abort).

## 4. Test it in Studio

Press Play. A **GOLDEN DEV** button appears at the top left; it only exists in Studio.

- **Preview 1–10:** replays that rebirth's cutscene at the rock without changing your save.
  Rebirth 10 includes the finale.
- **Ready next / Set 0 / Set 9 / Set 10:** real progression on your Studio save. Use *Set 9*
  then *Ready next*, and do the real 10th rebirth at the rock to see the finale, the stone's
  speech and the transformation in order.
- **Stone speech:** replays the stone speaking after rebirth 10 (stand near the rock).
- **Calling:** skips the speech straight to the golden, calling stone.
- **Start trial:** runs the full true-rebirth sequence for real.
- **Unfinished ending:** what a player sees if they left after the trial but before the end.
- **Memory visit:** what a player who finished everything sees at the stone.
- **Fast dialogue:** auto-advances dialogue after 0.7 s.

Enable *Game Settings → Security → Studio Access to API Services* if you want the save
flags to persist between test sessions.

## Where to change things

- **Every spoken line:** `GoldenMeridianConfig.Script`, `RockSpeech`, `RockCalls`, `Ending`.
- **Colours:** `GoldenMeridianConfig` (Gold, WhiteGold, Amber, …).
- **How easy the trial is:** `GoldenMeridianConfig.Trial.MinCharge`. The server enforces it.
- **Realm layout (god distance, gate, skip distances):** `GoldenMeridianConfig.Realm`.
- **World 2:** set `GoldenMeridianConfig.World2.Enabled = true` and implement
  `World2Gateway.send`. The server then sends the player on instead of back to the stone.

## Saved data

Progress is stored in the existing save document as `goldenPath`, with these flags:
`invitationSeen`, `trialStarted`, `trialCompleted`, `unlocked`, `world2`, `endingSeen` and
`unlockedAt`. Old saves load with an empty path. The Golden Meridian and World 2 access are
granted and saved the moment the trial succeeds, so disconnecting afterwards never loses
them; the player sees the unfinished ending next time. `MaxRebirths` stays 24 so no existing
save is cut down. New rebirths stop at 10, and any tester already above 10 is simply invited.
