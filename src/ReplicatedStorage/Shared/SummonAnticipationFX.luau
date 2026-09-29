-- One camera/audio layer per batch; each opening owns its own screen debris burst.
local FX={}
local Run=game:GetService("RunService")
local Players=game:GetService("Players")
local SoundService=game:GetService("SoundService")
local player=Players.LocalPlayer
local AuraBurst=require(script.Parent.SummonAuraBurst)
local tiers={Common=1,Uncommon=2,Rare=3,Epic=4,Legendary=5,Mythical=6}
local function rarityTier(data,fallback)
 local rank=data.rarityTier
 if type(rank)=="number" and rank==rank and rank<math.huge and rank>=1 then return math.floor(rank) end
 return tiers[data.rarity] or fallback or 1
end
local strength={.0015,.0035,.007,.013,.022,.035}
local volume={.07,.12,.2,.31,.46,.65}
local Registry=require(script.Parent.SummonSceneRegistry)
local active
local function removeOffset(s)
 if s.offset and s.camera and workspace.CurrentCamera==s.camera then s.camera.CFrame=s.camera.CFrame*s.offset:Inverse() end
 s.offset=nil
end
function FX.stop()
 local s=active;if not s then return end;active=nil
 Run:UnbindFromRenderStep("SummonTensionReset")
 Run:UnbindFromRenderStep("SummonTension")
 removeOffset(s)
 for _,burst in s.bursts do burst:destroy() end
 s.folder:Destroy()
end
local function crumble(s,lane,count)
 local random=s.random
 for i=1,count do
  lane.cursor=lane.cursor%18+1
  local item=lane.pool[lane.cursor]
  if not item then
   local p=Instance.new(lane.cursor%2==0 and "WedgePart" or "Part")
   p.Name="FallingShellChip";p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
   p.Material=Enum.Material.Slate;p.Color=Color3.fromRGB(87,80,102):Lerp(Color3.new(1,1,1),.25);p.CastShadow=false;p.Parent=s.folder
   item={part=p};lane.pool[lane.cursor]=item
  end
  local direction=Vector3.new(random:NextNumber(-1,1),random:NextNumber(-.7,1),random:NextNumber(-1,1))
  if direction.Magnitude<.01 then direction=Vector3.xAxis end
  direction=direction.Unit
  local center=lane.position
  if lane.shell and lane.shell.Parent then center=lane.shell:GetPivot().Position end
  item.origin=center+direction*Vector3.new(1.65,1.78,1.6)
  item.velocity=Vector3.new(direction.X*.8,-.6,direction.Z*.8)
  item.born=s.clock;item.life=random:NextNumber(.6,1)
  item.rotation=Vector3.new(random:NextNumber(-3,3),random:NextNumber(-3,3),random:NextNumber(-3,3))
  item.part.Size=Vector3.new(.12,.09,.16)*random:NextNumber(.6,1.6)
  item.part.Transparency=0;item.part.Position=item.origin
 end
end
local function screenBurst(s,lane,data)
 -- Only a Legendary-or-higher reward throws debris onto the player's screen.
 if lane.tier<5 or player:GetAttribute("ReducedMotion")==true then return end
 local slot=data.slot or lane.slot or 1
 if s.bursts[slot] then s.bursts[slot]:destroy() end
 s.bursts[slot]=AuraBurst.new(player.PlayerGui,data.position or lane.position,lane.tier,s.token+slot*8191)
