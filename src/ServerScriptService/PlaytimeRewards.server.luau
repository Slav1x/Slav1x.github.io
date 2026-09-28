local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Config=require(RS.Shared.PlaytimeRewardConfig)
local Profiles=require(game.ServerScriptService.Server.Profiles)
local Persistence=require(game.ServerScriptService.Server.Persistence)
local sessions={}
local function added(p) sessions[p]={started=os.time(),claimed={},last=0} end
Players.PlayerAdded:Connect(added)
for _,p in Players:GetPlayers() do added(p) end
Players.PlayerRemoving:Connect(function(p) sessions[p]=nil end)
RS.PlaytimeRewards.OnServerInvoke=function(p,id)
 local s=sessions[p] if not s then return {error="Loading rewards..."} end
 local elapsed=os.time()-s.started
 local message
 if id~=nil then
  if type(id)~="string" or #id>32 then return {error="Invalid reward."} end
  if os.clock()-s.last<.35 then return {error="Please wait a moment."} end
  s.last=os.clock()
  local entry
  for _,e in Config do if e.id==id then entry=e break end end
  if not entry or elapsed<entry.seconds then message="This gift is not ready yet."
  elseif s.claimed[id] then message="Already claimed."
  elseif not Profiles.get(p).loaded or not Profiles.moneyValue(p) then message="Your data is still loading."
  else
   s.claimed[id]=true
   Profiles.addMoney(p,entry.cash)
   Profiles.fireChanged(p)
   task.spawn(Persistence.saveNow,p)
   message="Gift claimed!"
  end
 end
 return {elapsed=elapsed,claimed=table.clone(s.claimed),message=message}
end
