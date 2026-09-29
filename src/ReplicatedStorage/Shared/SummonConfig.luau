-- Shared source for the summon price, pool, timing, and displayed odds.
local Config = {}
-- Fixed world-space staging above the summoning basin; never derived from a character.
local basin = workspace:WaitForChild("SummoningPool")
Config.SpawnCFrame = CFrame.new(basin.Position + Vector3.new(0, 2.5, 0))
Config.RiseHeight = 3.6655
Config.CameraOffset = Vector3.new(12, 3, 0)
Config.CameraEnterSeconds = 1.1
Config.TierTransitionSeconds = 0.14
Config.TierPauseSeconds = 0.10
Config.CrackBeatSeconds = 0.24
Config.RevealSeconds = 0.72
Config.CameraReturnSeconds = 0.9
Config.BatchSpacing = 7
local function batchViewDirection()
 return Config.CameraOffset.Unit
end
function Config.slotCFrame(index, count)
 assert(count >= 1 and count <= 3 and index >= 1 and index <= count)
 local right = CFrame.lookAt(Config.CameraOffset, Vector3.zero).RightVector
 if count == 3 then
  -- Face the summon camera: one upper apex and two lower corners.
  -- Match the reference's 5:5:7 triangle, keeping its centroid at the summon center.
  local basis = CFrame.lookAt(batchViewDirection(), Vector3.zero)
  local height = Config.BatchSpacing * math.sqrt(5*5 - 3.5*3.5) / 7
  local lateral = index == 1 and -Config.BatchSpacing/2 or (index == 3 and Config.BatchSpacing/2 or 0)
  local vertical = index == 2 and height*2/3 or -height/3
  return Config.SpawnCFrame + basis.RightVector*lateral + basis.UpVector*vertical
 end
 return Config.SpawnCFrame + right * ((index - (count + 1) / 2) * Config.BatchSpacing)
end
function Config.batchCameraOffset(count, aspect)
 -- Every summon uses the single-summon shot, with no batch tilt or pullback.
 return Config.CameraOffset
end
Config.Cost = require(script.Parent.ZoneConfig).List[1].cost
Config.DisplaySeconds = 2
Config.ExitSeconds = 0.18
Config.PreviewOdds = true -- Preserves the existing equal-odds preview.
Config.Pool = require(script.Parent.ZoneConfig).List[1].pool
function Config.totalWeight()
 local total=0
 for _,entry in ipairs(Config.Pool) do
  assert(entry.weight > 0 and entry.weight % 1 == 0, "Invalid summon weight")
  total += entry.weight
 end
 return total
end
function Config.pick(random)
 local ticket=random:NextInteger(1,Config.totalWeight())
 for _,entry in ipairs(Config.Pool) do
  ticket -= entry.weight
  if ticket <= 0 then return entry.id end
 end
 error("Invalid summon pool")
end
return Config