local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local shop = script.Parent
local hud = shop.Parent
local originalDisplayOrder = hud.DisplayOrder
if shop.Visible then hud.DisplayOrder = 100 end
local shell = shop:WaitForChild("Shell")
local header = shell:WaitForChild("Header")
local nav = shell:WaitForChild("Navigation")
local content = shell:WaitForChild("Content")
local closeButton = header:WaitForChild("CloseButton")
local fadeOverlay = shell:WaitForChild("FadeOverlay")
local panelScale = shop:WaitForChild("PanelScale")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local UISounds = require(ReplicatedStorage:WaitForChild("SharedUI"):WaitForChild("UISounds"))

local GREEN = Color3.fromRGB(39, 226, 50)
local NAVY = Color3.fromRGB(10, 37, 61)
local BORDER = Color3.fromRGB(49, 98, 130)
local WHITE = Color3.fromRGB(245, 250, 255)
local DISABLED = Color3.fromRGB(35, 112, 67)

local pages = {}
for _, child in ipairs(content:GetChildren()) do
	if child:IsA("CanvasGroup") then
		pages[child.Name] = child
	end
end

local currentPage = "FeaturedPage"
local transitioning = false
local closing = false
local pendingProductCard
local passCards = {}

local function tween(object, duration, properties, style, direction)
	local animation = TweenService:Create(
		object,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		properties
	)
	animation:Play()
	return animation
end

local function hookButton(button, hoverScale, pressScale)
	local scale = button:FindFirstChild("ButtonScale")
	if not scale or not scale:IsA("UIScale") then return end
	local hovered = false
	local pressed = false
	local function update()
		local target = pressed and (pressScale or 0.95) or (hovered and (hoverScale or 1.05) or 1)
		tween(scale, 0.1, {Scale = target})
	end
	button.MouseEnter:Connect(function()
		hovered = true
		update()
		if button:IsA("ImageButton") then tween(button, 0.1, {ImageColor3 = Color3.fromRGB(210, 210, 210)}) end
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		pressed = false
		update()
		if button:IsA("ImageButton") then tween(button, 0.1, {ImageColor3 = Color3.new(1, 1, 1)}) end
	end)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pressed = true
			update()
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pressed = false
			update()
		end
	end)
end

local function hookCard(card)
 -- Artwork receives hover feedback; card bounds remain stable.
end

local function styleTabs(selectedPage)
	for _, tab in ipairs(nav:GetChildren()) do
		if tab:IsA("GuiButton") then
			local selected = tab:GetAttribute("Page") == selectedPage
			tween(tab, 0.16, {
				BackgroundColor3 = Color3.new(1, 1, 1),
			})
			local outline = tab:FindFirstChild("Outline")
			if outline then
				tween(outline, 0.16, {
					Color = selected and Color3.fromRGB(203, 255, 161) or Color3.fromRGB(88, 117, 158),
					Thickness = selected and 2 or 1,
					Transparency = selected and 0 or 0.08,
				})
			end
			local tabGradient = tab:FindFirstChild("TabGradient")
			if tabGradient and tabGradient:IsA("UIGradient") then
				tabGradient.Color = selected
					and ColorSequence.new(Color3.fromRGB(143, 241, 86), Color3.fromRGB(26, 160, 78))
					or ColorSequence.new(Color3.fromRGB(58, 86, 131), Color3.fromRGB(30, 47, 81))
			end
			local labelNode = tab:FindFirstChild("Label")
			if labelNode then labelNode.TextColor3 = selected and WHITE or Color3.fromRGB(212,227,245) end
 local icon=tab:FindFirstChild("AssetIcon")
 if icon then icon.ImageTransparency=selected and 0 or .12 end
		end
	end
end

local function setTab(pageName, instant)
	if transitioning or pageName == currentPage and not instant then return end
	local nextPage = pages[pageName]
	if not nextPage then return end
	local previous = pages[currentPage]
	if not instant then UISounds.play("Tab") end
	currentPage = pageName
	if pageName == "FeaturedPage" then nextPage.Scroll.CanvasPosition = Vector2.zero end
	styleTabs(pageName)
	if instant or not previous or previous == nextPage then
		for name, page in pairs(pages) do
			page.Visible = name == pageName
			page.GroupTransparency = name == pageName and 0 or 1
		end
		return
	end
	transitioning = true
	nextPage.Visible = true
	nextPage.GroupTransparency = 1
	tween(previous, 0.16, {GroupTransparency = 1})
	local incoming = tween(nextPage, 0.2, {GroupTransparency = 0})
	incoming.Completed:Once(function()
		previous.Visible = false
		transitioning = false
	end)
