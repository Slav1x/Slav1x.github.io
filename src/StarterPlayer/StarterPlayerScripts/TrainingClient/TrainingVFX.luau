-- Client-only, reusable effects. This module never awards or requests training.
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local VFX = {}
VFX.__index = VFX
local TAU = math.pi * 2
local CYAN = Color3.fromRGB(45, 220, 255)
local BLUE = Color3.fromRGB(58, 108, 255)
local ICE = Color3.fromRGB(202, 249, 255)
local transparency = {}
for i = 0, 40 do transparency[i] = NumberSequence.new(i / 40) end
local function ns(n) return transparency[math.clamp(math.floor(n * 40 + .5), 0, 40)] end
local function make(class, parent, props)
 local o = Instance.new(class)
 for k,v in props do o[k] = v end
 o.Parent = parent
 return o
end
local function anchor(parent, name)
 return make("Part", parent, {Name=name,Size=Vector3.one*.05,Transparency=1,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false})
end
local function ring(parent, name, color, width, broken)
 local root = anchor(parent, name)
 local entries = {}
 for i=0,3 do
  local from = i * math.pi/2 + (broken and .12 or 0)
  local to = (i+1) * math.pi/2 - (broken and .12 or 0)
  local a = make("Attachment",root,{})
  local b = make("Attachment",root,{})
  local beam = make("Beam",root,{Attachment0=a,Attachment1=b,Color=ColorSequence.new(color),Width0=width,Width1=width,Segments=10,FaceCamera=true,LightEmission=1,LightInfluence=0,Transparency=ns(1)})
  table.insert(entries,{a=a,b=b,beam=beam,from=from,to=to,curve=4/3*math.tan((to-from)/4)})
 end
 return {root=root,entries=entries,width=width}
end
local function drawRing(r,cf,radius,opacity)
 r.root.CFrame=cf
 for _,e in r.entries do
  local a,b=e.from,e.to
  e.a.CFrame=CFrame.fromMatrix(Vector3.new(math.cos(a)*radius,0,math.sin(a)*radius),Vector3.new(-math.sin(a),0,math.cos(a)),Vector3.yAxis)
  e.b.CFrame=CFrame.fromMatrix(Vector3.new(math.cos(b)*radius,0,math.sin(b)*radius),Vector3.new(-math.sin(b),0,math.cos(b)),Vector3.yAxis)
  e.beam.CurveSize0=radius*e.curve;e.beam.CurveSize1=radius*e.curve
  e.beam.Transparency=ns(1-opacity);e.beam.Enabled=opacity>.015
 end
end
function VFX.new(parent,character,root,scale,rockSize)
 local folder=make("Folder",parent,{Name="SpinEnergy"})
 local core=anchor(folder,"PalmResonance")
 local light=make("PointLight",core,{Name="PalmLight",Color=CYAN,Range=7*scale,Brightness=0,Shadows=false})
 local sparks=make("ParticleEmitter",core,{Name="RewardSparks",Texture="rbxasset://textures/particles/sparkles_main.dds",Rate=0,Lifetime=NumberRange.new(.3,.65),Speed=NumberRange.new(1.4,3.5),Drag=3,SpreadAngle=Vector2.new(180,180),LightEmission=1,LightInfluence=0,Color=ColorSequence.new(ICE,CYAN),Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.07*scale),NumberSequenceKeypoint.new(.3,.12*scale),NumberSequenceKeypoint.new(1,0)}),Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(1,1)})})
 local motes=make("ParticleEmitter",core,{Name="IonMotes",Texture="rbxasset://textures/particles/sparkles_main.dds",Rate=0,Lifetime=NumberRange.new(.5,1),Speed=NumberRange.new(.25,.9),Acceleration=Vector3.new(0,1.2,0),SpreadAngle=Vector2.new(140,140),LightEmission=1,LightInfluence=0,Color=ColorSequence.new(CYAN,ICE),Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.25,.065*scale),NumberSequenceKeypoint.new(1,0)})})
 local self=setmetatable({folder=folder,core=core,root=root,scale=scale,rockSize=rockSize,light=light,sparks=sparks,motes=motes,age=0,rewardAge=10,charge=0,afk=0,ticks={},satellites={},ribbons={},groundY=nil,groundCheck=0},VFX)
 self.palmRing=ring(folder,"GyroscopicHalo",CYAN,.035*scale,true)
 self.crossRing=ring(folder,"CrossingHalo",BLUE,.025*scale,true)
 self.floorRing=ring(folder,"FocusSeal",CYAN,.045*scale,true)
 self.floorInner=ring(folder,"CounterSeal",BLUE,.028*scale,true)
 self.wave=ring(folder,"RewardWave",ICE,.055*scale,false)
 self.ray=RaycastParams.new();self.ray.FilterType=Enum.RaycastFilterType.Exclude;self.ray.FilterDescendantsInstances={character,parent};self.ray.IgnoreWater=false
 for i=1,12 do
  local p=anchor(folder,"SealMark");p.Material=Enum.Material.Neon;p.Color=i%3==0 and ICE or CYAN
  p.Size=Vector3.new(.04,.025,i%3==0 and .32 or .15)*scale
  table.insert(self.ticks,p)
 end
 for i=1,5 do
  local p=make("WedgePart",folder,{Name="OrbitFragment",Size=Vector3.new(.16,.24,.17)*scale,Material=Enum.Material.Slate,Color=Color3.fromRGB(30,73,108),Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false,Transparency=1})
  local a=make("Attachment",p,{Position=Vector3.new(0,.055*scale,0)})
  local b=make("Attachment",p,{Position=Vector3.new(0,-.055*scale,0)})
  local trail=make("Trail",p,{Attachment0=a,Attachment1=b,Lifetime=.22,MinLength=.015,FaceCamera=true,LightEmission=1,Color=ColorSequence.new(CYAN,BLUE),Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.25),NumberSequenceKeypoint.new(1,1)}),WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)}),Enabled=false})
  table.insert(self.satellites,{part=p,trail=trail})
 end
 for i=1,3 do
  local p=anchor(folder,"SpiralWind")
  local a=make("Attachment",p,{Position=Vector3.new(0,.07*scale,0)})
  local b=make("Attachment",p,{Position=Vector3.new(0,-.07*scale,0)})
  local trail=make("Trail",p,{Attachment0=a,Attachment1=b,Lifetime=.45,MinLength=.02,FaceCamera=true,LightEmission=1,LightInfluence=0,Color=ColorSequence.new(i==2 and BLUE or CYAN,ICE),Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.35),NumberSequenceKeypoint.new(.5,.65),NumberSequenceKeypoint.new(1,1)}),WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,.2),NumberSequenceKeypoint.new(.3,1),NumberSequenceKeypoint.new(1,0)}),Enabled=false})
  table.insert(self.ribbons,{part=p,trail=trail})
 end
 return self
