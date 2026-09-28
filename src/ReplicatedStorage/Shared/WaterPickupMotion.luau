--!nonstrict
-- Absolute server-time sampling keeps every render frame continuous, including late joiners.
local M = {}
M.Active = 1
M.Sinking = 2
M.Submerged = 3
M.Rising = 4
M.SinkSeconds = 6
M.RiseSeconds = 1.35
M.SurfaceMin = 15
M.SurfaceMax = 15
M.RestMin = 30
M.RestMax = 30
function M.encode(phase,started,duration)
 return string.format("%d|%.9f|%.6f",phase,started,duration)
end
function M.decode(value)
 if typeof(value)=="Vector3" then return value end
 if type(value)=="table" then return value end
 if type(value)~="string" then return nil end
 local x,y,z=value:match("^(%d+)|([%d%.]+)|([%d%.]+)$")
 x,y,z=tonumber(x),tonumber(y),tonumber(z)
 if not x or not y or not z or z<=0 then return nil end
 return {X=x,Y=y,Z=z}
end
function M.smooth(t: number): number
 t = math.clamp(t, 0, 1)
 return t*t*t*(t*(t*6-15)+10)
end
function M.sample(timeline: any, now: number, seed: number, depth: number, reduced: boolean?): (CFrame, number, boolean)
 local phase = timeline.X
 local progress = math.clamp((now-timeline.Y)/math.max(timeline.Z,.001),0,1)
 local surface = if phase==M.Active then 1
  elseif phase==M.Sinking then 1-M.smooth(progress)
  elseif phase==M.Rising then M.smooth(progress) else 0
 -- This small motion is part of the gameplay target. Both accessibility modes
 -- use the same pose; Reduced Motion still suppresses decorative client effects.
 -- Seed changes the rhythm as well as the phase so nearby objects never march together.
 local variety = .5+.5*math.sin(seed*2.173+1.4)
 local pace = 1.12+variety*.62
 local amplitude = .22+(.5+.5*math.sin(seed*3.11))*.14
 local bob = math.sin(now*pace+seed)*amplitude + math.sin(now*(pace*1.57)+seed*.73)*.045
 local roll = math.sin(now*(.72+variety*.32)+seed)*.022*surface
 local pitch = math.sin(now*(.61+variety*.28)+seed*1.3)*.017*surface
 local turn = math.sin(now*(.38+variety*.17)+seed)*.024*surface
 local offset = CFrame.new(0,bob*surface-depth*(1-surface),0)*CFrame.Angles(pitch,turn,roll)
 -- Fade only once the model is below the surface, never as a contact disappearance.
 local hidden = if phase==M.Submerged then 1 else 0
 return offset,hidden,(phase==M.Active or phase==M.Sinking or phase==M.Rising) and now<timeline.Y+timeline.Z
end
function M.available(timeline: any, now: number): boolean
 timeline=M.decode(timeline)
 return timeline~=nil and (timeline.X==M.Active or timeline.X==M.Sinking or timeline.X==M.Rising) and now<timeline.Y+timeline.Z
end
-- Shared geometry pose, including orbiting pieces, used by both visual and hit code.
function M.partFrame(base, motion, localCF, orbit, now)
 return if orbit then base*motion*CFrame.Angles(0,now*.32,0)*localCF else base*motion*localCF
end
function M.pose(model, now)
 local timeline=M.decode(model:GetAttribute("PickupTimeline"))
 local base=model:GetAttribute("PickupBase")
 if not timeline or typeof(base)~="CFrame" then return nil end
 local motion,fade=M.sample(timeline,now,model:GetAttribute("PickupSeed") or 0,model:GetAttribute("PickupDepth") or 26)
 return base*motion,fade,motion,timeline
end
function M.availableForModel(model,now)
 if model:GetAttribute("PickupClaimed")==true or model:GetAttribute("Broken")==true then return false end
 local cf,_,_,timeline=M.pose(model,now)
 if not cf or not M.available(timeline,now) then return false end
 local bounds=model:GetAttribute("PickupVisualBounds")
 local size=model:GetAttribute("PickupVisualSize")
 if typeof(bounds)~="CFrame" or typeof(size)~="Vector3" then return timeline.X==M.Active end
 local box=cf*bounds
 local halfY=(math.abs(box.RightVector.Y)*size.X+math.abs(box.UpVector.Y)*size.Y+math.abs(box.LookVector.Y)*size.Z)*.5
 return box.Position.Y+halfY>(model:GetAttribute("PickupWaterY") or cf.Position.Y)+.05
end
return M
