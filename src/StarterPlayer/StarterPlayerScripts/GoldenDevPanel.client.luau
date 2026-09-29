-- STUDIO ONLY: a small panel for replaying every rebirth cutscene and every Golden
-- Meridian stage without earning them again. Does nothing outside Studio.
local RunService=game:GetService("RunService")
if not RunService:IsStudio() then return end
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
-- The panel always appears; if the server half is missing it says so instead of hiding.
local remote=RS:FindFirstChild("GoldenDevTools")
task.spawn(function() remote=remote or RS:WaitForChild("GoldenDevTools",60) end)
print("[GoldenDev] panel starting")
-- Load dependencies lazily: a missing module shows up as a message on the panel
-- instead of silently stopping this script before the button exists.
local loadErrors={}
local function load(label,get)
 local ok,result=pcall(get)
 if not ok then table.insert(loadErrors,label..": "..tostring(result));warn("[GoldenDev] "..label..": "..tostring(result)) end
 return ok and result or nil
end
local AwakeningConfig=load("ReplicatedStorage.Shared.AwakeningConfig",function() return require(RS:WaitForChild("Shared"):WaitForChild("AwakeningConfig",5)) end)
local nodeCount=AwakeningConfig and #AwakeningConfig.Nodes or 10
local activationTime=AwakeningConfig and AwakeningConfig.ActivationTime or 10.6
local Cinematic
local function cinematic()
 Cinematic=Cinematic or load("StarterPlayerScripts.AwakeningCinematic",function() return require(script.Parent:WaitForChild("AwakeningCinematic",5)) end)
 return Cinematic
end
local player=Players.LocalPlayer
local busy=false
local gui=Instance.new("ScreenGui")
gui.Name="GoldenDevPanel";gui.ResetOnSpawn=false;gui.DisplayOrder=10000;gui.IgnoreGuiInset=true;gui.Parent=player.PlayerGui
local toggle=Instance.new("TextButton")
toggle.AnchorPoint=Vector2.new(0,1);toggle.Size=UDim2.fromOffset(110,26);toggle.Position=UDim2.new(0,8,1,-8);toggle.Text="GOLDEN DEV";toggle.Font=Enum.Font.GothamBold;toggle.TextSize=12
toggle.BackgroundColor3=Color3.fromRGB(40,30,14);toggle.TextColor3=Color3.fromRGB(255,210,120);toggle.Parent=gui
local panel=Instance.new("Frame")
panel.AnchorPoint=Vector2.new(0,1);panel.Size=UDim2.fromOffset(300,424);panel.Position=UDim2.new(0,8,1,-40);panel.BackgroundColor3=Color3.fromRGB(18,16,14);panel.BackgroundTransparency=.08;panel.Visible=false;panel.Parent=gui
Instance.new("UICorner",panel).CornerRadius=UDim.new(0,8)
local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,4);layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Parent=panel
local pad=Instance.new("UIPadding");pad.PaddingTop=UDim.new(0,8);pad.PaddingLeft=UDim.new(0,8);pad.PaddingRight=UDim.new(0,8);pad.Parent=panel
local status=Instance.new("TextLabel")
local order=0
local function label(text)
 order+=1
 local l=Instance.new("TextLabel");l.Size=UDim2.new(1,0,0,16);l.BackgroundTransparency=1;l.Text=text;l.Font=Enum.Font.GothamBold;l.TextSize=11
 l.TextColor3=Color3.fromRGB(255,200,110);l.TextXAlignment=Enum.TextXAlignment.Left;l.LayoutOrder=order;l.Parent=panel
end
local function row()
 order+=1
 local r=Instance.new("Frame");r.Size=UDim2.new(1,0,0,26);r.BackgroundTransparency=1;r.LayoutOrder=order;r.Parent=panel
 local l=Instance.new("UIListLayout");l.FillDirection=Enum.FillDirection.Horizontal;l.Padding=UDim.new(0,4);l.Parent=r
 return r
