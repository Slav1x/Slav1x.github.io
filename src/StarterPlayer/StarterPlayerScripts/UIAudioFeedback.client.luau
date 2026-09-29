-- Consistent feedback for authored and dynamically created controls.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Sounds=require(RS.SharedUI.UISounds)
local gui=Players.LocalPlayer:WaitForChild("PlayerGui")
local wired=setmetatable({},{__mode="k"})
local function audible(button)
 if not button.Active or not button.Interactable then return false end
 local node=button
 while node and node~=gui do
  if node:IsA("GuiObject") and not node.Visible then return false end
  if node:IsA("ScreenGui") and not node.Enabled then return false end
  node=node.Parent
 end
 return node==gui and button:GetAttribute("SilentUI")~=true
end
local function bind(button)
 if not button:IsA("GuiButton") or wired[button] then return end
 wired[button]=true
 button.MouseEnter:Connect(function()
  if audible(button) then Sounds.play("Hover") end
 end)
 local pressedActive=false
 button.InputBegan:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then pressedActive=audible(button) end
 end)
 button.Activated:Connect(function()
  -- Existing bespoke click handlers run first; the shared sound bank deduplicates them.
  local wasActive=pressedActive or audible(button)
  pressedActive=false
  task.defer(function() if wasActive then Sounds.play("Click") end end)
 end)
end
for _,node in gui:GetDescendants() do bind(node) end
gui.DescendantAdded:Connect(bind)
