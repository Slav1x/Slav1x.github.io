--!strict
-- Free spin training and the AFK station share one server-side cooldown.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Progression = require(Shared:WaitForChild("ProgressionConfig"))
local RockCatalog = require(Shared:WaitForChild("RockCatalog"))
local RockAppearance = require(Shared:WaitForChild("RockAppearance"))
local ThrowConfig = require(Shared:WaitForChild("ThrowConfig"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))

local TrainingService = {}
local TRAINER_ICON = "rbxassetid://82479640549547"
local lastGain: {[Player]: number} = {}
local spinning: {[Player]: Model} = {}
local lastMode: {[Player]: number} = {}
local afk: {[Player]: {character: Model, humanoid: Humanoid, root: BasePart, speed: number, jumpPower: number, jumpHeight: number, autoRotate: boolean, anchored: boolean}} = {}
local nextCheck = 0
local AFK_MULTIPLIER = 1.35

local function heldTool(player: Player): Tool?
	local character = player.Character
	if not character then return nil end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("IsTrainingTool") == true then return child end
	end
	return nil
end

local function findTool(player: Player): Tool?
	local held = heldTool(player)
	if held then return held end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in backpack:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("IsTrainingTool") == true then return child end
		end
	end
	return nil
end

local function updateRock(tool: Tool, rockId: string, variant: string)
	local rock = RockCatalog.get(rockId)
	-- Keep the tool distinct in the hotbar; its RockVisual carries the selected rock.
	tool.TextureId = TRAINER_ICON
	tool:SetAttribute("RockImage", nil)
	tool:SetAttribute("RockDisplayName", nil)
	local old = tool:FindFirstChild("RockVisual")
	if tool:GetAttribute("RockId") == rockId and tool:GetAttribute("Variant") == variant
		and old and old:IsA("Model") and old:GetAttribute("RockId") == rockId
		and old:GetAttribute("Variant") == variant then return end
	if old then old:Destroy() end
	tool.ToolTip = "Spin Strength Trainer • " .. rock.name .. " • click / E to toggle"
	tool:SetAttribute("RockId", rockId)
	tool:SetAttribute("Variant", variant)
	local model = RockAppearance.clone(rockId, variant)
	model.Name = "RockVisual"
	model:ScaleTo(ThrowConfig.RockVisualScale)
	model:PivotTo(CFrame.identity)
	local visualCenter = model:GetBoundingBox()
	model:PivotTo(CFrame.new(-visualCenter.Position))
	local spinner = tool:FindFirstChild("Spinner") :: BasePart?
	if not spinner then model:Destroy(); return end
	model:PivotTo(spinner.CFrame)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = spinner
			weld.Part1 = descendant
			weld.Parent = descendant
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant.Enabled = false
		end
	end
	model.Parent = tool
end

local function createTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Spin Trainer"
	tool.TextureId = TRAINER_ICON
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("IsTrainingTool", true)
	tool.Grip = CFrame.new(0, -0.65, -0.65) * CFrame.Angles(0, 0, math.rad(8))
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(.15, .15, .15)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Parent = tool
	local spinner = Instance.new("Part")
	spinner.Name = "Spinner"
	spinner.Size = Vector3.new(.1, .1, .1)
	spinner.Transparency = 1
	spinner.CanCollide = false
	spinner.CanTouch = false
	spinner.CanQuery = false
	spinner.Massless = true
	spinner.Parent = tool
	local motor = Instance.new("Motor6D")
	motor.Name = "PebbleSpin"
	motor.Part0 = handle
	motor.Part1 = spinner
	motor.C0 = CFrame.identity
	motor.Parent = handle
	spinner.CFrame = handle.CFrame * motor.C0
	return tool
end

local function ensureTool(player: Player): Tool?
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return nil end
	local profile = Profiles.get(player)
	if not profile.loaded or profile.starterRockClaimed ~= true or not next(profile.rocksOwned) then
		local premature = findTool(player)
		if premature then premature:Destroy() end
		return nil
	end
	local tool = findTool(player)
	if tool then
		tool.Name = "Spin Trainer"
	end
	if not tool then
		tool = createTool()
		tool.Parent = backpack
	end
	local rockId = if RockCatalog.exists(profile.rockEquipped)
		then profile.rockEquipped else RockCatalog.Default
	local variant = Profiles.equippedVariant(profile)
	updateRock(tool, rockId, variant)
	return tool
end

local function stopAfk(player: Player)
	local state = afk[player]
	afk[player] = nil
	player:SetAttribute("TrainingAFK", false)
	if not state then return end
	if state.humanoid.Parent and state.humanoid.Health > 0 then
		state.humanoid.WalkSpeed = state.speed
		state.humanoid.JumpPower = state.jumpPower
		state.humanoid.JumpHeight = state.jumpHeight
		state.humanoid.AutoRotate = state.autoRotate
	end
	if state.root.Parent then state.root.Anchored = state.anchored end
end

