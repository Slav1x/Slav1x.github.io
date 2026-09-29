-- Server-owned review -> prepare -> play -> commit -> release transaction.
-- No client timestamp, animation marker or supplied count awards a rebirth.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local Profiles=require(script.Parent.Profiles)
local Persistence=require(script.Parent.Persistence)
local Progression=require(RS.Shared.ProgressionConfig)
local Config=require(RS.Shared.AwakeningConfig)
local Remotes=require(RS.Shared.Remotes)
local A={}
local sessions,receipts,lastReview,lastBegin,lastMessage={},{},{},{},{}
local started=false
local completeRebirth
local event
local function rock()
 return workspace:FindFirstChild("MagicalRock")
end
local function body(player)
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local hum=character and character:FindFirstChildOfClass("Humanoid")
 if not root or not hum or hum.Health<=0 then return end
 return character,root,hum
end
local function nearby(player)
 local _,root=body(player)
 local model=rock()
 local anchor=model and model:FindFirstChild("InteractionAnchor")
 return root~=nil and anchor~=nil and (root.Position-anchor.Position).Magnitude<=Config.MaxDistance
end
local function ready(player)
 local p=Profiles.get(player)
 if not p.loaded then return false,"Your save is still loading." end
 if Persistence.isWriting(player) then return false,"Your save is finishing. Try again in a moment." end
 if p.pendingSummon or player:GetAttribute("RockInFlight")==true then return false,"Finish your throw or summon first." end
 if player:GetAttribute("TrainingSpinning")==true or player:GetAttribute("TrainingAFK")==true then return false,"Finish training before awakening." end
 local money=Profiles.moneyValue(player)
 return Progression.canRebirth(p,money and money.Value or 0)
end
local function status(player)
 local p=Profiles.get(player)
 local money=Profiles.moneyValue(player)
 local cash=money and money.Value or 0
 local eligible,reason=ready(player)
 local q=Progression.rebirthRequirements(p.rebirths)
 local count=math.min(p.rebirths+1,Progression.MaxRebirths)
 return {ready=eligible,reason=reason,current=p.rebirths,next=count,
  requirements={
   {label="Complete "..q.areaName.." this journey",met=(p.cycleCompletedAreas or {})[q.areaId]==true},
   {label="Spin Strength  "..Progression.formatStrength(p.spinStrength).." / "..Progression.formatStrength(q.strength),met=p.spinStrength>=q.strength},
   {label=string.format("Throw Power  %d / %d",p.upgrades.power or 0,q.powerLevel),met=(p.upgrades.power or 0)>=q.powerLevel},
   {label="$"..Progression.formatStrength(cash).." / $"..Progression.formatStrength(q.cost),met=cash>=q.cost},
  },
  benefit=string.format("Strength ceiling  %s → %s\nPermanent cash bonus  +%d%% → +%d%%\nSpin gains  %.2fx → %.2fx",Progression.formatStrength(Progression.strengthCap(p.rebirths)),Progression.formatStrength(q.nextStrengthCap),math.round(p.rebirths*Progression.RebirthMoneyBonus*100),math.round(count*Progression.RebirthMoneyBonus*100),Progression.rebirthGainMultiplier(p.rebirths),Progression.rebirthGainMultiplier(count)),
  resets="Cash, upgrades and this journey's area progress reset. Spin Strength returns to 10.",
  keeps="Your rocks, variants, traits, pets, shards, mastery, abilities and discoveries stay."}
end
local function release(player,reason)
 local s=sessions[player]
 if not s then return end
 sessions[player]=nil
 for _,c in s.connections do c:Disconnect() end
 if s.root.Parent then
  s.root.Anchored=s.anchored
  s.root.AssemblyLinearVelocity=Vector3.zero
  s.root.AssemblyAngularVelocity=Vector3.zero
 end
 if s.hum.Parent then
  s.hum.AutoRotate=s.autoRotate
  s.hum.WalkSpeed=s.walkSpeed
  s.hum:SetStateEnabled(Enum.HumanoidStateType.Jumping,s.jumping)
  if s.tool and s.tool.Parent==player:FindFirstChild("Backpack") and player.Character==s.character and s.hum.Health>0 then
   s.hum:EquipTool(s.tool)
  end
 end
 if player.Parent then
  player:SetAttribute("RebirthCinematic",false)
  if reason then event:FireClient(player,"Abort",{token=s.token,reason=reason,committed=s.committed==true}) end
 end
end
local function commit(player,s)
 if sessions[player]~=s or s.phase~="playing" then return end
 local character,root=body(player)
 if character~=s.character or root~=s.root or not nearby(player) then release(player,"The awakening was interrupted.");return end
 if Profiles.get(player).rebirths~=s.before then release(player,"Your progression changed. Approach the stone again.");return end
 local eligible,reason=ready(player)
 if not eligible then release(player,reason);return end
 s.phase="committing" -- consume before calling code that emits profile signals
 local ok,success,count=pcall(completeRebirth,player)
 if not ok or not success then
  warn("[Awakening] commit rejected",ok and count or success)
  release(player,"The awakening could not finish. Your current progress is safe.")
  return
 end
 s.committed=true;s.phase="complete"
 event:FireClient(player,"Complete",{token=s.token,count=count,skipped=s.skipped==true})
