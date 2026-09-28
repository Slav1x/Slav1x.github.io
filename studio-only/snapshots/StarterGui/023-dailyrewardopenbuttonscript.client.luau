local TweenService = game:GetService("TweenService")

local button = script.Parent
local playerGui = button.Parent.Parent.Parent
local dailyRewardGUI = playerGui:WaitForChild("DailyRewardsUI")

local uiScale = button:WaitForChild("UIScale")

-- Hover
button.MouseEnter:Connect(function()
	TweenService:Create(
		uiScale,
		TweenInfo.new(0.1),
		{Scale = 1.05}
	):Play()
end)

button.MouseLeave:Connect(function()
	TweenService:Create(
		uiScale,
		TweenInfo.new(0.1),
		{Scale = 1}
	):Play()
end)

-- Open / close
button.Activated:Connect(function()
	dailyRewardGUI.Enabled = not dailyRewardGUI.Enabled
end)
