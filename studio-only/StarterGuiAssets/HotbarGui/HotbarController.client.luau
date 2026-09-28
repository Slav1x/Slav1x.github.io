-- Dynamic hotbar: shows one slot per item in the player's backpack.
-- The entire UI is built at runtime by this script, so it can't be broken
-- by changes to StarterGui. Slots rebuild automatically as items change.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MAX_SLOTS = 9
local equippedTool = nil
local slotTools = {} -- maps slot index -> toggle function, for number keys
local firstSeen = setmetatable({}, {__mode = "k"})
local nextSeen = 0
local function sortKey(tool)
	if tool:GetAttribute("IsRockTool") == true then return 1 end
	if tool:GetAttribute("IsTrainingTool") == true then return 2 end
	return 3
end
local function seenKey(tool)
	if not firstSeen[tool] then
		nextSeen += 1
		firstSeen[tool] = nextSeen
	end
	return firstSeen[tool]
end

-- ----------------------------------------------------------------
-- Build the UI from scratch (self-contained, no StarterGui dependencies)
-- ----------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "HotbarGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 10
gui.Parent = playerGui

local bar = Instance.new("Frame")
bar.Name = "Hotbar"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -12)
bar.Size = UDim2.new(0, 0, 0, 76)
bar.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
bar.BackgroundTransparency = 0.3
bar.BorderSizePixel = 0
bar.Visible = false
bar.Parent = gui

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 12)
barCorner.Parent = bar

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = bar

local function createSlot(index, tool)
	local active = tool.Parent == player.Character
	local slot = Instance.new("ImageButton")
	slot.Name = "Slot" .. index
	slot.LayoutOrder = index
	slot.Size = UDim2.new(0, 64, 0, 64)
	slot.BackgroundColor3 = if active then Color3.fromRGB(10, 74, 108) else Color3.fromRGB(35, 35, 45)
	slot.BackgroundTransparency = if active then 0 else 0.15
	slot.BorderSizePixel = 0
	slot.AutoButtonColor = false
	slot.Parent = bar

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = slot

	if active then
		local stroke = Instance.new("UIStroke")
		stroke.Name = "Highlight"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Color3.fromRGB(67, 220, 255)
		stroke.Thickness = 3
		stroke.Transparency = 0
		stroke.Parent = slot
	end
	local activeMark = Instance.new("Frame")
	activeMark.Name = "ActiveMark"
	activeMark.AnchorPoint = Vector2.new(1, 0)
	activeMark.Position = UDim2.new(1, -5, 0, 5)
	activeMark.Size = UDim2.fromOffset(7, 7)
	activeMark.BackgroundColor3 = Color3.fromRGB(103, 255, 147)
	activeMark.BorderSizePixel = 0
	activeMark.Visible = active
	activeMark.Parent = slot
	local markCorner = Instance.new("UICorner")
	markCorner.CornerRadius = UDim.new(1, 0)
	markCorner.Parent = activeMark

	local number = Instance.new("TextLabel")
	number.Name = "Number"
	number.Size = UDim2.new(0, 18, 0, 18)
	number.Position = UDim2.new(0, 4, 0, 2)
	number.BackgroundTransparency = 1
	number.Text = tostring(index)
	number.TextColor3 = if active then Color3.fromRGB(151, 255, 185) else Color3.fromRGB(200, 200, 210)
	number.TextSize = 12
	number.Font = Enum.Font.GothamBold
	number.TextXAlignment = Enum.TextXAlignment.Left
	number.Parent = slot

	local image = Instance.new("ImageLabel")
	image.Name = "RockImage"
	image.AnchorPoint = Vector2.new(0.5, 0)
	image.Position = UDim2.new(0.5, 0, 0, 5)
	image.Size = UDim2.new(1, -14, 0, 43)
	image.BackgroundTransparency = 1
	image.Image = if tool:GetAttribute("IsTrainingTool") == true then tool.TextureId
		else tool:GetAttribute("RockImage") or tool.TextureId
	image.ScaleType = Enum.ScaleType.Fit
	image.Parent = slot

	local name = Instance.new("TextLabel")
	name.Name = "ToolName"
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, -3)
	name.Size = UDim2.new(1, -8, 0, 17)
	name.BackgroundTransparency = 1
	name.Text = if tool:GetAttribute("IsTrainingTool") == true then tool.Name
		else tool:GetAttribute("RockDisplayName") or tool.Name
	name.TextColor3 = Color3.fromRGB(235, 235, 240)
	name.TextSize = 10
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Font = Enum.Font.GothamMedium
	name.Parent = slot

	if image.Image == "" then
		image.Visible = false
		name.AnchorPoint = Vector2.new(0.5, 0.5)
		name.Position = UDim2.fromScale(0.5, 0.55)
		name.Size = UDim2.new(1, -10, 0, 34)
		name.TextSize = 12
		name.TextWrapped = true
	end

	-- Click a slot to equip / unequip that tool
	local function toggle()
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
		if tool.Parent == player.Character then
			humanoid:UnequipTools()
		else
			humanoid:EquipTool(tool)
		end
	end
	slot.MouseButton1Click:Connect(toggle)
	slotTools[index] = toggle

	return slot
