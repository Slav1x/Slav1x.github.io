local G={}
local Tween=game:GetService("TweenService")
G.Tiers={
 Common={cracks=1,color=Color3.fromRGB(245,250,255)},
 Uncommon={cracks=1,color=Color3.fromRGB(90,240,130)},
 Rare={cracks=1,color=Color3.fromRGB(65,160,255)},
 Epic={cracks=1,color=Color3.fromRGB(190,100,255)},
 Legendary={cracks=1,color=Color3.fromRGB(255,198,45)},
 Mythical={cracks=1,color=Color3.fromRGB(245,80,225)},
}
G.TotalCracks=6
-- Shared shell treatment, calibrated for world and ViewportFrame lighting.
G.ShellVisual={
 Material=Enum.Material.Slate,
 WorldColor=Color3.fromRGB(60,48,38),
 IconColor=Color3.fromRGB(120,109,98),
 -- The orange crack card needs a warmer tint to read like the same shell.
 SealIconColor=Color3.fromRGB(137,102,78),
 IconAmbient=Color3.fromRGB(94,90,86),
 IconLightColor=Color3.fromRGB(205,190,175),
}
function G.settings(rarity) return G.Tiers[rarity] or G.Tiers.Common end
local function part(model,name,size,cf,color,material,class)
 local p=Instance.new(class or "Part");p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color;p.Material=material
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Parent=model;return p
end
local function crackColor(color)
 return ColorSequence.new(color:Lerp(Color3.new(1,1,1),.6),color)
end
local function addFractureLights(core,color)
 -- Light originates at the seams and fades a short distance outside the shell.
 local directions={
  Vector3.new(1,1,0),Vector3.new(1,-1,0),Vector3.new(-1,1,0),Vector3.new(-1,-1,0),
  Vector3.new(1,0,1),Vector3.new(1,0,-1),Vector3.new(-1,0,1),Vector3.new(-1,0,-1),
  Vector3.new(0,1,1),Vector3.new(0,1,-1),Vector3.new(0,-1,1),Vector3.new(0,-1,-1),
 }
 for i,v in directions do
  local direction=v.Unit
  local origin=Instance.new("Attachment")
  origin.Name="FractureOrigin";origin.CFrame=CFrame.lookAt(direction*1.3,direction*2.3)
  origin:SetAttribute("Direction",direction);origin:SetAttribute("Index",i);origin.Parent=core
  local tip=Instance.new("Attachment")
  tip.Name="FractureTip";tip.Position=direction*2.1;tip.Parent=core
  local shaft=Instance.new("Beam")
  shaft.Name="FractureLight";shaft.Attachment0=origin;shaft.Attachment1=tip
  shaft.FaceCamera=true;shaft.Segments=1;shaft.LightEmission=1;shaft.LightInfluence=0
  shaft.Color=crackColor(color);shaft.Width0=.12;shaft.Width1=.015
  shaft.Transparency=NumberSequence.new(1);shaft.Enabled=false;shaft.Parent=origin
  local glow=Instance.new("ParticleEmitter")
  glow.Name="FractureMotes";glow.Texture="rbxasset://textures/particles/smoke_main.dds"
  glow.Color=crackColor(color);glow.LightEmission=1;glow.LightInfluence=0
  glow.EmissionDirection=Enum.NormalId.Front;glow.SpreadAngle=Vector2.new(12,12)
  glow.Lifetime=NumberRange.new(.2,.45);glow.Speed=NumberRange.new(.6,1.4)
  glow.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.08),NumberSequenceKeypoint.new(.3,.23),NumberSequenceKeypoint.new(1,0)})
  glow.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.35),NumberSequenceKeypoint.new(.25,.15),NumberSequenceKeypoint.new(1,1)})
  glow.Rate=0;glow.Parent=origin
  if i==1 or i==6 or i==9 then
   local spill=Instance.new("PointLight");spill.Name="CrackSpill";spill.Color=color
   spill.Range=5;spill.Brightness=0;spill.Shadows=false;spill.Parent=origin
  end
 end
end
local function addBranchCracks(piece,color,index)
 if not piece:GetAttribute("BranchCrack") then return end
 local rest=piece:GetAttribute("Rest")
 local direction=piece:GetAttribute("Direction")
 local tangent=direction:Cross(Vector3.yAxis)
 if tangent.Magnitude<.01 then tangent=direction:Cross(Vector3.xAxis) end
 tangent=tangent.Unit
 local up=direction:Cross(tangent).Unit
 local function project(v)
  local d=v.Unit
  return Vector3.new(d.X*1.595,d.Y*1.725,d.Z*1.545)
 end
 local function segment(a,b,threshold)
  local first=Instance.new("Attachment");first.Name="CrackNode";first.Position=rest:PointToObjectSpace(project(a));first.Parent=piece
  local last=Instance.new("Attachment");last.Name="CrackNode";last.Position=rest:PointToObjectSpace(project(b));last.Parent=piece
  local line=Instance.new("Beam");line.Name="BranchFracture"
  line.Attachment0=first;line.Attachment1=last;line.FaceCamera=true;line.Segments=1
  line.LightEmission=1;line.LightInfluence=0;line.Color=crackColor(color)
  line.Width0=.012;line.Width1=.008;line.Enabled=false;line.Transparency=NumberSequence.new(.1)
  line:SetAttribute("Threshold",threshold);line.Parent=piece
 end
 local points={}
 for i=0,5 do
  points[i+1]=direction+tangent*((i-2.5)*.11)+up*(math.sin(i*2.4+index)*.055)
  if i>0 then segment(points[i],points[i+1],.06+(i-1)*.095+(index%3)*.025) end
 end
 local fork=points[3]
 local elbow=fork+up*.16-tangent*.06
 segment(fork,elbow,.32)
 segment(elbow,elbow+up*.16+tangent*.06,.52)
