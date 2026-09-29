--!strict
--[[
	RockCatalog

	Every throwable rock: price, look, trail, and what it does to a throw.
	Shared, because the server needs prices and stats (authoritative) and the
	client needs colours and trails (presentation).

	Player Spin Strength is amplified by this catalog's strength multipliers.
	Small handling profiles redistribute launch speed, momentum loss and arc
	height. Traits supply separate percentage factors through resolveStats; there is no
	per-rock skip count. Physics safety and progression curves live in their
	existing ThrowConfig and ProgressionConfig modules.
]]

export type Rock = {
	id: string,
	name: string,
	icon: string,
	image: string?,
	shopEnabled: boolean?,
	rarity: string,
	price: number,

	-- Look
	color: Color3,
	material: Enum.Material,
	trail: {Color3},   -- three stops, head to tail

	strengthMultiplier: number?,
	characteristics: {launchSpeed: number, waterLoss: number, bounceLift: number}?,
	behaviorProfile: string?,
	moneyBonus: number, -- existing economy bonus is intentionally independent

}

export type RockStats = {
 strengthMultiplier: number,
 launchSpeed: number,
 waterLoss: number,
 bounceLift: number,
 moneyBonus: number,
 masteryMultiplier: number,
 sweetZoneMultiplier: number,
 traitLaunchSpeed: number,
 traitWaterLoss: number,
 traitBounceHeight: number,
 traitPowerupMultiplier: number,
 traitSkipPreserveInterval: number,
}

local TraitCatalog = require(script.Parent:WaitForChild("TraitCatalog"))
local RockCatalog = {}
-- Applied once to the rock\'s declared specialty, before trait factors.
RockCatalog.EnchantedMultiplier = 1.3
RockCatalog.Specialties={Balanced="strengthMultiplier",Swift="launchSpeed",Skimmer="waterLoss",Momentum="waterLoss",Glider="bounceLift"}

RockCatalog.Default = "pebble"

RockCatalog.Rocks = {
	{
		id = "pebble",
		name = "Pebble",
		icon = "🪨",
		rarity = "Common",
		price = 0,
		color = Color3.fromRGB(126, 126, 126),
		material = Enum.Material.Slate,
		trail = {
			Color3.fromRGB(215, 245, 255),
			Color3.fromRGB(120, 205, 255),
			Color3.fromRGB(70, 140, 220),
		},
		moneyBonus = 0,
	},
	{
		id = "smooth_stone",
		name = "Smooth Stone",
		icon = "⚪",
		rarity = "Common",
		price = 250,
		color = Color3.fromRGB(197, 197, 190),
		material = Enum.Material.Concrete,
		trail = {
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(205, 225, 235),
			Color3.fromRGB(140, 165, 180),
		},
		moneyBonus = 0,
	},
	{
		id = "quartz",
		name = "Quartz",
		icon = "🤍",
		rarity = "Rare",
		price = 5500,
		color = Color3.fromRGB(238, 238, 245),
		material = Enum.Material.Glass,
		trail = {
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(225, 240, 255),
			Color3.fromRGB(165, 200, 240),
		},
		moneyBonus = 0.15,
	},
	{
		id = "obsidian",
		name = "Obsidian",
		icon = "🖤",
		rarity = "Epic",
		price = 30000,
		color = Color3.fromRGB(22, 20, 28),
		material = Enum.Material.Glass,
		trail = {
			Color3.fromRGB(215, 180, 255),
			Color3.fromRGB(120, 60, 190),
			Color3.fromRGB(25, 20, 35),
		},
		moneyBonus = 0.4,
	},
	{
		id = "golden_skimmer",
		name = "Golden Skimmer",
		icon = "🌟",
		rarity = "Legendary",
		price = 500000,
		color = Color3.fromRGB(226, 170, 40),
		material = Enum.Material.Foil,
		trail = {
			Color3.fromRGB(255, 250, 205),
			Color3.fromRGB(255, 200, 60),
			Color3.fromRGB(205, 130, 15),
		},
		moneyBonus = 1.5,
	},
} :: {Rock}

