local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("SummonPromptUI")
local root = gui:WaitForChild("PromptRoot")
local button = root:WaitForChild("ActionButton")
local scale = root:WaitForChild("UIScale")
local gradient = button:WaitForChild("MainGradient")
local stroke = button:WaitForChild("OuterStroke")
local keyCap = button:WaitForChild("KeyCap")
local keyGradient = keyCap:WaitForChild("KeyGradient")
local keyText = keyCap:WaitForChild("KeyText")
local actionText = button:WaitForChild("ActionText")
local costText = button:WaitForChild("CostText")
local coinIcon = button:WaitForChild("CoinIcon")
local glarePrimary = button:WaitForChild("GlarePrimary")
local glareSecondary = button:WaitForChild("GlareSecondary")

-- One feathered sweep, without the harsh overlapping white bars.
button.ClipsDescendants = true
glareSecondary.Visible=false
glarePrimary.AnchorPoint=Vector2.new(.5,.5)
glarePrimary.Size=UDim2.fromScale(.32,2)
glarePrimary.Rotation=18
glarePrimary.BackgroundColor3=Color3.fromRGB(190,240,255)
glarePrimary.BackgroundTransparency=.82
glarePrimary.BorderSizePixel=0
glarePrimary.Position=UDim2.fromScale(-.5,.5)
local softGlare=glarePrimary:FindFirstChildWhichIsA("UIGradient") or Instance.new("UIGradient",glarePrimary)
softGlare.Rotation=0
softGlare.Transparency=NumberSequence.new({
 NumberSequenceKeypoint.new(0,1),
 NumberSequenceKeypoint.new(.3,.7),
 NumberSequenceKeypoint.new(.5,0),
 NumberSequenceKeypoint.new(.7,.7),
 NumberSequenceKeypoint.new(1,1),
})

local Catalog = require(ReplicatedStorage.Shared:WaitForChild("RockCatalog"))
local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))
local UI = require(ReplicatedStorage.Shared:WaitForChild("SummonUIStyle"))
-- Request shell content without blocking the prompt controller's startup.
task.spawn(function()
 pcall(function()
  game:GetService("ContentProvider"):PreloadAsync({ReplicatedStorage:WaitForChild("GeodeShellTemplate")})
 end)
end)
UI.mount(gui)
UI.prompt(root,false)
-- Two separate prompt cards; keyboard/gamepad and touch use the same prompts.
local tripleRoot=root:Clone()
tripleRoot.Name="TriplePromptRoot"
local station=workspace:WaitForChild("terrain"):WaitForChild("SpinButton")
local summonCenter=workspace:WaitForChild("SummoningPool")
local autoRemote=ReplicatedStorage:WaitForChild("SummonAutoRoll")
local autoMode=0
local autoNotice
local autoNoticeUntil=0
local autoGui=Instance.new("ScreenGui")
autoGui.Name="SummonAutoUI";autoGui.IgnoreGuiInset=true;autoGui.ResetOnSpawn=false;autoGui.DisplayOrder=35
autoGui.Parent=player.PlayerGui
script.Destroying:Connect(function() autoGui:Destroy() end)
local autoPanel=Instance.new("Frame")
autoPanel.Name="AutoRollPanel";autoPanel.AnchorPoint=Vector2.new(1,0)
autoPanel.Position=UDim2.new(1,-18,0,200);autoPanel.Size=UDim2.fromOffset(236,166)
autoPanel.BackgroundTransparency=1;autoPanel.BorderSizePixel=0;autoPanel.Visible=false;autoPanel.Parent=autoGui
local autoInk=Color3.fromRGB(12,19,30)
local autoColors={[1]=Color3.fromRGB(34,210,89),[3]=Color3.fromRGB(174,66,244)}
local function autoCorner(object,radius)
 local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,radius);corner.Parent=object
end
local autoTitle=Instance.new("TextLabel")
autoTitle.Name="Title";autoTitle.BackgroundTransparency=1;autoTitle.Position=UDim2.fromOffset(8,0)
autoTitle.Size=UDim2.new(1,-16,0,27);autoTitle.Font=Enum.Font.FredokaOne
autoTitle.TextSize=19;autoTitle.TextColor3=Color3.new(1,1,1)
autoTitle.TextStrokeColor3=autoInk;autoTitle.TextStrokeTransparency=0
autoTitle.Text="AUTO-ROLL";autoTitle.TextXAlignment=Enum.TextXAlignment.Left;autoTitle.ZIndex=3;autoTitle.Parent=autoPanel
local function autoButton(count,y)
 local shadow=Instance.new("Frame")
 shadow.Name="Auto"..count.."xShadow";shadow.Position=UDim2.fromOffset(8,y+5)
 shadow.Size=UDim2.new(1,-16,0,48);shadow.BackgroundColor3=autoInk
 shadow.BorderSizePixel=0;shadow.ZIndex=1;shadow.Parent=autoPanel;autoCorner(shadow,15)
 local b=Instance.new("TextButton")
 b.Name="Auto"..count.."x";b.Position=UDim2.fromOffset(8,y);b.Size=UDim2.new(1,-16,0,48)
 b.BackgroundColor3=Color3.new(1,1,1);b.BorderSizePixel=0;b.Text=""
 b.AutoButtonColor=false;b.Selectable=true;b.ZIndex=2;b.Parent=autoPanel;autoCorner(b,15)
 local sheen=Instance.new("UIGradient");sheen.Name="Sheen";sheen.Rotation=90;sheen.Parent=b
 local color=autoColors[count]
 sheen.Color=ColorSequence.new(color:Lerp(Color3.new(1,1,1),.28),color:Lerp(autoInk,.2))
 local rim=Instance.new("UIStroke");rim.Name="CandyRim";rim.Color=autoInk;rim.Thickness=3;rim.Parent=b
 local gloss=Instance.new("Frame")
 gloss.Name="Gloss";gloss.Position=UDim2.fromOffset(7,5);gloss.Size=UDim2.new(1,-14,0,12)
 gloss.BackgroundColor3=Color3.new(1,1,1);gloss.BackgroundTransparency=.78
 gloss.BorderSizePixel=0;gloss.ZIndex=3;gloss.Parent=b;autoCorner(gloss,8)
 local main=Instance.new("TextLabel")
 main.Name="MainLabel";main.BackgroundTransparency=1;main.Position=UDim2.fromOffset(5,3)
 main.Size=UDim2.new(1,-10,0,26);main.Font=Enum.Font.FredokaOne;main.TextSize=20
 main.TextColor3=Color3.new(1,1,1);main.TextStrokeColor3=autoInk;main.TextStrokeTransparency=0
 main.TextXAlignment=Enum.TextXAlignment.Center;main.ZIndex=4;main.Parent=b
 local cost=Instance.new("TextLabel")
 cost.Name="CostLabel";cost.BackgroundTransparency=1;cost.Position=UDim2.fromOffset(5,28)
 cost.Size=UDim2.new(1,-10,0,16);cost.Font=Enum.Font.FredokaOne;cost.TextSize=13
 cost.TextColor3=Color3.new(1,1,1);cost.TextStrokeColor3=autoInk;cost.TextStrokeTransparency=0
 cost.TextXAlignment=Enum.TextXAlignment.Center;cost.ZIndex=4;cost.Parent=b
 return b
end
local autoOne=autoButton(1,30)
local autoThree=autoButton(3,85)
local autoStatus=Instance.new("TextLabel")
autoStatus.Name="Status";autoStatus.BackgroundTransparency=1;autoStatus.Position=UDim2.fromOffset(8,140)
autoStatus.Size=UDim2.new(1,-16,0,24);autoStatus.Font=Enum.Font.FredokaOne
autoStatus.TextSize=13;autoStatus.TextWrapped=true;autoStatus.TextColor3=Color3.new(1,1,1)
autoStatus.TextStrokeColor3=autoInk;autoStatus.TextStrokeTransparency=0
autoStatus.TextXAlignment=Enum.TextXAlignment.Left;autoStatus.TextYAlignment=Enum.TextYAlignment.Top
autoStatus.ZIndex=3;autoStatus.Visible=false;autoStatus.Parent=autoPanel
local ZoneConfig=require(ReplicatedStorage.Shared.ZoneConfig)
local collectionSnapshot={}
local hasPendingSummon=false
local function currentCollection()
 return ZoneConfig.ById[player:GetAttribute("SelectedSummonCollection") or "driftwood"] or ZoneConfig.List[1]
