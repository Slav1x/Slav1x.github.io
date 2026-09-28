-- Server-authoritative coin egg hatching. All prices, pools, access and grants live here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("EggHatchConfig"))
local Zones = require(Shared:WaitForChild("ZoneConfig"))
local Catalog = require(Shared:WaitForChild("PetCatalog"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Profiles = require(script.Parent.Server:WaitForChild("Profiles"))
local displays = workspace:WaitForChild("EggDisplays")
local random = Random.new()
local lastRequest = {}

local function respond(player, ok, message, results, price)
 Remotes.EggHatchResult:FireClient(player, {
  ok=ok,message=message,results=results or {},price=price or 0,
 })
end

local function pick(pool)
 local ticket=random:NextInteger(1,100)
 for _,pet in ipairs(pool) do
  ticket-=pet.Weight
  if ticket<=0 then return pet end
 end
 return pool[#pool]
end

Remotes.RequestEggHatch.OnServerEvent:Connect(function(player,eggId,zoneId,quantity)
 if type(eggId)~="string" or type(zoneId)~="string" or type(quantity)~="number" then return end
 if quantity~=1 and quantity~=3 then return end
 if eggId~="Egg1" and eggId~="Egg2" then
  respond(player,false,"This egg is not available yet.")
  return
 end
 local now=os.clock()
 if now-(lastRequest[player] or 0)<0.45 then
  respond(player,false,"Wait a moment before hatching again.")
  return
 end
 lastRequest[player]=now

 local profile=Profiles.get(player)
 if not profile.loaded then respond(player,false,"Your inventory is still loading.") return end
 local zone=Zones.ById[zoneId]
 if not zone then return end
 if not Zones.unlocked(profile,zoneId) then
  respond(player,false,"Discover "..zone.name.." before hatching its pets.")
  return
 end
 local egg=displays:FindFirstChild(eggId)
 local anchor=egg and egg:FindFirstChild("InteractionPoint")
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 if not anchor or not root or not humanoid or humanoid.Health<=0 or (root.Position-anchor.Position).Magnitude>15 then
  respond(player,false,"Move closer to the egg to hatch.")
  return
 end
 local pool=Config.pool(eggId,zoneId)
 local each=Config.price(eggId,zoneId)
 if not pool or not each then return end
 local total=each*quantity
 local money=Profiles.moneyValue(player)
 if not money or money.Value<total then
  respond(player,false,"You need "..Config.formatMoney(total).." coins.")
  return
 end
 if type(profile.petsOwned)~="table" or type(profile.discoveredPets)~="table" or type(profile.petCounts)~="table" then
  respond(player,false,"Your pet inventory is not ready. Please rejoin.")
  return
 end
 local results={}
 for i=1,quantity do
  local pet=pick(pool)
  if not Catalog.exists(pet.Id) then
   warn("[EggHatch] Missing catalog entry: "..pet.Id)
   respond(player,false,"This egg is temporarily unavailable.")
   return
  end
  results[i]={id=pet.Id,name=pet.Name,model=pet.Model,rarity=pet.Rarity,
   color=pet.Color,isNew=not profile.petsOwned[pet.Id]}
 end
 -- No yields between payment, ownership and snapshot.
 if not Profiles.trySpend(player,total) then
  respond(player,false,"You need "..Config.formatMoney(total).." coins.")
  return
 end
 for _,pet in ipairs(results) do
  profile.petsOwned[pet.id]=true
  profile.discoveredPets[pet.id]=true
  profile.petCounts[pet.id]=math.min(1000000,(profile.petCounts[pet.id] or 0)+1)
  pet.count=profile.petCounts[pet.id]
 end
 Profiles.fireChanged(player)
 respond(player,true,"Hatched "..tostring(quantity).." pet"..(quantity==1 and "" or "s").."!",results,total)
end)

Players.PlayerRemoving:Connect(function(player) lastRequest[player]=nil end)

