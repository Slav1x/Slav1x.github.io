--!strict
--[[
	MonetizationConfig

	========================================================================
	ALL IDS ARE 0 -- NOTHING IS CONFIGURED YET.
	========================================================================

	Create the passes and products on the Creator Dashboard, paste the ids in
	below, and they become live with no code changes.

	While an id is 0 the item is treated as UNGATED: the pass counts as owned
	so the perk can be tested, and the product simply cannot be bought. That
	way the game is fully playable before any of this exists, and turning it
	on is a one-line edit per item rather than a refactor.

	Prices are the recommended anchors from the design pass, not gospel.
]]

local RunService = game:GetService("RunService")
local MonetizationConfig = {}

export type Pass = {
	key: string,
	id: number,
	name: string,
	description: string,
	suggestedRobux: number,
	-- Perks, in the same bonus convention as every other buff source.
	moneyBonus: number,
	luckBonus: number,
	magnetBonus: number,
	speedBonus: number,
	grantsAutoThrow: boolean,
}

MonetizationConfig.Passes = {
	{
		key = "double_money",
		id = 0,
		name = "2x Money",
		description = "Doubles all money you collect, forever.",
		suggestedRobux = 199,
		moneyBonus = 1,
		luckBonus = 0,
		magnetBonus = 0,
		speedBonus = 0,
		grantsAutoThrow = false,
	},
	{
		key = "auto_throw",
		id = 0,
		name = "Auto Throw",
		description = "Keeps throwing for you, releasing in the perfect zone.",
		suggestedRobux = 299,
		moneyBonus = 0,
		luckBonus = 0,
		magnetBonus = 0,
		speedBonus = 0,
		grantsAutoThrow = true,
	},
	{
		key = "lucky",
		id = 0,
		name = "Lucky Charm",
		description = "+5% chance for any pickup to pay out as gold.",
		suggestedRobux = 149,
		moneyBonus = 0,
		luckBonus = 0.05,
		magnetBonus = 0,
		speedBonus = 0,
		grantsAutoThrow = false,
	},
	{
		key = "vip",
		id = 0,
		name = "VIP",
		description = "+50% money, +10% throw power, and a VIP aura.",
		suggestedRobux = 499,
		moneyBonus = 0.5,
		luckBonus = 0.02,
		magnetBonus = 8,
		speedBonus = 0.1,
		grantsAutoThrow = false,
	},
} :: {Pass}

export type Product = {
	key: string,
	id: number,
	name: string,
	description: string,
	suggestedRobux: number,
	grantMoney: number,
}

MonetizationConfig.Products = {
	{
		key = "cash_small", id = 0, name = "Pocket Change",
		description = "$25,000", suggestedRobux = 49, grantMoney = 25000,
	},
	{
		key = "cash_medium", id = 0, name = "Bag of Cash",
		description = "$150,000", suggestedRobux = 199, grantMoney = 150000,
	},
	{
		key = "cash_large", id = 0, name = "Treasure Chest",
		description = "$1,000,000", suggestedRobux = 799, grantMoney = 1000000,
	},
} :: {Product}

local passByKey: {[string]: Pass} = {}
for _, pass in MonetizationConfig.Passes do
	passByKey[pass.key] = pass
end

local productById: {[number]: Product} = {}
for _, product in MonetizationConfig.Products do
	if product.id ~= 0 then
		productById[product.id] = product
	end
end

function MonetizationConfig.pass(key: string): Pass?
	return passByKey[key]
end

function MonetizationConfig.productFor(id: number): Product?
	return productById[id]
end

-- An unconfigured pass counts as owned, so its perk can be tested before the
-- pass exists. Set the id to gate it for real.
function MonetizationConfig.isUngated(pass: Pass): boolean
	-- Unconfigured passes are testable in Studio, but never become free ownership in live servers.
	return pass.id == 0 and RunService:IsStudio()
end

return MonetizationConfig
