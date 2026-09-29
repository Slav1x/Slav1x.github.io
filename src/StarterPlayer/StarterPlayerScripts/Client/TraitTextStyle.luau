-- Trait names use text color alone for rarity; Legendary letters cycle through the spectrum.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Traits = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TraitCatalog"))

local Style = {}
local animated = {}

local function toHex(color)
	return string.format("#%02X%02X%02X",
		math.clamp(math.floor(color.R * 255 + .5), 0, 255),
		math.clamp(math.floor(color.G * 255 + .5), 0, 255),
		math.clamp(math.floor(color.B * 255 + .5), 0, 255))
end

local function escape(character)
	if character == "&" then return "&amp;" end
	if character == "<" then return "&lt;" end
	if character == ">" then return "&gt;" end
	return character
end

local function rainbowText(value, phase)
	local pieces = {}
	local index = 0
	for _, codepoint in utf8.codes(value) do
		local character = utf8.char(codepoint)
		index += 1
		if character == " " then
			table.insert(pieces, " ")
		else
			local hue = (phase + (index - 1) * .078) % 1
			local color = Color3.fromHSV(hue, .84, 1)
			table.insert(pieces, '<font color="' .. toHex(color) .. '">' .. escape(character) .. '</font>')
		end
	end
	return table.concat(pieces)
end

function Style.color(rarity)
	return Traits.RarityColors[rarity] or Color3.new(1, 1, 1)
end

function Style.clear(label)
	animated[label] = nil
	label.RichText = false
	label.TextColor3 = Color3.new(1, 1, 1)
end

function Style.apply(label, value, rarity)
	animated[label] = nil
	label.TextStrokeColor3 = Color3.fromRGB(9, 16, 33)
	label.TextStrokeTransparency = .55
	if rarity == "Legendary" then
		label.RichText = true
		label.TextColor3 = Color3.new(1, 1, 1)
		animated[label] = value
		label.Text = rainbowText(value, (os.clock() * .18) % 1)
	else
		label.RichText = false
		label.TextColor3 = Style.color(rarity)
		label.Text = value
	end
end

local elapsed = 0
RunService.RenderStepped:Connect(function(dt)
	elapsed += dt
	if elapsed < .05 then return end
	elapsed = 0
	local phase = (os.clock() * .18) % 1
	for label, value in animated do
		if label.Parent then
			label.Text = rainbowText(value, phase)
		else
			animated[label] = nil
		end
	end
end)

return Style