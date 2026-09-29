--!strict
--[[
	TutorialService (server)

	Owns the beginner tutorial stage. It never grants anything and never
	trusts the client about gameplay: every stage is re-derived from the real
	profile (rocks owned, confirmed skips, cash earned, upgrade levels,
	rebirth eligibility). The client can only report two presentation facts
	("I showed the rewards card", "I opened the Upgrades menu") and ask to
	skip the tutorial.

	The stage lives on the existing Profile, is saved by Persistence and is
	pushed to the client inside the normal ProfileState snapshot, so there is
	no second DataStore and no extra state remote.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TutorialConfig = require(Shared:WaitForChild("TutorialConfig"))
local ProgressionConfig = require(Shared:WaitForChild("ProgressionConfig"))
local RockCatalog = require(Shared:WaitForChild("RockCatalog"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Profiles = require(script.Parent:WaitForChild("Profiles"))

local TutorialService = {}

local lastAction: {[Player]: number} = {}
local moneyConnections: {[Player]: RBXScriptConnection} = {}
local reconcileQueued: {[Player]: boolean} = {}
local started = false

local SWEET_ZONE_ATTRIBUTE = "TutorialSweetZoneMul"
local STAGE_ATTRIBUTE = "TutorialStage"

local function ownsCollectibleRock(profile: Profiles.Profile): boolean
	for id, owned in profile.rocksOwned do
		if owned and RockCatalog.exists(id) then
			return true
		end
	end
	return false
end

local function boughtAnyUpgrade(profile: Profiles.Profile): boolean
	for _, level in profile.upgrades do
		if type(level) == "number" and level > 0 then
			return true
		end
	end
	return false
end

-- Pure: given the profile and current cash, which stage should the player be
-- in? Stages only move forward, except RebirthReady <-> FreePlay which
-- follows live rebirth eligibility (spending cash can drop below the cost).
function TutorialService.evaluate(profile: Profiles.Profile, money: number): string
	local stage = if TutorialConfig.isStage(profile.tutorialStage) then profile.tutorialStage else "SummonRock"
	if stage == "Completed" or profile.tutorialSkipped then
		return "Completed"
	end
	if profile.rebirths > 0 then
		return "Completed"
	end

	local flags = profile.tutorialFlags
	local bought = boughtAnyUpgrade(profile)
	-- Note: an early upgrade purchase does NOT jump straight to FreePlay. A
	-- player could afford one (e.g. daily-reward cash) before owning a rock;
	-- the walk below still teaches summon/throw first, then clears the
	-- upgrade steps instantly because their goals are already met.

	-- Walk forward through every stage whose goal is already met, so actions
	-- done early (or before a disconnect) are recognised in one pass.
	for _ = 1, #TutorialConfig.Stages do
		local nextStage: string? = nil
		if stage == "SummonRock" and ownsCollectibleRock(profile) then
			nextStage = "FirstThrow"
		elseif stage == "FirstThrow" and profile.totalSkips > 0 then
			nextStage = "LearnRewards"
		elseif stage == "LearnRewards" and profile.totalMoney > 0 and flags.rewardsSeen == true then
			nextStage = "OpenUpgrades"
		elseif stage == "OpenUpgrades" and (flags.upgradesOpened == true or bought) then
			nextStage = "BuyUpgrade"
		elseif stage == "BuyUpgrade" and bought then
			nextStage = "FreePlay"
		end
		if not nextStage then
			break
		end
		stage = nextStage
	end

	if stage == "FreePlay" or stage == "RebirthReady" then
		local ready = ProgressionConfig.canRebirth(profile, money)
		stage = if ready then "RebirthReady" else "FreePlay"
	end
	return stage
end

local function applyAttributes(player: Player, stage: string)
	player:SetAttribute(STAGE_ATTRIBUTE, stage)
	-- Read by ThrowService when rolling the sweet zone. Server attributes cannot
	-- be changed by the client, so this cannot be abused.
	player:SetAttribute(SWEET_ZONE_ATTRIBUTE,
		if stage == "FirstThrow" then TutorialConfig.FirstThrowSweetZoneMul else nil)
end

-- Returns true if the stage changed.
local function reconcile(player: Player): boolean
	if not player.Parent or not Profiles.has(player) then
		return false
	end
	local profile = Profiles.get(player)
	if not profile.loaded then
		return false
	end
	local before = profile.tutorialStage
	local after = TutorialService.evaluate(profile, Profiles.getMoney(player))
	profile.tutorialStage = after
	applyAttributes(player, after)
	return before ~= after
end
TutorialService.reconcile = reconcile

-- Money lives in leaderstats and does not fire Profiles.onChanged, but it
-- decides rebirth eligibility. Coalesce bursts of pickups into one check.
local function queueReconcile(player: Player)
	if reconcileQueued[player] then return end
	reconcileQueued[player] = true
	task.delay(0.35, function()
		reconcileQueued[player] = nil
		if reconcile(player) then
			Profiles.fireChanged(player)
		end
	end)
end

local function onAction(player: Player, action: unknown)
	if type(action) ~= "string" or not TutorialConfig.Actions[action] then
		return
	end
	local now = os.clock()
	if now - (lastAction[player] or -math.huge) < TutorialConfig.ActionCooldown then
		return
	end
	lastAction[player] = now
	if not Profiles.has(player) then return end
	local profile = Profiles.get(player)
	if not profile.loaded or profile.tutorialStage == "Completed" then
		return
	end

	if action == "skip" then
		profile.tutorialSkipped = true
		profile.tutorialStage = "Completed"
		applyAttributes(player, "Completed")
		Profiles.fireChanged(player)
		-- Persist the choice promptly rather than waiting for the autosave.
		task.defer(function()
			local Persistence = require(script.Parent:WaitForChild("Persistence")) :: any
			if player.Parent then Persistence.saveNow(player) end
		end)
		return
	end

	if action == "rewardsSeen" then
		-- Only meaningful once there is actually a reward to have seen.
		if profile.totalMoney <= 0 or profile.tutorialFlags.rewardsSeen then return end
		profile.tutorialFlags.rewardsSeen = true
	elseif action == "upgradesOpened" then
		if profile.tutorialFlags.upgradesOpened then return end
		profile.tutorialFlags.upgradesOpened = true
	end
	Profiles.fireChanged(player)
end

local function watchMoney(player: Player)
	task.spawn(function()
		local stats = player:WaitForChild("leaderstats", 30)
		local money = stats and stats:WaitForChild("Money", 30)
		if not money or not money:IsA("ValueBase") or not player.Parent then return end
		if moneyConnections[player] then moneyConnections[player]:Disconnect() end
		moneyConnections[player] = (money :: any).Changed:Connect(function()
			local profile = Profiles.has(player) and Profiles.get(player)
			-- Cash only matters for the rebirth half of the tutorial.
			if profile and (profile.tutorialStage == "FreePlay" or profile.tutorialStage == "RebirthReady") then
				queueReconcile(player)
			end
		end)
	end)
end

function TutorialService.start()
	if started then return end
	started = true

	Profiles.beforeChanged(function(player)
		reconcile(player)
	end)
	Remotes.TutorialAction.OnServerEvent:Connect(onAction)

	Players.PlayerAdded:Connect(watchMoney)
	for _, player in Players:GetPlayers() do
		watchMoney(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
		reconcileQueued[player] = nil
		local connection = moneyConnections[player]
		if connection then connection:Disconnect() end
		moneyConnections[player] = nil
	end)
end

return TutorialService
