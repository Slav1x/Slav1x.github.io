-- Shared, server-validated coin egg pools. Special shop pets are deliberately absent.
local Zones = require(game:GetService("ReplicatedStorage").Shared.ZoneConfig)
local C = {}
C.Zones = Zones.List

local names = {
 driftwood = {"Mouse","Fox","Deer","Panda","Wolf","Unicorn","Flying Pig"},
 blossom = {"Leafy Bunny","Leafy Kitty","Leafy Deer","Koi","Leafy Dragon","Holy Leaf","King Koi"},
 candy = {"Yummy Doggy","Yummy Kitty","Candy Fox","Candy Dino","Candy Golem","Candy Paladin","Candy Dragon"},
 sunscorch = {"Orange Deer","Lemon Fox","Flying Acorn","Castle Bear","Flame Drop","Shining Star","Inferno Dragon"},
 frozen = {"Frost Kitty","Frost Deer","Frost Wolf","Polar Bear","Ice Dragon","Frost Dragon","Glacier Lord"},
 crystal = {"Smiling Orb","Castle Deer","Crystalline Globe","Ruby Dragon","Rainbow Shock","Hexarium","Lavender Dominator"},
 toxic = {"Immortality Stone","Void Fox","Radium","Goof Bot","Release Robot","Hexarium","Demonic Furnace"},
 inferno = {"Flame Drop","Crimson Knight","Crimson Knight","Dark Dragon","Inferno Dragon","Demonic Furnace","Dark Phoenix"},
 cosmic = {"Void Bat","Celestial Wisp","The Moon","Lunar Serpent","Shining Star","Overlord","Starlight Dragon"},
}
local swatches = {
 Common=Color3.fromRGB(80,157,129), Uncommon=Color3.fromRGB(64,153,194),
 Rare=Color3.fromRGB(113,91,208), Epic=Color3.fromRGB(185,91,196),
 Legendary=Color3.fromRGB(231,164,59), Exclusive=Color3.fromRGB(220,125,56),
}
local rarities={"Common","Common","Uncommon","Rare","Rare","Epic","Legendary"}
local odds={Egg1={35,35,24,6},Egg2={42,42,14,2}}
local function comma(value)
 local s=tostring(value)
 while true do
  local result,n=s:gsub("^(%-?%d+)(%d%d%d)","%1,%2")
  s=result
  if n==0 then break end
 end
 return s
end
C.formatMoney=comma
function C.petId(zoneId,slot)
 return "egg_"..zoneId.."_"..tostring(slot)
end
function C.price(eggId,zoneId)
 local zone=Zones.ById[zoneId]
 if not zone or (eggId~="Egg1" and eggId~="Egg2") then return nil end
 return zone.cost*(eggId=="Egg2" and 2 or 1)
end
function C.pool(eggId,zoneId)
 if eggId~="Egg1" and eggId~="Egg2" then return nil end
 local list=names[zoneId]
 if not list then return nil end
 local first=eggId=="Egg1" and 1 or 4
 local pool={}
 for i=1,4 do
  local slot=first+i-1
  pool[i]={Id=C.petId(zoneId,slot),Name=list[slot],Model=list[slot],
   Rarity=rarities[slot],Weight=odds[eggId][i],Color=swatches[rarities[slot]]}
 end
 return pool
end
function C.allPets()
 local result={}
 for zoneIndex,zone in ipairs(Zones.List) do
  local list=names[zone.id]
  assert(list and #list==7,"Missing pet collection: "..zone.id)
  for slot,name in ipairs(list) do
   result[#result+1]={Id=C.petId(zone.id,slot),Name=name,Model=name,
    Rarity=rarities[slot],ZoneId=zone.id,ZoneIndex=zoneIndex,
    Color=swatches[rarities[slot]]}
  end
 end
 return result
end
function C.get(eggId,zoneId)
 if eggId=="Egg3" then
  local paid={"Admiral","Duke","Electra","Overlord"}
  local result={}
  for _,name in ipairs(paid) do
   result[#result+1]={Name=name,Model=name,Rarity="EXCLUSIVE",
    PercentageText="ODDS TBD",Color=swatches.Exclusive}
  end
  return {Name="EXCLUSIVE EGG",Category="ROBUX COLLECTION",Accent=swatches.Exclusive,
   CostText="ROBUX PRICE TBD",Previews=result,Notice="EXCLUSIVE EGG • COMING SOON"}
 end
 local zone=Zones.ById[zoneId] or Zones.List[1]
 local pool=C.pool(eggId,zone.id)
 local previews={}
 for _,pet in ipairs(pool) do
  previews[#previews+1]={Name=pet.Name,Model=pet.Model,Id=pet.Id,
   Rarity=string.upper(pet.Rarity),PercentageText=tostring(pet.Weight).."%",Color=pet.Color}
 end
 local isFirst=eggId=="Egg1"
 local price=C.price(eggId,zone.id)
 return {Name=isFirst and "COMMON EGG" or "LEGEND EGG",
  Category=isFirst and "COMMON → RARE" or "RARE → LEGENDARY",
  Accent=isFirst and Color3.fromRGB(109,239,148) or Color3.fromRGB(145,118,240),
  Cost=price,CostText=comma(price).." COINS / HATCH",
  Previews=previews,Notice="E HATCH  •  R HATCH 3  •  T AUTO",
  Zone=zone}
end
return C

