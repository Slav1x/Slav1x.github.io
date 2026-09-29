-- The Magical Rock after the tenth awakening, for this player only.
--   Invited  (the stone has spoken): overflowing gold. Veins of light traced over the
--            stone's real surface, amber edges, white-hot highlights, rising wisps, light
--            shafts, a pillar you can see from anywhere, a deeper hum, and it calls you.
--   Awakened (Golden Meridian unlocked): the same identity at rest. Calm gold, no calling.
-- Everything is client-side and rebuilt if the rock streams out and back in.
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Lighting=game:GetService("Lighting")
local Tween=game:GetService("TweenService")
local RS=game:GetService("ReplicatedStorage")
local Golden=require(RS.Shared.GoldenMeridianConfig)
local VFX=require(script.Parent.AwakeningVFX)
local smooth,make,part,seq=VFX.smooth,VFX.make,VFX.part,VFX.seq
local player=Players.LocalPlayer
local R={}
R.__index=R
local function tween(object,seconds,props) local t=Tween:Create(object,TweenInfo.new(seconds,Enum.EasingStyle.Sine),props);t:Play();return t end
local function positional(parent,name,id,speed,volume,minDistance,maxDistance,looped)
 local s=make("Sound",parent,{Name=name,SoundId=id,PlaybackSpeed=speed,Volume=volume,Looped=looped==true,RollOffMode=Enum.RollOffMode.InverseTapered,RollOffMinDistance=minDistance,RollOffMaxDistance=maxDistance})
 s:SetAttribute("GoldenAudio",true)
 return s
