-- Shared world blur, header glare motion, and cash flight.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local hud = script.Parent
local daily = pg:WaitForChild("DailyRewardsUI")
local gifts = pg:WaitForChild("PlaytimeGiftsUI")
local quests = pg:WaitForChild("QuestsUI")
local prompt = pg:FindFirstChild("SummonPromptUI")

local function isShown(object)
    local current = object
    while current and current ~= pg do
        if current:IsA("ScreenGui") and not current.Enabled then return false end
        if current:IsA("GuiObject") and not current.Visible then return false end
        current = current.Parent
    end
    return current == pg
end

local headerGlare = {}
for _, root in {hud, daily, gifts, quests} do
    for _, child in root:GetDescendants() do
        if child.Name == "SivaFixedGlare" and child:IsA("Frame")
            and (child.Parent.Name == "Header" or child.Parent.Name:match("^Reward%d+$") or child.Parent == hud.inventoryui.Title or child.Parent == hud.SummonGroveQuickButton.Face) then
            local image = child:FindFirstChild("DiagonalGlare")
            if image then table.insert(headerGlare, {image = image, delay = math.random() * 1.1}) end
        end
    end
end
local rewardRays = {}
for _, root in {daily, gifts, quests} do
    for _, image in root:GetDescendants() do
        if image:IsA("ImageLabel") and (image.Name == "RewardSunray" or image.Name == "QuestSunray") then
            table.insert(rewardRays, image)
        end
    end
end
local sharedCloseButtons = {
    hud.IndexPanel.Header.Close,
    hud.shopui.Shell.Header.CloseButton,
    hud.inventoryui.CloseButton,
    hud.upgradesui.Surface.Header.Close,
    hud.settingsui.Surface.Header.Close,
    daily.Background.Header.Close,
    gifts.Background.Header.Close,
    quests.QuestPanel.Header.Close,
}
for _, button in sharedCloseButtons do
    -- Keep close controls centered in their headers after responsive layouts run.
    local header = button.Parent.Name == "Header" and button.Parent or nil
    local normalizing = false
    local function syncClose()
        if normalizing then return end
        normalizing = true
        local side = header and math.clamp(header.AbsoluteSize.Y - 12, 38, 46) or 46
        local size = UDim2.fromOffset(side, side)
        if button.Size ~= size then button.Size = size end
        if header then
            local anchor = Vector2.new(1, .5)
            local position = UDim2.new(1, -12, .5, 0)
            if button.AnchorPoint ~= anchor then button.AnchorPoint = anchor end
            if button.Position ~= position then button.Position = position end
        end
        normalizing = false
    end
    button:GetPropertyChangedSignal("Position"):Connect(syncClose)
    button:GetPropertyChangedSignal("Size"):Connect(syncClose)
    if header then header:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncClose) end
    task.defer(syncClose)
    local scale = button:FindFirstChildOfClass("UIScale")
    local shade = button:FindFirstChild("HoverShade")
    local hovered = false
    local function animateClose(isDown)
        if scale then
            local target = isDown and .94 or (hovered and 1.11 or 1)
            if player:GetAttribute("ReducedMotion") then scale.Scale = 1
            else TweenService:Create(scale, TweenInfo.new(.13, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = target}):Play() end
        end
        if shade then
            TweenService:Create(shade, TweenInfo.new(.13), {BackgroundTransparency = hovered and .7 or 1}):Play()
        end
    end
    button.MouseEnter:Connect(function() hovered=true; animateClose(false) end)
    button.MouseLeave:Connect(function() hovered=false; animateClose(false) end)
    button.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then animateClose(true) end
    end)
    button.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then animateClose(false) end
    end)
