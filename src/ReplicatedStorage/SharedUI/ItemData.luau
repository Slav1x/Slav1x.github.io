--!strict
--[[
	ItemData
	Placeholder data for the UI. When the real gameplay systems exist,
	replace the contents of these tables (or feed them from the server).
	Fields:
		Name, Icon (emoji placeholder), Rarity, Price, Owned, Quantity, Discovered
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemData = {}

-- Rocks are no longer placeholder data. They are derived from the
-- Rojo-managed ReplicatedStorage.Shared.RockCatalog, which is the same table
-- the server prices purchases from and the client reads trail colours from --
-- so the shop, the throw stats and the visuals can never drift apart.
-- Owned/Equipped are filled in at runtime from the ShopState remote.
local RockCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RockCatalog"))

ItemData.Rocks = {}
for _, rock in RockCatalog.Rocks do
	table.insert(ItemData.Rocks, {
		Id = rock.id,
		Name = rock.name,
		Icon = rock.icon,
		Rarity = rock.rarity,
		Price = rock.price,
		Owned = rock.id == RockCatalog.Default, -- the starter rock is free and pre-owned
		Discovered = true,
	})
end

-- Pets, like rocks, come from a Rojo-managed catalog so ownership ids,
-- prices and buffs cannot drift from what the server charges.
local PetCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PetCatalog"))

ItemData.Pets = {}
for _, pet in PetCatalog.Pets do
	table.insert(ItemData.Pets, {
		Id = pet.id,
		Name = pet.name,
		Icon = pet.icon,
		Rarity = pet.rarity,
		Price = pet.price,
		Owned = false,
		Discovered = true,
	})
end

ItemData.Mutations = {
	{Name = "Glossy", Icon = "✨", Rarity = "Uncommon", Discovered = true},
	{Name = "Mossy", Icon = "🌿", Rarity = "Rare", Discovered = true},
	{Name = "Golden", Icon = "🌟", Rarity = "Legendary", Discovered = true},
	{Name = "Crystalline", Icon = "💎", Rarity = "Epic", Discovered = false},
	{Name = "Fiery", Icon = "🔥", Rarity = "Legendary", Discovered = false},
	{Name = "Frost", Icon = "❄️", Rarity = "Epic", Discovered = false},
	{Name = "Bouncy", Icon = "🏀", Rarity = "Uncommon", Discovered = false},
	{Name = "Magnetic", Icon = "🧲", Rarity = "Rare", Discovered = false},
}

-- 7-day daily reward calendar (visual states only for now)
--[[
ItemData.DailyRewards = {
	{Day = 1, Icon = "🪙", Amount = 100, Reward = "Coins", State = "Claimed"},
	{Day = 2, Icon = "🪙", Amount = 250, Reward = "Coins", State = "Available"},
	{Day = 3, Icon = "🪙", Amount = 500, Reward = "Coins", State = "Locked"},
	{Day = 4, Icon = "🥚", Amount = 1, Reward = "Pet Egg", State = "Locked"},
	{Day = 5, Icon = "🪙", Amount = 1500, Reward = "Coins", State = "Locked"},
	{Day = 6, Icon = "💎", Amount = 1, Reward = "Geode", State = "Locked"},
	{Day = 7, Icon = "🌟", Amount = 1, Reward = "Legendary Mutation", State = "Locked"},
}
]]

return ItemData
