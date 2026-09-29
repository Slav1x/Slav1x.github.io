-- Server-authoritative acquisition. No yield occurs between payment and ownership.
local Transaction = {}
local Profiles = require(script.Parent.Server.Profiles)
local Appearance = require(game.ReplicatedStorage.Shared.RockAppearance)
local Catalog = require(game.ReplicatedStorage.Shared.RockCatalog)
local rng = Random.new()
function Transaction.commit(profile, money, id, cost)
 if not profile or not profile.loaded then return false, "Your inventory is still loading." end
 if type(cost) ~= "number" or cost < 0 or cost ~= cost then return false, "Invalid summon cost." end
 if not Catalog.exists(id) or id == "hermes_rock" or id == "jetpack_rock" then return false, "Invalid collectible." end
 if not money or money.Value < cost then return false, "You need "..cost.." coins to summon." end
 if type(profile.rocksOwned) ~= "table" or type(profile.rockCounts) ~= "table" then
  return false, "Your inventory is not ready. Please rejoin."
 end
 local enchantedChance=math.clamp((Appearance.EnchantedChance or .01)*(workspace:GetAttribute("GlobalEnchantedMultiplier") or 1),0,.02)
 local variant = rng:NextNumber() < enchantedChance and "Enchanted" or "Normal"
 local isNew
 if variant == "Enchanted" then isNew = not profile.discoveredEnchantedRocks[id]
 else isNew = not profile.rocksOwned[id] end
 local instanceId, count = Profiles.addRock(profile, id, variant)
 money.Value -= cost
 return true, isNew, count, variant, instanceId
end
return Transaction