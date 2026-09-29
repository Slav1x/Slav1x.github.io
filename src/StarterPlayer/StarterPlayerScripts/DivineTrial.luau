-- The Divine Skip Trial: one legendary skip across the Spirit Realm.
-- It LOOKS impossible and FEELS enormous, but any deliberate hold succeeds; only a
-- sub-tenth-second tap falls short, and even then the god simply says "Again."
-- The server judges the throw (GoldenMeridianService); this module is presentation.
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local RS=game:GetService("ReplicatedStorage")
local Golden=require(RS.Shared.GoldenMeridianConfig)
local VFX=require(script.Parent.AwakeningVFX)
local make,part,seq=VFX.make,VFX.part,VFX.seq
local player=Players.LocalPlayer
local Trial={}
local HOLD_KEYS={[Enum.KeyCode.E]=true,[Enum.KeyCode.Space]=true,[Enum.KeyCode.ButtonR2]=true,[Enum.KeyCode.ButtonX]=true,[Enum.KeyCode.ButtonA]=true}
local function smooth(a) a=math.clamp(a,0,1);return a*a*(3-2*a) end
local function throwAnimationId()
 local ok,id=pcall(function() return require(RS.Shared.ThrowConfig).Presentation.Input.AnimationId end)
 return ok and id or nil
end
---------------------------------------------------------------- the divine pebble
local function makePebble(folder)
 local p={}
 p.part=make("Part",folder,{Name="DivinePebble",Size=Vector3.new(1,.36,.76),Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,CastShadow=false,
  Material=Enum.Material.Marble,Color=Color3.fromRGB(226,220,206)})
 make("SpecialMesh",p.part,{MeshType=Enum.MeshType.Sphere})
 p.light=make("PointLight",p.part,{Color=Golden.Gold,Range=10,Brightness=2,Shadows=false})
 p.sparkle=make("ParticleEmitter",p.part,{Texture=VFX.Sparkle,Rate=14,Lifetime=NumberRange.new(.4,.8),Speed=NumberRange.new(.2,.8),SpreadAngle=Vector2.new(180,180),
  LightEmission=1,LightInfluence=0,Color=ColorSequence.new(Golden.WhiteGold,Golden.Gold),Size=seq(0,.12,1,0),Transparency=seq(0,.1,1,1)})
 p.band=VFX.ring(folder,"PebbleBand",20,Golden.Gold,.035,.1,CFrame.identity)
 -- Two orbiting sparks with trails wrap it in spirals of gold.
 p.orbits={}
 for i=1,2 do
  local o=make("Part",folder,{Name="PebbleOrbit",Size=Vector3.one*.1,Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,Transparency=1})
  local a0=make("Attachment",o,{Position=Vector3.new(0,.05,0)});local a1=make("Attachment",o,{Position=Vector3.new(0,-.05,0)})
  make("Trail",o,{Attachment0=a0,Attachment1=a1,Lifetime=.45,LightEmission=1,LightInfluence=0,MinLength=.02,FaceCamera=true,WidthScale=seq(0,1,1,0),
   Color=ColorSequence.new(Golden.WhiteHot,Golden.Gold),Transparency=seq(0,.1,1,1)})
  table.insert(p.orbits,{part=o,offset=(i-1)*math.pi})
 end
 p.flight=make("Trail",p.part,{Attachment0=make("Attachment",p.part,{Position=Vector3.new(0,.15,0)}),Attachment1=make("Attachment",p.part,{Position=Vector3.new(0,-.15,0)}),
  Lifetime=.6,LightEmission=1,LightInfluence=0,FaceCamera=true,Color=ColorSequence.new(Golden.WhiteHot,Golden.Gold),Transparency=seq(0,.2,1,1),WidthScale=seq(0,1,1,0),Enabled=false})
 local t=0
 function p:place(cf,dt,spin)
  t+=dt or 0
  self.part.CFrame=cf*CFrame.Angles(0,t*(spin or 1.2),0)
  self.band:place(cf*CFrame.Angles(0,t*(spin or 1.2),0),.48,0)
  local list,frames={},{}
  for _,o in self.orbits do
   local a=t*5+o.offset
   table.insert(list,o.part);table.insert(frames,cf*CFrame.new(math.cos(a)*.9,math.sin(t*3+o.offset)*.35,math.sin(a)*.9))
  end
  workspace:BulkMoveTo(list,frames,Enum.BulkMoveMode.FireCFrameChanged)
 end
 function p:setVisible(v)
  self.part.Transparency=v and 0 or 1;self.light.Enabled=v;self.sparkle.Enabled=v
  self.band:paint(Golden.Gold,v and .1 or 1)
 end
 return p
