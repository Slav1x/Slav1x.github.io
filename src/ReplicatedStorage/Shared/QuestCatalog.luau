--!strict
--[[
	QuestCatalog

	Daily objectives. Three at a time, rerolled once a day, each one a
	different metric so they cannot all be finished by the same throw.

	Targets scale with the player's rebirth count rather than being fixed, so
	"collect 5,000 money" stays a real ask at rebirth 6 instead of being
	cleared by a single throw.
]]

export type Quest = {
	id: string,
	metric: string,
	name: string,
	icon: string,
	-- baseTarget is for a rebirth-0 player; scale is applied per rebirth.
	baseTarget: number,
	scale: number,
	rewardMoney: number,
	rewardSpinStrength: number,
	-- "total" accumulates across throws; "best" wants one throw to hit it.
	mode: string,
}

local QuestCatalog = {}

QuestCatalog.DailyCount = 3

QuestCatalog.Quests = {
	{
		id = "throw_20", metric = "throws", mode = "total",
		name = "Skip %d stones", icon = "Rock",
		baseTarget = 20, scale = 1.15, rewardMoney = 900, rewardSpinStrength = 12,
	},
	{
		id = "throw_60", metric = "throws", mode = "total",
		name = "Skip %d stones", icon = "Rock",
		baseTarget = 60, scale = 1.15, rewardMoney = 2600, rewardSpinStrength = 32,
	},
	{
		id = "far_800", metric = "distance", mode = "best",
		name = "Land a %d stud throw", icon = "Rock",
		baseTarget = 800, scale = 1.1, rewardMoney = 1500, rewardSpinStrength = 20,
	},
	{
		id = "far_1200", metric = "distance", mode = "best",
		name = "Land a %d stud throw", icon = "Rock",
		baseTarget = 1200, scale = 1.1, rewardMoney = 3200, rewardSpinStrength = 40,
	},
	{
		id = "skips_35", metric = "skips_single", mode = "best",
		name = "Get %d skips in one throw", icon = "Rock",
		baseTarget = 35, scale = 1.08, rewardMoney = 1400, rewardSpinStrength = 19,
	},
	{
		id = "skips_55", metric = "skips_single", mode = "best",
		name = "Get %d skips in one throw", icon = "Rock",
		baseTarget = 55, scale = 1.08, rewardMoney = 3000, rewardSpinStrength = 38,
	},
	{
		id = "money_5k", metric = "money", mode = "total",
		name = "Collect $%d", icon = "Cash",
		baseTarget = 5000, scale = 1.45, rewardMoney = 1800, rewardSpinStrength = 22,
	},
	{
		id = "money_20k", metric = "money", mode = "total",
		name = "Collect $%d", icon = "Cash",
		baseTarget = 20000, scale = 1.45, rewardMoney = 5200, rewardSpinStrength = 52,
	},
	{
		id = "gold_10", metric = "gold", mode = "total",
		name = "Grab %d gold bars", icon = "Gold",
		baseTarget = 10, scale = 1.25, rewardMoney = 2400, rewardSpinStrength = 30,
	},
	{
		id = "perfect_8", metric = "perfects", mode = "total",
		name = "Nail %d perfect releases", icon = "Skill",
		baseTarget = 8, scale = 1.12, rewardMoney = 2200, rewardSpinStrength = 34,
	},
	{
		id = "boom_5", metric = "booms", mode = "total",
		name = "Break the sound barrier %d times", icon = "Power",
		baseTarget = 5, scale = 1.12, rewardMoney = 2800, rewardSpinStrength = 38,
	},
}

local byId: {[string]: Quest} = {}
for _, quest in QuestCatalog.Quests do
	byId[quest.id] = quest
end

function QuestCatalog.get(id: string?): Quest?
	if id and byId[id] then
		return byId[id]
	end
	return nil
end

function QuestCatalog.targetFor(quest: Quest, rebirths: number): number
	return math.floor(quest.baseTarget * quest.scale ^ math.max(rebirths, 0))
end

function QuestCatalog.rewardFor(quest: Quest, rebirths: number): (number, number)
	-- Rewards scale with the same curve as the target, so a harder daily is
	-- worth proportionally more rather than becoming a worse deal over time.
	local factor = quest.scale ^ math.max(rebirths, 0)
	return math.floor(quest.rewardMoney * factor), math.floor(quest.rewardSpinStrength * factor)
end

function QuestCatalog.describe(quest: Quest, target: number): string
	return string.format(quest.name, target)
end

--[[
	Picks DailyCount distinct quests with distinct metrics, seeded by the day
	so every player on every server gets the same rotation and it is stable
	across rejoins without needing to be saved.
]]
function QuestCatalog.rollDaily(daySeed: number): {string}
	local random = Random.new(daySeed)
	local pool = table.clone(QuestCatalog.Quests)

	-- Fisher-Yates with the seeded generator.
	for i = #pool, 2, -1 do
		local j = random:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end

	local chosen = {}
	local usedMetrics: {[string]: boolean} = {}
	for _, quest in pool do
		if not usedMetrics[quest.metric] then
			usedMetrics[quest.metric] = true
			table.insert(chosen, quest.id)
			if #chosen >= QuestCatalog.DailyCount then
				break
			end
		end
	end
	return chosen
end

return QuestCatalog
