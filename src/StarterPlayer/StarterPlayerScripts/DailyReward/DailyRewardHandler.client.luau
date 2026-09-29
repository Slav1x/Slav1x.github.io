local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Tween=game:GetService("TweenService")
local Run=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local MarketplaceService=game:GetService("MarketplaceService")
local player=Players.LocalPlayer
local pg=player:WaitForChild("PlayerGui")
local hud=pg:WaitForChild("MainHUD")
local S=require(RS.SharedUI.FinalUIStyle)
local UISounds=require(RS.SharedUI.UISounds)
local config=require(RS.Shared.PlaytimeRewardConfig)
local dailyConfig=require(RS.Modules.Configs.DAILY_REWARD_CONFIG)
local DAILY_ICONS={cash="rbxassetid://127824684237342",spin="rbxassetid://78885528615503",summon="rbxassetid://138255528748096",all="rbxassetid://138255528748096"}
local daily=pg:WaitForChild("DailyRewardsUI")
local play=pg:WaitForChild("PlaytimeGiftsUI")
local questsGui=pg:WaitForChild("QuestsUI")
local states={}
local function tween(x,props,d) local t=Tween:Create(x,TweenInfo.new(d or .15),props) t:Play() return t end
local function timeText(s) s=math.max(0,math.ceil(s)) if s>=3600 then return string.format("%02d:%02d:%02d",math.floor(s/3600),math.floor(s/60)%60,s%60) end return string.format("%02d:%02d",math.floor(s/60),s%60) end
local function comma(n) return tostring(n):reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","") end
local function dailyTimeText(s) s=math.max(0,math.ceil(s)); return string.format("%02d:%02d:%02d",math.floor(s/3600),math.floor(s/60)%60,s%60) end
local function render(gui)
 local e=states[gui] local data=e.data local body=gui.Background
 if not data then return end
 local count=0
 local readyCount=0
 for i,c in e.cards do
  local claimed,ready,left
  if e.daily then
   claimed=i<data.CurrentDay or (i==data.CurrentDay and not data.RewardRedeemable)
   ready=i==data.CurrentDay and data.RewardRedeemable
   left=(data.NextDailyRewardTime or os.time())-os.time()
  else
   claimed=data.claimed[config[i].id]==true
   left=config[i].seconds-(data.elapsed+os.clock()-e.received)
   ready=left<=0 and not claimed
  end
  if claimed then count+=1 end
  if ready then readyCount+=1 end
  c:SetAttribute("Ready",ready)
  if e.daily then
   local pulse=e.pulses[i]
   if ready and gui.Enabled and not player:GetAttribute("ReducedMotion") then
    if not pulse then
     c.ButtonScale.Scale=.96
     pulse=Tween:Create(c.ButtonScale,TweenInfo.new(1.15,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Scale=1.035})
     e.pulses[i]=pulse
     pulse:Play()
    end
   elseif pulse then
    pulse:Cancel()
    e.pulses[i]=nil
    c.ButtonScale.Scale=1
   end
  end
  local special=(e.daily and i==7) or ((not e.daily) and i==6)
  c.State.Text=claimed and "✓  CLAIMED" or ready and "CLAIM NOW" or (e.daily and "     LOCKED" or timeText(left))
  local lock=c.State:FindFirstChild("ReferenceLock")
  if lock then lock.Visible=not claimed and not ready end
  c.State.BackgroundColor3=claimed and Color3.fromRGB(25,105,80) or ready and Color3.fromRGB(43,196,83) or Color3.fromRGB(32,55,86)
  c.State.TextColor3=claimed and Color3.fromRGB(235,255,244) or ready and Color3.new(1,1,1) or Color3.fromRGB(242,248,255)
  c.State.TextStrokeTransparency=claimed and .42 or .36
  local stateGradient=c.State:FindFirstChild("StateGradient")
  if stateGradient then
   local top=claimed and Color3.fromRGB(48,154,113) or ready and Color3.fromRGB(100,244,112) or Color3.fromRGB(64,88,122)
   local bottom=claimed and Color3.fromRGB(17,79,63) or ready and Color3.fromRGB(17,137,66) or Color3.fromRGB(20,40,69)
   stateGradient.Color=ColorSequence.new(top,bottom)
  end
  c.RewardIcon.ImageTransparency=claimed and .28 or 0
  c.Outline.Color=ready and Color3.fromRGB(255,236,128) or special and Color3.fromRGB(255,210,70) or claimed and Color3.fromRGB(56,148,120) or S.navy
  c.Outline.Thickness=ready and 3.5 or special and 3 or 2
  -- Tile face colors and gradients are editable on the Studio instances.
 end
 gui:SetAttribute("ReadyCount",readyCount)
 body.ProgressTrack.Fill.Size=UDim2.fromScale(count/#e.cards,1)
 if e.daily then
  body.Status.Text=count.."/7 REWARDS CLAIMED"
  local strip=body:FindFirstChild("StreakStrip")
  if strip then
   strip.StreakLabel.Text=tostring(data.CurrentDailyRewardStreak).." DAY STREAK"
   strip.NextRewardLabel.Text=data.RewardRedeemable and "REWARD READY!" or "NEXT REWARD IN\n"..dailyTimeText(data.NextDailyRewardTime-os.time())
  end
 else
  local elapsedTime=data.elapsed+os.clock()-e.received
  local nextSeconds=3600
  local nextRemaining=0
  for _,reward in ipairs(config) do
   if not data.claimed[reward.id] then
    nextSeconds=reward.seconds
    nextRemaining=math.max(0,reward.seconds-elapsedTime)
    break
   end
  end
  body.Status.Text=count.."/6 GIFTS CLAIMED   •   "..(count==6 and "ALL GIFTS COLLECTED" or "NEXT IN "..timeText(nextRemaining))
  body.ProgressTrack.Fill.Size=UDim2.fromScale(math.clamp(elapsedTime/nextSeconds,0,1),1)
 end
end
local function request(gui,id,isClaim)
 local e=states[gui] if e.busy then return end e.busy=true
 local ok,data=pcall(function() return e.remote:InvokeServer(id) end)
 e.busy=false
 if ok and type(data)=="table" and not data.error then
  e.data=data e.received=os.clock() render(gui)
  if isClaim then UISounds.play("Claim") end
 else gui.Background.Status.Text=(ok and data and data.error) or "Could not load rewards. Try again." end
end
local closeTokens={}
local closingGuis={}
local function close(gui)
 if not gui.Enabled or closingGuis[gui] then return end
 closingGuis[gui]=true
 closeTokens[gui]=(closeTokens[gui] or 0)+1
 local token=closeTokens[gui]
 local body=gui.Background
 if player:GetAttribute("ReducedMotion") then
  gui.Enabled=false
  body.OpenScale.Scale=1
  closingGuis[gui]=nil
  return
 end
 local animation=Tween:Create(body.OpenScale,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=.82})
 animation:Play()
 animation.Completed:Once(function()
  if closeTokens[gui]==token and gui.Parent then
   gui.Enabled=false
   body.OpenScale.Scale=1
   closingGuis[gui]=nil
  end
 end)
