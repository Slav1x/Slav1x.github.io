--!strict
-- MainHUD visuals live in StarterGui. This controller only updates data and behavior.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local hud = script.Parent
local shared = ReplicatedStorage:WaitForChild("Shared")
local ui = ReplicatedStorage:WaitForChild("SharedUI")
local Remotes = require(shared:WaitForChild("Remotes"))
local Rocks = require(shared:WaitForChild("RockCatalog"))
local Pets = require(shared:WaitForChild("PetCatalog"))
local CollectionConfig = require(shared:WaitForChild("CollectionConfig"))
local UISounds = require(ui:WaitForChild("UISounds"))
local ProfileStore = require(player:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("ProfileStore"))
local ThrowInput = require(player.PlayerScripts.Client:WaitForChild("ThrowInput"))
local friend = hud:WaitForChild("FriendBoostHUD")
local friendText = friend:WaitForChild("Value")
local invite = friend:WaitForChild("Invite")
local inviteTip = friend:WaitForChild("FriendTip")
local multiplier = hud:WaitForChild("CashMultiplierHUD")
local multValue = multiplier:WaitForChild("Value")
local breakdown = hud:WaitForChild("MultiplierBreakdown")
local breakdownList = breakdown:WaitForChild("BreakdownList")
local breakdownTotal = breakdown:WaitForChild("Total")
local summon = hud:WaitForChild("SummonGroveQuickButton")
local summonTitle = summon:WaitForChild("Title")
local summonFace = summon:WaitForChild("Face")
local indexButton = hud.LeftNav:WaitForChild("Index")
local autoButton = hud.LeftNav:WaitForChild("AutoThrow")
local backdrop = hud:WaitForChild("IndexBackdrop")
local panel = hud:WaitForChild("IndexPanel")
local panelScale = panel:WaitForChild("PanelScale")
local header = panel:WaitForChild("Header")
local close = header:WaitForChild("Close")
local tabs = panel:WaitForChild("VariantTabs")
local standard = tabs:WaitForChild("Standard")
local enchanted = tabs:WaitForChild("Enchanted")
local categories = panel:WaitForChild("Categories")
local rocksTab = categories:WaitForChild("Rocks")
local petsTab = categories:WaitForChild("Pets")
local grid = panel:WaitForChild("Grid")
local cardTemplate = grid:WaitForChild("CardTemplate")
local enchantedTemplate = grid:WaitForChild("EnchantedCardTemplate")
local progress = panel:WaitForChild("Progress")
local progressTitle = progress:WaitForChild("Title")
local progressFill = progress.Track.Fill
local nextReward = progress:WaitForChild("NextReward")
local ink = Color3.fromRGB(8, 28, 48)
local white = Color3.fromRGB(250, 253, 255)
local cyan = Color3.fromRGB(39, 204, 244)
local purple = Color3.fromRGB(161, 78, 230)
local category = "rocks"
local variant = "standard"
local autoOn = false
local pinnedBreakdown = false
local indexBlur = Lighting:FindFirstChild("IndexWorldBlur") or Instance.new("BlurEffect")
indexBlur.Name = "IndexWorldBlur"
indexBlur.Size = 0
indexBlur.Enabled = true
indexBlur.Parent = Lighting
local layoutScale = 1

local function play(kind)
	UISounds.play(kind)
end
local function animate(button, callback)
	local scale = button:FindFirstChildOfClass("UIScale")
	if scale then
		local function base() return button:GetAttribute("BaseScale") or 1 end
		button.MouseEnter:Connect(function()
			if not player:GetAttribute("ReducedMotion") then TweenService:Create(scale, TweenInfo.new(.13), {Scale=base()*1.055}):Play() end
			play("Hover")
		end)
		button.MouseLeave:Connect(function() TweenService:Create(scale, TweenInfo.new(.13), {Scale=base()}):Play() end)
		button.InputBegan:Connect(function(input)
			if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
				TweenService:Create(scale, TweenInfo.new(.07), {Scale=base()*.94}):Play()
			end
		end)
		button.InputEnded:Connect(function(input)
			if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
				TweenService:Create(scale, TweenInfo.new(.1), {Scale=base()}):Play()
			end
		end)
	end
	button.Activated:Connect(function() play("Click"); callback() end)
end
local function has(list, id)
	if typeof(list)~="table" then return false end
	for _, value in list do if value==id then return true end end
	return false
end
local function multiplierText(value)
	if math.abs(value-math.round(value))<.005 then return tostring(math.round(value)).."x" end
	return string.format("%.2f",value):gsub("0$","").."x"
