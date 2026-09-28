--!strict
-- Behavior for the authored, single-scroll Shop in StarterGui.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local shop = script.Parent
local hud = shop.Parent
local shell = shop:WaitForChild("Shell")
local header = shell:WaitForChild("Header")
local content = shell:WaitForChild("Content")
local storefront = content:WaitForChild("Storefront")
local closeButton = header:WaitForChild("CloseButton")
local fadeOverlay = shell:WaitForChild("FadeOverlay")
local panelScale = shop:WaitForChild("PanelScale")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MonetizationConfig = require(ReplicatedStorage.Shared.MonetizationConfig)
local UISounds = require(ReplicatedStorage.SharedUI.UISounds)
local Abilities = require(ReplicatedStorage.Shared.AbilityCatalog)
local Store = require(player:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("ProfileStore"))

local originalDisplayOrder = hud.DisplayOrder
local sections = {
    storefront.StarterPackSection,
    storefront.GamepassesSection,
    storefront.SpecialPetsSection,
    storefront.SpecialRocksSection,
    storefront.CashPacksSection,
}
local starter = sections[1].StarterPack
local cards = {}
local passCards = {}
local pendingProductCard: Frame? = nil
local pendingCashJump = false
local closing = false
local cardGap = 10

-- Cameras do not replicate. Bind an explicit local camera to the authored 3D ability art.
local function bindAbilityPreviewCamera(preview: ViewportFrame)
    local world = preview:FindFirstChildWhichIsA("WorldModel")
    local model = world and world:FindFirstChildWhichIsA("Model")
    if not model or not model:FindFirstChildWhichIsA("BasePart", true) then return end
    local camera = preview:FindFirstChildWhichIsA("Camera") or Instance.new("Camera")
    camera.Name = "Camera"
    camera.FieldOfView = 32
    local cf, size = model:GetBoundingBox()
    local distance = math.max(size.X, size.Y, size.Z) * .5 / math.tan(math.rad(camera.FieldOfView * .5)) * 1.30
    camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(.5, .60, 1).Unit * distance, cf.Position)
    camera.Parent = preview
    preview.CurrentCamera = camera
end
for _, descendant in storefront:GetDescendants() do
    if descendant:IsA("ViewportFrame") and descendant.Name == "AbilityPreview" then
        bindAbilityPreviewCamera(descendant)
        local connection = descendant.DescendantAdded:Connect(function(added)
            if added:IsA("BasePart") then task.defer(bindAbilityPreviewCamera, descendant) end
        end)
        script.Destroying:Connect(function() connection:Disconnect() end)
    end
end

-- The ray artwork and its speed are authored on the ImageLabels in Studio.
-- Advance them together only while the Shop is open, so every section has
-- a gentle revolving highlight without creating UI objects at runtime.
local sunrays: {{image: ImageLabel, speed: number}} = {}
for _, descendant in storefront:GetDescendants() do
    if descendant:IsA("ImageLabel") then
        local speed = descendant:GetAttribute("ShopRaySpeed")
        if typeof(speed) == "number" and speed ~= 0 then
            table.insert(sunrays, {image = descendant, speed = speed})
        end
    end
end
local rayStep = 0
local rayMotionConnection = RunService.Heartbeat:Connect(function(dt: number)
    if not shop.Visible or player:GetAttribute("ReducedMotion") == true then return end
    rayStep += dt
    if rayStep < 1 / 30 then return end
    local advance = math.min(rayStep, 0.1)
    rayStep = 0
    for _, ray in sunrays do
        if ray.image.Parent then
            ray.image.Rotation = (ray.image.Rotation + ray.speed * advance) % 360
        end
    end
end)
script.Destroying:Connect(function()
    rayMotionConnection:Disconnect()
end)

-- These shine strips are authored in Studio and clipped to the studded headers.
local shineBands = {starter.StarterHeaderShine}
for _, section in {sections[2], sections[3], sections[4], sections[5]} do
    table.insert(shineBands, section.SectionHeader.HeaderShineBand)
