--!strict
--[[
	WorldSetup (server)

	Uses the placed water geometry and gives each player one real rock tool that
	mirrors their server-selected inventory rock. The tool is also the
	authoritative "rock held out" state used by ThrowService.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ThrowConfig = require(Shared:WaitForChild("ThrowConfig"))
local RockCatalog = require(Shared:WaitForChild("RockCatalog"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local RockAppearance = require(Shared:WaitForChild("RockAppearance"))
local AbilityVisuals = require(Shared:WaitForChild("AbilityVisuals"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local WorldSetup = {}

local ROCK_TOOL_ATTRIBUTE = "IsRockTool"

local function setupCollisionGroups()
	for _, name in {ThrowConfig.PebbleCollisionGroup, ThrowConfig.WaterCollisionGroup, "ShoreBarrier"} do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(
		ThrowConfig.PebbleCollisionGroup,
		ThrowConfig.WaterCollisionGroup,
		false
	)
end

-- Player barriers keep the shore safe without blocking throws or launch raycasts.
local function configureShoreSafety()
	PhysicsService:CollisionGroupSetCollidable(ThrowConfig.PebbleCollisionGroup, "ShoreBarrier", false)
	PhysicsService:CollisionGroupSetCollidable(ThrowConfig.WaterCollisionGroup, "ShoreBarrier", false)
end

local function getLake()
	local WaterSurface = require(Shared:WaitForChild("WaterSurface"))
	local water = WaterSurface.getPrimary()
	if not water then warn("WorldSetup: add a physical part tagged SkippingWater to the lake") end
	return water
end

local function rockToolIn(container: Instance?): Tool?
	if not container then return nil end
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and (child:GetAttribute(ROCK_TOOL_ATTRIBUTE) == true or child.Name == "Dev Rock") then
			return child
		end
	end
	return nil
end

local function currentRockTool(player: Player): Tool?
	return rockToolIn(player.Character) or rockToolIn(player:FindFirstChildOfClass("Backpack"))
end

local function removeRockTools(player: Player)
	while true do
		local tool = currentRockTool(player)
		if not tool then break end
		tool:Destroy()
	end
end

local function createRockTool(rockId: string, variant: string, abilityId: string?): Tool
	local rock = RockCatalog.get(rockId)
	local tool = Instance.new("Tool")
	tool.Name = (variant == "Enchanted" and "Enchanted " or "") .. rock.name
	tool.ToolTip = rock.name .. " — equip to throw, R to inspect"
	tool.TextureId = rock.image or ""
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute(ROCK_TOOL_ATTRIBUTE, true)
	tool:SetAttribute("RockId", rock.id)
	tool:SetAttribute("Variant", variant)
	tool:SetAttribute("AbilityId", abilityId)
	tool:SetAttribute("RockImage", rock.image or "")
	tool:SetAttribute("RockDisplayName", rock.name)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.2, 0.2, 0.2)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Parent = tool

	local models = ReplicatedStorage:FindFirstChild("RockModels")
	local template = (models and models:FindFirstChild(rock.id)) or ReplicatedStorage:FindFirstChild("Pebble")
	if template and template:IsA("Model") then
		local visual = RockAppearance.apply(template:Clone(), rock.id, variant)
		visual.Name = "RockVisual"
		AbilityVisuals.attach(visual, abilityId)
		visual:ScaleTo(ThrowConfig.RockVisualScale)
		visual:PivotTo(CFrame.identity)
		for _, descendant in visual:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = false
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
				descendant.Massless = true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = descendant
				weld.Parent = descendant
			elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
				descendant.Enabled = false
			end
		end
		visual.Parent = tool
	end

	-- Lift the enlarged stone above the palm instead of burying its centre in the hand.
	tool.Grip = CFrame.new(0, -0.65, -0.65) * CFrame.Angles(0, 0, math.rad(8))
	return tool
end

local function syncRockTool(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end

	local profile = Profiles.get(player)
	if not profile.loaded or not next(profile.rocksOwned) then removeRockTools(player); return end
	local rockId = profile.rockEquipped
	local variant = Profiles.equippedVariant(profile)
	local abilityId = profile.abilityEquipped
	local existing = currentRockTool(player)
	if existing and existing:GetAttribute(ROCK_TOOL_ATTRIBUTE) == true
		and existing:GetAttribute("RockId") == rockId
		and existing:GetAttribute("Variant") == variant
		and existing:GetAttribute("AbilityId") == abilityId
	then
		return
	end

	local wasHeld = existing ~= nil and player.Character ~= nil and existing.Parent == player.Character
	removeRockTools(player)

	local tool = createRockTool(rockId, variant, abilityId)
	tool.Parent = backpack
	if (wasHeld or (profile.starterRockClaimed and profile.totalThrows == 0)) and player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid:EquipTool(tool) end
	end
end

local function createStarterRock()
	if workspace:FindFirstChild("StarterRiverRock") then return end
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local base = spawn and spawn.Position or Vector3.new(-609, 15.5, -36.75)
	-- The pickup sits on the sand beside the first water entry, away from the path.
	local pickupPosition = Vector3.new(base.X + 86, 16.05, base.Z - 25)
	local model = Instance.new("Model")
	model.Name = "StarterRiverRock"
	model.Parent = workspace

	local anchor = Instance.new("Part")
	anchor.Name = "PickupAnchor"
	anchor.Size = Vector3.new(3.5, 2.2, 3.5)
	anchor.CFrame = CFrame.new(pickupPosition)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Parent = model

	local templates = ReplicatedStorage:FindFirstChild("RockModels")
	local template = templates and templates:FindFirstChild(RockCatalog.Default)
	if template and template:IsA("Model") then
		local visual = template:Clone()
		visual.Name = "RiverRockVisual"
		visual:PivotTo(CFrame.new(pickupPosition + Vector3.new(0, 0.25, 0)))
		for _, descendant in visual:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
				descendant.CastShadow = false
			end
		end
		visual.Parent = model
		local highlight = Instance.new("Highlight")
		highlight.Name = "StarterRockGlow"
		highlight.Adornee = visual
		highlight.FillColor = Color3.fromRGB(255, 222, 95)
		highlight.FillTransparency = 0.78
		highlight.OutlineColor = Color3.fromRGB(255, 244, 160)
		highlight.OutlineTransparency = 0.05
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = model
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickUpRiverRock"
	prompt.ActionText = "Pick Up"
	prompt.ObjectText = "River Rock"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Parent = anchor

	local board = Instance.new("BillboardGui")
	board.Name = "StarterRockTutorial"
	board.Adornee = anchor
	board.Size = UDim2.fromOffset(300, 96)
	board.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
	board.AlwaysOnTop = true
	board.MaxDistance = 130
	board.Parent = anchor

	local panel = Instance.new("Frame")
	panel.Name = "TutorialPanel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(8, 25, 46)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = board
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 222, 95)
	stroke.Thickness = 2
	stroke.Parent = panel

	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.BackgroundTransparency = 1
	arrow.Position = UDim2.fromOffset(10, 8)
	arrow.Size = UDim2.fromOffset(42, 72)
	arrow.Font = Enum.Font.GothamBlack
	arrow.Text = "▼"
	arrow.TextColor3 = Color3.fromRGB(255, 222, 95)
	arrow.TextSize = 40
	arrow.TextStrokeColor3 = Color3.fromRGB(8, 25, 46)
	arrow.TextStrokeTransparency = 0.15
	arrow.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(56, 12)
	title.Size = UDim2.new(1, -66, 0, 27)
	title.Font = Enum.Font.GothamBlack
	title.Text = "YOUR FIRST RIVER ROCK"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromOffset(56, 43)
	subtitle.Size = UDim2.new(1, -66, 0, 38)
	subtitle.Font = Enum.Font.GothamBold
	subtitle.Text = "PICK IT UP  •  THEN CLAIM YOUR FREE ROLL"
	subtitle.TextColor3 = Color3.fromRGB(177, 225, 255)
	subtitle.TextSize = 12
	subtitle.TextWrapped = true
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Parent = panel

	prompt.Triggered:Connect(function(player)
		local profile = Profiles.get(player)
		if not profile.loaded then
			Remotes.Toast:FireClient(player, "Your inventory is still loading.", "bad")
			return
		end
		if profile.starterRockClaimed == true then
			Remotes.Toast:FireClient(player, "You already picked up your River Rock.", "info")
			return
		end
		profile.starterRockClaimed = true
		profile.rocksOwned[RockCatalog.Default] = true
		profile.rockCounts[RockCatalog.Default] = math.max(profile.rockCounts[RockCatalog.Default] or 0, 1)
		Profiles.selectRock(profile, RockCatalog.Default, nil)
		Profiles.fireChanged(player)
		Remotes.Toast:FireClient(player, "River Rock collected! Visit the Summoning Station for your free first roll.", "good")
	end)
end

function WorldSetup.start()
	setupCollisionGroups()
	configureShoreSafety()
	getLake()
	-- The first rock is awarded through Summon Grove.

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(syncRockTool, player)
		end)
		if player.Character then task.defer(syncRockTool, player) end
	end

	Profiles.onChanged(function(player)
		local profile = Profiles.get(player)
		player:SetAttribute("StarterRockClaimed", profile.starterRockClaimed == true)
		if player.Parent then syncRockTool(player) end
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do onPlayerAdded(player) end
end

return WorldSetup