end
invite.MouseEnter:Connect(function() inviteTip.Visible=true end)
invite.MouseLeave:Connect(function() inviteTip.Visible=false end)
invite.Activated:Connect(function()
 play("Click")
 local ok,err=pcall(function() SocialService:PromptGameInvite(player) end)
 if not ok then warn("[MainHUD] Invite prompt failed: "..tostring(err)) end
end)
multiplier.MouseEnter:Connect(function() if not panel.Visible then breakdown.Visible=true end end)
multiplier.MouseLeave:Connect(function() if not pinnedBreakdown then breakdown.Visible=false end end)
animate(multiplier,function() pinnedBreakdown=not pinnedBreakdown; breakdown.Visible=pinnedBreakdown end)
animate(summon,function() Remotes.RequestSummonTeleport:FireServer() end)
local summonGlare = summonFace:FindFirstChild("StaticGlare")
summon.MouseEnter:Connect(function()
	if summonGlare then TweenService:Create(summonGlare,TweenInfo.new(.13),{BackgroundTransparency=.8}):Play() end
end)
summon.MouseLeave:Connect(function()
	if summonGlare then TweenService:Create(summonGlare,TweenInfo.new(.13),{BackgroundTransparency=.9}):Play() end
end)

local function setSelected(button, active, selectedColor)
	local base = active and selectedColor or selectedColor:Lerp(Color3.fromRGB(22, 29, 34), .48)
	button.BackgroundColor3 = base
	button.BackgroundTransparency = active and 0 or .06
	local caption = button:FindFirstChild("Caption")
	if caption then
		caption.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(218, 221, 222)
		caption.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		caption.TextStrokeTransparency = 0
	end
	local line = button:FindFirstChild("TopHighlight")
	if line then line.BackgroundTransparency = active and .64 or .86 end
	local gradient = button:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Enabled = true
		gradient.Rotation = 90
		gradient.Color = ColorSequence.new(base:Lerp(Color3.new(1, 1, 1), .28), base:Lerp(Color3.new(0, 0, 0), .35))
	end
	local studs = button:FindFirstChild("Studs")
	if studs then studs.ImageTransparency = active and .46 or .65 end
end
local function rarityColor(item)
	return Rocks.RarityColors[item.rarity] or Color3.fromRGB(128,177,205)
end
local indexCardColors = {
	Common = Color3.fromRGB(87, 43, 27),
	Uncommon = Color3.fromRGB(55, 67, 45),
	Rare = Color3.fromRGB(76, 51, 30),
	Epic = Color3.fromRGB(77, 36, 72),
	Legendary = Color3.fromRGB(94, 50, 22),
	Mythical = Color3.fromRGB(77, 34, 77),
	Exclusive = Color3.fromRGB(80, 55, 35),
}
local function indexStat(item, kind)
	if kind == "rocks" then return string.format("%.2fx STRENGTH", Rocks.resolveStats(item.id).strengthMultiplier) end
	if (item.moneyBonus or 0) > 0 then return "+" .. math.floor(item.moneyBonus * 100 + .5) .. "% CASH" end
	if (item.luckBonus or 0) > 0 then return "+" .. math.floor(item.luckBonus * 100 + .5) .. "% LUCK" end
	return "COMPANION"