local function validPlayer(player: Player): (boolean, Humanoid?, BasePart?)
	if player:GetAttribute("RebirthCinematic")==true or not player.Parent or not Profiles.get(player).loaded or player:GetAttribute("RockInFlight") == true then return false, nil, nil end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or humanoid.Sit or not root or not root:IsA("BasePart") then return false, nil, nil end
	return true, humanoid, root
end

function TrainingService.train(player: Player, quiet: boolean?)
	local valid = validPlayer(player)
	if not valid then return false end
	if quiet and not spinning[player] then return false end
	local now = os.clock()
	if now - (lastGain[player] or -math.huge) < Progression.TrainingCooldown then return false end
	local profile = Profiles.get(player)
	local base = Progression.trainingGain(profile.spinStrength, profile.rebirths)
	local gain = math.min(math.max(0, Progression.strengthCap(profile.rebirths) - profile.spinStrength), base * (afk[player] and AFK_MULTIPLIER or 1) * (Profiles.dailyBoostActive(profile, "spin") and 2 or 1))
	if gain <= 0 then
		if quiet then stopAfk(player) end
		Remotes.ShopResult:FireClient(player, "spin", false, "Strength ceiling reached. Rebirth opens the next tier.")
		return false
	end
	lastGain[player] = now
	local gained = Profiles.addSpinStrength(player, gain)
	Profiles.fireChanged(player)
	if gained > 0 then Remotes.RewardPopup:FireClient(player, "spin", gained) end
	Remotes.ShopResult:FireClient(player, "spin", true, "+" .. Progression.formatStrength(gained) .. " Spin Strength")
	return true
end

local function stopTraining(player: Player)
	stopAfk(player)
	spinning[player] = nil
	player:SetAttribute("TrainingSpinning", false)
end

local function onMode(player: Player, requested: unknown)
	local mode = if requested == true then "afk" elseif requested == false then "off" else requested
	if mode ~= "off" and mode ~= "spin" and mode ~= "afk" then return end
	if mode == "off" then stopTraining(player); return end
	local now = os.clock()
	if now - (lastMode[player] or -math.huge) < .15 then return end
	lastMode[player] = now
	local valid, humanoid, root = validPlayer(player)
	if not valid or not humanoid or not root then return end
	local tool = if mode == "afk" then ensureTool(player) else heldTool(player)
	if not tool then return end
	if tool.Parent ~= player.Character then humanoid:EquipTool(tool) end
	if heldTool(player) ~= tool then return end
	local profile = Profiles.get(player)
	if Progression.trainingGain(profile.spinStrength, profile.rebirths) <= 0 then
		stopTraining(player)
		Remotes.ShopResult:FireClient(player, "spin", false, "Strength ceiling reached. Rebirth opens the next tier.")
		return
	end
	if mode == "spin" then
		stopAfk(player)
	elseif not afk[player] then
		afk[player] = {
			character = player.Character :: Model, humanoid = humanoid, root = root,
			speed = humanoid.WalkSpeed, jumpPower = humanoid.JumpPower,
			jumpHeight = humanoid.JumpHeight, autoRotate = humanoid.AutoRotate, anchored = root.Anchored,
		}
		humanoid:Move(Vector3.zero, false)
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.AutoRotate = false
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = true
		player:SetAttribute("TrainingAFK", true)
	end
	spinning[player] = player.Character :: Model
	player:SetAttribute("TrainingSpinning", true)
	TrainingService.train(player, true)
end

function TrainingService.start()
	Remotes.TrainingMode.OnServerEvent:Connect(onMode)
	Players.PlayerRemoving:Connect(function(player)
		stopTraining(player)
		lastGain[player] = nil
		lastMode[player] = nil
	end)
	local function onPlayer(player: Player)
		player:SetAttribute("TrainingAFK", false)
		player:SetAttribute("TrainingSpinning", false)
		player.CharacterRemoving:Connect(function() stopTraining(player) end)
		player.CharacterAdded:Connect(function()
			stopTraining(player)
			task.defer(function()
				local backpack = player:WaitForChild("Backpack", 10)
				if backpack and player.Parent then ensureTool(player) end
			end)
		end)
		if player.Character then task.defer(ensureTool, player) end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do onPlayer(player) end
	Profiles.onChanged(function(player)
		if player.Parent then task.defer(ensureTool, player) end
	end)
	RunService.Heartbeat:Connect(function()
		if os.clock() < nextCheck then return end
		nextCheck = os.clock() + .15
		for player, character in spinning do
			local valid = validPlayer(player)
			if not valid or player.Character ~= character or heldTool(player) == nil then
				stopTraining(player)
			else
				local profile = Profiles.get(player)
				if Progression.trainingGain(profile.spinStrength, profile.rebirths) <= 0 then
					stopTraining(player)
					Remotes.ShopResult:FireClient(player, "spin", false, "Strength ceiling reached. Rebirth opens the next tier.")
				else
					TrainingService.train(player, true)
				end
			end
		end
	end)
end

return TrainingService

