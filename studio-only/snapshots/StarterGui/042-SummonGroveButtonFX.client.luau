-- Extra hover and click feedback. MainHUD's existing button scale and sound stay intact.
local TweenService = game:GetService("TweenService")
local player = game:GetService("Players").LocalPlayer
local button = script.Parent
local face = button:WaitForChild("Face")
local halo = face:WaitForChild("HoverHalo")
local flash = face:WaitForChild("ClickFlash")
local title = button:WaitForChild("Title")
local normalFace = face.BackgroundColor3
local normalTitle = title.TextColor3
local hovering = false
local active = {}

local function tween(object, properties, duration, style)
    if active[object] then active[object]:Cancel() end
    local animation = TweenService:Create(object, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
    active[object] = animation
    animation:Play()
end

local function setHover(over)
    hovering = over
    if player:GetAttribute("ReducedMotion") then
        halo.Transparency = over and .22 or 1
        halo.Thickness = over and 4 or 2
        face.BackgroundColor3 = over and Color3.fromRGB(69, 184, 255) or normalFace
        title.TextColor3 = over and Color3.fromRGB(255, 249, 207) or normalTitle
        return
    end
    tween(halo, {Transparency = over and .12 or 1, Thickness = over and 4 or 2}, .16)
    tween(face, {BackgroundColor3 = over and Color3.fromRGB(69, 184, 255) or normalFace}, .16)
    tween(title, {TextColor3 = over and Color3.fromRGB(255, 249, 207) or normalTitle}, .16)
end

button.MouseEnter:Connect(function() setHover(true) end)
button.MouseLeave:Connect(function() setHover(false) end)
button.Activated:Connect(function()
    if player:GetAttribute("ReducedMotion") then return end
    flash.Size = UDim2.fromScale(.12, .72)
    flash.Position = UDim2.fromScale(.5, .5)
    flash.BackgroundTransparency = .55
    tween(flash, {Size = UDim2.fromScale(1.28, 1.8), BackgroundTransparency = 1}, .34, Enum.EasingStyle.Quint)
    halo.Transparency = 0
    halo.Thickness = 6
    tween(halo, {Transparency = hovering and .12 or 1, Thickness = hovering and 4 or 2}, .32)
end)


