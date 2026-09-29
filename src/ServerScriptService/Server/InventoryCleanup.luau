--!strict
-- Preserve historical inventory records. Catalog visibility determines which
-- collectibles appear in the current UI; migration never discards purchases.
local Cleanup = {}
Cleanup.Rocks = {}
Cleanup.Pets = {}
function Cleanup.apply(profile)
 profile.abilitiesOwned = profile.abilitiesOwned or {}
 for _, id in {"hermes_rock", "jetpack_rock"} do
  local legacyOwned = (profile.rocksOwned and profile.rocksOwned[id])
   or (profile.rockCounts and (profile.rockCounts[id] or 0) > 0)
  for _, copy in profile.traitedRocks or {} do
   if copy.rockId == id then legacyOwned = true end
  end
  if legacyOwned then profile.abilitiesOwned[id] = true end
  -- Keep the legacy records intact so old purchases can always be recovered.
  -- The same equipped entitlement now occupies the ability slot.
  if profile.rockEquipped == id and profile.abilitiesOwned[id] then
   profile.abilityEquipped = id
   local replacement = nil
   local Catalog = require(game.ReplicatedStorage.Shared.RockCatalog)
   for _, rock in Catalog.Rocks do
    if rock.id ~= "hermes_rock" and rock.id ~= "jetpack_rock" and profile.rocksOwned and profile.rocksOwned[rock.id] then replacement = rock.id; break end
   end
   if not replacement then
    replacement = "pebble"
    profile.rocksOwned = profile.rocksOwned or {}
    profile.rockCounts = profile.rockCounts or {}
    profile.rocksOwned.pebble = true
    profile.rockCounts.pebble = math.max(profile.rockCounts.pebble or 0, 1)
   end
   profile.rockEquipped = replacement
   profile.rockEquippedInstance = nil
  end
 end
end
return Cleanup