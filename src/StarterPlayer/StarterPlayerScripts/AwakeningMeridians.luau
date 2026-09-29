-- The inner world: a private, client-only space far above the player where a holographic
-- echo of their body shows the meridian map. Built in world space (not a ViewportFrame)
-- so neon, bloom, lights and particles render at full quality.
--
-- One map, three uses:
--   "awakening"  rebirths 1-10. Every earlier meridian and the channels around it stay lit,
--                so the body visibly fills in, one region per rebirth.
--   finale       rebirth 10 only (automatic): after the tenth path wakes, all ten pulse
--                together, flow toward the chest and a faint gold spark appears. Foreshadow.
--   "golden"     the Golden Meridian: all ten converge on the chest (the first meridian)
--                and become one golden heart.
-- Node positions and unlock order come from AwakeningConfig.Nodes.
local RS=game:GetService("ReplicatedStorage")
local Config=require(RS.Shared.AwakeningConfig)
local Golden=require(RS.Shared.GoldenMeridianConfig)
local VFX=require(script.Parent.AwakeningVFX)
local smooth,make,part,seq=VFX.smooth,VFX.make,VFX.part,VFX.seq
local M={}
local VOID=Color3.fromRGB(3,8,21)
local SHELL=Color3.fromRGB(48,86,124)
local CHANNEL=Color3.fromRGB(64,70,82)
local AWAKE=Color3.fromRGB(44,128,214) -- an earlier meridian's resting blue
local SPENT=Color3.fromRGB(30,36,50)
local HEIGHT=1200
-- Golden Meridian beats, in seconds from the start of the golden inner view.
M.GoldenTimeline={pulses=1.6,converge=2.4,unstable=4.2,shift=6.6,vacuum=9.0,activate=9.8,finish=14.6}
-- Rebirth 10 finale beats, in seconds after the tenth meridian activates.
M.FinaleTimeline={reveal=1.1,pulses={2.4,3.0,3.45},spark=4.1,finish=5.4}
local function bump(t,at,width)
 local d=(t-at)/width
 if d<0 or d>1 then return 0 end
 return math.sin(d*math.pi)
