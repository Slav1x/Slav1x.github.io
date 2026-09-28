--!strict
--[[
	PetCatalog

	Pets are passive buffs you equip one at a time. Each one leans on a
	different part of the loop so the choice is not just "buy the newest":
	money multipliers help banking, magnet helps sloppy aim, luck helps gold
	bars, speed helps distance records.

	Pets can optionally provide a reusable 3D world model and flight settings.
	Entries without a model keep the lightweight badge fallback, so adding the
	first real pet does not disturb the existing catalog or inventory flow.
]]

export type Pet = {
	id: string,
	name: string,
	icon: string,
	rarity: string,
	price: number,

	color: Color3,

	-- Buffs, same BONUS convention as RockCatalog: 0.15 => +15%.
	moneyBonus: number,
	magnetBonus: number,  -- studs added to money collect radius
	luckBonus: number,    -- added to gold-bar chance (0.02 => +2 points)
	speedBonus: number,   -- 0.03 => +3% launch speed
	image: string?,
	model: string?,
	modelYaw: number?,
	followOffset: Vector3?,
	flight: {[string]: number}?,
	vfx: {[string]: number}?,
	shopEnabled: boolean?,
	developerExclusive: boolean?,
}

local PetCatalog = {}

PetCatalog.Pets = {
	{
		id = "sun_phoenix", name = "Sun Phoenix", icon = "🔥", image = "rbxassetid://116136941734017",
		rarity = "Exclusive", price = 0, shopEnabled = false, developerExclusive = true,
		color = Color3.fromRGB(255, 120, 24), model = "SunPhoenix", modelYaw = 0,
		followOffset = Vector3.new(-4.0, 3.2, 3.1),
		flight = {stiffness = 7.0, maxCatchupDistance = 30, hoverHeight = 0.25, hoverSpeed = 2.2,
			wingSpeed = 4.3, wingAmplitude = 23, tailSpeed = 2.2, tailAmplitude = 5},
		vfx = {idleEmberRate = 3, catchupSparkRate = 8},
		moneyBonus = 0, magnetBonus = 0, luckBonus = 0, speedBonus = 0,
	},
} :: {Pet}

table.insert(PetCatalog.Pets, {id="verdant_golem", name="Verdant Golem", icon="✦", image="rbxassetid://119280883617007", rarity="Exclusive", price=0, shopEnabled=false, color=Color3.fromRGB(130,200,65), moneyBonus=0,magnetBonus=0,luckBonus=0,speedBonus=0})
table.insert(PetCatalog.Pets, {id="void_drake", name="Void Drake", icon="✦", image="rbxassetid://116760958470942", rarity="Exclusive", price=0, shopEnabled=false, color=Color3.fromRGB(155,65,240), moneyBonus=0,magnetBonus=0,luckBonus=0,speedBonus=0})
local legacyAbyssalSerpent = {id="abyssal_serpent", name="Abyssal Serpent", icon="✦", image="rbxassetid://116796945500643", rarity="Exclusive", price=0, shopEnabled=false, color=Color3.fromRGB(40,160,255), moneyBonus=0,magnetBonus=0,luckBonus=0,speedBonus=0}
table.insert(PetCatalog.Pets, {id="snow_kitsune", name="Snow Kitsune", icon="✦", image="rbxassetid://83756941223394", rarity="Exclusive", price=0, shopEnabled=false, color=Color3.fromRGB(165,230,255), moneyBonus=0,magnetBonus=0,luckBonus=0,speedBonus=0})

-- Distinct BGC Pack pets reserved for Starter Pack and Special Pets.
-- Their shop cards stay inactive until product IDs and receipt grants are configured.
table.insert(PetCatalog.Pets, {id="starter_mythic_baron_bunny",name="Mythic Baron Bunny",icon="✦",rarity="Exclusive",price=0,shopEnabled=false,model="Mythic Baron Bunny",color=Color3.fromRGB(62,173,255),moneyBonus=0,magnetBonus=0,luckBonus=0,speedBonus=0})
table.insert(PetCatalog.Pets, {id="mythic_candy_paladin",name="Mythic Candy Paladin",icon="✦",rarity="Exclusive",price=0,shopEnabled=false,model="Mythic Candy Paladin",color=Color3.fromRGB(255,92,207),moneyBonus=0,magnetBonus=0,luckBonus=0,speedBonus=0})
table.insert(PetCatalog.Pets, {id="mythic_christmas_robot",name="Mythic Christmas Robot",icon="✦",rarity="Exclusive",price=0,shopEnabled=false,model="Mythic Christmas Robot",color=Color3.fromRGB(85,219,255),moneyBonus=0,magnetBonus=0,luckBonus=0,speedBonus=0})
table.insert(PetCatalog.Pets, {id="mythic_fall_queen",name="Mythic Fall Queen",icon="✦",rarity="Exclusive",price=0,shopEnabled=false,model="Mythic Fall Queen",color=Color3.fromRGB(255,177,70),moneyBonus=0,magnetBonus=0,luckBonus=0,speedBonus=0})

-- Every regular egg slot is an inventory/index collectible. A model reused by a later
-- zone has its own stable ID so discoveries and duplicate counts remain independent.
local EggHatchConfig=require(script.Parent.EggHatchConfig)
local rarityBonus={Common=0,Uncommon=.01,Rare=.025,Epic=.045,Legendary=.075}
for _,entry in ipairs(EggHatchConfig.allPets()) do
 table.insert(PetCatalog.Pets,{
  id=entry.Id,name=entry.Name,icon="✦",rarity=entry.Rarity,price=0,shopEnabled=false,
  model=entry.Model,color=entry.Color,
  moneyBonus=math.min(.22,entry.ZoneIndex*.015+(rarityBonus[entry.Rarity] or 0)),
  magnetBonus=0,luckBonus=0,speedBonus=0,
  flight={stiffness=6.8,maxCatchupDistance=35,hoverHeight=.18,hoverSpeed=2.6},
 })
end

local byId: {[string]: Pet} = {}
for _, pet in PetCatalog.Pets do
	byId[pet.id] = pet
end
byId[legacyAbyssalSerpent.id] = legacyAbyssalSerpent

function PetCatalog.get(id: string?): Pet?
	if id and byId[id] then
		return byId[id]
	end
	return nil
end

function PetCatalog.exists(id: string?): boolean
	return id ~= nil and byId[id] ~= nil
end

return PetCatalog
