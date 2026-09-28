--!strict
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local hud=script.Parent
local player=Players.LocalPlayer
local profile=require(player:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("ProfileStore"))
local progression=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionConfig"))
local sounds=require(ReplicatedStorage:WaitForChild("SharedUI"):WaitForChild("UISounds"))
local cash=hud:WaitForChild("CashMultiplierHUD")
local cashPane=hud:WaitForChild("MultiplierBreakdown")
local button=hud:WaitForChild("SpinMultiplierHUD")
local pane=hud:WaitForChild("SpinMultiplierBreakdown")
local rows=pane:WaitForChild("BreakdownList")
local pinned=false
local function fmt(value)
 value=tonumber(value) or 1
 if math.abs(value-math.round(value))<.005 then return tostring(math.round(value)).."x" end
 return string.format("%.2f",value):gsub("0$","").."x"
end
local function refresh()
 local state=profile.get()
 local rebirths=tonumber(state.rebirths) or 0
 local strength=progression.normalizeSpinStrength(state.spinStrength or progression.StartingSpinStrength)
 local strengthFactor=(strength/progression.StartingSpinStrength)^progression.SpinGainGrowthExponent
 local rebirthFactor=progression.rebirthGainMultiplier(rebirths)
 local total=tonumber(state.spinGainMultiplier) or strengthFactor*rebirthFactor
 button.Value.Text=fmt(total)
 pane.Total.Text=fmt(total)
 local data={
  {"Base spin gain","1x"},
  {"Strength ("..progression.formatStrength(strength)..")",fmt(strengthFactor)},
  {"Rebirth bonus ("..math.floor(rebirths)..")",fmt(rebirthFactor)},
 }
 for i=1,10 do
  local row=rows:FindFirstChild("Row"..i)
  if row then
   row.Visible=i<=#data
   if i<=#data then row.Label.Text=data[i][1];row.Value.Text=data[i][2] end
  end
 end
end
profile.onChanged(refresh)
refresh()
local function syncLayout()
 local scale=cash:FindFirstChildOfClass("UIScale")
 local target=button:FindFirstChildOfClass("UIScale")
 if scale and target then target.Scale=scale.Scale end
 button:SetAttribute("BaseScale",cash:GetAttribute("BaseScale") or 1)
 local gap=10*(scale and scale.Scale or 1)
 button.Position=UDim2.new(cash.Position.X.Scale,cash.Position.X.Offset-cash.AbsoluteSize.X-gap,cash.Position.Y.Scale,cash.Position.Y.Offset)
 local width=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X or hud.AbsoluteSize.X
 if width>=800 then
  pane.Position=UDim2.new(cashPane.Position.X.Scale,cashPane.Position.X.Offset-cashPane.AbsoluteSize.X-10,cashPane.Position.Y.Scale,cashPane.Position.Y.Offset)
 else
  pane.Position=cashPane.Position
 end
 pane.ResponsiveScale.Scale=cashPane.ResponsiveScale.Scale
end
cash:GetPropertyChangedSignal("Position"):Connect(syncLayout)
cash:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncLayout)
cashPane:GetPropertyChangedSignal("Position"):Connect(syncLayout)
cashPane.ResponsiveScale:GetPropertyChangedSignal("Scale"):Connect(syncLayout)
task.defer(syncLayout)
local uiScale=button:FindFirstChildOfClass("UIScale")
local function animate(scale)
 if uiScale then
  TweenService:Create(uiScale,TweenInfo.new(.13),{Scale=scale}):Play()
 end
end
button.MouseEnter:Connect(function()
 cashPane.Visible=false
 if not hud.IndexPanel.Visible then pane.Visible=true end
 if not player:GetAttribute("ReducedMotion") then animate((button:GetAttribute("BaseScale") or 1)*1.055) end
 sounds.play("Hover")
end)
button.MouseLeave:Connect(function()
 if not pinned then pane.Visible=false end
 animate(button:GetAttribute("BaseScale") or 1)
end)
button.Activated:Connect(function()
 sounds.play("Click")
 cashPane.Visible=false
 pinned=not pinned
 pane.Visible=pinned
end)
cash.MouseEnter:Connect(function() pinned=false;pane.Visible=false end)
cash.Activated:Connect(function() pinned=false;pane.Visible=false end)
hud.IndexPanel:GetPropertyChangedSignal("Visible"):Connect(function()
 if hud.IndexPanel.Visible then pinned=false;pane.Visible=false end
end)

