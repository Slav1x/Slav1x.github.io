-- Animated, native-GUI egg preview and server-authoritative hatching client.
local root = script.Parent
local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local Tween = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local config = require(root:WaitForChild("EggPreviewConfig"))
local displays = root:WaitForChild("EggDisplays")
local modelLibrary = ReplicatedStorage:WaitForChild("BGCPetPreviewModels")
local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))
local PetViewport = require(ReplicatedStorage.SharedUI:WaitForChild("PetViewport"))
local sunburst = ReplicatedStorage:WaitForChild("GeneratedUIAssets"):WaitForChild("Sunburst").Value

local gui = Instance.new("ScreenGui")
gui.Name = "EggPreview_V3"
gui.ResetOnSpawn = false
gui.DisplayOrder = 155
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function add(class, parent, name, props)
    local instance = Instance.new(class)
    instance.Name = name
    for key, value in pairs(props or {}) do instance[key] = value end
    instance.Parent = parent
    return instance
end
local function round(parent, radius)
    return add("UICorner", parent, "Corner", {CornerRadius = UDim.new(0, radius)})
end
local function stroke(parent, color, thickness, transparency)
    return add("UIStroke", parent, "Outline", {Color = color, Thickness = thickness, Transparency = transparency or 0})
end
local function label(parent, name, value, size, color)
    return add("TextLabel", parent, name, {
        BackgroundTransparency = 1, Text = value, Font = Enum.Font.FredokaOne,
        TextColor3 = color or Color3.new(1, 1, 1), TextSize = size,
        TextStrokeColor3 = Color3.fromRGB(13, 18, 27), TextStrokeTransparency = .12,
        TextScaled = true, TextWrapped = true,
    })
end
local function gradient(parent, colors)
    local sequence = {}
    for i, color in ipairs(colors) do
        table.insert(sequence, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
    end
    return add("UIGradient", parent, "Gradient", {Color = ColorSequence.new(sequence), Rotation = 90})
end
local function scaleHover(button)
    local s = add("UIScale", button, "HoverScale", {Scale = 1})
    local inside, pressed = false, false
    local function update()
        Tween:Create(s, TweenInfo.new(.13, Enum.EasingStyle.Quad),
            {Scale = pressed and .95 or (inside and 1.035 or 1)}):Play()
    end
    button.MouseEnter:Connect(function() inside = true update() end)
    button.MouseLeave:Connect(function() inside = false pressed = false update() end)
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then pressed = true update() end
    end)
    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then pressed = false update() end
    end)
end

local rootFrame = add("CanvasGroup", gui, "PreviewPanel", {
    AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.45, .5),
    Size = UDim2.fromOffset(1000, 620), BackgroundTransparency = 1,
    GroupTransparency = 1, Visible = false,
})
local uiScale = add("UIScale", rootFrame, "ResponsiveScale", {Scale = 1})

local nav = add("Frame", rootFrame, "CollectionSwitcher", {
    Position = UDim2.fromOffset(0, 72), Size = UDim2.fromOffset(235, 475),
    BackgroundColor3 = Color3.fromRGB(10, 18, 23), BackgroundTransparency = .23,
    ClipsDescendants = true,
})
round(nav, 24)
stroke(nav, Color3.fromRGB(91, 112, 106), 4, .15)
local navTitle = label(rootFrame, "ZonesTitle", "ZONES", 31)
navTitle.Position = UDim2.fromOffset(10, 24)
navTitle.Size = UDim2.fromOffset(220, 42)
local zoneScroll = add("ScrollingFrame", nav, "Zones", {
    Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 1, -20),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5,
    ScrollBarImageColor3 = Color3.fromRGB(185, 227, 216), CanvasSize = UDim2.fromOffset(0, 0),
})
local zoneLayout = add("UIListLayout", zoneScroll, "ZoneLayout", {
    Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder,
})
zoneLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    zoneScroll.CanvasSize = UDim2.fromOffset(0, zoneLayout.AbsoluteContentSize.Y + 6)
end)

