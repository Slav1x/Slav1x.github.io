--!nonstrict
-- Presentation only: all progression, event odds and rewards stay on the server.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Lighting=game:GetService("Lighting")
local Tween=game:GetService("TweenService")
local Run=game:GetService("RunService")
local Debris=game:GetService("Debris")
local player=Players.LocalPlayer
local Store=require(player:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("ProfileStore"))
local Remotes=require(RS.Shared.Remotes)
local Mastery=require(RS.Shared.MasteryConfig)
local ProgressionConfig=require(RS.Shared.ProgressionConfig)
local Zones=require(RS.Shared.ZoneConfig)
local Rocks=require(RS.Shared.RockCatalog)
local Appearance=require(RS.Shared.RockAppearance)
local Sounds=require(RS.SharedUI.UISounds)
local Events=require(RS.Shared.EnvironmentEventConfig)
local gui=Instance.new("ScreenGui")
gui.Name="ProgressionFeedback";gui.ResetOnSpawn=false;gui.DisplayOrder=35;gui.Parent=player:WaitForChild("PlayerGui")
local function frame(name,size,position,anchor)
 local f=Instance.new("Frame");f.Name=name;f.Size=size;f.Position=position;f.AnchorPoint=anchor or Vector2.zero
 f.BackgroundColor3=Color3.fromRGB(15,30,45);f.BackgroundTransparency=.12;f.BorderSizePixel=0;f.Parent=gui
 local corner=Instance.new("UICorner",f);corner.CornerRadius=UDim.new(0,10)
 local stroke=Instance.new("UIStroke",f);stroke.Color=Color3.fromRGB(90,190,177);stroke.Transparency=.4
 return f
end
local function label(parent,name,text,pos,size,textSize,color)
 local t=Instance.new("TextLabel");t.Name=name;t.Text=text;t.Position=pos;t.Size=size;t.BackgroundTransparency=1
 t.TextColor3=color or Color3.fromRGB(232,246,247);t.Font=Enum.Font.GothamMedium;t.TextSize=textSize or 14;t.TextXAlignment=Enum.TextXAlignment.Left;t.TextWrapped=true;t.Parent=parent;return t
end
local event=frame("EnvironmentalEvent",UDim2.fromOffset(430,52),UDim2.new(.5,0,0,8),Vector2.new(.5,0));event.Visible=false
local eventName=label(event,"Name","",UDim2.fromOffset(12,5),UDim2.new(1,-24,0,20),17)
local eventEffect=label(event,"Effect","",UDim2.fromOffset(12,27),UDim2.new(1,-24,0,18),12)
local card=frame("Journey",UDim2.fromOffset(254,116),UDim2.new(1,-18,1,-88),Vector2.one)
local title=label(card,"Title","YOUR JOURNEY",UDim2.fromOffset(12,8),UDim2.new(1,-24,0,19),13,Color3.fromRGB(124,225,204))
local objective=label(card,"Objective","Complete Driftwood Lake",UDim2.fromOffset(12,28),UDim2.new(1,-24,0,32),13)
local mastery=label(card,"Mastery","MASTERY 0",UDim2.fromOffset(12,65),UDim2.new(1,-24,0,18),12)
local track=Instance.new("Frame",card);track.Name="MasteryTrack";track.Position=UDim2.fromOffset(12,88);track.Size=UDim2.new(1,-24,0,5);track.BorderSizePixel=0;track.BackgroundColor3=Color3.fromRGB(45,72,79)
local fill=Instance.new("Frame",track);fill.Name="Progress";fill.Size=UDim2.fromScale(0,1);fill.BorderSizePixel=0;fill.BackgroundColor3=Color3.fromRGB(128,236,213)
local shards=label(card,"Shards","TRAIT SHARDS  0",UDim2.fromOffset(12,98),UDim2.new(1,-24,0,14),11,Color3.fromRGB(202,176,255))
local celebration=frame("Milestone",UDim2.fromOffset(430,104),UDim2.new(.5,0,.2,0),Vector2.new(.5,0));celebration.Visible=false
local heading=label(celebration,"Heading","",UDim2.fromOffset(18,13),UDim2.new(1,-36,0,26),21)
local detail=label(celebration,"Detail","",UDim2.fromOffset(18,46),UDim2.new(1,-36,0,42),14)
local scale=Instance.new("UIScale",celebration)
local fxFolder=Instance.new("Folder",workspace);fxFolder.Name="ProgressionCosmetics"
local effect=Instance.new("ColorCorrectionEffect",Lighting);effect.Name="GlobalEventTint";effect.Enabled=false
local bloom=Instance.new("BloomEffect",Lighting);bloom.Name="GlobalEventBloom";bloom.Intensity=0;bloom.Size=22;bloom.Threshold=1.6
local ray=Instance.new("SunRaysEffect",Lighting);ray.Name="GlobalEventRays";ray.Intensity=0
local bannerQueue={};local showing=false
local function announce(name,body,color)
 table.insert(bannerQueue,{name,body,color})
 if showing then return end
 showing=true
 task.spawn(function()
  while #bannerQueue>0 do
   local item=table.remove(bannerQueue,1)
   heading.Text=item[1];detail.Text=item[2];heading.TextColor3=item[3] or Color3.fromRGB(128,236,213)
   scale.Scale=.86;celebration.Visible=true
   Tween:Create(scale,TweenInfo.new(.35,Enum.EasingStyle.Back),{Scale=1}):Play()
   Sounds.play("Success");task.wait(3.8);celebration.Visible=false;task.wait(.15)
  end
  showing=false
 end)