end
function FX.begin(data)
 FX.stop()
 local folder=Instance.new("Folder");folder.Name="SummonAnticipation";folder.Parent=workspace
 local s={folder=folder,token=data.token,clock=0,lanes={},bursts={},tier=1,pulse=0,random=Random.new(data.token),opened=false}
 active=s
 for i,entry in data.geodes or {data} do
  s.lanes[i]={slot=i,position=entry.position,tier=rarityTier(entry),pool={},cursor=0,clock=0,cracked=(entry.total or 0)>0}
  s.tier=math.max(s.tier,s.lanes[i].tier)
 end
 for _,spec in {{name="RockCrumble",id="rbxassetid://9118689425"},{name="FallingGrit",id="rbxassetid://9118770617"}} do
  local sound=Instance.new("Sound");sound.Name=spec.name;sound.SoundId=spec.id
  sound.Volume=0;sound.Looped=true;sound.PlaybackSpeed=spec.name=="RockCrumble" and .85 or 1.05
  sound.Parent=folder;sound:Play();s[spec.name]=sound
 end
 Run:BindToRenderStep("SummonTensionReset",Enum.RenderPriority.Camera.Value-1,function() removeOffset(s) end)
 Run:BindToRenderStep("SummonTension",Enum.RenderPriority.Camera.Value+2,function(dt)
  s.clock+=dt
  local reduced=player:GetAttribute("ReducedMotion")==true
  s.pulse=math.max(0,s.pulse-dt*2.8)
  local crumbling=false
  for _,lane in s.lanes do
   if not lane.open then
    if not lane.shell or not lane.shell.Parent then
     lane.shell=Registry.find(s.token,lane.slot,false)
    end
    if lane.cracked then
     crumbling=true;lane.clock+=dt
     local interval=1/((reduced and 1 or 3)+lane.tier*(reduced and .4 or 1.6))
     if lane.clock>=interval then lane.clock=0;crumble(s,lane,1) end
    end
   end
   for _,item in lane.pool do
    local age=s.clock-item.born;local u=age/item.life
    if u<1 then
     item.part.CFrame=CFrame.new(item.origin+item.velocity*age+Vector3.new(0,-11*age*age,0))
      *CFrame.Angles(item.rotation.X*age,item.rotation.Y*age,item.rotation.Z*age)
     item.part.Transparency=math.clamp((u-.65)/.35,0,1)
    else item.part.Transparency=1 end
   end
  end
  local target=crumbling and volume[math.min(s.tier,#volume)]*(s.charging and 1 or .65+.35*math.min(1,s.pulse)) or 0
  local blend=1-math.exp(-dt*12)
  s.RockCrumble.Volume+=(target-s.RockCrumble.Volume)*blend
  s.FallingGrit.Volume+=(target*.45-s.FallingGrit.Volume)*blend
  local kick=0
  for slot,burst in s.bursts do
   if reduced then burst:destroy();s.bursts[slot]=nil
   else
    kick=math.max(kick,burst:step(dt))
    if burst.destroyed then s.bursts[slot]=nil end
   end
  end
  local amplitude=strength[math.min(s.tier,#strength)]*((crumbling and (s.charging and .9 or .16) or 0)+s.pulse)
  if not reduced and (amplitude>.00001 or kick>0) then
   local camera=workspace.CurrentCamera;local t=s.clock
   local offset=CFrame.new(math.noise(t*22,0)*amplitude*3,math.noise(0,t*27)*amplitude*2,kick)
    *CFrame.Angles(math.noise(t*25,8)*amplitude,math.noise(4,t*23)*amplitude*.7,math.noise(t*20,3)*amplitude*.6)
   camera.CFrame=camera.CFrame*offset;s.camera=camera;s.offset=offset
  end

 end)
end
function FX.stage(kind,data)
 local s=active;if not s or s.token~=data.token then return end
 local lane=s.lanes[data.slot or 1];if not lane then return end
 if data.rarity or data.rarityTier then lane.tier=rarityTier(data,lane.tier) end
 s.tier=math.max(s.tier,lane.tier)
 if kind=="Strike" or kind=="Upgrade" then
  lane.cracked=true;s.pulse=math.max(s.pulse,kind=="Upgrade" and 1.25 or .85)
  crumble(s,lane,player:GetAttribute("ReducedMotion")==true and 1 or 3+lane.tier)
 elseif kind=="Anticipation" then
  lane.cracked=true;s.charging=true;s.pulse=math.max(s.pulse,.9)
 elseif kind=="Open" then
  lane.open=true
  if not s.opened then s.opened=true;s.pulse=.65 end
  screenBurst(s,lane,data)
 elseif kind=="Result" then lane.open=true
 elseif kind=="FadeOut" then
  lane.open=true
 end
end
return FX
