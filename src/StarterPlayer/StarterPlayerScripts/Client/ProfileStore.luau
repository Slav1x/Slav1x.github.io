--!strict
--[[
	ProfileStore (client)

	A tiny cache of the last ProfileState the server pushed, plus a change
	signal. Every client panel reads from here instead of each one connecting
	to the remote and keeping its own copy, which is how the old shop slots
	ended up unable to see ownership changes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local ProfileStore = {}

local state: {[string]: any} = {
	spinStrength = 0,
	spinGainMultiplier = 1,
	trainingGain = 0,
	rebirthCost = 0,
	rebirthDistance = 0,
	rebirthGainMultiplier = 1,
	rebirthNextGainMultiplier = 1,
	rocksOwned = {},
	rockCounts = {},
	traitedRocks = {},
	abilitiesOwned = {},
	abilityEquipped = nil,
	rockEquippedVariant = "Normal",
	rockEquipped = "pebble",
	rockEquippedInstance = nil,
	petsOwned = {},
	inventoryFavorites = {},
	petEquipped = nil,
	upgrades = {},
	rebirths = 0,
	level = 1,
	xpInto = 0,
	xpNeed = 0,
	bestDistance = 0,
	totalSkips = 0,
	totalThrows = 0,
	modifiers = {},
}

local listeners: {() -> ()} = {}
local received = false

function ProfileStore.get(): {[string]: any}
	return state
end

function ProfileStore.hasLoaded(): boolean
	return received
end

function ProfileStore.onChanged(listener: () -> ())
	table.insert(listeners, listener)
	if received then
		-- Fire immediately for anything that registers after the first push,
		-- so late panels are never stuck showing defaults.
		task.spawn(listener)
	end
end

local function ownsIn(list: {string}?, id: string?): boolean
	if not id or not list then
		return false
	end
	for _, owned in list do
		if owned == id then
			return true
		end
	end
	return false
end

function ProfileStore.ownsRock(id: string?): boolean
	return ownsIn(state.rocksOwned, id)
end

function ProfileStore.rockCount(id: string?): number
	local counts = state.rockCounts
	return if id and typeof(counts) == "table" and typeof(counts[id]) == "number" then counts[id] else 0
end

function ProfileStore.untraitedRockCount(id: string?): number
	if not id then return 0 end
	local count = ProfileStore.rockCount(id)
	for _, copy in state.traitedRocks or {} do
		if copy.rockId == id then count -= 1 end
	end
	return math.max(0, count)
end

function ProfileStore.ownsAbility(id: string?): boolean
	return ownsIn(state.abilitiesOwned, id)
end

function ProfileStore.ownsPet(id: string?): boolean
	return ownsIn(state.petsOwned, id)
end

function ProfileStore.upgradeLevel(id: string): number
	local levels = state.upgrades
	if typeof(levels) == "table" and typeof(levels[id]) == "number" then
		return levels[id]
	end
	return 0
end

Remotes.ProfileState.OnClientEvent:Connect(function(snapshot)
	if typeof(snapshot) ~= "table" then
		return
	end
	state = snapshot
	received = true
	for _, listener in listeners do
		local ok, err = pcall(listener)
		if not ok then
			warn("[ProfileStore] listener failed: " .. tostring(err))
		end
	end
end)

-- Ask for state on load, so a panel built after the join push still fills in.
task.spawn(function()
	for _ = 1, 20 do
		if received then
			return
		end
		Remotes.RequestShopState:FireServer()
		task.wait(0.75)
	end
end)

return ProfileStore