end
function A.begin(player,token)
 local now=os.clock()
 if now-(lastBegin[player] or -math.huge)<.75 or sessions[player] then return false end
 lastBegin[player]=now
 if type(token)~="string" or #token>64 then return false end
 local receipt=receipts[player]
 if not receipt or receipt.token~=token or now>receipt.expires or receipt.before~=Profiles.get(player).rebirths or not nearby(player) then
  Remotes.Toast:FireClient(player,"Approach the Magical Rock and review your awakening first.","bad");return false
 end
 receipts[player]=nil
 local eligible,reason=ready(player)
 if not eligible then Remotes.Toast:FireClient(player,reason,"bad");return false end
 local character,root,hum=body(player)
 if not character or root.Anchored or hum.Sit then Remotes.Toast:FireClient(player,"Stand beside the stone to awaken.","bad");return false end
 local model=rock();local stance=model and model:FindFirstChild("Stance")
 if not stance then return false end
 local s={token=Http:GenerateGUID(false),before=Profiles.get(player).rebirths,phase="preparing",character=character,root=root,hum=hum,
  anchored=root.Anchored,walkSpeed=hum.WalkSpeed,autoRotate=hum.AutoRotate,jumping=hum:GetStateEnabled(Enum.HumanoidStateType.Jumping),tool=character:FindFirstChildOfClass("Tool"),connections={}}
 sessions[player]=s
 player:SetAttribute("RebirthCinematic",true)
 hum:UnequipTools()
 hum.WalkSpeed=0;hum.AutoRotate=false;hum:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
 root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero;root.Anchored=true
 local height=hum.RigType==Enum.HumanoidRigType.R6 and 3 or hum.HipHeight+root.Size.Y/2
 root.CFrame=stance.CFrame+CFrame.new(0,height,0).Position
 table.insert(s.connections,hum.Died:Connect(function() release(player,"The awakening was interrupted.") end))
 table.insert(s.connections,player.CharacterRemoving:Connect(function() release(player,"The awakening was interrupted.") end))
 table.insert(s.connections,character.ChildAdded:Connect(function(child)
  if child:IsA("Tool") then task.defer(function() if sessions[player]==s and hum.Parent then hum:UnequipTools() end end) end
 end))
 event:FireClient(player,"Begin",{token=s.token,count=s.before+1})
 task.delay(7,function() if sessions[player]==s and s.phase=="preparing" then release(player,"The scene could not load. Please try again.") end end)
 task.delay(Config.Timeout,function() if sessions[player]==s then release(player,"The awakening has returned you to the world.") end end)
 return true
end
function A.start(commitCallback)
 if started then return end
 started=true;completeRebirth=commitCallback
 event=RS:FindFirstChild("AwakeningEvent") or Instance.new("RemoteEvent")
 event.Name="AwakeningEvent";event.Parent=RS
 local review=RS:FindFirstChild("AwakeningReview") or Instance.new("RemoteFunction")
 review.Name="AwakeningReview";review.Parent=RS
 review.OnServerInvoke=function(player,action)
  if type(action)~="string" then return {error="Invalid request."} end
  if action=="cancel" then receipts[player]=nil;return {} end
  local now=os.clock()
  if now-(lastReview[player] or -math.huge)<.3 then return {error="The stone is listening…"} end
  lastReview[player]=now
  if action~="review" or sessions[player] or not nearby(player) then return {error="Come closer to the Magical Rock."} end
  local result=status(player)
  if result.ready then
   local token=Http:GenerateGUID(false)
   receipts[player]={token=token,before=Profiles.get(player).rebirths,expires=now+60}
   result.token=token
  end
  return result
 end
 Remotes.RequestRebirth.OnServerEvent:Connect(A.begin)
 event.OnServerEvent:Connect(function(player,action,token)
  if type(action)~="string" or type(token)~="string" or #token>64 then return end
  local s=sessions[player]
  if not s or s.token~=token then return end
  if action=="Cancel" then release(player,"The awakening was interrupted.");return end
  if action=="Finish" and s.phase=="complete" then release(player);return end
  local now=os.clock()
  if now-(lastMessage[player] or -math.huge)<.1 then return end
  lastMessage[player]=now
  if action=="Ready" and s.phase=="preparing" then
   s.phase="playing";s.started=now
   event:FireClient(player,"Play",{token=s.token,at=workspace:GetServerTimeNow()+.15})
   task.delay(Config.ActivationTime+.15,function() commit(player,s) end)
  elseif action=="Skip" and s.phase=="playing" and now-s.started>=Config.SkipAfter then
   s.skipped=true;commit(player,s)
  end
 end)
 Players.PlayerRemoving:Connect(function(player)
  release(player);receipts[player]=nil;lastReview[player]=nil;lastBegin[player]=nil;lastMessage[player]=nil
 end)
end
return A
