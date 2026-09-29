--!strict
-- Purchasable attachments; deliberately separate from collectible RockCatalog.
local AbilityCatalog = {}
AbilityCatalog.Abilities = {
	{id="hermes_rock", name="Hermes", description="Double your rock's flight speed while equipped.", rarity="Exclusive", price=25000, icon="⚡", image="rbxassetid://79938105304706", color=Color3.fromRGB(245,210,120), modelId="hermes_rock"},
	{id="jetpack_rock", name="Jetpack", description="Hold Space during a throw to fly. Eight seconds of fuel.", rarity="Exclusive", price=50000, icon="✦", image="rbxassetid://104725267119032", color=Color3.fromRGB(70,190,255), modelId="jetpack_rock"},
}
AbilityCatalog.byId = {}
for _, ability in AbilityCatalog.Abilities do AbilityCatalog.byId[ability.id] = ability end
function AbilityCatalog.get(id: string?) return id and AbilityCatalog.byId[id] or nil end
function AbilityCatalog.speedMultiplier(id: string?): number return if id == "hermes_rock" then 2 else 1 end
AbilityCatalog.Jetpack = {
	MaxFuel = 8, -- seconds of uninterrupted thrust
	RechargeDelay = 1.5, -- delay after releasing Space / running empty
	RechargeRate = 0.8, -- fuel seconds recharged each real second
	MinRestartFuel = 0.25,
	UpSpeed = 24, -- controlled climbing speed, studs/second
	VerticalResponse = 8,
	MaxLiftAcceleration = 140,
	InputTimeout = 0.6, -- heartbeat input stops thrust if focus/network is lost
}
return AbilityCatalog
