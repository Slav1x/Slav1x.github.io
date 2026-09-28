--!strict
--[[
	MainHUDScript (LocalScript inside the MainHUD ScreenGui)

	1. STUD TEXTURE: applies the LEGO stud surface texture (asset 6927295847)
	   to every GuiObject tagged with the "StudSurface" attribute. The texture
	   instances are created HERE at runtime, so they never render in Studio
	   edit mode — studs only appear while the game is actually running.
	2. STAT CHIPS: keeps the Money / Strength Value labels in sync with
	   player.leaderstats, formatting big numbers (1.2K, 5.6M).
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedUI = ReplicatedStorage:WaitForChild("SharedUI")
local UIHelpers = require(SharedUI:WaitForChild("UIHelpers"))
local ProgressionConfig = require(ReplicatedStorage.Shared.ProgressionConfig)

local player = Players.LocalPlayer
local hud = script.Parent
local playerGui = player:WaitForChild("PlayerGui")

-- 1) STUD TEXTURE (runtime only -> invisible in edit mode)
local function textureSurface(instance: Instance)
	if instance:IsA("GuiObject") and instance:GetAttribute("StudSurface") == true then
		UIHelpers.applyStudTexture(instance)
	end
end

for _, descendant in playerGui:GetDescendants() do
	textureSurface(descendant)
end
playerGui.DescendantAdded:Connect(textureSurface)

-- 2) STAT CHIPS -> leaderstats
local function watchStat(label: TextLabel, stat: Instance)
	local function refresh()
		if stat.Name == "Strength" and (hud:GetAttribute("BankingThrowRewards") == true or player:GetAttribute("RockInFlight") == true) then return end
		label.Text = if stat.Name == "Strength"
			then "SPIN STRENGTH\n" .. ProgressionConfig.formatStrength((stat :: any).Value)
			else UIHelpers.formatNumber((stat :: any).Value)
	end
	refresh()
	stat.Changed:Connect(refresh)
	if stat.Name == "Strength" then
		hud:GetAttributeChangedSignal("BankingThrowRewards"):Connect(refresh)
		player:GetAttributeChangedSignal("RockInFlight"):Connect(refresh)
	end
end

local function bindChip(chip: Instance)
 if chip:GetAttribute("PresentationManaged") then return end
	local statName = chip:GetAttribute("StatName")
	local valueLabel = chip:FindFirstChild("Value")
	if typeof(statName) ~= "string" or not (valueLabel and valueLabel:IsA("TextLabel")) then
		return
	end
	local label = valueLabel :: TextLabel

	local function bindStats(stats: Instance)
		local stat = stats:FindFirstChild(statName)
		if stat and (stat:IsA("IntValue") or stat:IsA("NumberValue")) then
			watchStat(label, stat)
		else
			-- stat value may be created a moment later
			stats.ChildAdded:Connect(function(child)
				if child.Name == statName and (child:IsA("IntValue") or child:IsA("NumberValue")) then
					watchStat(label, child)
				end
			end)
		end
	end

	local stats = player:FindFirstChild("leaderstats")
	if stats then
		bindStats(stats)
	else
		-- leaderstats may be created a moment after the player joins
		local connection: RBXScriptConnection? = nil
		connection = player.ChildAdded:Connect(function(child)
			if child.Name == "leaderstats" then
				if connection then
					connection:Disconnect()
				end
				bindStats(child)
			end
		end)
	end
end

for _, descendant in hud:GetDescendants() do
	if descendant:GetAttribute("StatName") then
		bindChip(descendant)
	end
end
-- Gameplay touch controls should never cover a modal's controls.
do
 local saved={}
 local function modalState()
  local open=false
  for _,name in {"shopui","inventoryui","upgradesui","settingsui"} do
   local p=hud:FindFirstChild(name) if p and p.Visible then open=true end
  end
  for _,g in playerGui:GetChildren() do
   if g:IsA("ScreenGui") and g.Name=="TouchControls" then
    if open then if saved[g]==nil then saved[g]=g.Enabled end g.Enabled=false
    elseif saved[g]~=nil then g.Enabled=saved[g] saved[g]=nil end
   end
  end
 end
 for _,name in {"shopui","inventoryui","upgradesui","settingsui"} do hud[name]:GetPropertyChangedSignal("Visible"):Connect(modalState) end
 playerGui.ChildAdded:Connect(function() task.defer(modalState) end)
 modalState()
end