end
task.spawn(function()
    while script.Parent do
        if shop.Visible and player:GetAttribute("ReducedMotion") ~= true then
            for index, band in shineBands do
                task.delay((index - 1) * .13, function()
                    local shine = band:FindFirstChild("ShineSweep")
                    if not shop.Visible or not shine then return end
                    shine.Position = UDim2.new(0, -130, 0, -14)
                    TweenService:Create(shine, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                        Position = UDim2.new(1, 130, 0, -14),
                    }):Play()
                end)
            end
        end
        task.wait(5)
    end
end)

local function tween(object: Instance, duration: number, props: {[string]: any}, style: Enum.EasingStyle?)
    local t = TweenService:Create(object, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function hookButton(button: GuiButton, hover: number, press: number)
    local scale = button:FindFirstChild("ButtonScale")
    if not scale or not scale:IsA("UIScale") then return end
    local over, down = false, false
    local function update()
        tween(scale, 0.11, {Scale = down and press or (over and hover or 1)})
    end
    button.MouseEnter:Connect(function() over = true; update(); UISounds.play("Hover") end)
    button.MouseLeave:Connect(function() over = false; down = false; update() end)
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then down = true; update() end
    end)
    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then down = false; update() end
    end)
end

local function productId(card: Frame): number
    local key = card:GetAttribute("ProductKey")
    if typeof(key) == "string" and key ~= "" then
        local pass = MonetizationConfig.pass(key)
        if pass and pass.id > 0 then return pass.id end
        for _,product in MonetizationConfig.Products do
            if product.key == key and product.id > 0 then return product.id end
        end
    end
    local id = card:GetAttribute("ProductId")
    if typeof(id) == "number" and id > 0 then return id end
    return 0
end

local function setButtonText(button: TextButton, value: string, showRobux: boolean)
    button.Text = value
    local label = button:FindFirstChild("PriceLabel", true)
    if label and label:IsA("TextLabel") then label.Text = value end
    local icon = button:FindFirstChild("RobuxIcon", true)
    if icon and icon:IsA("ImageLabel") then icon.Visible = showRobux end
end

local function refreshCard(card: Frame)
    local button = card:FindFirstChild("BuyButton")
    if not button or not button:IsA("TextButton") then return end
    local kind = card:GetAttribute("ProductType")
    if kind == "Ability" then
        local ability = Abilities.get(card:GetAttribute("AbilityId"))
        if not ability then return end
        local owned = Store.ownsAbility(ability.id)
        card:SetAttribute("Owned", owned)
        local equipped = Store.get().abilityEquipped == ability.id
        setButtonText(button, not Store.hasLoaded() and "LOADING..." or (owned and (equipped and "UNEQUIP" or "OWNED • EQUIP") or (tostring(ability.price).." COINS")), false)
        return
    end
    local id = productId(card)
    if id <= 0 then
        card:SetAttribute("Owned", false)
        setButtonText(button, "COMING SOON", false)
        return
    end
    if kind == "GamePass" then
        setButtonText(button, "CHECKING...", false)
        task.spawn(function()
            local okOwned, owned = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
            if not card.Parent then return end
            card:SetAttribute("Owned", okOwned and owned == true)
            if okOwned and owned then
                setButtonText(button, "OWNED", false)
                return
            end
            local okInfo, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, Enum.InfoType.GamePass)
            if not card.Parent then return end
            if okInfo and info and info.PriceInRobux then
                setButtonText(button, tostring(info.PriceInRobux), true)
            else
                setButtonText(button, "BUY", false)
            end
        end)
    elseif kind == "DeveloperProduct" then
        task.spawn(function()
            local okInfo, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, Enum.InfoType.Product)
            if not card.Parent then return end
            if okInfo and info and info.PriceInRobux then
                setButtonText(button, tostring(info.PriceInRobux), true)
            else
                setButtonText(button, "BUY", false)
            end
        end)
    else
        setButtonText(button, "COMING SOON", false)
    end
end

