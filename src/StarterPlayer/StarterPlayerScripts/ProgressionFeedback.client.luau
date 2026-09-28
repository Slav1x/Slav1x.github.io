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
local Traits=require(RS.Shared.TraitCatalog)
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
local event=frame("EnvironmentalEvent",UDim2.fromOffset(260,62),UDim2.new(1,-14,0,64),Vector2.new(1,0));event.Visible=false
local eventName=label(event,"Name","",UDim2.fromOffset(12,5),UDim2.new(1,-24,0,20),14)
local eventEffect=label(event,"Effect","",UDim2.fromOffset(12,27),UDim2.new(1,-24,0,30),11)
eventEffect.TextScaled=true
local eventTextLimit=Instance.new("UITextSizeConstraint",eventEffect);eventTextLimit.MinTextSize=8;eventTextLimit.MaxTextSize=11
-- Journey card uses the same bright blue, stud texture and outlined lettering as the main menus.
local cardShadow=Instance.new("Frame")
cardShadow.Name="JourneyShadow";cardShadow.AnchorPoint=Vector2.one;cardShadow.Position=UDim2.new(1,-14,1,-84)
cardShadow.Size=UDim2.fromOffset(318,148);cardShadow.BackgroundColor3=Color3.fromRGB(2,11,25)
cardShadow.BackgroundTransparency=.3;cardShadow.BorderSizePixel=0;cardShadow.Parent=gui
local shadowCorner=Instance.new("UICorner",cardShadow);shadowCorner.CornerRadius=UDim.new(0,14)
local card=frame("Journey",UDim2.fromOffset(318,148),UDim2.new(1,-18,1,-88),Vector2.one)
card.BackgroundColor3=Color3.fromRGB(8,24,47);card.BackgroundTransparency=0;card.ClipsDescendants=true
card:FindFirstChildOfClass("UICorner").CornerRadius=UDim.new(0,13)
local cardStroke=card:FindFirstChildOfClass("UIStroke");cardStroke.Color=Color3.fromRGB(59,173,239);cardStroke.Thickness=2.5;cardStroke.Transparency=0
local bodyGradient=Instance.new("UIGradient",card);bodyGradient.Rotation=90
bodyGradient.Color=ColorSequence.new(Color3.fromRGB(18,48,79),Color3.fromRGB(5,19,39))
local bodyStuds=Instance.new("ImageLabel",card);bodyStuds.Name="BodyStuds";bodyStuds.BackgroundTransparency=1
bodyStuds.Position=UDim2.fromOffset(0,42);bodyStuds.Size=UDim2.new(1,0,1,-42)
bodyStuds.Image="rbxassetid://6927295847";bodyStuds.ImageColor3=Color3.fromRGB(102,164,225)
bodyStuds.ImageTransparency=.9;bodyStuds.ScaleType=Enum.ScaleType.Tile;bodyStuds.TileSize=UDim2.fromOffset(43,43)
local header=Instance.new("Frame",card);header.Name="BlueStudHeader";header.Size=UDim2.new(1,0,0,43)
header.BackgroundColor3=Color3.fromRGB(15,113,231);header.BorderSizePixel=0;header.ClipsDescendants=true
local headerCorner=Instance.new("UICorner",header);headerCorner.CornerRadius=UDim.new(0,11)
local headerGradient=Instance.new("UIGradient",header);headerGradient.Rotation=90
headerGradient.Color=ColorSequence.new(Color3.fromRGB(19,139,255),Color3.fromRGB(5,65,179))
local headerFoot=Instance.new("Frame",header);headerFoot.Position=UDim2.new(0,0,1,-12);headerFoot.Size=UDim2.new(1,0,0,12)
headerFoot.BackgroundColor3=Color3.fromRGB(5,65,179);headerFoot.BorderSizePixel=0
local headerStuds=Instance.new("ImageLabel",header);headerStuds.Name="Studs";headerStuds.BackgroundTransparency=1
headerStuds.Size=UDim2.fromScale(1,1);headerStuds.Image="rbxassetid://6927295847"
headerStuds.ImageTransparency=.76;headerStuds.ScaleType=Enum.ScaleType.Tile;headerStuds.TileSize=UDim2.fromOffset(44,44)
local glare=Instance.new("ImageLabel",header);glare.Name="DiagonalGlare";glare.BackgroundTransparency=1
glare.Position=UDim2.fromScale(.31,-.7);glare.Size=UDim2.fromScale(.32,2.4)
glare.Image="rbxassetid://71904840558679";glare.ImageTransparency=.84
local icon=Instance.new("ImageLabel",header);icon.Name="RockIcon";icon.BackgroundTransparency=1
icon.Position=UDim2.fromOffset(9,5);icon.Size=UDim2.fromOffset(34,34)
icon.Image="rbxassetid://84708459117473";icon.ImageRectOffset=Vector2.new(80,48)
icon.ImageRectSize=Vector2.new(416,280);icon.ScaleType=Enum.ScaleType.Fit
local title=label(header,"Title","REBIRTH",UDim2.fromOffset(47,5),UDim2.new(1,-131,0,33),23,Color3.new(1,1,1))
title.Font=Enum.Font.FredokaOne;title.TextScaled=true;title.TextStrokeColor3=Color3.fromRGB(12,26,43);title.TextStrokeTransparency=0
local titleLimit=Instance.new("UITextSizeConstraint",title);titleLimit.MinTextSize=17;titleLimit.MaxTextSize=23
local countPlate=Instance.new("Frame",header);countPlate.Name="RebirthBadge"
countPlate.AnchorPoint=Vector2.new(1,0);countPlate.Position=UDim2.new(1,-11,0,7);countPlate.Size=UDim2.fromOffset(76,29)
countPlate.BackgroundColor3=Color3.fromRGB(155,62,231);countPlate.BorderSizePixel=0
local countCorner=Instance.new("UICorner",countPlate);countCorner.CornerRadius=UDim.new(0,8)
local countStroke=Instance.new("UIStroke",countPlate);countStroke.Color=Color3.fromRGB(14,24,46);countStroke.Thickness=2
local countText=label(countPlate,"Count","1",UDim2.fromScale(0,0),UDim2.fromScale(1,1),16,Color3.new(1,1,1))
countText.Font=Enum.Font.FredokaOne;countText.TextXAlignment=Enum.TextXAlignment.Center
countText.TextStrokeColor3=Color3.fromRGB(15,22,43);countText.TextStrokeTransparency=0
local objective=label(card,"Objective","Complete Driftwood Lake",UDim2.fromOffset(13,49),UDim2.new(1,-26,0,29),12,Color3.fromRGB(248,251,255))
objective.Font=Enum.Font.GothamBold;objective.TextStrokeColor3=Color3.fromRGB(6,17,34);objective.TextStrokeTransparency=.55
local mastery=label(card,"Mastery","MASTERY 0",UDim2.fromOffset(13,81),UDim2.new(1,-26,0,18),12,Color3.fromRGB(194,226,255))
mastery.Font=Enum.Font.GothamBold;mastery.TextScaled=true;mastery.TextStrokeColor3=Color3.fromRGB(6,17,34);mastery.TextStrokeTransparency=.55
local masteryLimit=Instance.new("UITextSizeConstraint",mastery);masteryLimit.MinTextSize=10;masteryLimit.MaxTextSize=12
local track=Instance.new("Frame",card);track.Name="MasteryTrack";track.Position=UDim2.fromOffset(13,104)
track.Size=UDim2.new(1,-26,0,10);track.BorderSizePixel=0;track.BackgroundColor3=Color3.fromRGB(31,61,98)
local trackCorner=Instance.new("UICorner",track);trackCorner.CornerRadius=UDim.new(0,5)
local trackStroke=Instance.new("UIStroke",track);trackStroke.Color=Color3.fromRGB(86,179,240);trackStroke.Thickness=1;trackStroke.Transparency=.35
local fill=Instance.new("Frame",track);fill.Name="Progress";fill.Size=UDim2.fromScale(0,1);fill.BorderSizePixel=0
fill.BackgroundColor3=Color3.fromRGB(59,228,116)
local fillCorner=Instance.new("UICorner",fill);fillCorner.CornerRadius=UDim.new(0,5)
local fillGradient=Instance.new("UIGradient",fill);fillGradient.Rotation=90
fillGradient.Color=ColorSequence.new(Color3.fromRGB(117,248,105),Color3.fromRGB(16,184,105))
local shardPlate=Instance.new("Frame",card);shardPlate.Name="ShardBadge";shardPlate.Position=UDim2.fromOffset(13,123)
shardPlate.Size=UDim2.fromOffset(145,18);shardPlate.BackgroundColor3=Color3.fromRGB(65,40,113);shardPlate.BorderSizePixel=0
local shardCorner=Instance.new("UICorner",shardPlate);shardCorner.CornerRadius=UDim.new(0,6)
local shardStroke=Instance.new("UIStroke",shardPlate);shardStroke.Color=Color3.fromRGB(184,120,255);shardStroke.Thickness=1
local shards=label(shardPlate,"Shards","0 SHARDS",UDim2.fromScale(0,0),UDim2.fromScale(1,1),11,Color3.fromRGB(244,225,255))
shards.Font=Enum.Font.FredokaOne;shards.TextXAlignment=Enum.TextXAlignment.Center
shards.TextStrokeColor3=Color3.fromRGB(17,18,40);shards.TextStrokeTransparency=.2
local forgePlate=Instance.new("Frame",card);forgePlate.Name="ForgeBadge";forgePlate.AnchorPoint=Vector2.new(1,0)
forgePlate.Position=UDim2.new(1,-13,0,123);forgePlate.Size=UDim2.fromOffset(131,18)
forgePlate.BackgroundColor3=Color3.fromRGB(91,62,24);forgePlate.BorderSizePixel=0
local forgeCorner=Instance.new("UICorner",forgePlate);forgeCorner.CornerRadius=UDim.new(0,6)
local forgeStroke=Instance.new("UIStroke",forgePlate);forgeStroke.Color=Color3.fromRGB(255,206,85);forgeStroke.Thickness=1
local forgeCost=label(forgePlate,"ForgeCost","FORGE COST 3",UDim2.fromScale(0,0),UDim2.fromScale(1,1),11,Color3.fromRGB(255,238,191))
forgeCost.Font=Enum.Font.FredokaOne;forgeCost.TextXAlignment=Enum.TextXAlignment.Center
forgeCost.TextStrokeColor3=Color3.fromRGB(30,20,11);forgeCost.TextStrokeTransparency=.2
local celebration=frame("Milestone",UDim2.fromOffset(430,104),UDim2.new(1,-18,1,-88),Vector2.one);celebration.Visible=false
local heading=label(celebration,"Heading","",UDim2.fromOffset(18,13),UDim2.new(1,-36,0,26),21)
local detail=label(celebration,"Detail","",UDim2.fromOffset(18,46),UDim2.new(1,-36,0,42),14)
local scale=Instance.new("UIScale",celebration)
local fxFolder=Instance.new("Folder",workspace);fxFolder.Name="ProgressionCosmetics"
local effect=Instance.new("ColorCorrectionEffect",Lighting);effect.Name="GlobalEventTint";effect.Enabled=false
local bloom=Instance.new("BloomEffect",Lighting);bloom.Name="GlobalEventBloom";bloom.Intensity=0;bloom.Size=22;bloom.Threshold=1.6
local ray=Instance.new("SunRaysEffect",Lighting);ray.Name="GlobalEventRays";ray.Intensity=0
local bannerQueue={};local showing=false
local pendingRewards=0
gui:SetAttribute("RewardNotificationsPending",0)
local function reserveRewardSlot()
 pendingRewards+=1
 gui:SetAttribute("RewardNotificationsPending",pendingRewards)
 -- Reserve before any yield and hide an already-shown discovery synchronously.
 -- Attribute-changed callbacks can be deferred; polling alone leaves a frame race.
 local notify=player.PlayerGui:FindFirstChild("Notify")
 local stack=notify and notify:FindFirstChild("Stack")
 if stack then
  for _,notice in stack:GetChildren() do
   if notice:IsA("GuiObject") and notice:GetAttribute("TransitionDiscovery")==true then notice.Visible=false end
  end
 end
