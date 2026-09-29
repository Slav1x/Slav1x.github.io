-- One steady on-screen stack per reward type. Repeated gains update in place.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Progression = require(ReplicatedStorage.Shared.ProgressionConfig)

local gui = Instance.new("ScreenGui")
gui.Name = "RewardPopups"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 85
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local GAP = 1.2
local FADE = .34
local styles = {
	spin = {color = Color3.fromRGB(95, 239, 237), glow = Color3.fromRGB(29, 118, 170), icon = "rbxassetid://78885528615503"},
	cash = {color = Color3.fromRGB(139, 255, 79), glow = Color3.fromRGB(25, 128, 48), icon = "rbxassetid://127824684237342"},
	gold = {color = Color3.fromRGB(255, 216, 70), glow = Color3.fromRGB(178, 102, 22), icon = "rbxassetid://105677100116374"},
}
local buckets = {}

local function moneyText(amount)
	return if amount < 1000 then tostring(math.floor(amount)) else Progression.formatStrength(amount)
end

-- The reference keeps gains in one screen-space area. Strength and money have
-- their own rows so the rock, aim reticle, and one another stay unobstructed.
local function slot(bucket)
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local scale = math.clamp(math.min(viewport.X / 900, viewport.Y / 650), .68, 1)
	local x = math.clamp(viewport.X * .62, 135 * scale, math.max(135 * scale, viewport.X - 135 * scale))
	local y = viewport.Y * .59 + (if bucket == "money" then 53 * scale else 0)
	y = math.clamp(y, 78 * scale, math.max(78 * scale, viewport.Y - 78 * scale))
	return x, y, scale
end

local function createCounter(bucket, worldPosition)
	local x, y, baseScale = slot(bucket, worldPosition)
	local holder = Instance.new("Frame")
	holder.Name = if bucket == "spin" then "SpinGain" else "MoneyGain"
	holder.AnchorPoint = Vector2.new(.5, .5)
	holder.Position = UDim2.fromOffset(x, y)
	holder.Size = UDim2.fromOffset(270, 56)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 85
	holder.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Scale = baseScale * .84
	scale.Parent = holder

	local icon = Instance.new("ImageLabel")
	icon.Name = "RewardIcon"
	icon.Position = UDim2.fromOffset(0, 4)
	icon.Size = UDim2.fromOffset(48, 48)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 87
	icon.Parent = holder

	local shadow = Instance.new("TextLabel")
	shadow.Name = "Glow"
	shadow.Position = UDim2.fromOffset(53, 3)
	shadow.Size = UDim2.fromOffset(214, 50)
	shadow.BackgroundTransparency = 1
	shadow.Font = Enum.Font.FredokaOne
	shadow.TextSize = 34
	shadow.TextXAlignment = Enum.TextXAlignment.Left
	shadow.TextStrokeColor3 = Color3.fromRGB(6, 21, 33)
	shadow.TextStrokeTransparency = .25
	shadow.ZIndex = 85
	shadow.Parent = holder

	local value = shadow:Clone()
	value.Name = "Value"
	value.Position = UDim2.fromOffset(51, 1)
	value.TextStrokeTransparency = 0
	value.ZIndex = 86
	value.Parent = holder

	return {
		holder = holder, scale = scale, icon = icon, shadow = shadow, value = value,
		baseScale = baseScale, total = 0, lastAt = 0, generation = 0,
		hasCash = false, hasGold = false, tweens = {},
	}
end

local function cancelTweens(state)
	for _, tween in state.tweens do tween:Cancel() end
	table.clear(state.tweens)
end

local function tween(state, object, duration, style, direction, properties)
	local animation = TweenService:Create(object, TweenInfo.new(duration, style, direction), properties)
	table.insert(state.tweens, animation)
	animation:Play()
end

local function refreshCounter(state, bucket, first, worldPosition)
	local style = if bucket == "spin" then styles.spin else if state.hasGold and not state.hasCash then styles.gold else styles.cash
	state.icon.Image = style.icon
	-- These are full-color assets. Tinting the muscle teal turned it green,
	-- unlike the identical icon in the lower-left Strength HUD.
	state.icon.ImageColor3 = Color3.new(1, 1, 1)
	state.shadow.TextColor3 = style.glow
	state.value.TextColor3 = style.color
	local number = if bucket == "spin" then "+" .. Progression.formatStrength(state.total)
		else "+$" .. moneyText(state.total)
	state.shadow.Text = number
	state.value.Text = number

	cancelTweens(state)
	state.shadow.TextTransparency = 0
	state.shadow.TextStrokeTransparency = .25
	state.value.TextTransparency = 0
	state.value.TextStrokeTransparency = 0
	state.icon.ImageTransparency = 0

	local x, y, baseScale = slot(bucket, worldPosition)
	state.baseScale = baseScale
	state.holder.Position = UDim2.fromOffset(x, y)
	if player:GetAttribute("ReducedMotion") == true then
		state.scale.Scale = baseScale
		return
	end
	-- Update the number in place; only a gentle pulse moves. No slot hopping.
	local generation = state.generation
	if first then state.scale.Scale = baseScale * .84 end
	tween(state, state.scale, first and .19 or .12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out,
		{Scale = baseScale * (first and 1.07 or 1.1)})
	task.delay(first and .19 or .12, function()
		if buckets[bucket] ~= state or state.generation ~= generation then return end
		tween(state, state.scale, .2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out,
			{Scale = baseScale})
	end)
end

local function popup(bucket, amount, cash, gold, worldPosition)
	if not Progression.isFinite(amount) or amount <= 0 then return end
	local now = os.clock()
	local state = buckets[bucket]
	if state and (not state.holder.Parent or now - state.lastAt > GAP) then
		state.holder:Destroy()
		buckets[bucket] = nil
		state = nil
	end
	local first = state == nil
	if first then
		state = createCounter(bucket, worldPosition)
		buckets[bucket] = state
	end
	state.total += amount
	state.hasCash = state.hasCash or cash == true
	state.hasGold = state.hasGold or gold == true
	state.lastAt = now
	state.generation += 1
	local generation = state.generation
	refreshCounter(state, bucket, first, worldPosition)
	task.delay(GAP, function()
		if buckets[bucket] ~= state or state.generation ~= generation then return end
		for _, label in {state.shadow, state.value} do
			tween(state, label, FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out,
				{TextTransparency = 1, TextStrokeTransparency = 1})
		end
		tween(state, state.icon, FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out,
			{ImageTransparency = 1})
		task.delay(FADE, function()
			if buckets[bucket] == state and state.generation == generation then
				buckets[bucket] = nil
				state.holder:Destroy()
			end
		end)
	end)
end

Remotes.RewardPopup.OnClientEvent:Connect(function(kind, amount, position)
	if kind == "spin" then popup("spin", amount, nil, nil, position) end
end)

Remotes.MoneyCollected.OnClientEvent:Connect(function(collectorUserId, collected, total)
	if collectorUserId ~= player.UserId or type(collected) ~= "table"
		or not Progression.isFinite(total) or total <= 0 then return end
	local hasCash, hasGold = false, false
	local position
	for _, entry in collected do
		if type(entry) == "table" and Progression.isFinite(entry.v) and entry.v > 0 then
			if entry.g == true then hasGold = true else hasCash = true end
			if not position then
				if typeof(entry.target) == "Vector3" then position = entry.target
				elseif typeof(entry.p) == "Vector3" then position = entry.p end
			end
		end
	end
	if hasCash or hasGold then popup("money", total, hasCash, hasGold, position) end
end)