local function purchase(card: Frame)
    if card:GetAttribute("ProductType") == "Ability" then
        local ability = Abilities.get(card:GetAttribute("AbilityId"))
        if not ability or not Store.hasLoaded() then return end
        if Store.ownsAbility(ability.id) then
            Remotes.RequestEquip:FireServer("ability", Store.get().abilityEquipped == ability.id and "" or ability.id)
        else
            Remotes.RequestPurchase:FireServer("ability", ability.id)
        end
        return
    end
    local id = productId(card)
    if id <= 0 then return end
    local kind = card:GetAttribute("ProductType")
    if kind == "GamePass" then
        if card:GetAttribute("Owned") == true then return end
        MarketplaceService:PromptGamePassPurchase(player, id)
    elseif kind == "DeveloperProduct" then
        local key = card:GetAttribute("ProductKey")
        if typeof(key) == "string" and key ~= "" then
            pendingProductCard = card
            Remotes.RequestPromptProduct:FireServer(key)
        end
    end
end

table.insert(cards, starter)
for _,section in sections do
    local holder = section:FindFirstChild("Cards")
    if holder then
        for _,card in holder:GetChildren() do
            if card:IsA("Frame") and card:FindFirstChild("BuyButton") then
                table.insert(cards, card)
                if card:GetAttribute("ProductType") == "GamePass" then
                    local id = productId(card)
                    if id > 0 then passCards[id] = card end
                end
            end
        end
    end
end
for _,card in cards do
    local button = card:FindFirstChild("BuyButton") :: TextButton?
    if button then
        hookButton(button, 1.035, 0.965)
        button.Activated:Connect(function()
            UISounds.play("Click")
            purchase(card)
        end)
        refreshCard(card)
    end
end
Store.onChanged(function()
    for _, card in cards do
        if card:GetAttribute("ProductType") == "Ability" then refreshCard(card) end
    end
end)
hookButton(closeButton, 1.1, 0.92)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(finishedPlayer, id, wasPurchased)
    if finishedPlayer ~= player or not wasPurchased then return end
    local card = passCards[id]
    if card then
        card:SetAttribute("Owned", true)
        setButtonText(card.BuyButton, "OWNED", false)
    end
    UISounds.play("Success")
end)
Remotes.Toast.OnClientEvent:Connect(function(_, kind)
    if kind == "epic" and pendingProductCard then
        UISounds.play("Success")
        pendingProductCard = nil
    end
end)

local function resizeStarter(width: number)
    local compact = width < 700
    local height = compact and 510 or 290
    sections[1].Size = UDim2.new(1, -18, 0, height)
    starter.Size = UDim2.new(1, 0, 0, height)
    if compact then
        starter.StarterTitle.Position = UDim2.fromOffset(15, 9)
        starter.StarterTitle.Size = UDim2.new(1, -30, 0, 42)
        starter.StarterTitle.TextSize = 29
        starter.Subtitle.Position = UDim2.fromOffset(17, 56)
        starter.Subtitle.Size = UDim2.new(1, -34, 0, 44)
        starter.Subtitle.TextSize = 14
        starter.BestValue.Position = UDim2.new(.58, 0, 0, 342)
        starter.BestValue.Size = UDim2.new(.38, 0, 0, 25)
        for i=1,4 do
            local tile = starter["RewardTile"..i]
            tile.Position = UDim2.new(if i%2==1 then .035 else .52, 0, 0, if i<=2 then 111 else 218)
            tile.Size = UDim2.new(.445, 0, 0, 98)
            tile.RewardName.Position = UDim2.new(0, 4, 1, -28)
            tile.RewardName.Size = UDim2.new(1, -8, 0, 23)
        end
        starter.ChestSunrays.Position = UDim2.fromScale(.29, .80)
        starter.ChestSunrays.Size = UDim2.fromScale(.55, .34)
        starter.CrystalChestArt.Position = UDim2.fromScale(.29, .81)
        starter.CrystalChestArt.Size = UDim2.fromScale(.45, .30)
        starter.BuyButton.Position = UDim2.new(.75,0,1,-24)
        starter.BuyButton.Size = UDim2.new(.42,0,0,44)
    else
        starter.StarterTitle.Position = UDim2.new(0,22,0,10)
        starter.StarterTitle.Size = UDim2.new(.66,0,0,44)
        starter.StarterTitle.TextSize = 36
        starter.Subtitle.Position = UDim2.new(0,24,0,57)
        starter.Subtitle.Size = UDim2.new(.71,0,0,28)
        starter.Subtitle.TextSize = 17
        starter.BestValue.Position = UDim2.new(.80,0,0,12)
        starter.BestValue.Size = UDim2.new(.18,0,0,30)
        for i=1,4 do
            local tile = starter["RewardTile"..i]
            tile.Position = UDim2.new(.025+(i-1)*.174,0,0,99)
            tile.Size = UDim2.new(.164,0,0,161)
            tile.RewardName.Position = UDim2.new(0,4,1,-39)
            tile.RewardName.Size = UDim2.new(1,-8,0,24)
        end
        starter.ChestSunrays.Position = UDim2.fromScale(.84,.51)
        starter.ChestSunrays.Size = UDim2.fromScale(.47,1.15)
        starter.CrystalChestArt.Position = UDim2.fromScale(.84,.49)
        starter.CrystalChestArt.Size = UDim2.fromScale(.30,.66)
        starter.BuyButton.Position = UDim2.new(.83,0,1,-17)
        starter.BuyButton.Size = UDim2.new(.29,0,0,45)
    end
