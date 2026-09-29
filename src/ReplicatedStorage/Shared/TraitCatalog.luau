-- Trait IDs stay stable across saves. Display names and exact effects live here.
local T={}
T.RollCost=3
T.Names={"Strength","Swift","Bouncy"}
T.RarityOrder={"Common","Uncommon","Rare","Epic","Legendary"}
T.RarityColors={
 Common=Color3.fromRGB(192,210,220),Uncommon=Color3.fromRGB(112,224,155),
 Rare=Color3.fromRGB(82,191,255),Epic=Color3.fromRGB(188,117,255),Legendary=Color3.fromRGB(255,203,65),
}
T.RarityWeights={Common=6000,Uncommon=2700,Rare=990,Epic=280,Legendary=30}
T.Results={};T.Modifiers={}
local pools={} for _,rarity in ipairs(T.RarityOrder) do pools[rarity]={} end
local byId={}
local function add(id,name,rarity,description,modifiers,benefits)
 local result={id=id,name=name,tier=1,label=name,rarity=rarity,
  description=description,modifiers=modifiers or {},benefits=benefits or {},color=T.RarityColors[rarity]}
 assert(not byId[id],"Duplicate trait ID")
 byId[id]=result;T.Modifiers[id]=result.modifiers;table.insert(T.Results,result);table.insert(pools[rarity],result)
end
-- One 10,000-point distribution; traits within each rarity have equal odds.
add("Strength1","Sturdy","Common","10% more rock strength",{strengthMultiplier=1.10})
add("Swift1","Fleet","Common","4% faster throws",{launchSpeed=1.04})
add("Bouncy1","Springy","Common","10% higher bounces",{bounceHeight=1.10})
add("Strength2","Stoneheart","Uncommon","20% more rock strength",{strengthMultiplier=1.20})
add("Swift2","Quickstream","Uncommon","8% faster throws",{launchSpeed=1.08})
add("Bouncy2","High Arc","Uncommon","20% higher bounces",{bounceHeight=1.20})
add("Prospector","Prospector","Uncommon","12% more throw cash",nil,{moneyBonus=.12})
add("Strength3","Titan Grip","Rare","30% more rock strength",{strengthMultiplier=1.30})
add("Swift3","Stormflight","Rare","12% faster throws",{launchSpeed=1.12})
add("Bouncy3","Skybound","Rare","30% higher bounces",{bounceHeight=1.30})
add("Scholar","Scholar","Rare","30% more mastery XP",nil,{masteryMultiplier=1.30})
add("Precision","True Aim","Rare","20% wider perfect zone",nil,{sweetZoneMultiplier=1.20})
add("Stormbound","Stormbound","Rare","16% faster throws",{launchSpeed=1.16})
add("Cloudbreaker","Cloudbreaker","Rare","25% higher bounces; 8% less speed lost per skip",{bounceHeight=1.25,waterLoss=.92})
add("Undertow","Undertow","Rare","18% less speed lost per skip",{waterLoss=.82})
add("Flowstate","Flowstate","Rare","8% faster throws; 12% less speed lost per skip",{launchSpeed=1.08,waterLoss=.88})
add("Slipstream","Slipstream","Epic","24% faster throws; 12% less speed lost per skip",{launchSpeed=1.24,waterLoss=.88})
add("Tidekeeper","Tidekeeper","Epic","30% less speed lost per skip; 20% wider perfect zone",{waterLoss=.70},{sweetZoneMultiplier=1.20})
add("Resonant","Resonant","Epic","40% more rock strength; Enchanted: 35% more mastery XP",{strengthMultiplier=1.40},{enchantedMasteryMultiplier=1.35})
add("Skybreaker","Skybreaker","Epic","50% higher bounces; 12% faster throws",{bounceHeight=1.50,launchSpeed=1.12})
add("TheOne","Horizon Sovereign","Legendary","60% more rock strength; 30% faster throws; 40% less speed lost per skip",{strengthMultiplier=1.60,launchSpeed=1.30,waterLoss=.60})
add("PowerSurge","Power Surge","Legendary","2x water boosts and Nitro refills",{powerupMultiplier=2})
add("EternalCadence","Eternal Cadence","Legendary","Every 2nd skip loses no speed or spin",{skipPreserveInterval=2})
local baseTotal=0
for _,rarity in ipairs(T.RarityOrder) do
 assert(#pools[rarity]>0 and T.RarityWeights[rarity]>0,"Empty rarity pool")
 baseTotal+=T.RarityWeights[rarity]
 for _,result in ipairs(pools[rarity]) do result.weight=T.RarityWeights[rarity]/#pools[rarity] end
end
assert(baseTotal==10000,"Trait rarity weights must total 10,000")
-- Trait Storm changes quality weights, never guarantees any result.
local stormFactors={Common=1,Uncommon=1.2,Rare=1.65,Epic=2.5,Legendary=3}
local function weight(result,luck)
 local boost=math.clamp(tonumber(luck) or 1,1,1.65)
 return result.weight*(1+(stormFactors[result.rarity]-1)*(boost-1)/.65)
end
local function total(luck)
 local sum=0 for _,r in ipairs(T.Results) do sum+=weight(r,luck) end return sum
end
function T.chancePercent(id,luck)
 local r=byId[id] return r and weight(r,luck)/total(luck)*100 or 0
end
function T.rarityChancePercent(rarity,luck)
 local sum=0 for _,r in ipairs(T.Results) do if r.rarity==rarity then sum+=weight(r,luck) end end
 return sum/total(luck)*100
end
function T.roll(rng,luck)
 local pick=rng:NextNumber(0,total(luck))
 for _,r in ipairs(T.Results) do pick-=weight(r,luck) if pick<0 then return r end end
 return T.Results[#T.Results]
end
function T.get(id) return type(id)=="string" and byId[id] or nil end
function T.label(id) local r=T.get(id) return r and r.label or "No Trait" end
function T.benefits(id,variant)
 local r=T.get(id);local b=r and r.benefits or {}
 return {moneyBonus=b.moneyBonus or 0,masteryMultiplier=(b.masteryMultiplier or 1)*(variant=="Enchanted" and (b.enchantedMasteryMultiplier or 1) or 1),sweetZoneMultiplier=b.sweetZoneMultiplier or 1}
end
return T

