--!strict
--[[
	TutorialQA (Studio-only test hook)

	Inert unless running in Studio with workspace attribute
	WorldProgressionTestMode = true (which also keeps Persistence off the live
	DataStore). Exposes ServerStorage.TutorialQA (BindableFunction) so a
	tester can jump the real, server-owned profile to any tutorial situation
	without grinding. Never reachable from clients.
]]

local RunService = game:GetService("RunService")
if not RunService:IsStudio() or workspace:GetAttribute("WorldProgressionTestMode") ~= true then
	return
end

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent:WaitForChild("Server")
local Profiles = require(Server:WaitForChild("Profiles"))
local Persistence = require(Server:WaitForChild("Persistence")) :: any
local TutorialService = require(Server:WaitForChild("TutorialService")) :: any
local ProgressionConfig = require(ReplicatedStorage.Shared:WaitForChild("ProgressionConfig"))

local existing = ServerStorage:FindFirstChild("TutorialQA")
local hook: BindableFunction = if existing and existing:IsA("BindableFunction") then existing else Instance.new("BindableFunction")
hook.Name = "TutorialQA"
hook.Parent = ServerStorage

hook.OnInvoke = function(action: string, arg: any)
	local player = Players:GetPlayers()[1]
	assert(player, "no player")
	local profile = Profiles.get(player)
	if action == "state" then
		return {
			loaded = profile.loaded, stage = profile.tutorialStage, flags = profile.tutorialFlags,
			skipped = profile.tutorialSkipped, money = Profiles.getMoney(player), totalMoney = profile.totalMoney,
			totalSkips = profile.totalSkips, upgrades = profile.upgrades, rebirths = profile.rebirths,
			sweetMul = player:GetAttribute("TutorialSweetZoneMul"), attrStage = player:GetAttribute("TutorialStage"),
		}
	elseif action == "grantRock" then
		profile.rocksOwned.pebble = true
		profile.rockCounts.pebble = math.max(profile.rockCounts.pebble or 0, 1)
		profile.starterRockClaimed = true
		profile.freeSummonUsed = true
		Profiles.selectRock(profile, "pebble", nil)
	elseif action == "cash" then
		Profiles.addMoney(player, tonumber(arg) or 0)
	elseif action == "skipsAndCash" then
		profile.totalSkips += 1
		profile.totalThrows += 1
		Profiles.addMoney(player, tonumber(arg) or 0)
	elseif action == "rebirthReady" then
		-- Satisfy every real rebirth requirement for the current journey.
		local q = ProgressionConfig.rebirthRequirements(profile.rebirths)
		-- The play that gets a real player here (skips, cash, the upgrade steps).
		profile.totalSkips = math.max(profile.totalSkips, 1)
		profile.totalThrows = math.max(profile.totalThrows, 1)
		profile.totalMoney = math.max(profile.totalMoney, q.cost)
		profile.tutorialFlags.rewardsSeen = true
		profile.tutorialFlags.upgradesOpened = true
		profile.cycleCompletedAreas[q.areaId] = true
		profile.completedAreas[q.areaId] = true
		profile.spinStrength = q.strength
		profile.upgrades.power = math.max(profile.upgrades.power or 0, q.powerLevel)
		local money = Profiles.getMoney(player)
		if money < q.cost then Profiles.addMoney(player, q.cost - money) end
	elseif action == "teleport" then
		local character = player.Character
		if character and typeof(arg) == "Vector3" then character:PivotTo(CFrame.new(arg)) end
	elseif action == "roundtrip" then
		-- Simulate disconnect + rejoin through the real serialise/deserialise.
		local data = Persistence.testSerialise(player, profile)
		local restored = Persistence.testDeserialise(data)
		restored.loaded = true
		Profiles.set(player, restored)
	elseif action == "legacy" then
		-- A save written before the tutorial existed.
		local data = Persistence.testSerialise(player, profile)
		data.tutorialStage, data.tutorialFlags, data.tutorialSkipped = nil, nil, nil
		for key, value in (arg or {}) do data[key] = value end
		local restored = Persistence.testDeserialise(data)
		restored.loaded = true
		Profiles.set(player, restored)
	elseif action == "reset" then
		local fresh = Profiles.blank()
		fresh.loaded = true
		Profiles.set(player, fresh)
		local money = Profiles.moneyValue(player)
		if money then money.Value = 0 end
	elseif action == "evaluate" then
		return TutorialService.evaluate(profile, Profiles.getMoney(player))
	end
	Profiles.fireChanged(player)
	return profile.tutorialStage
end
