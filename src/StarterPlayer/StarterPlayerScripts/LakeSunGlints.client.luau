-- Sparse client-side sun glints. The pool stays near the camera and only lights visible lake surface.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local WaterSurface = require(game.ReplicatedStorage.Shared.WaterSurface)

local player = Players.LocalPlayer
local folder = Instance.new("Folder")
folder.Name = "LocalLakeGlints"
folder.Parent = workspace

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = {folder}
rayParams.IgnoreWater = true

local glints = {}
for i = 1, 30 do
 local part = Instance.new("Part")
 part.Name = "SunGlint"
 part.Anchored = true
 part.CanCollide = false
 part.CanTouch = false
 part.CanQuery = false
 part.CastShadow = false
 part.Material = Enum.Material.Neon
 part.Color = Color3.fromRGB(255, 246, 215)
 part.Size = Vector3.new(2.2 + (i % 4) * 0.9, 0.025, 0.1 + (i % 3) * 0.035)
 part.Transparency = 1
 part.Parent = folder
 glints[i] = part
end

local elapsed = 0
local connection = RunService.Heartbeat:Connect(function(dt)
 elapsed += dt
 if elapsed < 0.12 then return end
 elapsed = 0
 local camera = workspace.CurrentCamera
 if not camera then return end

 local baseX = math.floor(math.max(-300, camera.CFrame.Position.X + 160) / 80) * 80
 local now = os.clock()
 local reducedMotion = player:GetAttribute("ReducedMotion") == true
 for i, part in glints do
  local row = math.floor((i - 1) / 6)
  local column = (i - 1) % 6
  local x = baseX + row * 105 + ((i * 37) % 29) - 14
  local z = -40.5 + (column - 2.5) * 66 + ((i * 19) % 23) - 11
  local level = WaterSurface.at(Vector3.new(x, 0, z))
  if level then
   local hit = workspace:Raycast(Vector3.new(x, level + 25, z), Vector3.new(0, -27, 0), rayParams)
   if hit and CollectionService:HasTag(hit.Instance, WaterSurface.Tag) then
    local pulse = reducedMotion and 0.45 or math.max(0, math.sin(now * 1.25 + i * 2.17)) ^ 2
    part.CFrame = CFrame.new(x, level + 0.09, z) * CFrame.Angles(0, math.rad(((i * 13) % 35) - 17), 0)
    part.Transparency = 1 - 0.3 * pulse
   else
    part.Transparency = 1
   end
  else
   part.Transparency = 1
  end
 end
end)

script.Destroying:Connect(function()
 connection:Disconnect()
 folder:Destroy()
end)