end
local function collectionLocked()
 return not ZoneConfig.unlocked(collectionSnapshot,currentCollection().id)
end
local autoCost=require(ReplicatedStorage.Shared.SummonConfig).Cost
local function updateAutoButtons(reason)
 if reason then autoNotice=reason;autoNoticeUntil=os.clock()+3.5
 else autoNotice=nil end
 for count,b in {[1]=autoOne,[3]=autoThree} do
  local enabled=autoMode==count
  autoCost=currentCollection().cost
  b.MainLabel.Text=enabled and ("AUTO "..count.."x  ON") or ("AUTO "..count.."x")
  b.CostLabel.Text=enabled and "TAP TO STOP" or (collectionLocked() and "AREA LOCKED" or (autoCost*count).." COINS")
  b.Active=enabled or not collectionLocked();b.Selectable=b.Active
 end
 autoStatus.Visible=autoNotice~=nil and os.clock()<autoNoticeUntil
 autoStatus.Text=autoStatus.Visible and autoNotice or ""
end
updateAutoButtons()
-- Warm the actual hidden card viewports in front of the camera at startup.
-- The same render targets move to the altar after a few rendered frames.
local warmAnchor
local warmCamera=workspace.CurrentCamera
if warmCamera then
 warmAnchor=Instance.new("Part")
 warmAnchor.Name="SummonPreviewWarmAnchor";warmAnchor.Size=Vector3.one*.1
 warmAnchor.Transparency=1;warmAnchor.Anchored=true;warmAnchor.CanCollide=false
 warmAnchor.CanTouch=false;warmAnchor.CanQuery=false;warmAnchor.CastShadow=false
 warmAnchor.CFrame=CFrame.new(warmCamera.CFrame.Position+warmCamera.CFrame.LookVector*20-Vector3.new(0,8,0))
 warmAnchor.Parent=workspace
end
local worldUI=Instance.new("BillboardGui")
worldUI.Name="SummonWorldUI";worldUI.Adornee=warmAnchor or summonCenter
worldUI.Size=UDim2.fromScale(8.8,14)
worldUI.StudsOffsetWorldSpace=Vector3.new(0,9,0)
worldUI.AlwaysOnTop=false;worldUI.LightInfluence=0;worldUI.Active=true
-- Proximity fade owns visibility; no distance culling midway through the exit.
worldUI.MaxDistance=0;worldUI.ResetOnSpawn=false;worldUI.Parent=player.PlayerGui
script.Destroying:Connect(function() worldUI:Destroy() end)
local actions=Instance.new("Frame");actions.Name="SummonActions";actions.BackgroundTransparency=1
actions.AnchorPoint=Vector2.new(.5,.5);actions.Position=UDim2.fromScale(.5,8/14);actions.Size=UDim2.fromOffset(156,374);actions.Parent=worldUI
local actionsLimit=Instance.new("UISizeConstraint");actionsLimit.MaxSize=Vector2.new(156,374);actionsLimit.Parent=actions
root.Parent=actions;tripleRoot.Parent=actions
local tripleButton=tripleRoot.ActionButton
local triplePrompt
local tripleVisual=false
root.Position=UDim2.new(.5,0,0,0)
tripleRoot.Position=UDim2.new(.5,0,0,194)
for _,card in {root,tripleRoot} do
 card.Size=UDim2.new(.48,0,0,96)
 local b=card.ActionButton
 b.KeyCap.Size=UDim2.fromOffset(42,42)
 b.KeyCap.Position=UDim2.fromOffset(10,15)
 b.ActionText.Position=UDim2.fromOffset(62,10)
 b.ActionText.Size=UDim2.new(1,-70,0,27)
 b.ActionText.TextScaled=true
 local limit=Instance.new("UITextSizeConstraint");limit.MaxTextSize=22;limit.MinTextSize=10;limit.Parent=b.ActionText
 b.CostText.TextScaled=true
 local costLimit=Instance.new("UITextSizeConstraint");costLimit.MaxTextSize=14;costLimit.MinTextSize=9;costLimit.Parent=b.CostText