local themes = {
    driftwood = {"Lake Pets", Color3.fromRGB(0, 211, 142), Color3.fromRGB(28, 250, 223)},
    blossom = {"Blossom Pets", Color3.fromRGB(241, 85, 169), Color3.fromRGB(255, 186, 226)},
    candy = {"Candy Pets", Color3.fromRGB(234, 89, 183), Color3.fromRGB(255, 210, 107)},
    sunscorch = {"Desert Pets", Color3.fromRGB(237, 141, 32), Color3.fromRGB(255, 220, 99)},
    frozen = {"Snow Pets", Color3.fromRGB(26, 155, 243), Color3.fromRGB(174, 246, 255)},
    crystal = {"Crystal Pets", Color3.fromRGB(142, 91, 229), Color3.fromRGB(224, 198, 255)},
    toxic = {"Toxic Pets", Color3.fromRGB(97, 173, 22), Color3.fromRGB(190, 255, 95)},
    inferno = {"Lava Pets", Color3.fromRGB(229, 55, 31), Color3.fromRGB(255, 163, 55)},
    cosmic = {"Void Pets", Color3.fromRGB(66, 34, 160), Color3.fromRGB(174, 69, 240)},
}
local zoneButtons = {}
for i, zone in ipairs(config.Zones) do
    local theme = themes[zone.id] or {zone.name, zone.color, Color3.new(1, 1, 1)}
    local button = add("TextButton", zoneScroll, zone.id, {
        Size = UDim2.new(1, -8, 0, 70), LayoutOrder = i, Text = "",
        AutoButtonColor = false, BackgroundColor3 = theme[2],
        ClipsDescendants = true,
    })
    round(button, 18)
    gradient(button, {theme[2], theme[3]})
    local edge = stroke(button, Color3.fromRGB(24, 34, 40), 4)
    local name = label(button, "ZoneName", theme[1], 25)
    name.Position = UDim2.fromScale(.04, .15)
    name.Size = UDim2.fromScale(.92, .7)
    gradient(name, {Color3.new(1, 1, 1), Color3.fromRGB(239, 250, 252)})
    scaleHover(button)
    zoneButtons[i] = {button = button, edge = edge}
end

local panel = add("Frame", rootFrame, "EggSurface", {
    Position = UDim2.fromOffset(260, 70), Size = UDim2.fromOffset(730, 445),
    BackgroundColor3 = Color3.fromRGB(12, 21, 27), BackgroundTransparency = .31,
    ClipsDescendants = true,
})
round(panel, 25)
stroke(panel, Color3.fromRGB(67, 87, 90), 4, .18)
local titleRays = add("ImageLabel", rootFrame, "TitleSunburst", {
    Image = sunburst, AnchorPoint = Vector2.new(.5, .5),
    Position = UDim2.fromOffset(625, 45), Size = UDim2.fromOffset(350, 135),
    BackgroundTransparency = 1, ImageTransparency = .62, ImageColor3 = Color3.fromRGB(255, 215, 91),
    ZIndex = 2,
})
local collectionTitle = label(rootFrame, "CollectionTitle", "", 49, Color3.fromRGB(255, 230, 96))
collectionTitle.AnchorPoint = Vector2.new(.5, 0)
collectionTitle.Position = UDim2.fromOffset(625, 3)
collectionTitle.Size = UDim2.fromOffset(655, 55)
collectionTitle.ZIndex = 3
collectionTitle.Visible = false
local eggTitle = label(rootFrame, "EggTitle", "Common Egg", 47)
eggTitle.AnchorPoint = Vector2.new(.5, 0)
eggTitle.Position = UDim2.fromOffset(625, 10)
eggTitle.Size = UDim2.fromOffset(600, 55)
eggTitle.ZIndex = 3

