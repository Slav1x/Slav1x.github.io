--!strict
-- The lake is visual Parts, not Terrain water. The owning client supplies
-- character buoyancy; all rock physics, skips and cash stay server-authoritative.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Water = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("WaterSurface"))
local player = Players.LocalPlayer
local root: BasePart? = nil
local humanoid: Humanoid? = nil
local force: VectorForce? = nil
local attachment: Attachment? = nil
local previous: Vector3? = nil
local swimming = false
local jumpUntil = 0
local lastSplash = -10
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.RespectCanCollide = true

local function splash(position: Vector3, impactSpeed: number)
	if os.clock() - lastSplash < 0.6 then return end
	lastSplash = os.clock()
	local anchor = Instance.new("Part")
	anchor.Name = "CharacterWaterEntry"
	anchor.Anchored = true
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
	anchor.Position = position
	anchor.Parent = workspace
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	spray.Color = ColorSequence.new(Color3.fromRGB(180, 229, 249))
	spray.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, .3), NumberSequenceKeypoint.new(1, 1)})
	spray.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, .22), NumberSequenceKeypoint.new(1, 0)})
	spray.Speed = NumberRange.new(5, math.clamp(impactSpeed * .14, 9, 19))
	spray.Acceleration = Vector3.new(0, -35, 0)
	spray.Lifetime = NumberRange.new(.25, .5)
	spray.SpreadAngle = Vector2.new(65, 65)
	spray.Rate = 0
	spray.Parent = anchor
	spray:Emit(if player:GetAttribute("ReducedMotion") then 5 else 14)
	-- A thin surface ring gives entry feedback without any camera overlay.
	local ring = Instance.new("Part")
	ring.Name = "EntryRipple"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(.025, 2, 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Anchored = true
	ring.CanCollide, ring.CanQuery, ring.CanTouch = false, false, false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(162, 218, 242)
	ring.Transparency = .8
	ring.Parent = anchor
	TweenService:Create(ring, TweenInfo.new(.5), {Size = Vector3.new(.025, 7, 7), Transparency = 1}):Play()
	Debris:AddItem(anchor, .65)
end

local function stopSwimming()
	swimming = false
	if force then force.Force = Vector3.zero end
	if humanoid then
		humanoid:SetAttribute("LakeSwimming", false)
		if humanoid:GetState() == Enum.HumanoidStateType.Swimming then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
	end
end

local function bind(character: Model)
	stopSwimming()
	if force then force:Destroy() end
	if attachment then attachment:Destroy() end
	local nextRoot = character:WaitForChild("HumanoidRootPart") :: BasePart
	local nextHumanoid = character:WaitForChild("Humanoid") :: Humanoid
	if player.Character ~= character then return end
	root, humanoid = nextRoot, nextHumanoid
	attachment = Instance.new("Attachment")
	attachment.Name = "LakeBuoyancyAttachment"
	attachment.Parent = nextRoot
	force = Instance.new("VectorForce")
	force.Name = "LakeBuoyancy"
	force.Attachment0 = attachment
	force.ApplyAtCenterOfMass = true
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.Force = Vector3.zero
	force.Parent = nextRoot
	previous = nextRoot.Position
	groundParams.FilterDescendantsInstances = {character}
	jumpUntil = 0
end

UserInputService.JumpRequest:Connect(function()
	if not swimming or not root or not humanoid or os.clock() < jumpUntil then return end
	jumpUntil = os.clock() + .45
	stopSwimming()
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, 42, v.Z)
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
end)

RunService.PreSimulation:Connect(function(dt)
	local r, hum, buoyancy = root, humanoid, force
	if not r or not r.Parent or not hum or not buoyancy then return end
	local at = r.Position
	local waterY = Water.at(at)
	local prior = previous or at
	previous = at
	if hum.Health <= 0 or r.Anchored or not waterY or os.clock() < jumpUntil then
		if swimming then stopSwimming() end
		return
	end
	local ground = workspace:Raycast(at, Vector3.new(0, -5, 0), groundParams)
	if ground and ground.Position.Y >= waterY - .25 then
		if swimming then stopSwimming() end
		return
	end
	local targetY = waterY + .65
	local velocity = r.AssemblyLinearVelocity
	if at.Y > targetY + 1.25 then
		if swimming then stopSwimming() end
		return
	end
	if not swimming then
		swimming = true
		hum:SetAttribute("LakeSwimming", true)
		splash(Vector3.new(at.X, waterY + .06, at.Z), math.max(0, -velocity.Y))
		-- Sweep recovery prevents a single large fall step bypassing buoyancy.
		if prior.Y > targetY and at.Y < waterY - .6 then
			r.CFrame += Vector3.new(0, waterY - .6 - at.Y, 0)
			at = r.Position
		end
		velocity = Vector3.new(velocity.X, math.max(velocity.Y, -12), velocity.Z)
		r.AssemblyLinearVelocity = velocity
	end
	if hum:GetState() ~= Enum.HumanoidStateType.Swimming then
		hum:ChangeState(Enum.HumanoidStateType.Swimming)
	end
	-- Critically damped buoyancy settles at the waist instead of bouncing.
	local acceleration = math.clamp((targetY - at.Y) * 64 - velocity.Y * 16, -120, 420)
	buoyancy.Force = Vector3.new(0, r.AssemblyMass * (workspace.Gravity + acceleration), 0)
end)

player.CharacterAdded:Connect(bind)
player.CharacterRemoving:Connect(function()
	stopSwimming()
	root, humanoid, previous, force, attachment = nil, nil, nil, nil, nil
end)
if player.Character then task.spawn(bind, player.Character) end
