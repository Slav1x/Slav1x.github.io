-- Rainbow "wave" looping around the shop button's outline stroke
local RunService = game:GetService("RunService")

local button = script.Parent
local shadow = button:FindFirstChild("shop shadow")
if not shadow then return end

local stroke = shadow:FindFirstChildOfClass("UIStroke")
if not stroke then return end

-- The gradient tints the stroke's base color, so it must be white (black would render black)
stroke.Color = Color3.new(1, 1, 1)

-- Use (or create) a gradient on the stroke itself, which colors the outline
local gradient = stroke:FindFirstChildOfClass("UIGradient")
if not gradient then
	gradient = Instance.new("UIGradient")
	gradient.Parent = stroke
end

-- Rainbow that starts and ends on the same color so the loop is seamless
local rainbow = {}
for i = 0, 6 do
	table.insert(rainbow, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)))
end
gradient.Color = ColorSequence.new(rainbow)

local SPEED = 90 -- degrees per second (higher = faster); one full trip around = 360 / SPEED seconds

RunService.Heartbeat:Connect(function(dt)
	-- Rotate the gradient continuously in one direction so the colors
	-- travel around the outline like a wave circling the button
	gradient.Rotation = (gradient.Rotation + SPEED * dt) % 360
end)