end
UI.action(root,false)
UI.action(tripleRoot,true)
-- The selector shares this pedestal billboard, card scaling, and captured fade.
worldUI.ClipsDescendants=false
local areaSelector=require(ReplicatedStorage.Shared:WaitForChild("SummonAreaSelector")).mount(root)
tripleButton.ActionText.Text="SUMMON 3"
tripleButton.CostText.Position=UDim2.new(0,7,1,-22)
tripleButton.CostText.Size=UDim2.new(1,-14,0,17)
tripleButton.CostText.Text=tostring(currentCollection().cost*3).." COINS"
tripleButton.CoinIcon.Visible=false
local RunService=game:GetService("RunService")
local cardsScale=Instance.new("UIScale");cardsScale.Parent=actions
local function resizeCards()
 cardsScale.Scale=math.max(.01,worldUI.AbsoluteSize.X/274.56)
end
resizeCards()
-- Keep the original pedestal design within small or closely zoomed viewports.
local fitConnection=RunService.RenderStepped:Connect(function()
 local camera=workspace.CurrentCamera
 if not camera or not worldUI.Adornee then return end
 local base=camera:WorldToViewportPoint(worldUI.Adornee.Position)
 local up=camera:WorldToViewportPoint(worldUI.Adornee.Position+Vector3.yAxis)
 local pixelsPerStud=math.max(1,base.Y-up.Y)
 local topMargin=math.min(95,camera.ViewportSize.Y*.22)
 local bottomMargin=math.min(24,camera.ViewportSize.Y*.06)
 local height=math.min(14*pixelsPerStud,camera.ViewportSize.Y*.62,camera.ViewportSize.Y-topMargin-bottomMargin)
 worldUI.Size=UDim2.fromOffset(height*8.8/14,height)
 local center=math.clamp(base.Y-9*pixelsPerStud,topMargin+height/2,camera.ViewportSize.Y-bottomMargin-height/2)
 worldUI.StudsOffsetWorldSpace=Vector3.new(0,(base.Y-center)/pixelsPerStud,0)
end)
script.Destroying:Connect(function() fitConnection:Disconnect() end)
local resizeConnection=worldUI:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeCards)
script.Destroying:Connect(function() resizeConnection:Disconnect() end)
local homePosition=root.Position
local promptProgress=0
local promptActive=false
local fadeProperties={}
local function captureFade(object,property)
 table.insert(fadeProperties,{object=object,property=property,base=object[property]})
 object[property]=1
end
local fadeObjects=root:GetDescendants()
for _,object in tripleRoot:GetDescendants() do table.insert(fadeObjects,object) end
for _,object in fadeObjects do
 if object:IsDescendantOf(areaSelector.AreaName) then continue end -- Letters multiply their wave by PromptOpacity.
 if object:IsA("GuiObject") then captureFade(object,"BackgroundTransparency") end
 if object:IsA("TextLabel") or object:IsA("TextButton") then
  captureFade(object,"TextTransparency");captureFade(object,"TextStrokeTransparency")
 elseif object:IsA("ImageLabel") or object:IsA("ImageButton") or object:IsA("ViewportFrame") then
  captureFade(object,"ImageTransparency")
 elseif object:IsA("UIStroke") then
  captureFade(object,"Transparency")
 end
end
local autoFadeProperties={}
local function captureAutoFade(object,property)
 table.insert(autoFadeProperties,{object=object,property=property,base=object[property]})
 object[property]=1
end
for _,object in autoPanel:GetDescendants() do
 if object:IsA("GuiObject") then captureAutoFade(object,"BackgroundTransparency") end
 if object:IsA("TextLabel") or object:IsA("TextButton") then
  captureAutoFade(object,"TextTransparency");captureAutoFade(object,"TextStrokeTransparency")
 elseif object:IsA("ImageLabel") or object:IsA("ImageButton") or object:IsA("ViewportFrame") then
  captureAutoFade(object,"ImageTransparency")
 elseif object:IsA("UIStroke") then
  captureAutoFade(object,"Transparency")
 end