end
local function refreshIndex()
	grid.CanvasPosition=Vector2.zero
	for _,child in grid:GetChildren() do
		if child:IsA("Frame") and child~=cardTemplate and child~=enchantedTemplate then child:Destroy() end
	end
	local state=ProfileStore.get()
	local items=category=="rocks" and Rocks.Rocks or Pets.Pets
	local field=variant=="enchanted" and (category=="rocks" and "discoveredEnchantedRocks" or "discoveredEnchantedPets") or (category=="rocks" and "discoveredRocks" or "discoveredPets")
	local discoveries=state[field] or {}
	local count=0
	for i,item in items do
		local discovered=has(discoveries,item.id)
		if discovered then count+=1 end
		local card=(variant=="enchanted" and enchantedTemplate or cardTemplate):Clone()
		card.Name="Card_"..tostring(item.id)
		card.LayoutOrder=i
		card.Visible=true
		card.Outline.Color=Color3.fromRGB(4,4,4)
		card.Outline.Thickness=3
		card.RarityAccent.BackgroundColor3=rarityColor(item)
		card.RarityAccent.Visible=false
		card.Artwork.Image=item.image or ""
		card.Artwork.ImageColor3=discovered and white or Color3.fromRGB(0,0,0)
		card.Artwork.ImageTransparency=0
		card.Fallback.Visible=item.image==nil or item.image==""
		card.Fallback.Text=item.icon or "◆"
		card.Fallback.TextColor3=discovered and white or Color3.fromRGB(0,0,0)
		card.Fallback.TextSize=76
		card.Fallback.TextStrokeTransparency=discovered and .25 or 1
		card.Question.Visible=true
		card.Question.Text=discovered and item.name or "???"
		card.Question.TextSize=discovered and 18 or 29
		card.Question.TextColor3=white
		card:FindFirstChild("Name").Text=discovered and indexStat(item,category) or "???"
		card:FindFirstChild("Name").TextColor3=Color3.fromRGB(255,190,72)
		card:FindFirstChild("Name").TextSize=workspace.CurrentCamera.ViewportSize.Y<500 and 14 or 17
		card.Rarity.TextSize=workspace.CurrentCamera.ViewportSize.Y<500 and 13 or 17
		local cardColor=indexCardColors[item.rarity] or Color3.fromRGB(70,47,35)
		card.BackgroundColor3=cardColor
		card.BackgroundTransparency=.24
		local cardGradient=card:FindFirstChildOfClass("UIGradient")
		if cardGradient then
			cardGradient.Color=ColorSequence.new(cardColor:Lerp(Color3.new(1,1,1),.18),cardColor:Lerp(Color3.new(0,0,0),.28))
		end
		card.Rarity.Text=item.rarity or "Unknown"
		card.Rarity.TextColor3=rarityColor(item)
		card.Sparkle.Visible=variant=="enchanted" and discovered
  if category=="rocks" and discovered then
   local viewport=Instance.new("ViewportFrame")
   viewport.Name="RockAppearancePreview";viewport.BackgroundTransparency=1
   viewport.Position=card.Artwork.Position;viewport.Size=card.Artwork.Size;viewport.AnchorPoint=card.Artwork.AnchorPoint
   viewport.ZIndex=card.Artwork.ZIndex;viewport.Parent=card
   require(shared.RockAppearance).populateViewport(viewport,item.id,variant)
   card.Artwork.Visible=false;card.Fallback.Visible=false
  end
		card.Parent=grid
	end
	local prefix=(variant=="enchanted" and "ENCHANTED " or "")..string.upper(category)
	progressTitle.Text=string.format("%s  %d/%d",variant=="enchanted" and "Enchanted" or "Normal",count,#items)
	progressFill.Size=UDim2.fromScale(#items>0 and count/#items or 0,1)
	if category=="rocks" and variant=="standard" then
		local milestone=CollectionConfig.nextRockMilestone(count)
		if milestone then
			nextReward.Text=string.format("NEXT REWARD\n%d / %d ROCKS • +%d%% CASH",math.min(count,milestone.Required),milestone.Required,math.floor(milestone.CashBonus*100+.5))
		else nextReward.Text="COLLECTION BONUS\n+"..math.floor(CollectionConfig.rockBonus(count)*100+.5).."% CASH ACTIVE" end
	else nextReward.Text=variant=="enchanted" and "ENCHANTED COLLECTION\nRARE MAGICAL FINDS" or "KEEP DISCOVERING\nPERMANENTLY TRACKED" end
	setSelected(rocksTab,category=="rocks",Color3.fromRGB(45,198,252))
	setSelected(petsTab,category=="pets",Color3.fromRGB(61,146,196))
	rocksTab.Caption.Text="Rocks"
	petsTab.Caption.Text="Pets"
	setSelected(standard,variant=="standard",Color3.fromRGB(246,247,247))
	setSelected(enchanted,variant=="enchanted",Color3.fromRGB(255,183,34))
	local magical=variant=="enchanted"
	panel.BackgroundColor3=Color3.fromRGB(27,23,20)
	panel.BackgroundTransparency=.78
	grid.BackgroundColor3=Color3.fromRGB(31,25,22)
	grid.BackgroundTransparency=.92
	header.BackgroundColor3=Color3.fromRGB(2,172,213)
	local headerGradient=header:FindFirstChildOfClass("UIGradient")
	if headerGradient then headerGradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(26,218,236)),ColorSequenceKeypoint.new(.48,Color3.fromRGB(3,163,213)),ColorSequenceKeypoint.new(1,Color3.fromRGB(4,91,167))}) end
	progressFill.BackgroundColor3=Color3.fromRGB(255,172,4)
end
local indexClosing=false
local indexTransition=0
local indexScaleTween
local function closeIndex()
	if not panel.Visible or indexClosing then return end
	indexClosing=true
	indexTransition+=1
	local token=indexTransition
	play("Close")
	if indexScaleTween then indexScaleTween:Cancel() end
	if player:GetAttribute("ReducedMotion") then
		panel.Visible=false; backdrop.Visible=false; panelScale.Scale=layoutScale; indexClosing=false
	else
		indexScaleTween=TweenService:Create(panelScale,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=layoutScale*.82})
		indexScaleTween:Play()
		indexScaleTween.Completed:Once(function(state)
			if state==Enum.PlaybackState.Completed and indexTransition==token then
				panel.Visible=false; backdrop.Visible=false; panelScale.Scale=layoutScale; indexClosing=false
			end
		end)
	end
	TweenService:Create(indexBlur,TweenInfo.new(.18),{Size=0}):Play()
	if hud:GetAttribute("CurrentMenu")=="index" then hud:SetAttribute("CurrentMenu","") end
