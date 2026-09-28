local TweenService=game:GetService("TweenService")
local Players=game:GetService("Players")
local button=script.Parent
local icon=button.DailyCalendarArt
local home=icon.Rotation
local token=0
local current
local function reset()
 token+=1
 if current then current:Cancel() end
 current=TweenService:Create(icon,TweenInfo.new(.12,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Rotation=home})
 current:Play()
end
button.MouseEnter:Connect(function()
 if Players.LocalPlayer:GetAttribute("ReducedMotion") then return end
 token+=1
 local this=token
 task.spawn(function()
  for _,angle in {10,-10,7,-5,home} do
   if this~=token or not button.Parent then return end
   current=TweenService:Create(icon,TweenInfo.new(.11,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),{Rotation=angle})
   current:Play()
   current.Completed:Wait()
  end
 end)
end)
button.MouseLeave:Connect(reset)

