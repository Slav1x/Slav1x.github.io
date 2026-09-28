-- Raised HUD plus-button motion, adapted from JakeDev's hover and click behavior.
-- This animates prebuilt Studio UI; it creates no UI at runtime.
local TweenService=game:GetService("TweenService")
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local button=script.Parent
local scale=button:WaitForChild("HoverScale")
local shade=button.RaisedFace:WaitForChild("HoverShade")
local hovered=false
local down=false
local lastPointer=-math.huge
local active={}
local function animate(size,alpha,duration,style)
 for _,t in active do t:Cancel() end
 table.clear(active)
 if player:GetAttribute("ReducedMotion") then
  scale.Scale=1
  shade.BackgroundTransparency=1
  return
 end
 local info=TweenInfo.new(duration,style or Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
 for _,pair in {{scale,{Scale=size}},{shade,{BackgroundTransparency=alpha}}} do
  local t=TweenService:Create(pair[1],info,pair[2])
  table.insert(active,t)
  t:Play()
 end
end
local function enter()
 hovered=true
 if not down then animate(1.07,.86,.16,Enum.EasingStyle.Back) end
end
local function leave()
 hovered=false
 if not down then animate(1,1,.15) end
end
button.MouseEnter:Connect(enter)
button.MouseLeave:Connect(leave)
button.SelectionGained:Connect(enter)
button.SelectionLost:Connect(leave)
button.InputBegan:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
  lastPointer=os.clock()
  down=true
  animate(1.12,.7,.1,Enum.EasingStyle.Back)
 end
end)
button.InputEnded:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
  down=false
  animate(hovered and 1.07 or 1,hovered and .86 or 1,.17,Enum.EasingStyle.Back)
 end
end)
button.Activated:Connect(function()
 if os.clock()-lastPointer<.4 then return end
 animate(1.12,.7,.1,Enum.EasingStyle.Back)
 task.delay(.13,function()
  if button.Parent then animate(hovered and 1.07 or 1,hovered and .86 or 1,.17,Enum.EasingStyle.Back) end
 end)
end)

