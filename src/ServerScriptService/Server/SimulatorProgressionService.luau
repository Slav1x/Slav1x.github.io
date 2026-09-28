--!strict
-- Server-owned friend counts, collection milestone celebration, and safe Summon Grove teleport.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CollectionConfig = require(Shared:WaitForChild("CollectionConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))

local SimulatorProgressionService = {}
local teleportAt: {[Player]: number} = {}
local refreshingFriends = false

local function waitLoaded(player: Player): boolean
	for _ = 1, 120 do
		if not player.Parent then return false end
		if Profiles.get(player).loaded then return true end
		task.wait(0.1)
	end
	return false
end

local function areFriends(a: Player, b: Player): boolean
	local ok, result = pcall(function()
		return a:IsFriendsWith(b.UserId)
	end)
	if not ok then
		warn("[SimulatorProgression] friend check failed: " .. tostring(result))
		return false
	end
	return result == true
end

local function refreshFriendCounts()
	if refreshingFriends then return end
	refreshingFriends = true
	local active = Players:GetPlayers()
	local counts: {[Player]: number} = {}
	for _, player in active do counts[player] = 0 end
	for i = 1, #active do
		for j = i + 1, #active do
			local a, b = active[i], active[j]
			if areFriends(a, b) then
				counts[a] += 1
				counts[b] += 1
			end
		end
	end
	for player, count in counts do
		if player.Parent then
			local profile = Profiles.get(player)
			if profile.friendCount ~= count then
				profile.friendCount = count
				player:SetAttribute("FriendsInServer", count)
				Profiles.fireChanged(player)
			end
		end
	end
	refreshingFriends = false
end

local milestoneSyncing: {[Player]: boolean} = {}
local function syncMilestones(player: Player)
	if milestoneSyncing[player] or not player.Parent then return end
	milestoneSyncing[player] = true
	local profile = Profiles.get(player)
	local discovered = 0
	for _, value in profile.discoveredRocks do
		if value then discovered += 1 end
	end
	local changed = false
	for _, milestone in CollectionConfig.RockMilestones do
		if discovered >= milestone.Required and not profile.collectionMilestones[milestone.Key] then
			profile.collectionMilestones[milestone.Key] = true
			changed = true
			Remotes.Toast:FireClient(player,
				string.format("COLLECTION BONUS UNLOCKED!  %d Rocks Discovered  +%d%% Cash Earnings",
					milestone.Required, math.floor(milestone.CashBonus * 100 + 0.5)), "epic")
		end
	end
	milestoneSyncing[player] = nil
	if changed then task.defer(Profiles.fireChanged, player) end
end

local function teleportToSummon(player: Player)
	local now = os.clock()
	if now - (teleportAt[player] or 0) < CollectionConfig.SummonTeleportCooldown then return end
	teleportAt[player] = now
	local terrainModel = workspace:FindFirstChild("terrain")
	local destination = terrainModel and terrainModel:FindFirstChild("SpinButton")
	if not destination or not destination:IsA("BasePart") then
		Remotes.Toast:FireClient(player, "Pebble Plaza is unavailable right now", "bad")
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then return end
	character:PivotTo(destination.CFrame + CollectionConfig.SummonArrivalOffset)
end

function SimulatorProgressionService.start()
	Remotes.RequestSummonTeleport.OnServerEvent:Connect(teleportToSummon)
	Profiles.onChanged(syncMilestones)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			if waitLoaded(player) then
				syncMilestones(player)
				refreshFriendCounts()
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		teleportAt[player] = nil
		task.defer(refreshFriendCounts)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			if waitLoaded(player) then syncMilestones(player) end
		end)
	end
	task.spawn(refreshFriendCounts)
end

return SimulatorProgressionService
