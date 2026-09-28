local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Tween=game:GetService("TweenService")
local Prompts=game:GetService("ProximityPromptService")
local UIS=game:GetService("UserInputService")
local Config=require(RS.Shared.AwakeningConfig)
local Cinematic=require(script.Parent.AwakeningCinematic)
local Audio=require(script.Parent.AwakeningAudio)
local Remotes=require(RS.Shared.Remotes)
local player=Players.LocalPlayer
local review=RS:WaitForChild("AwakeningReview")
local event=RS:WaitForChild("AwakeningEvent")
Audio.preload()
local function make(class,parent,props)
 local v=Instance.new(class);for k,value in props do v[k]=value end;v.Parent=parent;return v
end
local function text(parent,name,words,pos,size,fontSize,color)
 return make("TextLabel",parent,{Name=name,Text=words,Position=pos,Size=size,TextSize=fontSize,TextColor3=color or Config.Ice,Font=Enum.Font.GothamMedium,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,BackgroundTransparency=1})
end
local gui=make("ScreenGui",player.PlayerGui,{Name="AwakeningReview",IgnoreGuiInset=true,ResetOnSpawn=false,DisplayOrder=160,Enabled=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
make("TextButton",gui,{Name="Backdrop",Text="",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(2,7,16),BackgroundTransparency=.22,AutoButtonColor=false,Modal=true,Selectable=false})
local panel=make("Frame",gui,{Name="Review",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(560,568),BackgroundColor3=Color3.fromRGB(9,20,35),BorderSizePixel=0})
make("UICorner",panel,{CornerRadius=UDim.new(0,16)})
make("UIStroke",panel,{Color=Color3.fromRGB(47,93,123),Thickness=1,Transparency=.25})
local scale=make("UIScale",panel,{Scale=1})
text(panel,"Eyebrow","THE MAGICAL ROCK",UDim2.fromOffset(30,25),UDim2.fromOffset(450,22),12,Color3.fromRGB(112,159,188))
local title=text(panel,"Title","Your next awakening",UDim2.fromOffset(30,56),UDim2.fromOffset(455,36),28)
local description=text(panel,"Description","The stone is listening…",UDim2.fromOffset(30,104),UDim2.fromOffset(496,42),15,Color3.fromRGB(161,184,204))
local scroll=make("ScrollingFrame",panel,{Name="Details",Position=UDim2.fromOffset(30,158),Size=UDim2.fromOffset(500,288),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=Config.Blue,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()})
make("UIListLayout",scroll,{Padding=UDim.new(0,13),SortOrder=Enum.SortOrder.LayoutOrder})
local function detail(words,color,size)
 local label=text(scroll,"Detail",words,UDim2.new(),UDim2.new(1,-16,0,0),size or 15,color)
 label.AutomaticSize=Enum.AutomaticSize.Y;return label
end
local confirm=make("TextButton",panel,{Name="ConfirmAwakening",Position=UDim2.fromOffset(30,467),Size=UDim2.fromOffset(500,48),BackgroundColor3=Color3.fromRGB(44,133,200),Text="AWAKEN",TextColor3=Color3.fromRGB(236,249,255),TextSize=16,Font=Enum.Font.GothamBold,BorderSizePixel=0})
make("UICorner",confirm,{CornerRadius=UDim.new(0,9)})
local cancel=make("TextButton",panel,{Name="Cancel",Position=UDim2.fromOffset(30,521),Size=UDim2.fromOffset(500,33),BackgroundTransparency=1,Text="Not yet · keep my current journey",TextColor3=Color3.fromRGB(141,167,190),TextSize=13,Font=Enum.Font.GothamMedium})
local hidden={}
local busy=false
local token
local retryReview=false
local generation=0
local scene
local function closeMenu()
 generation+=1;gui.Enabled=false;busy=false;token=nil;retryReview=false
 for g,enabled in hidden do if g.Parent then g.Enabled=enabled end end;table.clear(hidden)
 player:SetAttribute("NoobDialogueOpen",false) -- Existing throw modal contract.
end
local function cancelMenu()
 if busy then return end
 closeMenu();task.spawn(function() pcall(function() review:InvokeServer("cancel") end) end)
end
cancel.Activated:Connect(cancelMenu)
local function offerRetry(message)
 busy=false;token=nil;retryReview=true;description.Text=message
 confirm.Active=true;confirm.Text="REVIEW AGAIN"
end
local function showReview()
 if scene or gui.Enabled or player:GetAttribute("RebirthCinematic")==true then return end
 generation+=1;local ticket=generation;gui.Enabled=true;busy=true;token=nil;retryReview=false
 player:SetAttribute("NoobDialogueOpen",true)
 for _,g in player.PlayerGui:GetChildren() do if g:IsA("ScreenGui") and g~=gui then hidden[g]=g.Enabled;g.Enabled=false end end
 title.Text="Your next awakening";description.Text="The stone is listening…";confirm.Text="LISTENING…";confirm.Active=false
 for _,g in scroll:GetChildren() do if g:IsA("GuiObject") then g:Destroy() end end
 task.delay(8,function() if gui.Enabled and generation==ticket and busy then offerRetry("The stone is quiet. Review your awakening to try again.") end end)
 task.spawn(function()
  local ok,result=pcall(function() return review:InvokeServer("review") end)
  if generation~=ticket or not gui.Enabled then return end
  busy=false
  if not ok or type(result)~="table" or result.error then
   offerRetry(ok and result and result.error or "Could not reach the stone. Try again in a moment.");return
  end
  token=result.token;retryReview=false
  local node,isNew=Config.stage(result.next)
  title.Text=result.next==1 and "The first awakening" or (isNew and node.name or "A deeper resonance")
  description.Text=result.ready and (player.DisplayName..", you are ready. A new journey begins here.") or result.reason
  detail(result.benefit,Config.Ice,16)
  local lines={"YOUR POTENTIAL"}
  for _,r in result.requirements do table.insert(lines,(r.met and "✓  " or "○  ")..r.label) end
  detail(table.concat(lines,"\n"),Color3.fromRGB(149,182,204),14)
  detail("RELEASE\n"..result.resets,Color3.fromRGB(220,183,159),14)
  detail("KEEP\n"..result.keeps,Color3.fromRGB(147,204,197),14)
  confirm.Active=result.ready;confirm.Text=result.ready and "AWAKEN  ·  REBIRTH "..result.next or "YOUR JOURNEY CONTINUES"
  confirm.BackgroundColor3=result.ready and Color3.fromRGB(38,122,189) or Color3.fromRGB(34,51,69)
  scroll.CanvasPosition=Vector2.zero
 end)
end
confirm.Activated:Connect(function()
 if not busy and retryReview then closeMenu();showReview();return end
 if busy or not token then return end
 busy=true;local receipt=token;token=nil;confirm.Text="THE STONE ANSWERS…"
 Remotes.RequestRebirth:FireServer(receipt)
 local ticket=generation
 task.delay(8,function() if gui.Enabled and generation==ticket and busy then offerRetry("The awakening did not begin. Review your awakening to try again.") end end)
end)
Prompts.PromptTriggered:Connect(function(prompt,who)
 if who==player and prompt:GetAttribute("MagicalRock")==true then showReview() end
end)
UIS.InputBegan:Connect(function(input)
 if gui.Enabled and (input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB) then cancelMenu() end
end)
Remotes.Toast.OnClientEvent:Connect(function(message,kind)
 if gui.Enabled and busy and kind=="bad" then offerRetry(tostring(message)) end
end)
event.OnClientEvent:Connect(function(action,data)
 if type(data)~="table" then return end
 if action=="Begin" then
  if scene then event:FireServer("Cancel",data.token);return end
  closeMenu()
  scene=Cinematic.begin(data,function(reason)
   scene=nil
   if reason then warn("[Awakening] "..reason) end
  end)
 elseif scene and scene.token==data.token then
  if action=="Play" then scene:play(data.at)
  elseif action=="Complete" then scene:complete(data)
  elseif action=="Abort" then scene:destroy(data.reason,false) end
 end
end)
-- Quiet, personalized calling. Each player's eligibility affects only their own effects.
local calls=make("ScreenGui",player.PlayerGui,{Name="AwakeningCall",IgnoreGuiInset=true,ResetOnSpawn=false,DisplayOrder=80})
local call=text(calls,"Whisper","",UDim2.fromScale(.2,.17),UDim2.fromScale(.6,.085),19,Config.Ice)
call.TextXAlignment=Enum.TextXAlignment.Center;call.TextYAlignment=Enum.TextYAlignment.Center
call.TextStrokeColor3=Color3.fromRGB(0,10,20);call.TextStrokeTransparency=.35;call.TextTransparency=1;call.TextScaled=true
make("UITextSizeConstraint",call,{MinTextSize=12,MaxTextSize=19})
local lastCall=-math.huge;local callAt=-math.huge;local wasReady=false
local rock,anchor,highlight,light,hum,whisper,billboard,waypoint
local function bindRock()
 local found=workspace:FindFirstChild("MagicalRock")
 if not found or found==rock then return end
 rock=found;anchor=rock:FindFirstChild("InteractionAnchor")
 if not anchor then rock=nil;return end
 highlight=make("Highlight",rock,{Name="PersonalAwakeningGlow",Adornee=rock,FillColor=Config.Blue,OutlineColor=Config.Ice,FillTransparency=.94,OutlineTransparency=.45,DepthMode=Enum.HighlightDepthMode.Occluded,Enabled=false})
 light=make("PointLight",anchor,{Name="PersonalCallingLight",Color=Config.Blue,Range=13,Brightness=0})
 hum=make("Sound",anchor,{Name="StoneResonance",SoundId=Config.Audio.Ambient,Looped=true,Volume=0,PlaybackSpeed=.7,RollOffMinDistance=5,RollOffMaxDistance=34})
 whisper=make("Sound",anchor,{Name="StoneCall",SoundId=Config.Audio.Chime,Volume=.16,PlaybackSpeed=.74,RollOffMinDistance=10,RollOffMaxDistance=110})
 local sfx=game.SoundService:FindFirstChild("SFX");hum.SoundGroup=sfx;whisper.SoundGroup=sfx;hum:Play()
 billboard=make("BillboardGui",calls,{Name="StoneWaypoint",Adornee=anchor,Size=UDim2.fromOffset(220,60),StudsOffsetWorldSpace=Vector3.new(0,4.8,0),AlwaysOnTop=true,MaxDistance=550,Enabled=false})
 waypoint=text(billboard,"Destination","",UDim2.fromScale(0,0),UDim2.fromScale(1,1),14,Config.Ice)
 waypoint.TextXAlignment=Enum.TextXAlignment.Center;waypoint.TextYAlignment=Enum.TextYAlignment.Center
 waypoint.TextStrokeTransparency=.35;waypoint.TextStrokeColor3=Color3.fromRGB(1,9,22)
end
local elapsed=0
local heartbeat=Run.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.06 then return end;local step=elapsed;elapsed=0
 if gui.Enabled then
  local size=workspace.CurrentCamera.ViewportSize
  local w=math.min(560,size.X-32);local h=math.min(568,size.Y-28)
  local compact=h<480;local inset=24;local contentY=compact and 118 or 158
  scale.Scale=1;panel.Size=UDim2.fromOffset(w,h)
  panel.Eyebrow.Position=UDim2.fromOffset(inset,compact and 13 or 25)
  title.Position=UDim2.fromOffset(inset,compact and 34 or 56);title.Size=UDim2.fromOffset(w-48,36);title.TextSize=compact and 22 or 26
  description.Position=UDim2.fromOffset(inset,compact and 73 or 104);description.Size=UDim2.fromOffset(w-48,42);description.TextSize=14
  scroll.Position=UDim2.fromOffset(inset,contentY);scroll.Size=UDim2.fromOffset(w-48,math.max(48,h-contentY-118))
  confirm.Position=UDim2.fromOffset(inset,h-100);confirm.Size=UDim2.fromOffset(w-48,48)
  cancel.Position=UDim2.fromOffset(inset,h-47);cancel.Size=UDim2.fromOffset(w-48,36)
 end
 bindRock()
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local distance=root and anchor and (root.Position-anchor.Position).Magnitude or math.huge
 if gui.Enabled and (not root or distance>17) then closeMenu() end
 local ready=player:GetAttribute("RebirthReady")==true
 local quiet=scene~=nil or gui.Enabled or player:GetAttribute("RockInFlight")==true or player:GetAttribute("RebirthCinematic")==true
 local active=ready and not quiet
 if highlight then highlight.Enabled=active end
 if light then light.Brightness=active and (.6+.2*math.sin(os.clock()*1.3)) or 0 end
 if hum then hum.Volume+=( (active and .09 or 0)-hum.Volume)*math.min(1,step*2) end
 if billboard then billboard.Enabled=active;waypoint.Text="◇  MAGICAL ROCK\n"..(distance<12 and "Your awakening awaits" or tostring(math.floor(distance)).." studs") end
 local now=os.clock()
 if active and ((not wasReady and now-lastCall>15) or (distance<35 and now-lastCall>70)) then
  lastCall=now;callAt=now;call.Text=player.DisplayName.."…\n"..(distance<35 and "Come closer." or "Your next awakening awaits.")
  if whisper then whisper:Play() end
 end
 if not quiet then wasReady=ready end
 local age=now-callAt
 call.Visible=active and age<6
 call.TextTransparency=age<1 and 1-math.clamp(age,0,1) or age>4.5 and math.clamp((age-4.5)/1.5,0,1) or 0
end)
player.CharacterRemoving:Connect(function() closeMenu() end)
script.Destroying:Connect(function()
 heartbeat:Disconnect();closeMenu();if scene then scene:destroy(nil,true) end
 for _,v in {gui,calls,highlight,light,hum,whisper} do if v then v:Destroy() end end
end)