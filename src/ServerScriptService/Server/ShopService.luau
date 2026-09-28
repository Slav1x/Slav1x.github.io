--!strict
--[[
	ShopService (server)

	The only thing allowed to spend money. Handles rocks, pets and levelled
	upgrades through one generic path, and is the only writer of ownership and
	equipment on a Profile.

	The client sends a kind and an id -- never a price, never a level, never a
	cost. Everything is looked up server-side from the catalogs.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RockCatalog = require(Shared:WaitForChild("RockCatalog"))
local PetCatalog = require(Shared:WaitForChild("PetCatalog"))
local UpgradeCatalog = require(Shared:WaitForChild("UpgradeCatalog"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AbilityCatalog = require(Shared:WaitForChild("AbilityCatalog"))

local Profiles = require(script.Parent:WaitForChild("Profiles"))

local ShopService = {}
local TrainingService = require(script.Parent:WaitForChild("TrainingService"))

local function result(player: Player, ok: boolean, message: string, id: string?)
	Remotes.ShopResult:FireClient(player, id or "", ok, message)
end

-- ============================================================================
-- Queries used by the throw / money systems
-- ============================================================================

function ShopService.getEquippedRock(player: Player)
	return RockCatalog.get(Profiles.get(player).rockEquipped)
end

-- ============================================================================
-- Rocks and pets
-- ============================================================================

local function purchaseRock(player: Player, id: string)
	local profile = Profiles.get(player)
	if profile.rocksOwned[id] then
		-- Already owned: a second buy obviously means "equip it".
		Profiles.selectRock(profile, id, nil)
		Profiles.fireChanged(player)
		return
	end

	local rock = RockCatalog.get(id)
	if rock.shopEnabled == false then
		result(player, false, "This rock is not for sale", id)
		return
	end
	if not Profiles.trySpend(player, rock.price) then
		result(player, false, "Not enough money", id)
		return
	end

	profile.rocksOwned[id] = true
	profile.rockCounts[id] = math.max(profile.rockCounts[id] or 0, 1)
	Profiles.selectRock(profile, id, nil) -- buying equips, saving a second click
	Profiles.fireChanged(player)
	result(player, true, "Unlocked " .. rock.name, id)
end

local function purchaseAbility(player: Player, id: string)
	local ability = AbilityCatalog.get(id)
	if not ability then return end
	local profile = Profiles.get(player)
	if not profile.abilitiesOwned[id] then
		if not Profiles.trySpend(player, ability.price) then
			result(player, false, "Not enough money", id)
			return
		end
		profile.abilitiesOwned[id] = true
	end
	profile.abilityEquipped = id
	Profiles.fireChanged(player)
	result(player, true, ability.name .. " equipped", id)
end

local function purchasePet(player: Player, id: string)
	local profile = Profiles.get(player)
	if profile.petsOwned[id] then
		profile.petEquipped = id
		Profiles.fireChanged(player)
		return
	end

	local pet = PetCatalog.get(id)
	if not pet then
		return
	end
	if pet.shopEnabled == false then
		result(player, false, "This pet is not for sale", id)
		return
	end
	if not Profiles.trySpend(player, pet.price) then
		result(player, false, "Not enough money", id)
		return
	end

	profile.petsOwned[id] = true
	profile.petEquipped = id
	Profiles.fireChanged(player)
	result(player, true, "Unlocked " .. pet.name, id)
end

local function purchaseUpgrade(player: Player, id: string)
	local upgrade = UpgradeCatalog.get(id)
	if not upgrade then
		return
	end

	local profile = Profiles.get(player)
	local level = profile.upgrades[id] or 0
	if UpgradeCatalog.isMaxed(upgrade, level, profile.rebirths) then
		result(player, false, upgrade.name .. " is at this journey's cap — rebirth increases it", id)
		return
	end

	local cost = UpgradeCatalog.costAt(upgrade, level)
	if not Profiles.trySpend(player, cost) then
		result(player, false, "Not enough money", id)
		return
	end

	profile.upgrades[id] = level + 1
	Profiles.fireChanged(player)
	result(player, true, upgrade.name .. " level " .. (level + 1), id)
end

-- ============================================================================
-- Request handlers
-- ============================================================================

-- The upgrade button and hotbar item share the same authoritative gain path.

local function onPurchase(player: Player, kind: unknown, id: unknown)
	if typeof(kind) ~= "string" or typeof(id) ~= "string" then
		return
	end
	if not Profiles.get(player).loaded then
		-- Refuse to spend before the save has loaded, or a slow DataStore read
		-- would let a player buy against a balance that is about to be
		-- replaced -- and then lose the purchase.
		result(player, false, "Still loading your save", id)
		return
	end

	if kind=="training" and id=="spin" then
  TrainingService.train(player, false)
 elseif (kind == "ability" or kind == "rock") and AbilityCatalog.get(id) then
		purchaseAbility(player, id)
	elseif kind == "rock" and RockCatalog.exists(id) then
		purchaseRock(player, id)
	elseif kind == "pet" and PetCatalog.exists(id) then
		purchasePet(player, id)
	elseif kind == "upgrade" and UpgradeCatalog.get(id) then
		purchaseUpgrade(player, id)
	end
end

local function onEquip(player: Player, kind: unknown, id: unknown, instanceId: unknown)
	if typeof(kind) ~= "string" or typeof(id) ~= "string" then
		return
	end
	local profile = Profiles.get(player)
	if not profile.loaded then
		result(player, false, "Still loading your save", id)
		return
	end

	if kind == "ability" or (kind == "rock" and AbilityCatalog.get(id)) then
		if id == "" then
			profile.abilityEquipped = nil
		elseif not AbilityCatalog.get(id) or not profile.abilitiesOwned[id] then
			result(player, false, "Ability not owned", id)
			return
		else
			profile.abilityEquipped = id
		end
	elseif kind == "rock" then
		if not RockCatalog.exists(id) then
			return
		end
		if not profile.rocksOwned[id] then
			result(player, false, "Not owned", id)
			return
		end
		if instanceId ~= nil and typeof(instanceId) ~= "string" then return end
		if not Profiles.selectRock(profile, id, instanceId) then
			result(player, false, "That rock copy is no longer available", id)
			return
		end
	elseif kind == "pet" then
		-- An empty id unequips, so a player can run with no pet.
		if id == "" then
			profile.petEquipped = nil
		elseif not PetCatalog.exists(id) then
			return
		elseif not profile.petsOwned[id] then
			result(player, false, "Not owned", id)
			return
		else
			profile.petEquipped = id
		end
	else
		return
	end

	Profiles.fireChanged(player)
end

local favoriteCooldown: {[Player]: number} = {}
local function onFavorite(player: Player, key: unknown, starred: unknown)
	if typeof(key) ~= "string" or #key > 100 or typeof(starred) ~= "boolean" then return end
	local now = os.clock()
	if now - (favoriteCooldown[player] or 0) < .08 then return end
	favoriteCooldown[player] = now
	local profile = Profiles.get(player)
	if not profile.loaded then return end
	local rockId = string.match(key, "^rock:([%w_]+)$")
	local petId = string.match(key, "^pet:([%w_]+)$")
	local copyId = string.match(key, "^traited:(.+)$")
	local abilityId = string.match(key, "^ability:([%w_]+)$")
	local valid = (rockId and RockCatalog.exists(rockId) and profile.rocksOwned[rockId] and Profiles.untraitedCount(profile, rockId) > 0)
		or (petId and PetCatalog.exists(petId) and profile.petsOwned[petId])
		or (copyId and profile.traitedRocks[copyId] ~= nil)
		or (abilityId and profile.abilitiesOwned[abilityId] == true)
	if not valid then return end
	profile.inventoryFavorites[key] = starred and true or nil
	Profiles.fireChanged(player)
end

-- ============================================================================
-- Wiring
-- ============================================================================

function ShopService.start()
	Remotes.RequestPurchase.OnServerEvent:Connect(onPurchase)
	Remotes.RequestEquip.OnServerEvent:Connect(onEquip)
	Remotes.RequestFavorite.OnServerEvent:Connect(onFavorite)
	Players.PlayerRemoving:Connect(function(player) favoriteCooldown[player] = nil end)
	Remotes.RequestShopState.OnServerEvent:Connect(function(player)
		Remotes.ProfileState:FireClient(player, Profiles.snapshot(player))
	end)

	-- One push per change, for every system that cares.
	Profiles.onChanged(function(player)
		if player.Parent then
			Remotes.ProfileState:FireClient(player, Profiles.snapshot(player))
		end
	end)

	local function onPlayerAdded(player: Player)
		-- leaderstats is created by a separate script; wait so the first push
		-- carries a real balance.
		task.spawn(function()
			for _ = 1, 100 do
				if player:FindFirstChild("leaderstats") then
					break
				end
				task.wait(0.1)
			end
			if player.Parent then
				Profiles.fireChanged(player)
			end
		end)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return ShopService