-- Featured set keeps existing IDs, prices, ownership, and shop compatibility.
local featured = {
	pebble = {name = "River Rock", image = "rbxassetid://94724297704128"},
	smooth_stone = {name = "Smooth Skimmer", image = "rbxassetid://122787265115173"},
	quartz = {name = "Tide Quartz", image = "rbxassetid://95370562205472"},
	obsidian = {name = "Void Obsidian", image = "rbxassetid://108928748119233"},
	golden_skimmer = {name = "Sunstone", image = "rbxassetid://107580671340891"},
}
RockCatalog.Featured = {"pebble", "smooth_stone", "quartz", "obsidian", "golden_skimmer", "astral_core"}
RockCatalog.RarityColors = {
	Common = Color3.fromRGB(192, 210, 220), Uncommon = Color3.fromRGB(120, 225, 145),
	Rare = Color3.fromRGB(64, 199, 255), Epic = Color3.fromRGB(190, 110, 255),
	Legendary = Color3.fromRGB(255, 203, 65), Mythical = Color3.fromRGB(255, 100, 223),
}
for _, rock in RockCatalog.Rocks do
	local upgrade = featured[rock.id]
	if upgrade then
		rock.name, rock.image = upgrade.name, upgrade.image
	end
end
table.insert(RockCatalog.Rocks, {
	id = "astral_core", name = "Astral Core", icon = "✦", image = "rbxassetid://83069214928352",
	rarity = "Mythical", price = 1250000,
	color = Color3.fromRGB(43, 28, 92), material = Enum.Material.Glass,
	trail = {Color3.fromRGB(90, 250, 255), Color3.fromRGB(170, 75, 255), Color3.fromRGB(255, 90, 215)},
	moneyBonus = 1.8,
})
-- Existing shop cosmetics remain neutral; no cash purchase until configured.
table.insert(RockCatalog.Rocks, {
 id = "treasure_stone", name = "Treasure Stone", icon = "✦", image = "rbxassetid://122545364105942",
 rarity = "Exclusive", price = 0, shopEnabled = false,
 color = Color3.fromRGB(35,120,255), material = Enum.Material.SmoothPlastic,
 trail = {Color3.fromRGB(35,120,255), Color3.fromRGB(255,225,170), Color3.fromRGB(35,120,255)},
 moneyBonus = 0,
})
local legacyMagmaSkimmer = {
 id = "magma_skimmer", name = "Magma Skimmer", icon = "✦", image = "rbxassetid://124056229559844",
 rarity = "Exclusive", price = 0, shopEnabled = false,
 color = Color3.fromRGB(255,106,30), material = Enum.Material.SmoothPlastic,
 trail = {Color3.fromRGB(255,106,30), Color3.fromRGB(255,225,170), Color3.fromRGB(255,106,30)},
 moneyBonus = 0,
}
table.insert(RockCatalog.Rocks, {
 id = "celestial_shard", name = "Celestial Shard", icon = "✦", image = "rbxassetid://102454535732257",
 rarity = "Exclusive", price = 0, shopEnabled = false,
 color = Color3.fromRGB(140,75,255), material = Enum.Material.SmoothPlastic,
 trail = {Color3.fromRGB(140,75,255), Color3.fromRGB(255,225,170), Color3.fromRGB(140,75,255)},
 moneyBonus = 0,
})
-- Hermes and Jetpack now live in AbilityCatalog. IDs are migrated by Persistence.
local zoneRocks={
 {"sugar_pebble","Sugar Pebble","Common",255,196,222,0.1},
 {"peppermint_stone","Peppermint Stone","Common",246,99,132,0.11},
 {"gumdrop_geode","Gumdrop Geode","Uncommon",154,111,235,0.15},
 {"cocoa_cluster","Cocoa Cluster","Rare",111,65,49,0.2},
 {"candy_prism","Candy Prism","Legendary",101,229,214,0.28},
 {"sugarheart","Sugarheart","Mythical",255,102,187,0.4},
 {"frost_pebble","Frost Pebble","Common",129,189,220,0.14},
 {"snowstone","Snowstone","Common",235,245,255,0.16},
 {"glacier_shard","Glacier Shard","Uncommon",86,206,240,0.21},
 {"aurora_quartz","Aurora Quartz","Rare",136,237,208,0.27},
 {"frost_crown","Frost Crown","Legendary",180,194,255,0.36},
 {"winterheart","Winterheart","Mythical",73,168,239,0.46},
 {"cavern_quartz","Cavern Quartz","Common",200,193,247,0.15},
 {"amethyst_geode","Amethyst Geode","Common",169,100,239,0.17},
 {"sapphire_cluster","Sapphire Cluster","Uncommon",65,135,250,0.22},
 {"ruby_matrix","Ruby Matrix","Rare",234,75,118,0.285},
 {"emerald_crown","Emerald Crown","Legendary",78,226,165,0.375},
 {"prismatic_heart","Prismatic Heart","Mythical",218,192,255,0.47},
 {"corroded_pebble","Corroded Pebble","Common",116,127,65,0.16},
 {"sludge_stone","Sludge Stone","Common",84,115,45,0.18},
 {"waste_crystal","Waste Crystal","Uncommon",180,233,66,0.23},
 {"isotope_geode","Isotope Geode","Rare",107,221,153,0.3},
 {"reactor_core","Reactor Core","Legendary",209,247,74,0.39},
 {"fallout_heart","Fallout Heart","Mythical",127,251,142,0.48},


 {"ember_pebble","Ember Pebble","Common",94,57,45,0.18},
 {"basalt_stone","Basalt Stone","Common",63,65,74,0.20},
 {"cinder_rock","Cinder Rock","Uncommon",106,72,65,0.25},
 {"lava_glass","Lava Glass","Rare",195,62,29,0.32},
 {"phoenix_heart","Phoenix Heart","Legendary",255,130,38,0.42},
 {"moon_pebble","Moon Pebble","Common",167,179,202,0.24},
 {"meteor_stone","Meteor Stone","Common",83,80,110,0.27},
 {"stardust_rock","Stardust Rock","Uncommon",107,133,189,0.34},
 {"nebula_quartz","Nebula Quartz","Rare",151,97,217,0.40},
 {"eclipse_stone","Eclipse Stone","Legendary",42,37,66,0.48},
 {"moss_stone","Moss Stone","Uncommon",78,155,104,0.07},
 {"lakeheart","Lakeheart","Mythical",55,202,226,0.3},
 {"petal_stone","Petal Stone","Common",255,181,206,0.08},
 {"bamboo_pebble","Bamboo Pebble","Common",120,195,111,0.06},
 {"koi_stone","Koi Stone","Uncommon",250,141,107,0.13},
 {"sakura_quartz","Sakura Quartz","Rare",243,149,218,0.18},
 {"spirit_stone","Spirit Stone","Legendary",175,162,255,0.24},
 {"bloomheart","Bloomheart","Mythical",255,102,189,0.35},
 {"sandstone","Sandstone","Common",206,159,96,0.12},
 {"cactus_stone","Cactus Stone","Common",100,159,99,0.13},
 {"fossil_rock","Fossil Rock","Uncommon",222,210,164,0.18},
 {"amber_shard","Amber Shard","Rare",255,176,68,0.22},
 {"solar_stone","Solar Stone","Legendary",255,202,55,0.32},
 {"scarab_core","Scarab Core","Mythical",75,190,176,0.44},
 {"magma_core","Magma Core","Mythical",235,78,46,0.5},
}
for _,v in ipairs(zoneRocks) do
 local color=Color3.fromRGB(v[4],v[5],v[6])
 table.insert(RockCatalog.Rocks,{
  id=v[1],name=v[2],icon="",image="",rarity=v[3],price=0,shopEnabled=false,
  color=color,material=Enum.Material.Slate,
  trail={color:Lerp(Color3.new(1,1,1),0.45),color,color:Lerp(Color3.new(0,0,0),0.4)},
  moneyBonus=v[7],
 })