end
local function notificationsBlocked()
 if not gui.Enabled or player:GetAttribute("NoobDialogueOpen")==true or player:GetAttribute("RockInFlight")==true then return true end
 local throwHud=player.PlayerGui:FindFirstChild("ThrowHud")
 local result=throwHud and throwHud:FindFirstChild("ResultHolder")
 return result and result:IsA("GuiObject") and result.Visible or false
end
local function announce(name,body,color)
 table.insert(bannerQueue,{name,body,color})
 reserveRewardSlot()
 if showing then return end
 showing=true
 task.spawn(function()
  while #bannerQueue>0 do
   -- Rewards remain queued; the flight has only the small area-arrival card.
   while gui.Parent and notificationsBlocked() do task.wait(.1) end
   if not gui.Parent then break end
   local item=table.remove(bannerQueue,1)
   heading.Text=item[1];detail.Text=item[2];heading.TextColor3=item[3] or Color3.fromRGB(128,236,213)
   scale.Scale=1;celebration.Visible=true;event.Visible=false;card.Visible=false;cardShadow.Visible=false
   Sounds.play("Success")
   local remaining=3.8
   while gui.Parent and remaining>0 do
    local dt=task.wait(.1)
    local blocked=notificationsBlocked()
    celebration.Visible=not blocked
    if not blocked then event.Visible=false;remaining-=dt end
   end
   celebration.Visible=false
   pendingRewards-=1;gui:SetAttribute("RewardNotificationsPending",pendingRewards)
   task.wait(.15)
  end
  showing=false
 end)