end
function G.create(cf,rarity,parent)
 local spec=G.settings(rarity)
 local m=Instance.new("Model");m.Name="SummonedGeode"
 local core=part(m,"CrystalHeart",Vector3.one*2.2,cf,spec.color,Enum.Material.Neon)
 core.Shape=Enum.PartType.Ball;core.Transparency=1;m.PrimaryPart=core
 local light=Instance.new("PointLight");light.Name="InnerGlow";light.Color=spec.color;light.Range=14;light.Brightness=0;light.Parent=core
 addFractureLights(core,spec.color)
 -- Inner embers support the brighter light at the fracture mouths.
 for i=1,8 do
  local angle=i*math.pi/4
  local at=Instance.new("Attachment");at.Name="InnerEmbers";at.Position=Vector3.new(math.cos(angle)*1.1,math.sin(angle*2)*.35,math.sin(angle)*1.1);at.Parent=core
  local dust=Instance.new("ParticleEmitter");dust.Name="InnerSparks";dust.Texture="rbxasset://textures/particles/sparkles_main.dds"
  dust.Color=ColorSequence.new(spec.color);dust.LightEmission=1;dust.LightInfluence=0
  dust.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.07),NumberSequenceKeypoint.new(1,0)})
  dust.Transparency=NumberSequence.new(.2,1);dust.Lifetime=NumberRange.new(.4,.9);dust.Speed=NumberRange.new(.4,1.5)
  dust.SpreadAngle=Vector2.new(360,360);dust.Rate=0;dust.Parent=at
 end
 local shell=Instance.new("Folder");shell.Name="Shell";shell.Parent=m
 -- Curved hollow shell sections are built once in Studio, then cheaply cloned.
 local template=game.ReplicatedStorage:WaitForChild("GeodeShellTemplate")
 for index,source in template:GetChildren() do
  if source:IsA("BasePart") then
   local p=source:Clone()
   p.Color=G.ShellVisual.WorldColor
   p.Material=G.ShellVisual.Material
   if p:IsA("PartOperation") then p.UsePartColor=true end
   p.CFrame=cf*p:GetAttribute("Rest")
   p.Parent=shell
   addBranchCracks(p,spec.color,index)
  end
 end
 local crystals=Instance.new("Folder");crystals.Name="Crystals";crystals.Parent=m
 for i=1,12 do
  local a=i*math.pi/6
  local p=part(crystals,"Crystal",Vector3.new(.28,.65,.3),cf*CFrame.new(math.cos(a)*.8,math.sin(a*2)*.6,math.sin(a)*.8)*CFrame.Angles(a,0,.4),spec.color,Enum.Material.Neon,"WedgePart")
  p.Transparency=1
 end
 m.Parent=parent or workspace;return m
