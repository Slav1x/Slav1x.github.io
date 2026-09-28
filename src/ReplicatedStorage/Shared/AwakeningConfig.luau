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
-- Positions are in the inner body's normalized local coordinates.
-- Later awakenings can extend this table without changing the cinematic renderer.
C.Nodes = {
 {id="heart", name="Heart Meridian", at=Vector3.new(0,.65,-.55), unlock=1},
 {id="root", name="Root Meridian", at=Vector3.new(0,-.8,-.55), unlock=3},
 {id="throat", name="Voice Meridian", at=Vector3.new(0,1.55,-.55), unlock=5},
 {id="left", name="Flow Meridian", at=Vector3.new(-1.55,.4,-.55), unlock=8},
 {id="right", name="Force Meridian", at=Vector3.new(1.55,.4,-.55), unlock=12},
 {id="brow", name="Sight Meridian", at=Vector3.new(0,2.35,-.55), unlock=18},
 {id="crown", name="Crown Meridian", at=Vector3.new(0,2.9,-.55), unlock=24},
}
function C.stage(count)
 local target=C.Nodes[1]
 for _,node in C.Nodes do if node.unlock<=count then target=node end end
 return target, target.unlock==count
end
return C
