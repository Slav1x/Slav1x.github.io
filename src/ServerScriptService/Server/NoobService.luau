-- Noob owns Rebirth access; the existing progression service owns the reset.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local Profiles=require(script.Parent.Profiles)
local Progression=require(RS.Shared.ProgressionConfig)
local N={}
local confirmations={}
local last={}
local started=false
-- Repair authored/missing interaction parts on boot. The NPC art remains unchanged.
function N.ensureInteraction(npc)
 if not npc then
  local terrain=workspace:FindFirstChild("terrain")
  npc=terrain and terrain:FindFirstChild("noob")
 end
 if not npc then return nil end
 local torso=npc:FindFirstChild("Torso",true) or npc:FindFirstChild("HumanoidRootPart",true) or npc:FindFirstChild("Head",true)
 if not torso or not torso:IsA("BasePart") then return nil end
 local anchor=npc:FindFirstChild("DialogueAnchor")
 if anchor and not anchor:IsA("BasePart") then anchor:Destroy();anchor=nil end
 if not anchor then anchor=Instance.new("Part");anchor.Name="DialogueAnchor";anchor.Parent=npc end
 anchor.Size=Vector3.one;anchor.CFrame=torso.CFrame+Vector3.new(0,1,0)
 anchor.Transparency=1;anchor.Anchored=true;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false;anchor.CastShadow=false
 local prompt=anchor:FindFirstChild("RebirthPrompt")
 if prompt and not prompt:IsA("ProximityPrompt") then prompt:Destroy();prompt=nil end
 if not prompt then prompt=Instance.new("ProximityPrompt");prompt.Name="RebirthPrompt";prompt.Parent=anchor end
 prompt.ActionText="Talk about Rebirth";prompt.ObjectText="Noob"
 prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.GamepadKeyCode=Enum.KeyCode.ButtonX
 prompt.Style=Enum.ProximityPromptStyle.Default;prompt.RequiresLineOfSight=false
 prompt.MaxActivationDistance=12;prompt.HoldDuration=0;prompt.Enabled=true
 prompt:SetAttribute("NoobDialogue",true)
 for _,other in npc:GetDescendants() do
  if other:IsA("ProximityPrompt") and other~=prompt and other:GetAttribute("NoobDialogue")==true then other.Enabled=false end
 end
 return anchor
end
local function nearby(player)
 local terrain=workspace:FindFirstChild("terrain")
 local npc=terrain and terrain:FindFirstChild("noob")
 local anchor=npc and npc:FindFirstChild("DialogueAnchor")
 if not anchor then anchor=N.ensureInteraction(npc) end
 local char=player.Character
 local root=char and char:FindFirstChild("HumanoidRootPart")
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 return anchor and root and hum and hum.Health>0 and (root.Position-anchor.Position).Magnitude<=15
end
local function status(player)
 local p=Profiles.get(player)
 local money=Profiles.moneyValue(player)
 local cash=money and money.Value or 0
 local ready,reason=Progression.canRebirth(p,cash)
 local q=Progression.rebirthRequirements(p.rebirths)
 local nextCount=math.min(p.rebirths+1,Progression.MaxRebirths)
 local requirements={
  {label="Complete "..q.areaName.." this journey",met=(p.cycleCompletedAreas or {})[q.areaId]==true},
  {label="Spin Strength: "..Progression.formatStrength(p.spinStrength).." / "..Progression.formatStrength(q.strength),met=p.spinStrength>=q.strength},
  {label=string.format("Throw Power: %d / %d",p.upgrades.power or 0,q.powerLevel),met=(p.upgrades.power or 0)>=q.powerLevel},
  {label="Money: $"..Progression.formatStrength(cash).." / $"..Progression.formatStrength(q.cost),met=cash>=q.cost},
 }
 return {ready=ready,reason=reason,current=p.rebirths,next=nextCount,requirements=requirements,
  benefit=string.format("Strength ceiling: %s → %s. Permanent money bonus: +%d%% → +%d%%. Spin gain multiplier: %.2fx → %.2fx.",Progression.formatStrength(Progression.strengthCap(p.rebirths)),Progression.formatStrength(q.nextStrengthCap),math.round(p.rebirths*Progression.RebirthMoneyBonus*100),math.round(nextCount*Progression.RebirthMoneyBonus*100),Progression.rebirthGainMultiplier(p.rebirths),Progression.rebirthGainMultiplier(nextCount)),
  resets="Money becomes $0; Spin Strength returns to 10; upgrades and this journey's best distance and area completions reset.",
  keeps="Rocks and variants, traits, pets, shards, mastery, abilities, discoveries, permanent area rewards, titles and redeemed codes stay."}
end
function N.consumeConfirmation(player,token)
 local receipt=confirmations[player];confirmations[player]=nil
 return type(token)=="string" and receipt~=nil and receipt.token==token and os.clock()<receipt.expires and receipt.rebirths==Profiles.get(player).rebirths and nearby(player)==true
end
function N.start()
 if started then return end;started=true
 N.ensureInteraction()
 -- Handles a world/NPC inserted after services boot without a per-frame loop.
 workspace.DescendantAdded:Connect(function(instance)
  if instance.Name=="noob" or instance.Name=="Torso" then task.defer(N.ensureInteraction) end
 end)
 local remote=RS:FindFirstChild("NoobDialogue") or Instance.new("RemoteFunction")
 remote.Name="NoobDialogue";remote.Parent=RS
 remote.OnServerInvoke=function(player,action)
  if type(action)~="string" or not nearby(player) then return {error="Come a little closer to Noob."} end
  if os.clock()-(last[player] or -math.huge)<.15 then return {error="One thought at a time!"} end
  last[player]=os.clock()
  local p=Profiles.get(player)
  if not p.loaded then return {error="Your save is still loading."} end
  if action=="rebirth" then
   local result=status(player)
   if p.pendingSummon or player:GetAttribute("RockInFlight")==true then result.ready=false;result.reason="Finish your throw or summon first." end
   if result.ready then
    local token=Http:GenerateGUID(false)
    confirmations[player]={token=token,expires=os.clock()+45,rebirths=p.rebirths}
    result.token=token
   end
   return result
  elseif action=="cancel" then confirmations[player]=nil;return {text="No rush. The lake isn't going anywhere."}
  elseif action=="aboutRebirth" then
   confirmations[player]=nil
   return {text="Rebirth resets this journey's money, strength and upgrades for a higher strength ceiling, faster rebuilding and a permanent money bonus. Rocks, variants, traits, pets, mastery and discoveries stay. Choose Rebirth to review the exact changes, then confirm."}
  end
  confirmations[player]=nil
  return {text="Looking to Rebirth? I'll show your requirements and exactly what changes before you confirm."}
 end
 Players.PlayerRemoving:Connect(function(p) confirmations[p]=nil;last[p]=nil end)
end
return N

