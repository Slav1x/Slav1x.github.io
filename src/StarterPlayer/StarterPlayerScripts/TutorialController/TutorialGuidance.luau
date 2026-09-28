--!strict
--[[
	TutorialGuidance (client)

	Reusable pointers. Every pointer takes a *resolver* (a GuiObject, an
	Instance, a Vector3 or a function returning one) and re-resolves it every
	frame, so it keeps tracking its target through resizes, layout shifts,
	menus opening, respawns and streaming.

	  guidance:PointToGui(target, {label?, side?, swatch?})   bouncing arrow + bubble
	  guidance:HighlightGui(target, {padding?, spotlight?, swatch?})  ring, ripples, sparkles
	  guidance:PointToWorld(target, {...})                    see TutorialWorldMarkers
	  guidance:HighlightWorld(target, {...})
	  guidance:ClearGuidance()                                removes everything

	Each call returns a handle with :Destroy(); ClearGuidance destroys all.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent:WaitForChild("TutorialTheme"))

local new = Theme.new
local player = Players.LocalPlayer

export type Handle = {Destroy: (any) -> ()}
type Item = {update: (number) -> (), destroy: () -> ()}

local Guidance = {}
Guidance.__index = Guidance

-- ============================================================================
-- Screen geometry
-- ============================================================================

local function resolveGui(target: any): GuiObject?
	local value = if type(target) == "function" then target() else target
	if typeof(value) == "Instance" and value:IsA("GuiObject") and value.Parent then
		return value
	end
	return nil
end

-- Visible on screen right now? Honours Visible, CanvasGroup fades and
-- scrolling-frame clipping. Returns AbsolutePosition space (below top bar).
local function screenRect(object: GuiObject): (Vector2?, Vector2?)
	local size = object.AbsoluteSize
	if size.X < 2 or size.Y < 2 then return nil, nil end
	local position = object.AbsolutePosition
	local center = position + size / 2
	local node: Instance? = object
	local screen: ScreenGui? = nil
	while node do
		if node:IsA("ScreenGui") then
			screen = node
			break
		elseif node:IsA("LayerCollector") then
			return nil, nil
		end
		if node:IsA("GuiObject") then
			if not node.Visible then return nil, nil end
			if node:IsA("CanvasGroup") and node.GroupTransparency > .85 then return nil, nil end
			if node ~= object and node:IsA("ScrollingFrame") then
				local clipPos, clipSize = node.AbsolutePosition, node.AbsoluteSize
				if center.X < clipPos.X or center.Y < clipPos.Y or center.X > clipPos.X + clipSize.X
					or center.Y > clipPos.Y + clipSize.Y then
					return nil, nil
				end
			end
		end
		node = node.Parent
	end
	if not screen or not screen.Enabled or not screen:IsDescendantOf(player) then return nil, nil end
	return position, size
end
Guidance.screenRect = screenRect
Guidance.resolveGui = resolveGui

local function cornerRadiusFor(object: GuiObject, size: Vector2): number
	local corner = object:FindFirstChildOfClass("UICorner")
	if corner then
		return math.min(corner.CornerRadius.Offset + corner.CornerRadius.Scale * math.min(size.X, size.Y), math.min(size.X, size.Y) / 2)
	end
	return 14
end

-- ============================================================================
-- Guidance object
-- ============================================================================

function Guidance.new(layer: Instance, world: any?)
	local self = setmetatable({}, Guidance) :: any
	self.layer = layer
	self.world = world
	self.items = {} :: {Item}
	self.clock = 0
	self.connection = nil
	return self
end

function Guidance:_add(item: Item): Handle
	table.insert(self.items, item)
	if not self.connection then
		self.connection = RunService.RenderStepped:Connect(function(dt)
			self.clock += dt
			for _, entry in self.items do
				local ok, err = pcall(entry.update, dt)
				if not ok then warn("[TutorialGuidance] " .. tostring(err)) end
			end
		end)
	end
	local handle = {}
	function handle.Destroy(_: any)
		local index = table.find(self.items, item)
		if index then
			table.remove(self.items, index)
			item.destroy()
		end
		if #self.items == 0 and self.connection then
			self.connection:Disconnect()
			self.connection = nil
		end
	end
	return handle
end

-- PointToGui: the Figma arrow, bouncing with squash & stretch toward the
-- target, plus a sticker bubble behind it on the side with the most room.
function Guidance:PointToGui(target: any, options: {label: string?, side: string?, swatch: string?}?): Handle
	local opts = options or {}
	local arrow = new("ImageLabel", {Name = "TutorialArrow", AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(72, 72),
		BackgroundTransparency = 1, Image = Theme.Images.Arrow, Visible = false, ZIndex = 22, Parent = self.layer})
	local bubble = if opts.label then Theme.bubble(self.layer, opts.label, opts.swatch, 24) else nil
	if bubble then bubble.Visible = false end
	local bubbleScale = if bubble then new("UIScale", {Parent = bubble}) else nil
	local shownAt: number? = nil

	local function update(_dt: number)
		local object = resolveGui(target)
		local position, size = nil, nil
		if object then position, size = screenRect(object) end
		if position then position -= self.layer.AbsolutePosition end
		if not position or not size then
			arrow.Visible = false
			if bubble then bubble.Visible = false end
			shownAt = nil
			return
		end
		local camera = workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local scale = Theme.viewScale()
		local center = position + size / 2

		local side = opts.side
		if not side or side == "auto" then
			if center.X < viewport.X * .22 then side = "right"
			elseif center.X > viewport.X * .78 then side = "left"
			elseif center.Y > viewport.Y * .5 then side = "top"
			else side = "bottom" end
		end
		-- direction: unit vector from arrow toward the target
		local direction, edge, rotation
		if side == "right" then
			direction, edge, rotation = Vector2.new(-1, 0), Vector2.new(position.X + size.X, center.Y), 90
		elseif side == "left" then
			direction, edge, rotation = Vector2.new(1, 0), Vector2.new(position.X, center.Y), -90
		elseif side == "bottom" then
			direction, edge, rotation = Vector2.new(0, -1), Vector2.new(center.X, position.Y + size.Y), 180
		else
			direction, edge, rotation = Vector2.new(0, 1), Vector2.new(center.X, position.Y), 0
		end

		local t = self.clock
		if not shownAt then shownAt = t end
		local intro = math.clamp((t - shownAt) / .35, 0, 1)
		local introEase = 1 - (1 - intro) ^ 3
		local calm = Theme.reducedMotion()
		-- Bounce: fast in, soft out, with squash on contact.
		local phase = (t * 1.6) % 1
		local bounce = if calm then .3 else (1 - math.abs(math.sin(phase * math.pi))) -- 0 at contact
		local arrowSize = 72 * scale
		local gap = (4 + bounce * 16) * scale + (1 - introEase) * 40 * scale
		local squash = if calm then 1 else 1 - math.clamp(.18 - bounce, 0, .18)
		local along = arrowSize * squash
		local across = arrowSize * (2 - squash)
		local arrowCenter = edge - direction * (gap + along / 2)
		arrow.Position = UDim2.fromOffset(arrowCenter.X, arrowCenter.Y)
		arrow.Size = UDim2.fromOffset(across, along)
		arrow.Rotation = rotation
		arrow.ImageTransparency = 1 - introEase
		arrow.Visible = true

		if bubble and bubbleScale then
			bubble.Visible = true
			bubbleScale.Scale = scale * (.6 + .4 * introEase)
			local bubbleSize = bubble.AbsoluteSize
			local reach = if direction.X ~= 0 then bubbleSize.X else bubbleSize.Y
			local bubbleCenter = arrowCenter - direction * (arrowSize * .5 + reach / 2 + 2 * scale)
			bubbleCenter = Vector2.new(
				math.clamp(bubbleCenter.X, bubbleSize.X / 2 + 8, viewport.X - bubbleSize.X / 2 - 8),
				math.clamp(bubbleCenter.Y, bubbleSize.Y / 2 + 8, viewport.Y - bubbleSize.Y / 2 - 8))
			bubble.Position = UDim2.fromOffset(bubbleCenter.X, bubbleCenter.Y)
		end
	end

	return self:_add({
		update = update,
		destroy = function()
			arrow:Destroy()
			if bubble then bubble:Destroy() end
		end,
	})
end

-- HighlightGui: outlined sun ring (ink under-stroke so it reads on any
-- background), water ripples expanding outward, two twinkling sparkles,
-- and an optional soft spotlight dimming everything else.
function Guidance:HighlightGui(target: any, options: {padding: number?, spotlight: boolean?, swatch: string?}?): Handle
	local opts = options or {}
	local tone = Theme.swatch(opts.swatch or "sun")
	local under = new("Frame", {Name = "TutorialHighlightInk", BackgroundTransparency = 1, Visible = false, ZIndex = 18,
		Parent = self.layer}, {Theme.corner(14)})
	local underStroke = Theme.stroke(Theme.Ink, 8)
	underStroke.Parent = under
	local ring = new("Frame", {Name = "TutorialHighlight", BackgroundTransparency = 1, Visible = false, ZIndex = 19,
		Parent = self.layer}, {Theme.corner(14)})
	local ringStroke = Theme.stroke(tone.top, 4)
	ringStroke.Parent = ring
	local ripples = Theme.ripples(self.layer, 2, tone.top, 17, 1.4, 22, 3)
	local sparkles = {}
	for index = 1, 2 do
		sparkles[index] = new("ImageLabel", {Name = "Sparkle", AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(22, 22),
			BackgroundTransparency = 1, Image = Theme.Images.Sparkle, Visible = false, ZIndex = 21, Parent = self.layer})
	end
	local shades = {}
	if opts.spotlight then
		for index = 1, 4 do
			shades[index] = new("Frame", {Name = "Shade", BackgroundColor3 = Theme.Ink, BackgroundTransparency = 1,
				BorderSizePixel = 0, ZIndex = 16, Parent = self.layer})
		end
	end
	local shownAt: number? = nil

	local function hide()
		ring.Visible = false
		under.Visible = false
		ripples.setVisible(false)
		for _, sparkle in sparkles do sparkle.Visible = false end
		for _, shade in shades do shade.Visible = false end
		shownAt = nil
	end

	local function update(_dt: number)
		local object = resolveGui(target)
		local position, size = nil, nil
		if object then position, size = screenRect(object) end
		if position then position -= self.layer.AbsolutePosition end
		if not position or not size or not object then hide() return end
		local t = self.clock
		if not shownAt then shownAt = t end
		local intro = math.clamp((t - shownAt) / .25, 0, 1)
		local scale = Theme.viewScale()
		local calm = Theme.reducedMotion()
		local pulse = if calm then .5 else math.sin(t * 5) * .5 + .5
		local pad = ((opts.padding or 6) + pulse * 2) * scale
		local radius = cornerRadiusFor(object, size) + pad
		local center = position + size / 2
		for _, frame in {ring, under} do
			frame.Visible = true
			frame.Position = UDim2.fromOffset(position.X - pad, position.Y - pad)
			frame.Size = UDim2.fromOffset(size.X + pad * 2, size.Y + pad * 2)
			local corner = frame:FindFirstChildOfClass("UICorner") :: UICorner
			corner.CornerRadius = UDim.new(0, radius)
		end
		ringStroke.Thickness = (4 + pulse * 1.5) * scale
		underStroke.Thickness = ringStroke.Thickness + 4 * scale
		ringStroke.Transparency = 1 - intro
		underStroke.Transparency = 1 - intro
		ripples.setVisible(true)
		ripples.step(center, size + Vector2.new(pad * 2, pad * 2), t, radius)

		if not calm then
			local corners = {position + Vector2.new(size.X + pad * .4, -pad * .4), position + Vector2.new(-pad * .4, size.Y + pad * .4)}
			for index, sparkle in sparkles do
				local twinkle = math.max(0, math.sin(t * 3 + index * 2.1))
				sparkle.Visible = true
				sparkle.Position = UDim2.fromOffset(corners[index].X, corners[index].Y)
				sparkle.Size = UDim2.fromOffset(26 * scale * twinkle, 26 * scale * twinkle)
				sparkle.Rotation = t * 60
			end
		end

		if #shades == 4 then
			local camera = workspace.CurrentCamera
			local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
			local x0, y0 = math.floor(position.X - pad), math.floor(position.Y - pad)
			local x1, y1 = math.ceil(position.X + size.X + pad), math.ceil(position.Y + size.Y + pad)
			local rects = {{0, 0, viewport.X, y0}, {0, y1, viewport.X, viewport.Y - y1}, {0, y0, x0, y1 - y0}, {x1, y0, viewport.X - x1, y1 - y0}}
			for index, rect in rects do
				local shade = shades[index]
				shade.Visible = true
				shade.Position = UDim2.fromOffset(rect[1], rect[2])
				shade.Size = UDim2.fromOffset(math.max(0, rect[3]), math.max(0, rect[4]))
				shade.BackgroundTransparency = 1 - .42 * intro
			end
		end
	end

	return self:_add({
		update = update,
		destroy = function()
			ring:Destroy()
			under:Destroy()
			ripples.destroy()
			for _, sparkle in sparkles do sparkle:Destroy() end
			for _, shade in shades do shade:Destroy() end
		end,
	})
end

-- World pointers are drawn by TutorialWorldMarkers but owned here so a single
-- ClearGuidance() tears down every kind of pointer.
function Guidance:PointToWorld(target: any, options: {[string]: any}?): Handle
	assert(self.world, "TutorialGuidance needs TutorialWorldMarkers for world pointers")
	local marker = self.world:pointTo(target, options or {})
	return self:_add({update = function(dt) marker.update(dt) end, destroy = function() marker.destroy() end})
end

function Guidance:HighlightWorld(target: any, options: {[string]: any}?): Handle
	assert(self.world, "TutorialGuidance needs TutorialWorldMarkers for world highlights")
	local marker = self.world:highlight(target, options or {})
	return self:_add({update = function(dt) marker.update(dt) end, destroy = function() marker.destroy() end})
end

function Guidance:ClearGuidance()
	local items = self.items
	self.items = {}
	for _, item in items do
		local ok, err = pcall(item.destroy)
		if not ok then warn("[TutorialGuidance] cleanup failed: " .. tostring(err)) end
	end
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
end

return Guidance
