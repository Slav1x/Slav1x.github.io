-- Banks the lower-left counters during a throw, then carries earned rewards into them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local hud = script.Parent
local stats = player:WaitForChild("leaderstats")
local strength = stats:WaitForChild("Strength")
local money = stats:WaitForChild("Money")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Progression = require(ReplicatedStorage.Shared.ProgressionConfig)
local UISounds = require(ReplicatedStorage.SharedUI.UISounds)
local strengthChip = hud:WaitForChild("StatsBar"):WaitForChild("Strength")
local moneyChip = hud:WaitForChild("Money")
local strengthLabel = strengthChip:WaitForChild("Value")
local moneyLabel = moneyChip:WaitForChild("Value")

local overlay = Instance.new("ScreenGui")
overlay.Name = "ThrowRewardFlight"
overlay.IgnoreGuiInset = true
overlay.ResetOnSpawn = false
overlay.DisplayOrder = 110
overlay.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
overlay.Parent = player:WaitForChild("PlayerGui")

local banking = false
local generation = 0
local startingStrength = 0
local startingMoney = 0
local collectedMoney = 0

local function compactCash(value)
	local n = math.max(0, tonumber(value) or 0)
	local units = {"", "K", "M", "B", "T", "Q"}
	local index = 1
	while n >= 1000 and index < #units do n /= 1000 index += 1 end
	local decimals = n < 10 and 2 or 1
	local rounded = math.floor(n * 10 ^ decimals + .5) / 10 ^ decimals
	if rounded >= 1000 and index < #units then rounded /= 1000 index += 1 decimals = 2 end
	return string.format("%." .. decimals .. "f", rounded) .. units[index]
end

local function begin()
	if banking then return end
	banking = true
	generation += 1
	startingStrength = strength.Value
	startingMoney = money.Value
	collectedMoney = 0
	hud:SetAttribute("BankingThrowRewards", true)
	local thisThrow = generation
	task.delay(120, function()
		if banking and generation == thisThrow then
			banking = false
			hud:SetAttribute("BankingThrowRewards", false)
		end
	end)
end

player:GetAttributeChangedSignal("RockInFlight"):Connect(function()
	if player:GetAttribute("RockInFlight") == true then begin() end
end)
if player:GetAttribute("RockInFlight") == true then begin() end

Remotes.MoneyCollected.OnClientEvent:Connect(function(userId, _, total)
	if banking and userId == player.UserId and type(total) == "number"
		and total > 0 and total < math.huge then
		collectedMoney += total
	end
end)

local function targetPoint(label)
	return Vector2.new(label.AbsolutePosition.X + label.AbsoluteSize.X * .5,
		label.AbsolutePosition.Y + label.AbsoluteSize.Y * .5)
end

local function sourcePoint(worldPosition)
	local camera = workspace.CurrentCamera
	if camera then
		if typeof(worldPosition) == "Vector3" then
			local point, visible = camera:WorldToViewportPoint(worldPosition)
			if visible and point.Z > 0 then
				return Vector2.new(point.X, point.Y - 38)
			end
		end
		local size = camera.ViewportSize
		return Vector2.new(size.X * .5, size.Y * .48)
	end
	return Vector2.new(480, 320)
end

local function pulse(chip)
	local scale = chip:FindFirstChild("RewardBankPulse")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "RewardBankPulse"
		scale.Parent = chip
	end
	scale.Scale = 1
	local up = TweenService:Create(scale, TweenInfo.new(.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.13})
	up:Play()
	up.Completed:Wait()
	TweenService:Create(scale, TweenInfo.new(.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
end

local function fly(kind, amount, worldPosition, onLand)
	local isMoney = kind == "money"
	local color = if isMoney then Color3.fromRGB(119, 255, 82) else Color3.fromRGB(99, 245, 235)
	local destination = targetPoint(if isMoney then moneyLabel else strengthLabel)
	local start = sourcePoint(worldPosition)
	start += Vector2.new(if isMoney then -56 else 56, if isMoney then 28 else -30)

	local holder = Instance.new("Frame")
	holder.Name = if isMoney then "MoneyFlight" else "StrengthFlight"
	holder.AnchorPoint = Vector2.new(.5, .5)
	holder.Position = UDim2.fromOffset(start.X, start.Y)
	holder.Size = UDim2.fromOffset(190, 58)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 20
	holder.Parent = overlay

	local scale = Instance.new("UIScale")
	scale.Scale = .78
	scale.Parent = holder

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Position = UDim2.fromOffset(0, 5)
	icon.Size = UDim2.fromOffset(48, 48)
	icon.Image = if isMoney then "rbxassetid://127824684237342" else "rbxassetid://78885528615503"
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 21
	icon.Parent = holder

	local value = Instance.new("TextLabel")
	value.Name = "Gain"
	value.BackgroundTransparency = 1
	value.Position = UDim2.fromOffset(42, 0)
	value.Size = UDim2.fromOffset(148, 56)
	value.Font = Enum.Font.FredokaOne
	value.TextScaled = true
	value.TextColor3 = color
	value.TextStrokeColor3 = Color3.fromRGB(7, 20, 35)
	value.TextStrokeTransparency = 0
	value.Text = if isMoney then "+$" .. compactCash(amount) else "+" .. Progression.formatStrength(amount)
	value.ZIndex = 21
	value.Parent = holder

	if player:GetAttribute("ReducedMotion") ~= true then
		local pop = TweenService:Create(scale, TweenInfo.new(.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.12})
		local lift = TweenService:Create(holder, TweenInfo.new(.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Position = UDim2.fromOffset(start.X, start.Y - 40)})
		pop:Play()
		lift:Play()
		lift.Completed:Wait()
		local travel = TweenService:Create(holder, TweenInfo.new(.57, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{Position = UDim2.fromOffset(destination.X, destination.Y)})
		local shrink = TweenService:Create(scale, TweenInfo.new(.57, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{Scale = .32})
		shrink:Play()
		travel:Play()
		travel.Completed:Wait()
	end

	onLand()
	UISounds.play("Claim")
	task.spawn(pulse, if isMoney then moneyChip else strengthChip)
	holder:Destroy()
end

Remotes.ThrowEnded.OnClientEvent:Connect(function(result)
	if not banking then return end
	local thisThrow = generation
	-- Allow the last server-awarded cash and stat updates to replicate.
	task.wait(.12)
	if generation ~= thisThrow then return end
	local strengthGain = if type(result) == "table" and type(result.spinStrengthGain) == "number"
		then math.max(0, result.spinStrengthGain) else 0
	local moneyGain = math.max(0, money.Value - startingMoney, collectedMoney)
	local worldPosition = if type(result) == "table" then result.position else nil
	local remaining = 0
	local function finishOne()
		remaining -= 1
		if remaining == 0 and generation == thisThrow then
			banking = false
			hud:SetAttribute("BankingThrowRewards", false)
		end
	end
	if moneyGain > 0 then
		remaining += 1
		task.spawn(function()
			fly("money", moneyGain, worldPosition, function()
				moneyLabel.Text = "$" .. compactCash(math.max(money.Value, startingMoney + moneyGain))
			end)
			finishOne()
		end)
	end
	if strengthGain > 0 then
		remaining += 1
		task.spawn(function()
			task.wait(.08)
			fly("strength", strengthGain, worldPosition, function()
				strengthLabel.Text = "SPIN STRENGTH\n" .. Progression.formatStrength(
					math.max(strength.Value, startingStrength + strengthGain))
			end)
			finishOne()
		end)
	end
	if remaining == 0 then
		banking = false
		hud:SetAttribute("BankingThrowRewards", false)
	end
end)

