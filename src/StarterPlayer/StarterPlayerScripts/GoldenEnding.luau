-- The send-off and the "To Be Continued" card.
-- The god raises his hand a little; the water glows; light rises around the player until
-- the whole realm is gold; black; then the card. When World 2 exists, GoldenMeridianClient
-- skips the card (the server's World2Gateway teleports instead) - nothing here changes.
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local RS=game:GetService("ReplicatedStorage")
local Golden=require(RS.Shared.GoldenMeridianConfig)
local VFX=require(script.Parent.AwakeningVFX)
local make,seq,smooth=VFX.make,VFX.seq,VFX.smooth
local player=Players.LocalPlayer
local E={}
local function spaced(text) return (string.gsub(text,"(%S)","%1 ")) end
function E.sendOff(ctx)
 local D,realm,god,audio=ctx.D,ctx.realm,ctx.god,ctx.audio
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 if not root then return false end
 local up=Vector3.yAxis
 local p=root.Position
 local toGod=((god.root.Position-p)*Vector3.new(1,0,1)).Unit
 local side=toGod:Cross(up)
 local folder=make("Folder",realm.folder,{Name="SendOff"})
 god:setPose("send",1)
 D:shoot(CFrame.lookAt(p-toGod*9+side*6+up*3,p+toGod*3+up*3),52)
 D:wait(1.1)
 -- Light rises out of the water around the player.
 local ring=make("Part",folder,{Name="Ascension",Size=Vector3.new(7,.4,7),CFrame=CFrame.new(p.X,realm.floorY+.2,p.Z),Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,Transparency=1})
 local rising=make("ParticleEmitter",ring,{Texture=VFX.Sparkle,Rate=0,Shape=Enum.ParticleEmitterShape.Cylinder,ShapeStyle=Enum.ParticleEmitterShapeStyle.Surface,EmissionDirection=Enum.NormalId.Top,
  Lifetime=NumberRange.new(1.4,2.2),Speed=NumberRange.new(3,7),Acceleration=Vector3.new(0,4,0),LightEmission=1,LightInfluence=0,Color=ColorSequence.new(Golden.WhiteHot,Golden.Gold),Size=seq(0,.3,1,0),Transparency=seq(0,.1,1,1)})
 local veil=make("ParticleEmitter",ring,{Texture=VFX.Soft,Rate=0,Shape=Enum.ParticleEmitterShape.Cylinder,ShapeStyle=Enum.ParticleEmitterShapeStyle.Surface,EmissionDirection=Enum.NormalId.Top,
  Lifetime=NumberRange.new(1.6,2.4),Speed=NumberRange.new(2,4),LightEmission=.8,LightInfluence=0,Color=ColorSequence.new(Golden.WhiteGold,Golden.Gold),Size=seq(0,2,1,5),Transparency=seq(0,.7,1,1)})
 local spirals={}
 for i=1,2 do
  local o=make("Part",folder,{Name="Spiral",Size=Vector3.one*.1,Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,Transparency=1})
  local a0=make("Attachment",o,{Position=Vector3.new(0,.2,0)});local a1=make("Attachment",o,{Position=Vector3.new(0,-.2,0)})
  make("Trail",o,{Attachment0=a0,Attachment1=a1,Lifetime=1.2,LightEmission=1,LightInfluence=0,FaceCamera=true,Color=ColorSequence.new(Golden.WhiteHot,Golden.Gold),Transparency=seq(0,.1,1,1),WidthScale=seq(0,1,1,0)})
  table.insert(spirals,{part=o,phase=(i-1)*math.pi})
 end
 audio:layer("ascend",Golden.Audio.Ambient,1.2,{decay=4})
 audio:set("ascend",.24,3,1.7)
 audio:chime(.6,.2)
 local glow=ctx.aura
 local view=workspace.CurrentCamera.CFrame
 D:animate(3.4,function(a,e)
  local k=smooth(a)
  rising.Rate=20+80*k;veil.Rate=4+14*k
  if glow then glow.level=1;glow.highlight.FillTransparency=1-(.14+.8*k);glow.glow.ImageTransparency=.5-.4*k end
  local list,frames={},{}
  for _,s in spirals do
   local angle=e*4+s.phase
   table.insert(list,s.part);table.insert(frames,CFrame.new(p+Vector3.new(math.cos(angle)*2.4,(e*2.2)%7,math.sin(angle)*2.4)))
  end
  workspace:BulkMoveTo(list,frames,Enum.BulkMoveMode.FireCFrameChanged)
  if a>.45 then D:setFade(1-smooth((a-.45)/.55),Golden.WhiteGold) end
  D:shoot(view*CFrame.new(0,k*1.2,-k*2),52-6*k)
 end)
 if not D.alive then return false end
 D:setFade(0,Golden.WhiteGold)
 D:wait(.5)
 D:animate(.45,function(a) D.fade.BackgroundColor3=Golden.WhiteGold:Lerp(Color3.new(0,0,0),smooth(a)) end)
 audio:set("ascend",0,1.2);audio:world(0,.5)
 for _,name in {"water","wash","air","bed","deep","choir","drone","tail"} do audio:set(name,0,1.4) end
 return D.alive
end
-- Returns a handle; :dismiss() fades it away once the world is back.
function E.card(ctx)
 local audio=ctx.audio
 local gui=make("ScreenGui",player.PlayerGui,{Name="GoldenLanding",IgnoreGuiInset=true,ScreenInsets=Enum.ScreenInsets.None,ResetOnSpawn=false,DisplayOrder=1002,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 local bg=make("Frame",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0})
 local motes={}
 for i=1,28 do
  local m=make("ImageLabel",bg,{AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(10+math.random(0,10),10+math.random(0,10)),BackgroundTransparency=1,Image=VFX.Sparkle,
   ImageColor3=i%4==0 and Golden.WhiteGold or Golden.Gold,ImageTransparency=1})
  table.insert(motes,{label=m,x=math.random(),y=math.random(),speed=.01+math.random()*.02,phase=math.random()*6.28,alpha=.4+math.random()*.4})
 end
 local line=make("Frame",bg,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(0,0,0,1),BackgroundColor3=Golden.Gold,BorderSizePixel=0,BackgroundTransparency=.1})
 make("UIGradient",line,{Transparency=seq(0,1,.5,0,1,1)})
 local kicker=make("TextLabel",bg,{AnchorPoint=Vector2.new(.5,1),Position=UDim2.fromScale(.5,.44),Size=UDim2.fromScale(.8,.03),BackgroundTransparency=1,Text=spaced(Golden.Ending.Kicker),
  TextScaled=true,Font=Enum.Font.GothamMedium,TextColor3=Golden.Gold,TextTransparency=1})
 make("UITextSizeConstraint",kicker,{MaxTextSize=13,MinTextSize=8})
 local title=make("TextLabel",bg,{AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,.475),Size=UDim2.fromScale(.86,.1),BackgroundTransparency=1,Text=Golden.Ending.Title,
  TextScaled=true,Font=Enum.Font.Garamond,TextColor3=Golden.WhiteGold,TextTransparency=1,TextStrokeColor3=Golden.DeepGold,TextStrokeTransparency=1})
 make("UITextSizeConstraint",title,{MaxTextSize=64,MinTextSize=24})
 make("UIGradient",title,{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Golden.Gold),ColorSequenceKeypoint.new(.5,Golden.WhiteHot),ColorSequenceKeypoint.new(1,Golden.Gold)})})
 local scale=make("UIScale",title,{Scale=1.06})
 local footer=make("TextLabel",bg,{AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,.6),Size=UDim2.fromScale(.4,.028),BackgroundTransparency=1,Text=spaced(Golden.World2.Name),
  TextScaled=true,Font=Enum.Font.GothamMedium,TextColor3=Golden.WhiteGold,TextTransparency=1})
 make("UITextSizeConstraint",footer,{MaxTextSize=12,MinTextSize=8})
 local prompt=make("TextLabel",bg,{AnchorPoint=Vector2.new(.5,1),Position=UDim2.fromScale(.5,.95),Size=UDim2.fromScale(.4,.025),BackgroundTransparency=1,
  Text=UIS.TouchEnabled and not UIS.KeyboardEnabled and "tap to continue" or "click to continue",TextScaled=true,Font=Enum.Font.GothamMedium,TextColor3=Color3.fromRGB(150,130,96),TextTransparency=1})
 make("UITextSizeConstraint",prompt,{MaxTextSize=12,MinTextSize=8})
 local start=os.clock()
 local alive=true
 local fading=1
 local connection=game:GetService("RunService").RenderStepped:Connect(function()
  local t=os.clock()-start
  for _,m in motes do
   m.y=(m.y-m.speed*.016)
   if m.y<-.05 then m.y=1.05 end
   m.label.Position=UDim2.fromScale(m.x+.015*math.sin(t*.5+m.phase),m.y)
   m.label.ImageTransparency=1-m.alpha*smooth(t/2.5)*fading
  end
  line.Size=UDim2.new(.38*smooth((t-.6)/1.6),0,0,1)
  kicker.TextTransparency=1-smooth((t-1.4)/1.4)*fading
  title.TextTransparency=1-smooth((t-2.6)/1.8)*fading
  title.TextStrokeTransparency=1-.35*smooth((t-2.6)/1.8)*fading
  scale.Scale=1.06-.06*smooth((t-2.6)/3)
  footer.TextTransparency=1-.55*smooth((t-4.8)/1.6)*fading
  prompt.TextTransparency=1-.5*smooth((t-6)/1)*fading*(.7+.3*math.sin(t*2))
 end)
 if audio then
  task.delay(2.6,function() if alive then audio:chime(.5,.26) end end)
 end
 local handle={gui=gui}
 -- Waits for the player (or eleven seconds) once the title has had time to land.
 function handle:hold()
  local done=false
  local c1=bg.InputBegan:Connect(function(input) if os.clock()-start>4 and (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch) then done=true end end)
  local c2=UIS.InputBegan:Connect(function(input) if os.clock()-start>4 and (input.KeyCode==Enum.KeyCode.Space or input.KeyCode==Enum.KeyCode.Return or input.KeyCode==Enum.KeyCode.E or input.KeyCode==Enum.KeyCode.ButtonA or input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch) then done=true end end)
  while not done and os.clock()-start<11 do task.wait() end
  c1:Disconnect();c2:Disconnect()
 end
 function handle:dismiss(seconds)
  seconds=seconds or 1.2
  local from=os.clock()
  while os.clock()-from<seconds do
   local a=smooth((os.clock()-from)/seconds)
   fading=1-a
   bg.BackgroundTransparency=a
   task.wait()
  end
  alive=false
  connection:Disconnect()
  gui:Destroy()
 end
 function handle:destroy() if alive then alive=false;connection:Disconnect();gui:Destroy() end end
 return handle
end
return E
