local cash=script.Parent
local K=require(cash.Parent.UIPolishKit)
local player=game:GetService("Players").LocalPlayer
local money=player:WaitForChild("leaderstats"):WaitForChild("Money")
local function refresh()
 cash.Value.Text="$"..K.compact(money.Value)
end
money.Changed:Connect(refresh)
refresh()