local cards = {}
for i = 1, 4 do
    local x = 19 + ((i - 1) % 3) * 235
    local y = 20 + math.floor((i - 1) / 3) * 207
    local card = add("Frame", panel, "PetCard" .. i, {
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(215, 190),
        BackgroundColor3 = Color3.fromRGB(80, 157, 129), BackgroundTransparency = .40,
        ClipsDescendants = true,
    })
    round(card, 20)
    local edge = stroke(card, Color3.fromRGB(204, 255, 228), 2, .36)
    local rays = add("ImageLabel", card, "Sunrays", {
        Image = sunburst, AnchorPoint = Vector2.new(.5, .5),
        Position = UDim2.fromScale(.5, .42), Size = UDim2.fromScale(1.25, 1.4),
        BackgroundTransparency = 1, ImageTransparency = .52, ZIndex = 2,
    })
    local viewport = add("ViewportFrame", card, "PetPreview", {
        Position = UDim2.fromScale(.06, .03), Size = UDim2.fromScale(.88, .70),
        BackgroundTransparency = 1, Ambient = Color3.fromRGB(205, 211, 222),
        LightColor = Color3.fromRGB(255, 244, 224), LightDirection = Vector3.new(-.5, -1, -.7),
        ZIndex = 3,
    })
    local world = add("WorldModel", viewport, "World", {})
    local camera = add("Camera", viewport, "PreviewCamera", {FieldOfView = 36})
    viewport.CurrentCamera = camera
    local odds = label(card, "Odds", "40%", 39)
    odds.Position = UDim2.fromScale(.06, .69)
    odds.Size = UDim2.fromScale(.88, .20)
    odds.ZIndex = 4
    local rarity = label(card, "Rarity", "COMMON", 23)
    rarity.Position = UDim2.fromScale(.08, .87)
    rarity.Size = UDim2.fromScale(.84, .13)
    rarity.ZIndex = 4
    cards[i] = {frame = card, edge = edge, rays = rays, viewport = viewport,
        world = world, camera = camera, odds = odds, rarity = rarity, modelName = nil}
end

local buttons = {}
local buttonData = {
    {"E", "Hatch", Color3.fromRGB(18, 215, 54), Color3.fromRGB(70, 255, 95)},
    {"R", "Multi", Color3.fromRGB(237, 162, 20), Color3.fromRGB(255, 225, 48)},
    {"T", "Auto", Color3.fromRGB(148, 29, 217), Color3.fromRGB(228, 55, 249)},
}
for i, data in ipairs(buttonData) do
    local button = add("TextButton", rootFrame, data[2] .. "Button", {
        Position = UDim2.fromOffset(273 + (i - 1) * 240, 523),
        Size = UDim2.fromOffset(220, 80), BackgroundColor3 = data[3],
        Text = "", AutoButtonColor = false,
    })
    round(button, 21)
    stroke(button, Color3.fromRGB(17, 29, 24), 7, .20)
    gradient(button, {data[4], data[3]})
    local key = label(button, "Key", data[1], 43)
    key.Position = UDim2.fromScale(.08, .04)
    key.Size = UDim2.fromScale(.84, .51)
    local action = label(button, "Action", data[2], 31)
    action.Position = UDim2.fromScale(.08, .50)
    action.Size = UDim2.fromScale(.84, .45)
    scaleHover(button)
    buttons[i] = button
end
local cost = label(rootFrame, "Cost", "COIN PRICE TBD", 25, Color3.fromRGB(255, 225, 85))
cost.Position = UDim2.fromOffset(524, 601)
cost.Size = UDim2.fromOffset(415, 28)
cost.TextXAlignment = Enum.TextXAlignment.Left
local coin = add("Frame", rootFrame, "CurrencyCoin", {
    Position = UDim2.fromOffset(483, 600), Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = Color3.fromRGB(255, 199, 47), BorderSizePixel = 0,
})
round(coin, 15)
stroke(coin, Color3.fromRGB(125, 68, 9), 3)
gradient(coin, {Color3.fromRGB(255, 239, 105), Color3.fromRGB(238, 142, 23)})
local coinMark = label(coin, "Mark", "$", 22)
coinMark.Size = UDim2.fromScale(1, 1)
local notice = label(rootFrame, "PreviewNotice", "PREVIEW ONLY • HATCHING NOT ACTIVE", 17, Color3.fromRGB(220, 239, 238))
notice.Position = UDim2.fromOffset(270, 631)
notice.Size = UDim2.fromOffset(700, 22)

local selectedIndex = {Egg1 = 1, Egg2 = 1}
local current
local alphaTween
local sizeTween
local cached = {}
local elapsed, check = 0, 0

