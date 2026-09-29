--!strict
--[[
	Leaderstats
	Creates Money and the Spin Strength display mirror in leaderstats for every player so the MainHUD
	stat chips have live values to display. Hook your data/economy system into
	these IntValues (or replace this script) when you add saving and progression.
--]]

local Players = game:GetService("Players")
local ProgressionConfig=require(game:GetService("ReplicatedStorage").Shared.ProgressionConfig)

local function onPlayerAdded(player: Player)
	if player:FindFirstChild("leaderstats") then
		return
	end

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"

	local money = Instance.new("IntValue")
	money.Name = "Money"
	money.Value = 0
	money.Parent = stats

	local strength = Instance.new("NumberValue")
	strength.Name = "Strength"
	strength.Value = ProgressionConfig.StartingSpinStrength
	strength.Parent = stats

	stats.Parent = player
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
