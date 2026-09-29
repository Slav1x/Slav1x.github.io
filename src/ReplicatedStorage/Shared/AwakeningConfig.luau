-- Shared presentation data only. Eligibility, receipts and commits live on the server.
local C = {}
C.Duration = 15.2
C.ActivationTime = 10.6
C.SkipAfter = 1.5
C.Timeout = 26
C.MaxDistance = 14
C.Blue = Color3.fromRGB(57, 165, 255)
C.Ice = Color3.fromRGB(190, 236, 255)
C.Dormant = Color3.fromRGB(87, 91, 98)
C.FallbackPosition = Vector3.new(-720, 41, -40.5)
C.Audio = {
 Ambient = "rbxassetid://1837463526", -- APM: Ethereal Drone
 Chime = "rbxassetid://9116395089", -- Pro Sound Effects: soft magic chimes
 Impact = "rbxassetid://9116384485", -- Pro Sound Effects: Magic Burst 1
}
-- The ten meridians, one per rebirth. `at` is in the inner body's normalized local
-- coordinates (the same space as the channel paths in AwakeningMeridians).
-- ProgressionConfig.NormalRebirths is derived from #C.Nodes, so the number of
-- rebirths and the number of meridians can never drift apart.
C.Nodes = {
 {id="heart", name="Heart Meridian", at=Vector3.new(0,.65,-.55), unlock=1},
 {id="root", name="Root Meridian", at=Vector3.new(0,-.8,-.55), unlock=2},
 {id="throat", name="Voice Meridian", at=Vector3.new(0,1.55,-.55), unlock=3},
 {id="left", name="Flow Meridian", at=Vector3.new(-1.55,.4,-.55), unlock=4},
 {id="right", name="Force Meridian", at=Vector3.new(1.55,.4,-.55), unlock=5},
 {id="leftStride", name="Stride Meridian", at=Vector3.new(-.52,-2.15,-.55), unlock=6},
 {id="rightStride", name="Anchor Meridian", at=Vector3.new(.52,-2.15,-.55), unlock=7},
 {id="hand", name="Skipping Meridian", at=Vector3.new(1.65,-1,-.55), unlock=8},
 {id="brow", name="Sight Meridian", at=Vector3.new(0,2.35,-.55), unlock=9},
 {id="crown", name="Crown Meridian", at=Vector3.new(0,2.9,-.55), unlock=10},
}
C.FinalAwakening = #C.Nodes
C.Ordinals = {"FIRST","SECOND","THIRD","FOURTH","FIFTH","SIXTH","SEVENTH","EIGHTH","NINTH","TENTH"}
C.Numerals = {"I","II","III","IV","V","VI","VII","VIII","IX","X"}
-- Words the cutscene whispers inside the body, per awakening.
C.InnerLines = {
 [1] = {before="One quiet point. A greater possibility.", after="The first light is yours."},
 [C.FinalAwakening] = {before="The last quiet point.", after="The tenth path wakes."},
 default = {before="Another quiet point is listening.", after="Another path wakes."},
}
function C.stage(count)
 local target=C.Nodes[1]
 for _,node in C.Nodes do if node.unlock<=count then target=node end end
 return target, target.unlock==count
end
function C.chapter(count)
 local i=math.clamp(math.floor(count),1,#C.Nodes)
 return C.Numerals[i].."  ·  THE "..C.Ordinals[i].." AWAKENING"
end
function C.innerLine(count,after)
 local lines=C.InnerLines[count] or C.InnerLines.default
 return after and lines.after or lines.before
end
return C
