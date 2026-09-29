-- Golden Meridian: the finale beyond the tenth awakening.
-- One server-owned session per player: rock -> arriving -> realm -> trial -> blessing -> return.
-- The client presents every beat. Only this module moves the character between the world
-- and the Spirit Realm, judges the divine skip, and writes the Golden Meridian into the save.
-- Nothing a client sends can grant it unless this session legitimately reached the trial.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local Profiles=require(script.Parent.Profiles)
local Persistence=require(script.Parent.Persistence)
local State=require(script.Parent.GoldenMeridianState)
local Gateway=require(script.Parent.World2Gateway)
local Progression=require(RS.Shared.ProgressionConfig)
local Config=require(RS.Shared.GoldenMeridianConfig)
local Remotes=require(RS.Shared.Remotes)
local G={}
local sessions={} -- [player] = live session
local returning={} -- [player] = anchored at the stone, waiting for the client to stream the world back
local slots={} -- [slot] = player; each session gets its own realm far from every other
local lastBegin,lastMessage,lastSeen={},{},{}
local event
local started=false

local function toast(player,text) Remotes.Toast:FireClient(player,text,"bad") end
local function rock() return workspace:FindFirstChild("MagicalRock") end
local function body(player)
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local hum=character and character:FindFirstChildOfClass("Humanoid")
 if not root or not hum or hum.Health<=0 then return end
 return character,root,hum
end
local function nearRock(player)
 local _,root=body(player)
 local model=rock()
 local anchor=model and model:FindFirstChild("InteractionAnchor")
 return root~=nil and anchor~=nil and anchor:IsA("BasePart") and (root.Position-anchor.Position).Magnitude<=Config.RockReach
end
local function standHeight(hum,root)
 return hum.RigType==Enum.HumanoidRigType.R6 and 3 or hum.HipHeight+root.Size.Y/2
end
local function claimSlot(player)
 local slot=0
 while slots[slot] do slot+=1 end
 slots[slot]=player
 return slot
end

-- Attributes are the client's read-only view of golden progress.
function G.sync(player)
 if not Profiles.has(player) then return end
 local profile=Profiles.get(player)
 if not profile.loaded then return end
 local path=State.get(profile)
 player:SetAttribute("GoldenPath",State.stage(profile))
 player:SetAttribute("GoldenInvitationSeen",path.invitationSeen==true)
 player:SetAttribute("GoldenEndingSeen",path.endingSeen==true)
 player:SetAttribute("GoldenMeridian",path.unlocked==true)
 player:SetAttribute("World2Unlocked",path.world2==true)
end

local function restoreBody(entry)
 local player,root,hum=entry.player,entry.root,entry.hum
 if root.Parent then
  root.Anchored=entry.saved.anchored
  root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
 end
 if hum.Parent then
  hum.WalkSpeed=entry.saved.walkSpeed;hum.AutoRotate=entry.saved.autoRotate
  hum:SetStateEnabled(Enum.HumanoidStateType.Jumping,entry.saved.jumping)
  if entry.tool and entry.tool.Parent==player:FindFirstChild("Backpack") and player.Character==entry.character and hum.Health>0 then
   hum:EquipTool(entry.tool)
  end
 end
 if player.Parent then
  player:SetAttribute("RebirthCinematic",false)
  player:SetAttribute("GoldenSession",false)
 end
end

-- Ends a session. Wherever it ended (realm, trial, a client error), a living character is
-- brought back to the stone and held there until its client has the world streamed in.
local function release(player,reason)
 local s=sessions[player]
 if not s then return end
 sessions[player]=nil
 if slots[s.slot]==player then slots[s.slot]=nil end
 for _,c in s.connections do c:Disconnect() end
 local alive=s.root.Parent~=nil and s.hum.Parent~=nil and s.hum.Health>0 and player.Character==s.character
 if alive and player.Parent then
  s.root.Anchored=true
  s.root.AssemblyLinearVelocity=Vector3.zero;s.root.AssemblyAngularVelocity=Vector3.zero
  s.root.CFrame=s.returnCFrame
  local entry={player=player,root=s.root,hum=s.hum,character=s.character,saved=s.saved,tool=s.tool,token=s.token}
  returning[player]=entry
  task.delay(Config.ReturnTimeout,function()
   if returning[player]==entry then returning[player]=nil;restoreBody(entry) end
  end)
 elseif player.Parent then
  player:SetAttribute("RebirthCinematic",false)
  player:SetAttribute("GoldenSession",false)
 end
 if player.Parent then event:FireClient(player,"Returned",{token=s.token,reason=reason}) end
