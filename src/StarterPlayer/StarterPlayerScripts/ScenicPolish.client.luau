--!nonstrict
-- Local, non-colliding lake art. All movement is cosmetic and throttled.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Water = require(RS.Shared.WaterSurface)
local player = Players.LocalPlayer
local spawn = workspace:WaitForChild("SpawnLocation")
local folder = Instance.new("Folder")
folder.Name = "LocalScenicPolish"
folder.Parent = workspace

local function part(parent, name, size, cf, color, material, transparency)
 local p = Instance.new("Part")
 p.Name = name
 p.Size = size
 p.CFrame = cf
 p.Color = color
 p.Material = material or Enum.Material.SmoothPlastic
 p.Transparency = transparency or 0
 p.Anchored = true
 p.CanCollide = false
 p.CanTouch = false
 p.CanQuery = false
 p.CastShadow = false
 p.Parent = parent
 return p
end

local lakeY = Water.at(spawn.Position + Vector3.new(260, 0, 0)) or 15.09
local glints = {}
for i = 1, 9 do
 local x = spawn.Position.X + 205 + i * 87
 local z = spawn.Position.Z + math.sin(i * 2.4) * 42
 local cf = CFrame.new(x, lakeY + 0.15, z) * CFrame.Angles(0, math.rad(20 + i * 17), 0)
 local glint = part(folder, "WaterGlint", Vector3.new(4 + i % 3 * 2, 0.04, 0.12), cf,
  Color3.fromRGB(255, 245, 199), Enum.Material.Neon, 0.75)
 table.insert(glints, {part = glint, phase = i * 1.3})
end

-- Three distinct silhouettes make the long channel feel like a journey.
local landmarks = {}
local designs = {} -- Landmarks are authored on the banks by EnvironmentOverhaul.
for index, design in designs do
 local x = spawn.Position.X + design.distance
 local z = spawn.Position.Z + design.side * 119
 local hit = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -150, 0))
 if hit then
  local ground = hit.Position.Y
  local model = Instance.new("Model")
  model.Name = design.name
  model.Parent = folder
  part(model, "Plinth", Vector3.new(11, 2.5, 11), CFrame.new(x, ground + 1.25, z),
   Color3.fromRGB(37, 64, 84), Enum.Material.Slate)
  part(model, "Column", Vector3.new(3.5, 27, 3.5), CFrame.new(x, ground + 16, z),
   Color3.fromRGB(229, 238, 240), Enum.Material.SmoothPlastic)
  part(model, "Accent", Vector3.new(6, 2, 6), CFrame.new(x, ground + 29, z),
   design.color, Enum.Material.Neon)
  local orb = part(model, "Beacon", Vector3.new(7, 7, 7), CFrame.new(x, ground + 35, z),
   design.color, Enum.Material.Neon)
  orb.Shape = Enum.PartType.Ball
  if index == 1 then
   for ray = 1, 6 do
    local angle = ray * math.pi / 3
    local rayCF = CFrame.new(x, ground + 35, z) * CFrame.Angles(0, 0, angle) * CFrame.new(0, 8.5, 0)
    part(model, "SunRay", Vector3.new(1.15, 6.5, 1.15), rayCF, design.color, Enum.Material.Neon)
   end
  elseif index == 2 then
   for _, side in {-1, 1} do
    local branchCF = CFrame.new(x + side * 5, ground + 16, z) * CFrame.Angles(0, 0, math.rad(-side * 23))
    part(model, "CoralBranch", Vector3.new(2.2, 19, 2.2), branchCF, design.color, Enum.Material.SmoothPlastic)
   end
  else
   for _, side in {-1, 1} do
    local sailCF = CFrame.new(x + side * 5.5, ground + 16, z) * CFrame.Angles(0, 0, math.rad(side * 17))
    part(model, "SkySail", Vector3.new(2, 24, 3.2), sailCF, design.color, Enum.Material.Neon, 0.22)
   end
  end
  local mast = part(model, "FlagPole", Vector3.new(0.55, 13, 0.55), CFrame.new(x, ground + 36, z + design.side * 4),
   Color3.fromRGB(32, 57, 73), Enum.Material.Metal)
  local flagCF = CFrame.new(x + 4.2, ground + 39, z + design.side * 4)
  local flag = part(model, "WindFlag", Vector3.new(8.1, 4.2, 0.25), flagCF, design.color,
   Enum.Material.SmoothPlastic)
  table.insert(landmarks, {flag = flag, base = flagCF, phase = index * 1.7, orb = orb})
 end
end

-- Quiet silhouettes above the water, built without emitters or physics.
local birds = {}
for i = 1, 5 do
 local wingA = part(folder, "BirdWing", Vector3.new(2.3, 0.12, 0.32), CFrame.new(),
  Color3.fromRGB(30, 69, 88))
 local wingB = part(folder, "BirdWing", Vector3.new(2.3, 0.12, 0.32), CFrame.new(),
  Color3.fromRGB(30, 69, 88))
 table.insert(birds, {a = wingA, b = wingB, phase = i * 1.8, distance = 250 + i * 52,
  height = 53 + i % 3 * 7, lateral = (i - 3) * 15})
end

local elapsed = 0
local connection
connection = RunService.Heartbeat:Connect(function(dt)
 elapsed += dt
 if elapsed < 0.10 then return end
 elapsed = 0
 local now = os.clock()
 local reduced = player:GetAttribute("ReducedMotion") == true
 for _, item in glints do
  item.part.Transparency = if reduced then 0.78 else 0.69 + 0.17 * math.sin(now * 1.5 + item.phase)
 end
 for _, item in landmarks do
  if reduced then item.flag.CFrame = item.base
  else
   item.flag.CFrame = item.base * CFrame.Angles(0, math.sin(now * 1.2 + item.phase) * 0.12,
    math.sin(now * 1.5 + item.phase) * 0.05)
  end
 end
 for _, bird in birds do
  local x = spawn.Position.X + bird.distance + (if reduced then 0 else math.sin(now * 0.22 + bird.phase) * 28)
  local y = lakeY + bird.height + (if reduced then 0 else math.sin(now * 0.7 + bird.phase) * 2)
  local z = spawn.Position.Z + bird.lateral
  local flap = if reduced then 0.08 else math.sin(now * 4.4 + bird.phase) * 0.16
  bird.a.CFrame = CFrame.new(x - 1, y, z) * CFrame.Angles(0, math.rad(20), flap + 0.12)
  bird.b.CFrame = CFrame.new(x + 1, y, z) * CFrame.Angles(0, math.rad(-20), -flap - 0.12)
 end
end)
script.Destroying:Connect(function()
 connection:Disconnect()
 folder:Destroy()
end)