end
function VFX:reward()
 self.rewardAge=0;self.emit=true
end
function VFX:step(dt,active,afk,reduced)
 self.age+=dt;self.rewardAge+=dt;self.groundCheck-=dt
 self.charge+=((active and 1 or 0)-self.charge)*(1-math.exp(-dt*2.4))
 self.afk+=((afk and active and 1 or 0)-self.afk)*(1-math.exp(-dt*4))
 self.reduced=reduced
 self.low=localPlayer:GetAttribute("GraphicsQualityPreset")=="LOW"
 if self.groundCheck<=0 then
  self.groundCheck=.4
  local hit=workspace:Raycast(self.root.Position,Vector3.new(0,-12*self.scale,0),self.ray)
  self.groundY=hit and hit.Position.Y+.045 or nil
 end
end
function VFX:render(frame,alpha)
 if not self.folder.Parent then return end
 local s=self.scale
 local strength=alpha*self.charge
 local afk=self.afk*alpha
 local motion=self.reduced and .22 or 1
 local t=self.age*motion
 local pulse=math.exp(-self.rewardAge*5)
 local radius=math.max(self.rockSize.X,self.rockSize.Z)*.69
 local position=frame.Position
 self.core.CFrame=CFrame.new(position)
 self.light.Brightness=self.low and 0 or strength*(.5+pulse*.7)
 self.motes.Rate=strength*(self.low and 2 or 6)
 drawRing(self.palmRing,CFrame.new(position)*CFrame.Angles(.18*math.sin(t),t*.8,.17),radius*(1+pulse*.12),strength*.76)
 drawRing(self.crossRing,CFrame.new(position)*CFrame.Angles(.7,-t*.5,-.3),radius*1.13,strength*.5)
 for i,e in self.satellites do
  local enabled=not self.low or i<=2
  local phase=t*2.4+i*TAU/5
  local r=radius*(1.45+.08*math.sin(t+i))
  e.part.CFrame=CFrame.new(position+Vector3.new(math.cos(phase)*r,math.sin(phase*1.7+i)*.27*s,math.sin(phase)*r))*CFrame.Angles(t*.8+i,t*1.4,i)
  e.part.Transparency=enabled and 1-strength*.95 or 1
  e.trail.Enabled=enabled and strength>.3 and not self.reduced
 end
 local ground=self.groundY
 local base=Vector3.new(self.root.Position.X,ground or self.root.Position.Y-3*s,self.root.Position.Z)
 local floorAlpha=ground and afk or 0
 drawRing(self.floorRing,CFrame.new(base)*CFrame.Angles(0,t*.24,0),2.35*s,floorAlpha*.62)
 drawRing(self.floorInner,CFrame.new(base+Vector3.new(0,.014,0))*CFrame.Angles(0,-t*.32,0),1.88*s,floorAlpha*.42)
 for i,p in self.ticks do
  local a=i*TAU/12+t*.24
  p.CFrame=CFrame.new(base+Vector3.new(math.cos(a)*2.55*s,.015,math.sin(a)*2.55*s))*CFrame.Angles(0,-a+math.pi/2,0)
  p.Transparency=1-floorAlpha*.65
 end
 for i,e in self.ribbons do
  local phase=t*2+i*TAU/3
  local y=(t*.32+i/3)%1
  local center=base:Lerp(position,y*.72)
  local r=(2.2-y*.85)*s
  e.part.CFrame=CFrame.new(center+Vector3.new(math.cos(phase)*r,(.15+y*1.15)*s,math.sin(phase)*r))
  e.trail.Enabled=afk>.4 and not self.reduced and (not self.low or i==1)
 end
 local age=math.clamp(self.rewardAge/.8,0,1)
 local waveAlpha=(1-age)^2*strength*(self.reduced and .12 or .55)
 drawRing(self.wave,CFrame.new(position)*CFrame.Angles(.2,0,0),radius*(1+age*1.8),waveAlpha)
 if self.emit then
  self.emit=false
  self.sparks:Emit(self.reduced and 2 or self.low and 4 or 10)
 end
end
function VFX:destroy()
 self.folder:Destroy()
end
return VFX