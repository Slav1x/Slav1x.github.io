--!strict
--[[
	Remotes

	Creates (on the server) or waits for (on the client) every throw
	RemoteEvent, so nothing has to hand-roll WaitForChild chains and the
	client can never accidentally create its own divergent copy -- which is
	what the old SplashEvent/ComboEvent/TierUpEvent setup risked.

	Note that no client -> server remote carries a score. The client reports
	INPUT only; the server measures the outcome itself.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "ThrowRemotes"

local NAMES = {
	"AreaCompleted",
	"MasteryUp",
	"TraitShardFound",
	-- client -> server (input only)
	"ChargeStart",   -- ()
	"ChargeRelease", -- (needleFraction: number, aimDirection: Vector3)
	"AbilityInput", -- (held: boolean) jetpack input only, validated by server
	"FlightAction", -- (throwId): nitro or timed kick; server validates ownership
	"Encounter", -- server -> clients: presentation only
	"Steer",         -- (direction: number) -1 | 0 | 1
	"RequestPurchase",-- (kind: "rock"|"pet"|"upgrade"|"training", id) -- never a price
	"TrainingMode", -- ("off" | "spin" | "afk"); server owns training state and rewards
	"RequestEquip",  -- (kind, rockId, copyId?) -- "untraited" selects the plain stack
	"RequestFavorite", -- (inventory key, starred: boolean)
	"RequestRebirth",-- ()
	"RequestClaimQuest",-- (questId: string)
	"RequestClaimQuestBonus",-- ()
	"RequestQuestState",-- ()
	"RequestLeaderboard",-- ()
	"RequestShopState",-- () -- UI asks on load; avoids racing the join push
	"RequestPromptPass",-- (passKey: string)
	"RequestPromptProduct",-- (productKey: string)
	"RequestSummonTeleport",-- () -- server teleports to the existing SpinButton destination
	"TraitRollRequest",-- (equippedRockId, copyId | "untraited") at the forge
	"TutorialAction",-- (action: "rewardsSeen"|"upgradesOpened"|"skip") -- presentation acks only

	-- server -> client
	"ChargeInfo",    -- (sweetMin, sweetMax)                            [thrower]
	"ThrowAccepted", -- (requestId, throwId) accepted server-side flight [thrower]
	"Skip",          -- (throwerUserId, position, skipIndex, tier, vel) [all]
	"ThrowEnded",    -- ({distance,skips,score,isPerfect,position})     [thrower]
	"MoneyCollected",-- (collectorUserId, {{p,v,g}}, total)            [all]
	"RewardPopup",  -- (kind: "spin", actualGain, worldPosition?)        [owner]
	"ProfileState",  -- (full profile snapshot)                        [owner]
	"TraitRollResult",-- ({ok, rockId?, traitId?, message?})           [owner]
	"ShopResult",    -- (id, ok: boolean, message: string)             [owner]
	"Toast",         -- (message: string, kind: string)                [owner]
	"LevelUp",       -- (level: number)                                [owner]
	"Rebirthed",     -- (userId: number, rebirths: number)              [all]
	"QuestState",    -- ({day, quests = {...}})                        [owner]
	"LeaderboardState",-- ({available, boards = {...}})              [all]
}

-- ThrowAccepted carries only IDs, never an instance. Clients still discover
-- in-flight pebbles through ThrowConfig.PebbleTag after they replicate.

local Remotes = {}

local folder: Instance

if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = ReplicatedStorage
		folder = created
	end

	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

for _, name in NAMES do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes
