-- The Spirit Realm: a private place far off the map that only this client builds.
-- Calm reflective water to the horizon, low mist, a low sun behind the Pebble God, colossal
-- stones drifting in the haze. Deliberately empty. Everything is parented to one folder
-- and every Lighting change is restored when the director closes.
--
-- Realm-local space: origin is the arrival point on the water, -Z runs toward the god.
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Lighting=game:GetService("Lighting")
local RS=game:GetService("ReplicatedStorage")
local Golden=require(RS.Shared.GoldenMeridianConfig)
local VFX=require(script.Parent.AwakeningVFX)
local make,part,seq=VFX.make,VFX.part,VFX.seq
local player=Players.LocalPlayer
local Realm={}
Realm.__index=Realm
local LIGHT_KEYS={"ClockTime","Brightness","Ambient","OutdoorAmbient","ColorShift_Top","ColorShift_Bottom","EnvironmentDiffuseScale","EnvironmentSpecularScale","GeographicLatitude"}
local ATMOSPHERE_KEYS={"Density","Offset","Color","Decay","Glare","Haze"}
-- Mirror across the water plane. Positions are exact; each part is also turned over so
-- faces and trims read upside down, like a real reflection.
local function mirror(cf,h)
 local x,y,z,r00,r01,r02,r10,r11,r12,r20,r21,r22=cf:GetComponents()
 return CFrame.new(x,2*h-y,z,r00,-r01,r02,-r10,r11,-r12,r20,-r21,r22)*CFrame.Angles(0,0,math.pi)
end
Realm.mirror=mirror
-- Pick the time of day whose low sun sits behind the god, so he stands against the glow.
local function chooseClock(towardGod)
 local original=Lighting.ClockTime
 local best,bestScore=17.3,-math.huge
 local function try(t)
  Lighting.ClockTime=t
  local d=Lighting:GetSunDirection()
  local elevation=math.deg(math.asin(math.clamp(d.Y,-1,1)))
  local flat=Vector3.new(d.X,0,d.Z)
  if flat.Magnitude<.01 or elevation<2 then return end
  local score=flat.Unit:Dot(towardGod)*2-math.abs(elevation-10)/8
  if score>bestScore then best,bestScore=t,score end
 end
 for t=5.8,7.6,.1 do try(t) end
 for t=16.4,18.2,.1 do try(t) end
 Lighting.ClockTime=original
 return best
