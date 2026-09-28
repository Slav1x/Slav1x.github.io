--!strict
-- Client-only character presentation. It never moves the root or changes physics.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ThrowConfig = require(ReplicatedStorage.Shared.ThrowConfig)
local RockCatalog = require(ReplicatedStorage.Shared.RockCatalog)
local RockAppearance = require(ReplicatedStorage.Shared.RockAppearance)
local AbilityVisuals = require(ReplicatedStorage.Shared.AbilityVisuals)
local P = ThrowConfig.Presentation.Input
local SidearmPose = {}
local localPlayer = Players.LocalPlayer
local inspectTiers: {[string]: number} = {Common=0, Uncommon=1, Rare=2, Epic=3, Legendary=4, Mythical=5, Exclusive=5}
local inspectAccents: {[string]: Color3} = {
	Common=Color3.fromRGB(190,210,222), Uncommon=Color3.fromRGB(105,225,145),
	Rare=Color3.fromRGB(74,207,255), Epic=Color3.fromRGB(112,105,255),
	Legendary=Color3.fromRGB(255,205,67), Mythical=Color3.fromRGB(93,235,255),
}

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function rotation(v: Vector3): CFrame
	return CFrame.Angles(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
end

local function collectJoints(character: Model, poseTable)
	local joints = {}
	for _, joint in character:GetDescendants() do
		if joint:IsA("Motor6D") or joint:IsA("AnimationConstraint") then
			local key = joint.Name:gsub(" ", "")
			if poseTable[key] then
				table.insert(joints, {motor = joint, key = key, base = joint.Transform, pose = CFrame.identity})
			end
		end
	end
	return joints
end

local function makePreview(rockId: string?, variant: string?, abilityId: string?): Model?
	local models = ReplicatedStorage:FindFirstChild("RockModels")
	local template = (models and rockId and models:FindFirstChild(rockId)) or ReplicatedStorage:FindFirstChild("Pebble")
	if not template or not template:IsA("Model") then return nil end
	local rock = RockAppearance.apply(template:Clone(), rockId or RockCatalog.Default, variant)
	AbilityVisuals.attach(rock, abilityId)
	rock.Name = "IdleRockPreview"
	rock:ScaleTo(ThrowConfig.RockVisualScale)
	for _, descendant in rock:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant.Enabled = false
		end
	end
	rock.Parent = workspace
	return rock
end

function SidearmPose.begin(character: Model)
	local joints = collectJoints(character, P.Sidearm.Ready)
	local started = os.clock()
	local released: number? = nil
	local stopped = false
	local lowerBodyWeight = 1
	local lastFrame = started
	local before: RBXScriptConnection? = nil
	local after: RBXScriptConnection? = nil

	local function restore()
		for _, entry in joints do
			if entry.motor.Parent then entry.motor.Transform = entry.base end
		end
	end
	local function stop()
		if stopped then return end
		stopped = true
		if before then before:Disconnect() end
		if after then after:Disconnect() end
		restore()
	end

	before = RunService.PreAnimation:Connect(restore)
	after = RunService.PreSimulation:Connect(function()
		if not character.Parent then stop(); return end
		local now = os.clock()
		local dt = math.clamp(now - lastFrame, 0, 0.05)
		lastFrame = now
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local groundedAndStill = humanoid and humanoid.MoveDirection.Magnitude < 0.08 and humanoid.FloorMaterial ~= Enum.Material.Air
		lowerBodyWeight += ((if groundedAndStill then 1 else 0) - lowerBodyWeight) * (1 - math.exp(-14 * dt))
		local releaseAt = released
		local elapsed = if releaseAt then now - releaseAt else 0
		if releaseAt and elapsed >= P.Sidearm.SnapDuration + P.Sidearm.RecoveryDuration then
			stop(); return
		end
		for _, entry in joints do
			local joint = entry.motor
			if not joint.Parent then continue end
			entry.base = joint.Transform
			local pose
			if releaseAt then
				local finish = rotation(P.Sidearm.Finish[entry.key] or Vector3.zero)
				if elapsed < P.Sidearm.SnapDuration then
					-- Torso leads, then elbow, then wrist: a short accelerating whip.
					local delay = if entry.key == "RightWrist" then 0.018 elseif entry.key == "RightElbow" then 0.009 else 0
					local t = math.clamp((elapsed - delay) / (P.Sidearm.SnapDuration - delay), 0, 1)
					-- Fast body lead and a restrained overshoot give the pebble a clear snap.
					local whip = 1 - (1 - t) ^ 3 + 0.07 * math.sin(math.pi * t)
					pose = entry.releasePose:Lerp(finish, whip)
				else
					pose = finish:Lerp(CFrame.identity, smooth((elapsed - P.Sidearm.SnapDuration) / P.Sidearm.RecoveryDuration))
				end
			else
				local windup = smooth((now - started) / P.WindupDuration)
				pose = CFrame.identity:Lerp(rotation(P.Sidearm.Ready[entry.key]), windup)
				-- Small living motion during a long hold, with no camera or aim drift.
				if entry.key == "RightShoulder" or entry.key == "RightWrist" or entry.key == "Waist" then
					local sway = math.sin((now - started) * 3.2) * math.rad(1.2) * windup
					pose *= CFrame.Angles(sway, 0, -sway * 0.5)
				end
			end
			if entry.key == "RightHip" or entry.key == "LeftHip" or entry.key == "RightKnee" or entry.key == "LeftKnee" then
				pose = CFrame.identity:Lerp(pose, lowerBodyWeight)
			end
			entry.pose = pose
			local basis = joint.C0.Rotation
			joint.Transform = basis:Inverse() * pose * basis * entry.base
		end
	end)

	return {
		release = function()
			if stopped or released then return end
			for _, entry in joints do entry.releasePose = entry.pose end
			released = os.clock()
		end,
		cancel = stop,
	}
end

local idleVariation = setmetatable({}, {__mode = "k"})

function SidearmPose.beginIdle(character: Model, tool: Tool)
	local settings = P.Sidearm.IdleToss
	local poseKeys = table.clone(settings.Pose)
	for _, key in {"LeftShoulder", "LeftElbow", "LeftWrist", "Waist", "RightHip", "LeftHip", "RightKnee", "LeftKnee"} do poseKeys[key] = Vector3.zero end
	local joints = collectJoints(character, poseKeys)
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	local leftHand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	local variation = "SkyToss"
	local orbitDuration = 2.8
	local flipDuration = 1.35
	local stretchDuration = 3.0
	local orbitPoses = {
		{0, {}},
		{0.16, {RightShoulder=Vector3.new(-45, -12, 28), RightElbow=Vector3.new(-50,0,0), Neck=Vector3.new(0,-12,0)}},
		{0.40, {RightShoulder=Vector3.new(-20,0,12), LeftShoulder=Vector3.new(-48,15,-32), LeftElbow=Vector3.new(-45,0,0), Neck=Vector3.new(0,18,0), Waist=Vector3.new(0,10,0)}},
		{0.54, {LeftShoulder=Vector3.new(-30,0,-22), LeftElbow=Vector3.new(-35,0,0), LeftWrist=Vector3.new(0,0,18), Neck=Vector3.new(0,16,0)}},
		{0.68, {LeftShoulder=Vector3.new(-48,12,-32), LeftElbow=Vector3.new(-50,0,0), Neck=Vector3.new(0,10,0)}},
		{0.90, {RightShoulder=Vector3.new(-42,-12,26), RightElbow=Vector3.new(-45,0,0), Neck=Vector3.new(0,-12,0), Waist=Vector3.new(0,-8,0)}},
		{1, {}},
	}
	local flipPoses = {
		{0, {}},
		{0.18, {RightShoulder=Vector3.new(-14,-10,20), RightElbow=Vector3.new(-30,0,0), RightWrist=Vector3.new(28,0,-12), Neck=Vector3.new(0,-8,0)}},
		{0.40, {RightShoulder=Vector3.new(-32,-12,38), RightElbow=Vector3.new(-54,0,0), RightWrist=Vector3.new(-42,0,14), Neck=Vector3.new(-8,-14,0)}},
		{0.70, {RightShoulder=Vector3.new(-24,6,22), RightElbow=Vector3.new(-24,0,0), RightWrist=Vector3.new(42,0,-10), Neck=Vector3.new(4,10,0)}},
		{1, {}},
	}
	local stretchPoses = {
		ShoulderStretch = {
			{0, {}}, {0.27, {Waist=Vector3.new(-4,0,2), Neck=Vector3.new(6,0,-2),
				LeftShoulder=Vector3.new(-33,7,-16), LeftElbow=Vector3.new(-14,0,0), RightShoulder=Vector3.new(-9,0,6)}},
			{0.65, {Waist=Vector3.new(-3,0,-2), Neck=Vector3.new(5,0,2),
				LeftShoulder=Vector3.new(-22,-4,-10), LeftElbow=Vector3.new(-12,0,0)}}, {1, {}},
		},
		SideStretch = {
			{0, {}}, {0.3, {Waist=Vector3.new(0,-4,7), Neck=Vector3.new(2,3,-5),
				LeftShoulder=Vector3.new(-16,0,-10), RightHip=Vector3.new(-3,0,0), LeftHip=Vector3.new(4,0,0)}},
			{0.65, {Waist=Vector3.new(0,4,-7), Neck=Vector3.new(2,-3,5),
				LeftShoulder=Vector3.new(-8,0,5), RightHip=Vector3.new(4,0,0), LeftHip=Vector3.new(-3,0,0)}}, {1, {}},
		},
		LegStretch = {
			{0, {}}, {0.35, {Waist=Vector3.new(2,0,-4), Neck=Vector3.new(-2,0,2),
				RightHip=Vector3.new(-7,0,0), RightKnee=Vector3.new(8,0,0), LeftHip=Vector3.new(4,0,0)}},
			{0.7, {Waist=Vector3.new(2,0,4), Neck=Vector3.new(-2,0,-2),
				LeftHip=Vector3.new(-7,0,0), LeftKnee=Vector3.new(8,0,0), RightHip=Vector3.new(4,0,0)}}, {1, {}},
		},
	}
	local function sequencePose(poses, key, p)
		for i=2,#poses do
			local a,b=poses[i-1],poses[i]
			if p <= b[1] then
				return (a[2][key] or Vector3.zero):Lerp(b[2][key] or Vector3.zero, smooth((p-a[1])/(b[1]-a[1])))
			end
		end
		return Vector3.zero
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local visual = tool:FindFirstChild("RockVisual")
	local stone = visual and (visual:FindFirstChild("Stone") or visual:FindFirstChildWhichIsA("BasePart", true))
	local hiddenParts = {}
	local preview: Model? = nil
	local started: number? = nil
	local launchFrame: CFrame? = nil
	local nextTossAt = os.clock() + math.random(5, 7)
	local stopped = false
	local connections = {}
	local windup, flight, catchTime = 0.32, 1.25, 0.32

	local function clearPreview()
		for part, transparency in hiddenParts do
			if part.Parent then part.LocalTransparencyModifier = transparency end
		end
		table.clear(hiddenParts)
		if preview then preview:Destroy(); preview = nil end
		launchFrame = nil
	end
	local function restore()
		for _, entry in joints do
			if entry.motor.Parent then entry.motor.Transform = entry.base end
		end
	end
	local function stop()
		if stopped then return end
		stopped = true
		for _, connection in connections do connection:Disconnect() end
		restore()
		clearPreview()
	end
	table.insert(connections, RunService.PreAnimation:Connect(restore))
	table.insert(connections, RunService.PreSimulation:Connect(function()
		if not character.Parent or tool.Parent ~= character or not stone or not stone.Parent
			or not humanoid or humanoid.Health <= 0 then stop(); return end
		local now = os.clock()
		local reduced = localPlayer:GetAttribute("ReducedMotion") == true
		local moving = humanoid.MoveDirection.Magnitude > 0.1 or humanoid.FloorMaterial == Enum.Material.Air or reduced
		if moving then
			started = nil
			nextTossAt = now + 1
			clearPreview()
		elseif not started and now >= nextTossAt then
			started = now
			local choice = math.random(1, 5)
			if choice <= 3 then
				variation = ({"ShoulderStretch", "SideStretch", "LegStretch"})[choice]
			else
				local previous = idleVariation[character]
				variation = if previous == "SkyToss" and root and head and leftHand then "AroundTheWorld"
					elseif previous == "SkyToss" or previous == "AroundTheWorld" then "PalmFlip"
					else "SkyToss"
				idleVariation[character] = variation
			end
		end
		local elapsed = if started then now - started else 0
		local lift = 0
		if started then
			if elapsed < windup then
				lift = -0.35 * math.sin(math.pi * elapsed / windup)
			elseif elapsed < windup + flight then
				local p = (elapsed - windup) / flight
				lift = math.sin(math.pi * math.min(p * 3, 1)) * 0.65 + math.sin(math.pi * p) * 0.35
			else
				lift = -0.28 * math.sin(math.pi * math.clamp((elapsed-windup-flight)/catchTime, 0, 1))
			end
		end
		for _, entry in joints do
			local joint = entry.motor
			if not joint.Parent then continue end
			entry.base = joint.Transform
			local angles = if stretchPoses[variation] and started
				then sequencePose(stretchPoses[variation], entry.key, math.clamp(elapsed / stretchDuration, 0, 1))
				elseif variation == "AroundTheWorld" and started
				then sequencePose(orbitPoses, entry.key, math.clamp(elapsed / orbitDuration, 0, 1))
				elseif variation == "PalmFlip" and started
				then sequencePose(flipPoses, entry.key, math.clamp(elapsed / flipDuration, 0, 1))
				else (settings.Pose[entry.key] or Vector3.zero) * lift
			-- Breathing persists between special idles and remains tiny during them.
			local breath = if reduced then 0 else math.sin(now * 1.65)
			if entry.key == "Waist" then angles += Vector3.new(1.25 * breath, 0, 0.4 * breath)
			elseif entry.key == "Neck" then angles += Vector3.new(-0.8 * breath, 0, 0)
			elseif entry.key == "LeftShoulder" or entry.key == "RightShoulder" then angles += Vector3.new(0.45 * breath, 0, 0)
			elseif entry.key == "RightHip" then angles += Vector3.new(-0.3 * breath, 0, 0)
			elseif entry.key == "LeftHip" then angles += Vector3.new(0.3 * breath, 0, 0) end
			local pose = rotation(angles)
			local basis = joint.C0.Rotation
			joint.Transform = basis:Inverse() * pose * basis * entry.base
		end
		local duration = if stretchPoses[variation] then stretchDuration
			elseif variation == "AroundTheWorld" then orbitDuration
			elseif variation == "PalmFlip" then flipDuration else windup + flight + catchTime
		if started and elapsed >= duration then
			started = nil
			nextTossAt = now + 1
			clearPreview()
		end
	end))
	-- Render after the character joints have moved, so launch and catch meet the palm.
	table.insert(connections, RunService.RenderStepped:Connect(function()
		if stopped or not started or not stone or not stone.Parent or stretchPoses[variation] then return end
		local elapsed = os.clock() - started
		if variation == "SkyToss" then
			if elapsed < windup then return end
			if elapsed >= windup + flight then clearPreview(); return end
		end
		if not preview then
			preview = makePreview(tool:GetAttribute("RockId"), tool:GetAttribute("Variant"), tool:GetAttribute("AbilityId"))
			if not preview then return end
			launchFrame = stone.CFrame
			preview:SetAttribute("IdleVariation", variation)
			for _, part in tool:GetDescendants() do
				if part:IsA("BasePart") then
					hiddenParts[part] = part.LocalTransparencyModifier
					part.LocalTransparencyModifier = 1
				end
			end
		end
		if preview and launchFrame then
			if variation == "PalmFlip" then
				local p = math.clamp(elapsed / flipDuration, 0, 1)
				local wave = math.sin(math.pi * p)
				local forward = if root then root.CFrame.LookVector else launchFrame.LookVector
				local right = if root then root.CFrame.RightVector else launchFrame.RightVector
				local position = launchFrame.Position:Lerp(stone.Position, smooth(p))
					+ Vector3.new(0, wave * 0.95, 0) + forward * (wave * 0.45)
					+ right * (math.sin(math.pi * 2 * p) * 0.16)
				local orientation = launchFrame.Rotation:Lerp(stone.CFrame.Rotation, smooth(p))
				preview:PivotTo(CFrame.new(position) * orientation
					* CFrame.Angles(math.pi * 4 * smooth(p), 0, wave * 0.35))
				preview:SetAttribute("IdleProgress", p)
				return
			end
			if variation == "AroundTheWorld" and root and head and leftHand then
				local p = math.clamp(elapsed / orbitDuration, 0, 1)
				-- Orbit outside the shoulders, with a visible left-palm catch halfway.
				local neck = Vector3.new(root.Position.X, head.Position.Y - head.Size.Y * 0.4, root.Position.Z)
				local frame = CFrame.new(neck) * root.CFrame.Rotation
				local radius = math.max(1.65, head.Size.X * 0.5 + 0.95)
				local right = frame:PointToWorldSpace(Vector3.new(radius,0,0))
				local left = frame:PointToWorldSpace(Vector3.new(-radius,0,0))
				local palm = leftHand.CFrame:PointToWorldSpace(Vector3.new(0,-leftHand.Size.Y*0.5,-0.25))
				local position
				if p < 0.16 then
					position = launchFrame.Position:Lerp(right,smooth(p/0.16))
				elseif p < 0.40 then
					local angle = math.pi * smooth((p-0.16)/0.24)
					position = frame:PointToWorldSpace(Vector3.new(radius*math.cos(angle),0.12*math.sin(angle),radius*math.sin(angle)))
				elseif p < 0.50 then
					position = left:Lerp(palm,smooth((p-0.40)/0.10))
				elseif p < 0.58 then
					position = palm
				elseif p < 0.68 then
					position = palm:Lerp(left,smooth((p-0.58)/0.10))
				elseif p < 0.90 then
					local angle = math.pi + math.pi * smooth((p-0.68)/0.22)
					position = frame:PointToWorldSpace(Vector3.new(radius*math.cos(angle),0.12*math.sin(angle-math.pi),radius*math.sin(angle)))
				else
					position = right:Lerp(stone.Position,smooth((p-0.90)/0.10))
				end
				local spin = math.pi * 4 * smooth(p)
				local orientation = launchFrame.Rotation:Lerp(stone.CFrame.Rotation,smooth(p))
				preview:PivotTo(CFrame.new(position) * orientation * CFrame.Angles(0,spin,0))
				preview:SetAttribute("IdleProgress", p)
				return
			end
			local p = math.clamp((elapsed - windup) / flight, 0, 1)
			local catchFrame = stone.CFrame
			local centre = launchFrame.Position:Lerp(catchFrame.Position, p)
				+ Vector3.new(0, 4 * p * (1-p) * 5.5, 0)
			local orientation = launchFrame.Rotation:Lerp(catchFrame.Rotation, smooth(p))
			preview:PivotTo(CFrame.new(centre) * orientation
				* CFrame.Angles(math.pi * 4 * p, math.pi * 2 * p, 0))
		end
	end))
	return {cancel = stop}
end

function SidearmPose.beginInspect(character: Model, tool: Tool, onComplete: () -> ())
	local visual = tool:FindFirstChild("RockVisual")
	local stone = visual and (visual:FindFirstChild("Stone") or visual:FindFirstChildWhichIsA("BasePart", true))
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not stone or not stone:IsA("BasePart") or not humanoid then return nil end
	local rockId = tool:GetAttribute("RockId")
	local rock = RockCatalog.get(if typeof(rockId) == "string" then rockId else nil)
	local tier = inspectTiers[rock.rarity] or 0
	local accent = if rock.rarity == "Exclusive" then rock.color else inspectAccents[rock.rarity] or inspectAccents.Common
	local effects: {Instance} = {}
	local nameplate = Instance.new("ScreenGui")
	nameplate.Name = "InspectNameplate"
	nameplate.IgnoreGuiInset = true
	nameplate.DisplayOrder = 12
	nameplate.ResetOnSpawn = false
	nameplate.Enabled = false
	nameplate.Parent = localPlayer:WaitForChild("PlayerGui")
	table.insert(effects, nameplate)
	local plate = Instance.new("Frame")
	plate.Size = UDim2.fromOffset(196, 54)
	plate.AnchorPoint = Vector2.new(0.5, 1)
	plate.BackgroundColor3 = Color3.fromRGB(0, 112, 222)
	plate.BorderSizePixel = 0
	plate.Parent = nameplate
	Instance.new("UICorner", plate).CornerRadius = UDim.new(0, 12)
	local plateGradient = Instance.new("UIGradient")
	plateGradient.Rotation = 90
	plateGradient.Color = ColorSequence.new(Color3.fromRGB(0, 119, 232), Color3.fromRGB(0, 70, 158))
	plateGradient.Parent = plate
	local border = Instance.new("UIStroke")
	border.Color = Color3.fromRGB(20, 37, 55)
	border.Thickness = 3
	border.Parent = plate
	local nameText = Instance.new("TextLabel")
	nameText.Position = UDim2.fromOffset(8, 5)
	nameText.Size = UDim2.new(1, -16, 0, 27)
	nameText.BackgroundTransparency = 1
	nameText.Font = Enum.Font.GothamBlack
	nameText.TextScaled = true
	nameText.Text = string.upper(rock.name)
	nameText.TextColor3 = Color3.new(1, 1, 1)
	nameText.TextStrokeColor3 = Color3.fromRGB(20, 37, 55)
	nameText.TextStrokeTransparency = 0
	nameText.Parent = plate
	local nameFit = Instance.new("UITextSizeConstraint")
	nameFit.MinTextSize = 10
	nameFit.MaxTextSize = 19
	nameFit.Parent = nameText
	local rarityText = Instance.new("TextLabel")
	rarityText.Position = UDim2.fromOffset(8, 31)
	rarityText.Size = UDim2.new(1, -16, 0, 16)
	rarityText.BackgroundTransparency = 1
	rarityText.Font = Enum.Font.GothamBold
	rarityText.TextSize = 12
	rarityText.Text = string.upper(rock.rarity)
	rarityText.TextColor3 = accent
	rarityText.TextStrokeColor3 = Color3.fromRGB(20, 37, 55)
	rarityText.TextStrokeTransparency = 0
	rarityText.Parent = plate
	local accentBar = Instance.new("Frame")
	accentBar.Position = UDim2.new(0, 8, 1, -5)
	accentBar.Size = UDim2.new(1, -16, 0, 3)
	accentBar.BackgroundColor3 = accent
	accentBar.BorderSizePixel = 0
	accentBar.Parent = plate
	Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 2)

	local reducedEffects = localPlayer:GetAttribute("ReducedThrowFlashes") == true or localPlayer:GetAttribute("ReducedMotion") == true
	local highlight: Highlight? = nil
	local glow: PointLight? = nil
	local orbit: Attachment? = nil
	local function motes(parent: Attachment, rate: number, first: Color3, last: Color3): ParticleEmitter
		local particles = Instance.new("ParticleEmitter")
		particles.Name = "InspectMotes"
		particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		particles.Color = ColorSequence.new(first, last)
		particles.LightEmission = 0.85
		particles.Rate = rate
		particles.Lifetime = NumberRange.new(0.35, 0.7)
		particles.Speed = NumberRange.new(0.5, 1.8)
		particles.Drag = 2
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0)})
		particles.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.08), NumberSequenceKeypoint.new(1, 1)})
		particles.Parent = parent
		return particles
	end
	if tier >= 2 and not reducedEffects then
		highlight = Instance.new("Highlight")
		highlight.Name = "InspectOutline"
		highlight.Adornee = visual
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.FillTransparency = 1
		highlight.OutlineColor = accent
		highlight.OutlineTransparency = 0.35
		highlight.Parent = visual
		table.insert(effects, highlight)
		local centre = Instance.new("Attachment")
		centre.Name = "InspectSparkCenter"
		centre.Parent = stone
		table.insert(effects, centre)
		local rate = if tier == 2 then 4 elseif tier == 3 then 10 elseif tier == 4 then 17 else 24
		local particles = motes(centre, rate, accent, Color3.new(1, 1, 1))
		particles:Emit(tier * 2)
		if tier >= 4 then
			glow = Instance.new("PointLight")
			glow.Name = "InspectGlow"
			glow.Color = accent
			glow.Range = if tier >= 5 then 8 else 6
			glow.Brightness = 0.8
			glow.Shadows = false
			glow.Parent = stone
			table.insert(effects, glow)
		end
		if tier >= 5 then
			orbit = Instance.new("Attachment")
			orbit.Name = "InspectOrbit"
			orbit.Parent = stone
			table.insert(effects, orbit)
			motes(orbit, 18, Color3.fromRGB(124, 234, 255), accent):Emit(8)
		end
	end

	-- Keep the equipped rock attached to the hand. Only the arm, wrist, and
	-- character's glance move, so inspection cannot drift away from the palm.
	local joints = collectJoints(character, {
		RightShoulder = true, RightElbow = true, RightWrist = true,
		Neck = true, Waist = true,
	})
	local keyframes = {
		{0, {}},
		{0.17, {RightShoulder=Vector3.new(-32,-12,44), RightElbow=Vector3.new(-32,0,0), RightWrist=Vector3.new(6,0,-12), Neck=Vector3.new(-5,12,0)}},
		{0.37, {RightShoulder=Vector3.new(-38,-12,46), RightElbow=Vector3.new(-36,0,0), RightWrist=Vector3.new(4,48,-16), Neck=Vector3.new(-9,15,0), Waist=Vector3.new(0,5,0)}},
		{0.58, {RightShoulder=Vector3.new(-36,-8,46), RightElbow=Vector3.new(-32,0,0), RightWrist=Vector3.new(8,-38,13), Neck=Vector3.new(-8,13,0), Waist=Vector3.new(0,4,0)}},
		{0.78, {RightShoulder=Vector3.new(-31,-10,43), RightElbow=Vector3.new(-30,0,0), RightWrist=Vector3.new(3,24,-8), Neck=Vector3.new(-4,8,0)}},
		{1, {}},
	}
	local function poseAt(key: string, progress: number): Vector3
		for i=2,#keyframes do
			local a,b = keyframes[i-1], keyframes[i]
			if progress <= b[1] then
				local t = smooth((progress-a[1])/(b[1]-a[1]))
				return (a[2][key] or Vector3.zero):Lerp(b[2][key] or Vector3.zero,t)
			end
		end
		return Vector3.zero
	end
	local started = os.clock()
	local duration = 2.2
	local stopped = false
	local connections = {}
	tool:SetAttribute("InspectingRock", true)
	local function stop(completed: boolean)
		if stopped then return end
		stopped = true
		for _, connection in connections do connection:Disconnect() end
		for _, effect in effects do effect:Destroy() end
		for _, entry in joints do
			if entry.motor.Parent then entry.motor.Transform = entry.base end
		end
		if tool.Parent then tool:SetAttribute("InspectingRock", false) end
		if completed then task.defer(onComplete) end
	end
	table.insert(connections, RunService.PreAnimation:Connect(function()
		for _, entry in joints do
			if entry.motor.Parent then entry.motor.Transform = entry.base end
		end
	end))
	table.insert(connections, RunService.PreSimulation:Connect(function()
		if not character.Parent or tool.Parent ~= character or not stone.Parent or humanoid.Health <= 0
			or humanoid.MoveDirection.Magnitude > 0.1 or humanoid.FloorMaterial == Enum.Material.Air then
			stop(true)
			return
		end
		local progress = (os.clock()-started)/duration
		if progress >= 1 then stop(true); return end
		local camera = workspace.CurrentCamera
		if camera then
			local position, visible = camera:WorldToViewportPoint(stone.Position + Vector3.new(0, 1.75, 0))
			nameplate.Enabled = visible and position.Z > 0 and progress > 0.10 and progress < 0.92
			plate.Position = UDim2.fromOffset(position.X, position.Y)
		end
		if highlight then
			highlight.OutlineTransparency = 0.46 - 0.22 * math.sin(progress * math.pi) ^ 2
		end
		if glow then
			glow.Brightness = 0.75 + 0.5 * math.sin(progress * math.pi) ^ 2
		end
		if orbit then
			local radius = math.max(stone.Size.X, stone.Size.Z) * 0.56
			local angle = (os.clock() - started) * 7
			orbit.Position = Vector3.new(math.cos(angle) * radius, 0.2 + 0.16 * math.sin(angle * 1.5), math.sin(angle) * radius)
		end
		for _, entry in joints do
			local joint = entry.motor
			if not joint.Parent then continue end
			entry.base = joint.Transform
			local pose = rotation(poseAt(entry.key,progress))
			local basis = joint.C0.Rotation
			joint.Transform = basis:Inverse() * pose * basis * entry.base
		end
	end))
	return {cancel = function() stop(false) end}
end

return SidearmPose
