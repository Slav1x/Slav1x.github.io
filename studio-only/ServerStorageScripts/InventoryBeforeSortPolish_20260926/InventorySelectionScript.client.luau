-- Inventory behavior. The shell and CardTemplate are editable Studio instances.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Rocks = require(RS.Shared.RockCatalog)
local Traits = require(RS.Shared.TraitCatalog)
local Mastery = require(RS.Shared.MasteryConfig)
local Pets = require(RS.Shared.PetCatalog)
local Abilities = require(RS.Shared.AbilityCatalog)
local RockAppearance = require(RS.Shared.RockAppearance)
local Remotes = require(RS.Shared.Remotes)
local UISounds = require(RS.SharedUI.UISounds)
local player = Players.LocalPlayer
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local Store = require(Client:WaitForChild("ProfileStore"))
local root = script.Parent
local closeButton = root:FindFirstChild("CloseButton") or root:FindFirstChild("Close")
local main = root.Main
local grid = main.Grid
local layout = grid.Layout
local categories = main.Categories
local menu = main.RarityMenu
local details = root.Details
local template = root.CardTemplate
local navy = Color3.fromRGB(8, 26, 48)
local white = Color3.fromRGB(250, 253, 255)
local muted = Color3.fromRGB(180, 211, 236)
local rank = {Common=1, Uncommon=2, Rare=3, Epic=4, Legendary=5, Mythical=6, Exclusive=7}
local category = "ALL"
local rarityFilter = "ALL"
local selected
local pending
local favorites = table.clone(Store.get().inventoryFavorites or {})
local byKey = {}
local visibleItems = {}
local rendered = {}
local portrait = false
local columns = 5
local suppressSelectionUntil = 0

local allItems = {}
for _, group in {{Rocks.Rocks, "rock"}, {Pets.Pets, "pet"}, {Abilities.Abilities, "ability"}} do
    for _, data in group[1] do
        table.insert(allItems, {data=data, kind=group[2], key=group[2]..":"..data.id})
    end
