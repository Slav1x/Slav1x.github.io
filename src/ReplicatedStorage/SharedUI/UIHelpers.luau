--!strict
--[[
	UIHelpers
	Reusable builders for the game UI: instance factory, corners, strokes,
	padding, panels, tab bars, scrollable grids, and item slots.
	All panels are scale-based with pixel constraints so they work on PC and mobile.
--]]

local Theme = require(script.Parent.Theme)

local UIHelpers = {}

-- Generic instance factory. "Parent" is always applied last.
function UIHelpers.create(className: string, props: {[string]: any}?, children: {Instance}?): Instance
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

function UIHelpers.corner(radius: number?): UICorner
	return UIHelpers.create("UICorner", {CornerRadius = UDim.new(0, radius or Theme.Sizes.Corner)})
end

--[[
	STUD SURFACE TEXTURE SYSTEM
	LEGO-style stud texture (asset 6927295847) tiled across UI surfaces.

	How edit-mode invisibility works:
	- At EDIT time, surfaces are only TAGGED via the "StudSurface" attribute
	  (UIHelpers.tagStudSurface). No texture instance exists, so Studio shows
	  clean panels.
	- At RUNTIME, a LocalScript (MainHUDScript) walks the PlayerGui and calls
	  UIHelpers.applyStudTexture on every tagged surface. LocalScript changes
	  only exist while the game is running, so the studs appear in Play mode only.
--]]

UIHelpers.STUD_TEXTURE_ID = "rbxassetid://6927295847"

-- Tags a GuiObject so the runtime stud applier textures it during play.
function UIHelpers.tagStudSurface(surface: GuiObject)
	surface:SetAttribute("StudSurface", true)
end

--[[
	Creates the tiled stud texture layer on a surface. RUNTIME ONLY — call from
	LocalScripts (e.g. MainHUDScript) so the texture never renders in edit mode.
]]
function UIHelpers.applyStudTexture(surface: GuiObject, tileSize: number?, transparency: number?): ImageLabel
	local existing = surface:FindFirstChild("StudTexture")
	if existing and existing:IsA("ImageLabel") then
		return existing
	end
	local size = tileSize or 28
	return UIHelpers.create("ImageLabel", {
		Name = "StudTexture",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = UIHelpers.STUD_TEXTURE_ID,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(size, size),
		ImageTransparency = transparency or 0.2,
		ZIndex = 1, -- sits above the background, below icons/text (ZIndex 2+)
		Parent = surface,
	}) :: ImageLabel
end

--[[
	Responsive left-nav button: chunky rounded square with an icon and a label.
	Scale-sized with aspect-ratio + min/max pixel constraints so it works on
	PC and mobile. Tagged as a stud surface and carries a "PanelName" attribute
	that UI scripts can read to decide which panel the button opens.
]]
function UIHelpers.makeNavButton(config: {
	Name: string,
	Label: string?,
	Icon: string,
	Color: Color3,
	LayoutOrder: number?,
	Parent: Instance,
}): TextButton
	local button = UIHelpers.create("TextButton", {
		Name = config.Name,
		Size = UDim2.fromScale(1, 0.19), -- relative to the nav column
		BackgroundColor3 = config.Color,
		AutoButtonColor = false,
		Text = "",
		TextSize = 0,
		LayoutOrder = config.LayoutOrder or 1,
		Parent = config.Parent,
	}, {
		UIHelpers.create("UIAspectRatioConstraint", {
			AspectRatio = 0.92, -- slightly taller than wide
			AspectType = Enum.AspectType.FitWithinMaxSize,
		}),
		UIHelpers.create("UISizeConstraint", {
			MinSize = Vector2.new(64, 70),
			MaxSize = Vector2.new(108, 117),
		}),
		UIHelpers.corner(16),
		UIHelpers.boldStroke(3),
		UIHelpers.shadow(),
	})

	UIHelpers.tagStudSurface(button)
	button:SetAttribute("PanelName", config.Name)

	UIHelpers.create("TextLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.07, 0),
		Size = UDim2.new(0.8, 0, 0.5, 0),
		BackgroundTransparency = 1,
		Text = config.Icon,
		TextScaled = true,
		Font = Theme.Fonts.Body,
		ZIndex = 2,
		Parent = button,
	})

	UIHelpers.create("TextLabel", {
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.94, 0),
		Size = UDim2.new(0.92, 0, 0.3, 0),
		BackgroundTransparency = 1,
		Text = config.Label or config.Name,
		TextColor3 = Theme.Colors.TextLight,
		TextScaled = true,
		TextWrapped = true,
		Font = Theme.Fonts.Header,
		TextStrokeTransparency = 0.4,
		TextStrokeColor3 = Theme.Colors.Outline,
		ZIndex = 2,
		Parent = button,
	})

	return button
