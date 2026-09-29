-- The inner world: a private, client-only space far above the player where a holographic
-- echo of their body shows the meridian map. Built in world space (not a ViewportFrame)
-- so neon, bloom, lights and particles render at full quality.
-- Node positions and unlock order come from AwakeningConfig.Nodes, so later awakenings
-- light more of the map without changes here.
local Config=require(game.ReplicatedStorage.Shared.AwakeningConfig)
local VFX=require(script.Parent.AwakeningVFX)
local smooth,make,part,seq=VFX.smooth,VFX.make,VFX.part,VFX.seq
local M={}
local VOID=Color3.fromRGB(3,8,21)
local SHELL=Color3.fromRGB(48,86,124)
local CHANNEL=Color3.fromRGB(64,70,82)
local HEIGHT=1200
function M.create(parent,folder,character,count)
 local root=character:FindFirstChild("HumanoidRootPart")
 local space=CFrame.new(root.Position+Vector3.new(0,HEIGHT,0))
 local self={nodes={},channels={},halos={},spin=0,last=nil}
 local model=make("Model",folder,{Name="InnerWorld"})
 local target,newNode=Config.stage(count);self.target=target
 local center=target.at+Vector3.new(0,0,-.14)
 local function at(v) return space*CFrame.new(v) end
 ---------------------------------------------------------------- the space itself
 -- Dark neon shell: unaffected by the time of day and never blooms.
 for _,w in {{Vector3.new(0,0,32),Vector3.new(80,60,1)},{Vector3.new(0,0,-32),Vector3.new(80,60,1)},{Vector3.new(40,0,0),Vector3.new(1,60,64)},{Vector3.new(-40,0,0),Vector3.new(1,60,64)},{Vector3.new(0,30,0),Vector3.new(80,1,64)},{Vector3.new(0,-30,0),Vector3.new(80,1,64)}} do
  local wall=part(model,"Void",w[2],at(w[1]),VOID,0);wall.CastShadow=true
 end
 -- Soft nebulae behind the body give depth without competing with the meridians.
 local nebulae={}
 for _,n in {{Vector3.new(0,.6,16),26,Color3.fromRGB(14,40,88),.55},{Vector3.new(-9,5,22),24,Color3.fromRGB(32,22,78),.68},{Vector3.new(10,-4,20),22,Color3.fromRGB(10,52,92),.7}} do
  table.insert(nebulae,{part=part(model,"Nebula",Vector3.one*n[2],at(n[1]),n[3],n[4],Enum.PartType.Ball),base=n[4]})
 end
 local dust=part(model,"DustVolume",Vector3.new(16,11,10),at(Vector3.new(0,0,2)),VOID,1)
 make("ParticleEmitter",dust,{Name="Dust",Texture=VFX.Sparkle,Rate=14,Shape=Enum.ParticleEmitterShape.Box,ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume,
  Lifetime=NumberRange.new(3,6),Speed=NumberRange.new(.05,.25),SpreadAngle=Vector2.new(180,180),LightEmission=1,LightInfluence=0,
  Color=ColorSequence.new(Config.Ice,Config.Blue),Size=seq(0,0,.5,.05,1,0),Transparency=seq(0,1,.5,.45,1,1)})
 ---------------------------------------------------------------- holographic body
 local slots={
  Head={Vector3.new(0,2.25,0),Vector3.new(1.4,1.2,1.1)},
  Torso={Vector3.new(0,.55,.1),Vector3.new(2,2,1)},
  UpperTorso={Vector3.new(0,.85,.1),Vector3.new(2,1.4,1)},
  LowerTorso={Vector3.new(0,-.3,.1),Vector3.new(1.5,.8,.9)},
  ["Left Arm"]={Vector3.new(-1.6,.3,.1),Vector3.new(.8,2.3,.8)},
  ["Right Arm"]={Vector3.new(1.6,.3,.1),Vector3.new(.8,2.3,.8)},
  LeftUpperArm={Vector3.new(-1.5,.65,.1),Vector3.new(.75,1.15,.75)},
  RightUpperArm={Vector3.new(1.5,.65,.1),Vector3.new(.75,1.15,.75)},
  LeftLowerArm={Vector3.new(-1.65,-.35,.1),Vector3.new(.65,.95,.65)},
  RightLowerArm={Vector3.new(1.65,-.35,.1),Vector3.new(.65,.95,.65)},
  LeftHand={Vector3.new(-1.65,-1,.1),Vector3.new(.65,.45,.65)},
  RightHand={Vector3.new(1.65,-1,.1),Vector3.new(.65,.45,.65)},
  ["Left Leg"]={Vector3.new(-.55,-1.65,.1),Vector3.new(.85,2.25,.85)},
  ["Right Leg"]={Vector3.new(.55,-1.65,.1),Vector3.new(.85,2.25,.85)},
  LeftUpperLeg={Vector3.new(-.5,-1.15,.1),Vector3.new(.8,1.1,.85)},
  RightUpperLeg={Vector3.new(.5,-1.15,.1),Vector3.new(.8,1.1,.85)},
  LeftLowerLeg={Vector3.new(-.5,-2.15,.1),Vector3.new(.65,1,.7)},
  RightLowerLeg={Vector3.new(.5,-2.15,.1),Vector3.new(.65,1,.7)},
  LeftFoot={Vector3.new(-.5,-2.75,-.1),Vector3.new(.7,.4,1)},
  RightFoot={Vector3.new(.5,-2.75,-.1),Vector3.new(.7,.4,1)},
 }
 local shells={}
 for name,slot in slots do
  local original=character:FindFirstChild(name)
  if original and original:IsA("BasePart") then
   local echo=original:Clone()
   if not echo then continue end
   for _,v in echo:GetDescendants() do
    if not v:IsA("DataModelMesh") then v:Destroy() elseif v:IsA("SpecialMesh") then v.TextureId="" end
   end
   if echo:IsA("MeshPart") then echo.TextureID="" end
   -- ForceField material renders as a shimmering, see-through hologram.
   echo.Name="Echo_"..name;echo.Size=slot[2];echo.CFrame=at(slot[1]);echo.Color=SHELL
   echo.Material=Enum.Material.ForceField;echo.Transparency=0;echo.Anchored=true
   echo.CanCollide=false;echo.CanTouch=false;echo.CanQuery=false;echo.CastShadow=false;echo.Parent=model
   table.insert(shells,echo)
  end
 end
 ---------------------------------------------------------------- channels
 local function path(points)
  for i=1,#points-1 do
   local a=Vector3.new(points[i][1],points[i][2],-.62);local b=Vector3.new(points[i+1][1],points[i+1][2],-.62)
   local seg=part(model,"MeridianChannel",Vector3.new(.034,.034,(a-b).Magnitude),space*CFrame.lookAt((a+b)*.5,b),CHANNEL,.2)
   table.insert(self.channels,{part=seg,distance=(((a+b)*.5)-center).Magnitude})
  end
 end
 path({{0,2.9},{0,2.35},{0,1.55},{0,.65},{0,-.8}})
 for _,side in {-1,1} do
  path({{0,1.25},{side*.65,1.05},{side*1.45,.82},{side*1.55,.4},{side*1.67,-.5},{side*1.65,-1}})
  path({{0,.65},{side*.65,.38},{side*.78,-.15},{0,-.8},{side*.48,-1.3},{side*.52,-2.15},{side*.52,-2.7}})
  path({{side*.48,-1.3},{side*.8,-1.75},{side*.52,-2.15}})
 end
 ---------------------------------------------------------------- nodes
 for _,node in Config.Nodes do
  local unlocked=node.unlock<count
  local isTarget=node.id==target.id
  local core=part(model,node.id,Vector3.one*(isTarget and .24 or .15),at(node.at+Vector3.new(0,0,-.13)),unlocked and Config.Blue or CHANNEL,0,Enum.PartType.Ball)
  self.nodes[node.id]=core
  if unlocked and not isTarget then
   part(model,"AwakenedHalo",Vector3.one*.42,core.CFrame,Config.Blue,.8,Enum.PartType.Ball)
  elseif not isTarget then
   -- Dormant points keep a faint rim so the player can see there is more to unlock.
   part(model,"DormantRim",Vector3.one*.24,core.CFrame,CHANNEL,.82,Enum.PartType.Ball)
  end
 end
 self.core=self.nodes[target.id]
 local coreCF=at(center)
 for i=1,3 do table.insert(self.halos,part(model,"HeartHalo",Vector3.one*(.4+i*.3),coreCF,Config.Blue,1,Enum.PartType.Ball)) end
 local light=make("PointLight",self.core,{Name="HeartLight",Color=Config.Blue,Range=7,Brightness=0,Shadows=false})
 local gyroA=VFX.ring(model,"Gyro",36,CHANNEL,.028,.5,coreCF)
 local gyroB=VFX.ring(model,"Gyro",36,CHANNEL,.022,.6,coreCF)
 local wave=VFX.ring(model,"ActivationWave",56,Config.Ice,.06,1,coreCF)
 local flareGui=make("BillboardGui",self.core,{Name="HeartFlare",Size=UDim2.fromScale(1,1),LightInfluence=0,Brightness=2,AlwaysOnTop=false})
 local flare=make("ImageLabel",flareGui,{Image=VFX.Sparkle,ImageColor3=Config.Ice,ImageTransparency=1,BackgroundTransparency=1,Size=UDim2.fromScale(1,1)})
 local gather=part(model,"GatherShell",Vector3.one*3.2,coreCF,Config.Blue,1,Enum.PartType.Ball)
 local inward=make("ParticleEmitter",gather,{Name="InwardLight",Texture=VFX.Sparkle,Rate=0,Shape=Enum.ParticleEmitterShape.Sphere,ShapeInOut=Enum.ParticleEmitterShapeInOut.Inward,ShapeStyle=Enum.ParticleEmitterShapeStyle.Surface,
  Lifetime=NumberRange.new(.9,1),Speed=NumberRange.new(1.5,1.7),LightEmission=1,LightInfluence=0,Color=ColorSequence.new(Config.Blue,Config.Ice),Size=seq(0,.03,.7,.09,1,0),Transparency=seq(0,1,.25,.1,1,.4)})
 local burst=make("ParticleEmitter",self.core,{Name="ActivationBurst",Texture=VFX.Sparkle,Rate=0,Shape=Enum.ParticleEmitterShape.Sphere,ShapeInOut=Enum.ParticleEmitterShapeInOut.Outward,
  Lifetime=NumberRange.new(.6,1.3),Speed=NumberRange.new(3,8),Drag=3.5,LightEmission=1,LightInfluence=0,Color=ColorSequence.new(Config.Ice,Config.Blue),Size=seq(0,.16,1,0),Transparency=seq(0,0,1,1)})
 ---------------------------------------------------------------- titles
 local frame=make("Frame",parent,{Name="InnerWorld",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=16,Visible=false})
 local function text(name,words,size,color,font)
  local t=make("TextLabel",frame,{Name=name,Text=words,TextColor3=color,BackgroundTransparency=1,TextSize=size,Font=font or Enum.Font.GothamMedium,TextScaled=true,TextTransparency=1,ZIndex=16})
  make("UITextSizeConstraint",t,{MaxTextSize=size,MinTextSize=10})
  return t
 end
 local chapter=text("Chapter",count==1 and "I  ·  THE FIRST AWAKENING" or "AWAKENING  ·  "..count,13,Color3.fromRGB(129,168,200))
 self.title=text("MeridianName",string.upper(target.name),30,Config.Ice,Enum.Font.GothamBold)
 self.title.TextStrokeColor3=Config.Blue;self.title.TextStrokeTransparency=1
 local rule=make("Frame",frame,{Name="Rule",BorderSizePixel=0,BackgroundColor3=Config.Blue,BackgroundTransparency=1,ZIndex=16})
 make("UIGradient",rule,{Transparency=seq(0,1,.3,0,.7,0,1,1)})
 self.caption=text("State","Dormant · waiting for your touch",15,Color3.fromRGB(149,178,204))
 local hint=text("Hint","A beginning. The other paths are still quiet.",12,Color3.fromRGB(95,122,150))
 local items={chapter,self.title,self.caption,hint}
 local function layout(view)
  local portrait=view.X<view.Y*1.15
  local align=portrait and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
  for _,t in items do t.TextXAlignment=align end
  if portrait then
   chapter.Position=UDim2.fromScale(.06,.115);chapter.Size=UDim2.fromScale(.88,.035)
   self.title.Position=UDim2.fromScale(.06,.15);self.title.Size=UDim2.fromScale(.88,.05)
   rule.Position=UDim2.fromScale(.3,.205);rule.Size=UDim2.new(.4,0,0,1)
   self.caption.Position=UDim2.fromScale(.06,.79);self.caption.Size=UDim2.fromScale(.88,.04)
   hint.Position=UDim2.fromScale(.06,.835);hint.Size=UDim2.fromScale(.88,.03)
  else
   chapter.Position=UDim2.fromScale(.065,.36);chapter.Size=UDim2.fromScale(.3,.035)
   self.title.Position=UDim2.fromScale(.065,.4);self.title.Size=UDim2.fromScale(.3,.06)
   rule.Position=UDim2.fromScale(.065,.472);rule.Size=UDim2.new(.22,0,0,1)
   self.caption.Position=UDim2.fromScale(.065,.49);self.caption.Size=UDim2.fromScale(.3,.04)
   hint.Position=UDim2.fromScale(.065,.535);hint.Size=UDim2.fromScale(.3,.03)
  end
 end
 ---------------------------------------------------------------- per frame
 -- The camera starts close to the heart and eases back to reveal the whole map.
 function self:camera(t,charge)
  local u=math.max(0,t-6.35)
  local pull=smooth(u/1.6)
  local distance=5.4+(12.6-5.4)*pull-charge*.7
  local look=Vector3.new(0,.1,0):Lerp(center,1-pull*.8)
  local eye=Vector3.new(math.sin(t*.14)*.35,.25+math.sin(t*.21)*.12,-distance)
  if self.activatedAt and not self.reduced then
   local k=math.max(0,1-(t-self.activatedAt)/.35)
   eye+=Vector3.new(math.sin(t*80)*.05*k,math.cos(t*73)*.04*k,0)
  end
  return space*CFrame.lookAt(eye,look),space*CFrame.new(center)
 end
 function self:update(t,charge,activated,reduced)
  if not model.Parent then return end
  self.reduced=reduced
  frame.Visible=true
  local dt=self.last and math.clamp(t-self.last,0,.1) or 0;self.last=t
  local view=workspace.CurrentCamera.ViewportSize
  layout(view)
  local pulse=.5+.5*math.sin(t*(3+charge*3))
  if activated and not self.activatedAt then self.activatedAt=t;burst:Emit(reduced and 14 or 48) end
  local since=self.activatedAt and t-self.activatedAt or nil
  local pop=since and math.max(0,1-since/.5) or 0
  -- Heart node: grey → blue → near-white at peak, then settles to a steady awakened blue.
  local color
  if since then color=Config.Ice:Lerp(Config.Blue,smooth(since/.9)*.7)
  elseif charge<.85 then color=CHANNEL:Lerp(Config.Blue,charge/.85)
  else color=Config.Blue:Lerp(Config.Ice,(charge-.85)/.15*.45) end
  self.core.Color=color
  self.core.Size=Vector3.one*(.24+charge*.1+pulse*.03*charge+pop*.22)
  for i,halo in self.halos do
   local strength=since and (.34-i*.07)*(1+pop) or charge*(.3-i*.07)
   halo.Transparency=1-math.clamp(strength,0,1)
   halo.Size=Vector3.one*(.4+i*.3+pulse*.1*charge+pop*i*.35)
   halo.Color=Config.Blue:Lerp(Config.Ice,pop*.6)
  end
  light.Brightness=since and (2+5*pop) or charge*2.5
  -- Two gyroscope rings spin up as the energy gathers.
  self.spin+=dt*((reduced and .3 or .5)+charge*(reduced and 1.2 or 4)+(since and 1.5 or 0))
  local ringColor=CHANNEL:Lerp(Config.Blue,math.clamp(charge*1.2,0,1)):Lerp(Config.Ice,pop)
  gyroA:paint(ringColor,.55-charge*.35);gyroB:paint(ringColor,.65-charge*.35)
  local grow=1+pop*.5+(since and .15 or 0)
  gyroA:place(coreCF*CFrame.Angles(math.rad(72),0,math.rad(18)),.55*grow,self.spin)
  gyroB:place(coreCF*CFrame.Angles(math.rad(100),math.rad(62),0),.72*grow,-self.spin*.8)
  inward.Rate=since and 0 or charge*(reduced and 22 or 48)
  flareGui.Size=UDim2.fromScale(1.1+charge*2.8+pop*5,1.1+charge*2.8+pop*5)
  flare.ImageTransparency=1-math.clamp(charge*.7+pop*.3,0,1);flare.Rotation=t*(reduced and 6 or 24)
  -- Activation wave: a flat ring of light crossing the whole body map.
  if since and since<1.2 then
   local w=smooth(since/1.2)
   wave:paint(Config.Ice,.05+.95*w);wave:place(coreCF*CFrame.Angles(math.rad(90),0,0),.4+4.2*w,0)
  else
   wave:paint(Config.Ice,1)
  end
  -- Channels: nearby paths sip energy while charging; on activation a pulse runs through
  -- every path and fades back, showing the dormant map without unlocking it.
  local front=since and since*3.4 or -10
  local frontFade=since and math.max(0,1-since/1.8) or 0
  for _,c in self.channels do
   local near=math.clamp(1-(c.distance-(.2+charge*.8))/.35,0,1)*charge*.55
   local band=math.max(0,1-math.abs(c.distance-front)/.5)*frontFade
   local settled=since and math.clamp(1-(c.distance-.35)/.3,0,1)*.6 or 0
   local b=math.clamp(math.max(near,band,settled),0,1)
   c.part.Color=CHANNEL:Lerp(band>near and Config.Ice or Config.Blue,b)
   c.part.Transparency=.2-.15*b
  end
  -- Hologram and space brighten with the energy.
  local shellColor=SHELL:Lerp(Color3.fromRGB(78,150,214),charge*.8):Lerp(Config.Ice,pop*.5)
  for _,s in shells do s.Color=shellColor end
  for _,n in nebulae do n.part.Transparency=n.base-.12*charge-.1*pop end
  -- Titles.
  local u=t-6.35
  local show=smooth((u-.7)/.8)
  chapter.TextTransparency=1-.9*show
  self.title.TextTransparency=1-show;self.title.TextStrokeTransparency=1-(.25+.35*charge+.4*pop)*show
  self.title.TextColor3=Config.Ice:Lerp(Color3.new(1,1,1),pop)
  rule.BackgroundTransparency=1-show*(.3+.6*charge)
  self.caption.TextTransparency=1-.95*show;hint.TextTransparency=1-.8*show*(since and 0 or 1)
  self.caption.Text=since and (newNode and "Awakened · a new path opens within" or "Resonance deepened") or "Breathe. Let the stone answer."
  self.caption.TextColor3=since and Config.Ice or Color3.fromRGB(149,178,204)
 end
 function self:hide() frame.Visible=false;model.Parent=nil end
 function self:destroy() frame:Destroy();model:Destroy() end
 self.frame=frame
 return self
end
return M