end

local zoneImages={
 moss_stone="rbxassetid://76709157979423",
 lakeheart="rbxassetid://96121089303562",
 petal_stone="rbxassetid://74418604174351",
 bamboo_pebble="rbxassetid://79164500920440",
 koi_stone="rbxassetid://140321289136549",

 sakura_quartz="rbxassetid://117667846180307",
 spirit_stone="rbxassetid://79305846179211",
 bloomheart="rbxassetid://92324152369509",
 sandstone="rbxassetid://124860031182560",
 cactus_stone="rbxassetid://73621228031679",
 fossil_rock="rbxassetid://140721657029812",
 amber_shard="rbxassetid://122257514176227",
 solar_stone="rbxassetid://74318439716204",
 scarab_core="rbxassetid://110852731314358",
 magma_core="rbxassetid://113572375363889",
}
for _,rock in ipairs(RockCatalog.Rocks) do
 if zoneImages[rock.id] then rock.image=zoneImages[rock.id] end
end

-- id -> rock, built once
local byId: {[string]: Rock} = {}
for _, rock in RockCatalog.Rocks do
	byId[rock.id] = rock
end
byId[legacyMagmaSkimmer.id] = legacyMagmaSkimmer
-- Legacy collectible remains discoverable for existing owners.
table.insert(RockCatalog.Rocks, legacyMagmaSkimmer)