end
local function tw(object, properties, duration, style)
    local tween = TweenService:Create(object, TweenInfo.new(duration or .14, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
    tween:Play()
    return tween
end
local function color(entry)
    return Rocks.RarityColors[entry.data.rarity] or entry.data.color or Color3.fromRGB(218, 132, 246)
end
local function owned(entry)
    if entry.kind == "ability" then return Store.ownsAbility(entry.data.id) end
    if entry.kind == "pet" then return Store.ownsPet(entry.data.id) end
    if entry.instanceId then
        local copy = (Store.get().traitedRocks or {})[entry.instanceId]
        return copy ~= nil and copy.rockId == entry.data.id and Store.ownsRock(entry.data.id)
    end
    return Store.ownsRock(entry.data.id) and Store.untraitedRockCount(entry.data.id) > 0
end
local function equipped(entry)
    local state = Store.get()
    if entry.kind == "ability" then return state.abilityEquipped == entry.data.id end
    if entry.kind == "pet" then return state.petEquipped == entry.data.id end
    return state.rockEquipped == entry.data.id and state.rockEquippedInstance == entry.instanceId
end
local function displayName(entry)
    return (entry.variant == "Enchanted" and "Enchanted " or "") .. entry.data.name
end
local function setArt(image, fallback, entry)
    local old = image:FindFirstChild("ModelPreview")
    if old then old:Destroy() end
    if entry and (entry.kind == "rock" or entry.kind == "ability") then
        local model
        if entry.kind == "rock" then
            model = RockAppearance.clone(entry.data.id, entry.variant or "Normal")
        else
            local models = RS:FindFirstChild("AbilityModels")
            local template = models and models:FindFirstChild(entry.data.modelId or entry.data.id)
            if template and template:IsA("Model") then model = template:Clone() end
        end
        if model then
            image.Image = ""
            image.Visible = true
            fallback.Visible = false
            local viewport = Instance.new("ViewportFrame")
            viewport.Name = "ModelPreview"
            viewport.Size = UDim2.fromScale(1, 1)
            viewport.BackgroundTransparency = 1
            viewport.Ambient = Color3.fromRGB(190, 201, 220)
            viewport.LightColor = Color3.fromRGB(255, 242, 220)
            viewport.LightDirection = Vector3.new(-1, -1, -1)
            viewport.ZIndex = image.ZIndex
            viewport.Parent = image
            local world = Instance.new("WorldModel")
            world.Parent = viewport
            model:PivotTo(CFrame.identity)
            for _, part in model:GetDescendants() do
                if part:IsA("BasePart") then part.Anchored=true; part.CanCollide=false end
            end
            model.Parent = world
            local bounds, size = model:GetBoundingBox()
            local radius = math.max(size.X, size.Y, size.Z)
            local camera = Instance.new("Camera")
            camera.FieldOfView = 34
            camera.CFrame = CFrame.lookAt(bounds.Position + Vector3.new(radius * 1.5, radius * .85, radius * 2.3), bounds.Position)
            camera.Parent = viewport
            viewport.CurrentCamera = camera
            return
        end
    end
    local asset = entry and entry.data.image or ""
    image.Image = asset
    image.Visible = asset ~= ""
    fallback.Text = entry and (entry.data.icon or "◆") or "◆"
    fallback.Visible = asset == ""
end
local function setFavorite(key)
    if not key then return end
    favorites[key] = not favorites[key] or nil
    if Store.hasLoaded() then Remotes.RequestFavorite:FireServer(key, favorites[key] == true) end
end
local function setButtonColor(button, base)
    button.BackgroundColor3 = base
end
local function updateDetails(animate)
    local entry = selected and byKey[selected]
    if entry and not owned(entry) then selected = nil; entry = nil end
    local detailColor = entry and color(entry) or muted
    setArt(details.PreviewBox.Art, details.PreviewBox.Icon, entry)
    details.PreviewBox.Sunrays.ImageColor3 = detailColor
    details.PreviewBox.Sunrays.ImageTransparency = entry and .87 or .94
    details.ItemName.Text = entry and displayName(entry) or "SELECT AN ITEM"
    details.RarityChip.Label.Text = entry and string.upper(entry.data.rarity) or "—"
    details.RarityChip.BackgroundColor3 = entry and detailColor:Lerp(navy, .5) or Color3.fromRGB(71, 93, 117)
    local stats = {}
    if entry then
        local data = entry.data
        if entry.kind == "rock" then
            local finalStats = Rocks.resolveStats(data.id, entry.traitId, entry.variant)
            table.insert(stats, string.format("%.2fx STRENGTH", finalStats.strengthMultiplier))
            table.insert(stats, string.upper(Rocks.characteristicLabel(data.id)))
        end
        if data.moneyBonus and data.moneyBonus ~= 0 then table.insert(stats, string.format("+%g%% MONEY", data.moneyBonus*100)) end
        if entry.kind == "pet" and data.speedBonus and data.speedBonus ~= 0 then table.insert(stats, string.format("%.2fx STRENGTH", 1 + data.speedBonus)) end
        if data.magnetBonus and data.magnetBonus ~= 0 then table.insert(stats, "+"..data.magnetBonus.." MAGNET") end
        if data.luckBonus and data.luckBonus ~= 0 then table.insert(stats, string.format("+%g%% LUCK", data.luckBonus*100)) end
        if entry.traitId then table.insert(stats, string.upper(Traits.label(entry.traitId))) end
        if entry.variant == "Enchanted" then table.insert(stats, "ENCHANTED · 1.3× SPECIALTY") end
        if entry.kind=="rock" then
            local progress=Mastery.progress(entry.instanceId and (Store.get().rockMastery or {})[entry.instanceId])
            table.insert(stats, string.format("MASTERY %d · %s",progress.level,progress.needed==0 and "MAX" or (progress.into.."/"..progress.needed.." XP")))
        end
        if entry.kind == "ability" then table.insert(stats, entry.data.id == "hermes_rock" and "2× ROCK SPEED" or "8s FLIGHT • HOLD SPACE") end
    end
    details.Stats.Text = table.concat(stats, "  •  ")
    if entry then
        local kind = entry.kind
        local trait = entry.traitId and (Traits.label(entry.traitId).." variant. ") or ""
        local ownership = entry.kind == "rock" and (entry.instanceId and "Individual rock." or "Copies owned: "..tostring(entry.displayCount or 1)..".") or "Part of your pet collection."
        details.Description.Text = entry.data.description or ("A "..entry.data.rarity:lower().." "..kind..". "..trait..ownership)
    else
        details.Description.Text = Store.hasLoaded() and "Choose a rock or pet to see its details." or "Loading your inventory..."
    end
    local canEquip = entry and Store.hasLoaded() and not pending and (entry.kind ~= "rock" or not equipped(entry))
    details.Equip.Active = canEquip and true or false
    setButtonColor(details.Equip, canEquip and Color3.fromRGB(8, 190, 82) or Color3.fromRGB(83, 140, 109))
    details.Equip.Text = not Store.hasLoaded() and "LOADING..." or (pending == selected and "EQUIPPING..." or (entry and (equipped(entry) and (entry.kind ~= "rock" and "UNEQUIP" or "EQUIPPED") or "EQUIP") or "SELECT ITEM"))
    details.Favorite.Text = (entry and favorites[entry.key] and "FAVORITED") or "FAVORITE"
    details.Favorite.Active = entry ~= nil
    details.Favorite.TextColor3 = (entry and favorites[entry.key]) and Color3.fromRGB(255, 222, 93) or white
    if animate and entry then
        local art = details.PreviewBox.Art
        art.ImageTransparency = .45
        tw(art, {ImageTransparency=0}, .18)
    end
end
local function makeEntries()
    local entries = {}
    byKey = {}
    local count = 0
    for _, base in allItems do
        if base.kind == "rock" and Store.ownsRock(base.data.id) then
            count += math.max(1, Store.rockCount(base.data.id))
            local untraited = Store.untraitedRockCount(base.data.id)
            if untraited > 0 then
                local item = {data=base.data, kind="rock", key=base.key, displayCount=untraited}
                table.insert(entries, item)
                byKey[item.key] = item
            end
        elseif (base.kind == "pet" and Store.ownsPet(base.data.id)) or (base.kind == "ability" and Store.ownsAbility(base.data.id)) then
            count += 1
            table.insert(entries, base)
            byKey[base.key] = base
        end
    end
    for instanceId, copy in Store.get().traitedRocks or {} do
        local source
        for _, candidate in allItems do
            if candidate.kind == "rock" and candidate.data.id == copy.rockId then source = candidate; break end
        end
        if source and Store.ownsRock(copy.rockId) and (Traits.get(copy.traitId) or copy.variant == "Enchanted" or copy.mastered == true) then
            local item = {data=source.data, kind="rock", key="traited:"..instanceId, instanceId=instanceId, traitId=copy.traitId, variant=copy.variant or "Normal", displayCount=1}
            table.insert(entries, item)
            byKey[item.key] = item
        end
    end
    return entries, count
end
local refresh
local function renderCard(entry, order)
    local card = template:Clone()
    card.Name = "Item_"..string.gsub(entry.key, "[^%w_]", "_")
    card.Visible = true
    card.LayoutOrder = order
    card.Parent = grid
    local rarityColor = color(entry)
    card.BackgroundColor3 = rarityColor:Lerp(navy, .78)
    card.Outline.Color = selected == entry.key and Color3.fromRGB(255, 237, 125) or rarityColor
    card.Outline.Thickness = 3
    card.SelectedStroke.Enabled = selected == entry.key
    setArt(card.Art, card.Icon, entry)
    card.ItemName.Text = displayName(entry)
    card.Rarity.Text = entry.kind == "ability" and "ABILITY" or entry.data.rarity
    card.Rarity.TextColor3 = rarityColor:Lerp(white, .25)
    card.Favorite.Text = ""
    local star = card.Favorite:FindFirstChild("StarImage")
    if star then star.ImageColor3 = favorites[entry.key] and Color3.fromRGB(255, 226, 76) or white end
    card.Equipped.Visible = equipped(entry)
    card.Quantity.Text = entry.variant == "Enchanted" and "✦ ENCHANTED" or entry.kind == "ability" and "OWNED" or entry.traitId and ("✦ "..Traits.label(entry.traitId)) or (entry.kind == "rock" and "×"..entry.displayCount or "")
    local width = layout.CellSize.X.Offset
    card.Art.Position = UDim2.fromOffset(12, portrait and 5 or 10)
    card.Art.Size = UDim2.fromOffset(width-24, portrait and 76 or 87)
    card.Icon.Position = card.Art.Position
    card.Icon.Size = card.Art.Size
    card.ItemName.Position = UDim2.fromOffset(5, portrait and 84 or 95)
    card.ItemName.Size = UDim2.fromOffset(width-10, portrait and 30 or 33)
    card.ItemName.TextSize = portrait and 16 or 18
    card.Rarity.Position = UDim2.fromOffset(5, portrait and 115 or 129)
    card.Rarity.Size = UDim2.fromOffset(width-10, portrait and 14 or 17)
    card.Rarity.TextSize = portrait and 12 or 15
    card.Favorite.Position = UDim2.fromOffset(width-33, 5)
    card.Quantity.Position = UDim2.fromOffset(6, portrait and 65 or 69)
    card.MouseEnter:Connect(function() tw(card.ButtonScale, {Scale=1.035}, .1) end)
    card.MouseLeave:Connect(function() tw(card.ButtonScale, {Scale=1}, .1) end)
    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then tw(card.ButtonScale, {Scale=.97}, .07) end
    end)
    card.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then tw(card.ButtonScale, {Scale=1}, .1) end
    end)
    card.Favorite.Activated:Connect(function()
        suppressSelectionUntil = os.clock()+.16
        setFavorite(entry.key)
        refresh()
    end)
    card.Activated:Connect(function()
        if os.clock() < suppressSelectionUntil then return end
        selected = entry.key
        UISounds.play("Tab")
        refresh()
        updateDetails(true)
    end)
    table.insert(rendered, card)
