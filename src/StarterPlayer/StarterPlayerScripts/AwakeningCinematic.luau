local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Lighting=game:GetService("Lighting")
local CAS=game:GetService("ContextActionService")
local StarterGui=game:GetService("StarterGui")
local Prompts=game:GetService("ProximityPromptService")
local Audio=require(script.Parent.AwakeningAudio)
local Pose=require(script.Parent.AwakeningPose)
local Meridians=require(script.Parent.AwakeningMeridians)
local VFX=require(script.Parent.AwakeningVFX)
local Config=require(RS.Shared.AwakeningConfig)
local player=Players.LocalPlayer
local event=RS:WaitForChild("AwakeningEvent")
local C={}
local function smooth(a) a=math.clamp(a,0,1);return a*a*(3-2*a) end
local function make(class,parent,props)
 local v=Instance.new(class);for k,value in props do v[k]=value end;v.Parent=parent;return v
end
function C.begin(packet,onFinished)
 local self={token=packet.token,alive=true,connections={},hidden={},coreGui={},locals={},committed=false}
 local char=player.Character
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 local root=char and char:FindFirstChild("HumanoidRootPart")
 local rock=workspace:FindFirstChild("MagicalRock")
 local anchor=rock and rock:FindFirstChild("InteractionAnchor")
 if not root or not hum or not anchor then event:FireServer("Cancel",packet.token);onFinished("The stone could not be reached.");return end
 local camera=workspace.CurrentCamera
 local saved={camera=camera,cf=camera.CFrame,focus=camera.Focus,fov=camera.FieldOfView,kind=camera.CameraType,subject=camera.CameraSubject,prompts=Prompts.Enabled}
 local gui=make("ScreenGui",player.PlayerGui,{Name="AwakeningCinema",IgnoreGuiInset=true,ScreenInsets=Enum.ScreenInsets.None,ClipToDeviceSafeArea=false,ResetOnSpawn=false,DisplayOrder=1000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 local folder=make("Folder",workspace,{Name="AwakeningLocalFX"})
 local blocker=make("TextButton",gui,{Name="InputShield",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",Modal=true,Active=true,Selectable=false,ZIndex=1})
 local top=make("Frame",gui,{Name="LetterboxTop",Size=UDim2.fromScale(1,0),BackgroundColor3=Color3.fromRGB(2,5,11),BorderSizePixel=0,ZIndex=15})
 local bottom=make("Frame",gui,{Name="LetterboxBottom",AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.fromScale(1,0),BackgroundColor3=Color3.fromRGB(2,5,11),BorderSizePixel=0,ZIndex=15})
 -- Hairline of light along the inner edge of each bar.
 for _,bar in {top,bottom} do
  local edge=make("Frame",bar,{Name="Edge",AnchorPoint=Vector2.new(0,bar==top and 0 or 1),Position=UDim2.fromScale(0,bar==top and 1 or 0),Size=UDim2.new(1,0,0,1),BorderSizePixel=0,BackgroundColor3=Config.Blue,BackgroundTransparency=.55,ZIndex=15})
  make("UIGradient",edge,{Transparency=VFX.seq(0,1,.5,0,1,1)})
 end
 local subtitle=make("TextLabel",gui,{Name="Whisper",Position=UDim2.fromScale(.1,.9),Size=UDim2.fromScale(.8,.075),Text="",TextScaled=true,TextColor3=Config.Ice,TextStrokeColor3=Config.Blue,TextStrokeTransparency=.82,TextTransparency=1,BackgroundTransparency=1,Font=Enum.Font.GothamMedium,ZIndex=16})
 make("UITextSizeConstraint",subtitle,{MaxTextSize=18,MinTextSize=10})
 local skip=make("TextButton",gui,{Name="Skip",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(.97,0,.025,0),Size=UDim2.fromOffset(150,44),BackgroundTransparency=1,Text=game:GetService("UserInputService").TouchEnabled and "Skip" or "Skip · Space / B",TextColor3=Color3.fromRGB(162,185,205),TextSize=13,Font=Enum.Font.GothamMedium,ZIndex=22,Visible=false})
 local fade=make("Frame",gui,{Name="Fade",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(2,6,15),BorderSizePixel=0,BackgroundTransparency=0,ZIndex=20})
 local flash=make("Frame",gui,{Name="BlueImpact",Size=UDim2.fromScale(1,1),BackgroundColor3=Config.Ice,BorderSizePixel=0,BackgroundTransparency=1,ZIndex=19})
 local tint=make("ColorCorrectionEffect",Lighting,{Name="AwakeningColor",TintColor=Color3.new(1,1,1),Saturation=0,Contrast=0,Brightness=0})
 local bloom=make("BloomEffect",Lighting,{Name="AwakeningBloom",Intensity=.15,Size=26,Threshold=1.1})
 local palm=rock:FindFirstChild("PalmContact")
 if not (palm and palm:IsA("BasePart")) then palm=anchor end
 local controls
 -- This game can use the new character controller without a legacy PlayerModule.
 -- Never wait for an optional control module while the screen is covered.
 local playerModule=player.PlayerScripts:FindFirstChild("PlayerModule")
 if playerModule then pcall(function() controls=require(playerModule):GetControls() end) end
 local controlsWereEnabled=controls and controls.controlsEnabled~=false
 if controlsWereEnabled then controls:Disable() end
 player:SetAttribute("RebirthCutscene",true)
 Prompts.Enabled=false
 for _,kind in {Enum.CoreGuiType.Backpack,Enum.CoreGuiType.PlayerList,Enum.CoreGuiType.Chat,Enum.CoreGuiType.EmotesMenu,Enum.CoreGuiType.Health} do
  pcall(function() self.coreGui[kind]=StarterGui:GetCoreGuiEnabled(kind);StarterGui:SetCoreGuiEnabled(kind,false) end)
 end
 local function hide(g)
  if g:IsA("ScreenGui") and g~=gui and self.hidden[g]==nil then
   self.hidden[g]=g.Enabled;g.Enabled=false
   table.insert(self.connections,g:GetPropertyChangedSignal("Enabled"):Connect(function()
    if self.alive and g.Enabled then g.Enabled=false end
   end))
  end
 end
 for _,g in player.PlayerGui:GetDescendants() do hide(g) end
 table.insert(self.connections,player.PlayerGui.DescendantAdded:Connect(hide))
 for _,p in char:GetDescendants() do if p:IsA("BasePart") then self.locals[p]=p.LocalTransparencyModifier end end
 local audio,pose,inner,fx
 -- The tenth awakening completes the blue network and lingers on what comes after it.
 local final=packet.count==Config.FinalAwakening
 local returnAfter=final and Meridians.FinaleTimeline.finish or 1.1
 local anomaly={}
 local function anomalySound(name,id,speed,volume,looped)
  local bus=game:GetService("SoundService"):FindFirstChild("AwakeningMix")
  local s=Instance.new("Sound");s.Name=name;s:SetAttribute("AwakeningAudio",true)
  s.SoundId=id;s.PlaybackSpeed=speed;s.Volume=volume;s.Looped=looped==true;s.SoundGroup=bus
  local r=Instance.new("ReverbSoundEffect");r.DecayTime=3.2;r.WetLevel=-8;r.DryLevel=-2;r.Parent=s
  s.Parent=game:GetService("SoundService");s:Play();table.insert(anomaly,s)
  return s
 end
 local restoredCamera=false
 local function restoreCamera()
  if restoredCamera then return end;restoredCamera=true
  local cam=workspace.CurrentCamera
  if cam then
   cam.CameraType=saved.kind;cam.FieldOfView=saved.fov;cam.CFrame=saved.cf;cam.Focus=saved.focus
   local currentHum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
   cam.CameraSubject=saved.subject and saved.subject:IsDescendantOf(workspace) and saved.subject or currentHum
  end
 end
 function self:destroy(reason,sendCancel)
  if not self.alive then return end;self.alive=false
  for _,c in self.connections do c:Disconnect() end
  CAS:UnbindAction("AwakeningBlock");CAS:UnbindAction("AwakeningSkip")
  if pose then pose:destroy() end
  if audio then audio:finish(.65) end
  restoreCamera()
  -- The custom character controller does not always replace a dead camera subject.
  if hum.Health<=0 or player.Character~=char then
   local function follow(newCharacter)
    local nextHum=newCharacter:WaitForChild("Humanoid",8)
    if nextHum and not player:GetAttribute("RebirthCutscene") then
     local cam=workspace.CurrentCamera
     if cam then cam.CameraType=Enum.CameraType.Custom;cam.CameraSubject=nextHum;cam.FieldOfView=saved.fov end
    end
   end
   if player.Character and player.Character~=char then task.defer(follow,player.Character)
   else
    local respawn=player.CharacterAdded:Once(follow)
    task.delay(15,function() respawn:Disconnect() end)
   end
  end
  for p,value in self.locals do if p.Parent then p.LocalTransparencyModifier=value end end
  for g,enabled in self.hidden do if g.Parent then g.Enabled=enabled end end
  for kind,enabled in self.coreGui do pcall(function() StarterGui:SetCoreGuiEnabled(kind,enabled) end) end
  Prompts.Enabled=saved.prompts
  if controlsWereEnabled and controls then controls:Enable() end
  player:SetAttribute("RebirthCutscene",false)
  player:SetAttribute("AwakeningPhase",nil)
  if fx then pcall(fx.destroy,fx) end
  if inner then pcall(inner.destroy,inner) end
  for _,s in anomaly do s:Destroy() end
  for _,object in {gui,folder,tint,bloom} do object:Destroy() end
  if sendCancel then event:FireServer("Cancel",self.token) else event:FireServer("Finish",self.token) end
  onFinished(reason)
 end
 local function requestSkip()
  if not self.alive or not self.started or workspace:GetServerTimeNow()-self.started<Config.SkipAfter or self.skipRequested then return end
  self.skipRequested=true;skip.Text="Returning…";event:FireServer("Skip",self.token)
 end
 CAS:BindActionAtPriority("AwakeningBlock",function() return Enum.ContextActionResult.Sink end,false,3000,unpack(Enum.PlayerActions:GetEnumItems()))
 CAS:BindActionAtPriority("AwakeningSkip",function(_,state) if state==Enum.UserInputState.Begin then requestSkip() end;return Enum.ContextActionResult.Sink end,false,3001,Enum.KeyCode.Space,Enum.KeyCode.ButtonB)
 table.insert(self.connections,skip.Activated:Connect(requestSkip))
 table.insert(self.connections,player.CharacterRemoving:Connect(function() self:destroy(nil,true) end))
 table.insert(self.connections,hum.Died:Connect(function() self:destroy(nil,true) end))
 table.insert(self.connections,workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() self:destroy(nil,true) end))
 -- Construct everything before acknowledging the server; failed setup never resets progression.
 local ok,err=xpcall(function()
  audio=Audio.begin()
  local contact=rock:FindFirstChild("PalmContact")
  pose=Pose.begin(char,folder,contact and contact.CFrame or anchor.CFrame)
  fx=VFX.create({gui=gui,folder=folder,character=char,root=root,rock=rock,anchor=anchor,palm=palm,final=final,reduced=function() return player:GetAttribute("ReducedMotion")==true end})
  inner=Meridians.create(gui,folder,char,packet.count)
 end,debug.traceback)
 if not ok then warn("[Awakening] setup",err);self:destroy("The scene could not load. Please try again.",true);return end
 local basis=root.CFrame
 local function point(x,y,z) return basis:PointToWorldSpace(Vector3.new(x,y,z)) end
 local function shot(x,y,z,tx,ty,tz) return CFrame.lookAt(point(x,y,z),point(tx,ty,tz)) end
 local wide=shot(8,5,9,0,1,-1.7)
 local medium=shot(5,2.8,3,0,.9,-1.3)
 local contact=shot(4.8,2.4,-1.2,.2,1,-1.1)
 local chest=shot(.1,.8,-4,0,.7,0)
 local dive=shot(0,.7,-.8,0,.7,0)
 local returnShot=shot(4,2.2,-5,0,.6,0)
 local seen={}
 local impactAt=-math.huge
 local function cue(name,at,t)
  if t>=at and not seen[name] then seen[name]=true;audio:cue(name);fx:cue(name,t);if name=="transfer" then impactAt=t end end
 end
 local NIGHT=Color3.fromRGB(2,6,15)
 local DEEP=Color3.fromRGB(6,22,52)
 local RELEASE=final and Color3.fromRGB(255,244,222) or Color3.fromRGB(214,240,255)
 local lastLine,lineAt="",0
 function self:play(at) if self.alive and not self.started then self.started=at end end
 function self:complete(data)
  if not self.alive or self.committed then return end
  self.committed=true;self.completedAt=workspace:GetServerTimeNow();self.skipped=data.skipped
  audio:cue("activate")
 end
 local connection
 connection=Run.RenderStepped:Connect(function()
  if not self.alive then return end
  local success,message=xpcall(function()
   if not char.Parent or not root.Parent or hum.Health<=0 then self:destroy(nil,true);return end
   if not self.started then camera.CameraType=Enum.CameraType.Scriptable;camera.CFrame=wide;return end
   local t=math.max(0,workspace:GetServerTimeNow()-self.started)
   local reduced=player:GetAttribute("ReducedMotion")==true
   local since=self.completedAt and workspace:GetServerTimeNow()-self.completedAt or nil
   skip.Visible=t>=Config.SkipAfter and not self.committed
   gui:SetAttribute("SequenceTime",t)
   local cf=wide
   local fov=52
   local focus=CFrame.new(point(0,.8,0))
   local phase="Establishing"
   local reach=smooth((t-1.65)/2.5)
   local eyes=smooth((t-3.9)/.6)
   local charge=smooth((t-6.55)/4.05)
   if not self.committed then charge=math.min(charge,.97) end
   local inInner,out=false,nil
   local line=""
   fade.BackgroundColor3=NIGHT
   fade.BackgroundTransparency=smooth(t/.7)
   flash.BackgroundTransparency=1
   if since and (self.skipped or since>=returnAfter) then
    out=since-(self.skipped and 0 or returnAfter)
    phase="Returning"
    inner:hide()
    if not seen.release then seen.release=true;fx:cue("return",t) end
    cf=returnShot:Lerp(medium,smooth(out/2.6))
    reach=1-smooth(out/1.3);eyes=1-smooth(out/.8)
    line=self.skipped and "Your awakening is complete." or final and "Something is different." or "Carry this light with you."
    -- Burst out of the body on a bright release, then settle into the world.
    if out<.35 then fade.BackgroundColor3=(self.skipped or reduced) and NIGHT or RELEASE end
    fade.BackgroundTransparency=out<.35 and smooth(out/.35) or out<1.8 and 1 or 1-smooth((out-1.8)/.45)
    if out>=2.25 then
     restoreCamera();fade.BackgroundTransparency=smooth((out-2.25)/.65)
     if out>=2.9 then self:destroy();return end
    end
    if not seen.fadeAudio then seen.fadeAudio=true;audio:finish(2.4) end
    if self.anomalyDrone then self.anomalyDrone.Volume*=.9 end
   elseif t>=6.35 then
    phase=self.committed and "Activated" or "InnerMeridians"
    inInner=true
    inner:update(t,charge,self.committed,reduced)
    cf,focus=inner:camera(t,charge);fov=40
    line=Config.innerLine(packet.count,self.committed)
    if final and since then
     -- Finale: the full network, a low tone no one has heard before, a spark of gold.
     local fin=since-Meridians.FinaleTimeline.reveal
     if fin>=.3 then line="Ten paths." end
     if fin>=2.9 then line="…" end
     if fin>=.9 and not seen.anomaly then
      seen.anomaly=true
      self.anomalyDrone=anomalySound("Awakening_Anomaly",Config.Audio.Ambient,.34,0,true)
     end
     if self.anomalyDrone then self.anomalyDrone.Volume=.3*smooth((fin-.9)/1.6)*(1-smooth((fin-3.9)/.5)) end
     for i,at_ in Meridians.FinaleTimeline.pulses do
      if since>=at_ and not seen["pulse"..i] then seen["pulse"..i]=true;anomalySound("Awakening_TenPulse",Config.Audio.Impact,.48+i*.05,.16+i*.03) end
     end
     if since>=Meridians.FinaleTimeline.spark and not seen.spark then seen.spark=true;anomalySound("Awakening_GoldenSpark",Config.Audio.Chime,.62,.2) end
    end
    fade.BackgroundColor3=DEEP
    fade.BackgroundTransparency=smooth((t-6.35)/.5)
    if since then
     flash.BackgroundTransparency=1-(reduced and .1 or .6)*(1-math.clamp(since/.38,0,1))
    end
   elseif t>=5.4 then
    phase="IntoTheBody";cf=chest:Lerp(dive,smooth((t-5.4)/1.05));fov=48
    line="Breathe."
    fade.BackgroundColor3=DEEP
    fade.BackgroundTransparency=1-smooth((t-6.02)/.33)
   elseif t>=2.1 then
    phase=t>=4.2 and "Contact" or "Reach";cf=medium:Lerp(contact,smooth((t-2.1)/2.3))
    fov=52-4*smooth((t-2.1)/2.3)
    line=t>=4.2 and "The stone remembers." or "Let go of what was."
   else
    cf=wide:Lerp(medium,smooth(t/2.1));line=player.DisplayName.."…"
   end
   if not since then
    cue("contact",4.15,t);cue("transfer",5.35,t);cue("inner",6.4,t)
    local hit=math.max(0,1-(t-impactAt)/.3)
    flash.BackgroundTransparency=1-hit*(reduced and .08 or .5)
    if not reduced and hit>0 then cf*=CFrame.new(math.sin(t*90)*.09*hit,math.cos(t*85)*.06*hit,0)*CFrame.Angles(0,0,math.sin(t*60)*.012*hit) end
   end
   -- Subtitles ease in on every new line instead of snapping.
   if line~=lastLine then lastLine=line;lineAt=t;subtitle.Text=line end
   subtitle.TextTransparency=1-smooth((t-lineAt)/.45)
   -- Letterbox bars glide in with the takeover and out as the world returns.
   local bars=.105*smooth(t/.9)
   if out then bars*=1-smooth((out-1.9)/.35) end
   top.Size=UDim2.fromScale(1,bars);bottom.Size=UDim2.fromScale(1,bars)
   -- Grading: cool and slightly desaturated in the world, rich and glowing inside the body.
   local grade=(phase=="Returning" and math.max(0,1-(since or 0)/2.5) or smooth(t))
   tint.TintColor=Color3.new(1,1,1):Lerp(Color3.fromRGB(185,217,255),grade*(inInner and .25 or .45))
   tint.Saturation=inInner and .1 or -.25*grade;tint.Contrast=(inInner and .14 or .08)*grade;tint.Brightness=0
   if inInner then bloom.Intensity=.45+charge*.6;bloom.Size=34;bloom.Threshold=.92
   else bloom.Intensity=.18+charge*.22+(since and 0 or math.max(0,1-(t-impactAt)/.4)*.8);bloom.Size=26;bloom.Threshold=1.1 end
   fx:update({t=t,cam=camera,phase=phase,reach=reach,charge=charge,inner=inInner,since=since,out=out,skipped=self.skipped,tint=tint})
   if not restoredCamera then
    fov+=fx.fovOffset
    camera.CameraType=Enum.CameraType.Scriptable;camera.CFrame=cf;camera.FieldOfView=fov+(camera.ViewportSize.X<camera.ViewportSize.Y and 18 or 0)
    camera.Focus=focus
   end
   for p in self.locals do if p.Parent and p.Name~="HumanoidRootPart" then p.LocalTransparencyModifier=0 end end
   pose:update(reach,eyes)
   audio:update(phase=="InnerMeridians" and charge or 0,t)
   player:SetAttribute("AwakeningPhase",phase);gui:SetAttribute("Phase",phase)
  end,debug.traceback)
  if not success then warn("[Awakening] render",message);self:destroy("The scene was interrupted.",true) end
 end)
 table.insert(self.connections,connection)
 task.delay(Config.Timeout+2,function() if self.alive then self:destroy("Returned safely to the world.",true) end end)
 event:FireServer("Ready",self.token)
 return self
end
return C