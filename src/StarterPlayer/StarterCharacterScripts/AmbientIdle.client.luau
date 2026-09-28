--!nonstrict
-- Gentle additive idle for an unequipped character. Gameplay animation keeps priority.
local RunService = game:GetService("RunService")
local player = game:GetService("Players").LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
-- Keep the neck stretch on the neck and torso; do not pin the left arm with IK.
local joints = {}
local allowed = {
 Root = true, RootJoint = true, Waist = true, Neck = true,
 RightShoulder = true, LeftShoulder = true, RightElbow = true, LeftElbow = true,
 RightHip = true, LeftHip = true, RightKnee = true, LeftKnee = true,
}
for _, joint in character:GetDescendants() do
 if (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) and allowed[joint.Name:gsub(" ", "")] then
  table.insert(joints, {motor = joint, key = joint.Name:gsub(" ", ""), base = joint.Transform})
 end
end
local equipped = character:FindFirstChildWhichIsA("Tool") ~= nil
character.ChildAdded:Connect(function(child)
 if child:IsA("Tool") then equipped = true end
end)
character.ChildRemoved:Connect(function(child)
 if child:IsA("Tool") then equipped = character:FindFirstChildWhichIsA("Tool") ~= nil end
end)

local function smooth(t)
 t = math.clamp(t, 0, 1)
 return t * t * (3 - 2 * t)
end
local function angles(x, y, z)
 return Vector3.new(x or 0, y or 0, z or 0)
end
local function stretchPose(kind, key)
 if kind == 1 then -- arms and shoulders
  if key == "RightShoulder" then return angles(-28, -8, 12) end
  if key == "LeftShoulder" then return angles(-28, 8, -12) end
  if key == "RightElbow" or key == "LeftElbow" then return angles(-10) end
  if key == "Waist" or key == "RootJoint" then return angles(-4) end
  if key == "Neck" then return angles(7) end
 elseif kind == 2 then -- easy side bend
  if key == "Waist" or key == "RootJoint" then return angles(-2, -4, 7) end
  if key == "Neck" then return angles(3, 3, -5) end
  if key == "LeftShoulder" then return angles(-12, 0, -10) end
  if key == "RightShoulder" then return angles(2, 0, 5) end
 elseif kind == 3 then -- back and neck reset
  if key == "Waist" or key == "RootJoint" then return angles(-6, 0, 0) end
  if key == "Neck" then return angles(8, 0, 0) end
  if key == "RightShoulder" then return angles(-9, 0, 8) end
 else -- small weight shift through hips and legs
  if key == "Waist" or key == "RootJoint" then return angles(0, 3, -4) end
  if key == "Neck" then return angles(0, -2, 2) end
  if key == "RightHip" then return angles(-6, 0, -2) end
  if key == "LeftHip" then return angles(5, 0, -2) end
  if key == "RightKnee" then return angles(5) end
 end
 return Vector3.zero
end

local weight = 0
local stillFor = 0
local nextStretch = 7
local stretchStart = nil
local stretchKind = 1
local last = os.clock()
local function restore()
 for _, entry in joints do
  if entry.motor.Parent then entry.motor.Transform = entry.base end
 end
end
local pre = RunService.PreAnimation:Connect(restore)
local post = RunService.PreSimulation:Connect(function()
 if not character.Parent or humanoid.Health <= 0 then return end
 local now = os.clock()
 local dt = math.clamp(now - last, 0, 0.05)
 last = now
 local idle = player:GetAttribute("ReducedMotion") ~= true and not equipped and humanoid.MoveDirection.Magnitude < 0.07
  and humanoid.FloorMaterial ~= Enum.Material.Air and not humanoid.Sit
 weight += ((if idle then 1 else 0) - weight) * (1 - math.exp(-6 * dt))
 if idle then
  stillFor += dt
  if not stretchStart and stillFor > nextStretch then
   stretchStart = now
   stretchKind = math.random(1, 4)
  end
 else
  stillFor = 0
  stretchStart = nil
  nextStretch = math.random(5, 9)
 end
 local stretch = 0
 if stretchStart then
  local t = (now - stretchStart) / 2.7
  if t >= 1 then
   stretchStart = nil
   stillFor = 0
   nextStretch = math.random(6, 10)
  else
   stretch = math.sin(math.pi * smooth(t)) ^ 2
  end
 end
 local breath = math.sin(now * 1.65)
 for _, entry in joints do
  local joint = entry.motor
  if not joint.Parent then continue end
  entry.base = joint.Transform
  if weight < 0.002 then continue end
  local key = entry.key
  -- Let walking, running, and tool animations own both arms immediately.
  if not idle and (key == "LeftShoulder" or key == "LeftElbow" or key == "RightShoulder" or key == "RightElbow") then continue end
  local motion = Vector3.zero
  if key == "Waist" or key == "RootJoint" then motion = angles(1.25 * breath, 0, 0.5 * breath)
  elseif key == "Neck" then motion = angles(-0.8 * breath, 0, 0)
  elseif key == "RightShoulder" then motion = angles(0.5 * breath, 0, 0.4 * breath)
  elseif key == "LeftShoulder" then motion = angles(0.5 * breath, 0, -0.4 * breath)
  elseif key == "RightHip" then motion = angles(-0.35 * breath)
  elseif key == "LeftHip" then motion = angles(0.35 * breath) end
  motion = (motion + stretchPose(stretchKind, key) * stretch) * weight
  local pose = CFrame.Angles(math.rad(motion.X), math.rad(motion.Y), math.rad(motion.Z))
  local basis = joint.C0.Rotation
  joint.Transform = basis:Inverse() * pose * basis * entry.base
 end
end)
script.Destroying:Connect(function()
 pre:Disconnect()
 post:Disconnect()
 restore()
end)