end
refresh = function()
    local oldScroll = grid.CanvasPosition
    for _, card in rendered do card:Destroy() end
    table.clear(rendered)
    local entries, count = makeEntries()
    visibleItems = {}
    local query = string.lower(main.SearchField.Input.Text)
    for _, entry in entries do
        local matchesCategory = category == "ALL" or (category == "ROCKS" and entry.kind == "rock") or (category == "PETS" and entry.kind == "pet") or (category == "SPECIAL" and (entry.kind == "ability" or entry.variant == "Enchanted" or (rank[entry.data.rarity] or 0) >= 5))
        local matchesRarity = rarityFilter == "ALL" or string.upper(entry.data.rarity) == rarityFilter
        local searchText = string.lower(displayName(entry).." "..(entry.traitId and Traits.label(entry.traitId) or ""))
        if matchesCategory and matchesRarity and string.find(searchText, query, 1, true) then table.insert(visibleItems, entry) end
    end
    table.sort(visibleItems, function(a, b)
        if favorites[a.key] ~= favorites[b.key] then return favorites[a.key] == true end
        local ra, rb = rank[a.data.rarity] or 0, rank[b.data.rarity] or 0
        if ra ~= rb then return ra > rb end
        if a.data.name == b.data.name then return a.key < b.key end
        return a.data.name < b.data.name
    end)
    if selected then
        local stillVisible = false
        for _, entry in visibleItems do
            if entry.key == selected then stillVisible = true; break end
        end
        if not stillVisible then selected = nil end
    end
    if not selected then
        for _, entry in visibleItems do if equipped(entry) then selected = entry.key; break end end
        if not selected and visibleItems[1] then selected = visibleItems[1].key end
    end
    for i, entry in visibleItems do renderCard(entry, i) end
    main.Count.Text = tostring(count).." ITEMS  •  "..tostring(#visibleItems).." SHOWN"
    main.EmptyMessage.Visible = #visibleItems == 0
    main.EmptyMessage.Text = Store.hasLoaded() and "No items found" or "Loading your inventory..."
    for _, name in {"ALL", "ROCKS", "PETS", "SPECIAL"} do
        local b = categories[name]
        local active = name == category
        b.BackgroundColor3 = active and Color3.fromRGB(0, 153, 237) or Color3.fromRGB(25, 65, 105)
        b.Outline.Color = active and Color3.fromRGB(131, 239, 255) or Color3.fromRGB(7, 28, 52)
    end
    local rarityLabel = main.RarityFilter:FindFirstChild("RARITYTEXT")
    if rarityLabel then rarityLabel.Text = rarityFilter == "ALL" and "RARITY" or rarityFilter end
    updateDetails(false)
    task.defer(function() if grid.Parent then grid.CanvasPosition = oldScroll end end)
end

local function wireButton(button)
    if not button:IsA("GuiButton") then return end
    local scale = button:FindFirstChild("ButtonScale")
    if not scale then return end
    button.MouseEnter:Connect(function() tw(scale, {Scale=1.035}, .1) end)
    button.MouseLeave:Connect(function() tw(scale, {Scale=1}, .1) end)
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then tw(scale, {Scale=.97}, .07) end
    end)
    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then tw(scale, {Scale=1}, .1) end
    end)
