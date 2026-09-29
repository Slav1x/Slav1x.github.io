--!strict
--[[
	TutorialFx (client)

	Feedback for tutorial milestones, reusing the game's own UI sound set
	(SharedUI.UISounds) and sparkle texture so it matches the rest of the
	game. Camera feedback is a tiny FOV breath, never shake, and is skipped
	during a charge/flight (ThrowFx owns the camera then) or with Reduced
	Motion on.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UISounds = require(ReplicatedStorage:WaitForChild("SharedUI"):WaitForChild("UISounds"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TutorialConfig"))
local C = Config.Colors

local player = Players.LocalPlayer

local Fx = {}

local function reducedMotion(): boolean
	return player:GetAttribute("ReducedMotion") == true
end

-- Plays a UI sound at a custom pitch without disturbing the shared instance.
local function pitched(name: string, speed: number, volume: number?)
	local group = SoundService:FindFirstChild("SFX")
	local source = group and group:FindFirstChild(name)
	if not source or not source:IsA("Sound") then return end
	local sound = source:Clone()
	sound.PlaybackSpeed = speed
	sound.Volume = (volume or 1) * source.Volume
	sound.Parent = group
	sound:Play()
	Debris:AddItem(sound, 4)
end

function Fx.appear()
	pitched("UI_Menu_Open", 1.15, .7)
end

function Fx.step()
	UISounds.play("Success")
end

function Fx.milestone()
	UISounds.play("Success")
	task.delay(.12, function() pitched("SFX_Reward_Claimed", 1.26, .8) end)
	task.delay(.26, function() pitched("SFX_Reward_Claimed", 1.5, .6) end)
end

function Fx.click()
	UISounds.play("Click")
end

local function busyCamera(): boolean
	return player:GetAttribute("RockInFlight") == true or player:GetAttribute("NoobDialogueOpen") == true
end

-- Brief FOV "breath" for the big moments.
function Fx.cameraPunch(amount: number?)
	if reducedMotion() or busyCamera() then return end
	local camera = workspace.CurrentCamera
	if not camera or camera.CameraType ~= Enum.CameraType.Custom then return end
	local base = camera.FieldOfView
	local peak = base + (amount or 4)
	local out = TweenService:Create(camera, TweenInfo.new(.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = peak})
	out:Play()
	out.Completed:Once(function()
		if math.abs(camera.FieldOfView - peak) < .5 then
			TweenService:Create(camera, TweenInfo.new(.45, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {FieldOfView = base}):Play()
		end
	end)
end

-- Sparkle burst + shock ring around the character, like other milestones.
function Fx.worldBurst(color: Color3?, size: number?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	local tint = color or C.Gold
	local folder = workspace:FindFirstChild("TutorialGuides") or workspace
	local emitterPart = Instance.new("Part")
	emitterPart.Name = "TutorialBurst"
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.one
	emitterPart.Position = root.Position
	emitterPart.Parent = folder
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(tint)
	emitter.LightEmission = .8
	emitter.Lifetime = NumberRange.new(.6, 1.2)
	emitter.Speed = NumberRange.new(10, 22)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, .35), NumberSequenceKeypoint.new(1, 0)})
	emitter.Parent = emitterPart
	emitter:Emit(if reducedMotion() then 10 else 34)
	Debris:AddItem(emitterPart, 2)

	if reducedMotion() then return end
	local ring = Instance.new("Part")
	ring.Name = "TutorialRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = tint
	ring.Transparency = .3
	ring.Size = Vector3.new(.12, 1, 1)
	ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = folder
	local diameter = size or 22
	TweenService:Create(ring, TweenInfo.new(.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = Vector3.new(.08, diameter, diameter), Transparency = 1}):Play()
	Debris:AddItem(ring, .8)
end

return Fx
