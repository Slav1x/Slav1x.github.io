--!nonstrict
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Tags=game:GetService("CollectionService")
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local M=require(RS.Shared.WaterPickupMotion)
local W=require(RS.Shared.CriticalWorldWindow)
local Sign=require(RS.Shared.EncounterSign)
local Tween=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local function breakBurst(record)
 local rng=Random.new()
 local count=0
 for _,entry in record.parts do
  local source=entry.part
  if source.Parent and not entry.ripple and source.Transparency<1 and count<10 then
   count+=1
   local shard=Instance.new("Part")
   shard.Name="WaterBreakFragment"
   shard.Size=Vector3.new(math.clamp(source.Size.X*.4,.4,2.2),math.clamp(source.Size.Y*.4,.35,1.4),math.clamp(source.Size.Z*.4,.4,2))
   shard.CFrame=source.CFrame;shard.Color=source.Color;shard.Material=source.Material
   shard.Anchored=true;shard.CanCollide=false;shard.CanTouch=false;shard.CanQuery=false
   shard.TopSurface=Enum.SurfaceType.Smooth;shard.BottomSurface=Enum.SurfaceType.Smooth
   shard.Parent=workspace.CurrentCamera
   local reduced=player:GetAttribute("ReducedMotion")==true
   local target=source.CFrame*CFrame.new(rng:NextNumber(-4,4),-rng:NextNumber(2,5),rng:NextNumber(-4,4))*CFrame.Angles(rng:NextNumber(-1,1),rng:NextNumber(-1,1),0)
   Tween:Create(shard,TweenInfo.new(if reduced then .25 else .75,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{CFrame=if reduced then source.CFrame else target,Transparency=1}):Play()
   Debris:AddItem(shard,1)
  end
 end
end
local P={}
local focus=nil
local pickups={}
local signs={}
local pending={}
local labelClock=0
local previewGui=nil
local function track(model)
 if pickups[model] or not model:IsA("Model") then return end
 local base=model:GetAttribute("PickupBase")
 if typeof(base)~="CFrame" or not model.PrimaryPart then pending[model]=true;return end
 pending[model]=nil
 local entries={};local known={}
 local function addPart(p)
  if not p:IsA("BasePart") or known[p] then return end
  known[p]=true
  table.insert(entries,{part=p,localCF=p:GetAttribute("PickupLocalCFrame") or base:ToObjectSpace(p.CFrame),ripple=p.Name=="SurfaceRipple",orbit=p.Name=="VortexArc" or p.Name=="OrbitPearl"})
 end
 for _,p in model:GetDescendants() do addPart(p) end
 local changed=model.DescendantAdded:Connect(addPart)
 local attachment=Instance.new("Attachment");attachment.Name="LocalWaterSpray";attachment.Parent=model.PrimaryPart
 local spray=Instance.new("ParticleEmitter");spray.Texture="rbxasset://textures/particles/sparkles_main.dds";spray.Rate=2;spray.Lifetime=NumberRange.new(.5,1.1);spray.Speed=NumberRange.new(1,2);spray.Acceleration=Vector3.new(0,-4,0);spray.SpreadAngle=Vector2.new(80,80);spray.Size=NumberSequence.new(.18);spray.Transparency=NumberSequence.new(.45);spray.Color=ColorSequence.new(Color3.fromRGB(213,244,249));spray.Enabled=false;spray.Parent=attachment
 pickups[model]={base=base,parts=entries,hidden=false,lastBreak=model:GetAttribute("BreakTime"),spray=spray,changed=changed,nextFrame=0}
end
local function label(gui)
 if not gui:IsA("BillboardGui") or signs[gui] then return end
 local model=gui:FindFirstAncestorWhichIsA("Model")
 gui.Enabled=false;gui.MaxDistance=10000
 Sign.layout(gui,false)
 if model and gui.Adornee then Sign.positionAbove(gui,model,gui.Adornee) end
 signs[gui]={model=model,alpha=0,wanted=false}
end
function P.setFocus(model) focus=model end
for _,m in Tags:GetTagged("WaterPickup") do track(m) end
for _,g in Tags:GetTagged("EncounterLabel") do label(g) end
Tags:GetInstanceAddedSignal("WaterPickup"):Connect(track)
Tags:GetInstanceAddedSignal("EncounterLabel"):Connect(label)
Tags:GetInstanceRemovedSignal("WaterPickup"):Connect(function(m) local r=pickups[m];if r then r.changed:Disconnect();if r.spray.Parent then r.spray.Parent:Destroy() end end;pickups[m]=nil;pending[m]=nil end)
Tags:GetInstanceRemovedSignal("EncounterLabel"):Connect(function(g) signs[g]=nil end)
Run.RenderStepped:Connect(function(dt)
 local camera=workspace.CurrentCamera;if not camera then return end
 local now=workspace:GetServerTimeNow()
 for model in pending do
  if not model:IsDescendantOf(workspace) then pending[model]=nil else track(model) end
 end
 local reduced=player:GetAttribute("ReducedMotion")==true
 local main=focus and focus.Parent and focus.PrimaryPart
 local velocity=main and main.AssemblyLinearVelocity or Vector3.zero
 local speed=main and math.max(Vector3.new(velocity.X,0,velocity.Z).Magnitude,focus:GetAttribute("LaunchSpeed") or 0) or 0
 local notice=main and W.notice(speed) or 65
 for model,r in pickups do
  if not model:IsDescendantOf(workspace) then r.changed:Disconnect();if r.spray.Parent then r.spray.Parent:Destroy() end;pickups[model]=nil;continue end
  local timeline=M.decode(model:GetAttribute("PickupTimeline"))
  if not timeline then continue end
  local distance=(r.base.Position-camera.CFrame.Position).Magnitude
  local near=distance<(main and W.lead(speed)+650 or 700)
  r.spray.Enabled=distance<180 and not reduced and M.availableForModel(model,now)
  if near then
   if distance>700 and now<r.nextFrame then continue end
   r.nextFrame=now+.1
   local stamp=model:GetAttribute("BreakTime")
   if stamp~=r.lastBreak then
    if stamp and now-stamp<1 then breakBurst(r) end
    r.lastBreak=stamp
   end
   local motion,fade=M.sample(timeline,now,model:GetAttribute("PickupSeed") or 0,model:GetAttribute("PickupDepth") or 26,reduced)
   if model:GetAttribute("Broken")==true then fade=1 end
   local claimedAt=model:GetAttribute("PickupClaimedAt")
   if typeof(claimedAt)=="number" then fade=math.max(fade,M.smooth((now-claimedAt)/.25)) end
   local bob=r.base*motion
   for _,e in r.parts do if e.part.Parent then
    if e.ripple then
     e.part.CFrame=r.base*e.localCF
     e.part.LocalTransparencyModifier=math.max(fade,if timeline.X==M.Active then .08+.12*(.5+.5*math.sin(now*1.6+(model:GetAttribute("PickupSeed") or 0))) else .5)
    else
     e.part.CFrame=M.partFrame(r.base,motion,e.localCF,e.orbit,now)
     e.part.LocalTransparencyModifier=fade
    end
   end end
   r.hidden=false
  elseif not r.hidden then
   for _,e in r.parts do if e.part.Parent then e.part.LocalTransparencyModifier=1 end end
   r.hidden=true
  end
 end
 labelClock+=dt
 if labelClock>=.08 then
  labelClock=0
  local main=focus and focus.Parent and focus.PrimaryPart
  if not main then local char=player.Character;main=char and char:FindFirstChild("HumanoidRootPart") end
  local maxRange=notice
  local candidates={}
  for gui,r in signs do
   r.wanted=false
   if not gui:IsDescendantOf(workspace) then signs[gui]=nil;continue end
   local model=r.model;local adornee=gui.Adornee
   if not main or not model or not model.Parent or not adornee then continue end
   local timeline=M.decode(model:GetAttribute("PickupTimeline"))
   if timeline and not M.availableForModel(model,now) then continue end
   if model:GetAttribute("Broken")==true then continue end
   local pos=adornee.Position
   local distance=(pos-main.Position).Magnitude
   local viewDistance=(pos-camera.CFrame.Position).Magnitude
   local screen,onScreen=camera:WorldToViewportPoint(pos+gui.StudsOffsetWorldSpace)
   -- Selection/overlap uses the lifted card center, not the object beneath it.
   screen-=Vector3.new(0,gui.Size.Y.Offset*gui.SizeOffset.Y,0)
   if distance<maxRange and viewDistance<maxRange+250 and onScreen then
    table.insert(candidates,{r=r,gui=gui,screen=screen,d=distance,forward=(pos-main.Position):Dot(speed>1 and Vector3.new(velocity.X,0,velocity.Z).Unit or camera.CFrame.LookVector),alpha=math.clamp((maxRange-distance)/math.max(60,speed*.25),0,1)})
   end
  end
  table.sort(candidates,function(a,b) return a.d<b.d end)
  -- Reserve a preview slot around 2.7 seconds ahead, rather than letting
  -- dense nearby pickups consume every label and reveal future choices too late.
  local preview,bestScore
  for _,c in candidates do if c.gui==previewGui and c.forward>=speed*1.5 then preview=c;break end end
  if speed>40 and not preview then
   for _,c in candidates do
    if c.forward>=speed*1.8 then
     local score=math.abs(c.forward-speed*2.7)
     if not bestScore or score<bestScore then preview=c;bestScore=score end
    end
   end
  end
  previewGui=preview and preview.gui or nil
  local chosen={}
  if preview then table.insert(chosen,preview) end
  for _,c in candidates do
   if #chosen>=2 then break end
   if c~=preview then
    local clear=true
    for _,picked in chosen do
     if math.abs(picked.screen.X-c.screen.X)<(picked.gui.Size.X.Offset+c.gui.Size.X.Offset)*.5+12 and math.abs(picked.screen.Y-c.screen.Y)<(picked.gui.Size.Y.Offset+c.gui.Size.Y.Offset)*.5+10 then clear=false end
    end
    if clear then table.insert(chosen,c) end
   end
  end
  for _,c in chosen do
   c.r.wanted=true;c.r.target=c.alpha
   local compact=c.d>250
   if c.r.compact~=compact then
    c.r.compact=compact;c.gui.AlwaysOnTop=compact
    Sign.layout(c.gui,compact)
   end
  end
 end
 local rate=1-math.exp(-dt*16)
 for gui,r in signs do
  if not gui.Parent then signs[gui]=nil;continue end
  local timeline=r.model and M.decode(r.model:GetAttribute("PickupTimeline"))
  -- Submergence takes precedence even between the slower proximity checks.
  if timeline and not M.availableForModel(r.model,now) then r.wanted=false end
  r.alpha+=( (r.wanted and r.target or 0)-r.alpha)*rate
  if not r.wanted then r.alpha=0 end -- Replaced choices must not linger over the next preview.
  gui.Enabled=r.alpha>.025
  local plate=gui:FindFirstChild("Plate")
  if plate and plate:IsA("CanvasGroup") then plate.GroupTransparency=1-r.alpha end
 end
end)
player.CharacterRemoving:Connect(function()
 focus=nil
 for gui,r in signs do r.alpha=0;r.wanted=false;if gui.Parent then gui.Enabled=false end end
end)
return P
