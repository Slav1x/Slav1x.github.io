-- The blessing: the Pebble God crosses the water in a few unhurried steps, inclines, and
-- rests his hand on the player's head. Everything goes quiet. Then the familiar inner
-- view - and all ten meridians converge into the Golden Meridian in the chest, the same
-- point where the very first rebirth began. The overwhelming part is the power he allows
-- through, never effort on his side.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Golden=require(RS.Shared.GoldenMeridianConfig)
local VFX=require(script.Parent.AwakeningVFX)
local Pose=require(script.Parent.AwakeningPose)
local Meridians=require(script.Parent.AwakeningMeridians)
local make,seq,smooth=VFX.make,VFX.seq,VFX.smooth
local player=Players.LocalPlayer
local B={}
-- The golden aura the player carries out of the inner view (and into the ending).
local function aura(D,realm,character,root)
 local a={}
 local folder=make("Folder",realm.folder,{Name="GoldenAura"})
 a.highlight=make("Highlight",folder,{Adornee=character,FillColor=Golden.Gold,OutlineColor=Golden.WhiteGold,FillTransparency=1,OutlineTransparency=1,DepthMode=Enum.HighlightDepthMode.Occluded})
 a.orbiters={}
 for i=1,3 do
  local o=make("Part",folder,{Name="AuraOrbit",Size=Vector3.one*.1,Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,Transparency=1})
  local e=make("ParticleEmitter",o,{Texture=VFX.Sparkle,Rate=0,Lifetime=NumberRange.new(.6,1),Speed=NumberRange.new(0),LightEmission=1,LightInfluence=0,
   Color=ColorSequence.new(Golden.WhiteGold,Golden.Gold),Size=seq(0,.18,1,0),Transparency=seq(0,.1,1,1)})
  table.insert(a.orbiters,{part=o,emitter=e,phase=(i-1)*2.1,tilt=(i-1)*.9})
 end
 -- The water beneath the player glows: a soft disc drawn on the surface.
 local disc=make("Part",folder,{Name="WaterGlow",Size=Vector3.new(14,.05,14),Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,Transparency=1})
 local sg=make("SurfaceGui",disc,{Face=Enum.NormalId.Top,SizingMode=Enum.SurfaceGuiSizingMode.FixedSize,CanvasSize=Vector2.new(256,256),LightInfluence=0})
 a.glow=make("ImageLabel",sg,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Image=VFX.Soft,ImageColor3=Golden.Gold,ImageTransparency=1})
 a.disc=disc
 a.level=0
 local t=0
 D:every(function(dt)
  t+=dt
  local L=a.level
  a.highlight.FillTransparency=1-L*.14;a.highlight.OutlineTransparency=1-L*.55
  local p=root.Position
  disc.CFrame=CFrame.new(p.X,realm.floorY+.08,p.Z)
  a.glow.ImageTransparency=1-L*(.45+.1*math.sin(t*2))
  local list,frames={},{}
  for _,o in a.orbiters do
   local angle=t*1.6+o.phase
   table.insert(list,o.part)
   table.insert(frames,CFrame.new(p)*CFrame.Angles(o.tilt,0,0)*CFrame.new(math.cos(angle)*2.2,math.sin(angle*.5)*1.4,math.sin(angle)*2.2))
   o.emitter.Rate=30*L
  end
  workspace:BulkMoveTo(list,frames,Enum.BulkMoveMode.FireCFrameChanged)
 end)
 return a