end

local openCashPacks = shop:WaitForChild("OpenCashPacks")
openCashPacks.Event:Connect(function()
 setTab("CashPacksPage", true)
end)

local function setButtonFill(button, topColor, bottomColor)
	local fill = button:FindFirstChild("ButtonFill")
	if not fill then return end
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	local gradient = fill:FindFirstChild("FillGradient")
	if gradient and gradient:IsA("UIGradient") then
		gradient.Color = ColorSequence.new(topColor, bottomColor)
	end
end

local function flashSuccess(card, owned)
	local button = card:FindFirstChild("BuyButton")
	local outline = card:FindFirstChild("Outline")
	if not button then return end
	local oldText = button.Text
	button.Text = "✓ PURCHASED"
	tween(button, 0.12, {BackgroundColor3 = Color3.new(1, 1, 1)})
	if outline then tween(outline, 0.12, {Color = Color3.fromRGB(173, 255, 108), Thickness = 4}) end
	task.delay(0.24, function()
		tween(button, 0.22, {BackgroundColor3 = GREEN})
	end)
	task.delay(1.1, function()
		if owned then
			button.Text = "OWNED"
			button.BackgroundColor3 = DISABLED
			setButtonFill(button, Color3.fromRGB(48, 125, 79), Color3.fromRGB(21, 77, 48))
			local robuxIcon = button:FindFirstChild("RobuxIcon", true)
			if robuxIcon then robuxIcon.Visible = false end
		else
			button.Text = oldText
		end
		if outline then
			tween(outline, 0.2, {Color = card:GetAttribute("AccentColor") or BORDER, Thickness = 2})
		end
	end)
end

local function fallbackPrice(card)
	local suggested = card:GetAttribute("SuggestedPrice")
	if typeof(suggested) ~= "string" then return "—" end
	return suggested:gsub("^R%$%s*", "")
end

local function refreshPassCard(card)
	local id = card:GetAttribute("ProductId")
	local button = card:FindFirstChild("BuyButton")
	if not button or typeof(id) ~= "number" or id <= 0 then return end
	passCards[id] = passCards[id] or {}
	table.insert(passCards[id], card)
	task.spawn(function()
		local owned = false
		local okOwned, resultOwned = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
		end)
		if okOwned then owned = resultOwned == true end
		card:SetAttribute("Owned", owned)
		local robuxIcon = button:FindFirstChild("RobuxIcon", true)
		if owned then
			button.Text = "OWNED"
			button.BackgroundColor3 = DISABLED
			if robuxIcon then robuxIcon.Visible = false end
			setButtonFill(button, Color3.fromRGB(48, 125, 79), Color3.fromRGB(21, 77, 48))
			local outline = button:FindFirstChild("Outline")
			if outline then outline.Color = Color3.fromRGB(27, 92, 58) end
			return
		end
		if robuxIcon then robuxIcon.Visible = true end
		local okInfo, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, Enum.InfoType.GamePass)
		end)
		if okInfo and info and info.PriceInRobux then
			button.Text = tostring(info.PriceInRobux)
		else
			button.Text = fallbackPrice(card)
		end
	end)
end

local function activateCard(card)
	local productType = card:GetAttribute("ProductType")
	local productId = card:GetAttribute("ProductId") or 0
	local button = card:FindFirstChild("BuyButton")
	if productType == "TabLink" then
		setTab(card:GetAttribute("TargetPage"))
		return
	end
	if productType == "Placeholder" or productId <= 0 then
		-- Visual-price placeholders are intentionally inert until a real ID is configured.
		if button then
			tween(button, 0.1, {BackgroundColor3 = Color3.fromRGB(72, 244, 91)})
			task.delay(0.18, function()
				tween(button, 0.16, {BackgroundColor3 = GREEN})
			end)
		end
		return
	end
	if productType == "GamePass" then
		if card:GetAttribute("Owned") then return end
		MarketplaceService:PromptGamePassPurchase(player, productId)
	elseif productType == "DeveloperProduct" then
		local key = card:GetAttribute("ProductKey")
		if typeof(key) == "string" and key ~= "" then
			pendingProductCard = card
			Remotes.RequestPromptProduct:FireServer(key)
		end
	end
