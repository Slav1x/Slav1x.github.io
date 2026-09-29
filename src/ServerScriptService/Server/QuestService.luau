--!strict
--[[
	QuestService (server)

	Tracks daily objective progress and pays out claims.

	Progress is reported through one `report(player, metric, amount, mode)`
	entry point that the throw and money systems call. Those systems know
	nothing about quests; the bootstrap wires their existing hooks to this.

	The daily set is derived from the UTC day number rather than stored, so
	every player on every server shares a rotation and rejoining mid-day
	cannot reroll it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestCatalog = require(Shared:WaitForChild("QuestCatalog"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Profiles = require(script.Parent:WaitForChild("Profiles"))

local QuestService = {}

local SECONDS_PER_DAY = 86400
local function bonusReward(rebirths: number): (number, number)
 return math.floor(6000*1.4^math.max(0,rebirths)), math.floor(60*1.15^math.max(0,rebirths))
end

local function currentDay(): number
	return math.floor(os.time() / SECONDS_PER_DAY)
end

-- ============================================================================
-- State, stored on the profile so Persistence picks it up for free
-- ============================================================================

type QuestState = {
	day: number,
	ids: {string},
	progress: {[string]: number},
	claimed: {[string]: boolean},
 bonusClaimed: boolean?,
}

local function blankState(day: number): QuestState
	return {
		day = day,
		ids = QuestCatalog.rollDaily(day),
		progress = {},
		claimed = {},
  bonusClaimed = false,
	}
end

local function stateFor(player: Player): QuestState
	local profile = Profiles.get(player)
	local state = (profile :: any).quests :: QuestState?

	local day = currentDay()
	if not state or typeof(state) ~= "table" or state.day ~= day then
		-- New day (or first ever): fresh set, progress cleared.
		state = blankState(day)
		;(profile :: any).quests = state
	end
	return state :: QuestState
end

function QuestService.snapshot(player: Player): {[string]: any}
	local state = stateFor(player)
	local rebirths = Profiles.get(player).rebirths
	local list = {}

	for _, id in state.ids do
		local quest = QuestCatalog.get(id)
		if quest then
			local target = QuestCatalog.targetFor(quest, rebirths)
			local money, spin = QuestCatalog.rewardFor(quest, rebirths)
			table.insert(list, {
				id = id,
				icon = quest.icon,
				text = QuestCatalog.describe(quest, target),
				progress = math.min(state.progress[id] or 0, target),
				target = target,
				claimed = state.claimed[id] == true,
				rewardMoney = money,
				rewardSpinStrength = spin,
			})
		end
	end

	local bonusMoney,bonusSpin=bonusReward(rebirths)
 return {day = state.day, resetAt = (state.day+1)*SECONDS_PER_DAY, quests = list, bonusClaimed = state.bonusClaimed == true, bonusMoney = bonusMoney, bonusSpinStrength = bonusSpin}
end

local function push(player: Player)
	if player.Parent then
		Remotes.QuestState:FireClient(player, QuestService.snapshot(player))
	end
end

-- ============================================================================
-- Reporting progress
-- ============================================================================

--[[
	`amount` accumulates for "total" quests and is taken as a high-water mark
	for "best" quests -- a 900 stud throw should satisfy "land an 800 stud
	throw" outright rather than adding 900 to a running total.
]]
function QuestService.report(player: Player, metric: string, amount: number)
	if amount <= 0 then
		return
	end
	local state = stateFor(player)
	local changed = false

	for _, id in state.ids do
		local quest = QuestCatalog.get(id)
		if quest and quest.metric == metric and not state.claimed[id] then
			local current = state.progress[id] or 0
			local updated = if quest.mode == "best"
				then math.max(current, amount)
				else current + amount
			if updated ~= current then
				state.progress[id] = updated
				changed = true
			end
		end
	end

	if changed then
		push(player)
	end
end

-- ============================================================================
-- Claiming
-- ============================================================================

local function onClaim(player: Player, questId: unknown)
	if typeof(questId) ~= "string" then
		return
	end
	local profile = Profiles.get(player)
	if not profile.loaded then
		Remotes.Toast:FireClient(player, "Still loading your save", "bad")
		return
	end

	local state = stateFor(player)
	local quest = QuestCatalog.get(questId)
	if not quest then
		return
	end

	-- Must actually be one of today's three.
	local isToday = false
	for _, id in state.ids do
		if id == questId then
			isToday = true
			break
		end
	end
	if not isToday or state.claimed[questId] then
		return
	end

	local target = QuestCatalog.targetFor(quest, profile.rebirths)
	if (state.progress[questId] or 0) < target then
		Remotes.Toast:FireClient(player, "Not finished yet", "bad")
		return
	end

	local money, spin = QuestCatalog.rewardFor(quest, profile.rebirths)
	state.claimed[questId] = true
	Profiles.addMoney(player, money)
 local gainedSpin=Profiles.addSpinStrength(player,spin)

	Remotes.Toast:FireClient(player, string.format("Quest complete  +$%d  +%d Spin Strength", money, math.floor(gainedSpin)), "epic")
	Profiles.fireChanged(player)
	push(player)
end

local function onBonusClaim(player: Player)
 local profile=Profiles.get(player)
 if not profile.loaded then return end
 local state=stateFor(player)
 if state.bonusClaimed then return end
 for _,id in state.ids do
  if state.claimed[id] ~= true then
   Remotes.Toast:FireClient(player,"Claim all three daily quests first","bad")
   return
  end
 end
 state.bonusClaimed=true
 local money,spin=bonusReward(profile.rebirths)
 Profiles.addMoney(player,money)
 local gainedSpin=Profiles.addSpinStrength(player,spin)
 Remotes.Toast:FireClient(player,string.format("Daily bonus! +$%d and +%d Spin Strength",money,math.floor(gainedSpin)),"epic")
 Profiles.fireChanged(player)
 push(player)
end

-- ============================================================================
-- Wiring
-- ============================================================================

function QuestService.start()
	Remotes.RequestClaimQuest.OnServerEvent:Connect(onClaim)
 Remotes.RequestClaimQuestBonus.OnServerEvent:Connect(onBonusClaim)
	Remotes.RequestQuestState.OnServerEvent:Connect(push)

	-- Re-push when the profile changes, since targets and rewards scale with
	-- rebirth count and would otherwise show stale numbers after a rebirth.
	Profiles.onChanged(push)
end

return QuestService