local function setModel(card, name)
    if card.modelName == name then return end
    card.modelName = name
    card.world:ClearAllChildren()
    local source = modelLibrary:FindFirstChild(name)
    if not source then warn("[EggPreview] Missing BGC pet model: " .. tostring(name)) return end
    local model = source:Clone()
    model.Parent = card.world
    model:PivotTo(CFrame.new())
    local cf, size = model:GetBoundingBox()
    local radius = math.max(size.X, size.Y, size.Z)
    local distance = radius * .5 / math.tan(math.rad(card.camera.FieldOfView * .5)) * 1.24
    local center = cf.Position + Vector3.new(0, size.Y * .03, 0)
    card.camera.CFrame = CFrame.lookAt(center + Vector3.new(size.X * .06, size.Y * .12, -distance), center)
end
local function responsive()
    local camera = workspace.CurrentCamera
    local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local mobile = view.X < 700
    if mobile then
        rootFrame.Size = UDim2.fromOffset(500, 680)
        rootFrame.Position = UDim2.fromScale(.5, .5)
        nav.Position = UDim2.fromOffset(0, 75)
        nav.Size = UDim2.fromOffset(112, 500)
        navTitle.Position = UDim2.fromOffset(0, 30)
        navTitle.Size = UDim2.fromOffset(112, 35)
        for _, item in ipairs(zoneButtons) do
            item.button.Size = UDim2.new(1, -7, 0, 61)
            item.button.ZoneName.TextSize = 18
        end
        panel.Position = UDim2.fromOffset(120, 80)
        panel.Size = UDim2.fromOffset(375, 440)
        collectionTitle.Position = UDim2.fromOffset(305, 3)
        collectionTitle.Size = UDim2.fromOffset(380, 45)
        eggTitle.Position = UDim2.fromOffset(305, 47)
        eggTitle.Size = UDim2.fromOffset(375, 35)
        titleRays.Position = UDim2.fromOffset(305, 45)
        titleRays.Size = UDim2.fromOffset(240, 110)
        for i, card in ipairs(cards) do
            card.frame.Position = UDim2.fromOffset(12 + ((i - 1) % 2) * 182, 13 + math.floor((i - 1) / 2) * 210)
            card.frame.Size = UDim2.fromOffset(170, 195)
        end
        for i, button in ipairs(buttons) do
            button.Position = UDim2.fromOffset(121 + (i - 1) * 126, 531)
            button.Size = UDim2.fromOffset(115, 77)
            button.Key.TextSize = 36
            button.Action.TextSize = 25
        end
        coin.Position = UDim2.fromOffset(191, 612)
        cost.Position = UDim2.fromOffset(225, 613)
        cost.Size = UDim2.fromOffset(270, 26)
        notice.Position = UDim2.fromOffset(120, 642)
        notice.Size = UDim2.fromOffset(375, 21)
        return math.min(1, view.X * .96 / 500, view.Y * .90 / 680)
    end
    rootFrame.Size = UDim2.fromOffset(1000, 660)
    rootFrame.Position = UDim2.fromScale(.45, .5)
    nav.Position = UDim2.fromOffset(0, 72)
    nav.Size = UDim2.fromOffset(235, 475)
    navTitle.Position = UDim2.fromOffset(10, 24)
    navTitle.Size = UDim2.fromOffset(220, 42)
    for _, item in ipairs(zoneButtons) do
        item.button.Size = UDim2.new(1, -8, 0, 70)
        item.button.ZoneName.TextSize = 25
    end
    panel.Position = UDim2.fromOffset(260, 70)
    panel.Size = UDim2.fromOffset(730, 445)
    collectionTitle.Position = UDim2.fromOffset(625, 3)
    collectionTitle.Size = UDim2.fromOffset(655, 55)
    eggTitle.Position = UDim2.fromOffset(625, 52)
    eggTitle.Size = UDim2.fromOffset(600, 36)
    titleRays.Position = UDim2.fromOffset(625, 45)
    titleRays.Size = UDim2.fromOffset(350, 135)
    for i, card in ipairs(cards) do
        card.frame.Position = UDim2.fromOffset(19 + ((i - 1) % 3) * 235, 20 + math.floor((i - 1) / 3) * 207)
        card.frame.Size = UDim2.fromOffset(215, 190)
    end
    for i, button in ipairs(buttons) do
        button.Position = UDim2.fromOffset(273 + (i - 1) * 240, 523)
        button.Size = UDim2.fromOffset(220, 80)
        button.Key.TextSize = 43
        button.Action.TextSize = 31
    end
    coin.Position = UDim2.fromOffset(483, 603)
    cost.Position = UDim2.fromOffset(524, 604)
    cost.Size = UDim2.fromOffset(415, 28)
    notice.Position = UDim2.fromOffset(270, 634)
    notice.Size = UDim2.fromOffset(700, 22)
    return math.min(1.08, view.X * .82 / 1000, view.Y * .80 / 660)
