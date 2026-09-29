-- The true rebirth begins at the Golden Rock:
--   establishing shot · hesitation (the hand rises, pulls back, pauses, commits) · contact ·
--   BUILD (gold gathers into the palm, veins flare toward it) · eyes close · an audio vacuum ·
--   a silhouette frame · the largest release of light in the game · the screen held in gold.
-- Returns an "engulf" handle; the caller dissolves it into the Spirit Realm.
local Players=game:GetService("Players")
local Lighting=game:GetService("Lighting")
local RS=game:GetService("ReplicatedStorage")
local Golden=require(RS.Shared.GoldenMeridianConfig)
local VFX=require(script.Parent.AwakeningVFX)
local Pose=require(script.Parent.AwakeningPose)
local make,part,seq,smooth=VFX.make,VFX.part,VFX.seq,VFX.smooth
local player=Players.LocalPlayer
local RC={}
-- A single frame of black shapes against gold: clones rendered unlit in a ViewportFrame.
local function silhouette(D,sources)
 local camera=workspace.CurrentCamera
 local vp=make("ViewportFrame",D.gui,{Name="Silhouette",Size=UDim2.fromScale(1,1),BackgroundColor3=Golden.WhiteGold,BackgroundTransparency=0,
  Ambient=Color3.new(0,0,0),LightColor=Color3.new(0,0,0),ImageColor3=Color3.new(0,0,0),ZIndex=58})
 local cam=make("Camera",vp,{CFrame=camera.CFrame,FieldOfView=camera.FieldOfView})
 vp.CurrentCamera=cam
 local strip={"LuaSourceContainer","ParticleEmitter","Beam","Trail","Light","Sound","BillboardGui","SurfaceGui","ProximityPrompt","Highlight","Decal","Texture","SurfaceAppearance","Fire","Smoke","Sparkles"}
 for _,source in sources do
  local ok,clone=pcall(function()
   local was=source.Archivable;source.Archivable=true
   local c=source:Clone();source.Archivable=was
   return c
  end)
  if ok and clone then
   for _,d in clone:GetDescendants() do
    local drop=false
    for _,class in strip do if d:IsA(class) then drop=true;break end end
    if drop then d:Destroy()
    elseif d:IsA("BasePart") then
     d.Color=Color3.new(0,0,0);d.Material=Enum.Material.SmoothPlastic
     if d:IsA("MeshPart") then d.TextureID="" end
    end
   end
   clone.Parent=vp
  end
 end
 return vp
end
-- The held light between worlds: gold, slow rays, drifting motes.
local function engulf(D)
 local frame=make("Frame",D.gui,{Name="Engulf",Size=UDim2.fromScale(1,1),BackgroundColor3=Golden.WhiteGold,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=56})
 local glow=make("ImageLabel",frame,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1.6,1.6),SizeConstraint=Enum.SizeConstraint.RelativeXX,
  BackgroundTransparency=1,Image=VFX.Soft,ImageColor3=Golden.WhiteHot,ImageTransparency=1,ZIndex=57})
 local rays={}
 for i=1,10 do
  local ray=make("Frame",frame,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(2,0,0,6+i%3*6),BackgroundColor3=Golden.Gold,BorderSizePixel=0,
   BackgroundTransparency=1,Rotation=i*18,ZIndex=57})
  make("UIGradient",ray,{Transparency=seq(0,1,.45,.6,.5,.4,.55,.6,1,1)})
  table.insert(rays,ray)
 end
 local motes={}
 for i=1,22 do
  local m=make("ImageLabel",frame,{AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(18,18),BackgroundTransparency=1,Image=VFX.Sparkle,ImageColor3=Golden.Gold,ImageTransparency=1,ZIndex=57})
  table.insert(motes,{label=m,x=math.random(),y=math.random(),speed=.02+math.random()*.04,phase=math.random()*6})
 end
 local handle={frame=frame,level=0}
 local start=os.clock()
 local stop=D:every(function()
  local t=os.clock()-start
  local L=handle.level
  frame.BackgroundTransparency=1-L
  glow.ImageTransparency=1-L*(.55+.15*math.sin(t*1.3))
  for i,ray in rays do ray.Rotation=i*18+t*(i%2==0 and 3 or -2);ray.BackgroundTransparency=1-L*(.25+.1*math.sin(t*.8+i)) end
  for _,m in motes do
   m.y=(m.y-m.speed*.016)%1
   m.label.Position=UDim2.fromScale(m.x+.02*math.sin(t+m.phase),m.y)
   m.label.ImageTransparency=1-L*.7
  end
 end)
 function handle:dissolve(seconds)
  local from=self.level
  D:animate(seconds,function(a) self.level=from*(1-smooth(a)) end)
  stop();frame:Destroy()
 end
 D:add(frame)
 return handle
