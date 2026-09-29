local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Animations = require(ReplicatedStorage:WaitForChild("SharedUI"):WaitForChild("Animations"))

local button = script.Parent
local mainHUD = button.Parent.Parent
local settingsUI = mainHUD:WaitForChild("settingsui")
local uiScale = button:FindFirstChildOfClass("UIScale")
if not uiScale then
	uiScale = Instance.new("UIScale")
	uiScale.Parent = button
end

button.MouseEnter:Connect(function()
	TweenService:Create(uiScale, TweenInfo.new(0.1), {Scale = 1.05}):Play()
end)

button.MouseLeave:Connect(function()
	TweenService:Create(uiScale, TweenInfo.new(0.1), {Scale = 1}):Play()
end)

button.MouseButton1Click:Connect(function()
	settingsUI.Toggle:Fire()
end)