end

local function render(id)
    local index = selectedIndex[id] or 1
    local zone = config.Zones[index]
    local data = config.get(id, zone and zone.id)
    local theme = themes[zone.id] or {zone.name, zone.color, Color3.new(1, 1, 1)}
    collectionTitle.Text = ""
    eggTitle.Text = string.gsub(data.Name, " EGG", " Egg")
    eggTitle.TextColor3 = data.Accent
    titleRays.ImageColor3 = data.Accent
    nav.Visible = id ~= "Egg3"
    navTitle.Visible = id ~= "Egg3"
    for i, item in ipairs(zoneButtons) do
        item.edge.Color = i == index and Color3.fromRGB(250, 255, 255) or Color3.fromRGB(24, 34, 40)
        item.edge.Thickness = i == index and 5 or 4
    end
    for i, card in ipairs(cards) do
        local pet = data.Previews[i]
        card.frame.BackgroundColor3 = pet.Color
        card.edge.Color = pet.Color:Lerp(Color3.new(1, 1, 1), .55)
        card.rays.ImageColor3 = pet.Color:Lerp(Color3.new(1, 1, 1), .45)
        card.odds.Text = pet.PercentageText
        card.rarity.Text = pet.Rarity
        card.rarity.TextColor3 = pet.Color:Lerp(Color3.new(1, 1, 1), .65)
        setModel(card, pet.Model or pet.Name)
    end
    cost.Text = data.CostText
    notice.Text = data.Notice or "PREVIEW ONLY"
    gui:SetAttribute("SelectedCollection", id == "Egg3" and "exclusive" or zone.id)
end
for i, item in ipairs(zoneButtons) do
    item.button.Activated:Connect(function()
        if current == "Egg1" or current == "Egg2" then
            selectedIndex[current] = i
            render(current)
        end
    end)
end

local function addDisplay(model)
    local visual = model:FindFirstChild("Visual")
    local anchor = model:FindFirstChild("InteractionPoint")
    if not visual or not anchor then return end
    local entry = {visual = visual, anchor = anchor,
        rest = visual:GetAttribute("RestPivot") or visual:GetPivot(),
        phase = visual:GetAttribute("Phase") or 0, fx = {}}
    for _, effect in model:GetDescendants() do
        if effect:IsA("ParticleEmitter") or effect:IsA("PointLight") then
            table.insert(entry.fx, effect)
        end
    end
    cached[model] = entry
end
for _, model in displays:GetChildren() do addDisplay(model) end
local added = displays.ChildAdded:Connect(function(model) task.defer(addDisplay, model) end)
local removed = displays.ChildRemoved:Connect(function(model) cached[model] = nil end)
local function show(id)
    if current == id then return end
    current = id
    gui:SetAttribute("ActiveEgg", id or "")
    if alphaTween then alphaTween:Cancel() end
    if sizeTween then sizeTween:Cancel() end
    if id then
        render(id)
        rootFrame.Visible = true
        uiScale.Scale = responsive() * .95
        alphaTween = Tween:Create(rootFrame, TweenInfo.new(.2), {GroupTransparency = 0})
        sizeTween = Tween:Create(uiScale, TweenInfo.new(.2, Enum.EasingStyle.Quad), {Scale = responsive()})
        sizeTween:Play()
    else
        alphaTween = Tween:Create(rootFrame, TweenInfo.new(.18), {GroupTransparency = 1})
        task.delay(.2, function() if not current then rootFrame.Visible = false end end)
    end
    alphaTween:Play()
end