end

--[[
	Bottom-left stat chip (e.g. Money, Strength): themed icon + live value.
	Carries a "StatName" attribute; MainHUDScript keeps the Value label in sync
	with player.leaderstats[StatName]. Width auto-sizes to the value text.
]]
function UIHelpers.makeStatChip(config: {
	Name: string,
	Icon: string?,
	IconImage: string?,
	Color: Color3,
	LayoutOrder: number?,
	Parent: Instance,
}): Frame
	local chip = UIHelpers.create("Frame", {
		Name = config.Name,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 46),
		BackgroundColor3 = config.Color,
		BorderSizePixel = 0,
		LayoutOrder = config.LayoutOrder or 1,
		Parent = config.Parent,
	}, {
		UIHelpers.corner(14),
		UIHelpers.boldStroke(3),
		UIHelpers.shadow(),
		UIHelpers.padding(0, 0, 10, 14),
	})

	UIHelpers.tagStudSurface(chip)
	chip:SetAttribute("StatName", config.Name)

	if config.IconImage then
		UIHelpers.create("ImageLabel", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			BackgroundTransparency = 1,
			Image = config.IconImage,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 2,
			Parent = chip,
		})
	else
		UIHelpers.create("TextLabel", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			BackgroundTransparency = 1,
			Text = config.Icon or "❓",
			TextScaled = true,
			Font = Theme.Fonts.Body,
			ZIndex = 2,
			Parent = chip,
		})
	end

	UIHelpers.create("TextLabel", {
		Name = "Value",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 36, 0.5, 0),
		Size = UDim2.new(0, 0, 0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = "0",
		TextColor3 = Theme.Colors.TextLight,
		TextSize = 20,
		Font = Theme.Fonts.Header,
		TextStrokeTransparency = 0.4,
		TextStrokeColor3 = Theme.Colors.Outline,
		ZIndex = 2,
		Parent = chip,
	})

	return chip
end