end
---------------------------------------------------------------- the trial
function Trial.run(ctx)
 local D,realm,god,audio,dlg=ctx.D,ctx.realm,ctx.god,ctx.audio,ctx.dlg
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local hum=character and character:FindFirstChildOfClass("Humanoid")
 if not root or not hum then return false end
 local folder=make("Folder",realm.folder,{Name="Trial"})
 local up=Vector3.yAxis
 local spot=realm:point(Golden.Realm.TrialSpot)
 local gate=realm:point(Golden.Realm.Gate)
 local dir=((gate-spot)*Vector3.new(1,0,1)).Unit
 local right=dir:Cross(up)
 local floorY=realm.floorY
 local function water(p) return Vector3.new(p.X,floorY+.1,p.Z) end
 ---------------------------------------------------------------- stand at the mark
 D:lockControls(true)
 hum:MoveTo(Vector3.new(spot.X,root.Position.Y,spot.Z))
 D:waitUntil(function() return ((root.Position-spot)*Vector3.new(1,0,1)).Magnitude<1.6 end,5)
 root.CFrame=CFrame.lookAt(Vector3.new(spot.X,root.Position.Y,spot.Z),Vector3.new(spot.X,root.Position.Y,spot.Z)+dir)
 root.AssemblyLinearVelocity=Vector3.zero
 local wide=CFrame.lookAt(spot-dir*16+right*4+up*5.2,spot+dir*30+up*2)
 local from=workspace.CurrentCamera.CFrame
 D:animate(1.4,function(a) D:shoot(from:Lerp(wide,D.inOut(a)),60) end)
 god:setLook(root.Position)
 ---------------------------------------------------------------- summon: the pebble rises from the water
 local pebble=makePebble(folder)
 pebble:setVisible(false)
 local pebbleSpot=water(spot+dir*3.5+right*1.2)
 local pebbleReady=false
 local held=true
 local function handCF()
  local hand=character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
  local base=hand and hand.CFrame or root.CFrame*CFrame.new(1.2,0,0)
  return CFrame.new(base.Position+root.CFrame.LookVector*.6+up*.5)
 end
 local function summon(quick)
  pebbleReady=false
  god:setPose("palm",quick and 2.4 or 1.4)
  if not D:wait(quick and .2 or .7) then return end
  -- The water under the mark trembles before anything rises.
  for i=1,quick and 3 or 7 do
   realm:ripple(pebbleSpot,.8+i*.35,.7,Golden.WhiteGold,.55)
   if not D:wait(.12) then return end
  end
  audio:impact(.34,.16);audio:chime(.52,.14)
  pebble:setVisible(true)
  local risen=pebbleSpot+up*3.2
  D:animate(quick and .9 or 1.8,function(a,e) pebble:place(CFrame.new(pebbleSpot:Lerp(risen,smooth(a))-up*(1-a)*1.2),1/60,3) end)
  local start=risen
  D:animate(quick and .6 or 1.1,function(a) pebble:place(CFrame.new(start:Lerp(handCF().Position,smooth(a))),1/60,2) end)
  god:setPose("rest",1.2)
  pebbleReady=true
 end
 local hover=D:every(function(dt)
  if held and pebbleReady then pebble:place(handCF()*CFrame.new(0,math.sin(os.clock()*2)*.08,0),dt,1.2) end
 end)
 ---------------------------------------------------------------- the path and the gate
 local plates={}
 local gateParts={}
 local ringCenter=water(gate)+up*10
 local gateRing=VFX.ring(folder,"GateRing",56,Golden.Gold,.22,1,CFrame.new(ringCenter))
 local pillarRoot=part(folder,"GateLight",Vector3.one,CFrame.new(water(gate)),Golden.WhiteGold,1)
 local g0=make("Attachment",pillarRoot,{Position=Vector3.new(0,.2,0)});local g1=make("Attachment",pillarRoot,{Position=Vector3.new(0,34,0)})
 local gateBeam=make("Beam",pillarRoot,{Attachment0=g0,Attachment1=g1,FaceCamera=true,LightEmission=1,LightInfluence=0,Width0=12,Width1=16,Segments=4,
  Texture=VFX.Soft,TextureMode=Enum.TextureMode.Stretch,Color=ColorSequence.new(Golden.WhiteHot,Golden.Gold),Transparency=NumberSequence.new(1)})
 local gateLight=make("PointLight",pillarRoot,{Color=Golden.Gold,Range=45,Brightness=0,Shadows=false})
 local gateReady=false
 local function raisePath()
  -- He lifts two fingers a few centimetres. A road of light runs to the horizon.
  god:setPose("twoFingers",1.3)
  if not D:wait(.9) then return end
  god:setPose("twoFingersUp",.9)
  if not D:wait(.35) then return end
  audio:chime(.45,.22);audio:impact(.3,.2)
  realm:flash(Golden.Gold,.35)
  local length=(gate-spot).Magnitude
  local count=30
  for i=1,count do
   local d=4+(length-10)*(i-1)/(count-1)
   local p=water(spot+dir*d)+up*.02
   table.insert(plates,part(folder,"GoldenRoad",Vector3.new(3.2,.05,length/count*.82),CFrame.lookAt(p,p+dir),Golden.Gold,1))
  end
  -- The mist parts along the road.
  D:spawn(function() D:animate(2.5,function(a) realm.mistLevel=1-.45*smooth(a) end) end)
  local rushStart=os.clock()
  local stopRush
  stopRush=D:every(function()
   local e=os.clock()-rushStart
   for i,p in plates do
    local arrive=(i-1)*.045
    local flashK=math.max(0,1-math.abs(e-arrive)/.25)
    local settled=e>=arrive and .78 or 1
    p.Transparency=math.min(settled,1-flashK*.9)
   end
   if e>count*.045+.4 then stopRush() end
  end)
  -- Stones rise out of the water to frame the light.
  for _,side in {-1,1} do
   local base=water(gate)+right*side*9
   local stone=make("Part",folder,{Name="GatePillar",Size=Vector3.new(6,34,6),Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,Material=Enum.Material.Slate,Color=Color3.fromRGB(108,106,102)})
   make("SpecialMesh",stone,{MeshType=Enum.MeshType.Sphere})
   table.insert(gateParts,{part=stone,base=base,final=base+up*15})
  end
  local lintel=make("Part",folder,{Name="GateStone",Size=Vector3.new(7,3.2,5),Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,Material=Enum.Material.Slate,Color=Color3.fromRGB(150,142,128)})
  make("SpecialMesh",lintel,{MeshType=Enum.MeshType.Sphere})
  table.insert(gateParts,{part=lintel,base=water(gate)-up*6,final=water(gate)+up*25})
  local reflect={}
  for _,g in gateParts do table.insert(reflect,g.part) end
  realm:reflect(reflect)
  local sheets=part(folder,"GateSheets",Vector3.new(24,2,8),CFrame.new(water(gate)),Golden.WhiteGold,1)
  local fall=make("ParticleEmitter",sheets,{Texture=VFX.Soft,Rate=0,Lifetime=NumberRange.new(1.2,2),Speed=NumberRange.new(2,5),EmissionDirection=Enum.NormalId.Top,Acceleration=Vector3.new(0,-14,0),
   LightEmission=.3,Color=ColorSequence.new(Color3.fromRGB(230,238,240)),Size=seq(0,1.5,1,4),Transparency=seq(0,.55,1,1)})
  fall:Emit(40)
  audio:impact(.26,.3)
  D:animate(2.4,function(a)
   local e=smooth(a)
   for _,g in gateParts do g.part.CFrame=CFrame.lookAt(g.base:Lerp(g.final,e)-up*(1-e)*18,g.base:Lerp(g.final,e)-up*(1-e)*18+dir) end
   gateBeam.Transparency=seq(0,1-.75*e,.7,1-.35*e,1,1)
   gateLight.Brightness=3*e
   gateRing:paint(Golden.Gold,1-.8*e);gateRing:place(CFrame.lookAt(ringCenter,ringCenter+dir)*CFrame.Angles(math.pi/2,0,0),7*e+.1,os.clock()*.4)
  end)
  god:setPose("rest",1)
  gateReady=true
 end
 local ringSpin=D:every(function()
  if gateReady then gateRing:place(CFrame.lookAt(ringCenter,ringCenter+dir)*CFrame.Angles(math.pi/2,0,0),7+.2*math.sin(os.clock()*1.4),os.clock()*.35) end
 end)
 for _,line in Golden.Script.Summon do
  local cue=line.cue
  local ok=dlg:say(Golden.Speaker.God,line[1],{onShow=function()
   if cue=="pebble" then summon(false) elseif cue=="path" then raisePath() end
  end})
  if not ok then return false end
 end
 dlg:close()
 if not D:waitUntil(function() return pebbleReady and gateReady end,12) then return D.alive end
 ---------------------------------------------------------------- one throw, as many times as needed
 local ui=make("Frame",D.gui,{Name="TrialMeter",AnchorPoint=Vector2.new(.5,1),Position=UDim2.fromScale(.5,.86),Size=UDim2.fromOffset(300,60),BackgroundTransparency=1,ZIndex=50,Visible=false})
 local track=make("Frame",ui,{AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,0),Size=UDim2.new(1,0,0,4),BackgroundColor3=Color3.fromRGB(40,32,20),BackgroundTransparency=.35,BorderSizePixel=0,ZIndex=50})
 make("UICorner",track,{CornerRadius=UDim.new(1,0)})
 local fillBar=make("Frame",track,{Size=UDim2.fromScale(0,1),BackgroundColor3=Golden.Gold,BorderSizePixel=0,ZIndex=51})
 make("UICorner",fillBar,{CornerRadius=UDim.new(1,0)})
 make("UIGradient",fillBar,{Color=ColorSequence.new(Golden.Amber,Golden.WhiteHot)})
 local hint=make("TextLabel",ui,{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,12),Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,Font=Enum.Font.Garamond,TextScaled=true,
  TextColor3=Golden.WhiteGold,TextTransparency=.1,ZIndex=50,Text=UIS.TouchEnabled and not UIS.KeyboardEnabled and "Hold anywhere to gather  ·  release to throw" or "Hold to gather  ·  release to throw"})
 local pad=make("TextButton",D.gui,{Name="TrialPad",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",AutoButtonColor=false,Selectable=false,ZIndex=49,Visible=false})
 local charging,chargeStart,released=false,0,nil
 local function beginCharge() if pad.Visible and not charging then charging=true;chargeStart=os.clock() end end
 local function endCharge() if charging then charging=false;released=math.clamp((os.clock()-chargeStart)/Golden.Trial.ChargeTime,0,1) end end
 D:connect(pad.InputBegan,function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then beginCharge() end end)
 D:connect(pad.InputEnded,function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then endCharge() end end)
 D:connect(UIS.InputBegan,function(input) if HOLD_KEYS[input.KeyCode] then beginCharge() end end)
 D:connect(UIS.InputEnded,function(input) if HOLD_KEYS[input.KeyCode] or input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then endCharge() end end)
 local animation=Instance.new("Animation");animation.AnimationId=throwAnimationId() or ""
 local animator=hum:FindFirstChildOfClass("Animator")
 local throwTrack
 if animator and animation.AnimationId~="" then pcall(function() throwTrack=animator:LoadAnimation(animation);throwTrack.Priority=Enum.AnimationPriority.Action end) end
 D:add(function() if throwTrack then throwTrack:Stop() end end)
 audio:layer("gather",Golden.Audio.Ambient,1,{decay=2})
 local attempt=0
 local succeeded=false
 while D.alive and not succeeded do
  attempt+=1
  released=nil
  ui.Visible=true;pad.Visible=true
  fillBar.Size=UDim2.fromScale(0,1)
  -- Gather.
  local cam0=wide
  local tension=D:every(function(dt)
   local fill=charging and math.clamp((os.clock()-chargeStart)/Golden.Trial.ChargeTime,0,1) or 0
   fillBar.Size=UDim2.fromScale(fill,1)
   hint.TextTransparency=charging and .6 or .1
   god:riseStones(.12*fill)
   audio:set("gather",.2*fill,.1,1+.6*fill)
   pebble.light.Brightness=2+6*fill
   D:shoot(cam0*CFrame.new(0,0,-2.5*smooth(fill)),60-4*fill)
   if charging and math.random()<dt*9 then realm:ripple(water(root.Position),1+fill*2.5,.6,Golden.WhiteGold,.35) end
  end)
  D:waitUntil(function() return released~=nil end)
  tension()
  if not D.alive then break end
  local charge=released
  ui.Visible=false;pad.Visible=false
  audio:set("gather",0,.4,1)
  god:riseStones(0)
  if throwTrack then throwTrack:Play(.05);task.delay(1.4,function() if throwTrack then throwTrack:Stop(.3) end end) end
  ctx.send("Throw",charge)
  local result=ctx.await("ThrowResult",3)
  local success=result~=nil and result.success==true
  held=false
  local start=pebble.part.Position
  pebble.flight.Enabled=true
  audio:chime(.9,.12)
  if success then
   succeeded=true
   ---------------------------------------------------------------- the skip that shakes the realm
   local points={}
   for i,d in Golden.Realm.Skips do points[i]=water(spot+dir*d) end
   points[#points]=ringCenter
   local heights={5,5.5,6.5,7,10,7}
   local durations={.55,.5,.52,.55,1.2,.85}
   local camPos=workspace.CurrentCamera.CFrame.Position
   local pebblePos=start
   local camSide=0
   local follow=D:every(function(dt)
    local k=1-math.exp(-dt*5)
    local wanted=pebblePos-dir*9+up*3.4+right*(2+camSide*9)
    camPos=camPos:Lerp(wanted,k)
    D:shoot(CFrame.lookAt(camPos,pebblePos+dir*5),62)
   end)
   local function hop(i,from,to)
    return D:animate(durations[i],function(a)
     local p=from:Lerp(to,a)+up*heights[i]*4*a*(1-a)
     if i==#durations then p=from:Lerp(to,a)+up*heights[i]*math.sin(a*math.pi)*.6 end
     pebblePos=p
     pebble:place(CFrame.lookAt(p,p+dir),1/60,6)
    end)
   end
   local previous=start
   for i,target in points do
    if i==5 then camSide=1 else camSide=0 end
    if not hop(i,previous,target) then break end
    previous=target
    if i==1 then
     -- 1. The water erupts.
     Trial.column(folder,target,1.4);realm:ripple(target,18,2,Color3.new(1,1,1),.8);audio:splash(.9,.5);audio:impact(.8,.18)
    elseif i==2 then
     -- 2. The mist splits apart.
     Trial.column(folder,target,1);Trial.mistSplit(folder,target,right);realm:ripple(target,24,2.2,Golden.WhiteGold,.7)
     D:spawn(function() D:animate(1.2,function(a) realm.mistLevel=.55-.3*smooth(a) end) end)
     audio:splash(.8,.45);audio:chime(.7,.2)
    elseif i==3 then
     -- 3. Golden lightning across the horizon.
     Trial.column(folder,target,1.1);realm:ripple(target,26,2.2,Golden.Gold,.7);audio:splash(.8,.45)
     Trial.lightning(D,folder,target,dir,right);realm:flash(Golden.Gold,.9)
     task.delay(.35,function() audio:impact(.32,.5) end)
    elseif i==4 then
     -- 4. Walls of water rise on either side.
     Trial.waves(D,folder,target,dir,right);realm:ripple(target,32,2.4,Golden.WhiteGold,.8);audio:splash(.6,.6);audio:impact(.5,.25)
    elseif i==5 then
     -- 5. The stones of the realm leave the water.
     Trial.column(folder,target,1.3);realm:ripple(target,36,2.6,Golden.Gold,.8);audio:splash(.55,.55);audio:impact(.28,.45)
     Trial.risingStones(D,folder,realm,target,dir);realm:liftMonoliths(26)
    end
   end
   follow()
   ---------------------------------------------------------------- 6. Through the light: a pillar to the sky
   pebble:setVisible(false);pebble.flight.Enabled=false
   local eye=water(gate)-dir*48+right*40+up*12
   D:shoot(CFrame.lookAt(eye,water(gate)+up*24),60)
   local column=part(folder,"GoldenPillar",Vector3.one,CFrame.new(water(gate)),Golden.WhiteHot,1)
   local c0=make("Attachment",column,{Position=Vector3.zero});local c1=make("Attachment",column,{Position=Vector3.new(0,600,0)})
   local outer=make("Beam",column,{Attachment0=c0,Attachment1=c1,FaceCamera=true,LightEmission=1,LightInfluence=0,Width0=26,Width1=14,Segments=4,Texture=VFX.Soft,TextureMode=Enum.TextureMode.Stretch,Color=ColorSequence.new(Golden.WhiteGold,Golden.Gold),Transparency=NumberSequence.new(1)})
   local inner=make("Beam",column,{Attachment0=c0,Attachment1=c1,FaceCamera=true,LightEmission=1,LightInfluence=0,Width0=7,Width1=4,Segments=4,Color=ColorSequence.new(Golden.WhiteHot),Transparency=NumberSequence.new(1)})
   local blaze=make("PointLight",column,{Color=Golden.Gold,Range=60,Brightness=0,Shadows=false})
   realm:ripple(water(gate),320,3.2,Golden.WhiteGold,.9)
   realm:ripple(water(gate),160,2.4,Golden.Gold,.8)
   realm:flash(Golden.WhiteHot,1.4)
   audio:impact(.5,.8);audio:impact(.9,.5);audio:chime(.45,.4)
   task.delay(.8,function() audio:chime(1.1,.14) end)
   D:spawn(function() D:animate(4,function(a) realm.mistLevel=.3+.5*smooth((a-.3)/.7) end) end)
   local view=workspace.CurrentCamera.CFrame
   D:animate(3.2,function(a,e)
    local k=math.max(0,1-e/.7)
    local grow=smooth(a/.25)
    outer.Transparency=seq(0,.1+.5*(1-grow),.6,.35+.3*(1-grow),1,1)
    inner.Transparency=seq(0,(1-grow)*.9,.7,.4,1,1)
    blaze.Brightness=10*grow*(1-.5*smooth((a-.5)/.5))
    D:shoot(view*CFrame.new(math.sin(e*55)*.35*k,math.cos(e*48)*.28*k,0),60-6*k)
   end)
   D:spawn(function() D:animate(3,function(a) outer.Transparency=seq(0,.6+.4*a,.6,.65+.35*a,1,1);inner.Transparency=seq(0,.4+.6*a,.7,.6+.4*a,1,1) end) end)
  else
   ---------------------------------------------------------------- not quite: the stone sinks, calmly returned
   local skipPoint=water(spot+dir*9)
   D:animate(.45,function(a) local p=start:Lerp(skipPoint,a)+up*2*4*a*(1-a);pebble:place(CFrame.new(p),1/60,4) end)
   realm:ripple(skipPoint,4,1.2,Color3.new(1,1,1),.5);audio:splash(1.3,.2)
   local sink=water(spot+dir*13)
   D:animate(.35,function(a) local p=skipPoint:Lerp(sink,a)+up*.8*4*a*(1-a);pebble:place(CFrame.new(p),1/60,4) end)
   D:animate(.6,function(a) pebble:place(CFrame.new(sink-up*a*3),1/60,1);pebble.part.Transparency=a end)
   pebble.flight.Enabled=false
   pebble:setVisible(false)
   local line=Golden.Script.Retry[math.min(attempt,#Golden.Script.Retry)]
   dlg:say(Golden.Speaker.God,line,{auto=1.4})
   dlg:close()
   held=true
   D:shoot(wide,60)
   summon(true)
  end
 end
 hover();ringSpin()
 ui:Destroy();pad:Destroy()
 audio:set("gather",0,.5)
 return succeeded and D.alive
end
---------------------------------------------------------------- spectacle pieces (temporary, self-cleaning)
function Trial.column(folder,position,scale)
 local p=make("Part",folder,{Name="Eruption",Size=Vector3.new(2,.2,2),CFrame=CFrame.new(position),Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,Transparency=1})
 local spray=make("ParticleEmitter",p,{Texture=VFX.Soft,Rate=0,EmissionDirection=Enum.NormalId.Top,SpreadAngle=Vector2.new(14,14),Lifetime=NumberRange.new(.8,1.4),Speed=NumberRange.new(16*scale,28*scale),
  Acceleration=Vector3.new(0,-38,0),Drag=.6,LightEmission=.25,Color=ColorSequence.new(Color3.fromRGB(236,244,246),Golden.WhiteGold),Size=seq(0,1.2*scale,1,3.5*scale),Transparency=seq(0,.35,1,1)})
 local drops=make("ParticleEmitter",p,{Texture=VFX.Sparkle,Rate=0,EmissionDirection=Enum.NormalId.Top,SpreadAngle=Vector2.new(60,60),Lifetime=NumberRange.new(.6,1.2),Speed=NumberRange.new(10,22),
  Acceleration=Vector3.new(0,-40,0),LightEmission=1,Color=ColorSequence.new(Golden.WhiteHot,Golden.Gold),Size=seq(0,.25,1,0),Transparency=seq(0,0,1,1)})
 spray:Emit(math.floor(30*scale));drops:Emit(math.floor(26*scale))
 task.delay(3,function() p:Destroy() end)
end
function Trial.mistSplit(folder,position,right)
 for _,side in {-1,1} do
  local p=make("Part",folder,{Name="MistSplit",Size=Vector3.new(4,3,30),CFrame=CFrame.lookAt(position+Vector3.yAxis*2,position+Vector3.yAxis*2+right*side),Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,Transparency=1})
  local e=make("ParticleEmitter",p,{Texture=VFX.Soft,Rate=0,Shape=Enum.ParticleEmitterShape.Box,ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume,EmissionDirection=Enum.NormalId.Front,
   SpreadAngle=Vector2.new(12,12),Lifetime=NumberRange.new(1.6,2.4),Speed=NumberRange.new(22,40),Drag=1.2,LightEmission=.3,LightInfluence=.5,
   Color=ColorSequence.new(Golden.Mist),Size=seq(0,8,1,22),Transparency=seq(0,.7,1,1),Rotation=NumberRange.new(0,360)})
  e:Emit(26)
  task.delay(3,function() p:Destroy() end)
 end
end
function Trial.lightning(D,folder,near,dir,right)
 local rng=Random.new()
 local bolts={}
 for b=1,4 do
  local base=near+dir*rng:NextNumber(250,420)+right*rng:NextNumber(-340,340)
  local top=base+Vector3.new(rng:NextNumber(-40,40),rng:NextNumber(170,260),rng:NextNumber(-40,40))
  local bottom=base+Vector3.new(0,rng:NextNumber(10,40),0)
  local previous=top
  for i=1,11 do
   local a=i/11
   local p=top:Lerp(bottom,a)+(i<11 and Vector3.new(rng:NextNumber(-14,14),0,rng:NextNumber(-14,14)) or Vector3.zero)
   local len=(p-previous).Magnitude
   table.insert(bolts,part(folder,"GoldenLightning",Vector3.new(.9,.9,len),CFrame.lookAt((p+previous)/2,p),i%3==0 and Golden.WhiteHot or Golden.Gold,1))
   previous=p
  end
 end
 D:spawn(function()
  for _,flicker in {{.0,.05},{.09,.35},{.2,0},{.26,.6}} do
   task.wait(flicker[1]==0 and 0 or .06)
   for _,p in bolts do p.Transparency=flicker[2] end
  end
  D:animate(.35,function(a) for _,p in bolts do p.Transparency=.6+.4*a end end)
  for _,p in bolts do p:Destroy() end
 end)
end
function Trial.waves(D,folder,position,dir,right)
 local walls={}
 for _,side in {-1,1} do
  for i=-3,3 do
   local base=position+right*side*(10+math.abs(i)*.9)+dir*i*3.4
   local w=make("Part",folder,{Name="SpiritWave",Size=Vector3.new(1.2,14,3.8),Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,CastShadow=false,
    Material=Enum.Material.Glass,Color=Color3.fromRGB(214,232,236),Transparency=.45})
   local crest=part(folder,"WaveCrest",Vector3.new(1.4,.25,3.9),CFrame.identity,Golden.WhiteGold,.2)
   table.insert(walls,{wall=w,crest=crest,base=base,side=side,delay=math.abs(i)*.06})
  end
 end
 D:spawn(function()
  D:animate(1.8,function(a,e)
   for _,w in walls do
    local k=math.clamp((e-w.delay)/1.4,0,1)
    local h=math.sin(k*math.pi)*14
    local lean=CFrame.Angles(0,0,-w.side*.25*math.sin(k*math.pi))
    local cf=CFrame.lookAt(w.base,w.base+dir)*CFrame.new(0,h-7,0)*lean
    w.wall.CFrame=cf
    w.crest.CFrame=cf*CFrame.new(0,7.1,0)
    w.crest.Transparency=.2+.8*(1-math.sin(k*math.pi))
   end
  end)
  for _,w in walls do w.wall:Destroy();w.crest:Destroy() end
 end)
end
function Trial.risingStones(D,folder,realm,position,dir)
 local rng=Random.new()
 local stones={}
 for i=1,8 do
  local offset=Vector3.new(rng:NextNumber(-50,50),0,rng:NextNumber(-50,50))
  if offset.Magnitude<14 then offset=offset.Unit*14 end
  local size=rng:NextNumber(2.5,7)
  local s=make("Part",folder,{Name="RisenStone",Size=Vector3.new(size,size*.55,size*.8),Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,Material=Enum.Material.Slate,Color=Color3.fromRGB(110+rng:NextInteger(-20,30),108,104)})
  make("SpecialMesh",s,{MeshType=Enum.MeshType.Sphere})
  local base=Vector3.new(position.X+offset.X,realm.floorY,position.Z+offset.Z)
  local stream=make("ParticleEmitter",s,{Texture=VFX.Soft,Rate=12,EmissionDirection=Enum.NormalId.Bottom,Lifetime=NumberRange.new(.6,1),Speed=NumberRange.new(1,3),Acceleration=Vector3.new(0,-30,0),
   LightEmission=.2,Color=ColorSequence.new(Color3.fromRGB(230,238,240)),Size=seq(0,.6,1,1.4),Transparency=seq(0,.5,1,1)})
  table.insert(stones,{part=s,base=base,height=rng:NextNumber(6,22),spin=CFrame.Angles(rng:NextNumber(-.5,.5),rng:NextNumber(0,6.28),rng:NextNumber(-.5,.5)),stream=stream,phase=rng:NextNumber(0,6.28)})
 end
 local list={}
 for _,s in stones do table.insert(list,s.part) end
 realm:reflect(list)
 local start=os.clock()
 D:every(function()
  local e=os.clock()-start
  for _,s in stones do
   local k=smooth(e/2.4)
   s.part.CFrame=CFrame.new(s.base+Vector3.new(0,-4+(s.height+4)*k+math.sin(e*.6+s.phase)*.5*k,0))*s.spin*CFrame.Angles(0,e*.1,0)
   s.stream.Rate=12*(1-smooth((e-1.5)/2))
  end
 end)
end
return Trial