local connection = Run.Heartbeat:Connect(function(dt)
    if not displays:IsDescendantOf(workspace) then show(nil) return end
    elapsed += dt
    check += dt
    local camera = workspace.CurrentCamera
    for model, entry in pairs(cached) do
        if model.Parent and camera then
            local nearby = (camera.CFrame.Position - entry.anchor.Position).Magnitude < 100
            if nearby then
                local dy = player:GetAttribute("ReducedMotion") and 0 or math.sin(elapsed * math.pi * 2 / 2.6 + entry.phase) * .2
                entry.visual:PivotTo(entry.rest + Vector3.new(0, dy, 0))
            end
        end
    end
    if rootFrame.Visible and not player:GetAttribute("ReducedMotion") then
        titleRays.Rotation = (titleRays.Rotation + dt * 5) % 360
        for _, card in ipairs(cards) do card.rays.Rotation = (card.rays.Rotation + dt * 11) % 360 end
    end
    if check < .1 then return end
    check = 0
    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    local best, distance = nil, 11
    local currentDistance = math.huge
    for model, entry in pairs(cached) do
        local d = hrp and (entry.anchor.Position - hrp.Position).Magnitude or math.huge
        if model.Name == current then currentDistance = d end
        if d < distance then best = model.Name distance = d end
        for _, effect in ipairs(entry.fx) do effect.Enabled = d < 65 end
    end
    local hud = player.PlayerGui:FindFirstChild("MainHUD")
    local modal = false
    if hud then
        for _, name in {"shopui", "upgradesui", "inventoryui", "indexui"} do
            local frame = hud:FindFirstChild(name)
            if frame and frame:IsA("GuiObject") and frame.Visible then modal = true end
        end
    end
    if modal or not hum or hum.Health <= 0 then
        best = nil
    elseif current and currentDistance < 13 then
        if not best or best == current or distance > currentDistance - 1.5 then best = current end
    end
    show(best)
    if rootFrame.Visible and (not sizeTween or sizeTween.PlaybackState ~= Enum.PlaybackState.Playing) then
        uiScale.Scale = responsive()
    end
end)
script.Destroying:Connect(function()
    connection:Disconnect()
    added:Disconnect()
    removed:Disconnect()
    gui:Destroy()
end)

-- Result reveal stays on screen long enough to celebrate a hatch, even if the
-- player drifts away from the pedestal. All awards arrive from the server.
local reveal = add("Frame", gui, "HatchReveal", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(5, 9, 19),
    BackgroundTransparency = .28, Visible = false, Active = true, ZIndex = 20,
})
local revealPanel = add("Frame", reveal, "RevealPanel", {
    AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
    Size = UDim2.fromOffset(860, 430), BackgroundColor3 = Color3.fromRGB(12, 23, 34),
    BackgroundTransparency = .14, ZIndex = 21,
})
round(revealPanel, 28)
stroke(revealPanel, Color3.fromRGB(114, 244, 225), 4, .12)
local revealScale = add("UIScale", revealPanel, "ResponsiveScale", {Scale = 1})
local revealRays = add("ImageLabel", revealPanel, "Sunburst", {
    AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .49),
    Size = UDim2.fromOffset(790, 790), Image = sunburst, ImageTransparency = .79,
    ImageColor3 = Color3.fromRGB(255, 223, 111), BackgroundTransparency = 1, ZIndex = 21,
})
local revealTitle = label(revealPanel, "RevealTitle", "HATCHING...", 43,
    Color3.fromRGB(255, 233, 119))
revealTitle.Position = UDim2.fromOffset(120, 13)
revealTitle.Size = UDim2.fromOffset(620, 53)
revealTitle.ZIndex = 23
local revealHint = label(revealPanel, "RevealHint", "NEW PETS ADDED TO INVENTORY", 18,
    Color3.fromRGB(210, 248, 246))
