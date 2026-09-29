-- Existing bounded pool: biome motes, surface haze, and two shore/dust anchors.
local Run=game:GetService('RunService')
local Water=require(game.ReplicatedStorage.Shared.WaterSurface)
local Biomes=require(game.ReplicatedStorage.Shared.BiomePresentation)
local player=game.Players.LocalPlayer
local Shore=require(game.ReplicatedStorage.Shared.RiverlandsShoreProfile)
local spawn=workspace:WaitForChild('SpawnLocation')
local folder=Instance.new('Folder');folder.Name='LocalLakeAmbience';folder.Parent=workspace
local function emitter(name,texture,size,life)
 local anchor=Instance.new('Part');anchor.Name=name;anchor.Anchored=true;anchor.CanCollide=false;anchor.CanQuery=false;anchor.CanTouch=false;anchor.Transparency=1;anchor.Size=Vector3.new(70,16,70);anchor.Parent=folder
 local e=Instance.new('ParticleEmitter',anchor);e.Texture=texture;e.Rate=0;e.Lifetime=NumberRange.new(life*.65,life);e.Speed=NumberRange.new(.5,1.5);e.SpreadAngle=Vector2.new(180,180);e.LightEmission=.45;e.LightInfluence=.45
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.25,size),NumberSequenceKeypoint.new(1,0)})
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.2,.62),NumberSequenceKeypoint.new(.8,.83),NumberSequenceKeypoint.new(1,1)})
 e.Rotation=NumberRange.new(0,360);e.RotSpeed=NumberRange.new(-16,16);e.Drag=.24
 return anchor,e
end
local motes,me=emitter('BiomeMotes','rbxasset://textures/particles/sparkles_main.dds',.19,5)
local mist,mi=emitter('WaterHaze','rbxasset://textures/particles/smoke_main.dds',7,6);mist.Size=Vector3.new(90,1,90)
mi.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.4,.95),NumberSequenceKeypoint.new(1,1)})
local sand={}
for _,side in {-1,1} do
 local a,e=emitter('ShoreSandDust','rbxasset://textures/particles/smoke_main.dds',.8,3)
 a.Size=Vector3.new(18,.2,28);e.LightEmission=0;e.LightInfluence=.85;e.SpreadAngle=Vector2.new(18,18)
 table.insert(sand,{part=a,emitter=e,side=side})
end
local elapsed=0;local previous
local smoothColor=Color3.fromRGB(255,230,171)
local connection=Run.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.12 then return end
 local step=elapsed;elapsed=0
 local cam=workspace.CurrentCamera;if not cam then return end
 local pos=cam.CFrame.Position
 local profile=Biomes.at(pos)
 local event=Biomes.event()
 local reduced=player:GetAttribute('ReducedMotion')==true
 local alpha=1-math.exp(-1.5*step)
 local color=event and profile.mote:Lerp(event.color,.22) or profile.mote
 smoothColor=smoothColor:Lerp(color,alpha)
 me.Color=ColorSequence.new(smoothColor);mi.Color=ColorSequence.new(profile.fog)
 me.Rate+=(profile.moteRate-me.Rate)*alpha;mi.Rate+=(profile.mistRate-mi.Rate)*alpha
 me.Enabled=not reduced and math.abs(pos.Z+40.5)<500
 local gust=.85+.25*math.sin(os.clock()*.32)
 me.Acceleration=profile.id=='inferno' and Vector3.new(.25,2,0) or profile.id=='cosmic' and Vector3.new(.15,.1,.1) or Vector3.new(2.4,.1,.9)*gust
 if profile.id=='frozen' then me.Acceleration=Vector3.new(1,-3,.4);me.Speed=NumberRange.new(1,3) elseif profile.id=='toxic' then me.Acceleration=Vector3.new(0,1.4,0);me.Speed=NumberRange.new(.4,1) else me.Speed=NumberRange.new(.5,1.5) end
 me.Squash=NumberSequence.new(profile.id=='blossom' and 1.1 or 0)
 local size=profile.id=='frozen' and .38 or profile.id=='blossom' and .65 or profile.id=='sunscorch' and 1.2 or .24
 me.Texture=profile.id=='sunscorch' and 'rbxasset://textures/particles/smoke_main.dds' or 'rbxasset://textures/particles/sparkles_main.dds'
 me.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.2,size),NumberSequenceKeypoint.new(.8,size*.8),NumberSequenceKeypoint.new(1,0)})
 mi.Acceleration=Vector3.new(.6,.04,.25)*gust
 local y=Water.at(pos)
 mi.Enabled=not reduced and y~=nil and math.abs(pos.Y-(y or 0))<55
 motes.Position=pos+cam.CFrame.LookVector*24
 if y then mist.Position=Vector3.new(pos.X,y+1.3,pos.Z) end
 local beach=math.abs(pos.X-(spawn.Position.X+83))<150 and math.abs(pos.Z-spawn.Position.Z)<140 and pos.Y<55
 for _,item in sand do
  local desert=profile.id=='sunscorch'
  item.part.Position=desert and Vector3.new(pos.X+35,22,Shore.at(pos.X+35,item.side)+item.side*14) or spawn.Position+Vector3.new(83,.05,item.side*34)
  item.emitter.Enabled=not reduced and (beach or desert)
  item.emitter.Color=ColorSequence.new(profile.mote)
  item.emitter.Rate=desert and 1.2 or 1.5
  item.emitter.Acceleration=Vector3.new(1.5,.06,.6)*gust
 end
 if previous and (pos-previous).Magnitude>180 then me:Clear();mi:Clear();for _,item in sand do item.emitter:Clear() end end
 previous=pos
end)
script.Destroying:Connect(function() connection:Disconnect();folder:Destroy() end)
