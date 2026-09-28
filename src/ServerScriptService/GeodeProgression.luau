-- Each milestone draws a NEW server-side roll, conditional on tiers still reachable.
local P={}
local Config=require(game.ReplicatedStorage.Shared.SummonConfig)
local Catalog=require(game.ReplicatedStorage.Shared.RockCatalog)
P.Order={"Common","Uncommon","Rare","Epic","Legendary","Mythical"}
local Geode=require(game.ReplicatedStorage.Shared.GeodeReveal)
P.Cracks={}
for i,rarity in P.Order do P.Cracks[i]=Geode.settings(rarity).cracks end
local oldCracks={3,4,5,6,7,10}
local previousCracks={2,2,2,3,3,4}
function P.new(zoneId,firstGuaranteed,luckMultiplier)
 local pool={}
 local zone=require(game.ReplicatedStorage.Shared.ZoneConfig).ById[zoneId or "driftwood"]
 assert(zone,"Unknown summon collection")
 local source=firstGuaranteed and {{id="pebble",weight=100}} or zone.pool
 for _,entry in source do
  local tier=table.find(P.Order,Catalog.get(entry.id).rarity)
  assert(tier and entry.weight>0)
  local weight=entry.weight
  if tier>=3 and luckMultiplier==2 then weight=math.min(1000000,weight*2) end
  table.insert(pool,{id=entry.id,weight=weight,tier=tier})
 end
 local firstTier=6
 for _,entry in pool do firstTier=math.min(firstTier,entry.tier) end
 local total=0
 for i=1,firstTier-1 do total+=P.Cracks[i] end
 return {version=3,tier=firstTier,hits=0,total=total,pool=pool}
end
function P.restore(value)
 if type(value)=="table" and value.version==4 then
  if type(value.entries)~="table" or #value.entries<1 or #value.entries>3 then return nil end
  local entries={}
  for _,entry in value.entries do
   if type(entry)~="table" or entry.version==4 then return nil end
   local restored=P.restore(entry)
   if not restored then return nil end
   table.insert(entries,restored)
  end
  return {version=4,entries=entries}
 end
 if type(value)~="table" or (value.version~=1 and value.version~=2 and value.version~=3) then return nil end
 local savedCracks=value.version==1 and oldCracks or value.version==2 and previousCracks or P.Cracks
 local tier=value.tier;local hits=value.hits;local total=value.total
 if type(tier)~="number" or tier%1~=0 or tier<1 or tier>6 then return nil end
 if type(hits)~="number" or hits%1~=0 or hits<0 or hits>savedCracks[tier] then return nil end
 local expected=hits;for i=1,tier-1 do expected+=savedCracks[i] end
 if total~=expected or type(value.pool)~="table" or #value.pool==0 or #value.pool>100 then return nil end
 local pool={}
 for _,entry in value.pool do
  if type(entry)~="table" or type(entry.id)~="string" or not Catalog.exists(entry.id) then return nil end
  if type(entry.weight)~="number" or entry.weight%1~=0 or entry.weight<=0 or entry.weight>1000000 then return nil end
  if type(entry.tier)~="number" or entry.tier%1~=0 or entry.tier<1 or entry.tier>6 then return nil end
  table.insert(pool,{id=entry.id,weight=entry.weight,tier=entry.tier})
 end
 local reachable=0;for _,e in pool do if e.tier>=tier then reachable+=e.weight end end
 if reachable==0 then return nil end
 if value.version<3 then
  -- Retain the paid tier and credit proportional progress on the shorter schedule.
  hits=math.min(P.Cracks[tier],math.ceil(hits/savedCracks[tier]*P.Cracks[tier]))
  total=hits;for i=1,tier-1 do total+=P.Cracks[i] end
 end
 return {version=3,tier=tier,hits=hits,total=total,pool=pool}
end
function P.strike(state)
 if state.hits>=P.Cracks[state.tier] then return false end
 state.hits+=1;state.total+=1;return true
end
function P.resolve(state,random)
 assert(state.hits==P.Cracks[state.tier],"Milestone not reached")
 local remaining,current=0,0
 for _,e in state.pool do
  if e.tier>=state.tier then remaining+=e.weight end
  if e.tier==state.tier then current+=e.weight end
 end
 assert(remaining>0)
 if random:NextInteger(1,remaining)<=current then
  local ticket=random:NextInteger(1,current)
  for _,e in state.pool do if e.tier==state.tier then
   ticket-=e.weight;if ticket<=0 then return e.id end
  end end
 end
 assert(state.tier<6,"No terminal reward")
 state.tier+=1;state.hits=0
 return nil
end
return P