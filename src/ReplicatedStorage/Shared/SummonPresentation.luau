-- Client-owned, bounded effects. Rewards and interaction validation stay on the server.
local function newPresenter(slot,onCrack)
local M = {}
local RS=game:GetService("RunService")
local TS=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local Players=game:GetService("Players")
local CAS=game:GetService("ContextActionService")
local Catalog=require(game.ReplicatedStorage.Shared.RockCatalog)
local tiers={Common=1,Uncommon=2,Rare=3,Epic=4,Legendary=5,Mythical=6}
local UI=require(game.ReplicatedStorage.Shared:WaitForChild("SummonUIStyle"))
local Geode=require(game.ReplicatedStorage.Shared:WaitForChild("GeodeReveal"))
local CameraMotion=require(game.ReplicatedStorage.Shared:WaitForChild("SummonCamera"))
local SceneDisplay=require(game.ReplicatedStorage.Shared:WaitForChild("SummonSceneDisplay"))
local Curves=require(game.ReplicatedStorage.Shared:WaitForChild("SummonBezierVFX"))
local RevealVFX=require(game.ReplicatedStorage.Shared:WaitForChild("SummonRevealVFX"))
local active
local Config=require(game.ReplicatedStorage.Shared.SummonConfig)
local function tween(o,t,properties)
 -- Separate channels: a brightness pulse must not cancel a rarity color transition.
 for property,value in properties do
  TS:Create(o,TweenInfo.new(t,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{[property]=value}):Play()
 end
end
local function part(folder,pos,size,color)
 local p=Instance.new("Part");p.Name="SummonEnergy";p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
 p.Material=Enum.Material.Neon;p.Color=color;p.Size=size;p.Position=pos;p.Parent=folder;return p
end
local function sound(s,name,pitch,volume)
 local bank=game:GetService("SoundService"):FindFirstChild("SFX")
 local source=bank and bank:FindFirstChild(name)
 if not source then return end
 local a=source:Clone();a.PlaybackSpeed=pitch;a.Volume=volume;a.Looped=false;a.Parent=s.folder;a:Play();Debris:AddItem(a,5)
end
local function ring(s,radius,duration)
 if Players.LocalPlayer:GetAttribute("ReducedMotion")==true then return end
 s.curves.color=s.color
 s.curves:emit("ribbon",6+s.tier,math.min(radius*.35,4.8),duration*1.5)
end
local function burst(s,count)
 s.emitter:Emit(math.ceil(count*.15))
 if Players.LocalPlayer:GetAttribute("ReducedMotion")==true then return end
 s.curves.color=s.color
 s.curves:emit("burst",math.min(18,math.ceil(count/3)),2.8+s.tier*.2,.65+s.tier*.04)
end
function M.stop(immediate)
 local s=active;if not s then return end;active=nil
 if s.connection then s.connection:Disconnect() end
 if s.curves then s.curves:destroy() end
 if s.reveal then s.reveal:destroy() end
 if s.enchantedScreen then s.enchantedScreen:Destroy() end
 RS:UnbindFromRenderStep(("SummonImpact"..slot))
 RS:UnbindFromRenderStep(("SummonImpactReset"..slot))
 if s.camera and s.lastOffset then s.camera.CFrame=s.camera.CFrame*s.lastOffset:Inverse();s.lastOffset=nil end
 if immediate then
  s.gui:Destroy()
 else
  UI.dismissSeal(s)
  Debris:AddItem(s.gui,.22)
 end
 s.folder:Destroy()
end
function M.begin(data,remote)
 M.stop(true)
 local s={pos=data.position,color=Color3.fromRGB(140,220,255),token=data.token,slot=data.slot or 1,batchSize=data.batchSize or 1,tier=1,started=os.clock(),phase="Charge",remote=remote}
 s.required=data.required or Geode.settings(data.rarity).cracks
 s.total=data.total or 0;s.hits=data.hits or 0;s.rarity=data.rarity or "Common"
 s.color=Geode.settings(data.rarity).color;s.tier=data.rarityTier or tiers[data.rarity] or 1
 active=s
 s.folder=Instance.new("Folder");s.folder.Name="SummonPresentation";s.folder.Parent=workspace
 s.curves=Curves.new(s.folder,s.pos,s.color,s.slot*104729+s.token)
 s.curveClock=0;s.orbitClock=0;s.orbitRadius=2.6
 s.host=part(s.folder,s.pos,Vector3.one,s.color);s.host.Transparency=1
 local at=Instance.new("Attachment");at.Parent=s.host
 s.emitter=Instance.new("ParticleEmitter");s.emitter.Texture="rbxasset://textures/particles/sparkles_main.dds"
 s.emitter.Rate=3;s.emitter.Lifetime=NumberRange.new(.4,1);s.emitter.Speed=NumberRange.new(.15,.5)
 s.emitter.SpreadAngle=Vector2.new(360,360);s.emitter.LightEmission=1
 s.emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.22),NumberSequenceKeypoint.new(.3,.4),NumberSequenceKeypoint.new(1,0)})
 s.emitter.Transparency=NumberSequence.new(0,1);s.emitter.Color=ColorSequence.new(s.color);s.emitter.Parent=at
 s.light=Instance.new("PointLight");s.light.Color=s.color;s.light.Range=16;s.light.Brightness=0;s.light.Parent=s.host
 tween(s.light,.6,{Brightness=2})
 s.cracks={} -- Fractures are part of the replicated geode shell.
 s.shards={}
 for i=1,12 do
  local p=part(s.folder,s.pos,Vector3.new(.18,.45,.18),s.color);p.Transparency=i>4 and 1 or .15;s.shards[i]=p
  local a=Instance.new("Attachment");a.Position=Vector3.new(0,.16,0);a.Parent=p
  local b=Instance.new("Attachment");b.Position=Vector3.new(0,-.16,0);b.Parent=p
  local trail=Instance.new("Trail");trail.Attachment0=a;trail.Attachment1=b;trail.Lifetime=.22
  trail.LightEmission=1;trail.Color=ColorSequence.new(s.color);trail.Transparency=NumberSequence.new(.25,1)
  trail.Enabled=i<=4;trail.Parent=p
 end
 s.gui=Instance.new("ScreenGui");s.gui.Name="SummonCinematic";s.gui.ResetOnSpawn=false;s.gui.DisplayOrder=30;s.gui.Parent=Players.LocalPlayer.PlayerGui
 local button=Instance.new("TextButton");button.Name="BreakSeal";button.AnchorPoint=Vector2.new(.5,1);button.Position=UDim2.fromScale(.5,.88)
 button.Size=UDim2.new(.8,0,0,76);button.BackgroundColor3=Color3.fromRGB(14,23,39);button.BackgroundTransparency=.12
 button.TextColor3=Color3.new(1,1,1);button.TextSize=19;button.Font=Enum.Font.FredokaOne;button.Text="GATHERING ENERGY";button.AutoButtonColor=false;button.Parent=s.gui
 local constraint=Instance.new("UISizeConstraint");constraint.MaxSize=Vector2.new(420,76);constraint.Parent=button
 local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,16);corner.Parent=button
 local stroke=Instance.new("UIStroke");stroke.Color=s.color;stroke.Thickness=2;stroke.Parent=button;s.stroke=stroke
 local fill=Instance.new("Frame");fill.Name="Charge";fill.BorderSizePixel=0;fill.BackgroundColor3=s.color;fill.Position=UDim2.new(0,12,1,-9);fill.Size=UDim2.new(0,0,0,3);fill.Visible=false;fill.Parent=button;s.fill=fill
 s.button=button
 local caption=Instance.new("TextLabel");caption.BackgroundTransparency=1;caption.Position=UDim2.new(0,0,1,8);caption.Size=UDim2.new(1,0,0,24)
 caption.Font=Enum.Font.FredokaOne;caption.TextSize=12;caption.TextScaled=true;caption.TextColor3=Color3.fromRGB(203,217,235);caption.Text="Keep cracking. How far will it go?";caption.Parent=button
 s.caption=caption
 UI.seal(s)
 -- Only the first presenter owns the shared control; the others keep their effects.
 s.gui.Enabled=slot==1
 if s.batchSize>1 then
  s.caption.Text="One press cracks every geode"
  s.button.Eyebrow.Text=tostring(s.batchSize).." GEODES"
 end
 local function strike()
  if active~=s or s.phase=="Complete" then return end
  onCrack()
 end
 button.Selectable=false
 button.Activated:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 then strike() end
 end)
 sound(s,"UI_Menu_Open",.75,.45)
 s.connection=RS.RenderStepped:Connect(function(dt)
  local t=os.clock()-s.started
  local reduced=Players.LocalPlayer:GetAttribute("ReducedMotion")==true
  local intensity=s.phase=="Anticipation" and 1.6 or 1
  local radius=s.phase=="Anticipation" and .95 or ((s.phase=="Opening" or s.phase=="Complete") and 3.4 or 2.6)
  s.orbitRadius+=(radius-s.orbitRadius)*(1-math.exp(-dt*5))
  s.orbitClock+=dt*(.14+s.tier*.015)*intensity
  for i,p in ipairs(s.shards) do
   local phase=(reduced and 0 or s.orbitClock)+i/12
   local orbit=Curves.orbit(phase,s.orbitRadius)
   local tilted=CFrame.Angles(math.rad(18)*math.sin(i*2),0,math.rad(12)*math.cos(i)):VectorToWorldSpace(orbit)
   p.CFrame=CFrame.new(s.pos+tilted)*CFrame.Angles(t*.3,i,t*.2)
   p.Trail.Enabled=not reduced and s.phase~="Fading" and i<=math.max(4,s.tier*2)
  end
  s.curveClock+=dt
  if not reduced and s.phase~="Fading" and s.phase~="Complete" then
   local interval=s.phase=="Anticipation" and .12 or .4
   if s.curveClock>=interval then
    s.curveClock=0;s.curves.color=s.color
    s.curves:emit(s.phase=="Anticipation" and "inward" or "ribbon",s.phase=="Anticipation" and 3 or 1,3.3,.9)
   end
  end
  s.curves:step(dt)
  if s.reveal then s.reveal:step(dt) end
  if s.phase=="Charge" then s.fill.Size=UDim2.new(math.min(t/.7,1),-24,0,3) end
 end)
 -- Keep the seal interactive until Result, Closed, or character removal.
