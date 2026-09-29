-- Presentation only. The server still owns SelectedSummonCollection and validates access.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local Zones=require(RS.Shared:WaitForChild("ZoneConfig"))
local Remotes=require(RS.Shared:WaitForChild("Remotes"))
local remote=RS:WaitForChild("SummonCollection")
local playerGui=player:WaitForChild("PlayerGui")
local gui=playerGui:WaitForChild("SummonPromptUI")
local old=gui:FindFirstChild("CollectionSwitcher");if old then old:Destroy() end
local world=playerGui:WaitForChild("SummonWorldUI")
local root=world:WaitForChild("SummonActions"):WaitForChild("PromptRoot")
local selector=root:WaitForChild("AreaSelector")
local Visual=require(RS.Shared:WaitForChild("SummonAreaSelector"))
local Store=require(player.PlayerScripts:WaitForChild("Client"):WaitForChild("ProfileStore"))
local profile=Store.get()
local pending=nil
local desiredId=nil
local confirmedId=player:GetAttribute("SelectedSummonCollection") or "driftwood"
local serial=0
local stopped=false
local connections={}
local function currentId()
 return player:GetAttribute("SelectedSummonCollection") or "driftwood"
end
local function available()
 -- Browsing is unrestricted; purchase eligibility is enforced by the server.
 return Zones.List
end
local tutorialWasEnabled=nil
local function restoreTutorial()
 local tutorial=playerGui:FindFirstChild("CoreTutorialUI")
 if tutorial and tutorialWasEnabled~=nil then tutorial.Enabled=tutorialWasEnabled end
 tutorialWasEnabled=nil
end
local function refresh()
 local zone=Zones.ById[currentId()] or Zones.List[1]
 Visual.setArea(selector,zone)
 local tutorial=playerGui:FindFirstChild("CoreTutorialUI")
 if root:GetAttribute("PromptActive")==true and tutorial then
  if tutorialWasEnabled==nil then tutorialWasEnabled=tutorial.Enabled end
  tutorial.Enabled=false
 else restoreTutorial() end
 local enabled=profile.loaded==true and root:GetAttribute("PromptActive")==true and not profile.hasPendingSummon and #available()>1
 for _,b in {selector.Previous,selector.Next} do
  b.Active=enabled;b.Selectable=enabled;b.AutoButtonColor=enabled
 end
end
local dispatch
local function send(request)
 if stopped or pending~=request then return end
 request.attempt+=1
 if request.attempt>4 then pending=nil;desiredId=nil;refresh();Remotes.RequestShopState:FireServer();return end
 remote:FireServer(request.id,request.serial)
 local attempt=request.attempt
 -- Retry an interrupted acknowledgement without losing a queued destination.
 task.delay(2,function()
  if pending==request and request.attempt==attempt then send(request) end
 end)
end
dispatch=function()
 if stopped or pending or not desiredId then return end
 if desiredId==confirmedId then desiredId=nil;return end
 serial+=1
 pending={id=desiredId,serial=serial,attempt=0}
 send(pending)
end
local function cycle(direction)
 if profile.loaded~=true or profile.hasPendingSummon or root:GetAttribute("PromptActive")~=true then return end
 local list=available()
 if #list<2 then return end
 local base=desiredId or (pending and pending.id) or confirmedId
 local index=1
 for i,zone in ipairs(list) do if zone.id==base then index=i;break end end
 desiredId=list[(index-1+direction)%#list+1].id
 dispatch()
end
table.insert(connections,selector.Previous.Activated:Connect(function() cycle(-1) end))
table.insert(connections,selector.Next.Activated:Connect(function() cycle(1) end))
table.insert(connections,Remotes.ProfileState.OnClientEvent:Connect(function(state)
 if type(state)=="table" then profile=state;refresh() end
end))
table.insert(connections,player:GetAttributeChangedSignal("SelectedSummonCollection"):Connect(function()
 if not pending and not desiredId then confirmedId=currentId() end
 refresh()
end))
table.insert(connections,root:GetAttributeChangedSignal("PromptActive"):Connect(refresh))
table.insert(connections,RS:WaitForChild("SummonFeedback").OnClientEvent:Connect(function(kind,data)
 if kind~="CollectionSelected" or type(data)~="table" or not pending then return end
 local request=pending
 if data.requestId~=request.serial or data.id~=request.id then return end
 if data.accepted==false and data.reason=="throttled" then
  request.attempt+=1 -- invalidate the prior timeout while waiting for the server window
  task.delay(math.clamp(tonumber(data.retryAfter) or .15,.01,1)+.02,function() send(request) end)
  return
 end
 pending=nil
 if data.accepted then
  confirmedId=data.id
  if desiredId==confirmedId then desiredId=nil end
  dispatch()
 else
  desiredId=nil;confirmedId=currentId();Remotes.RequestShopState:FireServer()
 end
 refresh()
end))
table.insert(connections,game:GetService("RunService").RenderStepped:Connect(function(dt)
 Visual.step(selector,dt,root:GetAttribute("PromptOpacity") or 0,root:GetAttribute("PromptActive")==true,player:GetAttribute("ReducedMotion")==true)
end))
local function cleanup()
 stopped=true;pending=nil;desiredId=nil
 restoreTutorial()
 Visual.cleanup(selector)
 for _,c in connections do c:Disconnect() end
 table.clear(connections)
end
script.Destroying:Connect(cleanup)
world.Destroying:Connect(cleanup)
Store.onChanged(function() profile=Store.get();refresh() end)
refresh()
Remotes.RequestShopState:FireServer()