end

local function rebuild()
	-- Clear existing slots
	for _, child in bar:GetChildren() do
		if child:IsA("ImageButton") then
			child:Destroy()
		end
	end
	slotTools = {}

	-- Determine the currently equipped tool (a Tool parented to the character)
	equippedTool = nil
	local character = player.Character
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") then
				equippedTool = child
				break
			end
		end
	end

	-- Keep slot order independent of which tool is equipped.
	local tools = {}
	if equippedTool and equippedTool.Parent then
		table.insert(tools, equippedTool)
	end
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, child in backpack:GetChildren() do
			if child:IsA("Tool") then
				table.insert(tools, child)
			end
		end
	end

	for _, tool in tools do seenKey(tool) end
	table.sort(tools, function(a, b)
		local aGroup, bGroup = sortKey(a), sortKey(b)
		if aGroup ~= bGroup then return aGroup < bGroup end
		return seenKey(a) < seenKey(b)
	end)

	-- Build one slot per tool (capped at MAX_SLOTS)
	for i, tool in ipairs(tools) do
		if i > MAX_SLOTS then break end
		createSlot(i, tool)
	end

	-- Resize the bar to fit the number of slots
	local slotCount = math.min(#tools, MAX_SLOTS)
	if slotCount == 0 then
		bar.Size = UDim2.new(0, 0, 0, 76)
		bar.Visible = false
	else
		bar.Size = UDim2.new(0, slotCount * 64 + (slotCount - 1) * 6 + 24, 0, 82)
		bar.Visible = true
	end
end

local rebuildQueued = false
local function queueRebuild()
	if rebuildQueued then return end
	rebuildQueued = true
	task.defer(function()
		RunService.Heartbeat:Wait()
		rebuildQueued = false
		rebuild()
	end)
end

local function watchCharacter(character)
	-- Tools move in/out of the character when equipped/unequipped
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			queueRebuild()
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			queueRebuild()
		end
	end)
end

-- Track the backpack so the hotbar updates whenever items change
local function watchBackpack(backpack)
	backpack.ChildAdded:Connect(queueRebuild)
	backpack.ChildRemoved:Connect(queueRebuild)
end

if player.Backpack then
	watchBackpack(player.Backpack)
end
player.CharacterAdded:Connect(function(character)
	equippedTool = nil
	watchCharacter(character)
	queueRebuild()
end)

-- Backpack is recreated on respawn; watch for the new one
player.ChildAdded:Connect(function(child)
	if child.Name == "Backpack" then
		watchBackpack(child)
		queueRebuild()
	end
end)

if player.Character then
	watchCharacter(player.Character)
end

-- Number keys 1-9 equip the tool in that slot.
-- NOTE: top-row number keys don't have a ".Name" of "1", "2", etc -- Roblox
-- names them "One", "Two", ... "Nine", "Zero", so they need an explicit
-- KeyCode -> slot lookup rather than pattern-matching the name as a digit.
local NUMBER_KEY_TO_SLOT = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	local slotIndex = NUMBER_KEY_TO_SLOT[input.KeyCode]
	if slotIndex then
		local toggle = slotTools[slotIndex]
		if toggle then
			toggle()
		end
	end
end)

rebuild()local function fitHotbar()
 local v=workspace.CurrentCamera.ViewportSize
 local scale=bar:FindFirstChild("MobileScale") or Instance.new("UIScale",bar)
 scale.Name="MobileScale";scale.Scale=(v.X<600 or v.Y<500) and .75 or 1
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitHotbar)
fitHotbar()
