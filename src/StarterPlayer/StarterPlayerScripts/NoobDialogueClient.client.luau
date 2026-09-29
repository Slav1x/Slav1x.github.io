local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Tween=game:GetService("TweenService")
local player=Players.LocalPlayer
local remote=RS:WaitForChild("NoobDialogue")
local Remotes=require(RS.Shared.Remotes)
local gui=Instance.new("ScreenGui")
gui.Name="NoobConversation";gui.ResetOnSpawn=false;gui.DisplayOrder=140;gui.Enabled=false;gui.Parent=player.PlayerGui
gui.IgnoreGuiInset=true;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
-- Consume mouse/touch input across the entire viewport, including empty space
-- outside the scrolling panel. ThrowInput also enforces the modal for gamepad.
local blocker=Instance.new("TextButton",gui)
blocker.Name="ModalInputBlocker";blocker.Size=UDim2.fromScale(1,1)
blocker.BackgroundTransparency=1;blocker.Text="";blocker.AutoButtonColor=false
blocker.Active=true;blocker.Selectable=false;blocker.Modal=true;blocker.ZIndex=1
local panel=Instance.new("Frame",gui)
panel.Active=true;panel.ZIndex=2
panel.Name="Dialogue";panel.AnchorPoint=Vector2.new(.5,1);panel.Position=UDim2.new(.5,0,1,-20)
panel.Size=UDim2.fromOffset(620,470);panel.BackgroundColor3=Color3.fromRGB(10,28,48);panel.BorderSizePixel=0
local round=Instance.new("UICorner",panel);round.CornerRadius=UDim.new(0,18)
local rim=Instance.new("UIStroke",panel);rim.Color=Color3.fromRGB(241,196,81);rim.Thickness=3
local scale=Instance.new("UIScale",panel)
local function label(name,parent,text,pos,size,fontSize)
 local l=Instance.new("TextLabel",parent);l.Name=name;l.BackgroundTransparency=1;l.Text=text
 l.Position=pos;l.Size=size;l.TextColor3=Color3.fromRGB(238,245,253);l.TextSize=fontSize
 l.Font=Enum.Font.GothamMedium;l.TextWrapped=true;l.TextXAlignment=Enum.TextXAlignment.Left;l.TextYAlignment=Enum.TextYAlignment.Top
 return l
end
local title=label("Speaker",panel,"NOOB  /  REBIRTH GUIDE",UDim2.fromOffset(24,20),UDim2.fromOffset(535,30),21)
title.Font=Enum.Font.FredokaOne;title.TextColor3=Color3.fromRGB(255,221,109)
local message=label("Reply",panel,"",UDim2.fromOffset(24,66),UDim2.fromOffset(572,105),18)
local content=Instance.new("ScrollingFrame",panel)
content.Name="Choices";content.Position=UDim2.fromOffset(22,188);content.Size=UDim2.fromOffset(576,258)
content.BackgroundTransparency=1;content.BorderSizePixel=0;content.ScrollBarThickness=4
content.AutomaticCanvasSize=Enum.AutomaticSize.Y;content.CanvasSize=UDim2.new()
local layout=Instance.new("UIListLayout",content);layout.Padding=UDim.new(0,8);layout.SortOrder=Enum.SortOrder.LayoutOrder
local busy=false;local generation=0;local token=nil
local hidden={};local playerListEnabled
local hudNames={MainHUD=true,ProgressionFeedback=true,SpinTrainingGui=true,CoreTutorialUI=true,HotbarGui=true,SummonAutoUI=true,SummonAreaNavigation=true,ThrowHud=true,TouchControls=true}
local function showHUD(show)
 local starter=game:GetService("StarterGui")
 if show then
  for g,enabled in hidden do if g.Parent then g.Enabled=enabled end end
  table.clear(hidden)
  if playerListEnabled~=nil then pcall(function() starter:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,playerListEnabled) end) end
  playerListEnabled=nil
 else
  for _,g in player.PlayerGui:GetChildren() do if g:IsA("ScreenGui") and hudNames[g.Name] and hidden[g]==nil then hidden[g]=g.Enabled;g.Enabled=false end end
  pcall(function() playerListEnabled=starter:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList);starter:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false) end)
 end
end
local function clear() for _,c in content:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end content.CanvasPosition=Vector2.zero end
local function button(text,callback,color,parent)
 local b=Instance.new("TextButton",parent or content);b.Name=text:gsub("[^%w]","")
 b.Size=UDim2.new(1,-8,0,42);b.BackgroundColor3=color or Color3.fromRGB(27,76,112);b.BorderSizePixel=0
 b.Text=text;b.TextSize=17;b.Font=Enum.Font.GothamBold;b.TextColor3=Color3.new(1,1,1);b.AutoButtonColor=true
 local c=Instance.new("UICorner",b);c.CornerRadius=UDim.new(0,9)
 b.Activated:Connect(function() if not busy then callback() end end)
 return b
end
local function close()
 generation+=1;gui.Enabled=false;busy=false;token=nil;showHUD(true)
 player:SetAttribute("NoobDialogueOpen",false)
 task.spawn(function() pcall(function() remote:InvokeServer("cancel") end) end)