end
function R.new()
 local self=setmetatable({stage="Dormant",seen=false,quiet=false,level=0,flare=0,override=nil,focus=nil,focusStrength=0,
  surgeAt=-math.huge,surgeStrength=0,nextSurge=0,nextCall=6,t=0,acc=0,bindAcc=1,lastLine=0},R)
 self.folder=make("Folder",workspace,{Name="GoldenRockFX"})
 local gui=make("ScreenGui",player.PlayerGui,{Name="GoldenCall",IgnoreGuiInset=true,ResetOnSpawn=false,DisplayOrder=81,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 self.gui=gui
 self.callText=make("TextLabel",gui,{Name="Call",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.2),Size=UDim2.fromScale(.7,.06),BackgroundTransparency=1,Text="",
  TextScaled=true,Font=Enum.Font.Garamond,TextColor3=Golden.WhiteGold,TextStrokeColor3=Color3.fromRGB(40,24,6),TextStrokeTransparency=.55,TextTransparency=1})
 make("UITextSizeConstraint",self.callText,{MaxTextSize=30,MinTextSize=14})
 self.edges={}
 for _,spec in {{UDim2.fromScale(.5,0),UDim2.fromScale(1,.22),Vector2.new(.5,0),90},{UDim2.fromScale(.5,1),UDim2.fromScale(1,.22),Vector2.new(.5,1),-90},{UDim2.fromScale(0,.5),UDim2.fromScale(.16,1),Vector2.new(0,.5),0},{UDim2.fromScale(1,.5),UDim2.fromScale(.16,1),Vector2.new(1,.5),180}} do
  local f=make("Frame",gui,{Position=spec[1],Size=spec[2],AnchorPoint=spec[3],BorderSizePixel=0,BackgroundColor3=Golden.Gold,BackgroundTransparency=1})
  make("UIGradient",f,{Rotation=spec[4],Transparency=seq(0,0,1,1)})
  table.insert(self.edges,f)
 end
 self.connection=Run.Heartbeat:Connect(function(dt)
  local ok,err=pcall(self.step,self,dt)
  if not ok then warn("[GoldenRock] "..tostring(err)) end
 end)
 return self
end
function R:setStage(stage,seen)
 self.stage=stage;self.seen=seen==true
 if stage=="Dormant" then self:teardown() end
end
function R:setQuiet(quiet) self.quiet=quiet end
function R:surge(strength) self.surgeAt=self.t;self.surgeStrength=strength or 1 end
---------------------------------------------------------------- build
-- Veins follow the stone's real surface: raycast onto it, then walk across it.
local function traceVeins(v,folder)
 local rock=v.rock
 local list={}
 if rock:IsA("BasePart") then table.insert(list,rock) end
 for _,d in rock:GetDescendants() do
  if d:IsA("BasePart") and d.Transparency<.9 and d~=v.anchor and d.Name~="Stance" and d.Name~="PalmContact" then table.insert(list,d) end
 end
 if #list==0 then return {} end
 local restore={}
 for _,p in list do restore[p]=p.CanQuery;p.CanQuery=true end -- local-only; the server never sees this
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances=list
 local rng=Random.new(1010)
 local center=v.cf.Position
 local reach=v.size.Magnitude
 local step=math.clamp(v.size.Magnitude*.07,.35,1.2)
 local veins={}
 for _=1,11 do
  local dir=Vector3.new(rng:NextNumber(-1,1),rng:NextNumber(-.1,1),rng:NextNumber(-1,1))
  if dir.Magnitude<.15 then continue end
  dir=dir.Unit
  local hit=workspace:Raycast(center+dir*reach,-dir*reach*1.3,params)
  if not hit then continue end
  local points={hit.Position+hit.Normal*.04}
  local normal=hit.Normal
  local tangent=normal:Cross(Vector3.new(rng:NextNumber(-1,1),rng:NextNumber(-1,1),rng:NextNumber(-1,1)))
  if tangent.Magnitude<.01 then tangent=normal:Cross(Vector3.xAxis) end
  if tangent.Magnitude<.01 then continue end
  tangent=tangent.Unit
  for _=1,rng:NextInteger(5,9) do
   local side=normal:Cross(tangent)
   if side.Magnitude>.01 then tangent=(tangent+side.Unit*rng:NextNumber(-.55,.55)).Unit end
   local guess=points[#points]+tangent*step
   local probe=workspace:Raycast(guess+normal*1.6,-normal*3.4,params)
   if not probe then break end
   normal=probe.Normal
   tangent=tangent-normal*tangent:Dot(normal)
   if tangent.Magnitude<.01 then break end
   tangent=tangent.Unit
   table.insert(points,probe.Position+normal*.04)
  end
  if #points>=3 then table.insert(veins,{points=points,phase=rng:NextNumber(0,6.28)}) end
 end
 for p,q in restore do if p.Parent then p.CanQuery=q end end
 local segments={}
 for _,vein in veins do
  for k=1,#vein.points-1 do
   local a,b=vein.points[k],vein.points[k+1]
   local len=(b-a).Magnitude
   if len<.05 then continue end
   local cf=CFrame.lookAt((a+b)/2,b)
   local width=math.max(.05,.12*(1-k/#vein.points*.55))
   table.insert(segments,{
    core=part(folder,"GoldenVein",Vector3.new(width,width,len+width),cf,Golden.WhiteGold,1),
    glow=part(folder,"GoldenVeinGlow",Vector3.new(width*3,width*3,len+width*2),cf,Golden.Amber,1),
    index=k,phase=vein.phase,pos=(a+b)/2})
  end
 end
 return segments
end
function R:build(rock)
 local anchor=rock:FindFirstChild("InteractionAnchor")
 if not anchor or not anchor:IsA("BasePart") then return end
 local cf,size
 if rock:IsA("Model") then cf,size=rock:GetBoundingBox() elseif rock:IsA("BasePart") then cf,size=rock.CFrame,rock.Size else return end
 size=Vector3.new(math.min(size.X,40),math.min(size.Y,40),math.min(size.Z,40))
 local folder=make("Folder",self.folder,{Name="Rock"})
 local v={rock=rock,anchor=anchor,cf=cf,size=size,folder=folder}
 self.v=v
 v.center=part(folder,"GoldenCore",Vector3.one,cf,Golden.Gold,1)
 v.light=make("PointLight",v.center,{Color=Golden.Gold,Range=24,Brightness=0,Shadows=false})
 v.spill=make("PointLight",v.center,{Name="Spill",Color=Golden.Amber,Range=55,Brightness=0,Shadows=false})
 v.highlight=make("Highlight",folder,{Adornee=rock,FillColor=Golden.Gold,OutlineColor=Golden.WhiteGold,FillTransparency=1,OutlineTransparency=1,DepthMode=Enum.HighlightDepthMode.Occluded})
 v.shell=part(folder,"GoldenShell",size*.92,cf,Golden.Gold,1)
 local function emitter(name,props)
  local base={Name=name,Texture=VFX.Sparkle,Rate=0,Shape=Enum.ParticleEmitterShape.Box,ShapeStyle=Enum.ParticleEmitterShapeStyle.Surface,EmissionDirection=Enum.NormalId.Top,LightEmission=1,LightInfluence=0}
  for k,val in props do base[k]=val end
  return make("ParticleEmitter",v.shell,base)
 end
 v.motes=emitter("GoldMotes",{Lifetime=NumberRange.new(1.2,2.4),Speed=NumberRange.new(.8,2.6),Acceleration=Vector3.new(0,1.6,0),Drag=.5,SpreadAngle=Vector2.new(35,35),
  Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Golden.WhiteHot),ColorSequenceKeypoint.new(.4,Golden.Gold),ColorSequenceKeypoint.new(1,Golden.Amber)}),Size=seq(0,0,.2,.2,1,0),Transparency=seq(0,1,.15,0,1,1),RotSpeed=NumberRange.new(-80,80)})
 v.remnants=emitter("BlueRemnants",{Lifetime=NumberRange.new(1.4,2.2),Speed=NumberRange.new(.4,1.4),Acceleration=Vector3.new(0,1,0),SpreadAngle=Vector2.new(40,40),
  Color=ColorSequence.new(Golden.Ice,Golden.Blue),Size=seq(0,0,.3,.12,1,0),Transparency=seq(0,1,.2,.2,1,1)})
 v.wisps=emitter("GoldWisps",{Texture=VFX.Soft,Lifetime=NumberRange.new(1.6,2.8),Speed=NumberRange.new(2,4.5),Acceleration=Vector3.new(0,2.2,0),SpreadAngle=Vector2.new(18,18),
  Color=ColorSequence.new(Golden.Gold,Golden.WhiteGold),Size=seq(0,1,.5,2.6,1,3.6),Transparency=seq(0,1,.2,.7,1,1),Rotation=NumberRange.new(0,360),RotSpeed=NumberRange.new(-30,30)})
 v.ascending=emitter("AscendingWisps",{Texture=VFX.Soft,Lifetime=NumberRange.new(5,7.5),Speed=NumberRange.new(5,8),Acceleration=Vector3.new(0,1.2,0),SpreadAngle=Vector2.new(10,10),
  Color=ColorSequence.new(Golden.WhiteGold,Golden.Gold),Size=seq(0,2,.6,4.5,1,6),Transparency=seq(0,1,.15,.82,1,1),Rotation=NumberRange.new(0,360),RotSpeed=NumberRange.new(-15,15)})
 v.sparks=emitter("Crackle",{ShapeStyle=Enum.ParticleEmitterShapeStyle.Surface,Lifetime=NumberRange.new(.25,.55),Speed=NumberRange.new(4,9),Drag=6,SpreadAngle=Vector2.new(70,70),
  Color=ColorSequence.new(Golden.WhiteHot,Golden.Gold),Size=seq(0,.18,1,0),Transparency=seq(0,0,1,1)})
 v.segments=traceVeins(v,folder)
 -- Light shafts rising off the stone read as volumetric light.
 local top=part(folder,"GoldenTop",Vector3.one,CFrame.new(cf.Position+Vector3.new(0,size.Y*.42,0)),Golden.Gold,1)
 v.top=top
 v.rays={}
 for i=1,4 do
  local a=(i-1)*math.pi/2+.4
  local a0=make("Attachment",top,{Position=Vector3.new(math.cos(a)*size.X*.15,0,math.sin(a)*size.Z*.15)})
  local a1=make("Attachment",top,{Position=Vector3.new(math.cos(a)*6,34+i*3,math.sin(a)*6)})
  table.insert(v.rays,make("Beam",top,{Attachment0=a0,Attachment1=a1,FaceCamera=true,LightEmission=1,LightInfluence=0,Width0=size.X*.35,Width1=9,
   Texture=VFX.Soft,TextureMode=Enum.TextureMode.Stretch,TextureSpeed=.08,Color=ColorSequence.new(Golden.WhiteGold,Golden.Gold),Transparency=NumberSequence.new(1),Segments=6}))
 end
 -- The pillar: visible across the map while the stone is calling.
 local p0=make("Attachment",top,{Position=Vector3.zero})
 local p1=make("Attachment",top,{Position=Vector3.new(0,320,0)})
 v.pillar=make("Beam",top,{Attachment0=p0,Attachment1=p1,FaceCamera=true,LightEmission=1,LightInfluence=0,Width0=1.6,Width1=.5,Segments=4,
  Color=ColorSequence.new(Golden.WhiteHot,Golden.Gold),Transparency=NumberSequence.new(1),Enabled=false})
 -- Ground surge rings.
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={rock,self.folder,player.Character}
 local hit=workspace:Raycast(cf.Position,Vector3.new(0,-size.Y-20,0),params)
 v.ground=CFrame.new((hit and hit.Position or cf.Position-Vector3.new(0,size.Y/2,0))+Vector3.new(0,.08,0))
 v.rings={VFX.ring(folder,"GoldenSurge",64,Golden.Gold,.16,1,v.ground),VFX.ring(folder,"GoldenSurge",64,Golden.WhiteGold,.08,1,v.ground)}
 -- Sound: a deeper hum, a high shimmer, heard from the stone itself.
 v.hum=positional(v.center,"GoldenHum",Golden.Audio.Ambient,.55,0,8,170,true)
 v.shimmer=positional(v.center,"GoldenShimmer",Golden.Audio.Ambient,1.45,0,6,70,true)
 v.hum:Play();v.shimmer:Play()
 -- Our own prompt replaces the review prompt for this player (the server prompt is untouched).
 v.prompt=make("ProximityPrompt",anchor,{Name="GoldenPrompt",ActionText="Return to the stone",ObjectText="Magical Rock",KeyboardKeyCode=Enum.KeyCode.E,GamepadKeyCode=Enum.KeyCode.ButtonY,
  HoldDuration=.6,MaxActivationDistance=12,RequiresLineOfSight=false,Style=Enum.ProximityPromptStyle.Default,Enabled=false})
 v.prompt.Triggered:Connect(function() if self.onPrompt then self.onPrompt() end end)
 v.waypoint=make("BillboardGui",folder,{Name="GoldenWaypoint",Adornee=anchor,Size=UDim2.fromOffset(240,56),StudsOffsetWorldSpace=Vector3.new(0,size.Y*.5+5,0),AlwaysOnTop=true,MaxDistance=3000,LightInfluence=0,Enabled=false})
 v.waypointText=make("TextLabel",v.waypoint,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",TextScaled=true,Font=Enum.Font.Garamond,TextColor3=Golden.WhiteGold,TextStrokeColor3=Color3.fromRGB(40,24,6),TextStrokeTransparency=.4})
 v.warmth=make("ColorCorrectionEffect",Lighting,{Name="GoldenRockWarmth",TintColor=Color3.new(1,1,1),Brightness=0,Contrast=0,Saturation=0})
end
function R:teardown()
 local v=self.v
 if not v then return end
 self.v=nil
 if v.original and v.original.Parent then v.original.Enabled=v.originalEnabled end
 pcall(function() v.warmth:Destroy() end)
 pcall(function() v.prompt:Destroy() end)
 pcall(function() v.folder:Destroy() end)
end
---------------------------------------------------------------- behaviour
function R:call()
 local v=self.v
 if not v then return end
 self:surge(1.3)
 local whisper=positional(v.center,"GoldenCall",Golden.Audio.Chime,.6,.34,18,600,false)
 whisper:Play();task.delay(8,function() whisper:Destroy() end)
 local low=positional(v.center,"GoldenPulse",Golden.Audio.Impact,.42,.24,20,600,false)
 low:Play();task.delay(8,function() low:Destroy() end)
 local lines={Golden.format("{name}…",player.DisplayName)}
 if self.seen then
  local i=math.random(1,#Golden.RockCalls)
  if i==self.lastLine then i=i%#Golden.RockCalls+1 end
  self.lastLine=i
  table.insert(lines,Golden.RockCalls[i])
 else
  table.insert(lines,"Come to the stone.")
 end
 for _,f in self.edges do
  tween(f,.7,{BackgroundTransparency=.72})
  task.delay(.8,function() tween(f,2.2,{BackgroundTransparency=1}) end)
 end
 task.spawn(function()
  for _,text in lines do
   if self.quiet then break end
   self.callText.Text=text
   tween(self.callText,.9,{TextTransparency=0})
   task.wait(2.6)
   tween(self.callText,.9,{TextTransparency=1})
   task.wait(1)
  end
 end)
end
local function busy()
 return player:GetAttribute("RockInFlight")==true or player:GetAttribute("RebirthCinematic")==true or player:GetAttribute("RebirthCutscene")==true
  or player:GetAttribute("GoldenCutscene")==true or player:GetAttribute("NoobDialogueOpen")==true
end
function R:step(dt)
 self.t+=dt
 self.bindAcc+=dt
 if self.bindAcc>=.5 then
  self.bindAcc=0
  local rock=self.stage~="Dormant" and workspace:FindFirstChild("MagicalRock") or nil
  if self.v and (self.v.rock~=rock or not self.v.rock.Parent) then self:teardown() end
  if rock and not self.v then self:build(rock) end
 end
 local v=self.v
 if not v then return end
 local t=self.t
 local awakened=self.stage=="Awakened"
 local calling=self.stage=="Invited" and not self.quiet and not busy()
 local target=self.override or (awakened and .55 or (self.seen and 1 or 0))
 self.level+=(target-self.level)*math.min(1,dt*(self.override and 4 or 1.2))
 local L=self.level
 -- Surges: the stone overflows every few seconds; the gold one breathes slower.
 if not self.quiet and t>=self.nextSurge and L>.2 then
  self:surge(awakened and .4 or .7+math.random()*.5)
  self.nextSurge=t+(awakened and 9+math.random()*6 or 3.5+math.random()*3.5)
 end
 local s=math.max(0,1-(t-self.surgeAt)/1.5)*self.surgeStrength
 -- Calling: more insistent than any call before it.
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local distance=root and (root.Position-v.cf.Position).Magnitude or math.huge
 if calling and (self.seen or distance<400) and t>=self.nextCall then
  self:call()
  self.nextCall=t+(distance<45 and 16 or 30)+math.random()*6
 end
 v.prompt.Enabled=not self.quiet and ((self.stage=="Invited" and self.seen) or awakened) and not busy()
 v.prompt.ActionText=awakened and "Touch the stone" or "Return to the stone"
 local original=v.anchor:FindFirstChild("RebirthPrompt")
 if original and original:IsA("ProximityPrompt") then
  if v.original~=original then v.original=original;v.originalEnabled=original.Enabled end
  if original.Enabled then original.Enabled=false end
 end
 v.waypoint.Enabled=self.stage=="Invited" and not self.quiet and not busy() and distance>16
 if v.waypoint.Enabled then v.waypointText.Text="◈  THE MAGICAL ROCK\n"..(distance<60 and "It is waiting for you" or tostring(math.floor(distance)).." studs") end
 v.pillar.Enabled=calling and self.seen and L>.5
 if v.pillar.Enabled then v.pillar.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.35-.2*s),NumberSequenceKeypoint.new(.5,.7),NumberSequenceKeypoint.new(1,1)}) end
 -- Surge rings across the ground.
 local ring=smooth((t-self.surgeAt)/1.6)
 local ringAlpha=(1-ring)*math.min(1,self.surgeStrength)*L
 v.rings[1]:paint(Golden.Gold,1-ringAlpha*.7);v.rings[2]:paint(Golden.WhiteGold,1-ringAlpha*.5)
 if ringAlpha>0 then
  local radius=math.max(v.size.X,v.size.Z)*.6+ring*(awakened and 10 or 22)
  v.rings[1]:place(v.ground,radius,t*.1);v.rings[2]:place(v.ground,radius*.94,-t*.1)
 end
 -- Visual update at ~30 Hz; sound and prompts above run every frame.
 self.acc+=dt
 if self.acc<1/30 then return end
 self.acc=0
 local unstable=awakened and 1 or (.86+.14*math.sin(t*13.1)*math.sin(t*3.7))
 local flare=self.flare
 local focus,focusStrength=self.focus,self.focusStrength
 for _,seg in v.segments do
  local w=.5+.5*math.sin(t*(awakened and 1.2 or 2.3)-seg.index*.6+seg.phase)
  local near=focus and focusStrength*math.clamp(1-(seg.pos-focus).Magnitude/(v.size.Magnitude*.55),0,1) or 0
  local b=L*(.3+.7*w)*(1+.7*s+flare+near*1.5)*(awakened and .7 or unstable)
  seg.core.Transparency=1-math.clamp(b*.95,0,1)
  seg.glow.Transparency=1-math.clamp(b*.38,0,.6)
  seg.core.Color=Golden.WhiteGold:Lerp(Golden.WhiteHot,math.clamp(s+flare+near-.2,0,1))
 end
 v.highlight.FillTransparency=1-math.clamp(L*(.1+.12*s+.3*flare)*unstable,0,.6)
 v.highlight.OutlineTransparency=1-math.clamp(L*(.5+.3*s+.2*flare),0,1)
 v.light.Brightness=L*(1.3+2.4*s+4*flare)*(.9+.1*math.sin(t*9))
 v.light.Range=16+12*L
 v.spill.Brightness=L*(.35+.6*s+flare)
 local rate=awakened and .35 or 1
 v.motes.Rate=L*28*rate*(1+s+flare)
 v.remnants.Rate=L*3*rate
 v.wisps.Rate=L*12*rate*(1+s*.5)
 v.ascending.Rate=L*2.4*rate
 if not awakened and not self.quiet and math.random()<.06*L then v.sparks:Emit(math.random(2,5)) end
 local rayAlpha=L*(awakened and .45 or 1)*(.75+.25*math.sin(t*.9))+s*.2
 for _,beam in v.rays do beam.Transparency=seq(0,1-math.clamp(rayAlpha*.2,0,1),.5,1-math.clamp(rayAlpha*.1,0,1),1,1) end
 v.hum.Volume=L*(awakened and .14 or .3)*(self.quiet and .6 or 1)+s*.05
 v.hum.PlaybackSpeed=.55+.04*s
 v.shimmer.Volume=L*(awakened and .03 or .07)
 -- The light around the stone warms whoever stands near it.
 local camera=workspace.CurrentCamera
 local near=camera and math.clamp(1-((camera.CFrame.Position-v.cf.Position).Magnitude-25)/100,0,1)*L*(awakened and .45 or 1) or 0
 v.warmth.TintColor=Color3.new(1,1,1):Lerp(Color3.fromRGB(255,240,214),near)
 v.warmth.Brightness=.015*near+.02*s*near