end
local function ring(position,color,size)
 local p=Instance.new("Part");p.Shape=Enum.PartType.Cylinder;p.Name="MilestoneShockwave";p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
 p.Material=Enum.Material.Neon;p.Color=color;p.Transparency=.3;p.Size=Vector3.new(.12,1,1);p.CFrame=CFrame.new(position)*CFrame.Angles(0,0,math.pi/2);p.Parent=fxFolder
 Tween:Create(p,TweenInfo.new(.7),{Size=Vector3.new(.08,size,size),Transparency=1}):Play();Debris:AddItem(p,.8)
end
local function burst(position,color)
 local p=Instance.new("Part");p.Anchored=true;p.Size=Vector3.one;p.Transparency=1;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.Position=position;p.Parent=fxFolder
 local e=Instance.new("ParticleEmitter",p);e.Texture="rbxasset://textures/particles/sparkles_main.dds";e.Rate=0;e.Color=ColorSequence.new(color);e.LightEmission=.8
 e.Lifetime=NumberRange.new(.6,1.2);e.Speed=NumberRange.new(10,22);e.SpreadAngle=Vector2.new(180,180);e.Drag=4;e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.3),NumberSequenceKeypoint.new(1,0)})
 e:Emit(30);Debris:AddItem(p,2)
end
local shrineHighlight
local function refresh()
 local state=Store.get();local progress=state.mastery or Mastery.progress(nil)
 local nextArea
 for _,zone in ipairs(Zones.List) do if not (state.completedAreas or {})[zone.id] then nextArea=zone;break end end
 local req=state.rebirthRequirement
 if state.rebirthReady then objective.Text="Potential reached · visit the Rebirth Shrine"
 elseif nextArea then objective.Text=nextArea.name.." · reach "..nextArea.finish.." studs"
 elseif req then objective.Text="Next rebirth: "..(state.rebirthReason or "Build your current potential")
 else objective.Text="Master your collection and improve your traits" end
 local rock=Rocks.get(state.rockEquipped)
 mastery.Text=(rock and rock.name or "Rock").." · MASTERY "..progress.level.."  "..(progress.needed==0 and "MAX" or (progress.into.."/"..progress.needed))
 fill.Size=UDim2.fromScale(progress.needed==0 and 1 or math.clamp(progress.into/math.max(1,progress.needed),0,1),1)
 shards.Text="TRAIT SHARDS  "..tostring(state.traitShards or 0).."   ·   FORGE COST 3"
 title.Text="YOUR JOURNEY  ·  REBIRTH "..tostring(state.rebirths or 0)
 card.Visible=state.loaded==true and player:GetAttribute("RockInFlight")~=true
 local shrine=workspace:FindFirstChild("RebirthShrine")
 if shrine then
  if not shrineHighlight then shrineHighlight=Instance.new("Highlight",shrine);shrineHighlight.Name="EligibleGlow";shrineHighlight.Adornee=shrine;shrineHighlight.FillTransparency=.92;shrineHighlight.OutlineColor=Color3.fromRGB(146,255,225) end
  shrineHighlight.Enabled=state.rebirthReady==true
  local prompt=shrine:FindFirstChildWhichIsA("ProximityPrompt",true)
  if prompt then prompt.ActionText=state.rebirthReady and "Rebirth available" or "View your potential" end
 end