end
local function openIndex()
	if panel.Visible and not indexClosing then closeIndex(); return end
	indexTransition+=1
	indexClosing=false
	if indexScaleTween then indexScaleTween:Cancel() end
	for _,name in {"shopui","inventoryui","upgradesui","settingsui"} do
		local menu=hud:FindFirstChild(name)
		if menu and menu.Visible then
			local request=menu:FindFirstChild("CloseRequest") or menu:FindFirstChild("Toggle")
			if request then request:Fire() else menu.Visible=false end
		end
	end
	local pg=player:FindFirstChild("PlayerGui")
	if pg then
        local questsGui=pg:FindFirstChild("QuestsUI")
        if questsGui and questsGui.Enabled then questsGui.QuestPanel.CloseRequest:Fire() end
		for _,name in {"DailyRewardsUI","PlaytimeGiftsUI"} do
			local menu=pg:FindFirstChild(name)
			if menu and menu.Enabled then menu.CloseRequest:Fire() end
		end
	end
	hud:SetAttribute("CurrentMenu","index")
	pinnedBreakdown=false
	breakdown.Visible=false
	backdrop.BackgroundTransparency=1
	backdrop.Visible=true
	panel.Visible=true
	TweenService:Create(indexBlur,TweenInfo.new(.18),{Size=24}):Play()
	panelScale.Scale=player:GetAttribute("ReducedMotion") and layoutScale or layoutScale*.82
	if not player:GetAttribute("ReducedMotion") then TweenService:Create(panelScale,TweenInfo.new(.23,Enum.EasingStyle.Back),{Scale=layoutScale}):Play() end
	play("Open")
	refreshIndex()
end
animate(indexButton,openIndex)
animate(close,closeIndex)
animate(rocksTab,function() category="rocks"; play("Tab"); refreshIndex() end)
animate(petsTab,function() category="pets"; play("Tab"); refreshIndex() end)
animate(standard,function() variant="standard"; play("Tab"); refreshIndex() end)
animate(enchanted,function() variant="enchanted"; play("Tab"); refreshIndex() end)
hud:GetAttributeChangedSignal("CurrentMenu"):Connect(function()
	if hud:GetAttribute("CurrentMenu")~="index" and panel.Visible then closeIndex() end
end)
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if not panel.Visible then
		backdrop.Visible=false
		TweenService:Create(indexBlur,TweenInfo.new(.18),{Size=0}):Play()
	end
end)
UserInputService.InputBegan:Connect(function(input,processed)
	if not processed and input.KeyCode==Enum.KeyCode.Escape and panel.Visible then closeIndex() end
end)
local function hasAuto()
	local passes=ProfileStore.get().passes
	return typeof(passes)=="table" and passes.auto_throw==true
end
local function updateAuto()
	local label=autoButton.Visuals.Label
	if not hasAuto() then label.Text="AUTO\nLOCKED"
	elseif autoOn then label.Text="AUTO\nON"
	else label.Text="AUTO\nOFF" end
	label.TextColor3=autoOn and Color3.fromRGB(180,255,131) or white
	autoButton.Visuals.ImageLabel.ImageColor3=autoOn and Color3.fromRGB(155,255,186) or Color3.fromRGB(185,228,255)
end
local function toggleAuto()
	if not hasAuto() then Remotes.RequestPromptPass:FireServer("auto_throw"); return end
	autoOn=not autoOn
	play("Tab")
	updateAuto()
end
animate(autoButton,toggleAuto)
hud:WaitForChild("OpenMenu").Event:Connect(function(name)
	if name=="index" then openIndex()
	elseif name=="index_pets" then category="pets"; variant="standard"; if not panel.Visible then openIndex() else refreshIndex() end
	elseif name=="index_enchanted" then category="rocks"; variant="enchanted"; if not panel.Visible then openIndex() else refreshIndex() end
	elseif name=="auto_throw" then toggleAuto() end
end)
task.spawn(function()
	while script.Parent do
		if autoOn and hasAuto() and not ThrowInput.isBusy() then ThrowInput.autoThrow() end
		task.wait(.25)
	end
end)
local function refreshState()
	local state=ProfileStore.get()
	local count=tonumber(state.friendCount) or 0
	friendText.Text=string.format("FRIEND BOOST: %d%%",math.floor(CollectionConfig.friendBonus(count)*100+.5))
	
	local total=tonumber(state.cashMultiplier) or 1
	multValue.Text=multiplierText(total)
	breakdownTotal.Text=multiplierText(total)
	local count = 0
	for _,entry in state.cashBreakdown or {} do
		if entry.kind ~= "total" then
		count += 1
		if count <= 10 then
			local row = breakdownList["Row"..count]
			row.Visible = true
			row.Label.Text = tostring(entry.label or "Bonus")
			if entry.kind == "base" then row.Value.Text = string.format("%.2fx",entry.value)
			elseif entry.kind == "add" then row.Value.Text = string.format("+%d%%",math.floor(entry.value*100+.5))
			elseif entry.kind == "mul" then row.Value.Text = string.format("×%.2g",entry.value)
			else row.Value.Text = tostring(entry.value or "") end
		end
		end
	end
	if count == 0 then
		local row = breakdownList.Row1
		row.Visible = true; row.Label.Text = "Discover rocks and invite friends!"; row.Value.Text = ""
	end
	for i=math.max(1,count+1),10 do breakdownList["Row"..i].Visible = false end
	if not hasAuto() then autoOn=false end
	updateAuto()
	if panel.Visible then refreshIndex() end
