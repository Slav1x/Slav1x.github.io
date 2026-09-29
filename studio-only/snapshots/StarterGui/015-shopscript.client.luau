local TweenService=game:GetService("TweenService")
local Animations=require(game:GetService("ReplicatedStorage"):WaitForChild("SharedUI"):WaitForChild("Animations"))
local button=script.Parent
local hud=button.Parent.Parent
local panel=hud:WaitForChild("upgradesui")
local visual=button:WaitForChild("Visuals")
local scale=visual:WaitForChild("UIScale")
local icon=visual:WaitForChild("ImageLabel")
local baseRotation=icon.Rotation
local hovered,pressed=false,false
local active,turn
local function update()
 if game:GetService("Players").LocalPlayer:GetAttribute("ReducedMotion")==true then scale.Scale=1 icon.Rotation=baseRotation return end
 if active then active:Cancel() end
 if turn then turn:Cancel() end
 active=TweenService:Create(scale,TweenInfo.new(pressed and .07 or .14,Enum.EasingStyle.Quad),{Scale=pressed and .96 or (hovered and 1.045 or 1)})
 turn=TweenService:Create(icon,TweenInfo.new(.14),{Rotation=baseRotation+(hovered and 4 or 0)})
 active:Play() turn:Play()
end
button.MouseEnter:Connect(function() hovered=true update() end)
button.MouseLeave:Connect(function() hovered=false pressed=false update() end)
button.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then pressed=true update() end end)
button.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then pressed=false update() end end)
button.MouseButton1Click:Connect(function() panel.Toggle:Fire() end)

