-- Only the successful server reward path calls announce; clients cannot submit pulls.
local M={}
local RS=game:GetService("ReplicatedStorage")
local Catalog=require(RS.Shared.RockCatalog)
local Progression=require(script.Parent.GeodeProgression)
local remote=RS:FindFirstChild("SummonAnnouncement") or Instance.new("RemoteEvent")
remote.Name="SummonAnnouncement";remote.Parent=RS
function M.payload(player,id)
 local rock=Catalog.get(id)
 local rank=table.find(Progression.Order,rock.rarity)
 local threshold=table.find(Progression.Order,"Legendary")
 if not rank or not threshold or rank<threshold then return nil end
 return {username=player.Name,id=id,rarity=rock.rarity}
end
function M.announce(player,id)
 local payload=M.payload(player,id)
 if payload then remote:FireAllClients(payload) end
end
return M