end
function G.crack(m,hits,required)
 local progress=math.clamp(.12+hits/required*.88,0,1)
 local cf=m:GetPivot()
 m.CrystalHeart.Transparency=.45-progress*.4
 m.CrystalHeart.Size=Vector3.one*(2.2+progress*.7)
 local glow=m.CrystalHeart.InnerGlow
 local resting=.3+progress*progress*2.4
 glow.Brightness=hits>0 and resting+1.8 or resting
 glow.Range=8+progress*6
 Tween:Create(glow,TweenInfo.new(.24,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Brightness=resting}):Play()
 for _,origin in m.CrystalHeart:GetChildren() do
  if origin:IsA("Attachment") and origin.Name=="FractureOrigin" then
   local i=origin:GetAttribute("Index")
   local openness=hits==0 and 0 or math.clamp((progress-((i*7)%5)*.045)/.8,0,1)
   local direction=origin:GetAttribute("Direction")
   local shaft=origin.FractureLight
   origin.CFrame=CFrame.lookAt(direction*(1.28+openness*.28),direction*3)
   shaft.Attachment1.Position=direction*(1.65+openness*(.7+(i%3)*.18))
   shaft.Enabled=openness>0
   shaft.Width0=.07+openness*.21;shaft.Width1=.008
   shaft.Transparency=NumberSequence.new({
    NumberSequenceKeypoint.new(0,1-openness*.82),
    NumberSequenceKeypoint.new(.25,1-openness*.52),
    NumberSequenceKeypoint.new(.65,1-openness*.18),
    NumberSequenceKeypoint.new(1,1),
   })
   origin.FractureMotes.Rate=openness*1.5
   if hits>0 then origin.FractureMotes:Emit(2) end
  end
 end
 for _,p in m.Shell:GetChildren() do
  local localCF=p:GetAttribute("Rest")
  local direction=p:GetAttribute("Direction")
  local opened=hits==0 and 0 or math.clamp((progress-.12-p:GetAttribute("FractureOrder")*.15)/.85,0,1)
  -- Uneven separation exposes increasingly wide, deep luminous fractures.
  local target=cf*CFrame.new(direction*(opened*.3))*localCF
  p.Size=p:GetAttribute("RestSize")
  p.CFrame=target -- The server animates the whole shell kick immediately afterward.
  for _,effect in p:GetChildren() do
   if effect:IsA("Beam") and effect.Name=="BranchFracture" then
    local spread=math.clamp((hits/math.max(1,required)-effect:GetAttribute("Threshold"))/.18,0,1)
    effect.Enabled=spread>0
    effect.Width0=.012+spread*.03;effect.Width1=.008+spread*.017
    effect.Transparency=NumberSequence.new(.7-spread*.6)
   end
  end
 end
 for _,p in m.Crystals:GetChildren() do p.Transparency=1-progress end
 for _,dust in m.CrystalHeart:GetDescendants() do
  if dust:IsA("ParticleEmitter") and dust.Name=="InnerSparks" then dust.Rate=hits==0 and 0 or .5+progress end
 end
 for _,light in m.CrystalHeart:GetDescendants() do
  if light:IsA("PointLight") and light.Name=="CrackSpill" then
   local resting=hits==0 and 0 or .15+progress*.8
   light.Brightness=hits>0 and resting+.8 or 0
   Tween:Create(light,TweenInfo.new(.28),{Brightness=resting}):Play()
  end
 end
 m:SetAttribute("Cracks",hits);m:SetAttribute("RequiredCracks",required)
end
function G.recolor(m,rarity,duration)
 local color=G.settings(rarity).color
 local tweenInfo=TweenInfo.new(duration or .8,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
 Tween:Create(m.CrystalHeart,tweenInfo,{Color=color}):Play()
 Tween:Create(m.CrystalHeart.InnerGlow,tweenInfo,{Color=color}):Play()
 for _,light in m.CrystalHeart:GetDescendants() do
  if light:IsA("PointLight") and light.Name=="CrackSpill" then
   light.Color=color
   Tween:Create(light,tweenInfo,{Brightness=.9}):Play()
  end
 end
 for _,effect in m.CrystalHeart:GetDescendants() do
  if effect:IsA("ParticleEmitter") then effect.Color=crackColor(color);effect:Emit(3)
  elseif effect:IsA("Beam") then effect.Color=crackColor(color) end
 end
 for _,crystal in m.Crystals:GetChildren() do Tween:Create(crystal,tweenInfo,{Color=color}):Play() end
 for _,effect in m.Shell:GetDescendants() do
  if effect:IsA("Beam") then effect.Color=crackColor(color) end
 end
 m:SetAttribute("CurrentTier",rarity)
end
function G.shatter(m,rarity,tier)
 local center=m:GetPivot().Position
 -- Legendary and above throw the shell much farther and faster at the reveal.
 local impact=(tier and tier>=5) and math.min(3.2,2+(tier-5)*.55) or 1
 for i,p in m.Shell:GetChildren() do
  local d=(p.Position-center).Unit
  for _,effect in p:GetDescendants() do if effect:IsA("Beam") then effect.Enabled=false end end
  local travel=(2.6+(i%5)*.32)*impact
  local spin=1+(impact-1)*.25
  local tumble=CFrame.Angles((i%3-1)*1.1*spin,(i%5-2)*.65*spin,(i%4-1.5)*.8*spin)
  local flight=impact>1 and .48+(i%3)*.04 or .65+(i%3)*.08
  Tween:Create(p,TweenInfo.new(flight,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
   CFrame=(p.CFrame+d*travel+Vector3.new(0,(.5+(i%4)*.24)*impact,0))*tumble,
   Transparency=1}):Play()
 end
 m.CrystalHeart.Transparency=1;m.CrystalHeart.InnerGlow.Enabled=false
 for _,light in m.CrystalHeart:GetDescendants() do if light:IsA("PointLight") or light:IsA("ParticleEmitter") or light:IsA("Beam") then light.Enabled=false end end
 for _,p in m.Crystals:GetChildren() do
  Tween:Create(p,TweenInfo.new(impact>1 and .55 or .7),{Transparency=1,Position=p.Position+(p.Position-center).Unit*3*impact}):Play()
 end
 game:GetService("Debris"):AddItem(m,1)
end
return G