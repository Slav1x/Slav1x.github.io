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
 local top=make("Frame",gui,{Name="LetterboxTop",Size=UDim2.fromScale(1,.105),BackgroundColor3=Color3.fromRGB(2,5,11),BorderSizePixel=0,ZIndex=15})
 local bottom=make("Frame",gui,{Name="LetterboxBottom",Position=UDim2.fromScale(0,.895),Size=UDim2.fromScale(1,.105),BackgroundColor3=Color3.fromRGB(2,5,11),BorderSizePixel=0,ZIndex=15})
 local subtitle=make("TextLabel",gui,{Name="Whisper",Position=UDim2.fromScale(.1,.9),Size=UDim2.fromScale(.8,.075),Text="",TextScaled=true,TextColor3=Config.Ice,BackgroundTransparency=1,Font=Enum.Font.GothamMedium,ZIndex=16})
 make("UITextSizeConstraint",subtitle,{MaxTextSize=18,MinTextSize=10})
 local skip=make("TextButton",gui,{Name="Skip",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(.97,0,.025,0),Size=UDim2.fromOffset(150,44),BackgroundTransparency=1,Text=game:GetService("UserInputService").TouchEnabled and "Skip" or "Skip · Space / B",TextColor3=Color3.fromRGB(162,185,205),TextSize=13,Font=Enum.Font.GothamMedium,ZIndex=22,Visible=false})
 local fade=make("Frame",gui,{Name="Fade",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(2,6,15),BorderSizePixel=0,BackgroundTransparency=0,ZIndex=20})
 local flash=make("Frame",gui,{Name="BlueImpact",Size=UDim2.fromScale(1,1),BackgroundColor3=Config.Ice,BorderSizePixel=0,BackgroundTransparency=1,ZIndex=19})
 local tint=make("ColorCorrectionEffect",Lighting,{Name="AwakeningColor",TintColor=Color3.new(1,1,1),Saturation=0,Contrast=0,Brightness=0})
 local bloom=make("BloomEffect",Lighting,{Name="AwakeningBloom",Intensity=.15,Size=26,Threshold=1.1})
 local glow=make("PointLight",anchor,{Name="AwakeningContactLight",Color=Config.Blue,Range=14,Brightness=0})
 local aura=make("Attachment",root,{Name="AwakeningAura"})
 local heart=make("Attachment",root,{Name="AwakeningHeart",Position=Vector3.new(0,.65,-.45)})
 local palm=rock:FindFirstChild("PalmContact") or anchor
 local origin=make("Attachment",palm,{Name="AwakeningTransferOrigin"})
 local transfer=make("Beam",origin,{Name="PowerTransfer",Attachment0=origin,Attachment1=heart,FaceCamera=true,Color=ColorSequence.new(Config.Ice,Config.Blue),LightEmission=1,Width0=.16,Width1=.055,Segments=12,CurveSize0=.7,CurveSize1=-.3,Enabled=false})
 local transferGlow=make("Beam",origin,{Name="PowerTransferGlow",Attachment0=origin,Attachment1=heart,FaceCamera=true,Color=ColorSequence.new(Config.Blue),LightEmission=1,Width0=.4,Width1=.18,Segments=12,CurveSize0=.7,CurveSize1=-.3,Transparency=NumberSequence.new(.7),Enabled=false})
 local particles=make("ParticleEmitter",aura,{Name="Afterglow",Texture="rbxasset://textures/particles/sparkles_main.dds",Rate=0,Lifetime=NumberRange.new(.8,1.6),Speed=NumberRange.new(.4,2),Drag=1,SpreadAngle=Vector2.new(180,180),LightEmission=1,Color=ColorSequence.new(Config.Blue,Config.Ice),Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.08),NumberSequenceKeypoint.new(.3,.17),NumberSequenceKeypoint.new(1,0)})})
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
 local audio,pose,inner
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
  for _,object in {gui,folder,tint,bloom,glow,aura,heart,origin} do object:Destroy() end
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
  inner=Meridians.create(gui,char,packet.count)
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
  if t>=at and not seen[name] then seen[name]=true;audio:cue(name);if name=="transfer" then impactAt=t end end
 end
 function self:play(at) if self.alive and not self.started then self.started=at end end
 function self:complete(data)
  if not self.alive or self.committed then return end
  self.committed=true;self.completedAt=workspace:GetServerTimeNow();self.skipped=data.skipped
  audio:cue("activate");particles:Emit(player:GetAttribute("ReducedMotion")==true and 8 or 22)
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
   local phase="Establishing"
   local reach=smooth((t-1.65)/2.5)
   local eyes=smooth((t-3.9)/.6)
   local charge=smooth((t-6.55)/4.05)
   if not self.committed then charge=math.min(charge,.97) end
   fade.BackgroundTransparency=smooth(t/.7)
   flash.BackgroundTransparency=1
   if since and (self.skipped or since>=1.1) then
    local out=since-(self.skipped and 0 or 1.1)
    phase="Returning"
    inner:hide()
    cf=returnShot:Lerp(medium,smooth(out/2.6))
    reach=1-smooth(out/1.3);eyes=1-smooth(out/.8)
    subtitle.Text=self.skipped and "Your awakening is complete." or "Carry this light with you."
    fade.BackgroundTransparency=out<.35 and smooth(out/.35) or out<1.8 and 1 or 1-smooth((out-1.8)/.45)
    if out>=2.25 then
     restoreCamera();fade.BackgroundTransparency=smooth((out-2.25)/.65)
     if out>=2.9 then self:destroy();return end
    end
    if not seen.fadeAudio then seen.fadeAudio=true;audio:finish(2.4) end
   elseif t>=6.35 then
    phase=self.committed and "Activated" or "InnerMeridians"
    inner:update(t,charge,self.committed)
    cf=dive;fov=43
    subtitle.Text=self.committed and "The first light is yours." or "One quiet point. A greater possibility."
    fade.BackgroundTransparency=smooth((t-6.35)/.5)
    if since then
     flash.BackgroundTransparency=1-(reduced and .1 or .6)*(1-math.clamp(since/.38,0,1))
    end
   elseif t>=5.4 then
    phase="IntoTheBody";cf=chest:Lerp(dive,smooth((t-5.4)/1.05));fov=48
    subtitle.Text="Breathe."
    fade.BackgroundTransparency=1-smooth((t-6.02)/.33)
   elseif t>=2.1 then
    phase=t>=4.2 and "Contact" or "Reach";cf=medium:Lerp(contact,smooth((t-2.1)/2.3))
    fov=52-4*smooth((t-2.1)/2.3)
    subtitle.Text=t>=4.2 and "The stone remembers." or "Let go of what was."
   else
    cf=wide:Lerp(medium,smooth(t/2.1));subtitle.Text=player.DisplayName.."…"
   end
   if not since then
    cue("contact",4.15,t);cue("transfer",5.35,t);cue("inner",6.4,t)
    local hit=math.max(0,1-(t-impactAt)/.3)
    flash.BackgroundTransparency=1-hit*(reduced and .08 or .48)
    if not reduced and hit>0 then cf*=CFrame.new(math.sin(t*90)*.04*hit,math.cos(t*85)*.025*hit,0) end
   end
   if not restoredCamera then
    camera.CameraType=Enum.CameraType.Scriptable;camera.CFrame=cf;camera.FieldOfView=fov+(camera.ViewportSize.X<camera.ViewportSize.Y and 18 or 0)
    camera.Focus=CFrame.new(point(0,.8,0))
   end
   for p in self.locals do if p.Parent and p.Name~="HumanoidRootPart" then p.LocalTransparencyModifier=0 end end
   pose:update(reach,eyes)
   transfer.Enabled=t>=5.12 and t<6.35 and not self.skipped;transferGlow.Enabled=transfer.Enabled
   if transfer.Enabled then transfer.Transparency=NumberSequence.new(.1+.5*math.clamp((t-5.6)/.75,0,1)) end
   local grade=(phase=="Returning" and math.max(0,1-(since or 0)/2.5) or smooth(t))
   tint.TintColor=Color3.new(1,1,1):Lerp(Color3.fromRGB(185,217,255),grade*.45)
   tint.Saturation=-.25*grade;tint.Contrast=.08*grade
   bloom.Intensity=.18+charge*.22;glow.Brightness=(.4+charge*1.6)*grade
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