end

for _, tab in ipairs(nav:GetChildren()) do
	if tab:IsA("GuiButton") then
		hookButton(tab, 1.02, 0.97)
		tab.Activated:Connect(function()
			setTab(tab:GetAttribute("Page"))
		end)
	end
end
hookButton(closeButton, 1.12, 0.92)

for _, effect in ipairs(content:GetDescendants()) do
	if effect:IsA("ImageLabel") and effect.Name == "Sunburst" and effect:GetAttribute("AnimateSunburst") == true then
		effect.Rotation = 0
		TweenService:Create(effect, TweenInfo.new(30, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false), {Rotation = 360}):Play()
	end
end

local function syncButtonLabel(button)
	local label = button:FindFirstChild("PriceLabel", true) or button:FindFirstChild("DisplayText", true)
	if not label or not label:IsA("TextLabel") then return end
	local function sync()
		label.Text = button.Text
		label.Font = button.Font
		label.TextSize = button.TextSize
	end
	sync()
	button:GetPropertyChangedSignal("Text"):Connect(sync)
end

for _, descendant in ipairs(content:GetDescendants()) do
	if descendant:IsA("Frame") and descendant:FindFirstChild("BuyButton") then
		hookCard(descendant)
		local button = descendant.BuyButton
		syncButtonLabel(button)
		hookButton(button, 1.035, 0.965)
		button.Activated:Connect(function()
			activateCard(descendant)
		end)
		if descendant:GetAttribute("ProductType") == "GamePass" then
			refreshPassCard(descendant)
		elseif (descendant:GetAttribute("ProductId") or 0) <= 0 and descendant:GetAttribute("ProductType") ~= "TabLink" then
			if descendant:IsDescendantOf(pages.FeaturedPage) then
				button.Text = fallbackPrice(descendant)
				button.BackgroundColor3 = GREEN
				local robuxIcon = button:FindFirstChild("RobuxIcon", true)
				if robuxIcon then robuxIcon.Visible = true end
			else
				button.Text = "COMING SOON"
				button.BackgroundColor3 = DISABLED
				local robuxIcon = button:FindFirstChild("RobuxIcon", true)
				if robuxIcon then robuxIcon.Visible = false end
			end
		end
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(finishedPlayer, id, wasPurchased)
	if finishedPlayer ~= player or not wasPurchased then return end
	UISounds.play("Success")
	for _, card in ipairs(passCards[id] or {}) do
		card:SetAttribute("Owned", true)
		flashSuccess(card, true)
	end
end)

Remotes.Toast.OnClientEvent:Connect(function(_, kind)
	if kind == "epic" and pendingProductCard then
		UISounds.play("Success")
		flashSuccess(pendingProductCard, false)
		pendingProductCard = nil
	end
end)

local function openAnimation()
	if currentPage == "FeaturedPage" then pages.FeaturedPage.Scroll.CanvasPosition = Vector2.zero end
	closing = false
	hud.DisplayOrder = 100
	shell.Visible = true
	local blur = game:GetService("Lighting"):FindFirstChild("MenuWorldBlur")
	if not blur then blur = Instance.new("BlurEffect") blur.Name = "MenuWorldBlur" blur.Size = 0 blur.Parent = game:GetService("Lighting") end
	tween(blur, 0.2, {Size = 24})
	fadeOverlay.Visible = true
	fadeOverlay.BackgroundTransparency = 0.3
	panelScale.Scale = 1.08
	local fade = tween(fadeOverlay, 0.2, {BackgroundTransparency = 1}, Enum.EasingStyle.Quint)
	tween(panelScale, 0.25, {Scale = 1}, Enum.EasingStyle.Back)
	fade.Completed:Once(function() fadeOverlay.Visible = false end)
end

