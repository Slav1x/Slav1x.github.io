-- World-space and screen-space visuals for the awakening cinematic.
-- Owns no camera, input, audio or timeline: AwakeningCinematic drives it every frame.
-- Everything is local to this client and parented to the cinematic's folder or gui.
local Config=require(game.ReplicatedStorage.Shared.AwakeningConfig)
local V={}
V.Sparkle="rbxasset://textures/particles/sparkles_main.dds"
V.Soft="rbxasset://textures/particles/smoke_main.dds"
local function smooth(a) a=math.clamp(a,0,1);return a*a*(3-2*a) end
V.smooth=smooth
local function make(class,parent,props)
 local v=Instance.new(class);for k,value in props do v[k]=value end;v.Parent=parent;return v
end
V.make=make
function V.part(parent,name,size,cf,color,transparency,shape)
 local p=Instance.new("Part");p.Name=name;if shape then p.Shape=shape end
 p.Size=size;p.CFrame=cf;p.Color=color;p.Transparency=transparency or 0;p.Material=Enum.Material.Neon
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Parent=parent
 return p
end
local function seq(...) local k={};local v={...};for i=1,#v,2 do table.insert(k,NumberSequenceKeypoint.new(v[i],v[i+1])) end;return NumberSequence.new(k) end
V.seq=seq
-- A circle of thin neon segments in the local XZ plane of `cf`. Rotate `cf` to stand it up.
function V.ring(parent,name,count,color,width,transparency,start)
 local r={parts={},cframes={},count=count,width=width,chord=0,color=color,transparency=transparency or 0}
 for i=1,count do r.parts[i]=V.part(parent,name,Vector3.new(width,width*.4,.1),start or CFrame.identity,color,r.transparency) end
 function r:place(cf,radius,spin)
  local step=2*math.pi/self.count
  local chord=2*radius*math.sin(step/2)*1.06
  local resize=math.abs(chord-self.chord)>.002;self.chord=chord
  for i,p in self.parts do
   local a=spin+(i-.5)*step
   local mid=Vector3.new(math.cos(a)*radius,0,math.sin(a)*radius)
   self.cframes[i]=cf*CFrame.lookAt(mid,mid+Vector3.new(-math.sin(a),0,math.cos(a)))
   if resize then p.Size=Vector3.new(self.width,self.width*.4,chord) end
  end
  workspace:BulkMoveTo(self.parts,self.cframes,Enum.BulkMoveMode.FireCFrameChanged)
 end
 function r:paint(c,t)
  if c==self.color and t==self.transparency then return end
  self.color=c;self.transparency=t
  for _,p in self.parts do p.Color=c;p.Transparency=t end
 end
 return r
end
local function screenFrame(parent,name,z,color)
 return make("Frame",parent,{Name=name,BorderSizePixel=0,BackgroundColor3=color or Color3.new(1,1,1),BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),ZIndex=z,Active=false})