end
---------------------------------------------------------------- the stone speaks (after rebirth 10)
function R:speak(D,dlg,audio)
 local v=self.v
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if not v or not root then return false end
 self.quiet=true
 self.override=0
 local camera=workspace.CurrentCamera
 local start=camera.CFrame
 local rockPos=v.cf.Position
 local flat=(rockPos-root.Position)*Vector3.new(1,0,1)
 local dir=flat.Magnitude>.1 and flat.Unit or (camera.CFrame.LookVector*Vector3.new(1,0,1)).Unit
 local right=dir:Cross(Vector3.yAxis)
 local focus=rockPos+Vector3.new(0,v.size.Y*.12,0)
 local shot=CFrame.lookAt(root.Position-dir*7+right*2.6+Vector3.new(0,2.6,0),focus)
 local close=CFrame.lookAt(root.Position-dir*4.5+right*2+Vector3.new(0,2.2,0),focus)
 audio:world(.25,1.5)
 audio:layer("drone",Golden.Audio.Ambient,.62)
 audio:set("drone",.2,2)
 D:animate(1.7,function(a) D:shoot(start:Lerp(shot,D.inOut(a)),60-8*D.smooth(a));D:setBars(D.smooth(a)) end)
 self:surge(.5);audio:impact(.42,.16)
 -- A slow push toward the stone underneath the words.
 local pushStart=os.clock()
 local stopPush=D:every(function()
  local a=D.smooth((os.clock()-pushStart)/22)
  D:shoot(shot:Lerp(close,a),52-4*a)
 end)
 for i,text in Golden.RockSpeech do
  if not D.alive then break end
  if i==4 then D:spawn(function() D:animate(3,function(a) self.override=.4*D.smooth(a) end) end) end
  if i==5 then self:surge(.9);audio:impact(.5,.16) end
  if i==6 then D:spawn(function() D:animate(2.5,function(a) self.override=.4+.35*D.smooth(a) end) end) end
  dlg:whisper(Golden.format(text,player.DisplayName),i==1 and 1.6 or 2.3,i<4 and Golden.Ice or Golden.WhiteGold)
 end
 stopPush()
 if not D.alive then return false end
 -- The change: a surge that does not fade back to blue.
 self.override=1;self.level=math.max(self.level,.8)
 self:surge(2.4)
 audio:impact(.55,.5);audio:chime(.5,.28);audio:set("drone",.34,1.2,.5)
 D:spawn(function() D:animate(2.4,function(a) self.flare=1-D.smooth(a) end) end)
 local held=camera.CFrame
 D:animate(3.4,function(a,e)
  local k=math.max(0,1-e/.6)
  D:shoot(held*CFrame.new(math.sin(e*70)*.06*k,math.cos(e*60)*.05*k,0))
 end)
 self.seen=true
 self.override=nil
 audio:set("drone",0,2)
 audio:world(1,2)
 local fromCF=camera.CFrame
 D:animate(1.6,function(a) D:shoot(fromCF:Lerp(start,D.inOut(a)),48+(60-48)*a);D:setBars(1-D.smooth(a)) end)
 self.quiet=false
 self.nextCall=self.t+10
 return true
end
function R:destroy()
 self.connection:Disconnect()
 self:teardown()
 self.folder:Destroy()
 self.gui:Destroy()
end
return R
