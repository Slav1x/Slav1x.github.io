-- Lifecycle for one golden sequence. Waits and animations stop the moment the sequence
-- is aborted (death, server release, error), and every camera, control, GUI and instance
-- change is undone by close(), which always runs exactly once.
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local CAS=game:GetService("ContextActionService")
local StarterGui=game:GetService("StarterGui")
local Prompts=game:GetService("ProximityPromptService")
local Golden=require(game:GetService("ReplicatedStorage").Shared.GoldenMeridianConfig)
local player=Players.LocalPlayer
local D={}
D.__index=D
local function smooth(a) a=math.clamp(a,0,1);return a*a*(3-2*a) end
local function inOut(a) a=math.clamp(a,0,1);return a<.5 and 4*a*a*a or 1-(-2*a+2)^3/2 end
local function outCubic(a) a=math.clamp(a,0,1);return 1-(1-a)^3 end
D.smooth,D.inOut,D.outCubic=smooth,inOut,outCubic
local function make(class,parent,props)
 local v=Instance.new(class);for k,value in props do v[k]=value end;v.Parent=parent;return v
end
D.make=make
function D.reduced() return player:GetAttribute("ReducedMotion")==true end
function D.new(name)
 return setmetatable({name=name,alive=true,closed=false,cleanups={},connections={},hidden={},coreGui={}},D)
end
function D:add(item) table.insert(self.cleanups,item);return item end
function D:connect(signal,fn) local c=signal:Connect(fn);table.insert(self.connections,c);return c end
function D:fail(err)
 warn("[Golden] "..self.name..": "..tostring(err))
 self:abort("error")
end
function D:abort(reason)
 if not self.alive then return end
 self.alive=false;self.reason=reason or "aborted"
 if self.onAbort then task.spawn(self.onAbort,self.reason) end
end
-- Yields `seconds`. Returns false if the sequence was aborted meanwhile.
function D:wait(seconds)
 local finish=os.clock()+seconds
 repeat task.wait() until not self.alive or os.clock()>=finish
 return self.alive
end
function D:waitUntil(predicate,timeout)
 local finish=os.clock()+(timeout or math.huge)
 while self.alive and os.clock()<finish do
  if predicate() then return true end
  task.wait()
 end
 return false
end
-- Calls fn(alpha, elapsed) every rendered frame for `seconds`, then returns true.
function D:animate(seconds,fn)
 local start=os.clock()
 while self.alive do
  local elapsed=os.clock()-start
  local alpha=seconds>0 and math.clamp(elapsed/seconds,0,1) or 1
  local ok,err=pcall(fn,alpha,elapsed)
  if not ok then self:fail(err);return false end
  if alpha>=1 then return true end
  Run.RenderStepped:Wait()
 end
 return false
end
-- A per-frame job that runs until stopped or until the sequence ends.
function D:every(fn)
 local connection
 connection=Run.RenderStepped:Connect(function(dt)
  if not self.alive then connection:Disconnect();return end
  local ok,err=pcall(fn,dt)
  if not ok then connection:Disconnect();self:fail(err) end
 end)
 table.insert(self.connections,connection)
 return function() connection:Disconnect() end
end
function D:spawn(fn,...)
 local args=table.pack(...)
 task.spawn(function()
  local ok,err=pcall(fn,table.unpack(args,1,args.n))
  if not ok then self:fail(err) end
 end)
end
---------------------------------------------------------------- scene ownership
local function controlModule()
 local module=player.PlayerScripts:FindFirstChild("PlayerModule")
 local controls
 if module then pcall(function() controls=require(module):GetControls() end) end
 return controls
end
function D:takeScene()
 local camera=workspace.CurrentCamera
 self.camera=camera
 self.saved={kind=camera.CameraType,subject=camera.CameraSubject,fov=camera.FieldOfView,prompts=Prompts.Enabled}
 self.controls=controlModule()
 self.controlsWereEnabled=self.controls and self.controls.controlsEnabled~=false
 self:lockControls(true)
 player:SetAttribute("GoldenCutscene",true)
 for _,kind in {Enum.CoreGuiType.Backpack,Enum.CoreGuiType.PlayerList,Enum.CoreGuiType.EmotesMenu,Enum.CoreGuiType.Health} do
  pcall(function() self.coreGui[kind]=StarterGui:GetCoreGuiEnabled(kind);StarterGui:SetCoreGuiEnabled(kind,false) end)
 end
 local gui=make("ScreenGui",player.PlayerGui,{Name="GoldenCinema",IgnoreGuiInset=true,ScreenInsets=Enum.ScreenInsets.None,ClipToDeviceSafeArea=false,ResetOnSpawn=false,DisplayOrder=1001,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 self.gui=gui
 local function hide(g)
  if g:IsA("ScreenGui") and g~=gui and g.Name~="GoldenLanding" and self.hidden[g]==nil then
   self.hidden[g]=g.Enabled;g.Enabled=false
   table.insert(self.connections,g:GetPropertyChangedSignal("Enabled"):Connect(function()
    if self.alive and g.Enabled and self.hidden[g]~=nil then g.Enabled=false end
   end))
  end
 end
 for _,g in player.PlayerGui:GetChildren() do hide(g) end
 self:connect(player.PlayerGui.ChildAdded,hide)
 self.top=make("Frame",gui,{Name="LetterboxTop",Size=UDim2.fromScale(1,0),BackgroundColor3=Color3.fromRGB(4,4,6),BorderSizePixel=0,ZIndex=40})
 self.bottom=make("Frame",gui,{Name="LetterboxBottom",AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.fromScale(1,0),BackgroundColor3=Color3.fromRGB(4,4,6),BorderSizePixel=0,ZIndex=40})
 for _,bar in {self.top,self.bottom} do
  local edge=make("Frame",bar,{Name="Edge",AnchorPoint=Vector2.new(0,bar==self.top and 0 or 1),Position=UDim2.fromScale(0,bar==self.top and 1 or 0),Size=UDim2.new(1,0,0,1),BorderSizePixel=0,BackgroundColor3=Golden.Gold,BackgroundTransparency=.6,ZIndex=40})
  make("UIGradient",edge,{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(1,1)})})
 end
 self.fade=make("Frame",gui,{Name="Fade",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=60})
 self.subtitleLabel=make("TextLabel",gui,{Name="Subtitle",AnchorPoint=Vector2.new(.5,1),Position=UDim2.fromScale(.5,.965),Size=UDim2.fromScale(.8,.05),BackgroundTransparency=1,
  Text="",TextScaled=true,Font=Enum.Font.Garamond,TextColor3=Golden.WhiteGold,TextTransparency=1,TextStrokeColor3=Golden.DeepGold,TextStrokeTransparency=.85,ZIndex=45})
 make("UITextSizeConstraint",self.subtitleLabel,{MaxTextSize=22,MinTextSize=12})