end
ProfileStore.onChanged(refreshState)
local cameraConnection
local autoRollPanel
local function resize()
	local camera=workspace.CurrentCamera
	if not camera then return end
	local v=camera.ViewportSize
	local narrow=v.X<700
	local mobile=v.X<520
	local tiny=v.X<320
	local short=v.Y<500
	local phoneLandscape=short and v.X<1000
	local largeScale=math.clamp(v.Y/900,1,1.45)
	if narrow then largeScale=1 end
	hud.LeftNav.ResponsiveScale.Scale=phoneLandscape and .66 or (v.X>=1000 and v.X<1450 and v.Y>=700 and v.Y<950) and 1.18 or largeScale
	if phoneLandscape then
		hud.LeftNav.AnchorPoint=Vector2.new(0,0)
		hud.LeftNav.Position=UDim2.fromOffset(7,32)
	else
		hud.LeftNav.AnchorPoint=Vector2.new(0,.5)
		hud.LeftNav.Position=UDim2.new(0,12,.44,0)
	end
	hud.Money.ResponsiveScale.Scale=phoneLandscape and .76 or largeScale
	friend.ResponsiveScale.Scale=phoneLandscape and .7 or largeScale
	hud.LevelHolder.ResponsiveScale.Scale=largeScale
	local summonScale=math.min(largeScale,1.12)
	summon:SetAttribute("BaseScale",summonScale)
	summon:FindFirstChildOfClass("UIScale").Scale=summonScale
	multiplier:SetAttribute("BaseScale",largeScale)
	multiplier:FindFirstChildOfClass("UIScale").Scale=largeScale
	for _,name in {"dailyrewardsopenFrame","playtimerewardsopenFrame","questsopenFrame","settingsopenframe"} do
		hud[name].ResponsiveScale.Scale=largeScale
	end
	inviteTip.AnchorPoint=tiny and Vector2.new(1,0) or Vector2.new(0,0)
	inviteTip.Position=tiny and UDim2.new(1,0,1,7) or UDim2.new(1,10,0,0)
	inviteTip.Size=tiny and UDim2.fromOffset(math.min(210,v.X-22),38) or UDim2.fromOffset(math.min(248,math.max(130,v.X-(mobile and 254 or 260))),mobile and 38 or 30)
	inviteTip.TextSize=mobile and 12 or 14
	-- ScreenInsets already places MainHUD inside the safe area.
	local buttonWidth=math.clamp(math.floor(v.X*.30),tiny and 148 or 178,250)
	summon.Size=UDim2.fromOffset(buttonWidth,tiny and 44 or mobile and 48 or 52)
	-- Keep the summon button clear of the level HUD on PC; center it on phones.
	if mobile then
		summon.AnchorPoint=Vector2.new(.5,0)
		summon.Position=UDim2.new(.5,0,0,phoneLandscape and 38 or 8)
	else
		summon.AnchorPoint=Vector2.new(.5,0)
		local topInset=game:GetService("GuiService"):GetGuiInset().Y
		summon.Position=UDim2.new(.5,0,0,8-topInset)
	end
	summonTitle.Position=UDim2.fromOffset(8,1)
	summonTitle.Size=UDim2.new(1,-16,1,-9)
	summonTitle.TextScaled=true
	summonTitle.TextSizeConstraint.MinTextSize=13
	summonTitle.TextSizeConstraint.MaxTextSize=tiny and 17 or mobile and 19 or 22
	local left=mobile and 11 or 15
	friend.Position=phoneLandscape and UDim2.new(0,91,1,-8) or UDim2.new(0,left,1,-math.floor(16*largeScale))
	hud.Money.Position=phoneLandscape and UDim2.new(0,91,1,-37) or UDim2.new(0,left,1,-math.floor(54*largeScale))
	multiplier.Position=UDim2.new(1,-math.floor((short and 85 or mobile and 9 or 17)*largeScale),1,-math.floor((tiny and 120 or 17)*largeScale))
	breakdown.Position=UDim2.new(1,-14,1,-14)
	breakdown.ResponsiveScale.Scale=math.min(1,(v.X-24)/356,(hud.AbsoluteSize.Y-20)/300)
	local level=hud.LevelHolder
	level.Size=mobile and UDim2.fromOffset(164,67) or short and UDim2.fromOffset(200,67) or UDim2.fromOffset(224,72)
	level.Position=UDim2.new(1,-math.floor((mobile and 9 or 15)*largeScale),0,math.floor((mobile and 9 or short and 9 or 10)*largeScale))
	local settingsHost=hud.settingsopenframe
	settingsHost.Position=UDim2.new(1,-math.floor((mobile and 8 or 17)*largeScale),0,8 - game:GetService("GuiService"):GetGuiInset().Y)
	settingsHost.Size=UDim2.fromOffset(mobile and 38 or 40,mobile and 38 or 40)
	local shortcutStep=(short and 49 or mobile and 53 or 62)*largeScale
	local shortcutSize=(short and 44 or mobile and 46 or 58)*largeScale
	local shortcutY=(short and 136 or mobile and 162 or 176)*largeScale
	local autoVisible=autoRollPanel and autoRollPanel.Visible
	if autoVisible then
		local autoBottom=autoRollPanel.AbsolutePosition.Y+autoRollPanel.AbsoluteSize.Y-hud.AbsolutePosition.Y
		shortcutY=math.max(shortcutY,autoBottom+12)
	end
	local noRoom=autoVisible and shortcutY+2*shortcutStep+shortcutSize>hud.AbsoluteSize.Y-8
	hud:SetAttribute("SummonAutoBlocksShortcuts",noRoom and true or false)
	for i,name in {"dailyrewardsopenFrame","playtimerewardsopenFrame","questsopenFrame"} do
		local host=hud[name]
		local hostY=shortcutY+(i-1)*shortcutStep
		host.Position=UDim2.new(1,-math.floor((mobile and 8 or 17)*largeScale),0,math.floor(hostY))
		host.Size=UDim2.fromOffset(short and 44 or mobile and 46 or 58,short and 44 or mobile and 46 or 58)
	end
	tabs.Size=UDim2.fromOffset(140,96)
 categories.Size=UDim2.fromOffset(140,96)
 for _,button in {standard,enchanted,rocksTab,petsTab} do button.Size=UDim2.fromOffset(140,43) end
 if phoneLandscape then
  panel.Size=UDim2.fromOffset(800,380)
  panel.Position=UDim2.fromScale(.5,.5)
  header.Size=UDim2.new(1,-8,0,58)
  local depth=panel:FindFirstChild("ReferenceHeaderDepth")
  if depth then depth.Size=header.Size;depth.Position=header.Position+UDim2.fromOffset(0,7) end
  tabs.Position=UDim2.fromOffset(17,72)
  categories.Position=UDim2.new(1,-157,0,72)
  grid.Position=UDim2.fromOffset(170,72)
  grid.Size=UDim2.new(1,-340,1,-120)
  progress.Position=UDim2.new(0,18,1,-42)
  progress.Size=UDim2.new(1,-36,0,34)
  for _,card in ipairs({cardTemplate,enchantedTemplate}) do
   card.Size=UDim2.fromOffset(136,120)
   for _,name in ipairs({"Artwork","Fallback"}) do
    local art=card:FindFirstChild(name)
    if art then art.Position=UDim2.new(.5,-37,0,4);art.Size=UDim2.fromOffset(74,66) end
   end
   card:FindFirstChild("Name").Position=UDim2.fromOffset(4,72)
   card.Rarity.Position=UDim2.fromOffset(4,98)
  end
  layoutScale=math.min((v.X-28)/800,(hud.AbsoluteSize.Y-12)/380)
 elseif mobile then
  panel.Size=UDim2.fromOffset(390,650)
  panel.Position=UDim2.fromScale(.5,.5)
  header.Size=UDim2.new(1,-8,0,62)
  local depth=panel:FindFirstChild("ReferenceHeaderDepth")
  if depth then depth.Size=header.Size;depth.Position=header.Position+UDim2.fromOffset(0,7) end
  tabs.Position=UDim2.fromOffset(10,75)
  tabs.Size=UDim2.fromOffset(115,96)
  categories.Position=UDim2.fromOffset(265,75)
  categories.Size=UDim2.fromOffset(115,96)
  for _,button in {standard,enchanted,rocksTab,petsTab} do button.Size=UDim2.fromOffset(115,43) end
  grid.Position=UDim2.fromOffset(5,177)
  grid.Size=UDim2.fromOffset(380,403)
  progress.Position=UDim2.fromOffset(10,589)
  progress.Size=UDim2.fromOffset(370,51)
  for _,card in ipairs({cardTemplate,enchantedTemplate}) do
   card.Size=UDim2.fromOffset(175,145)
   for _,name in ipairs({"Artwork","Fallback"}) do
    local art=card:FindFirstChild(name)
    if art then art.Position=UDim2.new(.5,-48,0,4);art.Size=UDim2.fromOffset(96,82) end
   end
   card:FindFirstChild("Name").Position=UDim2.fromOffset(4,91)
   card.Rarity.Position=UDim2.fromOffset(4,119)
  end
  layoutScale=math.min((hud.AbsoluteSize.X-12)/390,(hud.AbsoluteSize.Y-12)/650)
 else
  panel.Size=UDim2.fromOffset(800,548)
  panel.Position=UDim2.fromScale(.5,.5)
  header.Size=UDim2.new(1,-8,0,72)
  local depth=panel:FindFirstChild("ReferenceHeaderDepth")
  if depth then depth.Size=header.Size;depth.Position=header.Position+UDim2.fromOffset(0,7) end
  tabs.Position=UDim2.fromOffset(17,89)
  categories.Position=UDim2.new(1,-157,0,89)
  grid.Position=UDim2.fromOffset(170,89)
  grid.Size=UDim2.new(1,-340,1,-171)
  progress.Position=UDim2.new(0,18,1,-70)
  progress.Size=UDim2.new(1,-36,0,58)
  for _,card in ipairs({cardTemplate,enchantedTemplate}) do
   card.Size=UDim2.fromOffset(136,142)
   for _,name in ipairs({"Artwork","Fallback"}) do
    local art=card:FindFirstChild(name)
    if art then art.Position=UDim2.new(.5,-44,0,7);art.Size=UDim2.fromOffset(88,78) end
   end
   card:FindFirstChild("Name").Position=UDim2.fromOffset(4,87)
   card.Rarity.Position=UDim2.fromOffset(4,115)
  end
  layoutScale=math.min(largeScale,(v.X-18)/800,(hud.AbsoluteSize.Y-18)/548)
 end
 grid.GridLayout.CellSize=UDim2.fromOffset(mobile and not phoneLandscape and 175 or 136,phoneLandscape and 120 or mobile and 145 or 142)
 grid.GridLayout.FillDirectionMaxCells=mobile and not phoneLandscape and 2 or 3
 -- Keep the reference layout readable at every viewport size.
 if phoneLandscape then
  panel.Size=UDim2.fromOffset(780,380)
  header.Size=UDim2.new(1,0,0,58)
  header.Title.Position=UDim2.fromOffset(82,2)
  header.Title.Size=UDim2.new(1,-160,0,52)
  header.Title.TextSize=39
  header.Close.Position=UDim2.new(1,-12,0,7)
  header.Close.Size=UDim2.fromOffset(43,43)
  tabs.Position=UDim2.fromOffset(12,67)
  categories.Position=UDim2.fromOffset(394,67)
  tabs.Size=UDim2.fromOffset(374,42)
  categories.Size=UDim2.fromOffset(374,42)
  standard.Position=UDim2.fromOffset(0,0)
  enchanted.Position=UDim2.fromOffset(190,0)
  rocksTab.Position=UDim2.fromOffset(0,0)
  petsTab.Position=UDim2.fromOffset(190,0)
  for _,button in {standard,enchanted,rocksTab,petsTab} do button.Size=UDim2.fromOffset(181,40) end
  grid.Position=UDim2.fromOffset(12,117)
  grid.Size=UDim2.fromOffset(756,205)
  grid.GridLayout.CellSize=UDim2.fromOffset(176,136)
  grid.GridLayout.FillDirectionMaxCells=4
  progress.Position=UDim2.fromOffset(12,331)
  progress.Size=UDim2.fromOffset(756,42)
  layoutScale=math.min((hud.AbsoluteSize.X-18)/780,(hud.AbsoluteSize.Y-10)/380)
 elseif v.X<700 then
  panel.Size=UDim2.fromOffset(390,650)
  header.Size=UDim2.new(1,0,0,72)
  header.Title.Position=UDim2.fromOffset(67,5)
  header.Title.Size=UDim2.new(1,-125,0,59)
  header.Title.TextSize=39
  header.Close.Position=UDim2.new(1,-10,0,12)
  header.Close.Size=UDim2.fromOffset(43,43)
  tabs.Position=UDim2.fromOffset(8,82)
  categories.Position=UDim2.fromOffset(202,82)
  tabs.Size=UDim2.fromOffset(180,106)
  categories.Size=UDim2.fromOffset(180,106)
  for _,button in {standard,enchanted,rocksTab,petsTab} do button.Size=UDim2.fromOffset(180,46) end
  standard.Position=UDim2.fromOffset(0,0)
  enchanted.Position=UDim2.fromOffset(0,57)
  rocksTab.Position=UDim2.fromOffset(0,0)
  petsTab.Position=UDim2.fromOffset(0,57)
  grid.Position=UDim2.fromOffset(8,197)
  grid.Size=UDim2.fromOffset(374,385)
  grid.GridLayout.CellSize=UDim2.fromOffset(162,160)
  grid.GridLayout.FillDirectionMaxCells=2
  progress.Position=UDim2.fromOffset(8,594)
  progress.Size=UDim2.fromOffset(374,47)
  layoutScale=math.min((hud.AbsoluteSize.X-12)/390,(hud.AbsoluteSize.Y-12)/650)
 elseif v.X<1100 then
  panel.Size=UDim2.fromOffset(780,560)
  header.Size=UDim2.new(1,0,0,84)
  tabs.Position=UDim2.fromOffset(13,96)
  categories.Position=UDim2.fromOffset(393,96)
  tabs.Size=UDim2.fromOffset(372,53)
  categories.Size=UDim2.fromOffset(372,53)
  standard.Position=UDim2.fromOffset(0,0)
  enchanted.Position=UDim2.fromOffset(189,0)
  rocksTab.Position=UDim2.fromOffset(0,0)
  petsTab.Position=UDim2.fromOffset(189,0)
  for _,button in {standard,enchanted,rocksTab,petsTab} do button.Size=UDim2.fromOffset(180,52) end
  grid.Position=UDim2.fromOffset(13,160)
  grid.Size=UDim2.fromOffset(754,333)
  grid.GridLayout.CellSize=UDim2.fromOffset(175,160)
  grid.GridLayout.FillDirectionMaxCells=4
  progress.Position=UDim2.fromOffset(13,504)
  progress.Size=UDim2.fromOffset(754,48)
  layoutScale=math.min((hud.AbsoluteSize.X-16)/780,(hud.AbsoluteSize.Y-16)/560)
 else
  panel.Size=UDim2.fromOffset(760,580)
  header.Size=UDim2.new(1,0,0,94)
  header.Title.Position=UDim2.fromOffset(92,9)
  header.Title.Size=UDim2.new(1,-165,0,59)
  header.Title.TextSize=51
  header.Close.Position=UDim2.new(1,-17,0,15)
  header.Close.Size=UDim2.fromOffset(53,53)
  tabs.Position=UDim2.fromOffset(-238,115)
  categories.Position=UDim2.new(1,18,0,115)
  tabs.Size=UDim2.fromOffset(204,127)
  categories.Size=UDim2.fromOffset(204,127)
  for _,button in {standard,enchanted,rocksTab,petsTab} do button.Size=UDim2.fromOffset(204,57) end
  standard.Position=UDim2.fromOffset(0,0)
  enchanted.Position=UDim2.fromOffset(0,69)
  rocksTab.Position=UDim2.fromOffset(0,0)
  petsTab.Position=UDim2.fromOffset(0,69)
  grid.Position=UDim2.fromOffset(16,105)
  grid.Size=UDim2.new(1,-32,1,-119)
  grid.GridLayout.CellSize=UDim2.fromOffset(167,168)
  grid.GridLayout.FillDirectionMaxCells=4
  progress.Position=UDim2.new(0,0,1,15)
  progress.Size=UDim2.new(1,0,0,49)
  layoutScale=math.min(1,(hud.AbsoluteSize.X-26)/1224,(hud.AbsoluteSize.Y-16)/644)
 end
 grid.GridLayout.CellPadding=UDim2.fromOffset(9,9)
 for _,card in ipairs({cardTemplate,enchantedTemplate}) do
  card.Size=grid.GridLayout.CellSize
  local art=card:FindFirstChild("Artwork")
  local fallback=card:FindFirstChild("Fallback")
  if art and fallback then
   art.Position=UDim2.new(0,15,0,39)
   art.Size=UDim2.new(1,-30,1,-73)
   fallback.Position=art.Position
   fallback.Size=art.Size
  end
  card:FindFirstChild("Name").Position=UDim2.fromOffset(5,2)
  card:FindFirstChild("Name").Size=UDim2.new(1,-10,0,24)
  card.Rarity.Position=UDim2.fromOffset(5,26)
  card.Rarity.Size=UDim2.new(1,-10,0,24)
  card.Question.Position=UDim2.new(0,5,1,-32)
  card.Question.Size=UDim2.new(1,-10,0,29)
 end
 local depth=panel:FindFirstChild("ReferenceHeaderDepth")
 if depth then depth.Size=header.Size;depth.Position=header.Position+UDim2.fromOffset(0,6) end
 local icon=header:FindFirstChild("IndexBookImage")
 if icon then icon.Size=UDim2.fromOffset(v.X<700 and 56 or 70,v.X<700 and 63 or 81);icon.Position=UDim2.fromOffset(v.X<700 and 6 or 13,3) end
 local compact=phoneLandscape or mobile
 local stats=hud:FindFirstChild("StatsBar")
 if stats then
  local ss=stats:FindFirstChild("MobileScale") or Instance.new("UIScale",stats);ss.Name="MobileScale"
  ss.Scale=compact and .62 or 1
  stats.AnchorPoint=compact and Vector2.zero or Vector2.new(0,1)
  stats.Position=compact and UDim2.fromOffset(72,mobile and 44 or 0) or UDim2.new(0,16,1,-174)
 end
 hud.Money.AnchorPoint=compact and Vector2.zero or Vector2.new(0,1)
 friend.AnchorPoint=compact and Vector2.zero or Vector2.new(0,1)
 if compact then
  hud.Money.ResponsiveScale.Scale=.64;friend.ResponsiveScale.Scale=.60
  hud.Money.Position=UDim2.fromOffset(72,mobile and 105 or 46)
  friend.Position=UDim2.fromOffset(72,mobile and 147 or 88)
  hud.LeftNav.ResponsiveScale.Scale=.66
  hud.LeftNav.AnchorPoint=Vector2.zero
  hud.LeftNav.Position=UDim2.fromOffset(7,mobile and 80 or 32)
  multiplier:FindFirstChildOfClass("UIScale").Scale=.65
  multiplier.Position=UDim2.new(.5,0,1,-6)
  summon.Size=UDim2.fromOffset(180,40)
 end
 panelScale.Scale=layoutScale
end
local function bindCamera()
	if cameraConnection then cameraConnection:Disconnect() end
	if workspace.CurrentCamera then cameraConnection=workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
	resize()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()
task.spawn(function()
    local autoGui=player.PlayerGui:WaitForChild("SummonAutoUI",30)
    if not autoGui then return end
    autoRollPanel=autoGui:WaitForChild("AutoRollPanel",30)
    if autoRollPanel then
        autoRollPanel:GetPropertyChangedSignal("Visible"):Connect(function() task.defer(resize) end)
        task.defer(resize)
    end
end)
refreshState()