end
function Realm.build(D,basis,audio)
 local self=setmetatable({D=D,basis=basis,audio=audio,t=0,ripplePool={},reflections={},monoliths={},proximity=0,mistLevel=1,
  flashAt=-math.huge,flashStrength=0,flashColor=Golden.WhiteGold,lastStep=0,lastIdle=0,nextBell=4,pathLevel=1,atmosphereBoost=0},Realm)
 local folder=D:add(make("Folder",workspace,{Name="SpiritRealm"}))
 self.folder=folder
 self.floorY=basis.Position.Y
 self.godPosition=basis:PointToWorldSpace(Golden.Realm.God)
 ---------------------------------------------------------------- water
 -- An invisible floor carries the player; the visible water is glass over a pale deep.
 make("Part",folder,{Name="Floor",Size=Vector3.new(2048,4,2048),CFrame=basis*CFrame.new(0,-2,0),Anchored=true,CanCollide=true,CanQuery=true,CanTouch=false,Transparency=1,CastShadow=false})
 make("Part",folder,{Name="WaterSurface",Size=Vector3.new(2048,.1,2048),CFrame=basis*CFrame.new(0,.03,0),Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,CastShadow=false,
  Material=Enum.Material.Glass,Color=Color3.fromRGB(196,210,214),Transparency=.42,Reflectance=.18})
 make("Part",folder,{Name="WaterDeep",Size=Vector3.new(2048,1,2048),CFrame=basis*CFrame.new(0,-150,0),Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,CastShadow=false,
  Material=Enum.Material.Neon,Color=Color3.fromRGB(176,172,160)})
 self.reflectFolder=make("Folder",folder,{Name="Reflections"})
 ---------------------------------------------------------------- ripple pool (perfect circles via SurfaceGui)
 for i=1,16 do
  local p=make("Part",folder,{Name="Ripple",Size=Vector3.new(1,.05,1),Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,Transparency=1,CastShadow=false,CFrame=basis*CFrame.new(0,-50,0)})
  local sg=make("SurfaceGui",p,{Face=Enum.NormalId.Top,SizingMode=Enum.SurfaceGuiSizingMode.FixedSize,CanvasSize=Vector2.new(256,256),LightInfluence=0,AlwaysOnTop=false,Enabled=false})
  local ring=make("Frame",sg,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,1),BackgroundTransparency=1})
  make("UICorner",ring,{CornerRadius=UDim.new(.5,0)})
  local stroke=make("UIStroke",ring,{Color=Color3.new(1,1,1),Thickness=3,Transparency=1})
  local soft=make("Frame",sg,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.94,.94),BackgroundTransparency=1})
  make("UICorner",soft,{CornerRadius=UDim.new(.5,0)})
  local softStroke=make("UIStroke",soft,{Color=Color3.new(1,1,1),Thickness=8,Transparency=1})
  self.ripplePool[i]={part=p,gui=sg,stroke=stroke,soft=softStroke,active=false}
 end
 ---------------------------------------------------------------- mist, motes, drift
 local follow=part(folder,"RealmAir",Vector3.new(300,2,300),basis*CFrame.new(0,1.2,0),Golden.Mist,1)
 self.follow=follow
 self.mist=make("ParticleEmitter",follow,{Name="Mist",Texture=VFX.Soft,Rate=7,Shape=Enum.ParticleEmitterShape.Box,ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume,
  Lifetime=NumberRange.new(10,14),Speed=NumberRange.new(.3,.9),SpreadAngle=Vector2.new(180,180),Acceleration=Vector3.new(0,.05,0),LightEmission=.15,LightInfluence=.7,
  Color=ColorSequence.new(Golden.Mist),Size=seq(0,18,.5,28,1,34),Transparency=seq(0,1,.25,.9,.75,.92,1,1),Rotation=NumberRange.new(0,360),RotSpeed=NumberRange.new(-4,4)})
 local airHigh=part(folder,"RealmMotes",Vector3.new(160,30,160),basis*CFrame.new(0,15,0),Golden.Gold,1)
 self.airHigh=airHigh
 self.motes=make("ParticleEmitter",airHigh,{Name="Motes",Texture=VFX.Sparkle,Rate=10,Shape=Enum.ParticleEmitterShape.Box,ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume,
  Lifetime=NumberRange.new(5,8),Speed=NumberRange.new(.2,.6),SpreadAngle=Vector2.new(180,180),Acceleration=Vector3.new(0,.2,0),LightEmission=1,LightInfluence=0,
  Color=ColorSequence.new(Golden.WhiteGold,Golden.Gold),Size=seq(0,0,.3,.12,1,0),Transparency=seq(0,1,.3,.3,1,1)})
 self.drift=make("ParticleEmitter",airHigh,{Name="DriftTowardGod",Texture=VFX.Sparkle,Rate=4,Shape=Enum.ParticleEmitterShape.Box,ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume,
  Lifetime=NumberRange.new(4,6),Speed=NumberRange.new(0),Acceleration=Vector3.zero,LightEmission=1,LightInfluence=0,
  Color=ColorSequence.new(Golden.Gold),Size=seq(0,0,.4,.1,1,0),Transparency=seq(0,1,.4,.25,1,1)})
 ---------------------------------------------------------------- colossal stones in the haze
 local rng=Random.new(77)
 local stones={
  {Vector3.new(-320,70,-380),70},{Vector3.new(210,110,-560),110},{Vector3.new(-160,150,-660),95},{Vector3.new(430,95,-200),80},
  {Vector3.new(390,40,140),60},{Vector3.new(-430,85,70),85},{Vector3.new(70,170,390),120},{Vector3.new(-270,48,-90),46},
  {Vector3.new(300,135,-430),78},{Vector3.new(-60,210,-900),160},
 }
 local palette={Color3.fromRGB(92,96,104),Color3.fromRGB(122,118,110),Color3.fromRGB(70,74,82),Color3.fromRGB(150,142,128)}
 for i,spec in stones do
  local size=spec[2]
  local p=make("Part",folder,{Name="Monolith",Size=Vector3.new(size,size*.52,size*.8),Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,CastShadow=false,
   Material=Enum.Material.Slate,Color=palette[(i-1)%#palette+1]})
  make("SpecialMesh",p,{MeshType=Enum.MeshType.Sphere})
  table.insert(self.monoliths,{part=p,base=spec[1],tilt=CFrame.Angles(rng:NextNumber(-.4,.4),rng:NextNumber(0,6.28),rng:NextNumber(-.3,.3)),
   bob=rng:NextNumber(2,5),period=rng:NextNumber(18,30),phase=rng:NextNumber(0,6.28),spin=rng:NextNumber(-.012,.012),lift=0})
 end
 ---------------------------------------------------------------- a faint path of light to the god
 self.path={}
 for i=1,22 do
  local z=-8-(i-1)*9
  local disc=part(folder,"GuideLight",Vector3.new(.06,2.4,2.4),basis*CFrame.new(math.sin(i*.7)*.6,.06,z)*CFrame.Angles(0,0,math.pi/2),Golden.Gold,1,Enum.PartType.Cylinder)
  table.insert(self.path,{part=disc,index=i})
 end
 -- A shaft of light on the god himself.
 local shaft=part(folder,"GodShaft",Vector3.one,CFrame.new(self.godPosition),Golden.WhiteGold,1)
 local s0=make("Attachment",shaft,{Position=Vector3.new(0,200,0)})
 local s1=make("Attachment",shaft,{Position=Vector3.new(0,1,0)})
 self.shaft=make("Beam",shaft,{Attachment0=s0,Attachment1=s1,FaceCamera=true,LightEmission=1,LightInfluence=0,Width0=30,Width1=10,Segments=4,
  Texture=VFX.Soft,TextureMode=Enum.TextureMode.Stretch,Color=ColorSequence.new(Golden.WhiteGold),Transparency=seq(0,1,.4,.86,1,.8)})
 ---------------------------------------------------------------- light
 local towardGod=(self.godPosition-basis.Position)*Vector3.new(1,0,1)
 self.clock=chooseClock(towardGod.Magnitude>0 and towardGod.Unit or Vector3.xAxis)
 self.savedLighting={}
 for _,k in LIGHT_KEYS do self.savedLighting[k]=Lighting[k] end
 local atmosphere=Lighting:FindFirstChildOfClass("Atmosphere")
 if not atmosphere then atmosphere=D:add(make("Atmosphere",Lighting,{Name="SpiritRealmAtmosphere"})) end
 self.atmosphere=atmosphere
 self.savedAtmosphere={}
 for _,k in ATMOSPHERE_KEYS do self.savedAtmosphere[k]=atmosphere[k] end
 local clouds=workspace.Terrain:FindFirstChildOfClass("Clouds")
 if clouds then
  local was=clouds.Enabled;clouds.Enabled=false
  D:add(function() if clouds.Parent then clouds.Enabled=was end end)
 end
 self.grade=D:add(make("ColorCorrectionEffect",Lighting,{Name="SpiritRealmGrade",TintColor=Color3.fromRGB(255,249,238),Contrast=.1,Saturation=-.08,Brightness=0}))
 self.bloom=D:add(make("BloomEffect",Lighting,{Name="SpiritRealmBloom",Intensity=.55,Size=36,Threshold=.93}))
 self.rays=D:add(make("SunRaysEffect",Lighting,{Name="SpiritRealmRays",Intensity=.08,Spread=.75}))
 self.depth=D:add(make("DepthOfFieldEffect",Lighting,{Name="SpiritRealmDepth",FarIntensity=.18,FocusDistance=40,InFocusRadius=90,NearIntensity=0}))
 D:add(function()
  Run:UnbindFromRenderStep("GoldenRealmLighting")
  for k,v in self.savedLighting do pcall(function() Lighting[k]=v end) end
  if atmosphere.Parent then for k,v in self.savedAtmosphere do pcall(function() atmosphere[k]=v end) end end
 end)
 return self
end
-- The realm's light, re-applied just before each frame renders so it wins over the
-- world's lighting controller; when the realm closes that controller glides back.
function Realm:startLight()
 Run:BindToRenderStep("GoldenRealmLighting",Enum.RenderPriority.Last.Value,function()
  local near=self.proximity
  local f=math.max(0,1-(self.t-self.flashAt)/1.2)*self.flashStrength
  Lighting.ClockTime=self.clock
  Lighting.Brightness=3.1+f*1.5
  Lighting.Ambient=Color3.fromRGB(132,124,116)
  Lighting.OutdoorAmbient=Color3.fromRGB(206,196,182)
  Lighting.ColorShift_Top=Color3.fromRGB(255,224,176)
  Lighting.ColorShift_Bottom=Color3.fromRGB(0,0,0)
  Lighting.EnvironmentDiffuseScale=.5;Lighting.EnvironmentSpecularScale=1
  local a=self.atmosphere
  a.Density=(.40-.13*near)*self.mistLevel+self.atmosphereBoost
  a.Offset=.18;a.Color=Color3.fromRGB(238,228,210);a.Decay=Color3.fromRGB(255,190,118)
  a.Glare=1.4+.8*near;a.Haze=(2.6-.8*near)*self.mistLevel
  self.grade.Brightness=f*.35
  self.grade.TintColor=Color3.fromRGB(255,249,238):Lerp(self.flashColor,f*.6)
 end)
end
function Realm:flash(color,strength)
 self.flashAt=self.t;self.flashColor=color or Golden.WhiteGold;self.flashStrength=strength or 1
end
function Realm:point(v) return self.basis:PointToWorldSpace(v) end
function Realm:onWater(position) return Vector3.new(position.X,self.floorY,position.Z) end
function Realm:ripple(position,radius,seconds,color,strength)
 for _,r in self.ripplePool do
  if not r.active then
   r.active=true;r.at=self.t;r.position=position;r.radius=radius;r.seconds=seconds or 1.6;r.strength=strength or .6
   r.stroke.Color=color or Color3.new(1,1,1);r.soft.Color=r.stroke.Color
   r.gui.Enabled=true
   return
  end
 end
end
-- Reflections of the given parts below the water. Dynamic sources are re-mirrored each frame.
function Realm:reflect(parts)
 local set={}
 for _,source in parts do
  if source:IsA("BasePart") and source.Transparency<.98 and source.Name~="HumanoidRootPart" then
   local ok,clone=pcall(function() return source:Clone() end)
   if ok and clone then
    for _,d in clone:GetDescendants() do
     if not (d:IsA("DataModelMesh") or d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceAppearance")) then d:Destroy() end
    end
    clone.Anchored=true;clone.CanCollide=false;clone.CanQuery=false;clone.CanTouch=false;clone.CastShadow=false
    clone.CFrame=mirror(source.CFrame,self.floorY)
    clone.Parent=self.reflectFolder
    table.insert(set,{source=source,clone=clone})
   end
  end
 end
 table.insert(self.reflections,set)
 return set
end
function Realm:proximityTo(k) self.proximity=k end
-- Raise the colossal stones (the fifth skip).
function Realm:liftMonoliths(amount) for _,m in self.monoliths do m.liftTarget=amount*(.6+.4*math.abs(math.sin(m.phase))) end end
function Realm:setPath(level) self.pathLevel=level end
function Realm:startSound()
 local audio=self.audio
 audio:layer("water",Golden.Audio.Water,.9,{wet=-14});audio:set("water",.2,3)
 audio:layer("wash",Golden.Audio.Wash,.72,{wet=-12});audio:set("wash",.08,3)
 audio:layer("air",Golden.Audio.Ambient,1.85,{eq={-24,-6,0},wet=-8});audio:set("air",.06,4)
 audio:layer("bed",Golden.Audio.Ambient,.83,{decay=4,wet=-6});audio:set("bed",.18,4)
 audio:layer("deep",Golden.Audio.Ambient,.5,{eq={2,-4,-18}});audio:set("deep",.12,4)
 audio:layer("choir",Golden.Audio.Ambient,1.12,{chorus=true,decay=5,wet=-3});audio:set("choir",0,1)
end
function Realm:start()
 local D=self.D
 self:startLight()
 D:every(function(dt) self:step(dt) end)
end
function Realm:step(dt)
 self.t+=dt
 local t=self.t
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local hum=character and character:FindFirstChildOfClass("Humanoid")
 -- Air follows the player.
 if root then
  local p=root.Position
  self.follow.CFrame=CFrame.new(p.X,self.floorY+1.2,p.Z)
  self.airHigh.CFrame=CFrame.new(p.X,self.floorY+15,p.Z)
  local toGod=(self.godPosition-p)*Vector3.new(1,0,1)
  if toGod.Magnitude>1 then self.drift.Acceleration=toGod.Unit*1.4+Vector3.new(0,.1,0) end
  -- Every step touches the water.
  local grounded=hum and hum.FloorMaterial~=Enum.Material.Air
  local moving=hum and hum.MoveDirection.Magnitude>.1
  if grounded and moving and t-self.lastStep>.32 then
   self.lastStep=t;self:ripple(self:onWater(p),3.4,1.5,Color3.new(1,1,1),.5)
  elseif grounded and not moving and t-self.lastIdle>2.4 then
   self.lastIdle=t;self:ripple(self:onWater(p),1.8,1.8,Color3.new(1,1,1),.25)
  end
 end
 self.mist.Rate=7*self.mistLevel
 -- Ripples.
 for _,r in self.ripplePool do
  if r.active then
   local a=(t-r.at)/r.seconds
   if a>=1 then r.active=false;r.gui.Enabled=false
   else
    local e=1-(1-a)^3
    local radius=math.max(.2,r.radius*e)
    r.part.Size=Vector3.new(radius*2,.05,radius*2)
    r.part.CFrame=CFrame.new(r.position.X,self.floorY+.07,r.position.Z)
    local px=256/(radius*2)
    r.stroke.Thickness=math.max(1,.07*px);r.soft.Thickness=math.max(2,.3*px)
    local alpha=(1-a)*r.strength
    r.stroke.Transparency=1-alpha;r.soft.Transparency=1-alpha*.35
   end
  end
 end
 -- Reflections.
 local parts,frames={},{}
 for _,set in self.reflections do
  for _,pair in set do
   if pair.source.Parent then
    table.insert(parts,pair.clone);table.insert(frames,mirror(pair.source.CFrame,self.floorY))
    local lt=pair.source.LocalTransparencyModifier
    local tr=math.max(pair.source.Transparency,lt)
    if pair.clone.Transparency~=tr then pair.clone.Transparency=tr end
    if pair.clone.Color~=pair.source.Color then pair.clone.Color=pair.source.Color end
   elseif pair.clone.Transparency<1 then pair.clone.Transparency=1 end
  end
 end
 if #parts>0 then workspace:BulkMoveTo(parts,frames,Enum.BulkMoveMode.FireCFrameChanged) end
 -- Colossal stones drift.
 for _,m in self.monoliths do
  m.lift+=((m.liftTarget or 0)-m.lift)*math.min(1,dt*.8)
  local y=math.sin(t*2*math.pi/m.period+m.phase)*m.bob+m.lift
  m.part.CFrame=self.basis*CFrame.new(m.base+Vector3.new(0,y,0))*m.tilt*CFrame.Angles(0,t*m.spin,0)
 end
 -- The path of light pulses toward the god, and fades once you are there.
 local wave=(t*.28)%1.4
 for _,d in self.path do
  local pulse=math.max(0,1-math.abs(wave*24-d.index)/3)
  d.part.Transparency=1-math.clamp((.08+.3*pulse)*self.pathLevel,0,1)
 end
 -- Distant bells.
 if t>=self.nextBell then
  self.nextBell=t+7+math.random()*6
  self.audio:chime(.48+math.random()*.25,.04+math.random()*.04)
 end
end
return Realm
