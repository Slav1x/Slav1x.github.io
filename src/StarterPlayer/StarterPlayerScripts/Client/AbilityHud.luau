--!strict
-- Fuel presentation lives in the existing ThrowHud, so flight visibility stays coherent.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local AbilityCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("AbilityCatalog"))
local AbilityHud = {}
local player = Players.LocalPlayer
local started = false
local function make(class: string, properties)
	local item = Instance.new(class)
	for key, value in pairs(properties) do if key ~= "Parent" then item[key] = value end end
	item.Parent = properties.Parent
	return item
end
function AbilityHud.start(gui: ScreenGui, hold: (boolean) -> ())
	if started then return end
	started = true
	local panel = make("Frame", {Name="JetpackFuel", AnchorPoint=Vector2.new(.5,1), Position=UDim2.new(.5,0,1,-106), Size=UDim2.fromOffset(280,65), BackgroundColor3=Color3.fromRGB(16,31,46), BackgroundTransparency=.1, BorderSizePixel=0, Visible=false, ZIndex=14, Parent=gui})
	make("UICorner", {CornerRadius=UDim.new(0,14), Parent=panel})
	make("UIStroke", {Color=Color3.fromRGB(201,171,103), Transparency=.2, Thickness=1.5, Parent=panel})
	local title = make("TextLabel", {Name="FuelTitle", Position=UDim2.fromOffset(13,7), Size=UDim2.new(1,-26,0,17), BackgroundTransparency=1, Font=Enum.Font.GothamBold, TextSize=12, TextColor3=Color3.fromRGB(249,227,181), TextXAlignment=Enum.TextXAlignment.Left, Text="JETPACK  ·  8.0s", ZIndex=15, Parent=panel})
	local track = make("Frame", {Name="FuelTrack", Position=UDim2.fromOffset(13,30), Size=UDim2.new(1,-26,0,10), BackgroundColor3=Color3.fromRGB(5,17,29), BorderSizePixel=0, ClipsDescendants=true, ZIndex=15, Parent=panel})
	make("UICorner", {CornerRadius=UDim.new(1,0), Parent=track})
	local fill = make("Frame", {Name="FuelFill", Size=UDim2.fromScale(1,1), BackgroundColor3=Color3.fromRGB(82,204,236), BorderSizePixel=0, ZIndex=16, Parent=track})
	make("UICorner", {CornerRadius=UDim.new(1,0), Parent=fill})
	local hint = make("TextLabel", {Name="FuelHint", Position=UDim2.fromOffset(13,44), Size=UDim2.new(1,-26,0,13), BackgroundTransparency=1, Font=Enum.Font.GothamMedium, TextSize=10, TextColor3=Color3.fromRGB(176,198,212), TextXAlignment=Enum.TextXAlignment.Left, Text="THROW · HOLD SPACE TO FLY", ZIndex=15, Parent=panel})
	local touch = make("TextButton", {Name="JetpackHold", AnchorPoint=Vector2.new(1,.5), Position=UDim2.new(1,-7,.5,0), Size=UDim2.fromOffset(64,50), BackgroundColor3=Color3.fromRGB(30,77,95), BorderSizePixel=0, Text="HOLD\nTO FLY", Font=Enum.Font.GothamBold, TextSize=12, TextColor3=Color3.fromRGB(228,246,248), Visible=UserInputService.TouchEnabled, ZIndex=16, Parent=panel})
	make("UICorner", {CornerRadius=UDim.new(0,14), Parent=touch})
	if UserInputService.TouchEnabled then
		title.Size = UDim2.new(1,-90,0,17)
		track.Size = UDim2.new(1,-90,0,10)
		hint.Size = UDim2.new(1,-90,0,13)
		hint.TextSize = 8
	end
	touch.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then hold(true) end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then hold(false) end
	end)
	local displayFuel = player:GetAttribute("JetpackFuel") or AbilityCatalog.Jetpack.MaxFuel
	local receivedFuel, receivedAt = displayFuel, os.clock()
	player:GetAttributeChangedSignal("JetpackFuel"):Connect(function()
		receivedFuel = player:GetAttribute("JetpackFuel") or AbilityCatalog.Jetpack.MaxFuel
		receivedAt = os.clock()
	end)
	RunService.RenderStepped:Connect(function(dt)
		local equipped = player:GetAttribute("EquippedAbility") == "jetpack_rock"
		panel.Visible = equipped
		if not equipped then return end
		local active = player:GetAttribute("JetpackActive") == true
		local flying = player:GetAttribute("RockInFlight") == true
		local empty = player:GetAttribute("JetpackExhausted") == true
		local target = math.clamp(receivedFuel - (if active then os.clock()-receivedAt else 0), 0, AbilityCatalog.Jetpack.MaxFuel)
		displayFuel += (target-displayFuel) * (1-math.exp(-20*dt))
		fill.Size = UDim2.fromScale(math.clamp(displayFuel/AbilityCatalog.Jetpack.MaxFuel,0,1),1)
		fill.BackgroundColor3 = if displayFuel < 1.5 then Color3.fromRGB(245,138,79) else Color3.fromRGB(82,204,236)
		title.Text = string.format("JETPACK  ·  %.1fs / %.0fs",displayFuel,AbilityCatalog.Jetpack.MaxFuel)
		hint.Text = if active then "THRUST ACTIVE  ·  A / D TO STEER"
			elseif empty then "RELEASE SPACE TO RECHARGE"
			elseif not flying then "THROW · HOLD SPACE TO FLY"
			elseif target < AbilityCatalog.Jetpack.MaxFuel-.05 then "RECHARGING  ·  HOLD SPACE TO FLY"
			else "HOLD SPACE / BUTTON A  ·  RELEASE TO GLIDE"
	end)
end
return AbilityHud
