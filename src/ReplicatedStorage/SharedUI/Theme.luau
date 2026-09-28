--!strict
--[[
	Theme
	Stud / blocky Roblox UI palette — bold outlines, vibrant colors,
	chunky cartoon type. Change values here to restyle the whole game UI.
--]]

local Theme = {}

Theme.Colors = {
	-- Surfaces
	Panel = Color3.fromRGB(255, 255, 255),
	PanelHeader = Color3.fromRGB(0, 170, 255),
	Slot = Color3.fromRGB(235, 245, 255),
	SlotDark = Color3.fromRGB(45, 55, 72),

	-- Brand + nav button colors (slop-game variety)
	Primary = Color3.fromRGB(0, 170, 255),
	PrimaryDark = Color3.fromRGB(0, 130, 210),
	Secondary = Color3.fromRGB(255, 159, 64),
	Accent = Color3.fromRGB(76, 217, 100),
	Danger = Color3.fromRGB(255, 82, 82),
	Purple = Color3.fromRGB(175, 82, 222),
	Pink = Color3.fromRGB(255, 95, 150),
	Yellow = Color3.fromRGB(255, 214, 64),

	-- Text
	Text = Color3.fromRGB(20, 20, 20),
	TextLight = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(110, 120, 140),

	-- Stud / outline
	Outline = Color3.fromRGB(0, 0, 0),
	Stroke = Color3.fromRGB(0, 0, 0),
	StudBump = Color3.fromRGB(255, 255, 255),
	Overlay = Color3.fromRGB(15, 20, 35),
	Shadow = Color3.fromRGB(0, 0, 0),
}

-- Rarity colors, shared by Inventory / Shop / Index
Theme.RarityColors = {
	Common = Color3.fromRGB(165, 176, 194),
	Uncommon = Color3.fromRGB(94, 201, 98),
	Rare = Color3.fromRGB(66, 148, 255),
	Epic = Color3.fromRGB(171, 104, 255),
	Legendary = Color3.fromRGB(255, 189, 62),
}

Theme.Fonts = {
	Header = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamBlack,
	Sub = Enum.Font.GothamBold,
}

Theme.Icons = {
	MoneyStack = "rbxassetid://119196652533935",
}

Theme.Sizes = {
	Corner = 16,
	CornerSmall = 10,
	Stroke = 3,
	Outline = 3,
	StudSize = 9,
}

return Theme