-- Balanced handling budgets: differences change contacts and airtime, not a
-- promised skip total. Data is explicit so summon-cost edits cannot retune art.
RockCatalog.HandlingProfiles = {
 Balanced={label="Balanced handling",launchSpeed=1.00,waterLoss=1.00,bounceLift=1.00},
 Skimmer={label="More shallow skips",launchSpeed=.94,waterLoss=.86,bounceLift=.90},
 Swift={label="Fast launch",launchSpeed=1.10,waterLoss=1.12,bounceLift=1.02},
 Glider={label="Longer arcs",launchSpeed=.97,waterLoss=1.08,bounceLift=1.15},
 Momentum={label="Keeps momentum",launchSpeed=1.04,waterLoss=.96,bounceLift=.93},
}
RockCatalog.StatBounds = {
 strengthMultiplier={.10,1000000},
 launchSpeed={.75,1.35},
 waterLoss={.65,1.30},
 bounceLift={.80,1.25},
}
-- Derived from existing zone-cost ratios (square root) and the existing six
-- summon slots, rounded to .05x; then stored as independent balance values.
local gameplay = {
 sugar_pebble={2.2,"Balanced"},
 peppermint_stone={2.4,"Skimmer"},
 gumdrop_geode={2.75,"Momentum"},
 cocoa_cluster={3.5,"Glider"},
 candy_prism={4.7,"Swift"},
 sugarheart={6.25,"Balanced"},
 frost_pebble={3.35,"Balanced"},
 snowstone={3.65,"Skimmer"},
 glacier_shard={4.2,"Momentum"},
 aurora_quartz={5.4,"Glider"},
 frost_crown={7.2,"Swift"},
 winterheart={9.5,"Balanced"},
 cavern_quartz={3.6,"Balanced"},
 amethyst_geode={3.9,"Skimmer"},
 sapphire_cluster={4.5,"Swift"},
 ruby_matrix={5.8,"Momentum"},
 emerald_crown={7.75,"Glider"},
 prismatic_heart={10.25,"Balanced"},
 corroded_pebble={3.85,"Balanced"},
 sludge_stone={4.2,"Skimmer"},
 waste_crystal={4.8,"Momentum"},
 isotope_geode={6.2,"Glider"},
 reactor_core={8.3,"Swift"},
 fallout_heart={11,"Balanced"},

 pebble={1.00,"Balanced"},
 smooth_stone={1.10,"Skimmer"},
 moss_stone={1.25,"Skimmer"},
 quartz={1.60,"Glider"},
 golden_skimmer={2.15,"Swift"},
 lakeheart={2.85,"Momentum"},
 petal_stone={1.75,"Glider"},
 bamboo_pebble={1.90,"Skimmer"},
 koi_stone={2.15,"Swift"},
 sakura_quartz={2.75,"Glider"},
 spirit_stone={3.70,"Skimmer"},
 bloomheart={4.95,"Balanced"},
 sandstone={2.85,"Momentum"},
 cactus_stone={3.10,"Skimmer"},
 fossil_rock={3.55,"Momentum"},
 amber_shard={4.55,"Glider"},
 solar_stone={6.10,"Swift"},
 scarab_core={8.05,"Balanced"},
 ember_pebble={4.45,"Swift"},
 basalt_stone={4.90,"Momentum"},
 cinder_rock={5.60,"Skimmer"},
 lava_glass={7.15,"Glider"},
 phoenix_heart={9.60,"Swift"},
 magma_core={12.75,"Balanced"},
 moon_pebble={7.05,"Glider"},
 meteor_stone={7.80,"Momentum"},
 stardust_rock={8.85,"Skimmer"},
 nebula_quartz={11.30,"Glider"},
 eclipse_stone={15.20,"Skimmer"},
 astral_core={20.15,"Balanced"},
 obsidian={1.85,"Momentum"},
 treasure_stone={1.00,"Balanced"},
 celestial_shard={1.00,"Balanced"},
 magma_skimmer={1.00,"Balanced"},
}
for _,rock in ipairs(RockCatalog.Rocks) do
 local entry=gameplay[rock.id]
 assert(entry,"Missing rock gameplay definition: "..rock.id)
 local profile=RockCatalog.HandlingProfiles[entry[2]]
 rock.strengthMultiplier=entry[1]
 rock.behaviorProfile=entry[2]
 rock.characteristics={launchSpeed=profile.launchSpeed,waterLoss=profile.waterLoss,bounceLift=profile.bounceLift}