end
B.aura=aura
function B.run(ctx)
 local D,realm,god,audio,dlg=ctx.D,ctx.realm,ctx.god,ctx.audio,ctx.dlg
 local reduced=D.reduced()
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local head=character and character:FindFirstChild("Head")
 if not root or not head then return false end
 local up=Vector3.yAxis
 local stand=root.Position
 local godFlat=(god.root.Position-stand)*Vector3.new(1,0,1)
 local facing=godFlat.Magnitude>.1 and godFlat.Unit or -realm.basis.LookVector
 local side=facing:Cross(up)
 local waterAt=function(p) return Vector3.new(p.X,realm.floorY,p.Z) end
 ---------------------------------------------------------------- he comes to you
 D:lockControls(true)
 root.CFrame=CFrame.lookAt(stand,stand+facing)
 local destination=CFrame.lookAt(waterAt(stand+facing*3.7),waterAt(stand))
 local mid=(stand+destination.Position)/2
 local twoShot=CFrame.lookAt(mid+side*17+up*1.6-facing*2,mid+up*4.5)
 local from=workspace.CurrentCamera.CFrame
 D:animate(1.2,function(a) D:shoot(from:Lerp(twoShot,D.inOut(a)),50) end)
 god:setLook(head.Position)
 god:setPose("rest",1)
 if not god:walkTo(D,destination,3.6,3) then return false end
 ---------------------------------------------------------------- his hand on your head
 local crown=head.Position+up*(head.Size.Y*.55)
 local pose=Pose.begin(character,realm.folder,root.CFrame)
 D:add(function() pose:destroy() end)
 local touchShot=CFrame.lookAt(stand+side*6.5+up*3.4+facing*.8,stand+up*3.4+facing*1.2)
 local ok=dlg:say(Golden.Speaker.God,Golden.Script.Blessing[1][1],{auto=2,onShow=function()
  god:reachTo(crown,.38)
 end})
 dlg:close()
 if not ok then return false end
 local camNow=workspace.CurrentCamera.CFrame
 D:spawn(function() D:animate(.9,function(a) pose:update(0,smooth(a)) end) end)
 -- Everything goes quiet: water, air, mist, stones.
 audio:set("water",.02,1.5);audio:set("wash",0,1.5);audio:set("air",0,1.5);audio:set("choir",.05,1.5);audio:set("bed",.05,1.5)
 audio:set("deep",.16,1.5)
 realm.mist.TimeScale=.15;god:freezeStones(true);realm:setPath(0)
 D:animate(2.6,function(a) D:shoot(camNow:Lerp(touchShot,D.inOut(a)),50-6*a) end)
 if not D.alive then return false end
 D:wait(.6)
 ---------------------------------------------------------------- inside: ten become one
 D:fadeTo(0,.6,Golden.WhiteGold)
 if not D.alive then return false end
 local inner=Meridians.create(D.gui,realm.folder,character,#require(RS.Shared.AwakeningConfig).Nodes,"golden")
 D:add(function() inner:destroy() end)
 local flash=make("Frame",D.gui,{Name="GoldenFlash",Size=UDim2.fromScale(1,1),BackgroundColor3=Golden.WhiteGold,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=55})
 D:add(flash)
 local T=Meridians.GoldenTimeline
 audio:layer("innerDeep",Golden.Audio.Ambient,.45,{eq={3,-3,-16},decay=4})
 audio:layer("innerRise",Golden.Audio.Ambient,1,{decay=2.5})
 audio:set("innerDeep",.24,2)
 local fired={}
 local function once(name,at,u,fn) if u>=at and not fired[name] then fired[name]=true;fn() end end
 D:spawn(function() D:fadeTo(1,.8) end)
 D:animate(T.finish,function(a,u)
  inner:golden(u,reduced)
  local cf,focus=inner:goldenCamera(u)
  D:shoot(cf,40,focus)
  for i=1,10 do once("pulse"..i,T.pulses+(i-1)*.2,u,function() audio:chime(.5+i*.06,.09) end) end
  once("together",T.pulses+2.2,u,function() audio:impact(.62,.16) end)
  once("converge",T.converge,u,function() audio:set("innerRise",.22,T.vacuum-T.converge,1.9) end)
  once("unstable",T.unstable,u,function() audio:impact(.38,.22) end)
  once("shift",T.shift,u,function() audio:chime(.9,.16) end)
  once("vacuum",T.vacuum,u,function() audio:vacuum(.02,.25);audio:set("innerRise",0,.2);audio:set("innerDeep",0,.25) end)
  once("activate",T.activate,u,function()
   audio:vacuum(1,.03);audio:impact(.45,.95);audio:impact(.8,.6);audio:chime(.42,.5)
   task.delay(.35,function() audio:chime(1.25,.2) end)
   audio:set("innerDeep",.18,1.5,.5)
  end)
  if u>=T.activate then
   local k=u-T.activate
   flash.BackgroundTransparency=reduced and 1-.4*math.max(0,1-k/.8) or math.clamp(k/1.2,0,1)
  end
 end)
 if not D.alive then return false end
 ---------------------------------------------------------------- back in the realm, carrying gold
 D:fadeTo(0,.6,Golden.WhiteGold)
 inner:hide()
 flash.BackgroundTransparency=1
 local glow=aura(D,realm,character,root)
 ctx.aura=glow
 pose:update(0,0)
 god:reachTo(nil)
 god.reach=nil
 god:setPose("rest",1.2)
 god:setEyes(.65) -- the smallest change in his expression
 god:setGlow(1)
 local after=CFrame.lookAt(stand-facing*7+side*5+up*3.2,stand+up*2.6)
 D:shoot(after,50)
 realm:flash(Golden.WhiteGold,.6)
 audio:set("water",.2,3);audio:set("bed",.18,3);audio:set("choir",.14,3);audio:set("deep",.12,3)
 D:spawn(function() D:fadeTo(1,1.4) end)
 -- The mist is pushed back by what just woke; the stones hang still, then breathe again.
 D:spawn(function()
  D:animate(1.5,function(a) glow.level=smooth(a);realm.mistLevel=math.max(.35,realm.mistLevel-.02) end)
  realm:ripple(realm:onWater(stand),60,3.5,Golden.Gold,.8)
  realm.mist.TimeScale=1
  D:wait(1.6)
  god:freezeStones(false)
 end)
 D:animate(3,function(a) D:shoot(after:Lerp(CFrame.lookAt(stand-facing*9+side*8+up*4,mid+up*4),D.inOut(a)),50) end)
 pose:destroy()
 return D.alive
end
return B