end
Store.onChanged(refresh);player:GetAttributeChangedSignal("RockInFlight"):Connect(refresh)
Remotes.AreaCompleted.OnClientEvent:Connect(function(reward)
 announce("AREA COMPLETE · "..reward.name,"+"..reward.cash.." money   +"..reward.shards.." Trait Shards\nTitle unlocked: "..reward.title,reward.color)
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart");if root then burst(root.Position,reward.color);ring(root.Position-Vector3.new(0,2,0),reward.color,24) end
end)
Remotes.MasteryUp.OnClientEvent:Connect(function(rockId,progress)
 announce("MASTERY "..progress.level.." · "..Rocks.get(rockId).name,progress.title.." · permanent progress\n+"..string.format("%.1f",progress.level*.5).."% strength and money",Color3.fromRGB(127,236,208))
end)
Remotes.TraitShardFound.OnClientEvent:Connect(function(position,total)
 announce("TRAIT SHARD FOUND","A rare skip reward · "..total.." shards owned",Color3.fromRGB(202,165,255));burst(position,Color3.fromRGB(202,165,255))
end)
local function prestige(p)
 local char=p.Character;if not char then return end
 local root=char:FindFirstChild("HumanoidRootPart");if not root then return end
 local count=p:GetAttribute("RebirthCount") or 0
 local old=root:FindFirstChild("RebirthPrestige");if old then old:Destroy() end
 if count<1 then return end
 local a=Instance.new("Attachment",root);a.Name="RebirthPrestige"
 local badge=Instance.new("BillboardGui",a);badge.Name="VeteranTitle";badge.Adornee=root;badge.Size=UDim2.fromOffset(190,22);badge.StudsOffset=Vector3.new(0,3.5,0);badge.MaxDistance=70;badge.AlwaysOnTop=false
 local text=Instance.new("TextLabel",badge);text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1;text.Font=Enum.Font.GothamSemibold;text.TextSize=12;text.TextColor3=Color3.fromRGB(155,233,218);text.TextStrokeTransparency=.6;text.Text="✦ "..ProgressionConfig.rebirthTitle(count).." · "..count
 local color=Color3.fromHSV((.43+math.min(count,12)*.025)%1,.38,1)
 local e=Instance.new("ParticleEmitter",a);e.Texture="rbxasset://textures/particles/sparkles_main.dds";e.Rate=math.min(5,1+count);e.Lifetime=NumberRange.new(1,1.5)
 e.Speed=NumberRange.new(.6,1.3);e.Size=NumberSequence.new(.12);e.Color=ColorSequence.new(color);e.LightEmission=.7;e.SpreadAngle=Vector2.new(80,80)
end
local function watch(p)
 p:GetAttributeChangedSignal("RebirthCount"):Connect(function() prestige(p) end)
 p.CharacterAdded:Connect(function(char) char:WaitForChild("HumanoidRootPart",10);prestige(p) end);prestige(p)
end
Players.PlayerAdded:Connect(watch);for _,p in Players:GetPlayers() do watch(p) end
Remotes.Rebirthed.OnClientEvent:Connect(function(userId,count)
 local p=Players:GetPlayerByUserId(userId);local char=p and p.Character;local root=char and char:FindFirstChild("HumanoidRootPart")
 if not root then return end
 local camera=workspace.CurrentCamera;if (camera.CFrame.Position-root.Position).Magnitude>250 and p~=player then return end
 local color=Color3.fromRGB(142,232,214);burst(root.Position,color);ring(root.Position-Vector3.new(0,2.5,0),color,38)
 if p==player then
  announce("REBIRTH "..count,"Your collection is permanent. Your potential has grown.\nStrength ceiling: "..tostring(Store.get().strengthCap or "increased"),color)
  local templates=RS:FindFirstChild("RockModels");local id=Store.get().rockEquipped;local template=templates and templates:FindFirstChild(id)
  if template then
   local rock=template:Clone();for _,part in rock:GetDescendants() do if part:IsA("BasePart") then part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false end end
   Appearance.apply(rock,id,Store.get().rockEquippedVariant);rock.Parent=fxFolder
   local duration=count==1 and 2.4 or 1.35;local started=os.clock();local connection
   connection=Run.RenderStepped:Connect(function()
    local t=(os.clock()-started)/duration
    if t>=1 or not root.Parent then connection:Disconnect();rock:Destroy();return end
    rock:PivotTo(CFrame.new(root.Position+Vector3.new(0,3+math.sin(t*math.pi)*3,0))*CFrame.Angles(0,t*math.pi*2,0))
   end)
  end
 end
end)
-- One lighting owner blends geography and event overrides; no abrupt night switch.
local Biomes=require(RS.Shared.BiomePresentation)
local sky=Lighting:FindFirstChildWhichIsA('Sky')
local atmosphere=Lighting:FindFirstChildWhichIsA('Atmosphere')
local originalLighting={ClockTime=Lighting.ClockTime,Brightness=Lighting.Brightness,Ambient=Lighting.Ambient,OutdoorAmbient=Lighting.OutdoorAmbient,FogColor=Lighting.FogColor}
local staticEffects={}
-- This controller owns runtime grading and glow; suspend the editor's preview stack.
for _,item in ipairs(Lighting:GetChildren()) do
 if item~=effect and item~=bloom and item~=ray and (item:IsA('ColorCorrectionEffect') or item:IsA('BloomEffect') or item:IsA('SunRaysEffect')) then
  staticEffects[item]=item.Enabled;item.Enabled=false
 end
