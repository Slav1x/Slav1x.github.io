--!strict
--[[
	Persistence (server)

	Saves and loads Profiles through DataStoreService.

	Deliberate choices:
	  - Money is stored here even though it lives in leaderstats at runtime,
	    because leaderstats is a display surface, not storage.
	  - A profile is marked `loaded` only after the read resolves (or is known
	    to have failed). ShopService refuses to spend before that, so a slow
	    read can never let a player buy against a balance that is about to be
	    overwritten.
	  - If a load FAILS (as opposed to returning nothing for a new player) the
	    profile is left unloaded and locked rather than silently replaced with
	    a blank one. Handing someone a fresh save because DataStore hiccuped
	    is how people lose hours of progress.
	  - Writes are throttled and also flushed on leave and on BindToClose.

	DataStore does not work in Studio unless "Enable Studio Access to API
	Services" is on, so every call is wrapped and failure is survivable: the
	game stays fully playable, it just will not remember anything.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local TraitCatalog = require(ReplicatedStorage.Shared:WaitForChild("TraitCatalog"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local ApiHealth = require(script.Parent:WaitForChild("ApiHealth"))

local Cleanup = require(script.Parent:WaitForChild("InventoryCleanup"))
local Persistence = {}
local ProgressionConfig=require(ReplicatedStorage.Shared.ProgressionConfig)
local UpgradeCatalog=require(ReplicatedStorage.Shared.UpgradeCatalog)

local STORE_NAME = "PebbleSkipping"
local STORE_VERSION = "v1"
local AUTOSAVE_INTERVAL = 90

local store: DataStore? = nil
local storeOk = false
local lastSave: {[Player]: number} = {}

local LOAD_ATTEMPTS = 4
local writing = {}
function Persistence.isWriting(player: Player): boolean return writing[player]==true end

local function keyFor(player: Player): string
	return STORE_VERSION .. "_" .. player.UserId
end

-- ============================================================================
-- Serialisation
--
-- Stored as plain arrays/maps of primitives. Catalog ids are strings, so a
-- save stays valid when rock or pet ORDER changes -- only renaming an id
-- breaks it, which is why ids and display names are separate fields.
-- ============================================================================

local function serialise(player: Player, heldProfile: Profiles.Profile?): {[string]: any}
	local profile = heldProfile or Profiles.get(player)
	Cleanup.apply(profile)
	return {
		money = Profiles.getMoney(player),
 redeemedCodes = table.clone(profile.redeemedCodes),
 spinStrength = ProgressionConfig.normalizeSpinStrength(profile.spinStrength),
 dailyBoostExpires = table.clone(profile.dailyBoostExpires),
 progressionVersion = 3,
 traitShards = profile.traitShards,
 rockMastery = profile.rockMastery,
 completedAreas = table.clone(profile.completedAreas),
 cycleCompletedAreas = table.clone(profile.cycleCompletedAreas),
 cycleBestDistance = profile.cycleBestDistance,
 permanentTitles = table.clone(profile.permanentTitles),
		rocksOwned = table.clone(profile.rocksOwned),
		rockCounts = table.clone(profile.rockCounts),
		traitedRocks = Profiles.copyTraited(profile),
		rockEquippedInstance = profile.rockEquippedInstance,
		abilitiesOwned = table.clone(profile.abilitiesOwned),
		abilityEquipped = profile.abilityEquipped,
		pendingSummon = require(game.ServerScriptService.GeodeProgression).restore(profile.pendingSummon),
		starterRockClaimed = profile.starterRockClaimed == true,
		discoveredZones = table.clone(profile.discoveredZones),
		tutorialComplete = profile.tutorialComplete == true,
		tutorialStage = profile.tutorialStage,
		tutorialFlags = table.clone(profile.tutorialFlags or {}),
		tutorialSkipped = profile.tutorialSkipped == true,
		freeSummonUsed = profile.freeSummonUsed == true,
		rockEquipped = profile.rockEquipped,
		petsOwned = table.clone(profile.petsOwned),
		petCounts = table.clone(profile.petCounts),
		petEquipped = profile.petEquipped,
		inventoryFavorites = table.clone(profile.inventoryFavorites),
		discoveredRocks = table.clone(profile.discoveredRocks),
		discoveredPets = table.clone(profile.discoveredPets),
		discoveredEnchantedRocks = table.clone(profile.discoveredEnchantedRocks),
		discoveredEnchantedPets = table.clone(profile.discoveredEnchantedPets),
		collectionMilestones = table.clone(profile.collectionMilestones),
		upgrades = table.clone(profile.upgrades),
		rebirths = profile.rebirths,
		xp = profile.xp,
		bestDistance = profile.bestDistance,
		totalSkips = profile.totalSkips,
		totalThrows = profile.totalThrows,
		totalMoney = profile.totalMoney,
		quests = profile.quests,
	}
end

local function deserialise(data: {[string]: any}): Profiles.Profile
	local profile = Profiles.blank()
 -- Existing saves used strength; canonical saves now keep only spinStrength.
 local savedStrength=ProgressionConfig.isFinite(data.spinStrength) and data.spinStrength or data.strength
 profile.spinStrength=ProgressionConfig.normalizeSpinStrength(savedStrength)
 if type(data.dailyBoostExpires) == "table" then
  local now = os.time()
  for _,kind in {"cash","spin","summon"} do
   local expiry = data.dailyBoostExpires[kind]
   if type(expiry) == "number" and expiry == expiry and expiry > now and expiry <= now + 86400 then
    profile.dailyBoostExpires[kind] = math.floor(expiry)
   end
  end
 end
	local AbilityCatalog = require(ReplicatedStorage.Shared.AbilityCatalog)
	for _, ability in AbilityCatalog.Abilities do
		if type(data.abilitiesOwned) == "table" and data.abilitiesOwned[ability.id] == true then
			profile.abilitiesOwned[ability.id] = true
		end
	end
	if type(data.abilityEquipped) == "string" and profile.abilitiesOwned[data.abilityEquipped] then
		profile.abilityEquipped = data.abilityEquipped
	end
 if typeof(data.redeemedCodes)=='table' then for id,claimed in data.redeemedCodes do if type(id)=='string' and claimed==true then profile.redeemedCodes[id]=true end end end
	profile.pendingSummon = require(game.ServerScriptService:WaitForChild("GeodeProgression")).restore(data.pendingSummon)
	profile.starterRockClaimed = data.starterRockClaimed == true
	profile.tutorialComplete = data.tutorialComplete == true or (tonumber(data.totalThrows) or 0)>0
	local ZoneConfig = require(game.ReplicatedStorage.Shared.ZoneConfig)
	profile.discoveredZones = {driftwood=true}
	for _,zone in ipairs(ZoneConfig.List) do
		if type(data.discoveredZones)=="table" and data.discoveredZones[zone.id]==true then profile.discoveredZones[zone.id]=true end
	end
	profile.freeSummonUsed = data.freeSummonUsed == true

	if typeof(data.rocksOwned) == "table" then
		for id, owned in data.rocksOwned do
			if typeof(id) == "string" and owned == true then
				profile.rocksOwned[id] = true
			end
		end
	end
	if typeof(data.rockCounts) == "table" then
		for id, count in data.rockCounts do
			if typeof(id) == "string" and typeof(count) == "number" then
				profile.rockCounts[id] = math.max(math.floor(count), 1)
			end
		end
	end
	-- Older saves stored ownership only, so every owned rock starts at one copy.
	for id, owned in profile.rocksOwned do
		if owned and not profile.rockCounts[id] then profile.rockCounts[id] = 1 end
	end
	-- A traited copy uses one unit from rockCounts; ordinary copies remain stacked.
	local used: {[string]: number} = {}
	if typeof(data.traitedRocks) == "table" then
		for instanceId, copy in data.traitedRocks do
			if typeof(instanceId) == "string" and #instanceId <= 64 and instanceId ~= "untraited"
				and typeof(copy) == "table" and typeof(copy.rockId) == "string"
				and profile.rocksOwned[copy.rockId] and (TraitCatalog.get(copy.traitId) or copy.variant == "Enchanted" or copy.mastered == true)
				and (used[copy.rockId] or 0) < (profile.rockCounts[copy.rockId] or 0) then
				profile.traitedRocks[instanceId] = {rockId = copy.rockId, traitId = TraitCatalog.get(copy.traitId) and copy.traitId or nil, variant = copy.variant == "Enchanted" and "Enchanted" or "Normal", mastered=copy.mastered == true}
				used[copy.rockId] = (used[copy.rockId] or 0) + 1
			end
		end
	end
	-- Convert last version's type-wide trait into one specific saved copy.
	local migrated: {[string]: string} = {}
	if typeof(data.rockTraits) == "table" then
		for rockId, traitId in data.rockTraits do
			if typeof(rockId) == "string" and profile.rocksOwned[rockId] and TraitCatalog.get(traitId)
				and (used[rockId] or 0) == 0 and (profile.rockCounts[rockId] or 0) > 0 then
				local instanceId = HttpService:GenerateGUID(false)
				profile.traitedRocks[instanceId] = {rockId = rockId, traitId = traitId}
				migrated[rockId] = instanceId
				used[rockId] = 1
			end
		end
	end
	if typeof(data.rockEquipped) == "string" then
		profile.rockEquipped = data.rockEquipped
	end
	local equippedInstance = if typeof(data.rockEquippedInstance) == "string" then data.rockEquippedInstance else migrated[profile.rockEquipped]
	if not Profiles.selectRock(profile, profile.rockEquipped, equippedInstance) then
		if not Profiles.selectRock(profile, profile.rockEquipped, nil) then
			Profiles.selectRock(profile, "pebble", nil)
		end
	end
	if typeof(data.petsOwned) == "table" then
		for id, owned in data.petsOwned do
			if typeof(id) == "string" and owned == true then
				profile.petsOwned[id] = true
			end
		end
	end
	if typeof(data.petCounts) == "table" then
		for id, count in data.petCounts do
			if typeof(id) == "string" and profile.petsOwned[id] and type(count) == "number" and count == count then
				profile.petCounts[id] = math.clamp(math.floor(count), 1, 1000000)
			end
		end
	end
	for id in profile.petsOwned do profile.petCounts[id] = profile.petCounts[id] or 1 end
	if typeof(data.petEquipped) == "string" then
		profile.petEquipped = data.petEquipped
	end
	local function loadFlags(source: any, target: {[string]: boolean})
		if typeof(source) ~= "table" then return end
		for id, value in source do
			if typeof(id) == "string" and value == true then target[id] = true end
		end
	end
	loadFlags(data.discoveredRocks, profile.discoveredRocks)
	loadFlags(data.discoveredPets, profile.discoveredPets)
	loadFlags(data.discoveredEnchantedRocks, profile.discoveredEnchantedRocks)
	loadFlags(data.discoveredEnchantedPets, profile.discoveredEnchantedPets)
	loadFlags(data.collectionMilestones, profile.collectionMilestones)
	if typeof(data.inventoryFavorites) == "table" then
		for key, starred in data.inventoryFavorites do
			if typeof(key) == "string" and #key <= 100 and starred == true then
				local rockId = string.match(key, "^rock:([%w_]+)$")
				local petId = string.match(key, "^pet:([%w_]+)$")
				local copyId = string.match(key, "^traited:(.+)$")
				local abilityId = string.match(key, "^ability:([%w_]+)$")
				if (rockId and profile.rocksOwned[rockId] and Profiles.untraitedCount(profile, rockId) > 0)
					or (petId and profile.petsOwned[petId])
					or (copyId and profile.traitedRocks[copyId])
					or (abilityId and profile.abilitiesOwned[abilityId]) then
					profile.inventoryFavorites[key] = true
				end
			end
		end
	end
	-- Migration: everything currently owned was legitimately discovered.
	for id, owned in profile.rocksOwned do if owned then profile.discoveredRocks[id] = true end end
	for id, owned in profile.petsOwned do if owned then profile.discoveredPets[id] = true end end
	if typeof(data.upgrades) == "table" then
		for id, level in data.upgrades do
			if typeof(id) == "string" and ProgressionConfig.isFinite(level) and UpgradeCatalog.get(id) then
				profile.upgrades[id] = math.clamp(math.floor(level), 0, UpgradeCatalog.get(id).maxLevel)
			end
		end
	end

	local function num(value: any, fallback: number): number
		return if ProgressionConfig.isFinite(value) then math.clamp(value, 0, 9e15) else fallback
	end

	profile.rebirths = math.min(ProgressionConfig.MaxRebirths,math.floor(num(data.rebirths, 0)))
	profile.spinStrength = ProgressionConfig.normalizeSpinStrength(profile.spinStrength,profile.rebirths)
 for id,level in profile.upgrades do
  local upgrade=UpgradeCatalog.get(id)
  if upgrade then profile.upgrades[id]=math.min(level,UpgradeCatalog.capAt(upgrade,profile.rebirths)) end
 end
 profile.traitShards = math.floor(math.min(num(data.traitShards,0),1000000))
 profile.cycleBestDistance = num(data.cycleBestDistance,0)
 for _,zone in ipairs(ZoneConfig.List) do
  if type(data.completedAreas)=="table" and data.completedAreas[zone.id]==true then profile.completedAreas[zone.id]=true end
  if type(data.cycleCompletedAreas)=="table" and data.cycleCompletedAreas[zone.id]==true then profile.cycleCompletedAreas[zone.id]=true end
 end
 loadFlags(data.permanentTitles,profile.permanentTitles)
 local Mastery=require(ReplicatedStorage.Shared.MasteryConfig)
 if type(data.rockMastery)=="table" then
  for id,record in data.rockMastery do
   if profile.traitedRocks[id] and type(record)=="table" then
    profile.rockMastery[id]={xp=math.floor(math.min(num(record.xp,0),Mastery.threshold(Mastery.MaxLevel))),best=num(record.best,0),throws=math.floor(num(record.throws,0))}
    profile.traitedRocks[id].mastered=true
   end
  end
 end
 profile.xp = math.floor(num(data.xp, 0))
	profile.bestDistance = math.floor(num(data.bestDistance, 0))
	profile.totalSkips = math.floor(num(data.totalSkips, 0))
	profile.totalThrows = math.floor(num(data.totalThrows, 0))
	profile.totalMoney = math.floor(num(data.totalMoney, 0))

	-- Quest state is validated by QuestService on read (it rerolls whenever
	-- the stored day is not today), so it only needs to survive the trip.
	if typeof(data.quests) == "table" then
		profile.quests = data.quests
	end

	-- Beginner tutorial. Saves from before the tutorial existed are migrated
	-- from real progress so returning players are never re-onboarded.
	local TutorialConfig = require(ReplicatedStorage.Shared:WaitForChild("TutorialConfig"))
	if TutorialConfig.isStage(data.tutorialStage) then
		profile.tutorialStage = data.tutorialStage
	elseif profile.rebirths > 0 then
		profile.tutorialStage = "Completed"
	elseif profile.totalThrows > 0 then
		profile.tutorialStage = "FreePlay"
	else
		profile.tutorialStage = "SummonRock"
	end
	if typeof(data.tutorialFlags) == "table" then
		for key in TutorialConfig.Actions do
			if data.tutorialFlags[key] == true then profile.tutorialFlags[key] = true end
		end
	end
	profile.tutorialSkipped = data.tutorialSkipped == true

	Cleanup.apply(profile)
	if profile.rocksOwned[profile.rockEquipped] then
		Profiles.selectRock(profile, profile.rockEquipped, profile.rockEquippedInstance)
	end
	return profile
end

-- ============================================================================
-- Load / save
-- ============================================================================

local function waitForLeaderstats(player: Player): boolean
	for _ = 1, 100 do
		if player:FindFirstChild("leaderstats") then
			return true
		end
		if not player.Parent then
			return false
		end
		task.wait(0.1)
	end
	return player:FindFirstChild("leaderstats") ~= nil
end

local function load(player: Player)
	if not storeOk or not store then
		-- No DataStore: play unsaved rather than refuse to work.
		local profile = Profiles.get(player)
		profile.loaded = true
		Profiles.fireChanged(player)
		return
	end

	local ok, data
	for attempt = 1, LOAD_ATTEMPTS do
		ok, data = pcall(function()
			return (store :: DataStore):GetAsync(keyFor(player))
		end)
		if ok then
			break
		end

		local err = tostring(data)
		if ApiHealth.isDisabled(err) then
			-- Permanent for this session: stop trying, for everyone.
			if storeOk then
				storeOk = false
				warn("[Persistence] DataStore API is disabled -- progress will NOT be saved. "
					.. "Enable Game Settings > Security > Studio Access to API Services.")
			end
			local profile = Profiles.get(player)
			profile.loaded = true -- let them play; there is just nothing to load
			Profiles.fireChanged(player)
			return
		end

		if attempt < LOAD_ATTEMPTS then
			task.wait(attempt * 1.5) -- back off before retrying
		end
		if not player.Parent then
			return
		end
	end

	if not player.Parent then
		return
	end

	if not ok then
		warn(string.format("[Persistence] load FAILED for %s after %d attempts: %s",
			player.Name, LOAD_ATTEMPTS, tostring(data)))
		-- Left unloaded on purpose. ShopService will not let them spend, so a
		-- transient DataStore error cannot cost them their save.
		Remotes.Toast:FireClient(player,
			"Couldn't load your save - purchases are paused so nothing is lost", "bad")
		Profiles.fireChanged(player)
		return
	end

	if typeof(data) == "table" then
		Profiles.set(player, deserialise(data))
		if waitForLeaderstats(player) then
			local money = Profiles.moneyValue(player)
			if money then
				money.Value = math.floor(
					if ProgressionConfig.isFinite(data.money) then math.clamp(data.money, 0, 9e15) else 0
				)
			end
		end
	end

	Profiles.get(player).loaded = true
	Profiles.fireChanged(player)
end

local function save(player: Player, reason: string)
	if not storeOk or not store then
		return
	end
	if not Profiles.has(player) then
		return
	end
	local profile = Profiles.get(player)
	if not profile.loaded then
		-- Never write a profile we failed to read; that is the overwrite we
		-- are trying to avoid.
		return
	end

	while writing[player] do task.wait() end
 writing[player]=true
 local payload = serialise(player, profile)
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(old)
 if type(old)=='table' and type(old.redeemedCodes)=='table' then for id,v in old.redeemedCodes do if v==true then payload.redeemedCodes[id]=true end end end
 return payload end)
	end)
	writing[player]=nil
 if ok then
		lastSave[player] = os.clock()
	else
		warn(string.format("[Persistence] save failed for %s (%s): %s", player.Name, reason, tostring(err)))
	end
end

function Persistence.saveNow(player: Player)
	save(player, "manual")
end

-- ============================================================================
-- Wiring
-- ============================================================================

function Persistence.start()
 -- Explicit test flag: integration tests must never write to the player's live save.
 if RunService:IsStudio() and workspace:GetAttribute("WorldProgressionTestMode")==true then
  storeOk=false
  local function add(player) local profile=Profiles.get(player); profile.loaded=true; Profiles.fireChanged(player) end
  Players.PlayerAdded:Connect(add)
  for _,player in Players:GetPlayers() do add(player) end
  return
 end
 local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok and result then
		store = result
		storeOk = true
	else
		storeOk = false
		warn("[Persistence] DataStore unavailable -- progress will NOT be saved. "
			.. "In Studio, enable Game Settings > Security > Studio Access to API Services.")
	end

	local function onPlayerAdded(player: Player)
		task.spawn(load, player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player, "leaving")
		lastSave[player] = nil
	end)

	-- Autosave, so a server crash costs at most AUTOSAVE_INTERVAL.
	task.spawn(function()
		while true do
			task.wait(15)
			for _, player in Players:GetPlayers() do
				local last = lastSave[player] or 0
				if os.clock() - last >= AUTOSAVE_INTERVAL then
					save(player, "autosave")
				end
			end
		end
	end)

	-- Final flush. Roblox gives BindToClose a short window, so saves run in
	-- parallel rather than one after another.
	game:BindToClose(function()
		
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				save(player, "shutdown")
				pending -= 1
			end)
		end
		local deadline = os.clock() + 8
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

-- Code reward, inventory grants, and receipt are committed together.
-- `grant` only accepts canonical catalog ids assembled by the server caller.
Persistence.supportsEnchantedCodeGrants=true
function Persistence.redeemCode(player, code, reward, grant)
 if not storeOk or not store or not Profiles.get(player).loaded then
  return false, "Save data is unavailable. Try again when your data is loaded."
 end
 if writing[player] then return false, "Saving your data. Try again in a moment." end
 local profile=Profiles.get(player)
 if profile.redeemedCodes[code] then return false, "You already redeemed this code!" end
 local stats=player:FindFirstChild("leaderstats")
 if not stats then return false,"Stats are still loading." end
 for name,amount in reward do
  if (name~="Money" and name~="Strength") or not ProgressionConfig.isFinite(amount) or amount<0 or not stats:FindFirstChild(name) then
   return false,"Reward configuration is invalid."
  end
 end
 writing[player]=true
 local payload=serialise(player)
 local duplicate=false
 local function mergeSaved(old)
  if type(old)~="table" then return end
  if type(old.redeemedCodes)=="table" then
   if old.redeemedCodes[code] then duplicate=true return end
   for id,v in old.redeemedCodes do if v==true then payload.redeemedCodes[id]=true end end
  end
  -- A receipt must not resurrect inventory wiped by a newer rebirth.
  local sameLife=(ProgressionConfig.isFinite(old.rebirths) and old.rebirths==payload.rebirths) or (old.rebirths==nil and payload.rebirths==0)
  if sameLife then
  if type(old.rocksOwned)=="table" then for id,v in old.rocksOwned do if v==true then payload.rocksOwned[id]=true end end end
  if type(old.rockCounts)=="table" then for id,v in old.rockCounts do if type(v)=="number" then payload.rockCounts[id]=math.max(payload.rockCounts[id] or 0,v) end end end
  if type(old.traitedRocks)=="table" then for instanceId,copy in old.traitedRocks do
   if type(instanceId)=="string" and type(copy)=="table" and type(copy.rockId)=="string" and (TraitCatalog.get(copy.traitId) or copy.variant=="Enchanted" or copy.mastered==true) then
    if not payload.traitedRocks[instanceId] then payload.traitedRocks[instanceId]={rockId=copy.rockId,traitId=copy.traitId,variant=copy.variant=="Enchanted" and "Enchanted" or "Normal",mastered=copy.mastered==true} end
   end
  end end
  end
  if type(old.abilitiesOwned)=="table" then for id,v in old.abilitiesOwned do if v==true then payload.abilitiesOwned[id]=true end end end
  if sameLife and type(old.petsOwned)=="table" then for id,v in old.petsOwned do if v==true then payload.petsOwned[id]=true end end end
  for _,field in {"discoveredRocks","discoveredPets","discoveredEnchantedRocks","discoveredEnchantedPets","collectionMilestones"} do
   if type(old[field])=="table" then for id,v in old[field] do if v==true then payload[field][id]=true end end end
  end
 end
 local function applyInventory()
  if type(grant)~="table" then return end
  if type(grant.rocks)=="table" then
   for _,id in grant.rocks do
    if type(id)=="string" then payload.rocksOwned[id]=true payload.rockCounts[id]=math.max(payload.rockCounts[id] or 0,1) end
   end
  end
  if type(grant.enchantedRocks)=="table" then
   local enchantedOwned={}
   for _,copy in payload.traitedRocks do
    if copy.variant=="Enchanted" then enchantedOwned[copy.rockId]=true end
   end
   for _,id in grant.enchantedRocks do
    if type(id)=="string" and not enchantedOwned[id] then
     Profiles.addRock(payload,id,"Enchanted")
     enchantedOwned[id]=true
    end
   end
  end
  if type(grant.pets)=="table" then
   for _,id in grant.pets do if type(id)=="string" then payload.petsOwned[id]=true end end
  end
 end
 local ok,result=pcall(function()
  return store:UpdateAsync(keyFor(player),function(old)
   duplicate=false
   payload=serialise(player)
   mergeSaved(old)
   if duplicate then return nil end
   payload.redeemedCodes[code]=true
   payload.money+=(reward.Money or 0)
   payload.spinStrength=math.min(ProgressionConfig.strengthCap(payload.rebirths),payload.spinStrength+(reward.Strength or 0))
   payload.totalMoney+=(reward.Money or 0)
   applyInventory()
   Cleanup.apply(payload)
   return payload
  end)
 end)
 if ok and not duplicate then
  profile.redeemedCodes=payload.redeemedCodes
  profile.rocksOwned=payload.rocksOwned
  profile.rockCounts=payload.rockCounts
  profile.traitedRocks=payload.traitedRocks
  profile.petsOwned=payload.petsOwned
  profile.abilitiesOwned=payload.abilitiesOwned
  profile.abilityEquipped=payload.abilityEquipped
  for _,field in {"discoveredRocks","discoveredPets","discoveredEnchantedRocks","discoveredEnchantedPets","collectionMilestones"} do
   profile[field]=payload[field]
  end
  for name,amount in reward do
   if name=="Money" then Profiles.addMoney(player,amount) else Profiles.addSpinStrength(player,amount) end
  end
  lastSave[player]=os.clock()
 elseif duplicate then profile.redeemedCodes[code]=true end
 writing[player]=nil
 if not ok then warn("[CodeRedemption] Save failed: "..tostring(result)) return false,"Could not save your reward. Please try again." end
 if duplicate then return false,"You already redeemed this code!" end
 Profiles.fireChanged(player)
 return true
end

if RunService:IsStudio() then
 Persistence.testDeserialise=deserialise
 Persistence.testSerialise=serialise
end
return Persistence
