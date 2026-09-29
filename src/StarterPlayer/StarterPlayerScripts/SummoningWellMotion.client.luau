-- Cosmetic motion for the summoning well. Summon interaction and rewards remain in their existing scripts.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local plaza = workspace:WaitForChild("PebblePlaza_20260925", 30)
if not plaza then return end
local well = plaza:WaitForChild("SummoningWellVisuals", 30)
if not well then return end
local pebbles = well:WaitForChild("OrbitPebbles", 30)
if not pebbles then return end

local centerX = well:GetAttribute("CenterX") or -660.196
local centerZ = well:GetAttribute("CenterZ") or -23.783
local elapsed = 0
local throttle = 0
local connection
connection = RunService.RenderStepped:Connect(function(dt)
 if not well:IsDescendantOf(workspace) then
  connection:Disconnect()
  return
 end
 if player:GetAttribute("ReducedMotion") == true then return end
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 if not root or (root.Position - Vector3.new(centerX, root.Position.Y, centerZ)).Magnitude > 150 then return end
 elapsed += math.min(dt, .05)
 throttle += dt
 if throttle < 1/30 then return end
 throttle = 0
 for _, pebble in ipairs(pebbles:GetChildren()) do
  if pebble:IsA("BasePart") then
   local index = pebble:GetAttribute("OrbitIndex") or 1
   local angle = (index - 1) * math.pi * 2 / 7 + elapsed * .47
   local radius = 3.3 + (index % 2) * .35
   local height = 20.1 + math.sin(elapsed * 1.4 + index) * .32
   pebble.CFrame = CFrame.new(centerX + math.cos(angle) * radius, height, centerZ + math.sin(angle) * radius)
    * CFrame.Angles(elapsed * .21 + index * .2, angle, elapsed * .19)
  end
 end
end)

script.Destroying:Connect(function()
 if connection then connection:Disconnect() end
end)