end
for _, b in {closeButton, main.RarityFilter, details.Equip, details.Favorite} do wireButton(b) end
for _, name in {"ALL", "ROCKS", "PETS", "SPECIAL"} do
    local b = categories[name]
    wireButton(b)
    b.Activated:Connect(function()
        category = name
        grid.CanvasPosition = Vector2.zero
        UISounds.play("Tab")
        refresh()
    end)
end
for _, item in menu:GetChildren() do
    if item:IsA("TextButton") then
        wireButton(item)
        item.Activated:Connect(function()
            rarityFilter = item.Name
            menu.Visible = false
            grid.CanvasPosition = Vector2.zero
            UISounds.play("Tab")
            refresh()
        end)
    end
end
main.RarityFilter.Activated:Connect(function() menu.Visible = not menu.Visible end)
main.SearchField.Input:GetPropertyChangedSignal("Text"):Connect(function()
    grid.CanvasPosition = Vector2.zero
    refresh()
end)
details.Favorite.Activated:Connect(function()
    if not selected then return end
    setFavorite(selected)
    refresh()
end)
details.Equip.Activated:Connect(function()
    local entry = selected and byKey[selected]
    if not entry or not owned(entry) or not Store.hasLoaded() or pending then return end
    if entry.kind == "rock" and equipped(entry) then return end
    pending = entry.key
    updateDetails(false)
    if entry.kind == "rock" then
        Remotes.RequestEquip:FireServer("rock", entry.data.id, entry.instanceId or "untraited")
    else
        Remotes.RequestEquip:FireServer(entry.kind, equipped(entry) and "" or entry.data.id)
    end
    task.delay(4, function()
        if pending == entry.key then pending = nil; updateDetails(false); details.Description.Text = "No confirmation yet. Try again." end
    end)
end)
Store.onChanged(function() pending = nil; favorites = table.clone(Store.get().inventoryFavorites or {}); refresh() end)
Remotes.ShopResult.OnClientEvent:Connect(function(_, ok, message)
    if not ok and pending then pending = nil; updateDetails(false); details.Description.Text = message end
end)