function UIHelpers.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return UIHelpers.create("UIStroke", {
		Color = color or Theme.Colors.Outline,
		Thickness = thickness or Theme.Sizes.Stroke,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UIHelpers.boldStroke(thickness: number?): UIStroke
	return UIHelpers.stroke(Theme.Colors.Outline, thickness or Theme.Sizes.Outline, 0)
end

-- Chunky offset shadow for that blocky GUI look
function UIHelpers.shadow(): UIStroke
	return UIHelpers.create("UIStroke", {
		Color = Theme.Colors.Shadow,
		Thickness = 5,
		Transparency = 0.55,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Embeds circular Lego-style studs on a surface
function UIHelpers.addStuds(parent: GuiObject, baseColor: Color3?)
	local color = baseColor or Theme.Colors.Primary
	local studColor = color:Lerp(Color3.new(1, 1, 1), 0.35)
	local zIndex = parent.ZIndex

	local layer = UIHelpers.create("Frame", {
		Name = "StudLayer",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = zIndex,
		Parent = parent,
	})

	local studSize = Theme.Sizes.StudSize
	local positions = {
		{0.18, 0.18}, {0.5, 0.14}, {0.82, 0.18},
		{0.18, 0.5}, {0.5, 0.5}, {0.82, 0.5},
		{0.18, 0.82}, {0.5, 0.86}, {0.82, 0.82},
	}

	for i, pos in positions do
		UIHelpers.create("Frame", {
			Name = "Stud" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(pos[1], pos[2]),
			Size = UDim2.fromOffset(studSize, studSize),
			BackgroundColor3 = studColor,
			BorderSizePixel = 0,
			ZIndex = zIndex + 1,
			Parent = layer,
		}, {
			UIHelpers.create("UICorner", {CornerRadius = UDim.new(1, 0)}),
			UIHelpers.create("UIStroke", {
				Color = Theme.Colors.Outline,
				Thickness = 1,
				Transparency = 0.25,
			}),
		})
	end

	return layer
end

-- Rounded stud-textured icon button (used for left-side nav)
function UIHelpers.makeIconButton(config: {
	Name: string,
	Position: UDim2,
	Size: UDim2?,
	Icon: string?,
	IconImage: string?,
	Color: Color3,
	Parent: Instance,
	}): TextButton
	local size = config.Size or UDim2.fromOffset(72, 72)
	local button = UIHelpers.create("TextButton", {
		Name = config.Name,
		Position = config.Position,
		Size = size,
		BackgroundColor3 = config.Color,
		AutoButtonColor = false,
		Text = "",
		TextSize = 0,
		Parent = config.Parent,
	}, {
		UIHelpers.corner(16),
		UIHelpers.boldStroke(3),
		UIHelpers.shadow(),
	})

	UIHelpers.addStuds(button, config.Color)

	if config.IconImage then
		UIHelpers.create("ImageLabel", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.62, 0.62),
			BackgroundTransparency = 1,
			Image = config.IconImage,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = button.ZIndex + 2,
			Parent = button,
		})
	elseif config.Icon then
		UIHelpers.create("TextLabel", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = config.Icon,
			TextSize = 34,
			Font = Theme.Fonts.Body,
			ZIndex = button.ZIndex + 2,
			Parent = button,
		})
	end

	return button
end

-- Stud-textured panel surface (money bar, cards, etc.)
function UIHelpers.makeStudFrame(props: {[string]: any}, children: {Instance}?): Frame
	local bg = props.BackgroundColor3 or Theme.Colors.Panel
	local frame = UIHelpers.create("Frame", props, children)
	if not frame:FindFirstChild("StudLayer") then
		UIHelpers.addStuds(frame, bg)
	end
	if not frame:FindFirstChild("Outline") then
		local outline = UIHelpers.boldStroke(3)
		outline.Name = "Outline"
		outline.Parent = frame
	end
	if not frame:FindFirstChildOfClass("UICorner") then
		UIHelpers.corner(Theme.Sizes.Corner).Parent = frame
	end
	return frame
end

function UIHelpers.padding(top: number?, bottom: number?, left: number?, right: number?): UIPadding
	return UIHelpers.create("UIPadding", {
		PaddingTop = UDim.new(0, top or 0),
		PaddingBottom = UDim.new(0, bottom or 0),
		PaddingLeft = UDim.new(0, left or 0),
		PaddingRight = UDim.new(0, right or 0),
	})
end

-- 1234 -> "1.2K", 5600000 -> "5.6M" (keeps the money display compact for big numbers)
function UIHelpers.formatNumber(value: number): string
	value = math.floor(value)
	if value >= 1_000_000_000 then
		return string.format("%.1fB", value / 1_000_000_000)
	elseif value >= 1_000_000 then
		return string.format("%.1fM", value / 1_000_000)
	elseif value >= 10_000 then
		return string.format("%.1fK", value / 1000)
	end
	return tostring(value)
end

--[[
	Builds a standard centered panel: dark overlay, rounded body, colored header,
	title, and close button.
	Returns: panel (CanvasGroup), content (Frame), closeButton (TextButton), overlay (Frame)
--]]
function UIHelpers.makePanel(screenGui: ScreenGui, title: string, widthScale: number?, heightScale: number?): (CanvasGroup, Frame, TextButton, Frame)
	local overlay = UIHelpers.create("Frame", {
		Name = "Overlay",
		BackgroundColor3 = Theme.Colors.Overlay,
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = screenGui,
	})

	local panel = UIHelpers.create("CanvasGroup", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(widthScale or 0.72, heightScale or 0.72),
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = false,
		Parent = screenGui,
	}, {
		UIHelpers.corner(18),
		UIHelpers.boldStroke(3),
		UIHelpers.shadow(),
		UIHelpers.create("UISizeConstraint", {
			MinSize = Vector2.new(320, 280),
			MaxSize = Vector2.new(900, 620),
		}),
	})

	local header = UIHelpers.create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = Theme.Colors.PanelHeader,
		BorderSizePixel = 0,
		Parent = panel,
	}, {UIHelpers.corner(18), UIHelpers.boldStroke(3)})

	UIHelpers.addStuds(header, Theme.Colors.PanelHeader)

	-- Square off the header's bottom corners
	UIHelpers.create("Frame", {
		Name = "HeaderFill",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundColor3 = Theme.Colors.PanelHeader,
		BorderSizePixel = 0,
		Parent = header,
	})

	UIHelpers.create("TextLabel", {
		Name = "Title",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.04, 0, 0.5, 0),
		Size = UDim2.new(0.6, 0, 0.55, 0),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = Theme.Colors.TextLight,
		Font = Theme.Fonts.Header,
		TextSize = 26,
		TextStrokeTransparency = 0.35,
		TextStrokeColor3 = Theme.Colors.Outline,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})

	local closeButton = UIHelpers.create("TextButton", {
		Name = "CloseButton",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0.96, 0, 0.5, 0),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Theme.Colors.Danger,
		AutoButtonColor = false,
		Text = "✕",
		TextColor3 = Theme.Colors.TextLight,
		Font = Theme.Fonts.Header,
		TextSize = 18,
		Parent = header,
	}, {UIHelpers.corner(10), UIHelpers.boldStroke(2)})

	local content = UIHelpers.create("Frame", {
		Name = "Content",
		Position = UDim2.new(0.04, 0, 0, 68),
		Size = UDim2.new(0.92, 0, 1, -84),
		BackgroundTransparency = 1,
		Parent = panel,
	})

	return panel, content, closeButton, overlay