end
local autoProgress=0
local autoActive=false
local autoHomePosition=autoPanel.Position
-- Keep transparent card viewports mounted so their render targets warm before reveal.
root.Visible=true
tripleRoot.Visible=true
worldUI.Active=false
button.Active=false;button.Selectable=false
tripleButton.Active=false;tripleButton.Selectable=false
root:SetAttribute("PromptActive",false)
root:SetAttribute("PromptOpacity",0)
if warmAnchor then
 task.delay(.25,function()
  if worldUI.Parent then worldUI.Adornee=summonCenter end
  warmAnchor:Destroy()
 end)
 script.Destroying:Connect(function() warmAnchor:Destroy() end)
end
local fadeConnection=RunService.RenderStepped:Connect(function(dt)
 if not promptActive and promptProgress==0 and not autoActive and autoProgress==0 then return end
 promptProgress=math.clamp(promptProgress+(promptActive and 1 or -1)*dt/(promptActive and .55 or .4),0,1)
 local opacity=promptProgress*promptProgress*(3-2*promptProgress)
 root:SetAttribute("PromptOpacity",opacity)
 for _,fade in fadeProperties do
  fade.object[fade.property]=1-(1-fade.base)*opacity
 end
 local offset=player:GetAttribute("ReducedMotion")==true and 0 or (1-opacity)*18
 root.Position=homePosition+UDim2.fromOffset(0,offset)
 root.Visible=true
 tripleRoot.Visible=promptProgress==0 or tripleVisual
 local interactive=promptActive and promptProgress>0
 worldUI.Active=interactive
 button.Active=interactive and (not collectionLocked() or hasPendingSummon);button.Selectable=button.Active
 tripleButton.Active=interactive and tripleVisual and (not collectionLocked() or hasPendingSummon);tripleButton.Selectable=tripleButton.Active
 if promptProgress==0 then tripleVisual=false end
 tripleRoot.Position=UDim2.new(.5,0,0,194+offset)
 autoProgress=math.clamp(autoProgress+(autoActive and 1 or -1)*dt/(autoActive and .55 or .4),0,1)
 local autoOpacity=autoProgress*autoProgress*(3-2*autoProgress)
 for _,fade in autoFadeProperties do
  fade.object[fade.property]=1-(1-fade.base)*autoOpacity
 end
 local autoOffset=player:GetAttribute("ReducedMotion")==true and 0 or (1-autoOpacity)*18
 autoPanel.Position=autoHomePosition+UDim2.fromOffset(0,autoOffset)
 autoPanel.Visible=autoProgress>0
end)
script.Destroying:Connect(function() fadeConnection:Disconnect() end)

local greenGradient = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(124, 255, 136)),
	ColorSequenceKeypoint.new(0.48, Color3.fromRGB(48, 222, 83)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 164, 64)),
})
local rewardGradient = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 239, 119)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 176, 50)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 94, 36)),
})

local currentPrompt
local summoning=false
local activeToken
local introSummonAvailable=false
local glareVersion = 0

glarePrimary.Visible=false
glareSecondary.Visible=false
local function runGlare() end

local function applies(prompt)
	local owner = prompt:GetAttribute("OwnerUserId")
	return prompt:GetAttribute("SummonPrompt") == true and (owner == nil or owner == player.UserId)
end

local function updateKey()
 local lastInput=UserInputService:GetLastInputType()
 tripleButton.KeyCap.KeyText.Text=lastInput==Enum.UserInputType.Touch and "TAP" or
  (string.find(lastInput.Name,"Gamepad") and "Y" or "R")
	local input = UserInputService:GetLastInputType()
	if input == Enum.UserInputType.Touch then
		keyText.Text = "TAP"
	elseif string.find(input.Name, "Gamepad") then
		keyText.Text = currentPrompt and currentPrompt.GamepadKeyCode.Name:gsub("Button", "") or "X"
	else
		keyText.Text = currentPrompt and currentPrompt.KeyboardKeyCode.Name or "E"
	end
