local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud = script.Parent
local dailyGui = playerGui:WaitForChild("DailyRewardsUI")
local giftsGui = playerGui:WaitForChild("PlaytimeGiftsUI")
local questsGui = playerGui:WaitForChild("QuestsUI")
local UISounds = require(ReplicatedStorage:WaitForChild("SharedUI"):WaitForChild("UISounds"))
local ProfileStore = require(player:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("ProfileStore"))

local buttons = {
	shop = hud.LeftNav.shop,
	inventory = hud.LeftNav.inventory,
	upgrades = hud.LeftNav.Upgrades,
	daily = hud.dailyrewardsopenFrame.dailyrewardsopenbutton,
	gifts = hud.playtimerewardsopenFrame.playtimerewardsopenbutton,
	quests = hud.questsopenFrame.questsopenbutton,
	settings = hud.settingsopenframe.settingsopenbutton,
}
local targets = {
	shop = hud.shopui,
	inventory = hud.inventoryui,
	upgrades = hud.upgradesui,
	daily = dailyGui,
	gifts = giftsGui,
	quests = questsGui,
	settings = hud.settingsui,
}
local order = {"shop", "inventory", "upgrades", "daily", "gifts", "quests", "settings"}

local function tween(object, duration, properties, style)
	local animation = TweenService:Create(object, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
	animation:Play()
	return animation
end

local function isOpen(name)
	local target = targets[name]
	if target:IsA("ScreenGui") then return target.Enabled end
	return target.Visible
end

local function setClosed(name, animated)
	local target = targets[name]
	if not isOpen(name) then return end
	if animated and target:FindFirstChild("CloseRequest") then
		target.CloseRequest:Fire()
	elseif animated and name == "quests" then
		questsGui.QuestPanel.CloseRequest:Fire()
	elseif target:IsA("ScreenGui") then
		target.Enabled = false
	elseif animated and target:FindFirstChild("Toggle") then
		target.Toggle:Fire()
	else
		target.Visible = false
	end
end

local function closeOthers(exceptName)
	for _, name in ipairs(order) do
		if name ~= exceptName then setClosed(name, true) end
	end
end

local inventoryUnread = 0
local refreshInventoryBadge

local function setOpen(name)
	local target = targets[name]
	if name == "inventory" then
		inventoryUnread = 0
		if refreshInventoryBadge then refreshInventoryBadge() end
	end
	if target:IsA("ScreenGui") then
		target.Enabled = true
	elseif target:FindFirstChild("Toggle") then
		if not target.Visible then target.Toggle:Fire() end
	else
		target.Visible = true
	end
end

local function activateMenu(name)
	UISounds.play("Click")
	if isOpen(name) then
		setClosed(name, true)
		hud:SetAttribute("CurrentMenu", "")
		UISounds.play("Close")
		return
	end
	closeOthers(name)
	setOpen(name)
	hud:SetAttribute("CurrentMenu", name)
	UISounds.play("Open")
end

hud:WaitForChild("OpenMenu").Event:Connect(function(name)
	if buttons[name] then activateMenu(name) end
end)

local function buttonScale(button)
	local scale = button:FindFirstChild("NavScale")
	if not scale then
		scale = button:FindFirstChildOfClass("UIScale")
	end
	assert(scale, "Navigation UIScale missing for "..button.Name)
	return scale
end

for name, button in pairs(buttons) do
	button.AutoButtonColor = false
	local scale = buttonScale(button)
	local hovered = false
	local pressed = false
	local function applyScale()
		local value = pressed and 0.94 or hovered and 1.07 or 1
		if player:GetAttribute("ReducedMotion") then
			scale.Scale = value
		else
			tween(scale, pressed and 0.075 or 0.12, {Scale = value}, pressed and Enum.EasingStyle.Quad or Enum.EasingStyle.Back)
		end
	end
	button.MouseEnter:Connect(function()
		hovered = true
		applyScale()

		UISounds.play("Hover")
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		pressed = false
		applyScale()

	end)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pressed = true
			applyScale()
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pressed = false
			applyScale()
		end
	end)
	button.Activated:Connect(function() activateMenu(name) end)
end

local badgeShown = {}
local function updateBadge(button, amount, textOverride)
	local badge = button:FindFirstChild("NotificationBadge")
	if not badge then return end
	local visible = amount > 0
	local labelText = textOverride or tostring(math.min(amount, 99))
	badge.Label.Text = labelText
	badge.Shadow.Text = labelText
	if visible and not badgeShown[badge] then
		badge.Visible = true
		badge.BadgeScale.Scale = player:GetAttribute("ReducedMotion") and 1 or 0.45
		if not player:GetAttribute("ReducedMotion") then
			local pop = tween(badge.BadgeScale, 0.18, {Scale = 1.14}, Enum.EasingStyle.Back)
			pop.Completed:Once(function()
				if badge.Parent and badge.Visible then tween(badge.BadgeScale, 0.1, {Scale = 1}) end
			end)
		end
	elseif not visible then
		badge.Visible = false
		badge.BadgeScale.Scale = 1
	end
	badgeShown[badge] = visible
end