revealHint.Position = UDim2.fromOffset(160, 393)
revealHint.Size = UDim2.fromOffset(540, 23)
revealHint.ZIndex = 23
local slots = {}
for i = 1, 3 do
    local slot = add("Frame", revealPanel, "RevealSlot"..i, {
        Position = UDim2.fromOffset(38 + (i - 1) * 270, 72),
        Size = UDim2.fromOffset(245, 310), BackgroundColor3 = Color3.fromRGB(28, 45, 65),
        BackgroundTransparency = .22, Visible = false, ZIndex = 22,
    })
    round(slot, 22)
    local edge = stroke(slot, Color3.fromRGB(111, 233, 214), 3, .18)
    local rays = add("ImageLabel", slot, "Rays", {
        AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .42),
        Size = UDim2.fromOffset(270, 270), BackgroundTransparency = 1,
        Image = sunburst, ImageTransparency = .68, ZIndex = 23,
    })
    local egg = add("Frame", slot, "EggShell", {
        AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .45),
        Size = UDim2.fromOffset(119, 157), BackgroundColor3 = Color3.fromRGB(98, 245, 132),
        Rotation = 0, ZIndex = 25,
    })
    round(egg, 76)
    stroke(egg, Color3.fromRGB(243, 255, 223), 4, .1)
    gradient(egg, {Color3.fromRGB(211, 255, 164), Color3.fromRGB(25, 203, 95)})
    local shine = add("Frame", egg, "Glare", {
        Position = UDim2.fromScale(.23, .11), Size = UDim2.fromScale(.21, .45),
        BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = .47,
        Rotation = -24, ZIndex = 26,
    })
    round(shine, 30)
    local crack = label(slot, "Crack", "✦", 72, Color3.fromRGB(255, 249, 214))
    crack.Position = UDim2.fromScale(.2, .20)
    crack.Size = UDim2.fromScale(.6, .45)
    crack.Visible = false
    crack.ZIndex = 27
    local viewport = add("ViewportFrame", slot, "HatchedPet", {
        Position = UDim2.fromScale(.05, .05), Size = UDim2.fromScale(.9, .65),
        BackgroundTransparency = 1, Ambient = Color3.fromRGB(220, 226, 237),
        LightColor = Color3.fromRGB(255, 246, 217), LightDirection = Vector3.new(-.5, -1, -.6),
        Visible = false, ZIndex = 26,
    })
    local petScale = add("UIScale", viewport, "PopScale", {Scale = .45})
    local petName = label(slot, "PetName", "", 24)
    petName.Position = UDim2.fromScale(.05, .71)
    petName.Size = UDim2.fromScale(.9, .12)
    petName.ZIndex = 26
    local rarity = label(slot, "Rarity", "", 20)
    rarity.Position = UDim2.fromScale(.05, .84)
    rarity.Size = UDim2.fromScale(.9, .12)
    rarity.ZIndex = 26
    slots[i] = {slot=slot, edge=edge, rays=rays, egg=egg, crack=crack,
        viewport=viewport, petScale=petScale, petName=petName, rarity=rarity}
end

local busy, auto = false, false
local requestToken = 0
local activeContext
local function setAuto(value)
    auto = value
    buttons[3].Action.Text = auto and "Stop" or "Auto"
    buttons[3].Key.Text = auto and "T" or "T"
end
local function updateRevealScale()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local view = camera.ViewportSize
    revealScale.Scale = math.min(1, view.X * .91 / 860, view.Y * .86 / 430)
end
local function requestHatch(quantity)
    if busy or (current ~= "Egg1" and current ~= "Egg2") then
        if current == "Egg3" then notice.Text = "EXCLUSIVE EGG • COMING SOON" end
        return
    end
    local zone = config.Zones[selectedIndex[current] or 1]
    if not zone then return end
    busy = true
    activeContext = {egg = current, zone = zone.id}
    requestToken += 1
    local token = requestToken
    notice.Text = "HATCHING..."
    Remotes.RequestEggHatch:FireServer(current, zone.id, quantity)
    task.delay(7, function()
        if busy and requestToken == token then
            busy = false
            setAuto(false)
            notice.Text = "Hatch request timed out. Try again."
        end
    end)
end

