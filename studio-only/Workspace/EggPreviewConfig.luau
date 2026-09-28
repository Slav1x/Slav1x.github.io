-- Shared preview pools for the three egg pedestals.
-- Hatch prices, product IDs, and grants must be configured on the server before enabling buttons.
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
C.PlannedVariants = {
 ["Flying Acorn"]=true,["Castle Bear"]=true,["Inferno Dragon"]=true,
 ["Smiling Orb"]=true,["Castle Deer"]=true,["Immortality Stone"]=true,
 ["Void Fox"]=true,["Demonic Furnace"]=true,["Crimson Knight"]=true,
 ["Void Bat"]=true,["Overlord"]=true,
}
local swatches = {
 Common=Color3.fromRGB(80,157,129),Uncommon=Color3.fromRGB(64,153,194),
 Rare=Color3.fromRGB(113,91,208),Epic=Color3.fromRGB(185,91,196),
 Legendary=Color3.fromRGB(231,164,59),Exclusive=Color3.fromRGB(220,125,56),
}
local odds1={35,35,24,6}
local odds2={42,42,14,2}
local tiers1={"Common","Common","Uncommon","Rare"}
local tiers2={"Rare","Rare","Epic","Legendary"}
local function entries(list, first, tiers, odds)
 local result={}
 for i=1,4 do
  local name=list[first+i-1]
  local rarity=tiers[i]
  result[i]={
   Name=name,Rarity=string.upper(rarity),
   PercentageText=tostring(odds[i]).."%",
   Color=swatches[rarity],Planned=C.PlannedVariants[name]==true,
  }
 end
 return result
end
function C.get(eggId,zoneId)
 if eggId=="Egg3" then
  local paid={"Admiral","Duke","Electra","Overlord"}
  local result={}
  for i,name in ipairs(paid) do
   result[i]={Name=name,Rarity="EXCLUSIVE",PercentageText="ODDS TBD",Color=swatches.Exclusive}
  end
  return {Name="EXCLUSIVE EGG",Category="ROBUX COLLECTION • FIXED POOL",Accent=swatches.Exclusive,
   CostText="ROBUX PRICE TBD",Previews=result,Notice="PREVIEW ONLY • PRODUCT NOT CONFIGURED"}
 end
 local zone=Zones.ById[zoneId] or Zones.List[1]
 local list=names[zone.id]
 local isFirst=eggId=="Egg1"
 return {
  Name=isFirst and "COMMON EGG" or "LEGEND EGG",
  Category=isFirst and "COMMON → RARE" or "RARE → LEGENDARY",
  Accent=isFirst and Color3.fromRGB(109,239,148) or Color3.fromRGB(145,118,240),
  CostText="COIN PRICE TBD",
  Previews=entries(list,isFirst and 1 or 4,isFirst and tiers1 or tiers2,isFirst and odds1 or odds2),
  Notice="PREVIEW ONLY • HATCHING NOT ACTIVE",
  Zone=zone,
 }
end
for _,zone in ipairs(Zones.List) do
 assert(names[zone.id] and #names[zone.id]==7,"Missing pet egg collection: "..zone.id)
end
return C