end

--[[
	Builds a horizontal tab bar (e.g. "Rocks" / "Pets").
	Returns a table: { buttons = {...}, select = (index) -> (), container = Frame }
--]]
function UIHelpers.makeTabs(parent: Instance, tabNames: {string}, onSelect: ((number, string) -> ())?): {[string]: any}
	local container = UIHelpers.create("Frame", {
		Name = "Tabs",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		UIHelpers.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})

	local buttons = {}

	local function select(index: number)
		for i, button in buttons do
			local isSelected = (i == index)
			button.BackgroundColor3 = isSelected and Theme.Colors.Primary or Theme.Colors.Slot
			button.TextColor3 = isSelected and Theme.Colors.TextLight or Theme.Colors.Text
			local stroke = button:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Thickness = isSelected and 3 or 2
			end
		end
		if onSelect then
			onSelect(index, tabNames[index])
		end
	end

	local tabWidth = math.max(1 / #tabNames - 0.04, 0.2)
	for i, name in tabNames do
		local button = UIHelpers.create("TextButton", {
			Name = name,
			Size = UDim2.new(tabWidth, 0, 0.8, 0),
			BackgroundColor3 = Theme.Colors.Slot,
			AutoButtonColor = false,
			Text = name,
			TextColor3 = Theme.Colors.Text,
			Font = Theme.Fonts.Body,
			TextSize = 16,
			LayoutOrder = i,
			Parent = container,
		}, {UIHelpers.corner(12), UIHelpers.boldStroke(2)})
		UIHelpers.addStuds(button, Theme.Colors.Slot)
		buttons[i] = button
		button.MouseButton1Click:Connect(function()
			select(i)
		end)
	end

	select(1)
	return {buttons = buttons, select = select, container = container}
end

--[[
	Builds a scrollable item grid. Returns the ScrollingFrame.
	cellSize example: UDim2.fromOffset(150, 180)
--]]
function UIHelpers.makeScrollGrid(parent: Instance, cellSize: UDim2, topOffset: number?): ScrollingFrame
	local scroll = UIHelpers.create("ScrollingFrame", {
		Name = "ItemGrid",
		Position = UDim2.new(0, 0, 0, topOffset or 52),
		Size = UDim2.new(1, 0, 1, -(topOffset or 52)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.Stroke,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = parent,
	})

	UIHelpers.create("UIGridLayout", {
		CellSize = cellSize,
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = scroll,
	})

	return scroll
end

--[[
	Builds the shared base of an item slot: rarity-tinted icon bubble, name, rarity label.
	The root is a TextButton so it is clickable. Panel scripts add their own extras
	(quantity badges, buy buttons, discovered states) on top.
	Returns: slot (TextButton), iconBubble (Frame)
--]]
function UIHelpers.makeItemSlot(item: {[string]: any}): (TextButton, Frame)
	local rarityColor = Theme.RarityColors[item.Rarity] or Theme.RarityColors.Common

	local slot = UIHelpers.create("TextButton", {
		Name = item.Name,
		BackgroundColor3 = Theme.Colors.Slot,
		AutoButtonColor = false,
		Text = "",
		TextSize = 0,
	}, {
		UIHelpers.corner(14),
		UIHelpers.boldStroke(3),
	})

	UIHelpers.addStuds(slot, Theme.Colors.Slot)

	local iconBubble = UIHelpers.create("Frame", {
		Name = "IconBubble",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(62, 62),
		BackgroundColor3 = rarityColor:Lerp(Color3.new(1, 1, 1), 0.72),
		BorderSizePixel = 0,
		Parent = slot,
	}, {UIHelpers.create("UICorner", {CornerRadius = UDim.new(1, 0)})})

	UIHelpers.create("TextLabel", {
		Name = "Icon",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = item.Icon or "❓",
		TextSize = 32,
		Font = Theme.Fonts.Body,
		Parent = iconBubble,
	})

	UIHelpers.create("TextLabel", {
		Name = "ItemName",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 82),
		Size = UDim2.new(0.92, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = item.Name,
		TextColor3 = Theme.Colors.Text,
		Font = Theme.Fonts.Body,
		TextSize = 15,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = slot,
	})

	UIHelpers.create("TextLabel", {
		Name = "Rarity",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104),
		Size = UDim2.new(0.92, 0, 0, 14),
		BackgroundTransparency = 1,
		Text = item.Rarity,
		TextColor3 = rarityColor,
		Font = Theme.Fonts.Sub,
		TextSize = 13,
		Parent = slot,
	})

	return slot, iconBubble
end

return UIHelpers