local function playReveal(results)
    updateRevealScale()
    reveal.Visible = true
    revealTitle.Text = "HATCHING..."
    revealRays.Rotation = 0
    for i, slot in ipairs(slots) do
        local pet = results[i]
        slot.slot.Visible = pet ~= nil
        if pet then
            local accent = pet.color or Color3.fromRGB(255, 223, 111)
            slot.slot.BackgroundColor3 = accent:Lerp(Color3.fromRGB(20, 29, 44), .75)
            slot.edge.Color = accent
            slot.rays.ImageColor3 = accent
            slot.rays.Rotation = 0
            slot.egg.Visible = true
            slot.egg.Rotation = 0
            slot.egg.Size = UDim2.fromOffset(119, 157)
            slot.egg.BackgroundTransparency = 0
            slot.crack.Visible = false
            slot.viewport.Visible = false
            slot.petScale.Scale = .45
            slot.petName.Text = ""
            slot.rarity.Text = ""
            PetViewport.populate(slot.viewport, pet.model)
        end
    end
    if #results == 1 then slots[1].slot.Position = UDim2.fromOffset(307, 72) end
    if #results == 3 then slots[1].slot.Position = UDim2.fromOffset(38, 72) end
    local reduced = player:GetAttribute("ReducedMotion") == true
    if not reduced then
        for beat = 1, 3 do
            for i = 1, #results do
                local egg = slots[i].egg
                Tween:Create(egg, TweenInfo.new(.12, Enum.EasingStyle.Quad),
                    {Rotation = beat % 2 == 0 and -13 or 13,
                     Size = UDim2.fromOffset(128, 149)}):Play()
            end
            task.wait(.14)
        end
    end
    for i = 1, #results do
        local slot = slots[i]
        slot.crack.Visible = true
        Tween:Create(slot.egg, TweenInfo.new(reduced and .04 or .27,
            Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Size = UDim2.fromOffset(191, 209), BackgroundTransparency = 1, Rotation = 0}):Play()
    end
    task.wait(reduced and .04 or .28)
    for i, pet in ipairs(results) do
        local slot = slots[i]
        slot.egg.Visible = false
        slot.crack.Visible = false
        slot.viewport.Visible = true
        slot.petName.Text = pet.name .. (pet.isNew and "  ✦ NEW" or "")
        slot.rarity.Text = string.upper(pet.rarity) .. "  •  ×" .. tostring(pet.count or 1)
        slot.rarity.TextColor3 = pet.color or Color3.new(1, 1, 1)
        Tween:Create(slot.petScale, TweenInfo.new(reduced and .04 or .33,
            Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
        Tween:Create(slot.rays, TweenInfo.new(.8), {Rotation = 44}):Play()
    end
    revealTitle.Text = #results == 1 and "PET HATCHED!" or "PETS HATCHED!"
    task.wait(reduced and .55 or 1.5)
    reveal.Visible = false
    busy = false
    local selectedZone = current and config.Zones[selectedIndex[current] or 1]
    if auto and activeContext and current == activeContext.egg
        and selectedZone and selectedZone.id == activeContext.zone then
        task.delay(.28, function() if auto and not busy then requestHatch(1) end end)
    else
        setAuto(false)
    end
end

local resultConnection = Remotes.EggHatchResult.OnClientEvent:Connect(function(response)
    if type(response) ~= "table" or not busy then return end
    requestToken += 1
    if not response.ok then
        busy = false
        setAuto(false)
        notice.Text = tostring(response.message or "Unable to hatch.")
        return
    end
    notice.Text = tostring(response.message or "Pet added to inventory.")
    task.spawn(playReveal, response.results or {})
end)
buttons[1].Activated:Connect(function() requestHatch(1) end)
buttons[2].Activated:Connect(function() requestHatch(3) end)
buttons[3].Activated:Connect(function()
    if auto then setAuto(false) return end
    if current == "Egg1" or current == "Egg2" then
        setAuto(true)
        if not busy then requestHatch(1) end
    end
end)
for _,item in ipairs(zoneButtons) do
    item.button.Activated:Connect(function() setAuto(false) end)
end
local keyConnection = UserInputService.InputBegan:Connect(function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() or not current then return end
    if input.KeyCode == Enum.KeyCode.E then requestHatch(1)
    elseif input.KeyCode == Enum.KeyCode.R then requestHatch(3)
    elseif input.KeyCode == Enum.KeyCode.T then
        if auto then setAuto(false)
        elseif current == "Egg1" or current == "Egg2" then
            setAuto(true)
            if not busy then requestHatch(1) end
        end
    end
end)
script.Destroying:Connect(function()
    resultConnection:Disconnect()
    keyConnection:Disconnect()
end)


