--!strict
-- Throw-only styling. Reuses inventory artwork without modifying inventory.
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ThrowConfig"))
local T = Config.Presentation.Hud.Theme
local Style = {}

local function make(class: string, props: {[string]: any}): any
	local o = Instance.new(class)
	for k, v in props do (o :: any)[k] = v end
	return o
end

function Style.panel(panel: GuiObject, accent: Color3?)
	panel.BackgroundColor3 = Color3.fromRGB(8, 26, 48)
	panel.BackgroundTransparency = 0
	panel.BorderSizePixel = 0
	local corner = panel:FindFirstChildOfClass("UICorner") or make("UICorner", {Parent = panel})
	corner.CornerRadius = UDim.new(0, T.Radius)
	local stroke = panel:FindFirstChildOfClass("UIStroke") or make("UIStroke", {Parent = panel})
	stroke.Color, stroke.Thickness, stroke.Transparency = accent or Color3.fromRGB(62, 164, 234), 2, 0.08
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local gradient = panel:FindFirstChildOfClass("UIGradient") or make("UIGradient", {Parent = panel})
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.fromRGB(17, 42, 68), Color3.fromRGB(7, 22, 42))
	local glow = make("Frame", {
		Name = "SoftGlow", BackgroundTransparency = 1, Active = false,
		Position = UDim2.fromOffset(-3, -3), Size = UDim2.new(1, 6, 1, 6),
		ZIndex = panel.ZIndex, Parent = panel,
	})
	make("UICorner", {CornerRadius = UDim.new(0, T.Radius + 3), Parent = glow})
	make("UIStroke", {Name = "Glow", Color = accent or Color3.fromRGB(21, 196, 255),
		Thickness = 3, Transparency = T.GlowRest, Parent = glow})
end

function Style.pebble(parent: GuiObject, position: UDim2, size: number)
	make("ImageLabel", {
		Name = "PebbleSeal", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position, Size = UDim2.fromOffset(size * 1.3, size * 1.3),
		BackgroundTransparency = 1, Image = T.PebbleImage, ScaleType = Enum.ScaleType.Fit,
		ImageRectOffset = Vector2.new(80, 48), ImageRectSize = Vector2.new(416, 280),
		Rotation = 0, ZIndex = parent.ZIndex + 2, Parent = parent,
	})
end

function Style.button(button: GuiButton, primary: boolean?)
	Style.panel(button, if primary then T.Gold else T.Edge)
	button.AutoButtonColor = false
	button.Selectable = false -- Preserve keyboard steering.
	-- A panel gradient also tints its own text; keep the caption above it.
	if button:IsA("TextButton") and button.Text ~= "" then
		make("TextLabel", {Name = "ButtonCaption", BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1), Text = button.Text, Font = button.Font,
			TextSize = button.TextSize, TextColor3 = T.Text,
			ZIndex = button.ZIndex + 2, Parent = button})
		button.Text = ""
	end
	local gradient = button:FindFirstChildOfClass("UIGradient") :: UIGradient
	if primary then gradient.Color = ColorSequence.new(T.GoldLight, T.Gold) end
	local scale = button:FindFirstChildOfClass("UIScale") or make("UIScale", {Parent = button})
	local glow = (button:FindFirstChild("SoftGlow") :: Frame):FindFirstChild("Glow") :: UIStroke
	local hover, held = false, false
	local scaleTween: Tween? = nil
	local glowTween: Tween? = nil
	local function refresh()
		if scaleTween then scaleTween:Cancel() end
		if glowTween then glowTween:Cancel() end
		scaleTween = TweenService:Create(scale, TweenInfo.new(T.HoverTime, Enum.EasingStyle.Quad), {
			Scale = if held then T.PressScale elseif hover then T.HoverScale else 1,
		})
		glowTween = TweenService:Create(glow, TweenInfo.new(T.HoverTime), {
			Transparency = if held or hover then T.GlowHover else T.GlowRest,
		})
		scaleTween:Play()
		glowTween:Play()
	end
	button.MouseEnter:Connect(function() hover = true; refresh() end)
	button.MouseLeave:Connect(function() hover = false; refresh() end)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			held = true; refresh()
		end
	end)
	local endConnection = UserInputService.InputEnded:Connect(function(input)
		if held and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			held = false; refresh()
		end
	end)
	button.Destroying:Once(function() endConnection:Disconnect() end)
end

function Style.header(panel: GuiObject, height: number)
	local header = make("Frame", {Name = "AccentHeader",
		Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 0, height),
		BackgroundColor3 = Color3.fromRGB(4, 113, 225), BorderSizePixel = 0,
		ClipsDescendants = true, ZIndex = panel.ZIndex, Parent = panel})
	make("UICorner", {CornerRadius = UDim.new(0, T.Radius - 2), Parent = header})
	make("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(11, 151, 245), Color3.fromRGB(0, 64, 185)), Parent = header})
	make("UIStroke", {Color = Color3.fromRGB(3, 188, 218), Thickness = 2, Transparency = 0.05, Parent = header})
	make("ImageLabel", {Name = "HeaderTexture", BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), Image = "rbxassetid://6927295847",
		ImageColor3 = Color3.new(1, 1, 1), ImageTransparency = 0.68,
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(121, 120),
		ZIndex = panel.ZIndex + 1, Parent = header})
	make("ImageLabel", {Name = "DiagonalGlare", BackgroundTransparency = 1,
		Position = UDim2.new(0.52, 0, -0.18, 0), Size = UDim2.new(0.45, 0, 1.36, 0),
		Image = "rbxassetid://71904840558679", ImageTransparency = 0.62,
		ScaleType = Enum.ScaleType.Stretch, ZIndex = panel.ZIndex + 2, Parent = header})
end

function Style.perfect(badge: GuiObject)
	Style.panel(badge, T.Gold)
	Style.pebble(badge, UDim2.new(0, 38, 0.5, 0), 48)
	make("TextLabel", {Name = "Title", BackgroundTransparency = 1,
		Position = UDim2.fromOffset(70, 10), Size = UDim2.new(1, -80, 0, 32),
		Text = "PERFECT!", Font = Enum.Font.FredokaOne, TextSize = 28,
		TextColor3 = T.GoldLight, TextStrokeColor3 = T.Panel, TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = badge.ZIndex + 2, Parent = badge})
	make("TextLabel", {Name = "Subtitle", BackgroundTransparency = 1,
		Position = UDim2.fromOffset(71, 43), Size = UDim2.new(1, -81, 0, 18),
		Text = "PINPOINT RELEASE", Font = Enum.Font.GothamBold, TextSize = 11,
		TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = badge.ZIndex + 2, Parent = badge})
end

return Style