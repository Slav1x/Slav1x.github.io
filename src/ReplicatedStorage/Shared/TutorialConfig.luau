--!strict
--[[
	TutorialConfig (shared)

	One place for the beginner tutorial's stage order, pacing and copy. The
	server owns which stage a player is in (TutorialService); the client only
	decides how to present that stage (TutorialController).

	Stage flow:
	  SummonRock -> FirstThrow -> LearnRewards -> OpenUpgrades -> BuyUpgrade
	  -> FreePlay (dormant) -> RebirthReady -> Completed

	Every stage is re-derived from real, server-owned profile state, so a
	player who does things early, rejoins, or resets never gets stuck.
]]

export type Stage = string

local TutorialConfig = {}

TutorialConfig.Stages = {
	"SummonRock",
	"FirstThrow",
	"LearnRewards",
	"OpenUpgrades",
	"BuyUpgrade",
	"FreePlay",
	"RebirthReady",
	"Completed",
}

TutorialConfig.Order = {} :: {[string]: number}
for index, stage in TutorialConfig.Stages do
	TutorialConfig.Order[stage] = index
end

-- Player-facing step numbers. Two stages can share a step (open + buy are
-- one idea to the player).
TutorialConfig.Step = {
	SummonRock = 1,
	FirstThrow = 2,
	LearnRewards = 3,
	OpenUpgrades = 4,
	BuyUpgrade = 4,
	RebirthReady = 5,
} :: {[string]: number}
TutorialConfig.TotalSteps = 5

-- Client -> server actions. Anything else is ignored.
TutorialConfig.Actions = {
	rewardsSeen = true,
	upgradesOpened = true,
	skip = true,
} :: {[string]: boolean}
TutorialConfig.ActionCooldown = 0.2

-- The first throw is more forgiving: the server widens the sweet zone.
TutorialConfig.FirstThrowSweetZoneMul = 1.5

-- Upgrade the tutorial recommends first. Throw Power also gates Rebirth.
TutorialConfig.RecommendedUpgrade = "power"

-- Seconds the "Nice skip" explanation stays before acknowledging itself.
TutorialConfig.RewardsAutoAckSeconds = 7
TutorialConfig.UpgradeCelebrationSeconds = 7

-- World fallbacks for StreamingEnabled: markers stay correct even while the
-- real instance is streamed out on the client.
TutorialConfig.Places = {
	SummonWell = Vector3.new(-685, 27, 21.5),
	ThrowDeck = Vector3.new(-534.2, 16, -40.5),
	LakeAim = Vector3.new(-455, 15.2, -40.5),
	Noob = Vector3.new(-720, 41, -40.5) -- Legacy key; now points to the Magical Rock,
}

TutorialConfig.Colors = {
	NavyTop = Color3.fromRGB(18, 48, 79),
	NavyBottom = Color3.fromRGB(5, 19, 39),
	BlueLight = Color3.fromRGB(19, 139, 255),
	BlueDark = Color3.fromRGB(5, 65, 179),
	Rim = Color3.fromRGB(59, 173, 239),
	Gold = Color3.fromRGB(255, 214, 64),
	GoldDeep = Color3.fromRGB(255, 160, 30),
	Green = Color3.fromRGB(59, 228, 116),
	GreenDeep = Color3.fromRGB(16, 160, 90),
	Purple = Color3.fromRGB(175, 117, 244),
	Ink = Color3.fromRGB(6, 17, 34),
	Text = Color3.fromRGB(248, 251, 255),
	Muted = Color3.fromRGB(177, 212, 240),
	Red = Color3.fromRGB(255, 96, 96),
}

TutorialConfig.Images = {
	Studs = "rbxassetid://6927295847",
	Glare = "rbxassetid://71904840558679",
	Pebble = "rbxassetid://84708459117473",
	Cash = "rbxassetid://127824684237342",
	Strength = "rbxassetid://78885528615503",
	Upgrades = "rbxassetid://84352265587966",
	Shop = "rbxassetid://79989192301898",
}

function TutorialConfig.isStage(value: any): boolean
	return type(value) == "string" and TutorialConfig.Order[value] ~= nil
end

function TutorialConfig.before(a: string, b: string): boolean
	return (TutorialConfig.Order[a] or 0) < (TutorialConfig.Order[b] or 0)
end

-- True while the tutorial should actively guide (not dormant or finished).
function TutorialConfig.isGuided(stage: string?): boolean
	return stage ~= nil and stage ~= "FreePlay" and stage ~= "Completed" and TutorialConfig.Order[stage] ~= nil
end

return TutorialConfig