end
local function bind(gui,isDaily)
 local b=gui.Background
 local e={daily=isDaily,remote=isDaily and RS:WaitForChild("DailyRewards") or RS:WaitForChild("PlaytimeRewards"),cards={},pulses={}} states[gui]=e
 for i=1,(isDaily and 7 or 6) do
  local c=b.RewardScroll["Reward"..i] e.cards[i]=c
  if isDaily then
   local preset=dailyConfig.DAY_PRESETS["Day "..i]
   c.Amount.Text=preset.card_text or preset.reward_text:gsub("SUMMON LUCK","LUCK"):gsub(" MIN","m")
   c.RewardIcon.Image=DAILY_ICONS[preset.icon]
   c:SetAttribute("RewardDescription",preset.reward_text)
  else
   c.Amount.Text="$"..comma(config[i].cash)
  end
  local hover=false
  c.MouseEnter:Connect(function() hover=true if not player:GetAttribute("ReducedMotion") and not (isDaily and c:GetAttribute("Ready")) then tween(c.ButtonScale,{Scale=1.025}) end end)
  c.MouseLeave:Connect(function() hover=false if not (isDaily and c:GetAttribute("Ready")) then tween(c.ButtonScale,{Scale=1}) end end)
  c.InputBegan:Connect(function(input) if (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch) and not (isDaily and c:GetAttribute("Ready")) then tween(c.ButtonScale,{Scale=.97},.08) end end)
  c.InputEnded:Connect(function(input) if (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch) and not (isDaily and c:GetAttribute("Ready")) then tween(c.ButtonScale,{Scale=hover and 1.025 or 1},.1) end end)
  c.Activated:Connect(function()
   if not c:GetAttribute("Ready") then return end
   request(gui,isDaily and true or config[i].id,true)
   if not player:GetAttribute("ReducedMotion") then c.ButtonScale.Scale=.96 tween(c.ButtonScale,{Scale=1},.2) end
  end)
 end
 b.Header.Close.Activated:Connect(function() close(gui) end)
 local closeRequest=gui:FindFirstChild("CloseRequest")
 if closeRequest then closeRequest.Event:Connect(function() close(gui) end) end
 gui:GetPropertyChangedSignal("Enabled"):Connect(function()
  if gui.Enabled then
   closingGuis[gui]=nil
   closeTokens[gui]=(closeTokens[gui] or 0)+1
   for _,other in {daily,play} do if other~=gui and other.Enabled then close(other) end end
   if player:GetAttribute("ReducedMotion") then b.OpenScale.Scale=1
   else
    b.OpenScale.Scale=.82
    Tween:Create(b.OpenScale,TweenInfo.new(.23,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
   end
   task.spawn(request,gui)
  else
   closingGuis[gui]=nil
   for i,pulse in e.pulses do pulse:Cancel();e.pulses[i]=nil;e.cards[i].ButtonScale.Scale=1 end
  end
 end)
end
bind(daily,true) bind(play,false)

-- Premium skip actions are fully wired visually but require real Developer Product IDs.
-- Configure ProductId attributes on the two buttons; zero intentionally never prompts.
local function bindSkip(button)
 if not button then return end
 local scale=button:FindFirstChild("ButtonScale")
 local hover=false
 button.MouseEnter:Connect(function() hover=true if scale and not player:GetAttribute("ReducedMotion") then tween(scale,{Scale=1.025}) end end)
 button.MouseLeave:Connect(function() hover=false if scale then tween(scale,{Scale=1}) end end)
 button.InputBegan:Connect(function(input) if scale and (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch) then tween(scale,{Scale=.97},.08) end end)
 button.InputEnded:Connect(function() if scale then tween(scale,{Scale=hover and 1.025 or 1},.1) end end)
 local lastTrigger=0
 local function triggerSkip()
  if os.clock()-lastTrigger<.2 then return end
  lastTrigger=os.clock()
  local productId=button:GetAttribute("ProductId")
  if typeof(productId)=="number" and productId>0 then
   MarketplaceService:PromptProductPurchase(player,productId)
  else
   local sub=button:FindFirstChild("SubLabel")
   if sub then
    local old=sub.Text
    sub.Text="PRODUCT ID REQUIRED"
    sub.TextColor3=Color3.fromRGB(255,238,153)
    task.delay(1.6,function()
     if sub.Parent then sub.Text=old sub.TextColor3=Color3.fromRGB(208,255,216) end
    end)
   end
  end
 end
 button.MouseButton1Down:Connect(triggerSkip)
 button.TouchTap:Connect(triggerSkip)
end
local skipActions=daily.Background:FindFirstChild("SkipActions")
if skipActions then
 bindSkip(skipActions:FindFirstChild("SkipOneDayButton"))
 bindSkip(skipActions:FindFirstChild("SkipToDay7Button"))
end

local function resize()
 local v=workspace.CurrentCamera.ViewportSize
 local portrait=v.X<v.Y and v.X<700
 for gui,e in states do
  local short=v.Y<500
  local compact=v.X<900 and v.Y<500
  local width=portrait and 390 or (e.daily and (compact and 920 or 940) or compact and 1040 or 880)
  local height=portrait and 660 or (e.daily and (short and 440 or 620) or compact and 400 or 600)
  local safe=hud.AbsoluteSize
  local scale=math.min(portrait and 1 or .86,(safe.X-(compact and 30 or 48))/width,(safe.Y-(compact and 36 or 64))/height)
  local b=gui.Background b.Size=UDim2.fromOffset(width,height) b.ResponsiveScale.Scale=scale
  b.Header.Size=UDim2.new(1,-8,0,70)
  local headerDepth=b:FindFirstChild("ReferenceHeaderDepth")
  if headerDepth then headerDepth.Size=b.Header.Size;headerDepth.Position=b.Header.Position+UDim2.fromOffset(0,7) end
  b.Header.HeaderLabel.TextSize=(portrait or short) and 24 or 32
  b.Status.TextSize=(portrait or short) and 13 or 17
  local strip=b:FindFirstChild("StreakStrip")
  if strip then
   strip.Position=UDim2.fromOffset(18,80)
   strip.Size=UDim2.new(1,-36,0,portrait and 45 or 52)
   strip.StreakLabel.TextSize=portrait and 17 or 24
   strip.NextRewardLabel.TextSize=portrait and 12 or 18
  end
  b.RewardScroll.Position=UDim2.fromOffset(18,e.daily and (portrait and 137 or 143) or 86)
  b.RewardScroll.Size=e.daily and UDim2.new(1,-36,1,-(portrait and 270 or 281)) or UDim2.new(1,-36,1,-163)
  b.ProgressTrack.Position=e.daily and UDim2.new(0,22,1,-123) or UDim2.new(0,72,1,-65)
  b.ProgressTrack.Size=e.daily and UDim2.new(1,-44,0,13) or UDim2.new(1,-94,0,13)
  b.Status.Position=e.daily and UDim2.new(0,22,1,-103) or UDim2.new(0,72,1,-44)
  if not e.daily then
   b.NextRewardClock.Position=UDim2.new(0,20,1,-100)
   b.NextRewardTitle.Position=UDim2.new(0,72,1,-95)
  end
  local actions=b:FindFirstChild("SkipActions")
  if actions then
   actions.Position=UDim2.new(.5,0,1,-14)
   actions.Size=UDim2.new(1,-44,0,52)
  end
  local columns=portrait and 2 or e.daily and 4 or compact and 6 or 3
  local cardH=short and 154 or (e.daily and 145 or 196)
  local step=cardH+12
  local available=width-48
  local cell=(available-(columns-1)*10)/columns
  for i,c in e.cards do
   local special=(e.daily and i==7) or ((not e.daily) and i==6)
   local col=(i-1)%columns local row=math.floor((i-1)/columns)
   local cardW=cell
   local cardHeight=cardH
   local y=5+row*step
   c.Position=UDim2.fromOffset(6+col*(cell+10),y)
   c.Size=UDim2.fromOffset(cardW,cardHeight)
   c.Day.Position=UDim2.new(0,4,0,special and 9 or 10)
   c.RewardIcon.Position=UDim2.new(.5,0,0,e.daily and 28 or special and 60 or (short and 36 or 48))
   c.RewardIcon.Size=UDim2.fromOffset(e.daily and 68 or special and 94 or (short and 60 or 78),e.daily and 58 or special and 76 or (short and 48 or 62))
   c.Amount.Position=UDim2.new(0,3,0,e.daily and 84 or special and 118 or (short and 86 or 112))
   c.Amount.TextSize=e.daily and 21 or special and 25 or (short and 19 or 22)
   c.State.Position=UDim2.new(0,7,1,-38) c.State.Size=UDim2.new(1,-14,0,30)
  end
  local rows=math.ceil(#e.cards/columns)
  b.RewardScroll.CanvasSize=UDim2.fromOffset(0,rows*step+(e.daily and portrait and 28 or 6))
 end
 -- Right-side utility positions belong to MainHUD.SimulatorHudController.
end

local originalResize=resize
resize=function()
 originalResize()
 local v=workspace.CurrentCamera.ViewportSize
 local portrait=v.X<v.Y and v.X<700
 local short=v.Y<540 and not portrait
 local width=portrait and 390 or 940
 local height=portrait and 690 or short and 500 or 620
 local b=daily.Background
 local safe=hud.AbsoluteSize
 local scale=math.min(portrait and 1 or .86,(safe.X-32)/width,(safe.Y-48)/height)
 b.Size=UDim2.fromOffset(width,height)
 b.ResponsiveScale.Scale=scale
 b.Header.Position=UDim2.fromOffset(4,4)
 b.Header.Size=UDim2.new(1,-8,0,portrait and 72 or short and 77 or 91)
 b.Header.HeaderLabel.TextSize=portrait and 23 or short and 29 or 37
 local subtitle=b.Header:FindFirstChild("ReferenceSubtitle")
 if subtitle then subtitle.Visible=not portrait;subtitle.TextSize=short and 14 or 17 end
 b.RewardScroll.Position=UDim2.fromOffset(portrait and 13 or 19,portrait and 88 or short and 94 or 107)
 b.RewardScroll.Size=UDim2.new(1,portrait and -26 or -38,0,portrait and 416 or short and 300 or 366)
 b.RewardScroll.ScrollingEnabled=portrait
 b.RewardScroll.ScrollBarThickness=portrait and 5 or 0
 b.ProgressTrack.Position=UDim2.new(0,22,1,portrait and -181 or short and -99 or -136)
 b.ProgressTrack.Size=UDim2.new(1,-44,0,12)
 b.Status.Position=UDim2.new(0,22,1,portrait and -164 or short and -84 or -117)
 b.Status.Size=UDim2.new(1,-44,0,20)
 b.Status.TextSize=portrait and 13 or 15
 local strip=b.StreakStrip
 strip.Position=UDim2.fromOffset(portrait and 17 or 21,portrait and 547 or short and 442 or 530)
 strip.Size=UDim2.fromOffset(portrait and 356 or short and 457 or 455,portrait and 55 or short and 49 or 71)
 local half=portrait and 178 or 226
 strip.StreakPanel.Position=UDim2.fromOffset(0,0)
 strip.StreakPanel.Size=UDim2.fromOffset(half-5,strip.Size.Y.Offset)
 strip.TimerPanel.Position=UDim2.fromOffset(half+4,0)
 strip.TimerPanel.Size=UDim2.fromOffset(strip.Size.X.Offset-half-4,strip.Size.Y.Offset)
 strip.Flame.Visible=false
 strip.ReferenceFlame.Position=UDim2.fromOffset(7,portrait and 7 or 9)
 strip.ReferenceFlame.Size=UDim2.fromOffset(portrait and 39 or short and 39 or 50,portrait and 39 or short and 39 or 50)
 strip.FlameGlow.Position=strip.ReferenceFlame.Position-UDim2.fromOffset(4,4)
 strip.FlameGlow.Size=strip.ReferenceFlame.Size+UDim2.fromOffset(8,8)
 strip.FlameArt.Position=UDim2.fromOffset(6,portrait and 3 or short and -2 or 5)
 strip.FlameArt.Size=UDim2.fromOffset(52,56)
 strip.FlameArt.FlameArtScale.Scale=portrait and .8 or short and .8 or 1
 strip.StreakLabel.Position=UDim2.fromOffset(portrait and 50 or 62,portrait and 5 or 9)
 strip.StreakLabel.Size=UDim2.fromOffset(half-(portrait and 52 or 64),portrait and 43 or short and 40 or 32)
 strip.StreakLabel.TextSize=portrait and 13 or short and 18 or 23
 strip.StreakLabel.TextXAlignment=Enum.TextXAlignment.Left
 local hint=strip:FindFirstChild("StreakHint")
 if not hint then
  hint=Instance.new("TextLabel")
  hint.Name="StreakHint";hint.BackgroundTransparency=1
  hint.Font=Enum.Font.FredokaOne;hint.Text="Come back tomorrow!"
  hint.TextColor3=Color3.fromRGB(210,231,255);hint.TextStrokeColor3=Color3.fromRGB(0,19,53)
  hint.TextStrokeTransparency=0;hint.ZIndex=9;hint.Parent=strip
 end
 hint.Visible=not portrait and not short
 hint.Position=UDim2.fromOffset(62,39);hint.Size=UDim2.fromOffset(half-65,24);hint.TextSize=15
 hint.TextXAlignment=Enum.TextXAlignment.Left
 strip.ClockIcon.Position=UDim2.fromOffset(half+10,portrait and 7 or 11)
 strip.ClockIcon.Size=UDim2.fromOffset(portrait and 33 or 42,portrait and 38 or 47)
 strip.ClockIcon.TextSize=portrait and 32 or 44
 strip.ClockArt.Position=UDim2.fromOffset(half+13,portrait and 8 or 14)
 local clockScale=strip.ClockArt:FindFirstChild("ClockArtScale")
 if not clockScale then clockScale=Instance.new("UIScale");clockScale.Name="ClockArtScale";clockScale.Parent=strip.ClockArt end
 clockScale.Scale=portrait and .75 or short and .8 or 1
 strip.ClockImage.Position=UDim2.fromOffset(half+8,portrait and 4 or short and 1 or 7)
 strip.ClockImage.Size=UDim2.fromOffset(portrait and 43 or short and 48 or 54,portrait and 43 or short and 48 or 54)
 strip.NextRewardLabel.Position=UDim2.fromOffset(half+(portrait and 49 or 62),portrait and 6 or 9)
 strip.NextRewardLabel.Size=UDim2.fromOffset(strip.Size.X.Offset-half-(portrait and 54 or 67),portrait and 44 or 55)
 strip.NextRewardLabel.TextSize=portrait and 12 or short and 15 or 18
 strip.NextRewardLabel.TextXAlignment=Enum.TextXAlignment.Left
 strip.NextRewardLabel.TextYAlignment=Enum.TextYAlignment.Center
 b.SkipActions.Position=UDim2.fromOffset(portrait and 17 or 485,portrait and 612 or short and 442 or 530)
 b.SkipActions.AnchorPoint=Vector2.new(0,0)
 b.SkipActions.Size=UDim2.fromOffset(portrait and 356 or short and 434 or 434,portrait and 57 or short and 49 or 71)
 for _,button in {b.SkipActions.SkipOneDayButton,b.SkipActions.SkipToDay7Button} do
  local first=button.Name=="SkipOneDayButton"
  button.Position=UDim2.fromOffset(first and 0 or (portrait and 182 or 222),0)
  button.Size=UDim2.fromOffset(portrait and 174 or 212,b.SkipActions.Size.Y.Offset)
  button.Robux.Position=UDim2.fromOffset(8,portrait and 27 or short and 20 or 37)
  button.Robux.Size=UDim2.fromOffset(30,26)
  button.Robux.TextSize=portrait and 16 or 20
  button.ReferenceSkipIcon.Position=UDim2.fromOffset(9,portrait and 4 or short and 6 or 9)
  button.ReferenceSkipIcon.Size=UDim2.fromOffset(37,portrait and 28 or short and 30 or 35)
  button.Label.Position=UDim2.fromOffset(portrait and 40 or 52,portrait and 4 or short and 4 or 9)
  button.Label.Size=UDim2.new(1,portrait and -44 or -56,0,portrait and 27 or 33)
  button.Label.TextSize=portrait and 14 or short and 17 or 20
  button.SubLabel.Position=UDim2.fromOffset(portrait and 40 or 52,portrait and 29 or short and 28 or 42)
  button.SubLabel.Size=UDim2.new(1,portrait and -44 or -56,0,18)
  button.SubLabel.TextSize=portrait and 9 or short and 10 or 11
 end
 local boardW=width-(portrait and 26 or 38)
 local gap=portrait and 8 or 10
 local pad=portrait and 7 or 8
 local cardW=portrait and math.floor((boardW-2*pad-gap)/2) or math.floor((boardW-2*pad-3*gap)/4)
 local cardH=portrait and 156 or short and 139 or 173
 local rowGap=portrait and 9 or 10
 for i=1,7 do
  local c=b.RewardScroll["Reward"..i]
  local special=i==7
  local x,y,w,h
  if portrait then
   local col=(i-1)%2;local row=math.floor((i-1)/2)
   x=pad+col*(cardW+gap);y=7+row*(cardH+rowGap)
   w=cardW;h=cardH
   if special then x=pad;w=boardW-2*pad;h=209 end
  else
   local col=(i-1)%3;local row=math.floor((i-1)/3)
   x=pad+col*(cardW+gap);y=6+row*(cardH+rowGap)
   w=cardW;h=cardH
   if special then x=pad+3*(cardW+gap);y=6;h=2*cardH+rowGap end
  end
  c.Position=UDim2.fromOffset(x,y);c.Size=UDim2.fromOffset(w,h)
  c.Day.Position=UDim2.fromOffset(4,special and (portrait and 7 or short and 37 or 69) or 8)
  c.Day.Size=UDim2.new(1,-8,0,special and 40 or 31)
  c.Day.TextSize=special and (portrait and 26 or 31) or portrait and 18 or short and 20 or 24
  c.RewardIcon.AnchorPoint=Vector2.new(.5,0)
  c.RewardIcon.Position=UDim2.new(.5,0,0,special and (portrait and 86 or short and 120 or 162) or (portrait and 42 or short and 36 or 46))
  c.RewardIcon.Size=UDim2.fromOffset(special and (portrait and 136 or 160) or (portrait and 78 or short and 82 or 108),special and (portrait and 85 or 112) or (portrait and 58 or short and 56 or 70))
  c.RewardSunray.Position=UDim2.new(.5,0,0,special and (portrait and 130 or short and 181 or 223) or (portrait and 72 or short and 65 or 82))
  c.RewardSunray.Size=UDim2.fromOffset(special and 290 or 190,special and 290 or 190)
  if special then states[daily].day7IconBase=c.RewardIcon.Position; states[daily].day7RayBase=c.RewardSunray.Position end
  c.Amount.Position=UDim2.fromOffset(3,special and (portrait and 150 or short and 214 or 268) or (portrait and 93 or short and 86 or 104))
  c.Amount.Size=UDim2.new(1,-6,0,special and 44 or 32)
  c.Amount.TextSize=special and (portrait and 31 or 39) or portrait and 23 or short and 24 or 29
  c.Amount.TextScaled=true
  c.State.Position=UDim2.new(0,8,1,special and -46 or -39)
  c.State.Size=UDim2.new(1,-16,0,special and 36 or 31)
  c.State.TextSize=portrait and 15 or 17
  local cardGlare=c:FindFirstChild("SivaFixedGlare")
  if cardGlare then cardGlare.DiagonalGlare.Size=UDim2.fromOffset(special and 120 or 82,special and 220 or 130) end
  if special then
   c.CrownArt.Position=UDim2.new(.5,-37,0,portrait and 1 or short and 3 or 16)
   c.CrownImage.Position=UDim2.new(.5,portrait and -35 or -44,0,portrait and -2 or short and -1 or 8)
   c.CrownImage.Size=UDim2.fromOffset(portrait and 70 or 88,portrait and 57 or 69)
   c.ReferenceCrown.Position=UDim2.new(.5,-36,0,portrait and 0 or 8)
   c.ReferenceCrown.Size=UDim2.fromOffset(72,portrait and 41 or 58)
   c.ReferenceCrown.TextSize=portrait and 39 or 53
   c.UltimateBadge.Position=UDim2.new(.5,-82,0,portrait and 51 or short and 81 or 117)
   c.UltimateBadge.Size=UDim2.fromOffset(164,25)
  end
 end
 b.RewardScroll.CanvasSize=UDim2.fromOffset(0,portrait and 4*(cardH+rowGap)+70 or 0)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
resize()
for _,name in {"shopui","inventoryui","settingsui","upgradesui"} do
 hud[name]:GetPropertyChangedSignal("Visible"):Connect(function() if hud[name].Visible then close(daily) close(play) end end)
end
questsGui:GetPropertyChangedSignal("Enabled"):Connect(function() if questsGui.Enabled then close(daily) close(play) end end)
UIS.InputBegan:Connect(function(i,processed) if not processed and i.KeyCode==Enum.KeyCode.Escape then close(daily) close(play) end end)
local elapsed=0
Run.Heartbeat:Connect(function(dt)
 local e=states[daily]
 if daily.Enabled and e and e.day7IconBase and not player:GetAttribute("ReducedMotion") then
  local offset=math.sin(os.clock()*math.pi/2.4)*7
  local card=daily.Background.RewardScroll.Reward7
  card.RewardIcon.Position=e.day7IconBase+UDim2.fromOffset(0,offset)
  card.RewardSunray.Position=e.day7RayBase+UDim2.fromOffset(0,offset*.7)
 end
 elapsed+=dt if elapsed<.2 then return end elapsed=0
 for gui,e in states do if gui.Enabled then
  render(gui)
  if not player:GetAttribute("ReducedMotion") then
   for _,c in e.cards do if c:GetAttribute("Ready") then c.Outline.Transparency=.12+.12*math.sin(os.clock()*2.5) else c.Outline.Transparency=0 end end
  end
 end end
end)
task.spawn(function()
 request(daily) request(play)
 while task.wait(10) do for gui in states do if gui.Enabled then request(gui) end end end
end)
local function syncRewardControls()
 local any=daily.Enabled or play.Enabled or hud.IndexPanel.Visible or questsGui.Enabled
 for _,name in {"shopui","inventoryui","settingsui","upgradesui"} do any=any or hud[name].Visible end
 local hidden=player:GetAttribute("HideHud")==true
  local skipping=hud:GetAttribute("SkipFlightActive")==true
 local vp=workspace.CurrentCamera.ViewportSize
 local phoneLandscape=vp.Y<500 and vp.X<1000
 local shortModal=(phoneLandscape or vp.X<520) and any
 hud.LeftNav.Visible=not hidden and not shortModal and not skipping
 hud.StatsBar.Visible=not hidden and not shortModal
 local rewardModal=daily.Enabled or play.Enabled or questsGui.Enabled
 hud.Money.Visible=not hidden and not shortModal and not rewardModal
 hud.FriendBoostHUD.Visible=not hidden and not shortModal and not rewardModal
 hud.CashMultiplierHUD.Visible=not hidden and not shortModal
  hud.SpinMultiplierHUD.Visible=not hidden and not shortModal
 hud.SummonGroveQuickButton.Visible=not hidden and not any and not skipping
 hud.LevelHolder.Visible=false -- Temporarily hide the level display.
 hud.dailyrewardsopenFrame.Visible=not hidden and not shortModal and not skipping and not hud:GetAttribute("SummonAutoBlocksShortcuts")
 hud.playtimerewardsopenFrame.Visible=not hidden and not shortModal and not skipping and not hud:GetAttribute("SummonAutoBlocksShortcuts")
 hud.questsopenFrame.Visible=not hidden and not shortModal and not skipping and not hud:GetAttribute("SummonAutoBlocksShortcuts")
 -- Settings remains available outside compact modals so Hide HUD can be undone.
 hud.settingsopenframe.Visible=not shortModal
 for _,g in pg:GetChildren() do
  if g:IsA("ScreenGui") and (g.Name=="TouchControls" or g.Name=="HotbarGui") then g.Enabled=not any end
 end
end
for _,g in {daily,play} do g:GetPropertyChangedSignal("Enabled"):Connect(function() task.defer(syncRewardControls) end) end
for _,name in {"shopui","inventoryui","settingsui","upgradesui","IndexPanel"} do hud[name]:GetPropertyChangedSignal("Visible"):Connect(function() task.defer(syncRewardControls) end) end
questsGui:GetPropertyChangedSignal("Enabled"):Connect(function() task.defer(syncRewardControls) end)
pg.ChildAdded:Connect(function() task.defer(syncRewardControls) end)
player:GetAttributeChangedSignal("HideHud"):Connect(syncRewardControls)
hud:GetAttributeChangedSignal("SummonAutoBlocksShortcuts"):Connect(syncRewardControls)
 hud:GetAttributeChangedSignal("SkipFlightActive"):Connect(syncRewardControls)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() task.defer(syncRewardControls) end)
task.defer(syncRewardControls)