end


function RockCatalog.get(id: string?): Rock
	if id and byId[id] then
		return byId[id]
	end
	return byId[RockCatalog.Default]
end

function RockCatalog.exists(id: string?): boolean
	return id ~= nil and byId[id] ~= nil
end

function RockCatalog.trailSequence(rock: Rock): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, rock.trail[1]),
		ColorSequenceKeypoint.new(0.5, rock.trail[2]),
		ColorSequenceKeypoint.new(1, rock.trail[3]),
	})
end


-- Returns a new table; callers cannot change catalog or trait definitions.
-- The server supplies the trait ID from the already-validated owned copy.
function RockCatalog.resolveStats(id: string?, traitId: any, variant: string?): RockStats
 local rock=RockCatalog.get(id)
 local characteristics=rock.characteristics or {launchSpeed=1,waterLoss=1,bounceLift=1}
 local trait=TraitCatalog.get(traitId)
 local modifiers=trait and trait.modifiers or {}
 local function traitFactor(field: string): number
  local value=modifiers[field]
  if type(value)~="number" or value~=value or value<=0 or value==math.huge then return 1 end
  return value
 end
 local function resolve(field: string, base: number): number
  if variant=="Enchanted" and field==RockCatalog.Specialties[rock.behaviorProfile or "Balanced"] then
   -- Handling benefits are advantages relative to neutral, not unrelated stats.
   if field=="strengthMultiplier" then base*=RockCatalog.EnchantedMultiplier
   else base=1+(base-1)*RockCatalog.EnchantedMultiplier end
  end
  -- Handling limits apply to the rock. Trait percentages are applied after
  -- those limits by the shared throw calculations, so they remain exact.
  local factor=if field=="strengthMultiplier" then traitFactor(field) else 1
  local bounds=RockCatalog.StatBounds[field]
  return math.clamp(base*factor,bounds[1],bounds[2])
 end
 local benefits=TraitCatalog.benefits(traitId,variant)
 return {
  moneyBonus=benefits.moneyBonus,
  masteryMultiplier=benefits.masteryMultiplier,
  sweetZoneMultiplier=benefits.sweetZoneMultiplier,
  traitLaunchSpeed=traitFactor("launchSpeed"),
  traitWaterLoss=traitFactor("waterLoss"),
  traitBounceHeight=traitFactor("bounceHeight"),
  traitPowerupMultiplier=traitFactor("powerupMultiplier"),
  traitSkipPreserveInterval=modifiers.skipPreserveInterval==2 and 2 or 0,
  strengthMultiplier=resolve("strengthMultiplier",rock.strengthMultiplier or 1),
  launchSpeed=resolve("launchSpeed",characteristics.launchSpeed),
  waterLoss=resolve("waterLoss",characteristics.waterLoss),
  bounceLift=resolve("bounceLift",characteristics.bounceLift),
 }
end

function RockCatalog.specialtyLabel(id: string?): string
 local key=RockCatalog.Specialties[RockCatalog.get(id).behaviorProfile or "Balanced"]
 return ({strengthMultiplier="strength",launchSpeed="launch speed",waterLoss="momentum retention",bounceLift="arc lift"})[key]
end

function RockCatalog.characteristicLabel(id: string?): string
 return RockCatalog.HandlingProfiles[RockCatalog.get(id).behaviorProfile or "Balanced"].label
end

return RockCatalog