end

local function show(prompt)
 if prompt:GetAttribute("SummonTriplePrompt")==true then
  triplePrompt=prompt
  updateKey()
  return
 end
	if not applies(prompt) then return end
	currentPrompt = prompt
	local isReward = prompt:GetAttribute("RewardPrompt") == true or prompt.ActionText == "Claim"
	actionText.Text = string.upper(prompt.ActionText ~= "" and prompt.ActionText or "SUMMON")
	if isReward then
		coinIcon.Visible = false
		costText.Position = UDim2.fromOffset(88, 43)
		costText.Size = UDim2.new(1, -102, 0, 30)
		costText.Text = prompt.ObjectText
		costText.TextColor3 = Color3.fromRGB(255, 250, 210)
		gradient.Color = rewardGradient
		keyCap.BackgroundColor3 = Color3.fromRGB(199, 91, 22)
		keyGradient.Color = ColorSequence.new(Color3.fromRGB(255, 156, 45), Color3.fromRGB(168, 55, 17))
		stroke.Color = Color3.fromRGB(118, 49, 10)
	else
		coinIcon.Visible = true
		costText.Position = UDim2.fromOffset(116, 43)
		costText.Size = UDim2.new(1, -128, 0, 30)
		costText.Text = if introSummonAvailable and currentCollection().id=="driftwood" and not hasPendingSummon then "FREE FIRST ROLL" else tostring(currentCollection().cost)
		costText.TextColor3 = Color3.fromRGB(250, 255, 218)
		gradient.Color = greenGradient
		keyCap.BackgroundColor3 = Color3.fromRGB(19, 128, 53)
		keyGradient.Color = ColorSequence.new(Color3.fromRGB(32, 158, 69), Color3.fromRGB(9, 96, 38))
		stroke.Color = Color3.fromRGB(8, 79, 34)
	end
	UI.prompt(root,isReward)
 if not isReward then
  actionText.Text=if collectionLocked() then "AREA LOCKED" elseif introSummonAvailable and currentCollection().id=="driftwood" and not hasPendingSummon then "CLAIM FREE ROLL" else "SUMMON 1"
  coinIcon.Visible=false
  costText.Position=UDim2.new(0,7,1,-22)
  costText.Size=UDim2.new(1,-14,0,17)
  costText.Text=if introSummonAvailable and currentCollection().id=="driftwood" and not hasPendingSummon then "FREE FIRST ROLL" else tostring(currentCollection().cost).." COINS"
 end
 tripleButton.ActionText.Text=hasPendingSummon and "RESUME" or (collectionLocked() and "AREA LOCKED" or "SUMMON 3")
 tripleButton.CostText.Text=hasPendingSummon and "Already paid" or tostring(currentCollection().cost*3).." COINS"
 if not isReward and collectionLocked() and not hasPendingSummon then
  costText.Text="REACH "..currentCollection().name
  tripleButton.CostText.Text="TO SUMMON THESE ROCKS"
 end
 if not isReward and hasPendingSummon then
  actionText.Text="RESUME"
  costText.Text="Already paid";coinIcon.Visible=false
 end
	updateKey()
 local entering=not promptActive
 promptActive=true
 root:SetAttribute("PromptActive",true)
 if entering then runGlare() end
end

-- The same distance gate controls the cards and the floating rocks.
local stationPrompt=station:WaitForChild("ProximityPrompt")
local function inStationRange()
 local character=player.Character
 local hrp=character and character:FindFirstChild("HumanoidRootPart")
 local humanoid=character and character:FindFirstChildWhichIsA("Humanoid")
 return station.Parent and stationPrompt.Enabled and applies(stationPrompt)
  and hrp and humanoid and humanoid.Health>0
  and (hrp.Position-station.Position).Magnitude<=stationPrompt.MaxActivationDistance
end
local function inSummonArea()
 return not summoning and inStationRange()