end
local rayTime = 0
RunService.Heartbeat:Connect(function(dt)
    if player:GetAttribute("ReducedMotion") then return end
    rayTime += dt
    if rayTime < 1/30 then return end
    local advance = math.min(rayTime, .1)
    rayTime = 0
    for _, image in rewardRays do
        if image.Parent and isShown(image) then
            image.Rotation = (image.Rotation + (image:GetAttribute("RewardRaySpeed") or 12) * advance) % 360
        end
    end
end)
task.spawn(function()
    while hud.Parent do
        for _, entry in headerGlare do
            local glare = entry.image
            if glare.Parent then
                if player:GetAttribute("ReducedMotion") then
                    glare.Position = UDim2.fromScale(.5, .5)
                elseif isShown(glare) then
                    task.delay(entry.delay, function()
                        if glare.Parent and isShown(glare) and not player:GetAttribute("ReducedMotion") then
                            glare.Position = UDim2.new(0, -120, .5, 0)
                            TweenService:Create(glare, TweenInfo.new(1.65, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                                Position = UDim2.new(1, 120, .5, 0),
                            }):Play()
                        end
                    end)
                end
            end
        end
        task.wait(5.8)
    end
end)

-- The older menu controllers still call their own blur functions. Disable those
-- effects so only this controller owns the blur seen by the player.
local function retireOldBlur(child)
    if child:IsA("BlurEffect") and (child.Name == "MenuWorldBlur" or child.Name == "IndexWorldBlur") then child.Enabled = false end
end
for _, child in Lighting:GetChildren() do retireOldBlur(child) end
Lighting.ChildAdded:Connect(retireOldBlur)
local worldBlur = Lighting:FindFirstChild("SivaWorldBlur") or Instance.new("BlurEffect")
worldBlur.Name = "SivaWorldBlur"
worldBlur.Size = 0
worldBlur.Parent = Lighting
local blurTween
local function modalIsOpen()
    for _, name in {"shopui", "inventoryui", "upgradesui", "settingsui", "IndexPanel"} do
        local modal = hud:FindFirstChild(name)
        if modal and isShown(modal) then return true end
    end
    for _, name in {"DailyRewardsUI", "PlaytimeGiftsUI", "QuestsUI"} do
        local modal = pg:FindFirstChild(name)
        if modal and isShown(modal) then return true end
    end
    return false
end
local lastBlurTarget = -1
local function updateBlur()
    local protectedOpen = false
    for _, name in {"shopui", "inventoryui", "upgradesui", "IndexPanel"} do
        local menu = hud:FindFirstChild(name)
        if menu and isShown(menu) then protectedOpen = true; break end
    end
    local target = modalIsOpen() and (protectedOpen and 22 or 18) or 0
    if target == lastBlurTarget then return end
    lastBlurTarget = target
    if blurTween then blurTween:Cancel() end
    if player:GetAttribute("ReducedMotion") then worldBlur.Size = target
    else
        blurTween = TweenService:Create(worldBlur, TweenInfo.new(.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = target})
        blurTween:Play()
    end
end
updateBlur()
task.spawn(function()
    while hud.Parent do
        updateBlur()
        task.wait(.1)
    end
end)

-- Every positive Money stat change uses the same cash flight, regardless of source.
local money = player:WaitForChild("leaderstats"):WaitForChild("Money")
local walletIcon = hud.Money.IconWell.Icon
local ThrowInput = require(player:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("ThrowInput"))
local effects = Instance.new("ScreenGui")
effects.Name = "SivaCashFlight"
effects.IgnoreGuiInset = true
effects.ResetOnSpawn = false
effects.DisplayOrder = 60
effects.Parent = pg

local gain = Instance.new("TextLabel")
gain.Name = "WalletGain"
gain.BackgroundTransparency = 1
gain.Size = UDim2.fromOffset(190, 30)
gain.Font = Enum.Font.FredokaOne
gain.TextSize = 23
gain.TextColor3 = Color3.fromRGB(170, 255, 160)
gain.TextStrokeColor3 = Color3.fromRGB(9, 28, 20)
gain.TextStrokeTransparency = 0
gain.TextXAlignment = Enum.TextXAlignment.Left
gain.Visible = false
gain.Parent = effects