end
function M.cardRarity(rarity)
 local s=active
 if s then UI.sealRarity(s,rarity) end
end
function M.stage(kind,data)
 local s=active;if not s or data.token~=s.token then return end
 if kind=="FadeOut" then
  UI.dismissSeal(s)
  SceneDisplay.fadeOut(s.slot)
  if s.reveal then s.reveal:destroy() end
  s.phase="Fading";s.curves:fade()
  s.emitter.Enabled=false
  tween(s.light,Config.ExitSeconds,{Brightness=0})
  for _,shard in s.shards do tween(shard,Config.ExitSeconds,{Transparency=1});shard.Trail.Enabled=false end
 elseif kind=="Seal" then
  s.required=data.required or s.required;s.hits=data.hits or 0;s.total=data.total or s.total
  s.rarity=data.rarity or s.rarity;s.tier=data.rarityTier or tiers[s.rarity] or 1;s.color=Geode.settings(s.rarity).color
  s.phase="Seal";s.button.Text="CRACK THE GEODE"
  s.caption.Text=(s.batchSize>1 and "CLICK OR E - CRACK ALL" or "CLICK OR E")
  s.button.Eyebrow.Text=string.upper(s.rarity).." ENERGY";s.button.Eyebrow.TextColor3=s.color
  s.button.AutoButtonColor=false
  UI.tier(s)
  s.fill.Size=UDim2.new(0,0,0,3);s.fill.Visible=false
 elseif kind=="Checkpoint" then
  s.phase="Checkpoint";s.button.Text="WILL IT OPEN...?"
  s.caption.Text="The geode is stirring..."
  tween(s.light,.16,{Brightness=2+s.tier*.6})
  sound(s,"UI_Menu_Close",.6,.4)
 elseif kind=="Upgrade" then
  s.phase="Upgrade";s.rarity=data.rarity;s.tier=data.rarityTier or tiers[data.rarity] or 1
  s.required=data.required;s.total=data.total or s.total;s.hits=0
  s.color=Geode.settings(s.rarity).color
  s.emitter.Color=ColorSequence.new(s.color)
  tween(s.light,Config.TierTransitionSeconds,{Color=s.color,Brightness=2+s.tier*.7,Range=14+s.tier*2})
  tween(s.stroke,Config.TierTransitionSeconds,{Color=s.color})
  s.fill.BackgroundColor3=s.color
  for i,p in s.shards do
   tween(p,Config.TierTransitionSeconds,{Color=s.color,Transparency=i<=s.tier*2 and .1 or 1})
   p.Trail.Color=ColorSequence.new(s.color);p.Trail.Enabled=i<=s.tier*2
  end
  s.button.Text=s.tier>=5 and "THE POWER KEEPS RISING!" or "IT'S STILL GROWING!"
  s.button.Eyebrow.Text=string.upper(s.rarity).." ENERGY";s.button.Eyebrow.TextColor3=s.color
  s.caption.Text="Keep going..."
  UI.tier(s);UI.strike(s,0)
  burst(s,12+s.tier*9);ring(s,6+s.tier,.6)
  sound(s,"UI_Menu_Open",.8+s.tier*.07,.5)
  if s.tier>=5 then
   task.delay(.2,function() if active==s then ring(s,12+s.tier,.8);sound(s,"SFX_Reward_Claimed",1.1,.35) end end)
  end
 elseif kind=="Strike" then
  s.hits=data.hits;s.total=data.total or s.total+1
  UI.strike(s,s.hits)
  s.light.Brightness=3+s.tier
  tween(s.light,.2,{Brightness=1+s.total/Geode.TotalCracks*7})
  sound(s,"UI_Menu_Close",.7+(s.hits/s.required)*.4,.5)
  burst(s,12+s.tier*4);ring(s,5+s.tier,.35)
  sound(s,"UI_Click_01",.85+(s.hits/s.required)*.55,.5)
  s.button.Text="CRACK THE GEODE"
  s.caption.Text=(s.batchSize>1 and "CLICK OR E - CRACK ALL" or "CLICK OR E")
 elseif kind=="Anticipation" then
  s.phase="Anticipation";s.phaseStart=os.clock();s.tier=data.rarityTier or tiers[data.rarity] or 1;s.color=Geode.settings(data.rarity).color
  s.enchanted=data.variant=="Enchanted"
  if s.enchanted then s.color=Color3.fromRGB(137,255,224);s.tier=math.max(s.tier,5) end
  s.emitter.Color=ColorSequence.new(s.color);s.light.Color=s.color;s.stroke.Color=s.color;s.fill.BackgroundColor3=s.color
  s.emitter.Rate=2+s.tier
  for _,crack in s.cracks do
   crack.part.Color=s.color
   tween(crack.part,data.duration*.75,{Size=crack.part.Size*1.6,Transparency=0})
  end
  task.delay(data.duration*.78,function()
   if active~=s or s.phase~="Anticipation" then return end
   s.emitter.Rate=0
   s.caption.Text="..."
  end)
  for i,p in ipairs(s.shards) do p.Color=s.color;p.Transparency=i<=s.tier*2 and .1 or 1;p.Trail.Color=ColorSequence.new(s.color);p.Trail.Enabled=i<=s.tier*2 end
  tween(s.light,data.duration,{Brightness=2+s.tier*.7,Range=15+s.tier*2})
  s.button.Text=s.tier>=5 and "AN EXTRAORDINARY DISCOVERY" or "THE SEAL IS OPENING"
  s.button.Eyebrow.Text=s.tier>=5 and "✦  SOMETHING SPECIAL  ✦" or "ENERGY UNLEASHED";s.button.Eyebrow.TextColor3=s.color
  s.caption.Text="Get ready...";for _,p in s.pips do tween(p,.2,{BackgroundColor3=s.color}) end
  s.button.TextSize=s.tier>=5 and 15 or 19;s.button.TextWrapped=true
  sound(s,"UI_Menu_Open",.55+s.tier*.06,.5)
  if s.tier>=4 then ring(s,7,.7) end
 elseif kind=="Result" then
  SceneDisplay.showResult(data)
  if s.reveal then s.reveal:attach(data.model) end
  s.phase="Complete" -- Keep the card until the shared scene exit.
 elseif kind=="Open" then  -- The shell's final center is authoritative, including anticipation movement.
  s.tier=data.rarityTier or tiers[data.rarity] or s.tier
  s.enchanted=data.variant=="Enchanted"
  if s.enchanted then
   local _,accent=require(game.ReplicatedStorage.Shared.RockAppearance).palette(data.id or "pebble")
   s.color=accent;s.tier=math.max(s.tier,5)
  end
  s.pos=data.position or s.pos
  s.host.Position=s.pos
  s.curves.center=s.pos

  for _,crack in s.cracks do crack.part:Destroy() end
  s.cracks={}
  for i=1,8 do
   local angle=i*math.pi/4
   local chip=part(s.folder,s.pos,Vector3.new(.25,.18,.35),Color3.fromRGB(65,74,91):Lerp(Color3.new(1,1,1),.25))
   chip.Material=Enum.Material.Slate
   tween(chip,.65,{CFrame=CFrame.new(s.pos+Vector3.new(math.cos(angle)*3,1+math.sin(angle*2)*.6,math.sin(angle)*3))*CFrame.Angles(angle,angle*2,0),Transparency=1})
   Debris:AddItem(chip,.7)
  end
  s.phase="Opening";s.button.Text="REVEAL NOW";s.caption.Text="CLICK OR E"
  if s.reveal then s.reveal:destroy() end
  s.reveal=RevealVFX.new(s.folder,s.pos,s.color,s.tier,Players.LocalPlayer:GetAttribute("ReducedMotion")==true,s.token+s.slot*8191)
  s.reveal:attach(data.model)
  if s.enchanted then
   sound(s,"SFX_Reward_Claimed",.78,.7)
   task.delay(.3,function() if active==s then sound(s,"UI_Menu_Open",1.55,.35) end end)
   s.button.Eyebrow.Text="✦ ENCHANTED DISCOVERY ✦"
   s.button.Eyebrow.TextColor3=s.color
   if Players.LocalPlayer:GetAttribute("ReducedMotion")~=true then
    s.enchantedScreen=Instance.new("ScreenGui");s.enchantedScreen.Name="EnchantedRevealGlow"
    s.enchantedScreen.IgnoreGuiInset=true;s.enchantedScreen.DisplayOrder=28;s.enchantedScreen.ResetOnSpawn=false;s.enchantedScreen.Parent=Players.LocalPlayer.PlayerGui
    local glow=Instance.new("Frame");glow.Size=UDim2.fromScale(1,1);glow.BorderSizePixel=0;glow.BackgroundColor3=s.color;glow.BackgroundTransparency=.92;glow.Parent=s.enchantedScreen
    tween(glow,.9,{BackgroundTransparency=1})
   end
  end
  sound(s,"SFX_Reward_Claimed",1.2-s.tier*.07,.45+s.tier*.045)
  if s.tier>=5 then task.delay(.22,function() if active==s then sound(s,"UI_Menu_Open",1.3,.45) end end) end
  s.light.Brightness=5+s.tier;tween(s.light,1.2,{Brightness=1.5})
  s.emitter.Rate=2
  -- Item reveal arcs have their own bounded pool so earlier cracks cannot overwrite them.
  -- The batch coordinator closes all presentations together.
 end
 if s.batchSize>1 and slot==1 then
  if kind=="Seal" or kind=="Strike" then
   s.button.Text="CRACK ALL "..s.batchSize
   s.button.Eyebrow.Text=tostring(s.batchSize).." GEODES"
  elseif kind=="Checkpoint" then
   s.button.Text="THE GEODES ARE STIRRING..."
  elseif kind=="Anticipation" then
   s.button.Text="ALL GEODES ARE OPENING"
  elseif kind=="Open" then
   s.button.Text="REVEALING YOUR ROCKS"
   s.caption.Text=""
  end
 end