end
player:GetAttributeChangedSignal("RockInFlight"):Connect(function()
 if player:GetAttribute("RockInFlight")==true then celebration.Visible=false end
end)
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
local function menuOpen()
 local hud=player.PlayerGui:FindFirstChild("MainHUD")
 if not hud then return false end
 for _,name in {"shopui","inventoryui","upgradesui","settingsui","IndexPanel"} do
  local panel=hud:FindFirstChild(name)
  if panel and panel:IsA("GuiObject") and panel.Visible then return true end
 end
 return false
end
local function refresh()
 local state=Store.get();local progress=state.mastery or Mastery.progress(nil)
 local nextArea
 for _,zone in ipairs(Zones.List) do if not (state.completedAreas or {})[zone.id] then nextArea=zone;break end end
 local req=state.rebirthRequirement
 if state.rebirthReady then objective.Text="Potential reached · the Magical Rock is calling"
 elseif nextArea then objective.Text=nextArea.name.." · reach "..nextArea.finish.." studs"
 elseif req then objective.Text="Next rebirth: "..(state.rebirthReason or "Build your current potential")
 else objective.Text="Master your collection and improve your traits" end
 local rock=Rocks.get(state.rockEquipped)
 mastery.Text=(rock and rock.name or "Rock").." · MASTERY "..progress.level.."  "..(progress.needed==0 and "MAX" or (progress.into.."/"..progress.needed))
 fill.Size=UDim2.fromScale(progress.needed==0 and 1 or math.clamp(progress.into/math.max(1,progress.needed),0,1),1)
 shards.Text=tostring(state.traitShards or 0).." TRAIT SHARDS"
 forgeCost.Text="FORGE COST "..tostring(Traits.RollCost)
 countText.Text=if state.rebirthReady then "READY" else tostring(state.rebirths or 0)
 countPlate.BackgroundColor3=if state.rebirthReady then Color3.fromRGB(20,185,93) else Color3.fromRGB(155,62,231)
 local showCard=state.loaded==true and player:GetAttribute("RockInFlight")~=true and not menuOpen() and not celebration.Visible
 card.Visible=showCard;cardShadow.Visible=showCard
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
 if userId==player.UserId and player:GetAttribute("RebirthCutscene")==true then return end
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
local skyFaces={"SkyboxBk","SkyboxDn","SkyboxFt","SkyboxLf","SkyboxRt","SkyboxUp"}
local originalSky={}
if sky then for _,key in skyFaces do originalSky[key]=sky[key] end originalSky.CelestialBodiesShown=sky.CelestialBodiesShown end
local caveSky=false
local clouds=workspace.Terrain:FindFirstChildOfClass("Clouds")
local createdClouds=clouds==nil
if not clouds then clouds=Instance.new("Clouds");clouds.Parent=workspace.Terrain end
local originalClouds={Cover=clouds.Cover,Density=clouds.Density,Color=clouds.Color}
local cloudMoods={driftwood={.38,.3,Color3.fromRGB(247,244,226)},blossom={.45,.24,Color3.fromRGB(249,226,238)},candy={.3,.3,Color3.fromRGB(253,224,238)},sunscorch={.08,.14,Color3.fromRGB(240,221,185)},frozen={.66,.4,Color3.fromRGB(222,237,249)},crystal={0,0,Color3.fromRGB(103,97,146)},toxic={.62,.48,Color3.fromRGB(179,193,127)},inferno={.7,.55,Color3.fromRGB(143,107,104)},cosmic={.08,.12,Color3.fromRGB(127,108,179)}}
local originalStars=sky and sky.StarCount
local originalAtmosphere=atmosphere and {Color=atmosphere.Color,Decay=atmosphere.Decay,Density=atmosphere.Density,Haze=atmosphere.Haze} or nil
local previousEvent=''
local eventEmitter
local alive=true
local function updateEvent()
 local config=Biomes.event()
 local key=config and config.id or ''
 local remaining=math.floor(math.max(0,(workspace:GetAttribute('GlobalEventEndsAt') or 0)-workspace:GetServerTimeNow()))
 local arrival=gui:FindFirstChild("AreaArrival")
 event.Visible=config~=nil and not celebration.Visible and not (arrival and arrival.Visible)
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
 -- PredictiveWorldStreaming owns bounded camera prefetch.
 local profile=Biomes.at(camera.CFrame.Position)
 local config=Biomes.event()
 local alpha=1-math.exp(-1.65*step)
 local cave=Zones.ById.crystal
 local distance=Zones.distanceAt(camera.CFrame.Position)
 -- Switch the sky only after the camera is under the entrance canopy.
 -- A dark cave background remains enclosed when low graphics culls distant meshes.
 local inside=cave and distance>cave.start+360 and distance<cave.finish-360 and math.abs(camera.CFrame.Position.Z+40.5)<850 and camera.CFrame.Position.Y<900
 if sky and inside~=caveSky then
  caveSky=inside
  for _,key in skyFaces do sky[key]=inside and "rbxasset://textures/blackBkg_square.png" or originalSky[key] end
  sky.CelestialBodiesShown=not inside and originalSky.CelestialBodiesShown
  Lighting:SetAttribute("CaveSkyActive",inside)
 end
 local cloud=cloudMoods[profile.id] or cloudMoods.driftwood
 clouds.Cover+=(cloud[1]-clouds.Cover)*alpha
 clouds.Density+=(cloud[2]-clouds.Density)*alpha
 clouds.Color=clouds.Color:Lerp(cloud[3],alpha)
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
 if sky then sky.StarCount=math.round(sky.StarCount+((caveSky and 0 or config and math.max(2600,profile.stars) or profile.stars)-sky.StarCount)*alpha) end
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
 if sky and sky.Parent then sky.StarCount=originalStars;for key,value in originalSky do sky[key]=value end end
 Lighting:SetAttribute("CaveSkyActive",nil)
 if createdClouds then clouds:Destroy() else for key,value in originalClouds do clouds[key]=value end end
 if atmosphere and atmosphere.Parent and originalAtmosphere then for key,value in pairs(originalAtmosphere) do atmosphere[key]=value end end
 for item,enabled in pairs(staticEffects) do if item.Parent then item.Enabled=enabled end end
 effect:Destroy();bloom:Destroy();ray:Destroy();fxFolder:Destroy();gui:Destroy()
