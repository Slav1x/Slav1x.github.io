-- The Golden Meridian: the finale beyond the ten awakenings.
-- Shared presentation data, realm layout and the script. Nothing here grants anything;
-- GoldenMeridianService on the server owns eligibility, the trial result and saving.
local Awakening=require(script.Parent.AwakeningConfig)
local C={}

C.NormalAwakenings=Awakening.FinalAwakening -- rebirth 10 completes the blue network

-- Palette: a warm divine gold, not flat yellow.
C.Gold=Color3.fromRGB(255,193,86)
C.WhiteGold=Color3.fromRGB(255,241,208)
C.WhiteHot=Color3.fromRGB(255,252,240)
C.Amber=Color3.fromRGB(228,122,36)
C.DeepGold=Color3.fromRGB(176,108,28)
C.Blue=Awakening.Blue
C.Ice=Awakening.Ice
C.Mist=Color3.fromRGB(236,228,212)

C.Audio={
 Ambient=Awakening.Audio.Ambient,
 Chime=Awakening.Audio.Chime,
 Impact=Awakening.Audio.Impact,
 Water="rbxassetid://9112877174", -- LakeSoundscape: lake bed
 Wash="rbxassetid://9126195224", -- LakeSoundscape: shore wash
 Splash="rbxassetid://119214808310856", -- ThrowFx: skip splash
}

-- Timings the server enforces. Presentation timings live with each client module.
C.RockReach=14 -- studs from the rock's InteractionAnchor to begin
C.PrepareTimeout=60 -- rock cutscene, realm build and the first reveal must finish by then
C.ReturnTimeout=8 -- the stone waits this long for the client to stream the world back in
C.SessionTimeout=20*60 -- a forgotten realm session returns the player to the stone
C.TrialRange=80 -- the trial can only open near the Pebble God

-- Realm layout. Each concurrent session gets its own slot far from the map and from
-- other slots, so players never see each other in their own realm.
-- The map runs along +X from ZoneConfig.OriginX; the realm sits far off it.
C.Realm={
 Base=Vector3.new(-9000,1600,9000),
 SlotSpacing=3500,
 WalkSpeed=14,
 -- Realm-local coordinates: -Z is "toward the god" (and toward the low sun).
 God=Vector3.new(0,0,-230),
 TrialSpot=Vector3.new(-12,0,-210),
 Gate=Vector3.new(250,0,-210),
 Skips={30,72,118,164,208,250}, -- distances along the trial path, last one is the gate
}
-- World basis for a slot. Realm -Z maps to world -X, so the god always stands "west".
function C.realmBasis(slot)
 local origin=C.Realm.Base+Vector3.new(0,0,slot*C.Realm.SlotSpacing)
 return CFrame.lookAt(origin,origin+Vector3.new(-1,0,0))
end
function C.realmPoint(basis,v) return basis:PointToWorldSpace(v) end

C.Trial={
 MinCharge=.12, -- any deliberate hold passes; only a sub-tenth-second tap falls short
 ChargeTime=.8,
 ThrowCooldown=.8,
}

C.World2={
 -- Flip on (and implement World2Gateway.send) once World 2 exists.
 Enabled=false,
 Name="WORLD II",
}

------------------------------------------------------------------------------------------
-- The script. {name} is replaced with the player's display name.
------------------------------------------------------------------------------------------
C.Speaker={Unknown="· · ·",God="THE PEBBLE GOD",Stone="THE MAGICAL ROCK"}

-- After the tenth awakening the stone speaks once, then changes for this player.
C.RockSpeech={
 "{name}…",
 "Ten paths now flow within you.",
 "Ten streams, each running its own way.",
 "But streams were never meant to stay apart.",
 "Beyond the ten, they become one.",
 "Return to me when you are ready.",
}
-- Then it keeps calling, more insistently than before.
C.RockCalls={
 "The ten must become one.",
 "The final path is open.",
 "Return to the stone.",
 "What was scattered is waiting to be gathered.",
 "Beyond the ten, something is waiting.",
}

-- Each line: {text, speaker?, cue?}. Cues are handled by the client sequence.
C.Script={
 Arrival={
  {"So. The stone found someone who would listen.",cue="lift"},
  {"Ten times you let go of everything you had built. Ten times you came back stronger."},
  {"The stone you touched is a pebble I let fall, long ago. It has waited at the water's edge for hands like yours.",cue="stonesStir"},
  {"Your kind has called me many things. The skippers call me the Pebble God.",cue="reveal"},
  {"Ten paths are strength. But strength that flows ten ways is only noise.",cue="mist"},
  {"Gather them, and you will hold what no training can give. The Golden Meridian."},
  {"It is not given for what you have collected. Only for what you are."},
  {"So show me the first thing you ever learned."},
 },
 Summon={
  {"A stone. The water. Your hand.",cue="pebble"},
  {"Reach the light.",cue="path"},
  {"Begin.",cue="begin"},
 },
 Retry={"Again.","The water is patient. Again.","Again."},
 Success={
  {"Good."},
  {"You have not forgotten where your strength began."},
  {"Then receive what lies beyond the ten.",cue="approach"},
 },
 Blessing={
  {"Close your eyes.",cue="touch"},
 },
 AfterBlessing={
  {"Until now, you have trained your body. Your arm. Your aim. Your will."},
  {"What wakes in you now does not live in the body.",cue="stonesFreeze"},
  {"The Golden Meridian lets you draw on what lies beneath the world. Powers your first world has no names for."},
  {"Your first journey is finished. It was never meant to be your last."},
  {"Beyond this water there is another world. Stranger forces. Older things. They will not wait for you."},
  {"There, you will learn to use what you have become."},
  {"Go.",cue="send"},
 },
 -- A player who unlocked the Golden Meridian but left before the blessing finished.
 Unfinished={
  {"You left before it was finished.",cue="lift"},
  {"Stand still.",cue="approach"},
 },
 -- A player who already saw everything, returning to the stone.
 Memory={
  {"You carry the gold already.",cue="lift"},
  {"The way beyond is not yet open. When it is, this water will carry you there."},
  {"Until then, go. Your world still remembers your name.",cue="send"},
 },
}

C.Ending={
 Kicker="THE GOLDEN MERIDIAN HAS AWAKENED",
 Title="TO BE CONTINUED…",
 Footer="WORLD II",
}

function C.format(text,name) return (string.gsub(text,"{name}",name)) end
return C