end

local resizing = false
local function resize()
    if resizing then return end
    resizing = true
    local camera = workspace.CurrentCamera
    if not camera then resizing = false; return end
    local v = camera.ViewportSize
    if RunService:IsStudio() then
        local previewWidth = shop:GetAttribute("PreviewViewportWidth")
        local previewHeight = shop:GetAttribute("PreviewViewportHeight")
        if typeof(previewWidth) == "number" and typeof(previewHeight) == "number" then
            v = Vector2.new(previewWidth, previewHeight)
        end
    end
    local width = if v.X < 700 then math.max(270,v.X-18) else math.min(1050,math.floor(v.X*.77))
    local height = if v.Y < 560 then math.max(280,v.Y-10) else math.min(780,math.floor(v.Y*.84))
    shop.AnchorPoint = Vector2.new(.5,.5)
    shop.Position = UDim2.fromScale(.5,.5)
    shop.Size = UDim2.fromOffset(width,height)
    local bounds = shop:FindFirstChild("ResponsiveBounds") :: UISizeConstraint?
    if bounds then bounds.MinSize = Vector2.zero; bounds.MaxSize = Vector2.new(1050,780) end
    local short = v.Y < 560
    local headerHeight = short and 52 or 64
    header.Position = UDim2.fromOffset(9,9)
    header.Size = UDim2.new(1,-18,0,headerHeight)
    header.Title.TextSize = short and 27 or 34
    header.SupportBadge.Visible = width > 680 and not short
    header.CloseButton.Size = UDim2.fromOffset(short and 38 or 44,short and 38 or 44)
    if width < 700 then
        header.BasketIcon.Position = UDim2.new(0,9,.5,0)
        header.BasketIcon.Size = UDim2.fromOffset(36,36)
        header.Title.Position = UDim2.new(0,50,.12,-2)
        header.Title.Size = UDim2.new(1,-115,.72,0)
    else
        header.BasketIcon.Position = UDim2.new(.025,0,.5,-2)
        header.BasketIcon.Size = UDim2.new(.068,0,.74,0)
        header.Title.Position = UDim2.new(.095,0,.12,-2)
        header.Title.Size = UDim2.new(.35,0,.72,0)
    end
    local headerDepth = shell:FindFirstChild("ReferenceHeaderDepth")
    if headerDepth and headerDepth:IsA("GuiObject") then
        headerDepth.Size = header.Size
        headerDepth.Position = header.Position + UDim2.fromOffset(0,7)
    end
    content.Position = UDim2.fromOffset(9,headerHeight+18)
    content.Size = UDim2.new(1,-18,1,-headerHeight-27)
    local inner = width - 72
    resizeStarter(width)
    local columns = if inner >= 760 then 3 elseif inner >= 490 then 2 else 1
    local cardHeight = if columns == 1 then 242 elseif short then 224 else 252
    for i=2,#sections do
        local section = sections[i]
        local holder = section.Cards
        local count = 0
        for _,child in holder:GetChildren() do if child:IsA("Frame") then count += 1 end end
        local rows = math.ceil(count/columns)
        local total = rows*cardHeight + math.max(0,rows-1)*cardGap
        -- Leave a few spare pixels for UIGridLayout's pixel rounding so the
        -- third card cannot wrap into an invisible second row.
        holder.CardGrid.CellSize = UDim2.new(1/columns,-math.ceil(cardGap*(columns-1)/columns)-3,0,cardHeight)
        holder.CardGrid.CellPadding = UDim2.fromOffset(cardGap,cardGap)
        holder.Size = UDim2.new(1,-26,0,total)
        section.Size = UDim2.new(1,-18,0,73+total+13)
        section.SectionHeader.Title.TextSize = if width < 400 then 23 else 29
    end
    resizing = false