end

local function commit(player,s)
 local profile=Profiles.get(player)
 local path=State.get(profile)
 -- One atomic grant: completing the trial awakens the Golden Meridian and opens World 2.
 path.trialStarted=true;path.trialCompleted=true;path.unlocked=true;path.world2=true
 if not Progression.isFinite(path.unlockedAt) then path.unlockedAt=os.time() end
 s.phase="blessing";s.committed=true
 Profiles.fireChanged(player)
 task.defer(Persistence.saveNow,player)
end

function G.begin(player)
 local now=os.clock()
 if now-(lastBegin[player] or -math.huge)<1 or sessions[player] or returning[player] then return false end
 lastBegin[player]=now
 if not Profiles.has(player) then return false end
 local profile=Profiles.get(player)
 if not profile.loaded then toast(player,"Your save is still loading.");return false end
 local stage=State.stage(profile)
 if stage=="Dormant" then return false end
 local path=State.get(profile)
 if not nearRock(player) then toast(player,"Come closer to the Magical Rock.");return false end
 if profile.pendingSummon or player:GetAttribute("RockInFlight")==true then toast(player,"Finish your throw or summon first.");return false end
 if player:GetAttribute("TrainingSpinning")==true or player:GetAttribute("TrainingAFK")==true then toast(player,"Finish training first.");return false end
 if player:GetAttribute("RebirthCinematic")==true then return false end
 local character,root,hum=body(player)
 if not character or root.Anchored or hum.Sit then toast(player,"Stand beside the stone.");return false end
 local model=rock()
 local stance=model and model:FindFirstChild("Stance")
 if not stance or not stance:IsA("BasePart") then return false end
 local mode=stage=="Invited" and "trial" or (path.endingSeen==true and "memory" or "unfinished")
 local slot=claimSlot(player)
 local s={token=Http:GenerateGUID(false),mode=mode,phase="rock",slot=slot,basis=Config.realmBasis(slot),
  character=character,root=root,hum=hum,tool=character:FindFirstChildOfClass("Tool"),connections={},
  saved={anchored=root.Anchored,walkSpeed=hum.WalkSpeed,autoRotate=hum.AutoRotate,jumping=hum:GetStateEnabled(Enum.HumanoidStateType.Jumping)},
  lastThrow=-math.huge,attempts=0}
 sessions[player]=s
 player:SetAttribute("RebirthCinematic",true) -- existing guard: blocks throws, training and the tutorial
 player:SetAttribute("GoldenSession",true)
 hum:UnequipTools()
 hum.WalkSpeed=0;hum.AutoRotate=false;hum:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
 root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero;root.Anchored=true
 root.CFrame=stance.CFrame+Vector3.new(0,standHeight(hum,root),0)
 s.returnCFrame=root.CFrame
 table.insert(s.connections,hum.Died:Connect(function() release(player,"interrupted") end))
 table.insert(s.connections,player.CharacterRemoving:Connect(function() release(player,"interrupted") end))
 table.insert(s.connections,character.ChildAdded:Connect(function(child)
  if child:IsA("Tool") then task.defer(function() if sessions[player]==s and hum.Parent then hum:UnequipTools() end end) end
 end))
 event:FireClient(player,"Begin",{token=s.token,mode=mode,basis=s.basis,rebirths=profile.rebirths})
 task.delay(Config.PrepareTimeout,function()
  if sessions[player]==s and (s.phase=="rock" or s.phase=="arriving") then release(player,"The way did not open. Try again.") end
 end)
 task.delay(Config.SessionTimeout,function() if sessions[player]==s then release(player,"The realm let you go.") end end)
 return true
end

-- Each handler is bound to the session token and its phase. Only the ones a client could
-- spam to any effect are rate limited (Begin, InvitationSeen, TrialReady, Throw); lifecycle
-- messages such as Landed or Cancel must never be dropped.
local handlers={}
handlers.EnterRealm=function(player,s)
 if s.phase~="rock" then return end
 s.phase="arriving"
 s.root.Anchored=true
 s.root.AssemblyLinearVelocity=Vector3.zero
 s.root.CFrame=s.basis*CFrame.new(0,standHeight(s.hum,s.root),0)
 event:FireClient(player,"Arrived",{token=s.token})