local glowShown = {}
local function updateGlow(button, ready)
	local glow = button:FindFirstChild("ReadyGlow")
	if not glow then return end
	if ready then
		glow.Visible = true
		if not glowShown[glow] then
			glow.BackgroundTransparency = player:GetAttribute("ReducedMotion") and 0.76 or 1
			glow.GlowScale.Scale = player:GetAttribute("ReducedMotion") and 1 or 0.7
			if not player:GetAttribute("ReducedMotion") then
				tween(glow, 0.28, {BackgroundTransparency = 0.76})
				local pop = tween(glow.GlowScale, 0.24, {Scale = 1.12}, Enum.EasingStyle.Back)
				pop.Completed:Once(function()
					if glow.Parent and glow.Visible then tween(glow.GlowScale, 0.12, {Scale = 1}) end
				end)
			end
		end
	else
		glow.Visible = false
	end
	glowShown[glow] = ready
end

local function refreshRewards()
	local dailyReady = (dailyGui:GetAttribute("ReadyCount") or 0) > 0
	local giftsReady = math.max(0, giftsGui:GetAttribute("ReadyCount") or 0)
	updateBadge(buttons.daily, dailyReady and 1 or 0, "!")
	updateBadge(buttons.gifts, giftsReady)
	updateGlow(buttons.daily, dailyReady)
	updateGlow(buttons.gifts, giftsReady > 0)
end
dailyGui:GetAttributeChangedSignal("ReadyCount"):Connect(refreshRewards)
giftsGui:GetAttributeChangedSignal("ReadyCount"):Connect(refreshRewards)
refreshRewards()

local lastInventory
local inventoryBaselineReady = false
local function inventoryCounts(snapshot)
	local counts = {}
	local traitedByRock = {}
	for instanceId, copy in pairs(snapshot.traitedRocks or {}) do
		if typeof(instanceId) == "string" and typeof(copy) == "table" then
			counts["special:" .. instanceId] = 1
			local rockId = tostring(copy.rockId or "")
			traitedByRock[rockId] = (traitedByRock[rockId] or 0) + 1
		end
	end
	for id, amount in pairs(snapshot.rockCounts or {}) do
		if typeof(id) == "string" and typeof(amount) == "number" and amount > 0 then
			counts["rock:" .. id] = math.max(0, amount - (traitedByRock[id] or 0))
		end
	end
	for _, id in ipairs(snapshot.rocksOwned or {}) do
		local key = "rock:" .. tostring(id)
		if not counts[key] and not traitedByRock[tostring(id)] then counts[key] = 1 end
	end
	for _, id in ipairs(snapshot.petsOwned or {}) do counts["pet:" .. tostring(id)] = 1 end
	for _, id in ipairs(snapshot.abilitiesOwned or {}) do counts["ability:" .. tostring(id)] = 1 end
	return counts
end
refreshInventoryBadge = function()
	updateBadge(buttons.inventory, inventoryUnread)
end
ProfileStore.onChanged(function()
	local snapshot = ProfileStore.get()
	if snapshot.loaded ~= true then return end
	local nextInventory = inventoryCounts(snapshot)
	if not inventoryBaselineReady then
		inventoryBaselineReady = true
		lastInventory = nextInventory
		refreshInventoryBadge()
		return
	end
	if lastInventory then
		local acquired, newTotal, oldTotal = 0, 0, 0
		for key, amount in pairs(nextInventory) do
			acquired += math.max(0, amount - (lastInventory[key] or 0))
			newTotal += amount
		end
		for _, amount in pairs(lastInventory) do oldTotal += amount end
		-- Allocating a mastery/trait GUID changes an existing copy key, not ownership.
		acquired = math.min(acquired, math.max(0, newTotal - oldTotal))
		if acquired > 0 and not hud.inventoryui.Visible then
			inventoryUnread += acquired
		end
	end
	lastInventory = nextInventory
	refreshInventoryBadge()
end)

local closeButtons = {
	hud.shopui.Shell.Header.CloseButton,
	hud.inventoryui.CloseButton,
	hud.upgradesui.Surface.Header.Close,
	hud.settingsui.Surface.Header.Close,
	dailyGui.Background.Header.Close,
	giftsGui.Background.Header.Close,
}
for _, button in ipairs(closeButtons) do
	button.Activated:Connect(function() UISounds.play("Close") end)
end
-- Close buttons missing a menu-specific hover handler share the same scale motion.
for _,button in ipairs({questsGui.QuestPanel.Header.Close,dailyGui.Background.Header.Close,giftsGui.Background.Header.Close}) do
	local scale=button:FindFirstChild("ButtonScale")
	if scale then
		local hovering=false
		button.MouseEnter:Connect(function()
			hovering=true
			if not player:GetAttribute("ReducedMotion") then tween(scale,.12,{Scale=1.09},Enum.EasingStyle.Back) end
		end)
		button.MouseLeave:Connect(function()
			hovering=false
			tween(scale,.12,{Scale=1})
		end)
		button.InputBegan:Connect(function(input)
			if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
				tween(scale,.07,{Scale=.93})
			end
		end)
		button.InputEnded:Connect(function(input)
			if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
				tween(scale,.12,{Scale=hovering and 1.09 or 1},Enum.EasingStyle.Back)
			end
		end)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= Enum.KeyCode.Escape then return end
	local hadOpen = false
	for _, name in ipairs(order) do hadOpen = hadOpen or isOpen(name) end
	if hadOpen then
		for _, name in ipairs(order) do setClosed(name, true) end
		hud:SetAttribute("CurrentMenu", "")
		UISounds.play("Close")
	end
end)

