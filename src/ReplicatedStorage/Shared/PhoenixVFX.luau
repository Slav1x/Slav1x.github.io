local VFX={}
local function attach(parent,name,pos)
 local a=Instance.new('Attachment');a.Name=name;a.Position=pos;a.Parent=parent;return a
end
local function emitter(parent,name,rate,size,lifetime,texture)
 local e=Instance.new('ParticleEmitter');e.Name=name;e.Texture=texture or 'rbxasset://textures/particles/fire_main.dds';e.Rate=rate
 e.Lifetime=NumberRange.new(lifetime*.7,lifetime);e.Speed=NumberRange.new(.12,.45);e.Drag=1.5
 e.SpreadAngle=Vector2.new(18,18);e.LightEmission=1;e.LightInfluence=0
 e.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,242,140)),ColorSequenceKeypoint.new(.35,Color3.fromRGB(255,168,30)),ColorSequenceKeypoint.new(1,Color3.fromRGB(238,55,7))})
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,size*.45),NumberSequenceKeypoint.new(.25,size),NumberSequenceKeypoint.new(1,0)})
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.48),NumberSequenceKeypoint.new(.2,.25),NumberSequenceKeypoint.new(1,1)})
 e.Rotation=NumberRange.new(-25,25);e.RotSpeed=NumberRange.new(-20,20);e.Parent=parent;return e
end
function VFX.add(model)
 local root=model.PrimaryPart;local body=model:FindFirstChild('Plumage');if not root or not body then return end
 local bones={};for _,v in body:GetDescendants() do if v:IsA('Bone') then bones[v.Name]=v end end
 local bodyBone=bones.Spine or bones.Body
 local tailBone=bones['Tail.02'] or bones.TailTip2
 if not bodyBone or not tailBone then error('Phoenix VFX requires body and tail bones') end
 local core=attach(bodyBone,'SolarCoreFX',Vector3.new(0,.28,-.44))
 local light=Instance.new('PointLight');light.Name='SolarLight';light.Color=Color3.fromRGB(255,189,68);light.Brightness=.6;light.Range=6;light.Shadows=false;light.Parent=core
 local aura=emitter(core,'GoldenAura',1.5,1.8,1.2,'rbxasset://textures/particles/smoke_main.dds')
 aura.Speed=NumberRange.new(0);aura.LockedToPart=true;aura.Color=ColorSequence.new(Color3.fromRGB(255,201,75));aura.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.4,.91),NumberSequenceKeypoint.new(1,1)})
 local embers=emitter(attach(bodyBone,'EmberAttachment',Vector3.new(0,.1,0)),'WarmEmbers',3,.045,1.6,'rbxasset://textures/particles/sparkles_main.dds')
 embers.Acceleration=Vector3.new(0,1.1,0);embers.SpreadAngle=Vector2.new(70,70)
 for _,side in {'L','R'} do
  local sign=if side=='L' then -1 else 1
  local wingBone=bones['WingTip.'..side] or bones['Wrist_'..side]
  if not wingBone then error('Phoenix VFX missing wing bone '..side) end
  local w=attach(wingBone,'WingFire_'..side,Vector3.new(sign*.42,.35,0))
  local e=emitter(w,'WingGlints',2,.20,.60);e.LockedToPart=true
 end
 local tail=attach(tailBone,'TailFire',Vector3.new(0,-.52,.01))
 local fire=emitter(tail,'TailFlameTrail',4,.30,.65);fire.Acceleration=Vector3.new(0,.45,0)
 local sparks=emitter(tail,'MotionSparks',0,.065,.80,'rbxasset://textures/particles/sparkles_main.dds');sparks.Speed=NumberRange.new(.35,.9)
 for n=0,2 do
  local a=attach(root,'OrbitFlame'..n,Vector3.new(1.1*math.cos(n*2*math.pi/3),.5,.6*math.sin(n*2*math.pi/3)));a:SetAttribute('OrbitIndex',n)
  local e=emitter(a,'OrbitFire',5,.23,.65);e.LockedToPart=true;e.Speed=NumberRange.new(0,.08)
 end
end
return VFX