end
handlers.Walk=function(player,s)
 if s.phase~="arriving" then return end
 s.phase="realm"
 s.root.Anchored=false
 s.hum.WalkSpeed=Config.Realm.WalkSpeed;s.hum.AutoRotate=true
 s.hum:SetStateEnabled(Enum.HumanoidStateType.Jumping,true)
end
handlers.TrialReady=function(player,s)
 if s.phase~="realm" or s.mode~="trial" then return end
 local now=os.clock()
 if now-(lastMessage[player] or -math.huge)<.25 then return end
 lastMessage[player]=now
 local god=s.basis:PointToWorldSpace(Config.Realm.God)
 if (s.root.Position-god).Magnitude>Config.TrialRange then
  event:FireClient(player,"TrialHold",{token=s.token})
  return
 end
 s.phase="trial"
 local path=State.get(Profiles.get(player))
 if path.trialStarted~=true then path.trialStarted=true end -- saved with the next write
 event:FireClient(player,"TrialOpen",{token=s.token})
end
handlers.Throw=function(player,s,charge)
 if s.phase~="trial" then return end
 local now=os.clock()
 if now-s.lastThrow<Config.Trial.ThrowCooldown then return end
 s.lastThrow=now;s.attempts+=1
 local success=Progression.isFinite(charge) and charge>=Config.Trial.MinCharge and charge<=1.001
 if success then commit(player,s) end
 event:FireClient(player,"ThrowResult",{token=s.token,success=success,attempt=s.attempts})
end
handlers.Finish=function(player,s)
 local finished=(s.mode=="trial" and s.phase=="blessing") or (s.mode~="trial" and s.phase=="realm")
 if not finished then return end
 local profile=Profiles.get(player)
 local path=State.get(profile)
 if s.mode~="memory" and path.unlocked==true and path.endingSeen~=true then
  path.endingSeen=true
  Profiles.fireChanged(player)
  task.defer(Persistence.saveNow,player)
 end
 if Gateway.available(player,path) then
  local ok,sent=pcall(Gateway.send,player)
  if ok and sent then
   s.phase="leaving"
   task.delay(30,function() if sessions[player]==s then release(player,"The way beyond did not open.") end end)
   return
  end
 end
 release(player,nil)
end
handlers.Cancel=function(player,s) release(player,nil) end

function G.start()
 if started then return end
 started=true
 event=RS:FindFirstChild("GoldenMeridianEvent") or Instance.new("RemoteEvent")
 event.Name="GoldenMeridianEvent";event.Parent=RS
 event.OnServerEvent:Connect(function(player,action,token,value)
  if type(action)~="string" then return end
  local now=os.clock()
  if action=="Begin" then G.begin(player);return end
  if action=="InvitationSeen" then
   if now-(lastSeen[player] or -math.huge)<2 or not Profiles.has(player) then return end
   lastSeen[player]=now
   local profile=Profiles.get(player)
   if profile.loaded and State.stage(profile)~="Dormant" then
    local path=State.get(profile)
    if path.invitationSeen~=true then path.invitationSeen=true;Profiles.fireChanged(player) end
   end
   return
  end
  if type(token)~="string" or #token>64 then return end
  if action=="Landed" then
   local entry=returning[player]
   if entry and entry.token==token then returning[player]=nil;restoreBody(entry) end
   return
  end
  local s=sessions[player]
  local handler=handlers[action]
  if s and s.token==token and handler then handler(player,s,value) end
 end)
 Profiles.onChanged(G.sync)
 for _,player in Players:GetPlayers() do task.spawn(G.sync,player) end
 Players.PlayerRemoving:Connect(function(player)
  release(player,nil)
  returning[player]=nil
  for slot,owner in slots do if owner==player then slots[slot]=nil end end
  lastBegin[player]=nil;lastMessage[player]=nil;lastSeen[player]=nil
 end)
end

-- Read-only view for dev tools and future World 2 systems.
function G.session(player) return sessions[player] end
return G