end
function RC.play(ctx,mode)
 local D,audio,rock=ctx.D,ctx.audio,ctx.rock
 local reduced=D.reduced()
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local handle=engulf(D)
 handle.settle=function() end
 local v=rock.v
 if not root or not v then
  -- The stone streamed out or the character is missing: go straight to the light.
  D:animate(1.2,function(a) handle.level=smooth(a) end)
  return handle
 end
 local folder=D:add(make("Folder",workspace,{Name="GoldenRockCinematic"}))
 local contact=v.rock:FindFirstChild("PalmContact")
 local palmCF=contact and contact:IsA("BasePart") and contact.CFrame or v.anchor.CFrame
 local pose=Pose.begin(character,folder,palmCF)
 D:add(function() pose:destroy() end)
 D:add(function() rock.focus=nil;rock.focusStrength=0;rock.flare=0;rock.override=nil end)
 local grade=D:add(make("ColorCorrectionEffect",Lighting,{Name="GoldenCut",TintColor=Color3.new(1,1,1),Saturation=0,Contrast=0,Brightness=0}))
 local bloom=D:add(make("BloomEffect",Lighting,{Name="GoldenCutBloom",Intensity=.2,Size=30,Threshold=1.05}))
 local basis=root.CFrame
 local function point(x,y,z) return basis:PointToWorldSpace(Vector3.new(x,y,z)) end
 local function shot(x,y,z,tx,ty,tz) return CFrame.lookAt(point(x,y,z),point(tx,ty,tz)) end
 local quick=mode~="trial" -- a returning visitor does not hesitate
 -- Audio: the familiar awakening air, deeper and louder than ever.
 audio:world(.12,1.2)
 audio:layer("drone",Golden.Audio.Ambient,.62,{decay=4});audio:set("drone",.26,1.5)
 audio:layer("hum",Golden.Audio.Ambient,1.02);audio:set("hum",.08,2)
 audio:layer("rise",Golden.Audio.Ambient,1.1,{decay=2.2})
 ---------------------------------------------------------------- 1. Establishing
 D:fadeTo(0,.35,Color3.new(0,0,0))
 local wideA=shot(13,2.6,12,0,3.2,-5)
 local wideB=shot(9.5,3.4,14,0,3.4,-5)
 D:shoot(wideA,55)
 D:spawn(function() D:fadeTo(1,.9) end)
 rock:surge(1.2)
 D:animate(quick and 1.6 or 2.8,function(a) D:shoot(wideA:Lerp(wideB,D.inOut(a)),55);D:setBars(smooth(a/.4)) end)
 if not D.alive then return handle end
 ---------------------------------------------------------------- 2. Hesitation (body language, no words)
 local medium=shot(6.5,2.6,-1.4,0,2,-1.8)
 D:shoot(medium,46)
 local reach=0
 local stopPose=D:every(function() pose:update(reach,0) end)
 if not quick then
  D:animate(1,function(a) reach=.55*smooth(a) end)
  rock:surge(1);audio:impact(.45,.18);audio:set("hum",.14,.4)
  D:animate(.6,function(a) reach=.55-.37*smooth(a) end)
  D:wait(.55)
  D:animate(.85,function(a) reach=.18+.82*smooth(a) end)
 else
  D:animate(1.1,function(a) reach=smooth(a) end)
 end
 if not D.alive then return handle end
 ---------------------------------------------------------------- 3. Contact and the build
 local palm=v.anchor.Position
 local hand=character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
 if hand then palm=hand.Position end
 audio:chime(.62,.22);audio:splash(1.6,.05)
 local gather=part(folder,"GatherSphere",Vector3.one*10,CFrame.new(palm),Golden.Gold,1,Enum.PartType.Ball)
 local inward=make("ParticleEmitter",gather,{Texture=VFX.Sparkle,Rate=0,Shape=Enum.ParticleEmitterShape.Sphere,ShapeInOut=Enum.ParticleEmitterShapeInOut.Inward,ShapeStyle=Enum.ParticleEmitterShapeStyle.Surface,
  Lifetime=NumberRange.new(.9,1),Speed=NumberRange.new(5,5.4),LightEmission=1,LightInfluence=0,Color=ColorSequence.new(Golden.Gold,Golden.WhiteHot),Size=seq(0,.05,.7,.18,1,0),Transparency=seq(0,1,.2,.05,1,.3)})
 local core=part(folder,"PalmLight",Vector3.one*.2,CFrame.new(palm),Golden.WhiteHot,1,Enum.PartType.Ball)
 local coreLight=make("PointLight",core,{Color=Golden.Gold,Range=14,Brightness=0,Shadows=false})
 local coreFlare=make("BillboardGui",core,{Size=UDim2.fromScale(1,1),LightInfluence=0,Brightness=3,AlwaysOnTop=false})
 local coreImage=make("ImageLabel",coreFlare,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Image=VFX.Sparkle,ImageColor3=Golden.WhiteGold,ImageTransparency=1})
 rock.focus=palm
 local close=shot(-2.7,2.5,2.3,.3,1.9,-2.2)
 local closer=shot(-1.9,2.3,1.2,.3,1.9,-2.2)
 local buildSeconds=quick and 2.1 or 2.9
 local eyes=0
 stopPose()
 D:animate(buildSeconds,function(a,e)
  local k=smooth(a)
  rock.focusStrength=k;rock.flare=.6*k
  if math.random()<.05+.1*k then rock:surge(.3+.4*k) end
  inward.Rate=10+90*k*(reduced and .5 or 1)
  coreLight.Brightness=6*k;coreImage.ImageTransparency=1-.8*k;coreFlare.Size=UDim2.fromScale(1+5*k,1+5*k)
  eyes=smooth((e-(buildSeconds*.35))/.6)
  pose:update(1,eyes)
  audio:set("rise",.3*k,.1,1.1+.7*k);audio:set("hum",.14+.1*k,.1)
  grade.Contrast=.12*k;grade.TintColor=Color3.new(1,1,1):Lerp(Color3.fromRGB(255,236,200),k)
  bloom.Intensity=.2+.5*k
  local shake=reduced and 0 or .03*k*k
  D:shoot(close:Lerp(closer,k)*CFrame.new(math.sin(e*47)*shake,math.cos(e*41)*shake,0),44-6*k)
 end)
 if not D.alive then return handle end
 ---------------------------------------------------------------- 4. The vacuum: a held breath
 audio:vacuum(.03,.12);audio:world(0,.1)
 inward.TimeScale=.12
 for _,e in {v.motes,v.wisps,v.ascending} do if e then e.TimeScale=.15 end end
 D:add(function() for _,e in {v.motes,v.wisps,v.ascending} do if e and e.Parent then e.TimeScale=1 end end end)
 D:animate(.55,function(a) grade.Saturation=-.55*smooth(a);grade.Brightness=-.05*smooth(a) end)
 if not D.alive then return handle end
 ---------------------------------------------------------------- 5. Release
 inward.TimeScale=1;inward.Rate=0
 for _,e in {v.motes,v.wisps,v.ascending} do if e then e.TimeScale=1 end end
 audio:vacuum(1,.03)
 audio:impact(.55,.85);audio:impact(1,.45);audio:chime(.5,.35);audio:splash(.5,.35)
 audio:set("rise",0,.3);audio:set("hum",0,.8);audio:set("drone",.3,.2,.75)
 if not reduced then
  local sil=silhouette(D,{character,v.rock})
  D:wait(.14)
  sil:Destroy()
 end
 local burst=make("ParticleEmitter",core,{Texture=VFX.Sparkle,Rate=0,Speed=NumberRange.new(20,48),Drag=2,SpreadAngle=Vector2.new(180,180),Lifetime=NumberRange.new(.6,1.4),
  LightEmission=1,LightInfluence=0,Color=ColorSequence.new(Golden.WhiteHot,Golden.Gold),Size=seq(0,.6,1,0),Transparency=seq(0,0,1,1)})
 burst:Emit(reduced and 40 or 140)
 local shock={VFX.ring(folder,"GoldenShock",72,Golden.WhiteGold,.35,0,v.ground),VFX.ring(folder,"GoldenShock",72,Golden.Gold,.6,0,v.ground)}
 rock:surge(3);rock.flare=1
 local view=workspace.CurrentCamera.CFrame
 D:animate(.5,function(a,e)
  handle.level=smooth(a/.4)
  shock[1]:place(v.ground,2+70*smooth(a),0);shock[2]:place(v.ground,1.5+52*smooth(a),0)
  shock[1]:paint(Golden.WhiteGold,a);shock[2]:paint(Golden.Gold,a)
  bloom.Intensity=.7+2*a;bloom.Threshold=1.05-.4*a
  local k=reduced and 0 or math.max(0,1-e/.45)
  D:shoot(view*CFrame.new(math.sin(e*70)*.3*k,math.cos(e*60)*.25*k,0),38-9*(1-a)*(reduced and .2 or 1))
 end)
 handle.level=1
 ---------------------------------------------------------------- 6. Held in the light
 audio:layer("tail",Golden.Audio.Ambient,1.9,{eq={-20,-4,2},decay=5});audio:set("tail",.1,1.2)
 audio:chime(1.2,.12)
 D:wait(.6)
 audio:set("drone",.2,2,.62)
 pose:update(0,1)
 -- Called once the realm is ready: the world-side pieces of this scene are no longer needed.
 handle.settle=function()
  pose:destroy()
  grade:Destroy();bloom:Destroy();folder:Destroy()
  rock.focus=nil;rock.focusStrength=0;rock.flare=0
 end
 return handle
end
return RC
