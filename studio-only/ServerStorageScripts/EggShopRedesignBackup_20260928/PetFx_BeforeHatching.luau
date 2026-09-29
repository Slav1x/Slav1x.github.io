--!strict
--[[
	PetFx (client)

	Reusable client renderer for equipped pets. Catalog entries may point to a
	3D model with per-pet follow, flight, and VFX tuning; older pets retain the
	lightweight badge fallback. Ownership and equipment remain server-owned.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetCatalog = require(Shared:WaitForChild("PetCatalog"))
local PhoenixFlight = require(Shared:WaitForChild("PhoenixFlight"))

local ProfileStore = require(script.Parent:WaitForChild("ProfileStore"))

local PetFx = {}

local player = Players.LocalPlayer

local DEFAULT_OFFSET = Vector3.new(-3.2, 2.6, 2.6)
local DEFAULT_STIFFNESS = 6.5
local DEFAULT_MAX_CATCHUP = 32
local DEFAULT_BOB_HEIGHT = 0.35
local DEFAULT_BOB_SPEED = 2.4

local current: Model? = nil
local currentId: string? = nil
local currentPet: any = nil
local currentCFrame: CFrame? = nil
local isWorldModel = false
local wingLeft: Model? = nil
local wingRight: Model? = nil
local tailModel: Model? = nil
local wingLeftRest: CFrame? = nil
local wingRightRest: CFrame? = nil
local tailRest: CFrame? = nil
local motionSparks: ParticleEmitter? = nil
local elapsed = 0
local phoenixState: any = nil

local function buildBadge(pet): Model
	local model = Instance.new("Model")
	model.Name = "PetBadge"

	local disc = Instance.new("Part")
	disc.Name = "Body"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.25, 2.1, 2.1)
	disc.Material = Enum.Material.Neon
	disc.Color = pet.color
	disc.Transparency = 0.15
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Parent = model

	local rim = Instance.new("SelectionBox")
	rim.Adornee = disc
	rim.Color3 = Color3.fromRGB(255, 255, 255)
	rim.LineThickness = 0.035
	rim.SurfaceTransparency = 1
	rim.Parent = disc

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(90, 90)
	billboard.AlwaysOnTop = false
	billboard.Parent = disc

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.Text = pet.icon
	icon.TextSize = 46
	icon.Font = Enum.Font.GothamBold
	icon.Parent = billboard

	local light = Instance.new("PointLight")
	light.Color = pet.color
	light.Brightness = 1.4
	light.Range = 10
	light.Shadows = false
	light.Parent = disc

	model.PrimaryPart = disc
	return model
end

local function restPivot(model: Model?): CFrame?
	if not model then return nil end
	local value = model:GetAttribute("RestPivot")
	return if typeof(value) == "CFrame" then value else nil
end

local function buildWorldModel(pet): Model?
	if typeof(pet.model) ~= "string" then return nil end
	local folder = ReplicatedStorage:FindFirstChild("PetModels")
	local template = folder and folder:FindFirstChild(pet.model)
	if template and template:GetAttribute("ArticulatedPhoenix") and not template:GetAttribute("PremiumReady") then
		template = folder:FindFirstChild("SunPhoenix_LegacyFallback")
	end
	if not template or not template:IsA("Model") then
		warn("[PetFx] Missing model for pet " .. pet.id)
		return nil
	end
	local model = template:Clone()
	model.Name = pet.name .. "_Follower"
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
	return model
end

local function destroyCurrent()
	phoenixState = nil
	if current then current:Destroy() end
	current = nil
	currentId = nil
	currentPet = nil
	currentCFrame = nil
	isWorldModel = false
	wingLeft, wingRight, tailModel = nil, nil, nil
	wingLeftRest, wingRightRest, tailRest = nil, nil, nil
	motionSparks = nil
end

local function syncEquipped()
	local id = ProfileStore.get().petEquipped
	if id == currentId and current ~= nil then return end
	destroyCurrent()
	if typeof(id) ~= "string" or id == "" then return end
	local pet = PetCatalog.get(id)
	if not pet then return end

	local model = buildWorldModel(pet)
	isWorldModel = model ~= nil
	model = model or buildBadge(pet)
	current = model
	currentId = id
	currentPet = pet
	phoenixState = if model:GetAttribute("ArticulatedPhoenix") then PhoenixFlight.bind(model) else nil
	wingLeft = model:FindFirstChild("WingLeft") :: Model?
	wingRight = model:FindFirstChild("WingRight") :: Model?
	tailModel = model:FindFirstChild("Tail") :: Model?
	wingLeftRest, wingRightRest, tailRest = restPivot(wingLeft), restPivot(wingRight), restPivot(tailModel)
	motionSparks = model:FindFirstChild("MotionSparks", true) :: ParticleEmitter?
	local embers = model:FindFirstChild("WarmEmbers", true)
	if embers and embers:IsA("ParticleEmitter") then
		embers.Rate = (pet.vfx and pet.vfx.idleEmberRate) or embers.Rate
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local initial = if root and root:IsA("BasePart") then root.CFrame * CFrame.new(pet.followOffset or DEFAULT_OFFSET) else CFrame.new(0, 8, 0)
	model:PivotTo(initial)
	currentCFrame = initial
	model.Parent = workspace
end

function PetFx.start()
	local templates = ReplicatedStorage:WaitForChild("PetModels")
	templates.ChildAdded:Connect(function(template)
		if currentPet and currentPet.model == template.Name then
			destroyCurrent()
			task.defer(syncEquipped)
		end
	end)
	ProfileStore.onChanged(syncEquipped)
	syncEquipped()

	RunService.RenderStepped:Connect(function(dt)
		local model, pet = current, currentPet
		if not model or not pet or not model.PrimaryPart then return end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then return end

		elapsed += dt
		local flight = pet.flight or {}
		local offset = pet.followOffset or DEFAULT_OFFSET
		local target = root.CFrame:PointToWorldSpace(offset)
		local bob = math.sin(elapsed * (flight.hoverSpeed or DEFAULT_BOB_SPEED)) * (flight.hoverHeight or DEFAULT_BOB_HEIGHT)
		local desiredPosition = target + Vector3.new(0, bob, 0)
		local planarVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
		local facing = if planarVelocity.Magnitude > 1.2 then planarVelocity.Unit else root.CFrame.LookVector
		local desired = CFrame.lookAt(desiredPosition, desiredPosition + facing)
			* CFrame.Angles(0, math.rad(pet.modelYaw or 0), 0)
		if not isWorldModel then
			desired = CFrame.new(desiredPosition) * CFrame.Angles(0, elapsed * 1.4, math.rad(90))
		end

		local from = currentCFrame or model:GetPivot()
		local distance = (from.Position - desiredPosition).Magnitude
		local maxCatchup = flight.maxCatchupDistance or DEFAULT_MAX_CATCHUP
		local nextFrame: CFrame
		if distance > maxCatchup then
			nextFrame = desired
		else
			local stiffness = (flight.stiffness or DEFAULT_STIFFNESS) + math.min(distance * 0.22, 5)
			local alpha = 1 - math.exp(-stiffness * dt)
			nextFrame = from:Lerp(desired, alpha)
		end
		model:PivotTo(nextFrame)
		currentCFrame = nextFrame

		if isWorldModel and phoenixState then
			local camera = workspace.CurrentCamera
			local cameraDistance = if camera then (camera.CFrame.Position - nextFrame.Position).Magnitude else 0
			PhoenixFlight.update(phoenixState, dt, planarVelocity.Magnitude, cameraDistance)
		elseif isWorldModel then
			local flap = math.rad(math.sin(elapsed * (flight.wingSpeed or 4)) * (flight.wingAmplitude or 20))
			if wingLeft and wingLeftRest then wingLeft:PivotTo(nextFrame * wingLeftRest * CFrame.Angles(0, 0, flap)) end
			if wingRight and wingRightRest then wingRight:PivotTo(nextFrame * wingRightRest * CFrame.Angles(0, 0, -flap)) end
			if tailModel and tailRest then
				local sway = math.rad(math.sin(elapsed * (flight.tailSpeed or 2)) * (flight.tailAmplitude or 4))
				tailModel:PivotTo(nextFrame * tailRest * CFrame.Angles(sway, 0, 0))
			end
			if motionSparks then
				motionSparks.Rate = if planarVelocity.Magnitude > 14 then (pet.vfx and pet.vfx.catchupSparkRate or 6) else 0
			end
		end
	end)

	player.CharacterRemoving:Connect(destroyCurrent)
	player.CharacterAdded:Connect(function() task.defer(syncEquipped) end)
end

return PetFx