end
local closeButton=button("×",close,nil,panel);closeButton.Name="Close"
closeButton.AnchorPoint=Vector2.new(1,.5)
closeButton.Position=UDim2.new(1,-12,0,35);closeButton.Size=UDim2.fromOffset(46,46)
closeButton.BackgroundColor3=Color3.new(1,1,1);closeButton.Text="X"
closeButton.Font=Enum.Font.FredokaOne;closeButton.TextSize=30
closeButton.TextStrokeColor3=Color3.fromRGB(8,11,17);closeButton.TextStrokeTransparency=0
closeButton.UICorner.CornerRadius=UDim.new(0,12)
local closeGradient=Instance.new("UIGradient",closeButton)
closeGradient.Color=ColorSequence.new(Color3.fromRGB(255,94,89),Color3.fromRGB(210,30,48))
closeGradient.Rotation=90
local closeOutline=Instance.new("UIStroke",closeButton)
closeOutline.Color=Color3.fromRGB(8,11,17);closeOutline.Thickness=3
closeOutline.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
local menu,ask
local function fit()
 local v=workspace.CurrentCamera.ViewportSize
 scale.Scale=math.min(1,(v.X-24)/620,(v.Y-32)/470)
end
local function showRebirth(result)
 clear();token=result.token
 message.Text="REBIRTH "..result.current.." → "..result.next.."\n"..(result.ready and "Ready when you are. Read what changes before confirming." or result.reason)
 local lines={result.benefit,"", "REQUIREMENTS"}
 for _,r in result.requirements do table.insert(lines,(r.met and "✓ " or "• ")..r.label) end
 table.insert(lines,"\nRESETS\n"..result.resets);table.insert(lines,"\nKEEPS\n"..result.keeps)
 local detail=label("ExactRebirthDetails",content,table.concat(lines,"\n"),UDim2.new(),UDim2.new(1,-12,0,0),17)
 detail.AutomaticSize=Enum.AutomaticSize.Y
 if result.ready then
  button("CONFIRM REBIRTH",function()
   if not token then return end
   local receipt=token;token=nil;busy=true
   message.Text="Confirming your Rebirth…"
   Remotes.RequestRebirth:FireServer(receipt)
   local g=generation
   task.delay(8,function() if gui.Enabled and generation==g and busy then busy=false;message.Text="No confirmation yet. Ask again to check your current progress.";menu() end end)
  end,Color3.fromRGB(134,67,187))
 end
 button("CANCEL — keep my current journey",function() token=nil;task.spawn(function() pcall(function() remote:InvokeServer("cancel") end) end);message.Text="No rush. Ask me again whenever you're ready.";menu() end)
end
ask=function(action)
 if busy then return end
 busy=true;local g=generation
 task.spawn(function()
  local ok,result=pcall(function() return remote:InvokeServer(action) end)
  if not gui.Enabled or generation~=g then return end
  busy=false
  if not ok or type(result)~="table" then message.Text="I lost my train of thought. Try again in a moment.";return end
  if result.error then message.Text=result.error;return end
  if action=="rebirth" then showRebirth(result) else message.Text=result.text;menu() end
 end)
end
menu=function()
 clear()
 for _,option in {{"REBIRTH","rebirth"},{"What does Rebirth do?","aboutRebirth"}} do
  local action=option[2];button(option[1],function() ask(action) end)
 end
 button("Never mind",close)
end
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt,who)
 if who~=player or gui.Enabled or prompt:GetAttribute("NoobDialogue")~=true then return end
 -- Set before any UI work or remote yield. The actual runtime ThrowInput
 -- module observes this attribute and cancels an existing charge.
 player:SetAttribute("NoobDialogueOpen",true)
 generation+=1;busy=false;token=nil;gui.Enabled=true;showHUD(false);fit();menu();ask("hello")
end)
Remotes.Rebirthed.OnClientEvent:Connect(function(id,count)
 if id==player.UserId and gui.Enabled then busy=false;message.Text="REBIRTH "..count.."! Your collection is safe. New journey, bigger potential. Go make some waves.";menu() end
end)
Remotes.Toast.OnClientEvent:Connect(function(text,kind)
 if gui.Enabled and busy and kind=="bad" then busy=false;token=nil;message.Text=tostring(text);menu() end
end)
game:GetService("UserInputService").InputBegan:Connect(function(input,processed)
 if gui.Enabled and (input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB) then close() end
end)
local connection=game:GetService("RunService").Heartbeat:Connect(function()
 if not gui.Enabled then return end
 fit()
 local terrain=workspace:FindFirstChild("terrain")
 local npc=terrain and terrain:FindFirstChild("noob")
 local anchor=npc and npc:FindFirstChild("DialogueAnchor")
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if not anchor or not root or (root.Position-anchor.Position).Magnitude>17 then close() end
end)
local hudAdded=player.PlayerGui.ChildAdded:Connect(function(g)
 if gui.Enabled and g:IsA("ScreenGui") and hudNames[g.Name] and hidden[g]==nil then hidden[g]=g.Enabled;g.Enabled=false end
end)
player.CharacterRemoving:Connect(function() if gui.Enabled then close() end end)
script.Destroying:Connect(function()
 connection:Disconnect();hudAdded:Disconnect();showHUD(true)
 player:SetAttribute("NoobDialogueOpen",false);gui:Destroy()
end)