end
function V.create(o)
 local self={impactAt=nil,contactAt=nil,returnAt=nil,fovOffset=0}
 local folder,gui,root,rock,anchor,palm=o.folder,o.gui,o.root,o.rock,o.anchor,o.palm
 local reduced=o.reduced
 ---------------------------------------------------------------- world
 local rockGlow=make("Highlight",folder,{Name="AwakeningRockGlow",Adornee=rock,FillColor=Config.Blue,OutlineColor=Config.Ice,FillTransparency=1,OutlineTransparency=1,DepthMode=Enum.HighlightDepthMode.Occluded})
 local rockLight=make("PointLight",anchor,{Name="AwakeningContactLight",Color=Config.Blue,Range=16,Brightness=0,Shadows=false})
 local rockCF,rockSize
 if rock:IsA("Model") then rockCF,rockSize=rock:GetBoundingBox() elseif rock:IsA("BasePart") then rockCF,rockSize=rock.CFrame,rock.Size else rockCF,rockSize=anchor.CFrame,Vector3.new(4,4,4) end
 local rockShell=V.part(folder,"RockMoteShell",rockSize*.9,rockCF,Config.Blue,1)
 local motes=make("ParticleEmitter",rockShell,{Name="RockMotes",Texture=V.Sparkle,Rate=0,Shape=Enum.ParticleEmitterShape.Box,ShapeStyle=Enum.ParticleEmitterShapeStyle.Surface,EmissionDirection=Enum.NormalId.Top,
  Lifetime=NumberRange.new(1.4,2.6),Speed=NumberRange.new(.6,1.8),Acceleration=Vector3.new(0,1.4,0),Drag=.6,SpreadAngle=Vector2.new(25,25),LightEmission=1,LightInfluence=0,
  Color=ColorSequence.new(Config.Ice,Config.Blue),Size=seq(0,0,.2,.16,1,0),Transparency=seq(0,1,.2,.1,1,1),RotSpeed=NumberRange.new(-60,60)})
 -- Palm: contact flare and a small ripple of light where skin meets stone.
 local origin=make("Attachment",palm,{Name="AwakeningTransferOrigin"})
 local flare=make("ParticleEmitter",origin,{Name="ContactFlare",Texture=V.Sparkle,Rate=0,LockedToPart=true,Lifetime=NumberRange.new(.55,.7),Speed=NumberRange.new(0),LightEmission=1,LightInfluence=0,
  Color=ColorSequence.new(Config.Ice),Size=seq(0,.6,.15,2.6,1,.4),Transparency=seq(0,.05,.5,.35,1,1),Rotation=NumberRange.new(0,360),RotSpeed=NumberRange.new(-90,90),ZOffset=1})
 local sparks=make("ParticleEmitter",origin,{Name="ContactSparks",Texture=V.Sparkle,Rate=0,Lifetime=NumberRange.new(.35,.8),Speed=NumberRange.new(3,7),Drag=5,SpreadAngle=Vector2.new(180,180),LightEmission=1,LightInfluence=0,
  Color=ColorSequence.new(Config.Ice,Config.Blue),Size=seq(0,.14,1,0),Transparency=seq(0,0,1,1)})
 local palmLight=make("PointLight",origin,{Name="PalmLight",Color=Config.Ice,Range=7,Brightness=0,Shadows=false})
 -- Transfer: three woven beams (core, glow and a counter-spiral) from palm to heart.
 local heart=make("Attachment",root,{Name="AwakeningHeart",Position=Vector3.new(0,.65,-.45)})
 local function beam(name,props)
  local b=make("Beam",origin,{Name=name,Attachment0=origin,Attachment1=heart,FaceCamera=true,LightEmission=1,LightInfluence=0,Segments=18,Enabled=false})
  for k,v in props do b[k]=v end;return b
 end
 local beams={
  beam("PowerTransfer",{Color=ColorSequence.new(Config.Ice,Config.Blue),Width0=.2,Width1=.07,CurveSize0=.7,CurveSize1=-.3,Texture=V.Sparkle,TextureMode=Enum.TextureMode.Wrap,TextureLength=1.1,TextureSpeed=2.6}),
  beam("PowerTransferGlow",{Color=ColorSequence.new(Config.Blue),Width0=.62,Width1=.24,CurveSize0=.7,CurveSize1=-.3,Transparency=seq(0,.72,1,.8)}),
  beam("PowerTransferSpiral",{Color=ColorSequence.new(Config.Ice),Width0=.07,Width1=.035,CurveSize0=-1.1,CurveSize1=.9,Texture=V.Sparkle,TextureMode=Enum.TextureMode.Wrap,TextureLength=.7,TextureSpeed=-4}),
 }
 local heartLight=make("PointLight",heart,{Name="AwakeningHeartLight",Color=Config.Blue,Range=9,Brightness=0,Shadows=false})
 -- Rising energy and afterglow around the player's body.
 local body=V.part(folder,"AwakeningBodyVolume",Vector3.new(2.2,4.6,1.4),root.CFrame*CFrame.new(0,-.4,0),Config.Blue,1)
 local wisps=make("ParticleEmitter",body,{Name="RisingWisps",Texture=V.Soft,Rate=0,Shape=Enum.ParticleEmitterShape.Box,ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume,EmissionDirection=Enum.NormalId.Top,
  Lifetime=NumberRange.new(.6,1.15),Speed=NumberRange.new(1.5,3.5),Acceleration=Vector3.new(0,3,0),SpreadAngle=Vector2.new(12,12),LightEmission=1,LightInfluence=0,
  Color=ColorSequence.new(Config.Blue,Config.Ice),Size=seq(0,.5,.4,1.3,1,1.8),Transparency=seq(0,1,.25,.72,1,1),Rotation=NumberRange.new(0,360),RotSpeed=NumberRange.new(-40,40)})
 local afterglow=make("ParticleEmitter",body,{Name="Afterglow",Texture=V.Sparkle,Rate=0,Shape=Enum.ParticleEmitterShape.Box,ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume,
  Lifetime=NumberRange.new(.9,1.8),Speed=NumberRange.new(.4,2.2),Drag=1,SpreadAngle=Vector2.new(180,180),Acceleration=Vector3.new(0,.8,0),LightEmission=1,LightInfluence=0,
  Color=ColorSequence.new(Config.Blue,Config.Ice),Size=seq(0,.08,.3,.2,1,0),Transparency=seq(0,0,.7,.2,1,1)})
 local charGlow=make("Highlight",folder,{Name="AwakeningCharacterGlow",Adornee=o.character,FillColor=Config.Blue,OutlineColor=Config.Ice,FillTransparency=1,OutlineTransparency=1,DepthMode=Enum.HighlightDepthMode.Occluded})
 -- Ground sigil: two counter-rotating rings and eight marks around the player's feet.
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={o.character,folder,rock}
 local hit=workspace:Raycast(root.Position,Vector3.new(0,-14,0),params)
 local floorY=hit and hit.Position.Y or root.Position.Y-3
 local ground=CFrame.new(root.Position.X,floorY+.07,root.Position.Z)
 local outer=V.ring(folder,"SigilOuter",56,Config.Blue,.1,1,ground)
 local innerRing=V.ring(folder,"SigilInner",40,Config.Blue,.05,1,ground)
 local marks={}
 for i=1,8 do marks[i]=V.part(folder,"SigilMark",Vector3.new(.08,.03,.55),ground,Config.Ice,1) end
 local markFrames={}
 ---------------------------------------------------------------- screen
 local canvas=make("Frame",gui,{Name="AwakeningFX",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=12,Active=false})
 local vignette={}
 for _,spec in {{"Top",UDim2.fromScale(.5,0),UDim2.fromScale(1,.42),Vector2.new(.5,0),90},{"Bottom",UDim2.fromScale(.5,1),UDim2.fromScale(1,.42),Vector2.new(.5,1),-90},{"Left",UDim2.fromScale(0,.5),UDim2.fromScale(.32,1),Vector2.new(0,.5),0},{"Right",UDim2.fromScale(1,.5),UDim2.fromScale(.32,1),Vector2.new(1,.5),180}} do
  local f=make("Frame",canvas,{Name="Vignette"..spec[1],Position=spec[2],Size=spec[3],AnchorPoint=spec[4],BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(1,4,12),BackgroundTransparency=1,ZIndex=12})
  make("UIGradient",f,{Rotation=spec[5],Transparency=seq(0,0,.55,.7,1,1)})
  table.insert(vignette,f)
 end
 local shock=screenFrame(canvas,"ImpactShockwave",13)
 make("UICorner",shock,{CornerRadius=UDim.new(1,0)})
 local shockStroke=make("UIStroke",shock,{Color=Config.Ice,Thickness=6,Transparency=1})
 local rays={}
 local rayCount=30
 local random=Random.new(os.clock()*1000)
 for i=1,rayCount do
  local ray=screenFrame(canvas,"ImpactRay",13,i%3==0 and Config.Blue or Config.Ice)
  make("UIGradient",ray,{Transparency=seq(0,1,.25,0,.7,.2,1,1)})
  rays[i]={frame=ray,angle=(i-1)/rayCount*math.pi*2+random:NextNumber(-.08,.08),width=random:NextNumber(2,7),reach=random:NextNumber(.6,1.15),delay=random:NextNumber(0,.05)}
 end
 local tunnel=make("ImageLabel",canvas,{Name="HeartLight",Image=V.Soft,ImageColor3=Config.Blue,ImageTransparency=1,BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),ZIndex=14,Active=false})
 local star=make("ImageLabel",canvas,{Name="HeartStar",Image=V.Sparkle,ImageColor3=Config.Ice,ImageTransparency=1,BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),ZIndex=14,Active=false})
 ---------------------------------------------------------------- cues
 function self:cue(name,t)
  local r=reduced()
  if name=="contact" then
   self.contactAt=t;flare:Emit(1);sparks:Emit(r and 6 or 16)
  elseif name=="transfer" then
   self.impactAt=t;sparks:Emit(r and 10 or 30);flare:Emit(1)
  elseif name=="return" then
   self.returnAt=t;afterglow:Emit(r and 10 or 34);wisps:Emit(r and 4 or 14)
  end
 end
 local function toScreen(cam,position)
  local p,visible=cam:WorldToViewportPoint(position)
  return Vector2.new(p.X,p.Y),visible and p.Z>0
 end
 ---------------------------------------------------------------- per frame
 -- s: {t, cam, phase, reach, charge, inner, since, out, skipped, grade(tint), bloom}
 function self:update(s)
  local t,cam,r=s.t,s.cam,reduced()
  local view=cam.ViewportSize
  local world=not s.inner
  local out=s.out
  -- Hits decay quickly so each cue reads as a single accent.
  local contactHit=self.contactAt and math.max(0,1-(t-self.contactAt)/.6) or 0
  local k=self.impactAt and t-self.impactAt or math.huge
  local impactHit=math.max(0,1-k/.5)
  local transfer=t>=5.12 and t<6.35 and not s.skipped and world and not out
  -- Rock: the stone brightens as the hand approaches, then answers on contact.
  local returnFade=out and math.max(0,1-out/1.6) or 1
  local awake=smooth(t/1.2)*returnFade
  rockGlow.OutlineTransparency=1-(.25+.5*s.reach+.25*impactHit)*awake
  rockGlow.FillTransparency=1-(.06*s.reach+.18*contactHit+.35*impactHit)*awake
  rockLight.Brightness=(.5+1.2*s.reach+3*contactHit+4*impactHit)*awake
  motes.Rate=(world and not out) and (3+16*s.reach+(t>=4.15 and 10 or 0))*(r and .5 or 1) or 0
  palmLight.Brightness=(world and not out) and (2.5*contactHit+5*impactHit+(t>=4.15 and t<6.35 and 1.2 or 0)) or 0
  -- Beams swell on the impact and thin out as the power settles into the chest.
  for i,b in beams do
   b.Enabled=transfer
   if transfer then
    local swell=1+1.4*impactHit
    local settle=math.clamp((t-5.6)/.75,0,1)
    if i==1 then b.Width0=.2*swell;b.Width1=.07*swell;b.Transparency=seq(0,.05+.5*settle,1,.15+.5*settle)
    elseif i==2 then b.Width0=.62*swell;b.Width1=.24*swell;b.Transparency=seq(0,.7+.2*settle,1,.8+.15*settle)
    else b.CurveSize0=-1.1+math.sin(t*9)*.25;b.CurveSize1=.9+math.cos(t*7)*.2;b.Transparency=seq(0,.2+.6*settle,1,.3+.6*settle) end
   end
  end
  heartLight.Brightness=transfer and (1.5+4*impactHit) or (out and 2.5*math.max(0,1-out/2) or 0)
  wisps.Rate=transfer and (r and 10 or 26) or 0
  -- The character's silhouette catches the light while power flows in, and keeps a brief aura after.
  if out then
   local after=math.max(0,1-out/2.2)
   charGlow.FillTransparency=1-.28*after;charGlow.OutlineTransparency=1-.8*after
  else
   local flow=transfer and smooth((t-5.12)/.25) or 0
   charGlow.FillTransparency=1-.18*impactHit;charGlow.OutlineTransparency=1-.7*flow
  end
  -- Ground sigil.
  local sigil=smooth((t-1.1)/2.6)*(world and 1 or 0)
  local radius,alpha=3.4,.62*sigil+.2*contactHit+.3*impactHit
  if out then
   local wave=smooth(out/1.3)
   radius=3.4+7*wave;alpha=(1-wave)*.9
  end
  local ringColor=Config.Blue:Lerp(Config.Ice,math.clamp(contactHit+impactHit,0,1))
  local spin=r and 0 or t*.16
  outer:paint(ringColor,1-math.clamp(alpha,0,1));innerRing:paint(Config.Blue,1-math.clamp(alpha*.8,0,1))
  outer:place(ground,radius,spin);innerRing:place(ground,radius*.78,-spin*1.6)
  for i,m in marks do
   local a=-spin*1.6+(i-1)*math.pi/4
   local at=Vector3.new(math.cos(a),0,math.sin(a))*radius*.89
   markFrames[i]=ground*CFrame.lookAt(at,at*2)
   m.Transparency=1-math.clamp(alpha*.9,0,1)
  end
  workspace:BulkMoveTo(marks,markFrames,Enum.BulkMoveMode.FireCFrameChanged)
  -- Impact frame: one inverted, high-contrast beat, speed lines from the palm and a shockwave ring.
  self.fovOffset=0
  local diag=view.Magnitude
  local palmScreen=toScreen(cam,origin.WorldPosition)
  if k<.5 and world then
   if k<.085 and not r then
    s.tint.TintColor=Config.Ice;s.tint.Saturation=-1;s.tint.Contrast=.85;s.tint.Brightness=.08
   end
   self.fovOffset=-(r and 2 or 7)*(1-smooth(k/.4))
   local grow=smooth(k/.5)
   shock.Position=UDim2.fromOffset(palmScreen.X,palmScreen.Y)
   shock.Size=UDim2.fromOffset(diag*.9*grow,diag*.9*grow)
   shockStroke.Thickness=2+8*(1-grow);shockStroke.Transparency=.1+.9*grow
  else
   shockStroke.Transparency=1
  end
  for _,ray in rays do
   local f=ray.frame
   local rk=k-ray.delay
   if r or rk<0 or rk>.45 or not world then f.BackgroundTransparency=1;continue end
   local extend=smooth(rk/.16)
   local length=diag*.55*ray.reach*extend
   local start=diag*(.05+.18*smooth(rk/.45))
   local dir=Vector2.new(math.cos(ray.angle),math.sin(ray.angle))
   local center=palmScreen+dir*(start+length/2)
   f.Position=UDim2.fromOffset(center.X,center.Y);f.Size=UDim2.fromOffset(length,ray.width*(1-.6*smooth(rk/.45)))
   f.Rotation=math.deg(ray.angle);f.BackgroundTransparency=.05+.95*smooth((rk-.1)/.35)
  end
  -- Into the body: the heart becomes a light the camera falls into.
  if t>=5.4 and t<6.35 and world and not out then
   local heartScreen=toScreen(cam,heart.WorldPosition)
   local fall=smooth((t-5.5)/.85)
   local size=view.Y*(.18+3.3*fall)
   tunnel.Position=UDim2.fromOffset(heartScreen.X,heartScreen.Y);tunnel.Size=UDim2.fromOffset(size,size)
   tunnel.ImageColor3=Config.Blue:Lerp(Config.Ice,fall*.6);tunnel.ImageTransparency=1-.9*smooth((t-5.45)/.45)
   star.Position=tunnel.Position;star.Size=UDim2.fromOffset(size*.45,size*.45);star.Rotation=t*40
   star.ImageTransparency=1-.8*smooth((t-5.5)/.4)*(1-fall*.7)
  else
   tunnel.ImageTransparency=1;star.ImageTransparency=1
  end
  -- Vignette tightens with tension and releases on the return.
  local strength=s.inner and .75 or (.4+.35*s.reach)
  if out then strength*=math.max(0,1-out/1.8) end
  for _,f in vignette do f.BackgroundTransparency=1-strength end
 end
 function self:destroy()
  for _,v in {canvas,rockGlow,rockLight,rockShell,origin,heart,body,charGlow} do v:Destroy() end
  for _,p in outer.parts do p:Destroy() end;for _,p in innerRing.parts do p:Destroy() end;for _,m in marks do m:Destroy() end
 end
 return self
end
return V
