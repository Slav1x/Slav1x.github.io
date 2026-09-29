--!strict
--[[
	UpgradeCatalog

	Repeatable, levelled money sinks. Rocks are big infrequent purchases;
	upgrades are the thing you dump spare change into between them, which is
	what keeps the collect loop feeling worth doing.

	Costs grow geometrically so they stay relevant as income scales, and every
	effect is bounded -- see the comment on Power, which feeds the one stat
	that can run away.
]]

export type Upgrade = {
	id: string,
	name: string,
	icon: string,
	description: string,
	maxLevel: number,
	baseCost: number,
	costGrowth: number,
	perLevel: number,
}

local UpgradeCatalog = {}
local ProgressionConfig = require(script.Parent.ProgressionConfig)

UpgradeCatalog.Upgrades = {
	{
		id = "power",
		name = "Throw Power",
		icon = "💪",
		description = "+2.5% effective Spin Strength per level",
		maxLevel = 60,
		baseCost = 250,
		costGrowth = 1.20,
		-- Speed is close to linear in distance, unlike bounce retention which
		-- scales as 1/(1-r). Putting the repeatable upgrade on speed keeps a
		-- maxed player strong without the runaway a retention upgrade causes.
		perLevel = 0.025,
	},
	{
		id = "magnet",
		name = "Magnet",
		icon = "🧲",
		description = "+2 studs money pickup radius per level",
		maxLevel = 20,
		baseCost = 200,
		costGrowth = 1.23,
		perLevel = 2,
	},
	{
		id = "luck",
		name = "Luck",
		icon = "🍀",
		description = "+0.3% gold bar chance per level",
		maxLevel = 20,
		baseCost = 450,
		costGrowth = 1.27,
		perLevel = 0.003,
	},
	{
		id = "fortune",
		name = "Fortune",
		icon = "💰",
		description = "+4% money from pickups per level",
		maxLevel = 40,
		baseCost = 325,
		costGrowth = 1.22,
		perLevel = 0.04,
	},
	{
		id = "skill",
		name = "Steady Hand",
		icon = "🎯",
		description = "Widens the perfect zone by 4% per level",
		maxLevel = 12,
		baseCost = 600,
		costGrowth = 1.3,
		perLevel = 0.04,
	},
} :: {Upgrade}

local byId: {[string]: Upgrade} = {}
for _, upgrade in UpgradeCatalog.Upgrades do
	byId[upgrade.id] = upgrade
end

function UpgradeCatalog.get(id: string?): Upgrade?
	if id and byId[id] then
		return byId[id]
	end
	return nil
end

-- Cost of going from `level` to `level + 1`.
function UpgradeCatalog.costAt(upgrade: Upgrade, level: number): number
	-- Later ceilings expand the journey; prices grow more gently after tier 25.
 local n=math.max(0,math.floor(level))
 return math.floor(upgrade.baseCost * upgrade.costGrowth ^ math.min(n,25) * 1.055 ^ math.max(0,n-25))
end

-- The absolute max protects saves; capAt is the ceiling for this journey.
function UpgradeCatalog.capAt(upgrade: Upgrade, rebirths: number?): number
 local r=if type(rebirths)=="number" and rebirths==rebirths then math.clamp(math.floor(rebirths),0,ProgressionConfig.MaxRebirths) else 0
 local caps={power={10,3},magnet={8,2},luck={6,2},fortune={8,4},skill={4,1}}
 local c=caps[upgrade.id]
 return if c then math.min(upgrade.maxLevel,c[1]+c[2]*r) else upgrade.maxLevel
end
function UpgradeCatalog.isMaxed(upgrade: Upgrade, level: number, rebirths: number?): boolean
 return level>=UpgradeCatalog.capAt(upgrade,rebirths)
end

return UpgradeCatalog