end
for count,b in {[1]=autoOne,[3]=autoThree} do
 b.Activated:Connect(function()
  if collectionLocked() and not autoMode then return end
  if autoMode~=count and not inStationRange() then return end
  autoRemote:FireServer(count)
 end)
end
local proximityConnection=RunService.Heartbeat:Connect(function()
 if autoNotice and os.clock()>=autoNoticeUntil then autoNotice=nil;updateAutoButtons() end
 autoActive=inStationRange()
 local nearby=inSummonArea()
 local triple=station:FindFirstChild("SummonThreePrompt")
 triplePrompt=nearby and triple and triple.Enabled and triple or nil
 -- Keep the visual alive during exit even after interaction becomes unavailable.
 if triplePrompt then tripleVisual=true end
 if nearby then
  if not promptActive or currentPrompt~=stationPrompt then show(stationPrompt) end
 elseif promptActive then
  currentPrompt=nil;promptActive=false
  root:SetAttribute("PromptActive",false)
 end
end)
script.Destroying:Connect(function() proximityConnection:Disconnect() end)

tripleButton.Activated:Connect(function()
 if (collectionLocked() and not hasPendingSummon) or not inSummonArea() or not triplePrompt or not triplePrompt.Enabled then return end
 local activated=triplePrompt
 activated:InputHoldBegin()
 task.delay(math.max(activated.HoldDuration,.05),function()
  if activated.Parent then activated:InputHoldEnd() end
 end)
end)
button.Activated:Connect(function()
	if (collectionLocked() and not hasPendingSummon) or not inSummonArea() or not currentPrompt or not currentPrompt.Enabled then return end
	local activatedPrompt = currentPrompt
	activatedPrompt:InputHoldBegin()
	task.delay(math.max(activatedPrompt.HoldDuration, 0.05), function()
		if activatedPrompt.Parent then activatedPrompt:InputHoldEnd() end
	end)
end)

local panel = gui:WaitForChild("SummonResult")
local edge = panel:WaitForChild("Outline")
local heading = panel:WaitForChild("Heading")
local rockImage = panel:WaitForChild("RockImage")
local rockName = panel:WaitForChild("RockName")
local detail = panel:WaitForChild("Details")
local equip = panel:WaitForChild("Equip")
local dismiss = panel:WaitForChild("Dismiss")
local Presentation = require(ReplicatedStorage.Shared:WaitForChild("SummonPresentation"))
local interaction = ReplicatedStorage:WaitForChild("SummonInteract")
player.CharacterRemoving:Connect(function() summoning=false;activeToken=nil;Presentation.stop(true) end)
local resultId
local messageVersion = 0

dismiss.Activated:Connect(function()
	panel.Visible = false
end)

equip.Activated:Connect(function()
	if resultId then
		Remotes.RequestEquip:FireServer("rock", resultId)
		equip.Text = "EQUIPPING..."
	end
end)

Remotes.ProfileState.OnClientEvent:Connect(function(state)
 collectionSnapshot=state
 updateAutoButtons()
 hasPendingSummon=state.hasPendingSummon==true
 introSummonAvailable=state.introSummonAvailable==true
 if currentPrompt and currentPrompt.Parent and root.Visible then show(currentPrompt) end
	if resultId and state.rockEquipped == resultId then equip.Text = "EQUIPPED" end
end)

Remotes.RequestShopState:FireServer()

player:GetAttributeChangedSignal("SelectedSummonCollection"):Connect(function()
 autoCost=currentCollection().cost;updateAutoButtons()
 if currentPrompt and currentPrompt.Parent and root.Visible then show(currentPrompt) end
end)