local previous, pending = money.Value, 0
local busy = false
local queued = false
local noticeId = 0
local function formatted(amount)
 return tostring(math.floor(amount)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end
local function showWalletGain(amount)
 noticeId += 1
 local ticket = noticeId
 local at = walletIcon.AbsolutePosition + Vector2.new(walletIcon.AbsoluteSize.X + 6, 2)
 gain.Position = UDim2.fromOffset(at.X, at.Y)
 gain.Text = "+$" .. formatted(amount)
 gain.TextTransparency = 0
 gain.TextStrokeTransparency = 0
 gain.Visible = true
 TweenService:Create(gain, TweenInfo.new(.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
  Position = UDim2.fromOffset(at.X, at.Y - 10),
 }):Play()
 task.delay(.72, function()
  if ticket ~= noticeId then return end
  TweenService:Create(gain, TweenInfo.new(.26), {TextTransparency=1, TextStrokeTransparency=1}):Play()
  task.delay(.28, function() if ticket==noticeId then gain.Visible=false end end)
 end)
end
local function newCashIcon(name, at, size, transparency)
 local img = Instance.new("ImageLabel")
 img.Name = name
 img.BackgroundTransparency = 1
 img.Image = walletIcon.Image
 img.ImageTransparency = transparency
 img.AnchorPoint = Vector2.new(.5,.5)
 img.Position = UDim2.fromOffset(at.X, at.Y)
 img.Size = UDim2.fromOffset(size,size)
 img.ZIndex = 4
 img.Parent = effects
 return img
end
local function playGain()
 queued = false
 if busy or pending <= 0 then return end
 if ThrowInput.isBusy() then
  queued = true
  task.delay(.15, playGain)
  return
 end
 busy = true
 local amount = pending
 pending = 0
 if player:GetAttribute("ReducedMotion") then
  showWalletGain(amount)
  task.delay(.3, function() busy=false; if pending>0 then task.delay(.15,playGain) end end)
  return
 end
 local camera = workspace.CurrentCamera
 local viewport = camera and camera.ViewportSize or Vector2.new(800,600)
 local center = viewport * .5
 local target = walletIcon.AbsolutePosition + walletIcon.AbsoluteSize*.5
 local count = math.clamp(math.floor(math.log10(amount+1)*2)+4, 5, 9)
 local icons = {}
 for i=1,count do
  local angle = i*math.pi*2/count + .25
  local radius = 74 + (i%3)*18
  local start = center + Vector2.new(math.cos(angle)*radius, math.sin(angle)*radius*.62)
  local img = newCashIcon("GatheredCash"..i, start, 30+(i%3)*5, .08)
  icons[i] = img
  TweenService:Create(img, TweenInfo.new(.31+(i%3)*.035, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
   Position=UDim2.fromOffset(center.X,center.Y),
   Size=UDim2.fromOffset(36,36),
   ImageTransparency=.02,
  }):Play()
 end
 local amountLabel = Instance.new("TextLabel")
 amountLabel.Name = "GatheredAmount"
 amountLabel.AnchorPoint = Vector2.new(.5,0)
 amountLabel.Position = UDim2.fromOffset(center.X,center.Y+23)
 amountLabel.Size = UDim2.fromOffset(190,33)
 amountLabel.BackgroundTransparency = 1
 amountLabel.Font = Enum.Font.FredokaOne
 amountLabel.TextSize = 25
 amountLabel.Text = "+$"..formatted(amount)
 amountLabel.TextColor3 = Color3.fromRGB(179,255,172)
 amountLabel.TextStrokeColor3 = Color3.fromRGB(8,41,34)
 amountLabel.TextStrokeTransparency = 0
 amountLabel.ZIndex = 5
 amountLabel.Parent = effects
 task.delay(.39,function()
  if not effects.Parent then return end
  for i,img in icons do
   if img.Parent then
    local spread = Vector2.new((i%3-1)*8,(i%2==0 and -1 or 1)*5)
    TweenService:Create(img,TweenInfo.new(.49+(i%3)*.045,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{
     Position=UDim2.fromOffset(target.X+spread.X,target.Y+spread.Y),
     Size=UDim2.fromOffset(16,16),
     ImageTransparency=.32,
    }):Play()
   end
  end
  TweenService:Create(amountLabel,TweenInfo.new(.28),{TextTransparency=1,TextStrokeTransparency=1}):Play()
 end)
 task.delay(1.01,function()
  for _,img in icons do img:Destroy() end
  amountLabel:Destroy()
  showWalletGain(amount)
  busy=false
  if pending>0 then task.delay(.13,playGain) end
 end)
end
money.Changed:Connect(function(value)
 local delta = value-previous
 previous=value
 if delta<=0 then return end
 pending+=delta
 if not busy and not queued then
  queued=true
  task.delay(.16,playGain)
 end
end)