local function resize(previewViewport)
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewport = previewViewport or camera.ViewportSize
    portrait = viewport.X < 720 and viewport.Y > viewport.X
    local width = portrait and 360 or 1150
    local height = portrait and 740 or 700
    root.Size = UDim2.fromOffset(width, height)
    root.Position = UDim2.fromScale(.5, .5)
    root.ResponsiveScale.Scale = portrait
        and math.min((viewport.X-12)/width, (viewport.Y-90)/height, 1.1)
        or math.min((viewport.X-40)/width, (viewport.Y-110)/height, 1.32)
    main.Size = UDim2.fromOffset(width, height)
    main.CyanEdge.Size = UDim2.fromOffset(width-14, height-14)
    main.Body.Size = UDim2.fromOffset(width-26, height-26)
    if portrait then
        root.Title.Position = UDim2.fromOffset(10, 10)
        root.Title.Size = UDim2.fromOffset(340, 69)
        root.Title.HeaderBottomEdge.Size = UDim2.fromOffset(322, 3)
        root.Title.HeaderBottomEdge.Position = UDim2.fromOffset(9, 63)
        root.Title.InventoryIcon.Size = UDim2.fromOffset(50, 50)
        root.Title.InventoryIcon.Position = UDim2.fromOffset(12, 8)
        root.Title.Heading.Size = UDim2.fromOffset(221, 58)
        root.Title.Heading.Position = UDim2.fromOffset(65, 6)
        root.Title.Heading.TextSize = 29
        root.Title.SivaFixedGlare.Size = root.Title.Size
        closeButton.Position = UDim2.fromOffset(307, 21)
        closeButton.Size = UDim2.fromOffset(38, 38)
        if closeButton:IsA("TextButton") then closeButton.TextSize = 25 end
        categories.Position = UDim2.fromOffset(12, 91)
        categories.Size = UDim2.fromOffset(336, 43)
        for i, name in {"ALL", "ROCKS", "PETS", "SPECIAL"} do
            local button = categories[name]
            button.Position = UDim2.fromOffset((i-1)*84, 1)
            button.Size = UDim2.fromOffset(79, 40)
            button.Text = name == "PETS" and "" or name
            button.TextSize = 14
        end
        categories.PETS.PawIcon.Visible = false
        categories.PETS.Caption.Position = UDim2.fromOffset(0, 0)
        categories.PETS.Caption.Size = UDim2.fromOffset(79, 40)
        categories.PETS.Caption.TextSize = 14
        main.RarityFilter.Position = UDim2.fromOffset(12, 141)
        main.RarityFilter.Size = UDim2.fromOffset(124, 40)
        main.RarityFilter.TextSize = 14
        main.RarityFilter.Caret.Size = UDim2.new(0, 21, 1, 0)
        main.RarityFilter.Caret.TextSize = 15
        menu.Position = UDim2.fromOffset(12, 184)
        menu.Size = UDim2.fromOffset(156, 324)
        for _, item in menu:GetChildren() do
            if item:IsA("TextButton") then item.Size = UDim2.fromOffset(140, 34); item.TextSize = 13 end
        end
        main.SearchField.Position = UDim2.fromOffset(143, 141)
        main.SearchField.Size = UDim2.fromOffset(205, 40)
        main.SearchField.SearchRing.Position = UDim2.fromOffset(9, 10)
        main.SearchField.SearchRing.Size = UDim2.fromOffset(15, 15)
        main.SearchField.SearchHandle.Position = UDim2.fromOffset(21, 24)
        main.SearchField.SearchHandle.Size = UDim2.fromOffset(11, 3)
        main.SearchField.Input.Position = UDim2.fromOffset(37, 1)
        main.SearchField.Input.Size = UDim2.new(1, -43, 1, -2)
        main.SearchField.Input.TextSize = 14
        grid.Position = UDim2.fromOffset(12, 190)
        grid.Size = UDim2.fromOffset(336, 282)
        main.Count.Position = UDim2.fromOffset(15, 475)
        main.Count.TextSize = 13
        details.Position = UDim2.fromOffset(12, 506)
        details.Size = UDim2.fromOffset(336, 219)
        details.PreviewBox.Position = UDim2.fromOffset(8, 8)
        details.PreviewBox.Size = UDim2.fromOffset(139, 202)
        details.PreviewBox.Sunrays.Position = UDim2.fromOffset(-31, 8)
        details.PreviewBox.Sunrays.Size = UDim2.fromOffset(200, 200)
        details.PreviewBox.Art.Position = UDim2.fromOffset(7, 19)
        details.PreviewBox.Art.Size = UDim2.fromOffset(125, 162)
        details.PreviewBox.Icon.Position = details.PreviewBox.Art.Position
        details.PreviewBox.Icon.Size = details.PreviewBox.Art.Size
        details.ItemName.Position = UDim2.fromOffset(154, 8)
        details.ItemName.Size = UDim2.fromOffset(170, 31)
        details.ItemName.TextSize = 21
        details.RarityChip.Position = UDim2.fromOffset(170, 43)
        details.RarityChip.Size = UDim2.fromOffset(140, 24)
        details.RarityChip.Label.Size = UDim2.fromOffset(136, 24)
        details.RarityChip.Label.TextSize = 14
        details.Description.Position = UDim2.fromOffset(153, 70)
        details.Description.Size = UDim2.fromOffset(170, 55)
        details.Description.TextSize = 13
        details.Stats.Position = UDim2.fromOffset(153, 128)
        details.Stats.Size = UDim2.fromOffset(170, 30)
        details.Stats.TextSize = 11
        details.Equip.Position = UDim2.fromOffset(153, 165)
        details.Equip.Size = UDim2.fromOffset(170, 31)
        details.Equip.TextSize = 17
        details.Favorite.Position = UDim2.fromOffset(153, 199)
        details.Favorite.Size = UDim2.fromOffset(170, 17)
        details.Favorite.TextSize = 13
        columns = 3
        layout.CellSize = UDim2.fromOffset(96, 132)
        layout.CellPadding = UDim2.fromOffset(8, 8)
    else
        root.Title.Position = UDim2.fromOffset(15, 12)
        root.Title.Size = UDim2.fromOffset(1120, 93)
        if root.Title:FindFirstChild("HeaderBottomEdge") then root.Title.HeaderBottomEdge.Size = UDim2.fromOffset(1102, 3) end
        if root.Title:FindFirstChild("HeaderBottomEdge") then root.Title.HeaderBottomEdge.Position = UDim2.fromOffset(9, 87) end
        root.Title.InventoryIcon.Size = UDim2.fromOffset(82, 76)
        root.Title.InventoryIcon.Position = UDim2.fromOffset(27, 7)
        root.Title.Heading.Size = UDim2.fromOffset(520, 73)
        root.Title.Heading.Position = UDim2.fromOffset(121, 9)
        root.Title.Heading.TextSize = 54
        root.Title.SivaFixedGlare.Size = root.Title.Size
        closeButton.Position = UDim2.fromOffset(1063, 27)
        closeButton.Size = UDim2.fromOffset(66, 61)
        if closeButton:IsA("TextButton") then closeButton.TextSize = 37 end
        categories.Position = UDim2.fromOffset(21, 121)
        categories.Size = UDim2.fromOffset(748, 59)
        for i, name in {"ALL", "ROCKS", "PETS", "SPECIAL"} do
            categories[name].Position = UDim2.fromOffset((i-1)*140, 3)
            categories[name].Size = UDim2.fromOffset(131, 52)
            categories[name].TextSize = 20
        end
        categories.ALL.Text = "▦  ALL"
        categories.ROCKS.Text = "◆  ROCKS"
        categories.PETS.Text = ""
        categories.SPECIAL.Text = "★  SPECIAL"
        categories.PETS.PawIcon.Visible = true
        categories.PETS.Caption.Position = UDim2.fromOffset(51, 0)
        categories.PETS.Caption.Size = UDim2.fromOffset(74, 52)
        categories.PETS.Caption.TextSize = 20
        main.RarityFilter.Position = UDim2.fromOffset(586, 124)
        main.RarityFilter.Size = UDim2.fromOffset(177, 52)
        main.RarityFilter.TextSize = 18
        main.RarityFilter.Caret.Size = UDim2.new(0, 25, 1, 0)
        main.RarityFilter.Caret.TextSize = 20
        menu.Position = UDim2.fromOffset(586, 182)
        menu.Size = UDim2.fromOffset(177, 324)
        for _, item in menu:GetChildren() do
            if item:IsA("TextButton") then item.Size = UDim2.fromOffset(161, 34); item.TextSize = 15 end
        end
        main.SearchField.Position = UDim2.fromOffset(781, 124)
        main.SearchField.Size = UDim2.fromOffset(346, 52)
        main.SearchField.SearchRing.Position = UDim2.fromOffset(14, 13)
        main.SearchField.SearchRing.Size = UDim2.fromOffset(20, 20)
        main.SearchField.SearchHandle.Position = UDim2.fromOffset(30, 32)
        main.SearchField.SearchHandle.Size = UDim2.fromOffset(15, 4)
        main.SearchField.Input.Position = UDim2.fromOffset(48, 2)
        main.SearchField.Input.Size = UDim2.new(1, -58, 1, -4)
        main.SearchField.Input.TextSize = 19
        grid.Position = UDim2.fromOffset(18, 190)
        grid.Size = UDim2.fromOffset(716, 483)
        main.Count.Position = UDim2.fromOffset(21, 672)
        main.Count.TextSize = 15
        details.Position = UDim2.fromOffset(752, 190)
        details.Size = UDim2.fromOffset(380, 483)
        details.PreviewBox.Position = UDim2.fromOffset(11, 11)
        details.PreviewBox.Size = UDim2.fromOffset(358, 228)
        details.PreviewBox.Sunrays.Position = UDim2.fromOffset(59, -25)
        details.PreviewBox.Sunrays.Size = UDim2.fromOffset(240, 240)
        details.PreviewBox.Art.Position = UDim2.fromOffset(67, 7)
        details.PreviewBox.Art.Size = UDim2.fromOffset(224, 207)
        details.PreviewBox.Icon.Position = details.PreviewBox.Art.Position
        details.PreviewBox.Icon.Size = details.PreviewBox.Art.Size
        details.ItemName.Position = UDim2.fromOffset(15, 243)
        details.ItemName.Size = UDim2.fromOffset(350, 37)
        details.ItemName.TextSize = 27
        details.RarityChip.Position = UDim2.fromOffset(117, 282)
        details.RarityChip.Size = UDim2.fromOffset(146, 27)
        details.RarityChip.Label.Size = UDim2.fromOffset(142, 26)
        details.RarityChip.Label.TextSize = 17
        details.Description.Position = UDim2.fromOffset(18, 316)
        details.Description.Size = UDim2.fromOffset(344, 52)
        details.Description.TextSize = 17
        details.Stats.Position = UDim2.fromOffset(18, 369)
        details.Stats.Size = UDim2.fromOffset(344, 31)
        details.Stats.TextSize = 15
        details.Equip.Position = UDim2.fromOffset(17, 407)
        details.Equip.Size = UDim2.fromOffset(346, 43)
        details.Equip.TextSize = 24
        details.Favorite.Position = UDim2.fromOffset(17, 454)
        details.Favorite.Size = UDim2.fromOffset(346, 26)
        details.Favorite.TextSize = 18
        columns = 5
        layout.CellSize = UDim2.fromOffset(130, 150)
        layout.CellPadding = UDim2.fromOffset(10, 10)
    end
    layout.FillDirectionMaxCells = columns
    refresh()
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() resize() end)
root:GetAttributeChangedSignal("InventoryPreviewViewport"):Connect(function()
 local v=root:GetAttribute("InventoryPreviewViewport")
 resize(typeof(v)=="Vector2" and v or nil)
end)