end
local function button(parent,text,width,fn)
 local b=Instance.new("TextButton");b.Size=UDim2.fromOffset(width,24);b.Text=text;b.Font=Enum.Font.GothamMedium;b.TextSize=11
 b.BackgroundColor3=Color3.fromRGB(52,44,32);b.TextColor3=Color3.fromRGB(240,230,210);b.AutoButtonColor=true;b.Parent=parent
 Instance.new("UICorner",b).CornerRadius=UDim.new(0,4)
 b.Activated:Connect(function()
  if busy then status.Text="Busy…";return end
  busy=true
  local ok,err=pcall(fn)
  if not ok then status.Text=tostring(err) end
  busy=false
 end)
end
local function call(action,value)
 if not remote then
  status.Text="✗ Server dev tools not found. Check ServerScriptService has the Script 'GoldenMeridian' (not inside 'Server') and 'Server' contains the ModuleScript 'GoldenDevTools'. Look for red errors in Output."
  return false
 end
 local ok,message=remote:InvokeServer(action,value)
 status.Text=(ok and "✓ " or "✗ ")..tostring(message or action)
 return ok
end
-- Plays the real cutscene locally without touching progression.
local function preview(n)
 local Cinematic=cinematic()
 if not Cinematic then status.Text="✗ Could not load AwakeningCinematic. "..table.concat(loadErrors," | ");return end
 if not call("stance") then return end
 task.wait(.3)
 local scene=Cinematic.begin({token="preview-"..n,count=n},function() end)
 if scene then
  scene:play(workspace:GetServerTimeNow()+.15)
  local completeAt=os.clock()+.3+activationTime
  while scene.alive do
   if not scene.committed and (os.clock()>=completeAt or scene.skipRequested) then scene:complete({skipped=scene.skipRequested==true,count=n}) end
   task.wait()
  end
 end
 call("unstance")
 status.Text="Previewed rebirth "..n
end
label("SETUP")
local r0=row()
button(r0,"Skip tutorial",140,function() call("skipTutorial") end)
button(r0,"Show state",140,function() call("state") end)
label("PREVIEW A REBIRTH CUTSCENE (no progress)")
local r1,r2=row(),row()
for n=1,nodeCount do button(n<=5 and r1 or r2,tostring(n),52,function() preview(n) end) end
label("REAL REBIRTHS (changes this Studio save)")
local r3=row()
button(r3,"Ready next",90,function() call("readyRebirth") end)
button(r3,"Set 0",60,function() call("setRebirths",0) end)
button(r3,"Set 9",60,function() call("setRebirths",9) end)
button(r3,"Set 10",60,function() call("setRebirths",10) end)
label("GOLDEN MERIDIAN")
local r4=row()
button(r4,"Stone speech",140,function() call("resetGolden",false) end)
button(r4,"Calling",140,function() call("resetGolden",true) end)
local r5=row()
button(r5,"Start trial",140,function() if call("resetGolden",true) then task.wait(.5);call("beginGolden") end end)
button(r5,"Unfinished ending",140,function() if call("grantGolden",false) then task.wait(.5);call("beginGolden") end end)
local r6=row()
button(r6,"Memory visit",140,function() if call("grantGolden",true) then task.wait(.5);call("beginGolden") end end)
local r7=row()
button(r7,"Fast dialogue: off",284,function() end)
local fastButton=r7:FindFirstChildOfClass("TextButton")
fastButton.Activated:Connect(function()
 local on=not (player:GetAttribute("GoldenDevFast")==true)
 player:SetAttribute("GoldenDevFast",on)
 fastButton.Text="Fast dialogue: "..(on and "on" or "off")
end)
order+=1
status.Size=UDim2.new(1,0,0,48);status.BackgroundTransparency=1;status.TextWrapped=true;status.Font=Enum.Font.Code;status.TextSize=11
status.TextColor3=Color3.fromRGB(200,200,190);status.TextXAlignment=Enum.TextXAlignment.Left;status.TextYAlignment=Enum.TextYAlignment.Top;status.Text="Studio only."
status.LayoutOrder=order;status.Parent=panel
if #loadErrors>0 then status.Text="✗ "..table.concat(loadErrors," | ") end
print("[GoldenDev] panel ready - GOLDEN DEV button is at the bottom left")
toggle.Activated:Connect(function() panel.Visible=not panel.Visible end)
