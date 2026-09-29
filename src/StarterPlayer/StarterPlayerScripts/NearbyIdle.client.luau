--!nonstrict
-- Subtle local presentation of nearby players' unarmed idle motion.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local states = {}
local allowed = {
 Root = true, RootJoint = true, Waist = true, Neck = true,
 RightShoulder = true, LeftShoulder = true, RightElbow = true, LeftElbow = true,
 RightHip = true, LeftHip = true, RightKnee = true, LeftKnee = true,
}
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

local function setup(player, character)
 local humanoid = character:WaitForChild("Humanoid", 10)
 local rootPart = character:WaitForChild("HumanoidRootPart", 10)
 if not humanoid or not rootPart then return end
 -- Nearby idles also leave arms to the character's movement animations.
 local joints = {}
 for _, joint in character:GetDescendants() do
  if (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) and allowed[joint.Name:gsub(" ", "")] then
   table.insert(joints, {motor = joint, key = joint.Name:gsub(" ", ""), base = joint.Transform})
  end
 end
 states[player] = {character = character, humanoid = humanoid, joints = joints,
  weight = 0, stillFor = 0, nextStretch = math.random(5, 9),
  stretchStart = nil, stretchKind = 1}
end
local function clearState(player)
 local state = states[player]
 if not state then return end
 for _, entry in state.joints do
  if entry.motor.Parent then entry.motor.Transform = entry.base end
 end
 states[player] = nil
end
local connections = {}
local function track(player)
 if player == localPlayer then return end
 connections[player] = player.CharacterAdded:Connect(function(character)
  clearState(player)
  task.spawn(setup, player, character)
 end)
 if player.Character then task.spawn(setup, player, player.Character) end
end
for _, player in Players:GetPlayers() do track(player) end
local added = Players.PlayerAdded:Connect(track)
local removed = Players.PlayerRemoving:Connect(function(player)
 clearState(player)
 if connections[player] then connections[player]:Disconnect(); connections[player] = nil end
end)
local pre = RunService.PreAnimation:Connect(function()
 for player, state in states do
  for _, entry in state.joints do
   if entry.motor.Parent then entry.motor.Transform = entry.base end
  end
 end
end)
local last = os.clock()
local post = RunService.PreSimulation:Connect(function()
 local now = os.clock()
 local dt = math.clamp(now - last, 0, 0.05)
 last = now
 local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
 for player, state in states do
  local character = state.character
  local humanoid = state.humanoid
  if not character.Parent or humanoid.Health <= 0 then clearState(player); continue end
  local otherRoot = character:FindFirstChild("HumanoidRootPart")
  local near = root and otherRoot and (root.Position - otherRoot.Position).Magnitude < 95
  local idle = localPlayer:GetAttribute("ReducedMotion") ~= true and near
   and not character:FindFirstChildWhichIsA("Tool")
   and Vector3.new(otherRoot.AssemblyLinearVelocity.X, 0, otherRoot.AssemblyLinearVelocity.Z).Magnitude < 1.2
   and humanoid.FloorMaterial ~= Enum.Material.Air and not humanoid.Sit
  state.weight += ((if idle then 1 else 0) - state.weight) * (1 - math.exp(-6 * dt))
  if idle then
   state.stillFor += dt
   if not state.stretchStart and state.stillFor > state.nextStretch then
    state.stretchStart = now
    state.stretchKind = math.random(1, 4)
   end
  else
   state.stillFor = 0
   state.stretchStart = nil
   state.nextStretch = math.random(5, 9)
  end
  local stretch = 0
  if state.stretchStart then
   local t = (now - state.stretchStart) / 2.7
   if t >= 1 then
    state.stretchStart = nil
    state.stillFor = 0
    state.nextStretch = math.random(6, 10)
   else
    stretch = math.sin(math.pi * smooth(t)) ^ 2
   end
  end
  local breath = math.sin(now * 1.65 + player.UserId % 17)
  for _, entry in state.joints do
   local joint = entry.motor
   if not joint.Parent then continue end
   entry.base = joint.Transform
   if state.weight < 0.002 then continue end
   local key = entry.key
   if not idle and (key == "LeftShoulder" or key == "LeftElbow" or key == "RightShoulder" or key == "RightElbow") then continue end
   local motion = Vector3.zero
   if key == "Waist" or key == "RootJoint" then motion = angles(1.25 * breath, 0, 0.5 * breath)
   elseif key == "Neck" then motion = angles(-0.8 * breath)
   elseif key == "RightShoulder" then motion = angles(0.5 * breath, 0, 0.4 * breath)
   elseif key == "LeftShoulder" then motion = angles(0.5 * breath, 0, -0.4 * breath)
   elseif key == "RightHip" then motion = angles(-0.35 * breath)
   elseif key == "LeftHip" then motion = angles(0.35 * breath) end
   motion = (motion + stretchPose(state.stretchKind, key) * stretch) * state.weight
   local pose = CFrame.Angles(math.rad(motion.X), math.rad(motion.Y), math.rad(motion.Z))
   local basis = joint.C0.Rotation
   joint.Transform = basis:Inverse() * pose * basis * entry.base
  end
 end
end)
script.Destroying:Connect(function()
 pre:Disconnect()
 post:Disconnect()
 added:Disconnect()
 removed:Disconnect()
 for _, connection in connections do connection:Disconnect() end
 for _, state in states do
  for _, entry in state.joints do
   if entry.motor.Parent then entry.motor.Transform = entry.base end
  end
 end
end)