local transition = 0
local closing = false
local function close()
    transition += 1
    local token = transition
    closing = true
    menu.Visible = false
    tw(root.PanelScale, {Scale=.94}, .16)
    task.delay(.17, function()
        if transition == token then root.Visible = false; root.PanelScale.Scale = 1; closing = false end
    end)
end
local function open()
    transition += 1
    closing = false
    for _, name in {"shopui", "settingsui", "upgradesui"} do
        local panel = root.Parent:FindFirstChild(name)
        if panel then panel.Visible = false end
    end
    root.Visible = true
    root.PanelScale.Scale = .94
    tw(root.PanelScale, {Scale=1}, .24, Enum.EasingStyle.Back)
    resize()
end
root.Toggle.Event:Connect(function() if root.Visible and not closing then close() else open() end end)
if closeButton then closeButton.Activated:Connect(close) end
UIS.InputBegan:Connect(function(input, processed)
    if not processed and root.Visible and input.KeyCode == Enum.KeyCode.Escape then close() end
end)
local hiddenHotbars = {}
local function syncHotbars()
    for _, gui in player.PlayerGui:GetChildren() do
        if gui.Name == "HotbarGui" and gui:IsA("ScreenGui") then
            if root.Visible then
                if hiddenHotbars[gui] == nil then hiddenHotbars[gui] = gui.Enabled end
                gui.Enabled = false
            elseif hiddenHotbars[gui] ~= nil then
                gui.Enabled = hiddenHotbars[gui]
                hiddenHotbars[gui] = nil
            end
        end
    end
end
root:GetPropertyChangedSignal("Visible"):Connect(syncHotbars)
player.PlayerGui.ChildAdded:Connect(function(gui)
    if gui.Name == "HotbarGui" then task.defer(syncHotbars) end
end)
local friendHud = root.Parent:FindFirstChild("FriendBoostHUD")
local friendWasVisible
local function syncFriendHud()
    if not friendHud then return end
    if root.Visible then
        if friendWasVisible == nil then friendWasVisible = friendHud.Visible end
        friendHud.Visible = false
    elseif friendWasVisible ~= nil then
        friendHud.Visible = friendWasVisible
        friendWasVisible = nil
    end
end
root:GetPropertyChangedSignal("Visible"):Connect(syncFriendHud)
if friendHud then
    friendHud:GetPropertyChangedSignal("Visible"):Connect(function()
        if root.Visible and friendHud.Visible then friendHud.Visible = false end
    end)
end
resize()
refresh()
syncHotbars()
syncFriendHud()