end

shop:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() task.defer(resize) end)
shop:GetAttributeChangedSignal("PreviewViewportWidth"):Connect(resize)
shop:GetAttributeChangedSignal("PreviewViewportHeight"):Connect(resize)
local cameraConn: RBXScriptConnection? = nil
local function bindCamera()
    if cameraConn then cameraConn:Disconnect() end
    local camera = workspace.CurrentCamera
    if camera then cameraConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
    resize()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()

local function scrollToCash()
    task.wait()
    local section = storefront.CashPacksSection
    local y = section.AbsolutePosition.Y-storefront.AbsolutePosition.Y+storefront.CanvasPosition.Y
    storefront.CanvasPosition = Vector2.new(0,math.max(0,y-8))
end

local function openAnimation()
    closing = false
    UISounds.play("Open")
    hud.DisplayOrder = 100
    shell.Visible = true
    resize()
    if not pendingCashJump then storefront.CanvasPosition = Vector2.zero end
    local blur = Lighting:FindFirstChild("MenuWorldBlur")
    if not blur then blur = Instance.new("BlurEffect"); blur.Name = "MenuWorldBlur"; blur.Size = 0; blur.Parent = Lighting end
    tween(blur,.2,{Size=24})
    fadeOverlay.Visible = true
    fadeOverlay.BackgroundTransparency = .45
    panelScale.Scale = player:GetAttribute("ReducedMotion") and 1 or .82
    tween(panelScale,.23,{Scale=1},Enum.EasingStyle.Back)
    tween(fadeOverlay,.18,{BackgroundTransparency=1}).Completed:Once(function() fadeOverlay.Visible = false end)
    if pendingCashJump then pendingCashJump = false; task.spawn(scrollToCash) end
end
local function closeAnimation()
    if closing then return end
    closing = true
    UISounds.play("Close")
    fadeOverlay.Visible = true
    fadeOverlay.BackgroundTransparency = 1
    tween(fadeOverlay,.13,{BackgroundTransparency=.45})
    tween(panelScale,.16,{Scale=.82}).Completed:Once(function()
        shop.Visible = false
        panelScale.Scale = 1
        fadeOverlay.BackgroundTransparency = 1
        fadeOverlay.Visible = false
        closing = false
    end)
end

closeButton.Activated:Connect(closeAnimation)
local closeRequest = shop:FindFirstChild("CloseRequest")
if closeRequest and closeRequest:IsA("BindableEvent") then closeRequest.Event:Connect(closeAnimation) end
shop:GetPropertyChangedSignal("Visible"):Connect(function()
    if shop.Visible then
        openAnimation()
    else
        hud.DisplayOrder = originalDisplayOrder
        local blur = Lighting:FindFirstChild("MenuWorldBlur")
        if blur then tween(blur,.15,{Size=0}) end
    end
end)

local openCashPacks = shop:WaitForChild("OpenCashPacks") :: BindableEvent
openCashPacks.Event:Connect(function()
    if not shop.Visible then
        pendingCashJump = true
        shop.Visible = true
    else
        task.spawn(scrollToCash)
    end
end)

if shop.Visible then openAnimation() end


