--!strict
--[[
	PanelKit (client)

	Small UI toolkit for the panels this project adds (Upgrades, Rebirth,
	Stats). Deliberately self-contained rather than reusing SharedUI, because
	SharedUI lives outside Rojo and is edited by other people -- a panel that
	depends on it can break without anything in this repo changing.

	Everything auto-sizes or scales, so nothing clips the way the fixed-width
	combo label did.
]]

local PanelKit = {}

PanelKit.Colors = {
	Backdrop = Color3.fromRGB(8, 14, 22),
	Panel = Color3.fromRGB(18, 26, 38),
	Row = Color3.fromRGB(28, 39, 55),
	RowAlt = Color3.fromRGB(34, 47, 66),
	Accent = Color3.fromRGB(90, 200, 255),
	Good = Color3.fromRGB(90, 230, 140),
	Bad = Color3.fromRGB(255, 105, 105),
	Gold = Color3.fromRGB(255, 205, 90),
	Text = Color3.fromRGB(235, 243, 255),
	TextDim = Color3.fromRGB(150, 168, 190),
}

PanelKit.Font = Enum.Font.GothamBold
PanelKit.FontHeavy = Enum.Font.GothamBlack

function PanelKit.new(className: string, props: {[string]: any}?, children: {Instance}?): any
	local instance = Instance.new(className)
	if props then
		for key, value in props do
			if key ~= "Parent" then
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function PanelKit.corner(radius: number?): UICorner
	return PanelKit.new("UICorner", {CornerRadius = UDim.new(0, radius or 12)})
end

function PanelKit.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return PanelKit.new("UIStroke", {
		Color = color or Color3.fromRGB(255, 255, 255),
		Thickness = thickness or 2,
		Transparency = transparency or 0.78,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function PanelKit.padding(all: number): UIPadding
	return PanelKit.new("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, all),
		PaddingRight = UDim.new(0, all),
	})
end

-- 1234 -> 1.2K. Panels show a lot of money and a lot of costs.
function PanelKit.short(value: number): string
	value = math.floor(value)
	if value >= 1_000_000_000 then
		return string.format("%.2fB", value / 1_000_000_000)
	elseif value >= 1_000_000 then
		return string.format("%.2fM", value / 1_000_000)
	elseif value >= 10_000 then
		return string.format("%.1fK", value / 1000)
	end
	return tostring(value)
end

--[[
	A centred modal panel with a header, a close button and a scrolling body.
	Returns the root (so callers can show/hide), the body to fill, and the
	title label so a panel can retitle itself live.
]]
function PanelKit.makePanel(
	parent: Instance,
	name: string,
	title: string,
	width: number,
	height: number
): (Frame, ScrollingFrame, TextLabel)
	local root = PanelKit.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = PanelKit.Colors.Panel,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 40,
		Parent = parent,
	}, {
		PanelKit.corner(18),
		PanelKit.stroke(PanelKit.Colors.Accent, 2, 0.55),
		PanelKit.new("UISizeConstraint", {
			MinSize = Vector2.new(300, 260),
			MaxSize = Vector2.new(width, height),
		}),
	})

	local header = PanelKit.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = PanelKit.Colors.Backdrop,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = 41,
		Parent = root,
	}, {PanelKit.corner(18)})

	local titleLabel = PanelKit.new("TextLabel", {
		Name = "Title",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 20, 0.5, 0),
		Size = UDim2.new(1, -80, 0, 30),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = PanelKit.Colors.Text,
		Font = PanelKit.FontHeavy,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 42,
		Parent = header,
	})

	local close = PanelKit.new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = PanelKit.Colors.Bad,
		AutoButtonColor = false,
		Text = "✕",
		TextColor3 = PanelKit.Colors.Text,
		Font = PanelKit.FontHeavy,
		TextSize = 18,
		ZIndex = 42,
		Parent = header,
	}, {PanelKit.corner(10)})
	close.MouseButton1Click:Connect(function()
		root.Visible = false
	end)

	local body = PanelKit.new("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.new(0, 0, 0, 58),
		Size = UDim2.new(1, 0, 1, -58),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PanelKit.Colors.Accent,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 41,
		Parent = root,
	}, {
		PanelKit.padding(12),
		PanelKit.new("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	return root, body, titleLabel
end

--[[
	A list row: icon, title, subtitle, and an action button on the right.
	Returns the row and the button so the caller can drive its state.
]]
function PanelKit.makeRow(parent: Instance, order: number): (Frame, TextLabel, TextLabel, TextButton, TextLabel)
	local row = PanelKit.new("Frame", {
		Name = "Row" .. order,
		Size = UDim2.new(1, 0, 0, 66),
		BackgroundColor3 = if order % 2 == 0 then PanelKit.Colors.Row else PanelKit.Colors.RowAlt,
		BorderSizePixel = 0,
		LayoutOrder = order,
		ZIndex = 42,
		Parent = parent,
	}, {PanelKit.corner(12)})

	local icon = PanelKit.new("TextLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(42, 42),
		BackgroundTransparency = 1,
		Text = "",
		TextSize = 28,
		Font = PanelKit.Font,
		ZIndex = 43,
		Parent = row,
	})

	local title = PanelKit.new("TextLabel", {
		Name = "Title",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 62, 0, 12),
		Size = UDim2.new(1, -210, 0, 22),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = PanelKit.Colors.Text,
		Font = PanelKit.FontHeavy,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 43,
		Parent = row,
	})

	local subtitle = PanelKit.new("TextLabel", {
		Name = "Subtitle",
		Position = UDim2.new(0, 62, 0, 34),
		Size = UDim2.new(1, -210, 0, 20),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = PanelKit.Colors.TextDim,
		Font = PanelKit.Font,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 43,
		Parent = row,
	})

	local button = PanelKit.new("TextButton", {
		Name = "Action",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(124, 40),
		BackgroundColor3 = PanelKit.Colors.Accent,
		AutoButtonColor = false,
		Text = "",
		TextColor3 = Color3.fromRGB(10, 16, 24),
		Font = PanelKit.FontHeavy,
		TextSize = 15,
		ZIndex = 43,
		Parent = row,
	}, {PanelKit.corner(10)})

	return row, title, subtitle, button, icon
end

return PanelKit