end)

local function fit()
 local v=workspace.CurrentCamera.ViewportSize
 local width=v.X
 local compact=v.Y<500 or v.X<600
 card.AnchorPoint=compact and Vector2.new(1,0) or Vector2.one
 cardShadow.AnchorPoint=card.AnchorPoint
 card.Position=compact and UDim2.new(1,-104,0,8) or UDim2.new(1,-18,1,-88)
 cardShadow.Position=card.Position+UDim2.fromOffset(3,3)
 card.Size=compact and UDim2.fromOffset(180,82) or UDim2.fromOffset(318,148)
 cardShadow.Size=card.Size
 if compact then card.Position=UDim2.new(1,-104,0,v.X<600 and 245 or 8);cardShadow.Position=card.Position+UDim2.fromOffset(3,3) end
 header.Size=UDim2.new(1,0,0,compact and 28 or 43)
 icon.Size=UDim2.fromOffset(compact and 24 or 34,compact and 24 or 34);icon.Position=UDim2.fromOffset(5,2)
 title.Position=UDim2.fromOffset(compact and 31 or 47,3)
 title.Size=UDim2.new(1,compact and -72 or -131,0,compact and 23 or 33)
 titleLimit.MinTextSize=compact and 12 or 17
 countPlate.Size=UDim2.fromOffset(compact and 34 or 76,compact and 21 or 29)
 countPlate.Position=UDim2.new(1,compact and -5 or -11,0,compact and 3 or 7)
 countText.TextSize=compact and 12 or 16
 objective.Position=UDim2.fromOffset(compact and 8 or 13,compact and 32 or 49)
 objective.Size=UDim2.new(1,compact and -16 or -26,0,compact and 22 or 29)
 objective.TextSize=compact and 10 or 12
 mastery.Position=UDim2.fromOffset(compact and 8 or 13,compact and 56 or 81)
 mastery.Size=UDim2.new(1,compact and -16 or -26,0,compact and 13 or 18)
 masteryLimit.MinTextSize=compact and 8 or 10
 track.Position=UDim2.fromOffset(compact and 8 or 13,compact and 73 or 104)
 track.Size=UDim2.new(1,compact and -16 or -26,0,compact and 5 or 10)
 shardPlate.Visible=not compact;forgePlate.Visible=not compact
 for _,f in {card,cardShadow} do
  local s=f:FindFirstChild("ResponsiveScale") or Instance.new("UIScale",f);s.Name="ResponsiveScale";s.Scale=compact and 1 or math.clamp(width/1000,.72,1)
 end
 event.Position=UDim2.new(1,-14,0,width<900 and 174 or v.Y<500 and 104 or 64)
 event.Size=UDim2.fromOffset(width<900 and 220 or 260,62)
 for _,f in {celebration} do
  local s=f:FindFirstChild("ResponsiveScale") or Instance.new("UIScale",f);s.Name="ResponsiveScale";s.Scale=math.clamp(width/1000,.62,1)
 end
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit);fit()




