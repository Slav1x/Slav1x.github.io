--!nonstrict
-- Only the server-owned thrown rock can discover a new river area.
local RS=game.ReplicatedStorage
local Zones=require(RS.Shared.ZoneConfig)
local Water=require(RS.Shared.WaterSurface)
local Profiles=require(script.Parent.Profiles)
local Remotes=require(RS.Shared.Remotes)
local P={}
function P.discover(profile,position)
 local found={}
 if not profile.loaded or typeof(position)~="Vector3" then return found end
 if position.X~=position.X or position.Y~=position.Y or position.Z~=position.Z then return found end
 if not Water.at(position) then return found end
 local distance=Zones.distanceAt(position)
 profile.discoveredZones=profile.discoveredZones or {driftwood=true}
 for _,zone in ipairs(Zones.List) do
  if distance>=zone.start and not profile.discoveredZones[zone.id] then
   profile.discoveredZones[zone.id]=true
   if zone.start>0 then table.insert(found,zone) end
  end
 end
 return found
end
function P.observeThrow(player,position)
 local found=P.discover(Profiles.get(player),position)
 if #found==0 then return end
 Profiles.fireChanged(player)
 for _,zone in ipairs(found) do
  Remotes.Toast:FireClient(player,zone.name.." DISCOVERED • NEW ROCK COLLECTION UNLOCKED","epic")
 end
end
return P