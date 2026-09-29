local hud=script.Parent.Parent
local plus=script.Parent:WaitForChild("CashPacksPlus")
plus.Activated:Connect(function()
 if not hud.shopui.Visible then hud.OpenMenu:Fire("shop") end
 hud.shopui.OpenCashPacks:Fire()
end)