end
return M
end
local Presentation={}
local AnticipationFX=require(game.ReplicatedStorage.Shared.SummonAnticipationFX)
local presenters={}
local slotRarities={}
local rarityRank={Common=1,Uncommon=2,Rare=3,Epic=4,Legendary=5,Mythical=6}
local function updateCardRarity()
 local rarest,highest="Common",0
 for _,rarity in slotRarities do
  local rank=rarityRank[rarity] or 0
  if rank>highest then rarest,highest=rarity,rank end
 end
 if presenters[1] then presenters[1].cardRarity(rarest) end
end
local token
local inputGui
local acceptingInput=false
local keyboardConnection
local exitToken
local autoEnabled=false
local ExitConfig=require(game.ReplicatedStorage.Shared.SummonConfig)
local SceneRegistry=require(game.ReplicatedStorage.Shared.SummonSceneRegistry)
local CAS=game:GetService("ContextActionService")
local CameraMotion=require(game.ReplicatedStorage.Shared.SummonCamera)
local SceneDisplay=require(game.ReplicatedStorage.Shared.SummonSceneDisplay)
function Presentation.setAutoMode(mode)
 autoEnabled=mode==1 or mode==3
 if not autoEnabled and not token then
  SceneDisplay.stop()
  CameraMotion.stop(false)
 end
