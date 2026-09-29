--!strict
--[[
	Profiles (server)

	One place that owns everything a player has: rocks, pets, upgrade levels,
	rebirths, level/XP and lifetime stats. Money stays in leaderstats because
	the existing MainHUD chip watches it there.

	Every other server system reads derived numbers from `modifiers()` rather
	than reaching into equipment itself, so adding a new buff source (a pet, an
	upgrade, a rebirth bonus, a gamepass) means editing one function instead of
	hunting through the throw and money code.

	Persistence lives in Persistence.luau, which calls load/serialise here.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RockCatalog = require(Shared:WaitForChild("RockCatalog"))
local PetCatalog = require(Shared:WaitForChild("PetCatalog"))
local UpgradeCatalog = require(Shared:WaitForChild("UpgradeCatalog"))
local ProgressionConfig = require(Shared:WaitForChild("ProgressionConfig"))
local CollectionConfig = require(Shared:WaitForChild("CollectionConfig"))
local MonetizationConfig = require(Shared:WaitForChild("MonetizationConfig"))

local Mastery = require(Shared:WaitForChild("MasteryConfig"))
local Profiles = {}

export type Profile = {
	traitShards: number,
	rockMastery: {[string]: any},
	completedAreas: {[string]: boolean},
	cycleCompletedAreas: {[string]: boolean},
	cycleBestDistance: number,
	permanentTitles: {[string]: boolean},
	rocksOwned: {[string]: boolean},
	rockCounts: {[string]: number},
	traitedRocks: {[string]: {rockId: string, traitId: string?, variant: string?}},
	abilitiesOwned: {[string]: boolean},
	abilityEquipped: string?,
	rockEquipped: string,
	rockEquippedInstance: string?,
	petsOwned: {[string]: boolean},
	petCounts: {[string]: number},
	inventoryFavorites: {[string]: boolean},
	petEquipped: string?,
	discoveredRocks: {[string]: boolean},
	discoveredPets: {[string]: boolean},
	discoveredEnchantedRocks: {[string]: boolean},
	discoveredEnchantedPets: {[string]: boolean},
	collectionMilestones: {[string]: boolean},
	friendCount: number,
	passes: {[string]: boolean},
	temporaryCashMultiplier: number,
	dailyBoostExpires: {[string]: number},
	upgrades: {[string]: number},
	rebirths: number,
	spinStrength: number,
	xp: number,
	bestDistance: number,
	totalSkips: number,
	totalThrows: number,
	totalMoney: number,
	-- Daily objective state. Shaped by QuestService; kept here so Persistence
	-- saves it with everything else.
	quests: {[string]: any}?,
	pendingSummon: {[string]: any}?,
	starterRockClaimed: boolean,
	discoveredZones: {[string]: boolean},
	tutorialComplete: boolean,
	-- Beginner tutorial (TutorialService). Stage is re-derived from real state.
	tutorialStage: string,
	tutorialFlags: {[string]: boolean},
	tutorialSkipped: boolean,
	freeSummonUsed: boolean,
	redeemedCodes: {[string]: boolean},
	-- Golden Meridian progress (GoldenMeridianState owns the shape).
	goldenPath: {[string]: any}?,
	loaded: boolean,
}

export type Modifiers = {
	spinStrength: number,
	effectiveStrength: number,
	rebirths: number,
	rockStats: {[string]: number},
	moneyMul: number,
	magnetBonus: number,
	luckBonus: number,
	sweetZoneMul: number,
}

local profiles: {[Player]: Profile} = {}

-- Fired whenever a profile changes, so the client push and the leaderboard
-- do not each have to poll.
local listeners: {(Player) -> ()} = {}
-- Run before listeners, so derived state (the tutorial stage) is already
-- current in the snapshot the change listeners push to the client.
local preChange: {(Player) -> ()} = {}

function Profiles.onChanged(listener: (Player) -> ())
	table.insert(listeners, listener)
end

function Profiles.beforeChanged(hook: (Player) -> ())
	table.insert(preChange, hook)
end

local function syncDiscoveries(profile: Profile)
	for id, owned in profile.rocksOwned do
		if owned and RockCatalog.exists(id) then profile.discoveredRocks[id] = true end
	end
	for _, copy in profile.traitedRocks do
		if copy.variant == "Enchanted" then profile.discoveredEnchantedRocks[copy.rockId] = true end
	end
	for id, owned in profile.petsOwned do
		if owned then profile.discoveredPets[id] = true end
	end
end

function Profiles.fireChanged(player: Player)
	local profile = Profiles.get(player)
	syncDiscoveries(profile)
	Profiles.syncSpinStrength(player)
	player:SetAttribute("RebirthCount", profile.rebirths)
	player:SetAttribute("EquippedAbility", profile.abilityEquipped)
	player:SetAttribute("EquippedRockVariant", Profiles.equippedVariant(profile))
	for _, hook in preChange do
		local ok, err = pcall(hook, player)
		if not ok then
			warn("[Profiles] pre-change hook failed: " .. tostring(err))
		end
	end
	for _, listener in listeners do
		local ok, err = pcall(listener, player)
		if not ok then
			warn("[Profiles] changed listener failed: " .. tostring(err))
		end
	end
end

-- ============================================================================
-- Lifecycle
-- ============================================================================

function Profiles.blank(): Profile
	return {
		-- The starter rock is always owned so a brand new player can throw.
		traitShards = 0,
		rockMastery = {},
		completedAreas = {},
		cycleCompletedAreas = {},
		cycleBestDistance = 0,
		permanentTitles = {},
		rocksOwned = {},
		rockCounts = {},
		traitedRocks = {},
		abilitiesOwned = {},
		abilityEquipped = nil,
		rockEquipped = RockCatalog.Default,
		rockEquippedInstance = nil,
		petsOwned = {},
		petCounts = {},
		inventoryFavorites = {},
		petEquipped = nil,
		discoveredRocks = {},
		discoveredPets = {},
		discoveredEnchantedRocks = {},
		discoveredEnchantedPets = {},
		collectionMilestones = {},
		friendCount = 0,
		passes = {},
		temporaryCashMultiplier = 1,
		dailyBoostExpires = {},
		upgrades = {},
		rebirths = 0,
		spinStrength = ProgressionConfig.StartingSpinStrength,
		xp = 0,
		bestDistance = 0,
		totalSkips = 0,
		totalThrows = 0,
		totalMoney = 0,
		quests = nil,
		starterRockClaimed = false,
		discoveredZones = {driftwood=true},
		tutorialComplete = false,
		tutorialStage = "SummonRock",
		tutorialFlags = {},
		tutorialSkipped = false,
		freeSummonUsed = false,
		redeemedCodes = {},
		loaded = false,
	}
end

function Profiles.get(player: Player): Profile
	local profile = profiles[player]
	if not profile then
		profile = Profiles.blank()
		profiles[player] = profile
	end
	return profile
end

function Profiles.has(player: Player): boolean
	return profiles[player] ~= nil
end

function Profiles.set(player: Player, profile: Profile)
	profiles[player] = profile
end

function Profiles.clear(player: Player)
	profiles[player] = nil
end

-- Each traited copy is separate; rockCounts still records the total of each type.
function Profiles.untraitedCount(profile: Profile, rockId: string): number
	local count = profile.rockCounts[rockId] or (if profile.rocksOwned[rockId] then 1 else 0)
	for _, copy in profile.traitedRocks do
		if copy.rockId == rockId then count -= 1 end
	end
	return math.max(0, count)
end

function Profiles.firstTraitedId(profile: Profile, rockId: string): string?
	local first = nil
	for instanceId, copy in profile.traitedRocks do
		if copy.rockId == rockId and (not first or instanceId < first) then first = instanceId end
	end
	return first
end

function Profiles.selectRock(profile: Profile, rockId: string, instanceId: string?): boolean
	if not profile.rocksOwned[rockId] then return false end
	if instanceId == "untraited" then
		if Profiles.untraitedCount(profile, rockId) < 1 then return false end
		profile.rockEquippedInstance = nil
	elseif instanceId ~= nil then
		local copy = profile.traitedRocks[instanceId]
		if not copy or copy.rockId ~= rockId then return false end
		profile.rockEquippedInstance = instanceId
	elseif Profiles.untraitedCount(profile, rockId) > 0 then
		profile.rockEquippedInstance = nil
	else
		local first = Profiles.firstTraitedId(profile, rockId)
		if not first then return false end
		profile.rockEquippedInstance = first
	end
	profile.rockEquipped = rockId
	return true
end

function Profiles.copyTraited(profile: Profile): {[string]: {rockId: string, traitId: string?, variant: string?}}
	local copy = {}
	for instanceId, value in profile.traitedRocks do
		copy[instanceId] = {rockId = value.rockId, traitId = value.traitId, variant = value.variant == "Enchanted" and "Enchanted" or "Normal", mastered=value.mastered == true}
	end
	return copy
end

-- Variant identity shares the existing per-copy inventory: normal copies stack,
-- while enchanted or traited copies retain a stable ID throughout their life.
function Profiles.equippedVariant(profile: Profile): string
	local copy = profile.rockEquippedInstance and profile.traitedRocks[profile.rockEquippedInstance]
	return copy and copy.variant == "Enchanted" and "Enchanted" or "Normal"
end

function Profiles.addRock(profile: Profile, rockId: string, variant: string?): (string?, number)
	assert(RockCatalog.exists(rockId), "Unknown collectible rock")
	assert(rockId ~= "hermes_rock" and rockId ~= "jetpack_rock", "Abilities are not collectible rocks")
	local count = (profile.rockCounts[rockId] or (profile.rocksOwned[rockId] and 1 or 0)) + 1
	profile.rocksOwned[rockId] = true
	profile.rockCounts[rockId] = count
	profile.discoveredRocks[rockId] = true
	local instanceId = nil
	if variant == "Enchanted" then
		instanceId = HttpService:GenerateGUID(false)
		profile.traitedRocks[instanceId] = {rockId = rockId, variant = "Enchanted"}
		profile.discoveredEnchantedRocks[rockId] = true
	end
	return instanceId, count
end

-- A normal stack copy gains identity on its first accepted throw. This extends
-- the existing individual-copy inventory instead of maintaining another inventory.
function Profiles.ensureMasteryCopy(profile: Profile): string?
 local id = profile.rockEquippedInstance
 if id and profile.traitedRocks[id] then
  profile.traitedRocks[id].mastered = true
 elseif Profiles.untraitedCount(profile,profile.rockEquipped) > 0 then
  id = HttpService:GenerateGUID(false)
  profile.traitedRocks[id] = {rockId=profile.rockEquipped,variant="Normal",mastered=true}
  if profile.inventoryFavorites["rock:"..profile.rockEquipped] then
   profile.inventoryFavorites["traited:"..id] = true
   if Profiles.untraitedCount(profile,profile.rockEquipped)==0 then profile.inventoryFavorites["rock:"..profile.rockEquipped]=nil end
  end
  profile.rockEquippedInstance = id
 else
  return nil
 end
 profile.rockMastery[id] = profile.rockMastery[id] or {xp=0,best=0,throws=0}
 return id
end
function Profiles.masteryLevel(profile: Profile): number
 local record = profile.rockEquippedInstance and profile.rockMastery[profile.rockEquippedInstance]
 return Mastery.level(record and record.xp)
end

-- ============================================================================
-- Money (kept in leaderstats so the existing HUD chip keeps working)
-- ============================================================================

function Profiles.moneyValue(player: Player): IntValue?
	local stats = player:FindFirstChild("leaderstats")
	local money = stats and stats:FindFirstChild("Money")
	if money and money:IsA("IntValue") then
		return money
	end
	return nil
end

function Profiles.getMoney(player: Player): number
	local money = Profiles.moneyValue(player)
	return money and money.Value or 0
end

function Profiles.addMoney(player: Player, amount: number)
	local money = Profiles.moneyValue(player)
	if not money then
		return
	end
	if not ProgressionConfig.isFinite(amount) then return end
	amount = math.floor(amount)
	money.Value = math.clamp(money.Value + amount, 0, 9e15)
	if amount > 0 then
		Profiles.get(player).totalMoney += amount
	end
end

function Profiles.trySpend(player: Player, amount: number): boolean
	local money = Profiles.moneyValue(player)
	if not ProgressionConfig.isFinite(amount) or amount < 0 or amount % 1 ~= 0 or not money or money.Value < amount then
		return false
	end
	money.Value -= amount
	return true
end

-- Strength is owned by the profile; the legacy Strength value is a display mirror.
function Profiles.syncSpinStrength(player: Player)
 local profile=Profiles.get(player)
 profile.spinStrength=ProgressionConfig.normalizeSpinStrength(profile.spinStrength,profile.rebirths)
 local stats=player:FindFirstChild("leaderstats")
 local value=stats and stats:FindFirstChild("Strength")
 if value and value:IsA("NumberValue") then value.Value=profile.spinStrength end
end
function Profiles.addSpinStrength(player: Player,amount: number): number
 local profile=Profiles.get(player)
 if not profile.loaded or not ProgressionConfig.isFinite(amount) or amount<=0 then return 0 end
 local before=ProgressionConfig.normalizeSpinStrength(profile.spinStrength)
 -- At astronomical values, keep a positive reward from rounding to no change.
 -- This is one representable increment, not a percentage-based growth bonus.
 if before+amount==before then amount=math.max(amount,before*2^-52) end
 local cap=ProgressionConfig.strengthCap(profile.rebirths)
 local after=math.min(cap,before+math.min(amount,math.max(0,cap-before)))
 profile.spinStrength=after
 Profiles.syncSpinStrength(player)
 return after-before
end

-- ============================================================================
-- Level / XP
-- ============================================================================

function Profiles.levelFor(xp: number): number
	local level = 1
	local remaining = xp
	while level < ProgressionConfig.MaxLevel do
		local need = ProgressionConfig.xpForLevel(level)
		if remaining < need then
			break
		end
		remaining -= need
		level += 1
	end
	return level
end

function Profiles.xpIntoLevel(xp: number): (number, number)
	local level = 1
	local remaining = xp
	while level < ProgressionConfig.MaxLevel do
		local need = ProgressionConfig.xpForLevel(level)
		if remaining < need then
			return remaining, need
		end
		remaining -= need
		level += 1
	end
	return 0, 0
end

function Profiles.addXp(player: Player, amount: number): (number, number)
	local profile = Profiles.get(player)
	local before = Profiles.levelFor(profile.xp)
	profile.xp += math.max(math.floor(amount), 0)
	local after = Profiles.levelFor(profile.xp)
	return before, after
end

-- ============================================================================
-- Derived modifiers -- the single place buffs are combined
-- ============================================================================

function Profiles.dailyBoostActive(profile: Profile, kind: string): boolean
	local expires = profile.dailyBoostExpires and profile.dailyBoostExpires[kind]
	return type(expires) == "number" and expires > os.time()
end

function Profiles.upgradeLevel(player: Player, id: string): number
	return Profiles.get(player).upgrades[id] or 0
end

local function trueCount(map: {[string]: boolean}): number
	local count = 0
	for id, value in map do if value and RockCatalog.exists(id) then count += 1 end end
	return count
end

local function cashComponents(player: Player)
	local profile = Profiles.get(player)
	local rock = RockCatalog.get(profile.rockEquipped)
	local pet = PetCatalog.get(profile.petEquipped)
	local fortune = profile.upgrades.fortune or 0
	local fortuneUpgrade = UpgradeCatalog.get("fortune")
	local equippedCopy = profile.rockEquippedInstance and profile.traitedRocks[profile.rockEquippedInstance]
 local specialty = RockCatalog.resolveStats(profile.rockEquipped, equippedCopy and equippedCopy.traitId, Profiles.equippedVariant(profile))
 local equipmentBonus = rock.moneyBonus + Profiles.masteryLevel(profile)*0.005
		+ fortune * (fortuneUpgrade and fortuneUpgrade.perLevel or 0)
		+ (pet and pet.moneyBonus or 0)
		+ profile.rebirths * ProgressionConfig.RebirthMoneyBonus
		+ (Profiles.levelFor(profile.xp) - 1) * ProgressionConfig.LevelMoneyBonus
	local friendBonus = CollectionConfig.friendBonus(profile.friendCount or 0)
	local collectionBonus = CollectionConfig.rockBonus(trueCount(profile.discoveredRocks))
	local additive = equipmentBonus + friendBonus + collectionBonus
	local passFactor = 1
	local passAdditive = 0
	local breakdown = {
		{label = "Base", kind = "base", value = 1},
	}
	if equipmentBonus ~= 0 then table.insert(breakdown, {label = "Equipment & Progress", kind = "add", value = equipmentBonus}) end
	table.insert(breakdown, {label = "Friend Boost", kind = "add", value = friendBonus})
	table.insert(breakdown, {label = "Rock Index", kind = "add", value = collectionBonus})
	for _, pass in MonetizationConfig.Passes do
		if profile.passes[pass.key] and pass.moneyBonus ~= 0 then
			if pass.key == "double_money" then
				local factor = 1 + pass.moneyBonus
				passFactor *= factor
				table.insert(breakdown, {label = pass.name, kind = "mul", value = factor})
			else
				passAdditive += pass.moneyBonus
				table.insert(breakdown, {label = pass.name, kind = "add", value = pass.moneyBonus})
			end
		end
	end
	additive += passAdditive
	local temporary = math.max(profile.temporaryCashMultiplier or 1, 1)
	if temporary > 1 then table.insert(breakdown, {label = "Temporary Boost", kind = "mul", value = temporary}) end
	local dailyCash = Profiles.dailyBoostActive(profile, "cash") and 2 or 1
	if dailyCash > 1 then table.insert(breakdown, {label = "Daily 2x Cash", kind = "mul", value = dailyCash}) end
	local traitCash = 1+(specialty.moneyBonus or 0)
	if traitCash ~= 1 then table.insert(breakdown, {label = "Trait", kind = "mul", value = traitCash}) end
	local total = math.max(1, (1 + additive) * passFactor * temporary * traitCash * dailyCash)
	table.insert(breakdown, {label = "TOTAL", kind = "total", value = total})
	return total, breakdown
end

function Profiles.cashBreakdown(player: Player)
	local total, breakdown = cashComponents(player)
	return total, breakdown
end

function Profiles.modifiers(player: Player): Modifiers
	local profile = Profiles.get(player)
	local rock = RockCatalog.get(profile.rockEquipped)
	local pet = PetCatalog.get(profile.petEquipped)
	local function levelOf(id: string): number
  local upgrade=UpgradeCatalog.get(id)
  local value=profile.upgrades[id]
  return upgrade and ProgressionConfig.isFinite(value) and math.clamp(math.floor(value),0,UpgradeCatalog.capAt(upgrade,profile.rebirths)) or 0
 end
	local function perLevel(id: string): number
		local upgrade = UpgradeCatalog.get(id)
		return upgrade and upgrade.perLevel or 0
	end
	local passSpeed, passMagnet, passLuck = 0, 0, 0
	for _, pass in MonetizationConfig.Passes do
		if profile.passes[pass.key] then
			passSpeed += pass.speedBonus
			passMagnet += pass.magnetBonus
			passLuck += pass.luckBonus
		end
	end
	local totalCash = cashComponents(player)
 local copy=profile.rockEquippedInstance and profile.traitedRocks[profile.rockEquippedInstance]
 local traitId=copy and copy.rockId==profile.rockEquipped and copy.traitId or nil
 local rockStats=RockCatalog.resolveStats(profile.rockEquipped,traitId,Profiles.equippedVariant(profile))
 local spinStrength=ProgressionConfig.normalizeSpinStrength(profile.spinStrength)
 -- Existing pet/pass/power bonuses amplify progression before its safe physics curve.
 local equipmentMultiplier=math.max(1,1+levelOf("power")*perLevel("power")+(pet and pet.speedBonus or 0)+passSpeed+Profiles.masteryLevel(profile)*0.005)
 local effectiveStrength=ProgressionConfig.safeProduct(ProgressionConfig.safeProduct(spinStrength,rockStats.strengthMultiplier),equipmentMultiplier)
	return {
  spinStrength=spinStrength,
  effectiveStrength=effectiveStrength,
  rockStats=rockStats,
  rebirths=profile.rebirths,
		moneyMul = totalCash - 1,
		magnetBonus = levelOf("magnet") * perLevel("magnet") + (pet and pet.magnetBonus or 0) + passMagnet,
		luckBonus = levelOf("luck") * perLevel("luck") + (pet and pet.luckBonus or 0) + passLuck,
		sweetZoneMul = (1 + levelOf("skill") * perLevel("skill")) * (rockStats.sweetZoneMultiplier or 1),
	}
end

-- ============================================================================
-- Client-facing snapshot
-- ============================================================================

local function keyList(map: {[string]: boolean}): {string}
	local list = {}
	for id, owned in map do
		if owned then
			table.insert(list, id)
		end
	end
	return list
end

local function collectibleKeyList(map: {[string]: boolean}): {string}
	local list = {}
	for id, owned in map do
		if owned and RockCatalog.exists(id) then table.insert(list, id) end
	end
	return list
end

function Profiles.snapshot(player: Player): {[string]: any}
	local profile = Profiles.get(player)
	syncDiscoveries(profile)
	local into, need = Profiles.xpIntoLevel(profile.xp)
	local cashMultiplier, cashBreakdown = Profiles.cashBreakdown(player)
 local upgradeCaps = {}
 for _, upgrade in UpgradeCatalog.Upgrades do upgradeCaps[upgrade.id]=UpgradeCatalog.capAt(upgrade,profile.rebirths) end
 local ready, reason = ProgressionConfig.canRebirth(profile,Profiles.getMoney(player))
 return {
  traitShards = profile.traitShards,
  rockMastery = profile.rockMastery,
  mastery = Mastery.progress(profile.rockEquippedInstance and profile.rockMastery[profile.rockEquippedInstance]),
  completedAreas = table.clone(profile.completedAreas),
  cycleCompletedAreas = table.clone(profile.cycleCompletedAreas),
  cycleBestDistance = profile.cycleBestDistance,
  permanentTitles = keyList(profile.permanentTitles),
  strengthCap = ProgressionConfig.strengthCap(profile.rebirths),
  nextStrengthCap = ProgressionConfig.strengthCap(profile.rebirths+1),
  upgradeCaps = upgradeCaps,
  rebirthReady = ready,
  rebirthReason = reason,
  rebirthRequirement = ProgressionConfig.rebirthRequirements(profile.rebirths),
		loaded = profile.loaded == true,
		hasPendingSummon = profile.pendingSummon ~= nil,
		starterRockClaimed = profile.starterRockClaimed == true,
		introSummonAvailable = #collectibleKeyList(profile.rocksOwned) == 0 and profile.freeSummonUsed ~= true,
		discoveredZones = keyList(profile.discoveredZones),
		tutorialComplete = profile.tutorialComplete == true,
		tutorial = {
			stage = profile.tutorialStage,
			skipped = profile.tutorialSkipped == true,
			flags = table.clone(profile.tutorialFlags),
		},
		totalMoney = profile.totalMoney,
		rocksOwned = collectibleKeyList(profile.rocksOwned),
		rockCounts = profile.rockCounts,
		traitedRocks = Profiles.copyTraited(profile),
		rockEquipped = profile.rockEquipped,
		rockEquippedInstance = profile.rockEquippedInstance,
		rockEquippedVariant = Profiles.equippedVariant(profile),
		abilitiesOwned = keyList(profile.abilitiesOwned),
		abilityEquipped = profile.abilityEquipped,
		petsOwned = keyList(profile.petsOwned),
		petCounts = table.clone(profile.petCounts),
		petEquipped = profile.petEquipped,
		inventoryFavorites = table.clone(profile.inventoryFavorites),
		discoveredRocks = collectibleKeyList(profile.discoveredRocks),
		discoveredPets = keyList(profile.discoveredPets),
		discoveredEnchantedRocks = collectibleKeyList(profile.discoveredEnchantedRocks),
		discoveredEnchantedPets = keyList(profile.discoveredEnchantedPets),
		collectionMilestones = table.clone(profile.collectionMilestones),
		friendCount = profile.friendCount,
		passes = table.clone(profile.passes),
		cashMultiplier = cashMultiplier,
		cashBreakdown = cashBreakdown,
		dailyBoostExpires = table.clone(profile.dailyBoostExpires),
		upgrades = profile.upgrades,
		rebirths = profile.rebirths,
  spinStrength=ProgressionConfig.normalizeSpinStrength(profile.spinStrength),
  spinGainMultiplier=ProgressionConfig.spinGainMultiplier(profile.spinStrength,profile.rebirths),
  trainingGain=ProgressionConfig.trainingGain(profile.spinStrength,profile.rebirths),
  rebirthCost=ProgressionConfig.rebirthCost(profile.rebirths),
  rebirthDistance=ProgressionConfig.rebirthDistance(profile.rebirths),
  rebirthGainMultiplier=ProgressionConfig.rebirthGainMultiplier(profile.rebirths),
  rebirthNextGainMultiplier=ProgressionConfig.rebirthGainMultiplier(profile.rebirths+1),
		level = Profiles.levelFor(profile.xp),
		xpInto = into,
		xpNeed = need,
		bestDistance = profile.bestDistance,
		totalSkips = profile.totalSkips,
		totalThrows = profile.totalThrows,
		modifiers = Profiles.modifiers(player),
	}
end

Players.PlayerRemoving:Connect(function(player)
	-- Persistence hooks PlayerRemoving too and runs first (connected earlier),
	-- so the profile is still here when it saves.
	task.defer(function()
		Profiles.clear(player)
	end)
end)

return Profiles