end
function D:lockControls(locked)
 self.controlsLocked=locked
 if locked then
  if self.controls then pcall(function() self.controls:Disable() end) end
  CAS:BindActionAtPriority("GoldenBlock",function() return Enum.ContextActionResult.Sink end,false,2900,table.unpack(Enum.PlayerActions:GetEnumItems()))
  local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
  if hum then hum:Move(Vector3.zero,false) end
 else
  CAS:UnbindAction("GoldenBlock")
  if self.controls then pcall(function() self.controls:Enable() end) end
 end
end
function D:setPrompts(enabled) Prompts.Enabled=enabled end
function D:portraitBoost()
 local view=self.camera.ViewportSize
 return view.X<view.Y and 18 or 0
end
function D:shoot(cf,fov,focus)
 local camera=self.camera
 camera.CameraType=Enum.CameraType.Scriptable
 camera.CFrame=cf
 if fov then camera.FieldOfView=fov+self:portraitBoost() end
 if focus then camera.Focus=focus end
end
-- Hand the camera back to the player (it follows their humanoid again).
function D:freeCamera()
 local camera=self.camera
 local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 camera.CameraType=Enum.CameraType.Custom
 if hum then camera.CameraSubject=hum end
 camera.FieldOfView=self.saved.fov
end
function D:setFade(transparency,color)
 self.fade.BackgroundTransparency=transparency
 if color then self.fade.BackgroundColor3=color end
end
function D:fadeTo(transparency,seconds,color)
 if color then self.fade.BackgroundColor3=color end
 local from=self.fade.BackgroundTransparency
 return self:animate(seconds,function(a) self.fade.BackgroundTransparency=from+(transparency-from)*smooth(a) end)
end
function D:setBars(amount)
 local h=.1*amount
 self.top.Size=UDim2.fromScale(1,h);self.bottom.Size=UDim2.fromScale(1,h)
end
function D:bars(amount,seconds)
 local from=self.top.Size.Y.Scale/.1
 return self:animate(seconds,function(a) self:setBars(from+(amount-from)*smooth(a)) end)
end
-- A quiet line under the picture (not the Pebble God's voice, which uses GoldenDialogue).
function D:subtitle(text,hold)
 local label=self.subtitleLabel
 self:spawn(function()
  label.Text=text
  self:animate(.5,function(a) label.TextTransparency=1-smooth(a) end)
  if hold then
   self:wait(hold)
   self:animate(.6,function(a) label.TextTransparency=smooth(a) end)
  end
 end)
end
-- Undo everything, once. Safe to call after an abort.
function D:close()
 if self.closed then return end
 self.closed=true
 self.alive=false
 for i=#self.cleanups,1,-1 do
  local item=self.cleanups[i]
  local ok,err=pcall(function()
   if typeof(item)=="Instance" then item:Destroy()
   elseif type(item)=="function" then item()
   elseif type(item)=="table" and item.destroy then item:destroy() end
  end)
  if not ok then warn("[Golden] cleanup: "..tostring(err)) end
 end
 for _,c in self.connections do c:Disconnect() end
 if self.saved then
  CAS:UnbindAction("GoldenBlock")
  if self.controls and self.controlsWereEnabled then pcall(function() self.controls:Enable() end) end
  for g,enabled in self.hidden do if g.Parent then g.Enabled=enabled end end
  for kind,enabled in self.coreGui do pcall(function() StarterGui:SetCoreGuiEnabled(kind,enabled) end) end
  Prompts.Enabled=self.saved.prompts
  local camera=workspace.CurrentCamera
  if camera then
   local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
   camera.CameraType=Enum.CameraType.Custom
   if hum then camera.CameraSubject=hum end
   camera.FieldOfView=self.saved.fov
  end
  player:SetAttribute("GoldenCutscene",false)
 end
 if self.gui then self.gui:Destroy() end
end
return D