end
function Presentation.stop(immediate,keepCamera)
 local keepCinematic=keepCamera==true or (not immediate and autoEnabled)
 AnticipationFX.stop()
 CAS:UnbindAction("SummonBreakSeal")
 if keyboardConnection then keyboardConnection:Disconnect();keyboardConnection=nil end
 acceptingInput=false
 if inputGui then inputGui:Destroy();inputGui=nil end
 for _,presenter in presenters do presenter.stop(immediate) end
 presenters={};slotRarities={};token=nil;exitToken=nil
 if not keepCinematic then SceneDisplay.stop() end
 CameraMotion.stop(immediate,keepCinematic)
end
function Presentation.begin(data,remote)
 Presentation.stop(true,data.skipCameraIntro==true)
 token=data.token
 acceptingInput=true
 local geodes=data.geodes or {data}
 SceneDisplay.begin(token,data.skipCameraIntro==true)
 CameraMotion.begin(data.position,#geodes,data.skipCameraIntro==true)
 AnticipationFX.begin(data)
 local function crack()
  if not acceptingInput or not token or game:GetService("UserInputService"):GetFocusedTextBox() then return end
  remote:FireServer(token)
 end
 for i,entry in geodes do
  entry.slot=i;entry.batchSize=#geodes
  slotRarities[i]=entry.rarity or "Common"
  local presenter=newPresenter(i,crack)
  presenters[i]=presenter
  presenter.begin(entry,remote)
 end
 updateCardRarity()
 -- One background click target for the whole batch. The visible card sits above it,
 -- so its Activated event and screen clicks cannot send duplicate strikes.
 inputGui=Instance.new("ScreenGui")
 inputGui.Name="SummonScreenInput";inputGui.IgnoreGuiInset=true;inputGui.ResetOnSpawn=false
 inputGui.DisplayOrder=29;inputGui.Parent=game.Players.LocalPlayer.PlayerGui
 local surface=Instance.new("TextButton");surface.Name="ClickToCrack"
 surface.Size=UDim2.fromScale(1,1);surface.BackgroundTransparency=1;surface.Text=""
 surface.AutoButtonColor=false;surface.Parent=inputGui
 surface.Selectable=false
 surface.Activated:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 then crack() end
 end)
 -- ProximityPrompt core bindings consume E before ContextActionService.
 -- Listen to E directly even when processed; crack() still rejects chat typing.
 keyboardConnection=game:GetService("UserInputService").InputBegan:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.Keyboard and input.KeyCode==Enum.KeyCode.E then
   crack()
  end
 end)
end
function Presentation.stage(kind,data)
 if data.token~=token then return end
 AnticipationFX.stage(kind,data)
 if kind=="FadeOut" and exitToken~=token then
  exitToken=token
  local closingToken=token
  -- Models, card, labels, and local effects share the same client-side deadline.
  SceneRegistry.fadeOut(closingToken,ExitConfig.ExitSeconds)
  task.delay(ExitConfig.ExitSeconds,function()
   if token==closingToken then Presentation.stop() end
  end)
 end
 if kind=="Result" or kind=="FadeOut" then
  acceptingInput=false
  if keyboardConnection then keyboardConnection:Disconnect();keyboardConnection=nil end
  if inputGui then inputGui:Destroy();inputGui=nil end
 end
 if data.rarity then
  slotRarities[data.slot or 1]=data.rarity
  updateCardRarity()
 end
 local presenter=presenters[data.slot or 1]
 if presenter then presenter.stage(kind,data) end
end
return Presentation