end
local originalStars=sky and sky.StarCount
local originalAtmosphere=atmosphere and {Color=atmosphere.Color,Decay=atmosphere.Decay,Density=atmosphere.Density,Haze=atmosphere.Haze} or nil
local previousEvent=''
local eventEmitter
local alive=true
local function updateEvent()
 local config=Biomes.event()
 local key=config and config.id or ''
 local remaining=math.floor(math.max(0,(workspace:GetAttribute('GlobalEventEndsAt') or 0)-workspace:GetServerTimeNow()))
 event.Visible=config~=nil
 if config then
  eventName.Text=config.name..string.format('  %d:%02d',remaining//60,remaining%60)
  eventEffect.Text=config.description
 end
 if key~=previousEvent then
  previousEvent=key
  if eventEmitter then eventEmitter:Destroy();eventEmitter=nil end
  if config then
   local p=Instance.new('Part',fxFolder);p.Name='EventWeather';p.Anchored=true;p.Transparency=1;p.Size=Vector3.new(70,1,70);p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
   local emitter=Instance.new('ParticleEmitter',p);emitter.Texture='rbxasset://textures/particles/sparkles_main.dds';emitter.Rate=12;emitter.Lifetime=NumberRange.new(2,3);emitter.Speed=NumberRange.new(3,6);emitter.Acceleration=Vector3.new(0,-3,0);emitter.EmissionDirection=Enum.NormalId.Bottom;emitter.Size=NumberSequence.new(.14);emitter.LightEmission=.6;emitter.Color=ColorSequence.new(config.color);eventEmitter=p
   announce(config.name,config.description,config.color)
  end
 end
 return config
end
-- Stream scenery around a detached flight camera without moving the character's focus.
local streamBusy=false
local streamTask
local lastStreamTime=-math.huge
local lastStreamPosition
local previousCameraPosition
local function updateCameraStreaming(camera,step)
 local position=camera.CFrame.Position
 local delta=previousCameraPosition and position-previousCameraPosition or Vector3.zero
 previousCameraPosition=position
 if not workspace.StreamingEnabled then return end
 local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
 local inFlight=player:GetAttribute('RockInFlight')==true
 if not inFlight and (not root or (position-root.Position).Magnitude<=192) then
  lastStreamPosition=nil
  return
 end
 local now=os.clock()
 if streamBusy or now-lastStreamTime<1 then return end
 -- Prefetch regions are temporary; refresh a detached view even while it pauses.
 if lastStreamPosition and (position-lastStreamPosition).Magnitude<=128 and now-lastStreamTime<3 then return end
 local direction=Vector3.new(camera.CFrame.LookVector.X,0,camera.CFrame.LookVector.Z)
 local motion=Vector3.new(delta.X,0,delta.Z)
 if inFlight and motion.Magnitude>.1 then direction=motion.Unit
 elseif direction.Magnitude>.01 then direction=direction.Unit
 else direction=Vector3.xAxis end
 local speed=math.min(800,motion.Magnitude/math.max(step,.01))
 local ahead=position+direction*math.clamp(speed*.9,280,640)
 streamBusy=true;lastStreamTime=now;lastStreamPosition=position
 streamTask=task.spawn(function()
  -- Sequential half-second deadlines bound both work and concurrent requests.
  pcall(function() player:RequestStreamAroundAsync(position,.5) end)
  local current=workspace.CurrentCamera
  if alive and current and (current.CFrame.Position-position).Magnitude<1600 then
   pcall(function() player:RequestStreamAroundAsync(ahead,.5) end)
  end
  streamBusy=false
 end)
end


local elapsed=0
local environmentConnection=Run.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.05 then return end
 local step=elapsed;elapsed=0
 local camera=workspace.CurrentCamera;if not camera then return end
 updateCameraStreaming(camera,step)
 local profile=Biomes.at(camera.CFrame.Position)
 local config=Biomes.event()
 local alpha=1-math.exp(-1.65*step)
 local clockTarget=config and (config.id=='golden_tide' and 16.45 or 17.15) or profile.clock
 local clockDelta=(clockTarget-Lighting.ClockTime+12)%24-12
 Lighting.ClockTime=(Lighting.ClockTime+clockDelta*alpha)%24
 Lighting.Brightness+=(profile.brightness-Lighting.Brightness)*alpha
 -- ThrowFx owns ExposureCompensation for sonic flashes. Regional lift stays on our own effect.
 effect.Brightness+=((profile.exposure-.08)*.12-effect.Brightness)*alpha
 Lighting.Ambient=Lighting.Ambient:Lerp(profile.ambient,alpha)
 Lighting.OutdoorAmbient=Lighting.OutdoorAmbient:Lerp(profile.outdoor,alpha)
 local fog=config and profile.fog:Lerp(config.color,.18) or profile.fog
 Lighting.FogColor=Lighting.FogColor:Lerp(fog,alpha)
 local tint=config and profile.tint:Lerp(config.tint or config.color,.58) or profile.tint
 effect.Enabled=true;effect.TintColor=effect.TintColor:Lerp(tint,alpha)
 effect.Saturation+=(profile.saturation+(config and .035 or 0)-effect.Saturation)*alpha
 effect.Contrast+=(profile.contrast-effect.Contrast)*alpha
 bloom.Intensity+=((config and .18 or profile.id=='cosmic' and .065 or .04)-bloom.Intensity)*alpha
 ray.Intensity+=(profile.sun*.012-ray.Intensity)*alpha
 if atmosphere then
  atmosphere.Color=atmosphere.Color:Lerp(fog,alpha)
  atmosphere.Decay=atmosphere.Decay:Lerp(profile.decay,alpha)
  atmosphere.Density+=(profile.density-atmosphere.Density)*alpha
  atmosphere.Haze+=(profile.haze-atmosphere.Haze)*alpha
 end
 if sky then sky.StarCount=math.round(sky.StarCount+((config and math.max(2600,profile.stars) or profile.stars)-sky.StarCount)*alpha) end
 if eventEmitter then
  eventEmitter.Position=camera.CFrame.Position+Vector3.new(0,18,0)
  local emitter=eventEmitter:FindFirstChildOfClass('ParticleEmitter')
  if emitter then emitter.Enabled=player:GetAttribute('ReducedMotion')~=true end
 end
end)
local eventConnection=workspace:GetAttributeChangedSignal('GlobalEventId'):Connect(updateEvent)
task.spawn(function() while alive and gui.Parent do updateEvent();refresh();task.wait(.35) end end)
script.Destroying:Connect(function()
 alive=false;environmentConnection:Disconnect();eventConnection:Disconnect()
 if streamTask then pcall(task.cancel,streamTask) end
 for key,value in pairs(originalLighting) do Lighting[key]=value end
 if sky and sky.Parent then sky.StarCount=originalStars end
 if atmosphere and atmosphere.Parent and originalAtmosphere then for key,value in pairs(originalAtmosphere) do atmosphere[key]=value end end
 for item,enabled in pairs(staticEffects) do if item.Parent then item.Enabled=enabled end end
 effect:Destroy();bloom:Destroy();ray:Destroy();fxFolder:Destroy();gui:Destroy()
end)

local function fit()
 local width=workspace.CurrentCamera.ViewportSize.X
 for _,f in {card,event,celebration} do
  local s=f:FindFirstChild("ResponsiveScale") or Instance.new("UIScale",f);s.Name="ResponsiveScale";s.Scale=math.clamp(width/1000,.62,1)
 end
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit);fit()