local function closeAnimation()
	if closing then return end
	closing = true
	fadeOverlay.Visible = true
	fadeOverlay.BackgroundTransparency = 1
	tween(fadeOverlay, 0.15, {BackgroundTransparency = 0.3}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local closingTween = tween(panelScale, 0.15, {Scale = 1.08}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	closingTween.Completed:Once(function()
		shop.Visible = false
		panelScale.Scale = 1
		fadeOverlay.BackgroundTransparency = 1
		fadeOverlay.Visible = false
		closing = false
	end)
end

closeButton.Activated:Connect(closeAnimation)
local closeRequest=shop:FindFirstChild("CloseRequest")
if closeRequest then closeRequest.Event:Connect(closeAnimation) end
shop:GetPropertyChangedSignal("Visible"):Connect(function()
	if shop.Visible then
		openAnimation()
	else
		hud.DisplayOrder = originalDisplayOrder
		local blur = game:GetService("Lighting"):FindFirstChild("MenuWorldBlur")
		if blur then tween(blur, 0.15, {Size = 0}) end
	end
end)

local function setGrid(grid, columns, height, gap)
	gap = gap or 10
	local widthOffset = -math.ceil((gap * (columns - 1) + 20) / columns)
	grid.CellSize = UDim2.new(1 / columns, widthOffset, 0, height)
	grid.CellPadding = UDim2.new(0, gap, 0, 12)
	grid.FillDirectionMaxCells = columns
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
end

local FULL_TAB_NAMES = {
	FeaturedPage = "Featured",
	GamepassesPage = "Gamepasses",
	SpecialPetsPage = "Special Pets",
	SpecialRocksPage = "Special Rocks",
	CashPacksPage = "Cash Packs",
}
local SHORT_TAB_NAMES = {
	FeaturedPage = "Featured",
	GamepassesPage = "Passes",
	SpecialPetsPage = "Pets",
	SpecialRocksPage = "Rocks",
	CashPacksPage = "Cash",
}

local function resize()
 local camera=workspace.CurrentCamera if not camera then return end
 local v=camera.ViewportSize
 local narrow=v.X<900
 local portrait=v.X<v.Y
 local shortScreen=v.Y<500
 local pageTop=shortScreen and 38 or 72
 local pageBottom=shortScreen and 48 or 84
 shop.AnchorPoint=Vector2.new(.5,.5)
 shop.Position=UDim2.fromScale(.5,.5)
 shop.Size=UDim2.fromScale(portrait and .92 or (narrow and .88 or .78),portrait and .88 or (shortScreen and .96 or .80))
 local maxSize=shop:FindFirstChild("ResponsiveBounds")
 if not maxSize then maxSize=Instance.new("UISizeConstraint") maxSize.Name="ResponsiveBounds" maxSize.Parent=shop end
 maxSize.MinSize=Vector2.zero
 maxSize.MaxSize=Vector2.new(1420,620)
 local w=shop.AbsoluteSize.X
 local headerH=shortScreen and 38 or 64
 local navH=shortScreen and 34 or 44
 header.Position=UDim2.fromOffset(9,9) header.Size=UDim2.new(1,-18,0,headerH)
 nav.Position=UDim2.fromOffset(12,headerH+18) nav.Size=UDim2.new(1,-24,0,navH)
 content.Position=UDim2.fromOffset(9,headerH+navH+26) content.Size=UDim2.new(1,-18,1,-headerH-navH-35)
 header.SupportBadge.Visible=w>650 and v.Y>=500
 header.Title.TextSize=shortScreen and 26 or 34
 header.CloseButton.Size=UDim2.fromOffset(shortScreen and 32 or 44,shortScreen and 32 or 44)
 local headerDepth=shell:FindFirstChild("ReferenceHeaderDepth")
 if headerDepth then headerDepth.Size=header.Size;headerDepth.Position=header.Position+UDim2.fromOffset(0,7) end
 for _,tab in nav:GetChildren() do if tab:IsA("GuiButton") then
  local small=w<650
  tab.Size=UDim2.new(.2,-6,1,-3)
  tab.Label.Text=(small and SHORT_TAB_NAMES or FULL_TAB_NAMES)[tab:GetAttribute("Page")]
  tab.Label.Position=UDim2.fromScale(small and .04 or .23,0)
  tab.Label.Size=UDim2.fromScale(small and .92 or .74,1)
  tab.Icon.Visible=not small and not tab:FindFirstChild("AssetIcon")
  local im=tab:FindFirstChild("AssetIcon") if im then im.Visible=not small end
 end end
 local available=math.max(content.AbsoluteSize.X-32,220)
 local columns=available>=820 and 4 or (available>=580 and 3 or (available>=360 and 2 or 1))
 local cardHeight=columns==1 and 310 or math.clamp(content.AbsoluteSize.Y-104,294,430)
 for _,pageName in ipairs({"GamepassesPage","SpecialPetsPage","SpecialRocksPage","CashPacksPage"}) do
  local page=pages[pageName]
  if page:FindFirstChild("PageTitle") then
   page.PageTitle.Position=UDim2.fromOffset(shortScreen and 14 or 22,shortScreen and 3 or 10)
   page.PageTitle.Size=UDim2.new(1,-28,0,shortScreen and 28 or 34)
   page.PageTitle.TextSize=shortScreen and 21 or 25
  end
  if page:FindFirstChild("PageSubtitle") then page.PageSubtitle.Visible=not shortScreen end
 end
 for _,name in {"SpecialPetsPage","SpecialRocksPage","CashPacksPage"} do
  local page=pages[name] local scroll=page.GridScroll
  setGrid(scroll.Grid,columns,cardHeight,12)
  scroll.Position=UDim2.fromOffset(8,pageTop) scroll.Size=UDim2.new(1,-16,1,-pageBottom)
  scroll.CanvasSize=UDim2.fromOffset(0,0) scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
  local f=page:FindFirstChild("CollectionFooter") if f then
 f.Position=UDim2.new(.5,0,0,cardHeight+92)
 f.Visible=columns==4 and content.AbsoluteSize.Y>cardHeight+120
 end
 end
 local scroll=pages.GamepassesPage.GridScroll local stack=scroll.PassStack
 local pc=available>=780 and 3 or (available>=450 and 2 or 1)
 local names={"DoubleCash","LuckyCharm","VIP"}
 local passHeight=shortScreen and 202 or 294
 for i=1,5 do stack["PassRow"..i].Visible=false end
 for i,name in names do
  local card=stack:FindFirstChild(name,true) local row=stack["PassRow"..math.ceil(i/pc)]
  card.Parent=row card.LayoutOrder=i card.Size=UDim2.new(1/pc,-16,0,passHeight)
  card:FindFirstChild("Name").Position=UDim2.new(.05,0,shortScreen and .57 or .60,0)
  card.Description.Position=UDim2.new(.07,0,shortScreen and .67 or .70,0)
  card.Description.Size=UDim2.new(.86,0,shortScreen and .085 or .105,0)
  card.BuyButton.Size=UDim2.new(.88,0,0,shortScreen and 32 or 40)
  row.Visible=true row.Size=UDim2.new(1,0,0,passHeight)
 end
 stack.Size=UDim2.new(1,0,0,math.ceil(#names/pc)*(passHeight+12))
 scroll.Position=UDim2.fromOffset(8,pageTop) scroll.Size=UDim2.new(1,-16,1,-pageBottom) scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
 local fs=pages.FeaturedPage.Scroll local root=fs.LayoutRoot
 local top=root.TopRow local starter=top.StarterPack local preview=top.GamepassesPreview local bottom=root.BottomRow
 local width=math.max(fs.AbsoluteSize.X-20,200)
 local split=width>=740
 local fit=false
 local fitH=math.max(fs.AbsoluteSize.Y-34,410)
 local heroH=fit and math.floor(fitH*.57) or (split and math.clamp(width*.24,290,350) or math.clamp(width*.72,310,390))
 local previewH=heroH
 top.Size=UDim2.new(1,0,0,split and heroH or heroH+previewH+14)
 starter.Position=UDim2.fromOffset(0,0) starter.Size=split and UDim2.new(.55,-7,1,0) or UDim2.new(1,0,0,heroH)
 preview.Position=split and UDim2.new(.55,7,0,0) or UDim2.fromOffset(0,heroH+14)
 preview.Size=split and UDim2.new(.45,-7,1,0) or UDim2.new(1,0,0,previewH)
 preview.Title.Position=UDim2.fromOffset(14,10) preview.Title.Size=UDim2.new(1,-28,0,27)
 preview.Subtitle.Position=UDim2.fromOffset(14,35) preview.Subtitle.Size=UDim2.new(1,-28,0,16)
 preview.Subtitle.TextSize=12
 preview.Subtitle.TextScaled=false
 local inset=60
 local rowH=math.floor((heroH-inset-60)/3)-5
 preview.Cards.Position=UDim2.fromOffset(10,inset) preview.Cards.Size=UDim2.new(1,-20,0,rowH*3+14)
 preview.Cards.ResponsiveGrid.CellSize=UDim2.new(1,0,0,rowH)
 preview.Cards.ResponsiveGrid.CellPadding=UDim2.fromOffset(0,7) preview.Cards.ResponsiveGrid.FillDirectionMaxCells=1
 preview.BuyButton.AnchorPoint=Vector2.new(.5,1) preview.BuyButton.Position=UDim2.new(.5,0,1,-10) preview.BuyButton.Size=UDim2.new(1,-20,0,32)
 local bc=width>=780 and 3 or (width>=510 and 2 or 1)
 local bh=math.clamp(width*.235,240,300) local rows=math.ceil(3/bc)
 bottom.ResponsiveGrid.CellSize=UDim2.new(1/bc,-math.ceil(12*(bc-1)/bc),0,bh)
 bottom.ResponsiveGrid.CellPadding=UDim2.fromOffset(12,12) bottom.ResponsiveGrid.FillDirectionMaxCells=bc
 local topH=split and heroH or heroH+previewH+14
 bottom.Position=UDim2.fromOffset(0,topH+14) bottom.Size=UDim2.new(1,0,0,rows*(bh+12))
 local height=topH+14+rows*bh+(rows-1)*12
 root.Size=UDim2.new(1,-20,0,height) fs.CanvasSize=UDim2.fromOffset(0,height+20)
end

shop:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() task.defer(resize) end)
content:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() task.defer(resize) end)
local cameraConnection
local function bindCamera()
	if cameraConnection then cameraConnection:Disconnect() end
	if workspace.CurrentCamera then
		cameraConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
	end
	resize()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()
setTab("FeaturedPage", true)

-- Only existing artwork and decorative layers animate; no instances are allocated per cycle.
local idleStates = {}
for _,im in ipairs(content:GetDescendants()) do
 if im:IsA("ImageLabel") and im:GetAttribute("PremiumIdle") then
  local theme=im:GetAttribute("Theme")
  local card=im.Parent
  while card and card~=content and not card:FindFirstChild("BuyButton") do card=card.Parent end
  if card and card~=content then
   local holder=im.Parent
   local holderHome=holder.Position
   local base=holder:FindFirstChild("ArtHoverScale")
   if not base then base=Instance.new("UIScale") base.Name="ArtHoverScale" base.Parent=im end
   local page=card
   while page.Parent~=content do page=page.Parent end
   local glow=card:FindFirstChild("DesignedSurface") and card.DesignedSurface:FindFirstChild("AmbientGlow")
   local duration=({JetpackRock=2.1,HermesRock=3.6,CelestialShard=4.2,MagmaSkimmer=3.2})[theme] or 3.3
   local bob=({JetpackRock=3,HermesRock=5,CelestialShard=5,MagmaSkimmer=4})[theme] or 5
   local home=im.Position
   local props={Position=home+UDim2.fromOffset(theme=="JetpackRock" and 2 or 0,-bob)}
   if theme=="CelestialShard" then props.Rotation=im.Rotation+1.5 end
   local motion=TweenService:Create(im,TweenInfo.new(duration,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),props)
   local breathe=glow and TweenService:Create(glow,TweenInfo.new(duration+.7,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{ImageTransparency=.79})
   local outline=card:FindFirstChild("Outline")
   local function updateVisible()
    if shop.Visible and page.Visible then motion:Play() if breathe then breathe:Play() end
    else motion:Pause() if breathe then breathe:Pause() end end
   end
   shop:GetPropertyChangedSignal("Visible"):Connect(updateVisible)
   page:GetPropertyChangedSignal("Visible"):Connect(updateVisible)
   card.MouseEnter:Connect(function()
    tween(base,.2,{Scale=1.05})
    tween(holder,.2,{Position=holderHome+UDim2.fromOffset(0,-2)})
    if outline then tween(outline,.2,{Thickness=2.3}) end
    if glow then if breathe then breathe:Pause() end tween(glow,.2,{ImageTransparency=.73}) end
   end)
   card.MouseLeave:Connect(function()
    tween(base,.25,{Scale=1})
    tween(holder,.25,{Position=holderHome})
    if outline then tween(outline,.25,{Thickness=1.7}) end
    if glow then tween(glow,.25,{ImageTransparency=.88}) end
    task.delay(.26,updateVisible)
   end)
   updateVisible()
  end
 end
end