end
function M.create(parent,folder,character,count,mode)
 mode=mode or "awakening"
 local golden=mode=="golden"
 if golden then count=#Config.Nodes+1 end
 local root=character:FindFirstChild("HumanoidRootPart")
 local space=CFrame.new(root.Position+Vector3.new(0,HEIGHT,0))
 local self={nodes={},order={},channels={},halos={},motes={},streams={},spin=0,last=nil,mode=mode}
 local model=make("Model",folder,{Name="InnerWorld"})
 local heartDef=Config.Nodes[1]
 local target,newNode=Config.stage(count)
 if golden then target=heartDef;newNode=false end
 self.target=target
 self.isFinal=not golden and count==Config.FinalAwakening
 local center=target.at+Vector3.new(0,0,-.14)
 local heart=heartDef.at+Vector3.new(0,0,-.14)
 local function at(v) return space*CFrame.new(v) end
 ---------------------------------------------------------------- the space itself
 -- Dark neon shell: unaffected by the time of day and never blooms.
 for _,w in {{Vector3.new(0,0,32),Vector3.new(80,60,1)},{Vector3.new(0,0,-32),Vector3.new(80,60,1)},{Vector3.new(40,0,0),Vector3.new(1,60,64)},{Vector3.new(-40,0,0),Vector3.new(1,60,64)},{Vector3.new(0,30,0),Vector3.new(80,1,64)},{Vector3.new(0,-30,0),Vector3.new(80,1,64)}} do
  local wall=part(model,"Void",w[2],at(w[1]),VOID,0);wall.CastShadow=true
 end
 -- Soft nebulae behind the body give depth without competing with the meridians.
 local nebulae={}
 for _,n in {{Vector3.new(0,.6,16),26,Color3.fromRGB(14,40,88),.55},{Vector3.new(-9,5,22),24,Color3.fromRGB(32,22,78),.68},{Vector3.new(10,-4,20),22,Color3.fromRGB(10,52,92),.7}} do
  table.insert(nebulae,{part=part(model,"Nebula",Vector3.one*n[2],at(n[1]),n[3],n[4],Enum.PartType.Ball),base=n[4],color=n[3]})
 end
 local dust=part(model,"DustVolume",Vector3.new(16,11,10),at(Vector3.new(0,0,2)),VOID,1)
 local dustEmitter=make("ParticleEmitter",dust,{Name="Dust",Texture=VFX.Sparkle,Rate=14,Shape=Enum.ParticleEmitterShape.Box,ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume,
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
 ---------------------------------------------------------------- nodes
 for _,node in Config.Nodes do
  local unlocked=node.unlock<count
  local isTarget=node.id==target.id
  local pos=node.at+Vector3.new(0,0,-.13)
  local core=part(model,node.id,Vector3.one*(isTarget and .24 or .15),at(pos),unlocked and Config.Blue or CHANNEL,0,Enum.PartType.Ball)
  local entry={def=node,core=core,pos=pos,unlocked=unlocked,isTarget=isTarget}
  if not isTarget then
   -- Awakened points keep a halo; dormant ones a faint rim, so the map shows what is left.
   entry.rim=part(model,unlocked and "AwakenedHalo" or "DormantRim",Vector3.one*(unlocked and .42 or .24),core.CFrame,unlocked and Config.Blue or CHANNEL,unlocked and .8 or .82,Enum.PartType.Ball)
  end
  entry.attachment=make("Attachment",core,{Name="Flow"})
  self.nodes[node.id]=entry
  table.insert(self.order,entry)
 end
 self.core=self.nodes[target.id].core
 local heartEntry=self.nodes[heartDef.id]
 ---------------------------------------------------------------- channels
 -- Each channel segment belongs to its nearest meridian, and lights when that one is awake.
 local function nearest(point)
  local best,bestDistance
  for _,entry in self.order do
   local d=(entry.def.at-point).Magnitude
   if not bestDistance or d<bestDistance then best,bestDistance=entry,d end
  end
  return best,bestDistance
 end
 local function path(points)
  for i=1,#points-1 do
   local a=Vector3.new(points[i][1],points[i][2],-.62);local b=Vector3.new(points[i+1][1],points[i+1][2],-.62)
   local mid=(a+b)*.5
   local owner,ownerDistance=nearest(mid)
   local seg=part(model,"MeridianChannel",Vector3.new(.034,.034,(a-b).Magnitude),space*CFrame.lookAt(mid,b),owner.unlocked and AWAKE or CHANNEL,.2)
   table.insert(self.channels,{part=seg,mid=mid,distance=(mid-center).Magnitude,heartDistance=(mid-heart).Magnitude,owner=owner,ownerDistance=ownerDistance,lit=owner.unlocked})
  end
 end
 path({{0,2.9},{0,2.35},{0,1.55},{0,.65},{0,-.8}})
 for _,side in {-1,1} do
  path({{0,1.25},{side*.65,1.05},{side*1.45,.82},{side*1.55,.4},{side*1.67,-.5},{side*1.65,-1}})
  path({{0,.65},{side*.65,.38},{side*.78,-.15},{0,-.8},{side*.48,-1.3},{side*.52,-2.15},{side*.52,-2.7}})
  path({{side*.48,-1.3},{side*.8,-1.75},{side*.52,-2.15}})
 end
 ---------------------------------------------------------------- the focal meridian
 local coreCF=at(center)
 local heartCF=at(heart)
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
 ---------------------------------------------------------------- convergence (finale and golden)
 -- Streams of light from every other meridian into the chest, where the first one woke.
 local heartFlow=heartEntry.attachment
 local goldFlareGui,goldFlare,goldRing
 if self.isFinal or golden then
  for _,entry in self.order do
   if entry==heartEntry then continue end
   local b=make("Beam",entry.core,{Name="Convergence",Attachment0=entry.attachment,Attachment1=heartFlow,FaceCamera=true,LightEmission=1,LightInfluence=0,Segments=14,
    Width0=.05,Width1=.03,CurveSize0=(entry.def.at.X>=0 and .35 or -.35),CurveSize1=0,Color=ColorSequence.new(Config.Blue,Config.Ice),Transparency=NumberSequence.new(1),
    Texture=VFX.Sparkle,TextureMode=Enum.TextureMode.Wrap,TextureLength=.5,TextureSpeed=1.8,Enabled=false})
   local stream={entry=entry,beam=b,motes={}}
   for i=1,4 do table.insert(stream.motes,{part=part(model,"FlowMote",Vector3.one*.07,entry.core.CFrame,Config.Ice,1,Enum.PartType.Ball),offset=(i-1)/4}) end
   table.insert(self.streams,stream)
  end
  goldFlareGui=make("BillboardGui",heartEntry.core,{Name="GoldenSpark",Size=UDim2.fromScale(.6,.6),LightInfluence=0,Brightness=3,AlwaysOnTop=false})
  goldFlare=make("ImageLabel",goldFlareGui,{Image=VFX.Sparkle,ImageColor3=Golden.Gold,ImageTransparency=1,BackgroundTransparency=1,Size=UDim2.fromScale(1,1)})
  goldRing=VFX.ring(model,"GoldenRing",48,Golden.Gold,.03,1,heartCF)
 end
 ---------------------------------------------------------------- titles
 local frame=make("Frame",parent,{Name="InnerWorld",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=16,Visible=false})
 local function text(name,words,size,color,font)
  local t=make("TextLabel",frame,{Name=name,Text=words,TextColor3=color,BackgroundTransparency=1,TextSize=size,Font=font or Enum.Font.GothamMedium,TextScaled=true,TextTransparency=1,ZIndex=16})
  make("UITextSizeConstraint",t,{MaxTextSize=size,MinTextSize=10})
  return t
 end
 local chapter=text("Chapter",golden and "BEYOND THE TEN" or Config.chapter(count),13,Color3.fromRGB(129,168,200))
 self.title=text("MeridianName",golden and "TEN PATHS" or string.upper(target.name),30,Config.Ice,Enum.Font.GothamBold)
 self.title.TextStrokeColor3=Config.Blue;self.title.TextStrokeTransparency=1
 local rule=make("Frame",frame,{Name="Rule",BorderSizePixel=0,BackgroundColor3=Config.Blue,BackgroundTransparency=1,ZIndex=16})
 make("UIGradient",rule,{Transparency=seq(0,1,.3,0,.7,0,1,1)})
 self.caption=text("State","",15,Color3.fromRGB(149,178,204))
 local hintWords=golden and "" or count==1 and "A beginning. The other paths are still quiet."
  or self.isFinal and "The last of the ten paths."
  or string.format("%d of %d paths awakened.",count,#Config.Nodes)
 local hint=text("Hint",hintWords,12,Color3.fromRGB(95,122,150))
 -- Progress pips: one diamond per meridian. The Golden Meridian gathers them into one.
 local pipBox=make("Frame",frame,{Name="Paths",BackgroundTransparency=1,ZIndex=16})
 local pips={}
 for i,node in Config.Nodes do
  local d=make("Frame",pipBox,{Name="Path"..i,AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(7,7),Rotation=45,BorderSizePixel=0,BackgroundColor3=Config.Blue,BackgroundTransparency=1,ZIndex=17})
  local stroke=make("UIStroke",d,{Color=CHANNEL,Thickness=1,Transparency=1})
  pips[i]={frame=d,stroke=stroke,node=node}
 end
 local items={chapter,self.title,self.caption,hint}
 local function layout(view)
  local portrait=view.X<view.Y*1.15
  local align=portrait and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
  for _,t in items do t.TextXAlignment=align end
  if portrait then
   chapter.Position=UDim2.fromScale(.06,.115);chapter.Size=UDim2.fromScale(.88,.035)
   self.title.Position=UDim2.fromScale(.06,.15);self.title.Size=UDim2.fromScale(.88,.05)
   rule.Position=UDim2.fromScale(.3,.205);rule.Size=UDim2.new(.4,0,0,1)
   self.caption.Position=UDim2.fromScale(.06,.77);self.caption.Size=UDim2.fromScale(.88,.04)
   hint.Position=UDim2.fromScale(.06,.815);hint.Size=UDim2.fromScale(.88,.03)
   pipBox.AnchorPoint=Vector2.new(.5,0);pipBox.Position=UDim2.fromScale(.5,.855);pipBox.Size=UDim2.fromOffset(150,12)
  else
   chapter.Position=UDim2.fromScale(.065,.36);chapter.Size=UDim2.fromScale(.3,.035)
   self.title.Position=UDim2.fromScale(.065,.4);self.title.Size=UDim2.fromScale(.3,.06)
   rule.Position=UDim2.fromScale(.065,.472);rule.Size=UDim2.new(.22,0,0,1)
   self.caption.Position=UDim2.fromScale(.065,.49);self.caption.Size=UDim2.fromScale(.3,.04)
   hint.Position=UDim2.fromScale(.065,.535);hint.Size=UDim2.fromScale(.3,.03)
   pipBox.AnchorPoint=Vector2.zero;pipBox.Position=UDim2.fromScale(.065,.575);pipBox.Size=UDim2.fromOffset(150,12)
  end
 end
 -- state 0 dormant, 1 awake, 2 awakening now (fill = 0..1), gather = 0..1 into one gold pip
 local function drawPips(show,fill,gather,gold)
  for i,p in pips do
   local awake=p.node.unlock<count or (p.node.id==target.id and fill>=1)
   local isTarget=not golden and p.node.id==target.id
   local x=(i-5.5)*14
   x*=1-smooth(gather)
   p.frame.Position=UDim2.new(pipBox.AnchorPoint.X,x+(pipBox.AnchorPoint.X==0 and 5.5*14+4 or 0),.5,0)
   local size=7+(isTarget and 3*bump(fill,0,1) or 0)+gold*6
   p.frame.Size=UDim2.fromOffset(size,size)
   local color=Config.Blue:Lerp(Golden.Gold,gold)
   p.frame.BackgroundColor3=isTarget and Config.Ice:Lerp(Config.Blue,fill) or color
   p.frame.BackgroundTransparency=1-show*((awake or isTarget and fill>0) and (isTarget and fill or 1) or 0)*(i==1 and 1 or 1-gold)
   p.stroke.Color=awake and color or isTarget and Config.Ice or CHANNEL
   p.stroke.Transparency=1-show*.9*(i==1 and 1 or 1-gold)
  end
 end
 ---------------------------------------------------------------- shared per-frame pieces
 local function setChannels(fn)
  for _,c in self.channels do
   local color,transparency=fn(c)
   c.part.Color=color;c.part.Transparency=transparency
  end
 end
 local function flowMotes(strength,speed,t,colorA,colorB,bright)
  for _,stream in self.streams do
   local from=stream.entry.pos;local to=heartEntry.pos
   local side=Vector3.new(-(to-from).Y,(to-from).X,0).Unit*.22
   stream.beam.Enabled=strength>0
   if strength>0 then
    stream.beam.Transparency=NumberSequence.new(1-strength*.55,1-strength*.8)
    stream.beam.Color=ColorSequence.new(colorA,colorB)
    stream.beam.TextureSpeed=speed*1.6
   end
   for _,m in stream.motes do
    local p=(t*speed*.45+m.offset)%1
    local position=from:Lerp(to,p)+side*math.sin(p*math.pi)
    m.part.CFrame=at(position)
    m.part.Color=colorA:Lerp(colorB,p)
    m.part.Transparency=strength>0 and 1-strength*(bright or .9)*math.sin(p*math.pi) or 1
   end
  end
 end
 local function setTitles(u,chapterText,titleText,captionText,hintAlpha,glow)
  local show=smooth((u-.7)/.8)
  if chapterText then chapter.Text=chapterText end
  if titleText then self.title.Text=titleText end
  if captionText then self.caption.Text=captionText end
  chapter.TextTransparency=1-.9*show
  self.title.TextTransparency=1-show;self.title.TextStrokeTransparency=1-(.25+.35*(glow or 0))*show
  rule.BackgroundTransparency=1-show*(.3+.6*(glow or 0))
  self.caption.TextTransparency=1-.95*show;hint.TextTransparency=1-.8*show*(hintAlpha or 1)
  return show
 end
 ---------------------------------------------------------------- awakening (rebirths 1-10)
 -- The camera starts close to the meridian and eases back to reveal the whole map.
 function self:camera(t,charge)
  local u=math.max(0,t-6.35)
  local pull=smooth(u/1.6)
  local distance=5.4+(12.6-5.4)*pull-charge*.7
  local look=Vector3.new(0,.1,0):Lerp(center,1-pull*.8)
  if self.isFinal and self.activatedAt then
   -- Finale: settle wide on the whole network, then lean in toward the chest.
   local fin=t-self.activatedAt-M.FinaleTimeline.reveal
   distance+=.8*smooth(fin/1.2)-4.2*smooth((fin-2.6)/1.6)
   look=look:Lerp(heart,smooth((fin-2.2)/1.8))
  end
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
  layout(workspace.CurrentCamera.ViewportSize)
  local pulse=.5+.5*math.sin(t*(3+charge*3))
  if activated and not self.activatedAt then self.activatedAt=t;burst:Emit(reduced and 14 or 48) end
  local since=self.activatedAt and t-self.activatedAt or nil
  local pop=since and math.max(0,1-since/.5) or 0
  local fin=since and self.isFinal and since-M.FinaleTimeline.reveal or nil
  local together=0 -- finale: all ten pulse as one
  if fin then for _,at_ in M.FinaleTimeline.pulses do together=math.max(together,bump(since,at_,.5)) end end
  -- Focal meridian: grey -> blue -> near-white at peak, then settles to a steady awakened blue.
  local color
  if since then color=Config.Ice:Lerp(Config.Blue,smooth(since/.9)*.7)
  elseif charge<.85 then color=CHANNEL:Lerp(Config.Blue,charge/.85)
  else color=Config.Blue:Lerp(Config.Ice,(charge-.85)/.15*.45) end
  self.core.Color=color:Lerp(Config.Ice,together*.6)
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
  -- Earlier meridians glow steadily; the new one's paths light outward from it once it wakes;
  -- a pulse runs through every path on activation, showing the dormant map without waking it.
  local front=since and since*3.4 or -10
  local frontFade=since and math.max(0,1-since/1.8) or 0
  setChannels(function(c)
   local base=c.lit and AWAKE or CHANNEL
   local owned=c.owner.isTarget
   local woken=owned and since and smooth((since-c.ownerDistance/2.6)/.35) or 0
   base=base:Lerp(AWAKE,woken)
   local near=math.clamp(1-(c.distance-(.2+charge*.8))/.35,0,1)*charge*.55
   local band=math.max(0,1-math.abs(c.distance-front)/.5)*frontFade
   local b=math.clamp(math.max(near,band,together*.8),0,1)
   return base:Lerp(band>near and Config.Ice or Config.Blue,b),.2-.15*math.max(b,woken*.5,c.lit and .5 or 0)
  end)
  for _,entry in self.order do
   if entry.isTarget then continue end
   entry.core.Color=(entry.unlocked and Config.Blue or CHANNEL):Lerp(Config.Ice,together*(entry.unlocked and .8 or 0))
   if entry.rim then entry.rim.Transparency=(entry.unlocked and .8 or .82)-together*.25 end
  end
  -- Finale: all ten flow toward the chest and something golden flickers where it all began.
  if fin then
   local flowing=smooth((fin-.4)/1.2)*(1-smooth((fin-3.9)/.4))
   flowMotes(flowing,1+fin*.5,t,Config.Blue,Config.Ice)
   local spark=smooth((fin-(M.FinaleTimeline.spark-M.FinaleTimeline.reveal))/.6)
   local flicker=spark*(.55+.45*math.sin(t*23)*math.sin(t*7.3))
   goldFlare.ImageTransparency=1-math.clamp(flicker*.85,0,1)
   goldFlareGui.Size=UDim2.fromScale(.5+flicker*1.1,.5+flicker*1.1);goldFlare.Rotation=-t*30
   goldRing:paint(Golden.Gold,1-spark*.5*(.6+.4*math.sin(t*5)))
   goldRing:place(heartCF*CFrame.Angles(math.rad(90),0,0),.36+spark*.08,t*.8)
   heartEntry.core.Color=heartEntry.core.Color:Lerp(Golden.Gold,flicker*.45)
  end
  -- Hologram and space brighten with the energy.
  local shellColor=SHELL:Lerp(Color3.fromRGB(78,150,214),charge*.8):Lerp(Config.Ice,pop*.5+together*.3)
  for _,s in shells do s.Color=shellColor end
  for _,n in nebulae do n.part.Transparency=n.base-.12*charge-.1*pop-.08*together end
  -- Titles.
  local caption=since and (newNode and "Awakened · a new path opens within" or "Resonance deepened") or "Breathe. Let the stone answer."
  if fin and fin>=0 then caption=fin<2.9 and "All ten paths are open." or "…and something beneath them." end
  local show=setTitles(t-6.35,nil,nil,caption,since and 0 or 1,charge*.6+pop*.4)
  self.title.TextColor3=Config.Ice:Lerp(Color3.new(1,1,1),pop)
  self.caption.TextColor3=since and Config.Ice or Color3.fromRGB(149,178,204)
  drawPips(show,since and smooth(since/.6) or 0,0,0)
 end
 ---------------------------------------------------------------- Golden Meridian
 local T=M.GoldenTimeline
 function self:goldenCamera(u)
  local push=smooth((u-T.unstable)/(T.vacuum-T.unstable))
  local distance=12.6-5.8*push
  if u>=T.activate then distance=6.8+1.8*smooth((u-T.activate)/.6)+ .6*smooth((u-T.activate-1)/4) end
  local look=Vector3.new(0,.1,0):Lerp(heart,smooth((u-T.converge)/3))
  local sway=u<T.vacuum and 1 or u<T.activate and 0 or smooth((u-T.activate)/2)
  local eye=Vector3.new(math.sin(u*.18)*.4*sway,.25+math.sin(u*.23)*.1*sway,-distance)
  if not self.reduced then
   local shake=(u>=T.unstable and u<T.vacuum and .018*smooth((u-T.unstable)/3) or 0)+(u>=T.activate and .09*math.max(0,1-(u-T.activate)/.5) or 0)
   eye+=Vector3.new(math.sin(u*71)*shake,math.cos(u*63)*shake,0)
  end
  return space*CFrame.lookAt(eye,look),heartCF
 end
 function self:golden(u,reduced)
  if not model.Parent then return end
  self.reduced=reduced
  frame.Visible=true
  layout(workspace.CurrentCamera.ViewportSize)
  local unstable=smooth((u-T.unstable)/(T.shift-T.unstable))
  local spent=smooth((u-(T.unstable+1.2))/(T.vacuum-T.unstable-1.2))
  local shift=smooth((u-T.shift)/(T.vacuum-T.shift))
  local vacuum=u>=T.vacuum and u<T.activate
  local activated=u>=T.activate
  local since=activated and u-T.activate or nil
  local pop=since and math.max(0,1-since/.6) or 0
  -- 1. Each meridian pulses in turn, then all of them together.
  local function nodePulse(i)
   return math.max(bump(u,T.pulses+(i-1)*.2,.45),bump(u,T.pulses+2.2,.5))
  end
  -- 2. Heart: blue -> white-blue -> white -> gold; tiny and white-hot in the silence; then gold.
  local heartColor
  if since then heartColor=Golden.WhiteHot:Lerp(Golden.Gold,smooth(since/.8))
  elseif vacuum then heartColor=Golden.WhiteHot
  else heartColor=Config.Blue:Lerp(Config.Ice,unstable):Lerp(Golden.WhiteHot,smooth((u-T.shift)/1)):Lerp(Golden.Gold,smooth((u-T.shift-1)/1.4)*.7) end
  local heartSize=since and (.46+pop*.35+.04*math.sin(u*2.2)) or vacuum and .1 or .24+.24*smooth((u-T.converge)/(T.vacuum-T.converge))+.04*math.sin(u*(4+unstable*10))
  heartEntry.core.Color=heartColor;heartEntry.core.Size=Vector3.one*heartSize
  for i,halo in self.halos do
   local strength
   if since then strength=(.4-i*.08)*(1+pop)
   elseif vacuum then strength=0
   else strength=(.12+.25*unstable)*(1-shift*.4)-(i-1)*.05 end
   halo.Transparency=1-math.clamp(strength,0,1)
   local contract=since and 1+pop*.8 or 1-shift*.55
   halo.Size=Vector3.one*(.4+i*.3)*contract*(1+.06*math.sin(u*3+i))
   halo.Color=since and Golden.Gold:Lerp(Golden.WhiteGold,pop) or Config.Blue:Lerp(Golden.WhiteGold,shift)
  end
  light.Color=since and Golden.Gold or Config.Blue:Lerp(Golden.WhiteGold,shift)
  light.Brightness=since and (3+6*pop) or vacuum and .5 or 1.5+3*unstable
  -- Gyros spin faster and faster, then collapse into the heart.
  local dt=self.last and math.clamp(u-self.last,0,.1) or 0;self.last=u
  self.spin+=dt*(since and .6 or 1+unstable*7)
  local ringRadius=since and .75+.3*smooth(since/.8) or (1-shift)*.62
  local ringColor=since and Golden.Gold or Config.Blue:Lerp(Golden.WhiteGold,shift)
  gyroA:paint(ringColor,vacuum and 1 or since and .35 or .45-unstable*.3);gyroB:paint(ringColor,vacuum and 1 or since and .45 or .55-unstable*.3)
  gyroA:place(heartCF*CFrame.Angles(math.rad(72),0,math.rad(18)),math.max(.01,ringRadius),self.spin)
  gyroB:place(heartCF*CFrame.Angles(math.rad(100),math.rad(62),0),math.max(.01,ringRadius*1.25),-self.spin*.8)
  -- 3. Energy streams inward from all ten, faster and brighter until the network gives out.
  local flowing=since and 0 or vacuum and 0 or smooth((u-T.converge)/1.2)
  local streamColor=Config.Blue:Lerp(Config.Ice,unstable)
  flowMotes(flowing,1+unstable*3,u,streamColor,Config.Ice:Lerp(Golden.WhiteGold,shift),.95)
  inward.Rate=(not since and not vacuum) and (8+60*unstable)*(reduced and .5 or 1) or 0
  inward.Color=ColorSequence.new(streamColor,Golden.WhiteGold:Lerp(Config.Ice,1-shift))
  -- 4. Nodes lose their identity as their energy leaves; after activation they return as gold.
  for i,entry in self.order do
   if entry==heartEntry then continue end
   local p=nodePulse(i)
   local flick=unstable*(.5+.5*math.sin(u*(17+i*3.1)))
   if since then
    local reach=smooth((since-(entry.pos-heartEntry.pos).Magnitude/3.2)/.4)
    entry.core.Color=SPENT:Lerp(Golden.Gold,reach);entry.core.Size=Vector3.one*(.06+.08*reach)
    if entry.rim then entry.rim.Color=Golden.Gold;entry.rim.Transparency=1-.2*reach end
   else
    entry.core.Color=Config.Blue:Lerp(Config.Ice,math.max(p,flick*.6)):Lerp(SPENT,spent)
    entry.core.Size=Vector3.one*(.15+.07*p)*(1-spent*.6)
    if entry.rim then entry.rim.Color=Config.Blue;entry.rim.Transparency=(.8-.3*p)+.2*spent end
   end
  end
  -- 5. Channels: white-blue while unstable, darken from the outside in, then relight gold from the chest.
  local goldFront=since and since*3.2 or -10
  setChannels(function(c)
   if since then
    local reach=smooth((goldFront-c.heartDistance)/.5)
    local crest=math.max(0,1-math.abs(c.heartDistance-goldFront)/.45)*math.max(0,1-since/2.4)
    return SPENT:Lerp(Golden.DeepGold,reach):Lerp(Golden.WhiteHot,crest),.2-.15*math.max(reach,crest)
   end
   local p=nodePulse(table.find(self.order,c.owner) or 1)
   local drain=smooth((spent*3.2-(3.2-c.heartDistance))/.6)
   local bright=math.max(p*.7,unstable*.6)
   return AWAKE:Lerp(Config.Ice,bright):Lerp(SPENT,vacuum and 1 or drain),.2-.15*bright*(1-drain)
  end)
  -- Activation: the gold ring crosses the body and the burst leaves the heart.
  if since and not self.goldenBurst then self.goldenBurst=true;burst.Color=ColorSequence.new(Golden.WhiteHot,Golden.Gold);burst:Emit(reduced and 20 or 70) end
  if since and since<1.4 then
   local w=smooth(since/1.4)
   wave:paint(Golden.Gold,.02+.98*w);wave:place(heartCF*CFrame.Angles(math.rad(90),0,0),.4+6*w,0)
  else
   wave:paint(Golden.Gold,1)
  end
  goldRing:paint(Golden.Gold,since and .25+.2*math.sin(u*2) or 1)
  goldRing:place(heartCF*CFrame.Angles(math.rad(90),0,0),since and .9+.05*math.sin(u*1.7) or .36,u*.35)
  flareGui.Size=UDim2.fromScale(since and 3+pop*6+.4*math.sin(u*2.2) or 1+unstable*2,since and 3+pop*6+.4*math.sin(u*2.2) or 1+unstable*2)
  flare.ImageColor3=since and Golden.WhiteGold or Config.Ice:Lerp(Golden.WhiteGold,shift)
  flare.ImageTransparency=vacuum and 1 or since and .15 or 1-(.2+.5*unstable)
  flare.Rotation=u*(reduced and 6 or 20)
  goldFlare.ImageTransparency=since and .3 or 1-shift*.6;goldFlareGui.Size=UDim2.fromScale(since and 5+pop*4 or .6+shift*1.5,since and 5+pop*4 or .6+shift*1.5)
  -- Hologram turns warm; the space itself dims before the gold and glows after it.
  local shellColor=since and SHELL:Lerp(Color3.fromRGB(208,150,70),smooth(since/1.2)):Lerp(Golden.WhiteGold,pop*.5)
   or SHELL:Lerp(Color3.fromRGB(96,170,230),unstable*.8):Lerp(Color3.fromRGB(20,26,40),vacuum and .9 or 0)
  for _,s in shells do s.Color=shellColor end
  for _,n in nebulae do
   n.part.Transparency=vacuum and .95 or since and n.base-.1 or n.base-.08*unstable
   n.part.Color=since and n.color:Lerp(Color3.fromRGB(96,62,20),smooth(since/1.5)*.8) or n.color
  end
  dustEmitter.Color=since and ColorSequence.new(Golden.WhiteGold,Golden.Gold) or ColorSequence.new(Config.Ice,Config.Blue)
  -- Titles: ten pips gather into one golden one as the name changes.
  local titleText=since and "THE GOLDEN MERIDIAN" or "TEN PATHS"
  local captionText=since and "Where the first path began, all ten become one." or u>=T.unstable and "They are becoming one." or "Ten paths, each running its own way."
  local show=setTitles(u,nil,titleText,captionText,0,since and .8 or unstable*.4)
  local titleGold=since and smooth(since/.8) or 0
  self.title.TextColor3=Config.Ice:Lerp(Golden.WhiteGold,titleGold)
  self.title.TextStrokeColor3=Config.Blue:Lerp(Golden.Amber,titleGold)
  self.caption.TextColor3=since and Golden.WhiteGold or Color3.fromRGB(149,178,204)
  if vacuum then self.title.TextTransparency=1;self.caption.TextTransparency=1 end
  drawPips(vacuum and 0 or show,1,smooth((u-T.converge)/(T.vacuum-T.converge)),titleGold)
 end
 function self:hide() frame.Visible=false;model.Parent=nil end
 function self:destroy() frame:Destroy();model:Destroy() end
 self.frame=frame
 return self
end
return M