ReplicatedStorage:WaitForChild("SummonFeedback").OnClientEvent:Connect(function(kind, data)
 if kind=="CollectionSelected" then return end
 if kind=="AutoRollState" then
  autoMode=data.mode or 0
  if autoMode==0 and not activeToken then summoning=false end
  Presentation.setAutoMode(autoMode)
  updateAutoButtons(data.reason)
  return
 end
 if kind=="Rolling" then
  if activeToken and data.token<=activeToken then return end
  activeToken=data.token
 elseif kind~="Error" and data.token~=activeToken then return end
 if kind=="Stored" then panel.Visible=false;gui.StoreToast.Visible=false;return end
 if kind=="Closed" then
  activeToken=nil
  -- The next auto-roll starts immediately; keep altar prompts hidden until then.
  if autoMode==0 then summoning=false end
  Presentation.stop()
  return
 end
 if kind=="FadeOut" or kind=="Seal" or kind=="Strike" or kind=="Anticipation" or kind=="Open" or kind=="Checkpoint" or kind=="Upgrade" then
  Presentation.stage(kind,data);return
 end
 if kind=="Rolling" then summoning=true;gui.StoreToast.Visible=false;Presentation.begin(data,interaction) end
 if kind=="Result" then panel.Visible=false;Presentation.stage(kind,data);return end
 if kind=="Error" then
  if summoning then return end
  activeToken=nil;Presentation.stop()
 end
	messageVersion += 1
	local version = messageVersion
	panel.Visible = true
	resultId = nil
	equip.Visible = false
	dismiss.Visible = true
	rockImage.Visible = false
	detail.Text = ""
	rockName.Text = ""
	if kind == "Rolling" then
		-- Compact, translucent progress card: visible but never blocks the screen.
		panel.Size = UDim2.fromOffset(285, 86)
		panel.BackgroundTransparency = 0.28
		edge.Transparency = 0.35
		panel.Position = UDim2.fromScale(0.5, 0.12)
		heading.Text = "SUMMONING"
		heading.TextColor3 = Color3.fromRGB(126, 216, 255)
		rockName.Text = "Awaken the stone. Break its seal."
		detail.Text = "Crack open the geode to reveal your rock."
		rockName.Position = UDim2.fromOffset(22, 39)
		rockName.Size = UDim2.new(1, -44, 0, 24)
		detail.Position = UDim2.fromOffset(22, 61)
		detail.Size = UDim2.new(1, -44, 0, 18)
		dismiss.Visible = false
        panel.Visible = false
	elseif kind == "Error" then
		panel.Size = UDim2.fromOffset(380, 224)
		panel.BackgroundTransparency = 0
		edge.Transparency = 0
		heading.Text = "CANNOT SUMMON"
		heading.TextColor3 = Color3.fromRGB(255, 164, 138)
		rockName.Text = data.message or "Please try again."
        UI.error(panel)
		task.delay(4, function()
			if version == messageVersion then panel.Visible = false end
		end)
	elseif kind == "Result" then
		-- Final reward uses the same light transparency, with a centered layout.
		panel.Size = UDim2.fromOffset(380, 224)
		panel.BackgroundTransparency = 0.22
		edge.Transparency = 0.2
		heading.Position = UDim2.fromOffset(16, 10)
		heading.Size = UDim2.new(1, -32, 0, 24)
		rockImage.Position = UDim2.new(0.5, -36, 0, 38)
		rockImage.Size = UDim2.fromOffset(72, 72)
		rockName.Position = UDim2.fromOffset(16, 110)
		rockName.Size = UDim2.new(1, -32, 0, 30)
		detail.Position = UDim2.fromOffset(16, 140)
		detail.Size = UDim2.new(1, -32, 0, 22)
		local rock = Catalog.get(data.id)
		resultId = data.id
		local color = Catalog.RarityColors[rock.rarity] or Color3.new(1, 1, 1)
		edge.Color = color
		heading.TextColor3 = color
		heading.Text = (data.isNew and "NEW DISCOVERY • " or "COLLECTED • ") .. string.upper(rock.rarity)
		rockImage.Visible = true
		rockImage.Image = rock.image or ""
		rockName.Text = rock.name
		detail.Text = string.format("%.2fx strength  •  %s owned", Catalog.resolveStats(rock.id).strengthMultiplier, tostring(data.count))
		equip.Visible = true
		equip.Text = "EQUIP"
		panel.Position = UDim2.new(0.5, 0, 0.14, 12)
        UI.result(panel,rock,data)
	end
end)

UserInputService.LastInputTypeChanged:Connect(updateKey)
ProximityPromptService.PromptShown:Connect(updateKey)
updateKey()



