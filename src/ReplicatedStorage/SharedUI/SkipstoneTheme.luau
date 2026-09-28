--!strict
--[[
	SkipstoneTheme (client) -- "Skipstone" design language

	The tutorial's visual system in one place: palette, type, the art uploaded
	from the Figma file "Skip a Pebble! · Tutorial UI", and builders for the
	shared building blocks (sticker panels, medallions, 3D buttons, bubbles,
	keycaps, ripples). Every tutorial surface is assembled from these so the
	look stays consistent -- and so it can be promoted to the rest of the HUD
	later. Lives in SharedUI so the tutorial and gameplay HUDs share it.

	Principles
	  * White "sticker" surfaces + thick ink outline + chunky bottom lip: pops
	    against the game's blue lake and sky instead of blending into them.
	  * Ripples are the attention language (a stone landing on water).
	  * Show inputs (keycaps, mouse, tap) instead of describing them.
	  * Luckiest Guy for display type, Nunito Heavy for body.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local Theme = {}

-- ============================================================================
-- Tokens
-- ============================================================================

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

Theme.Ink = rgb(14, 34, 64)
Theme.InkSoft = rgb(58, 84, 122)
Theme.Paper = rgb(255, 255, 255)
Theme.PaperShade = rgb(226, 243, 255)
Theme.Mist = rgb(207, 226, 242)

export type Swatch = {top: Color3, bottom: Color3, base: Color3, deep: Color3, text: Color3}

local function swatch(top: Color3, bottom: Color3, deep: Color3, text: Color3?): Swatch
	return {top = top, bottom = bottom, base = top:Lerp(bottom, .5), deep = deep, text = text or bottom}
end

Theme.Swatches = {
	sun = swatch(rgb(255, 228, 92), rgb(255, 159, 28), rgb(214, 110, 8), rgb(232, 124, 12)),
	lime = swatch(rgb(155, 240, 106), rgb(34, 179, 74), rgb(20, 128, 52), rgb(24, 150, 60)),
	lagoon = swatch(rgb(94, 216, 255), rgb(18, 120, 224), rgb(10, 82, 170), rgb(18, 120, 224)),
	grape = swatch(rgb(208, 156, 255), rgb(122, 60, 230), rgb(84, 34, 170), rgb(122, 60, 230)),
	coral = swatch(rgb(255, 138, 128), rgb(232, 69, 79), rgb(168, 36, 52), rgb(214, 56, 68)),
	stone = swatch(rgb(236, 243, 250), rgb(186, 203, 220), rgb(120, 140, 162), rgb(58, 84, 122)),
} :: {[string]: Swatch}

function Theme.swatch(name: string?): Swatch
	return Theme.Swatches[name or "lagoon"] or Theme.Swatches.lagoon
end

Theme.Display = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
Theme.Body = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy)
Theme.BodyBold = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold)

-- Art from the Figma file (exported @2x) and a few game-owned textures.
Theme.Images = {
	Arrow = "rbxassetid://121706379575040",
	PebbleDone = "rbxassetid://91928562832419",
	PebbleCurrent = "rbxassetid://103274996128526",
	PebbleEmpty = "rbxassetid://126413034546313",
	Check = "rbxassetid://115680758298238",
	Throw = "rbxassetid://86622382754705",
	Summon = "rbxassetid://109944977409381",
	Cash = "rbxassetid://123412495108227",
	Upgrade = "rbxassetid://71194207481445",
	Rebirth = "rbxassetid://137450225631302",
	Splash = "rbxassetid://74741389100800",
	Tap = "rbxassetid://101359250597029",
	Mouse = "rbxassetid://119485822677709",
	Ribbon = "rbxassetid://129176669924527",
	Sunburst = "rbxassetid://81256487429873",
	Glow = "rbxassetid://85865306532212",
	Tail = "rbxassetid://103835749876590",
	Sparkle = "rbxassetid://82200827247092",
}

-- Medallion icon + colour per concept.
Theme.Icons = {
	summon = {image = "Summon", swatch = "grape"},
	throw = {image = "Throw", swatch = "lagoon"},
	cash = {image = "Cash", swatch = "lime"},
	upgrade = {image = "Upgrade", swatch = "sun"},
	rebirth = {image = "Rebirth", swatch = "grape"},
	splash = {image = "Splash", swatch = "lagoon"},
	check = {image = "Check", swatch = "lime"},
	dock = {image = "Throw", swatch = "lagoon"},
} :: {[string]: {image: string, swatch: string}}

function Theme.icon(name: string?): (string, Swatch)
	local entry = Theme.Icons[name or "throw"] or Theme.Icons.throw
	return Theme.Images[entry.image], Theme.swatch(entry.swatch)
end

-- ============================================================================
-- Primitive helpers
-- ============================================================================

function Theme.new(className: string, props: {[string]: any}?, children: {Instance}?): any
	local instance: any = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then parent = value else instance[key] = value end
		end
	end
	if children then
		for _, child in children do child.Parent = instance end
	end
	if parent then instance.Parent = parent end
	return instance
end
local new = Theme.new

function Theme.corner(radius: number?): UICorner
	return new("UICorner", {CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0)})
end

function Theme.stroke(color: Color3, thickness: number, transparency: number?): UIStroke
	return new("UIStroke", {Color = color, Thickness = thickness, Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round})
end

function Theme.textStroke(color: Color3, thickness: number): UIStroke
	return new("UIStroke", {Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round})
end

function Theme.gradient(top: Color3, bottom: Color3, rotation: number?): UIGradient
	return new("UIGradient", {Color = ColorSequence.new(top, bottom), Rotation = rotation or 90})
end

function Theme.padding(left: number, right: number?, top: number?, bottom: number?): UIPadding
	return new("UIPadding", {PaddingLeft = UDim.new(0, left), PaddingRight = UDim.new(0, right or left),
		PaddingTop = UDim.new(0, top or left), PaddingBottom = UDim.new(0, bottom or top or left)})
end

function Theme.reducedMotion(): boolean
	return player:GetAttribute("ReducedMotion") == true
end

function Theme.tween(object: Instance, seconds: number, props: {[string]: any}, style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?, delay: number?): Tween
	local animation = TweenService:Create(object, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out, 0, false, delay or 0), props)
	animation:Play()
	return animation
end

function Theme.hex(color: Color3): string
	return string.format("#%02X%02X%02X", math.floor(color.R * 255 + .5), math.floor(color.G * 255 + .5),
		math.floor(color.B * 255 + .5))
end

-- Rich-text highlight in a swatch's readable colour.
function Theme.hl(text: string, swatchName: string?): string
	return string.format('<font color="%s">%s</font>', Theme.hex(Theme.swatch(swatchName or "sun").text), text)
end

function Theme.label(props: {[string]: any}): TextLabel
	local defaults: {[string]: any} = {BackgroundTransparency = 1, TextColor3 = Theme.Ink, FontFace = Theme.Body,
		TextSize = 16, Text = ""}
	for key, value in props do defaults[key] = value end
	return new("TextLabel", defaults)
end

-- ============================================================================
-- Building blocks
-- ============================================================================

-- Sticker panel: ink lip underneath + white body with ink outline.
-- Returns (root, body). Put content inside `body`.
function Theme.sticker(parent: Instance?, radius: number, lip: number?, name: string?): (Frame, Frame)
	local root = new("Frame", {Name = name or "Sticker", BackgroundTransparency = 1, Parent = parent})
	new("Frame", {Name = "Lip", Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, lip or 6),
		BackgroundColor3 = Theme.Ink, BorderSizePixel = 0, ZIndex = 1, Parent = root}, {Theme.corner(radius)})
	local body = new("Frame", {Name = "Body", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, ZIndex = 2, Parent = root},
		{Theme.corner(radius), Theme.stroke(Theme.Ink, 4), Theme.gradient(Theme.Paper, Theme.PaperShade)})
	return root, body
end

-- Medallion: ink rim, white ring, gradient disc, gloss, icon.
export type Medallion = {root: Frame, disc: Frame, discGradient: UIGradient, icon: ImageLabel, scale: UIScale,
	setIcon: (string?, Swatch?) -> ()}

function Theme.medallion(parent: Instance?, size: number, zIndex: number?): Medallion
	local z = zIndex or 10
	local root = new("Frame", {Name = "Medallion", AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1, ZIndex = z, Parent = parent})
	local scale = new("UIScale", {Parent = root})
	local rim = math.max(3, math.floor(size * .05))
	new("Frame", {Name = "Lip", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(.5, 0, .5, math.floor(size * .06)),
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Ink, BorderSizePixel = 0, ZIndex = z, Parent = root},
		{Theme.corner()})
	local outer = new("Frame", {Name = "Rim", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Ink, BorderSizePixel = 0, ZIndex = z + 1, Parent = root},
		{Theme.corner()})
	local ring = new("Frame", {Name = "Ring", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
		Size = UDim2.new(1, -rim * 2, 1, -rim * 2), BackgroundColor3 = Theme.Paper, BorderSizePixel = 0, ZIndex = z + 2,
		Parent = outer}, {Theme.corner()})
	local disc = new("Frame", {Name = "Disc", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
		Size = UDim2.new(1, -rim * 2, 1, -rim * 2), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
		ZIndex = z + 3, Parent = ring}, {Theme.corner()})
	local discGradient = Theme.gradient(Theme.Swatches.lagoon.top, Theme.Swatches.lagoon.bottom)
	discGradient.Parent = disc
	new("Frame", {Name = "Gloss", AnchorPoint = Vector2.new(.5, 0), Position = UDim2.fromScale(.42, .1),
		Size = UDim2.fromScale(.56, .26), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = .62,
		Rotation = -14, BorderSizePixel = 0, ZIndex = z + 4, Parent = disc}, {Theme.corner()})
	local icon = new("ImageLabel", {Name = "Icon", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .52),
		Size = UDim2.fromScale(.86, .86), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = z + 5,
		Parent = ring})
	local medallion: Medallion = {root = root, disc = disc, discGradient = discGradient, icon = icon, scale = scale,
		setIcon = function() end}
	function medallion.setIcon(name: string?, override: Swatch?)
		local image, tone = Theme.icon(name)
		tone = override or tone
		icon.Image = image
		-- A pale tint of the concept colour so the full-colour icon art pops.
		discGradient.Color = ColorSequence.new(Theme.Paper, tone.top:Lerp(Theme.Paper, .35))
	end
	return medallion
end

-- Chunky 3D button: darker base, gradient face that presses down.
function Theme.button(parent: Instance?, text: string, swatchName: string, size: UDim2, zIndex: number?): TextButton
	local tone = Theme.swatch(swatchName)
	local z = zIndex or 10
	local base = new("TextButton", {Name = "Button", Size = size, BackgroundColor3 = tone.deep, AutoButtonColor = false,
		Text = "", BorderSizePixel = 0, ZIndex = z, Parent = parent}, {Theme.corner(12), Theme.stroke(Theme.Ink, 3)})
	local face = new("Frame", {Name = "Face", Size = UDim2.new(1, 0, 1, -6), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, ZIndex = z + 1, Parent = base}, {Theme.corner(12),
		Theme.gradient(tone.top, tone.bottom)})
	new("Frame", {Name = "Gloss", Position = UDim2.new(0, 8, 0, 4), Size = UDim2.new(1, -16, .3, 0),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = .6, BorderSizePixel = 0, ZIndex = z + 2,
		Parent = face}, {Theme.corner()})
	local label = Theme.label({Name = "Label", Size = UDim2.fromScale(1, 1), FontFace = Theme.Display, TextSize = 20,
		TextColor3 = Color3.new(1, 1, 1), Text = text, ZIndex = z + 3, Parent = face})
	Theme.textStroke(Theme.Ink, 2.2).Parent = label
	local scale = new("UIScale", {Parent = base})
	local pressed = false
	local function sync()
		face.Position = UDim2.fromOffset(0, if pressed then 4 else 0)
	end
	base.MouseEnter:Connect(function()
		if not Theme.reducedMotion() then Theme.tween(scale, .14, {Scale = 1.05}, Enum.EasingStyle.Back) end
	end)
	base.MouseLeave:Connect(function() pressed = false; sync(); Theme.tween(scale, .14, {Scale = 1}) end)
	base.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pressed = true; sync()
		end
	end)
	base.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pressed = false; sync()
		end
	end)
	return base
end

-- Speech-bubble label (white sticker pill, display font).
function Theme.bubble(parent: Instance?, text: string, swatchName: string?, zIndex: number?): Frame
	local z = zIndex or 20
	local tone = Theme.swatch(swatchName or "sun")
	local root = new("Frame", {Name = "Bubble", AnchorPoint = Vector2.new(.5, .5), AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, ZIndex = z, Parent = parent})
	local body = new("Frame", {Name = "Body", AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Theme.Paper, BorderSizePixel = 0, ZIndex = z + 1, Parent = root},
		{Theme.corner(), Theme.stroke(Theme.Ink, 3), Theme.padding(14, 14, 6, 6)})
	local accent = new("Frame", {Name = "Accent", AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, -8, .5, 0),
		Size = UDim2.fromOffset(10, 10), BackgroundColor3 = tone.bottom, BorderSizePixel = 0, ZIndex = z + 2, Parent = body},
		{Theme.corner(), Theme.stroke(Theme.Ink, 2)})
	accent.Visible = false
	Theme.label({Name = "Text", AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0),
		FontFace = Theme.Display, TextSize = 20, RichText = true, Text = text, TextColor3 = Theme.Ink, ZIndex = z + 2,
		Parent = body})
	return root
end

function Theme.setBubbleText(bubble: Instance, text: string)
	local label = bubble:FindFirstChild("Text", true)
	if label and label:IsA("TextLabel") and label.Text ~= text then label.Text = text end
end

-- Keycap: white key with ink outline and a bottom lip.
function Theme.keycap(parent: Instance?, key: string, zIndex: number?): Frame
	local z = zIndex or 10
	local width = math.max(30, 14 + #key * 12)
	local root = new("Frame", {Name = "Key_" .. key, Size = UDim2.fromOffset(width, 32), BackgroundTransparency = 1,
		ZIndex = z, Parent = parent})
	new("Frame", {Name = "Lip", Size = UDim2.new(1, 0, 1, -2), Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = Theme.Ink, BorderSizePixel = 0, ZIndex = z, Parent = root}, {Theme.corner(8)})
	local cap = new("Frame", {Name = "Cap", Size = UDim2.new(1, 0, 1, -4), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, ZIndex = z + 1, Parent = root},
		{Theme.corner(8), Theme.stroke(Theme.Ink, 2.5), Theme.gradient(Theme.Paper, Theme.Mist)})
	Theme.label({Name = "Glyph", Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 1), FontFace = Theme.Display,
		TextSize = 18, Text = key, ZIndex = z + 2, Parent = cap})
	return root
end

-- Expanding ripple ring (the attention language). Returns a stepper that
-- positions/animates rings given a centre, base size and time.
export type Ripples = {step: (Vector2, Vector2, number, number?) -> (), setVisible: (boolean) -> (), destroy: () -> ()}

function Theme.ripples(parent: Instance, count: number, color: Color3, zIndex: number, period: number?,
	growth: number?, thickness: number?): Ripples
	local rings = {}
	for index = 1, count do
		local ring = new("Frame", {Name = "Ripple", AnchorPoint = Vector2.new(.5, .5), BackgroundTransparency = 1,
			Visible = false, ZIndex = zIndex, Parent = parent}, {Theme.corner()})
		local stroke = Theme.stroke(color, thickness or 3)
		stroke.Parent = ring
		rings[index] = {frame = ring, stroke = stroke, corner = ring:FindFirstChildOfClass("UICorner")}
	end
	local cycle = period or 1.6
	local grow = growth or 36
	local ripples: Ripples = {step = function() end, setVisible = function() end, destroy = function() end}
	function ripples.step(center: Vector2, size: Vector2, clock: number, radius: number?)
		for index, ring in rings do
			local phase = ((clock / cycle) + (index - 1) / count) % 1
			local extra = phase * grow
			ring.frame.Position = UDim2.fromOffset(center.X, center.Y)
			ring.frame.Size = UDim2.fromOffset(size.X + extra * 2, size.Y + extra * 2)
			if radius and ring.corner then ring.corner.CornerRadius = UDim.new(0, radius + extra) end
			ring.stroke.Transparency = .15 + phase * .85
			ring.stroke.Thickness = (thickness or 3) * (1 - phase * .5)
		end
	end
	function ripples.setVisible(visible: boolean)
		for _, ring in rings do ring.frame.Visible = visible and not Theme.reducedMotion() end
	end
	function ripples.destroy()
		for _, ring in rings do ring.frame:Destroy() end
	end
	return ripples
end

-- Screen-size-aware scale shared by every tutorial surface.
function Theme.viewScale(): (number, boolean)
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local compact = viewport.Y < 520 or viewport.X < 760
	local scale = math.min(viewport.X / 1150, viewport.Y / 660)
	return math.clamp(scale, if compact then .7 else .62, 1), compact
end

-- ============================================================================
-- Interaction kit (front-page feel). Every effect respects ReducedMotion.
--   Theme.studs(parent, transparency?, tile?, z?, radius?)   subtle stud texture layer
--   Theme.glare(parent, opts?) -> {sweep, destroy}            diagonal glare sweeps
--   Theme.interact(button, opts?) -> disconnect               hover lift, press squash,
--                                                             release bounce, ripple, glare
--   Theme.ripple(parent, pointAbs?, color?)                   one click ripple
--   Theme.popIn(uiScale, from?, seconds?)                     open pop (Back)
--   Theme.stagger(items, fromScale?, step?)                   children land one by one
--   Theme.pulse(uiScale, amount?, period?) -> stop            idle attention pulse
--   Theme.countUp(label, from, to, seconds?, format?)         rolling numbers
--   Theme.burst(layer, center, count?, color?, distance?)     sparkle burst (layer coords)
--   Theme.skinButton(button, swatchName, opts?)               3D-ify an existing button in place
--   Theme.band(parent, swatchName, radius?)                   colored header band with gloss,
--                                                             studs and glare
-- ============================================================================

local RunService = game:GetService("RunService")

Theme.Assets = {
	Glare = "rbxassetid://71904840558679",
	Studs = "rbxassetid://6927295847",
}

local function motionOff(): boolean
	return Theme.reducedMotion()
end

function Theme.studs(parent: Instance, transparency: number?, tile: number?, zIndex: number?, radius: number?): ImageLabel
	local studs = new("ImageLabel", {Name = "Studs", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		Image = Theme.Assets.Studs, ImageColor3 = Color3.new(1, 1, 1), ImageTransparency = transparency or .86,
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(tile or 56, tile or 56), ZIndex = zIndex or 1,
		Parent = parent})
	-- UICorner on an ImageLabel clips the image itself, so studs follow rounded corners.
	if radius then Theme.corner(radius).Parent = studs end
	return studs
end

-- ---- Glare ------------------------------------------------------------------
-- One scheduler for every glare so idle cost stays flat however many exist.
type GlareEntry = {mask: CanvasGroup, image: ImageLabel, period: number, nextAt: number, width: number,
	duration: number, owner: GuiObject}
local glares: {GlareEntry} = {}
local glareLoop: RBXScriptConnection? = nil

local function sweepEntry(entry: GlareEntry)
	if motionOff() then return end
	local image = entry.image
	image.Position = UDim2.new(0, -entry.width, .5, 0)
	image.Visible = true
	local tween = Theme.tween(image, entry.duration, {Position = UDim2.new(1, entry.width, .5, 0)}, Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut)
	tween.Completed:Once(function() image.Visible = false end)
end

local function ensureGlareLoop()
	if glareLoop then return end
	glareLoop = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for index = #glares, 1, -1 do
			local entry = glares[index]
			if not entry.mask.Parent then
				table.remove(glares, index)
			elseif entry.period > 0 and now >= entry.nextAt then
				entry.nextAt = now + entry.period + math.random() * 1.2
				if entry.owner.Visible and entry.owner.AbsoluteSize.X > 0 then sweepEntry(entry) end
			end
		end
		if #glares == 0 and glareLoop then glareLoop:Disconnect(); glareLoop = nil end
	end)
end

export type Glare = {sweep: () -> (), destroy: () -> (), image: ImageLabel, mask: CanvasGroup}

-- opts: period (seconds between auto sweeps, 0 = manual only), radius (corner of the mask),
-- transparency, width (px of the glare streak), zIndex, duration
function Theme.glare(parent: GuiObject, opts: {[string]: any}?): Glare
	local o = opts or {}
	local mask = new("CanvasGroup", {Name = "GlareMask", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		ZIndex = o.zIndex or 50, Parent = parent})
	if o.radius then Theme.corner(o.radius).Parent = mask end
	mask:SetAttribute("ArcadeDecoration", true)
	local width = o.width or 140
	local image = new("ImageLabel", {Name = "DiagonalGlare", AnchorPoint = Vector2.new(.5, .5),
		Position = UDim2.new(0, -width, .5, 0), Size = UDim2.new(0, width, 2.2, 0), BackgroundTransparency = 1,
		Image = Theme.Assets.Glare, ImageTransparency = o.transparency or .45, Visible = false, ZIndex = o.zIndex or 50,
		Parent = mask})
	local entry: GlareEntry = {mask = mask, image = image, period = if o.period ~= nil then o.period else 5.5,
		nextAt = os.clock() + 1 + math.random() * 3, width = width, duration = o.duration or 1.1, owner = parent}
	table.insert(glares, entry)
	ensureGlareLoop()
	return {
		sweep = function() sweepEntry(entry) end,
		destroy = function() mask:Destroy() end,
		image = image,
		mask = mask,
	}
end

-- ---- Ripple -----------------------------------------------------------------
function Theme.ripple(parent: GuiObject, pointAbs: Vector2?, color: Color3?)
	if motionOff() then return end
	local size = parent.AbsoluteSize
	local local2 = if pointAbs then pointAbs - parent.AbsolutePosition else size / 2
	local reach = math.max(size.X, size.Y) * 1.4
	local ring = new("Frame", {Name = "Ripple", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(local2.X, local2.Y),
		Size = UDim2.fromOffset(8, 8), BackgroundColor3 = color or Color3.new(1, 1, 1), BackgroundTransparency = .55,
		BorderSizePixel = 0, ZIndex = 60, Parent = parent}, {Theme.corner()})
	ring:SetAttribute("ArcadeDecoration", true)
	Theme.tween(ring, .45, {Size = UDim2.fromOffset(reach, reach), BackgroundTransparency = 1}, Enum.EasingStyle.Quad)
	task.delay(.5, function() ring:Destroy() end)
end

-- ---- Interact -------------------------------------------------------------------
-- opts: scale (existing UIScale to drive; else one named "InteractScale" is made),
-- hover (1.06), press (.93), tilt (degrees on hover, 0 to disable), glare (Glare from Theme.glare
-- or true to add one), ripple (true), rippleColor, rest (function returning resting scale)
function Theme.interact(button: GuiButton, opts: {[string]: any}?): () -> ()
	local o = opts or {}
	local scale: UIScale = (o.scale or button:FindFirstChild("InteractScale") or new("UIScale", {Name = "InteractScale",
		Parent = button})) :: any
	local glare: Glare? = if o.glare == true then Theme.glare(button, {period = 0, radius = o.radius}) else o.glare
	local hoverScale, pressScale = o.hover or 1.06, o.press or .93
	local tilt = o.tilt or 0
	local hovering, pressing = false, false
	local function rest(): number return if o.rest then o.rest() else 1 end
	local function settle(style: Enum.EasingStyle?, seconds: number?)
		local target = rest() * (if pressing then pressScale elseif hovering then hoverScale else 1)
		if motionOff() then scale.Scale = rest() return end
		Theme.tween(scale, seconds or .14, {Scale = target}, style or Enum.EasingStyle.Back)
		if tilt ~= 0 then
			Theme.tween(button, .16, {Rotation = if hovering and not pressing then tilt else 0}, Enum.EasingStyle.Back)
		end
	end
	local connections = {
		button.MouseEnter:Connect(function()
			hovering = true
			settle()
			if glare then glare.sweep() end
		end),
		button.MouseLeave:Connect(function()
			hovering, pressing = false, false
			settle(Enum.EasingStyle.Quad)
		end),
		button.InputBegan:Connect(function(input)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
				pressing = true
				settle(Enum.EasingStyle.Quad, .07)
				if o.ripple ~= false then
					Theme.ripple(button, Vector2.new(input.Position.X, input.Position.Y) + (o.rippleOffset or Vector2.zero),
						o.rippleColor)
				end
			end
		end),
		button.InputEnded:Connect(function(input)
			local kind = input.UserInputType
			if pressing and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch) then
				pressing = false
				if motionOff() then settle() return end
				-- Release overshoots a touch then settles: feels springy.
				scale.Scale = rest() * (hovering and hoverScale or 1) * 1.06
				settle(Enum.EasingStyle.Back, .22)
			end
		end),
	}
	return function()
		for _, connection in connections do connection:Disconnect() end
	end
end

-- ---- Motion helpers ---------------------------------------------------------------
function Theme.popIn(scale: UIScale, from: number?, seconds: number?)
	local rest = (scale:GetAttribute("RestScale") :: number?) or 1
	if motionOff() then scale.Scale = rest return end
	scale.Scale = rest * (from or .82)
	Theme.tween(scale, seconds or .32, {Scale = rest}, Enum.EasingStyle.Back)
end

-- Items land one after another (each needs, or gets, a UIScale named "StaggerScale").
function Theme.stagger(items: {GuiObject}, fromScale: number?, step: number?)
	if motionOff() then return end
	for index, item in items do
		local s: UIScale = (item:FindFirstChild("StaggerScale") or new("UIScale", {Name = "StaggerScale", Parent = item})) :: any
		s.Scale = fromScale or .6
		Theme.tween(s, .34, {Scale = 1}, Enum.EasingStyle.Back, Enum.EasingDirection.Out, (index - 1) * (step or .045))
	end
end

function Theme.pulse(scale: UIScale, amount: number?, period: number?): () -> ()
	local alive = true
	task.spawn(function()
		local clock = 0
		while alive and scale.Parent do
			local dt = RunService.Heartbeat:Wait()
			clock += dt
			if not motionOff() then
				scale.Scale = 1 + (amount or .045) * (math.sin(clock * math.pi * 2 / (period or 1.4)) * .5 + .5)
			end
		end
	end)
	return function() alive = false; scale.Scale = 1 end
end

-- Rolling number. format(n) -> string; default groups thousands.
function Theme.countUp(label: TextLabel, from: number, to: number, seconds: number?, format: ((number) -> string)?)
	local fmt = format or function(n: number): string
		local whole = tostring(math.floor(math.max(n, 0) + .5))
		local grouped = string.reverse(string.gsub(string.reverse(whole), "(%d%d%d)", "%1,"))
		return (string.gsub(grouped, "^,", ""))
	end
	if motionOff() then label.Text = fmt(to) return end
	local token = (label:GetAttribute("CountToken") or 0) + 1
	label:SetAttribute("CountToken", token)
	task.spawn(function()
		local start = os.clock()
		local duration = seconds or .8
		while label.Parent and label:GetAttribute("CountToken") == token do
			local alpha = math.clamp((os.clock() - start) / duration, 0, 1)
			label.Text = fmt(from + (to - from) * (1 - (1 - alpha) ^ 3))
			if alpha >= 1 then break end
			RunService.RenderStepped:Wait()
		end
	end)
end

-- Sparkle burst. `layer` should be a full-screen frame; center is in that layer's coordinates.
function Theme.burst(layer: GuiObject, center: Vector2, count: number?, color: Color3?, distance: number?)
	if motionOff() then return end
	local n = count or 10
	for index = 1, n do
		local angle = (index / n) * math.pi * 2 + math.random() * .5
		local size = math.random(14, 26)
		local sparkle = new("ImageLabel", {AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(center.X, center.Y),
			Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, Image = Theme.Images.Sparkle,
			ImageColor3 = if index % 2 == 0 then (color or Theme.Swatches.sun.top) else Color3.new(1, 1, 1), ZIndex = 200,
			Parent = layer})
		local target = center + Vector2.new(math.cos(angle), math.sin(angle)) * ((distance or 90) * (.7 + math.random() * .4))
		Theme.tween(sparkle, .6, {Position = UDim2.fromOffset(target.X, target.Y), Rotation = 180, ImageTransparency = 1,
			Size = UDim2.fromOffset(size * .4, size * .4)}, Enum.EasingStyle.Quart)
		task.delay(.65, function() sparkle:Destroy() end)
	end
end

-- Colored header band: gradient, gloss strip, subtle studs, auto glare. Returns the band.
function Theme.band(parent: GuiObject, swatchName: string, radius: number?): Frame
	local tone = Theme.swatch(swatchName)
	radius = radius or 18
	local band = new("Frame", {Name = "Band", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, Parent = parent}, {Theme.corner(radius), Theme.gradient(tone.top, tone.bottom)})
	Theme.studs(band, .88, 48, band.ZIndex, radius)
	new("Frame", {Name = "Gloss", Position = UDim2.new(0, 14, 0, 6), Size = UDim2.new(1, -28, .22, 0),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = .72, BorderSizePixel = 0, ZIndex = band.ZIndex,
		Parent = band}, {Theme.corner()})
	Theme.glare(band, {radius = radius, period = 5.8, transparency = .5})
	return band
end

-- Make an existing TextButton/ImageButton a chunky 3D Skipstone button without renaming it
-- or touching its text/children. Adds: ink border stroke (only if it has none), lip, gloss,
-- gradient (only if it has none), glare mask, hover/press/ripple. Returns the interact disconnect.
-- opts: radius, lip (px), noGradient, scale (existing UIScale to drive), keepColor (don't set bg),
-- keepText (leave text on the button), font, textColor, textStroke, maxTextSize, hover, press, tilt, period
function Theme.skinButton(button: GuiButton, swatchName: string, opts: {[string]: any}?): () -> ()
	local o = opts or {}
	local tone = Theme.swatch(swatchName)
	local radius = o.radius or 14
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	if not o.keepColor then
		button.BackgroundColor3 = Color3.new(1, 1, 1)
		button.BackgroundTransparency = 0
	end
	local corner = button:FindFirstChildOfClass("UICorner") or new("UICorner", {Parent = button})
	corner.CornerRadius = UDim.new(0, radius)
	local hasBorder = false
	for _, child in button:GetChildren() do
		if child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
			child.Color, child.Thickness, child.Transparency = Theme.Ink, 3, 0
			hasBorder = true
		end
	end
	if not hasBorder then Theme.stroke(Theme.Ink, 3).Parent = button end
	if not o.noGradient and not button:FindFirstChildOfClass("UIGradient") then
		Theme.gradient(tone.top, tone.bottom).Parent = button
	end
	if not button:FindFirstChild("SkipLip") then
		local lip = new("Frame", {Name = "SkipLip", AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 0, 0, o.lip or 5),
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Ink, BorderSizePixel = 0,
			ZIndex = math.max(button.ZIndex - 1, 1), Parent = button.Parent}, {Theme.corner(radius)})
		lip:SetAttribute("ArcadeDecoration", true)
		-- Follow the button's geometry and visibility (controllers move/resize it).
		local function follow()
			lip.AnchorPoint = button.AnchorPoint
			lip.Size = button.Size
			lip.Position = button.Position + UDim2.fromOffset(0, o.lip or 5)
			lip.Visible = button.Visible
			lip.LayoutOrder = button.LayoutOrder
			lip.ZIndex = math.max(button.ZIndex - 1, 1)
		end
		follow()
		for _, property in {"AnchorPoint", "Size", "Position", "Visible", "ZIndex"} do
			button:GetPropertyChangedSignal(property):Connect(follow)
		end
		button.Destroying:Once(function() lip:Destroy() end)
		-- Inside a layout the lip would take a slot; skip it there.
		if button.Parent and button.Parent:FindFirstChildWhichIsA("UIGridStyleLayout") then lip:Destroy() end
	end
	if not button:FindFirstChild("SkipGloss") then
		local gloss = new("Frame", {Name = "SkipGloss", Position = UDim2.new(0, 8, 0, 4), Size = UDim2.new(1, -16, .26, 0),
			BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = .68, BorderSizePixel = 0,
			ZIndex = button.ZIndex, Parent = button}, {Theme.corner()})
		gloss:SetAttribute("ArcadeDecoration", true)
	end
	-- A UIGradient tints the button's own text, so text moves to a child caption that mirrors
	-- button.Text (controllers keep writing button.Text as before).
	if button:IsA("TextButton") and not o.keepText and not button:FindFirstChild("SkipCaption") then
		local textButton = button :: TextButton
		local caption = Theme.label({Name = "SkipCaption", Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 1),
			FontFace = o.font or Theme.Display, TextScaled = true, TextColor3 = o.textColor or Color3.new(1, 1, 1),
			Text = textButton.Text, RichText = textButton.RichText, ZIndex = button.ZIndex + 2, Parent = button})
		new("UITextSizeConstraint", {MinTextSize = 8, MaxTextSize = o.maxTextSize or math.max(textButton.TextSize, 14),
			Parent = caption})
		Theme.textStroke(Theme.Ink, o.textStroke or 2).Parent = caption
		caption:SetAttribute("ArcadeDecoration", true)
		textButton.TextTransparency = 1
		for _, child in textButton:GetChildren() do
			if child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then child.Enabled = false end
		end
		textButton:GetPropertyChangedSignal("Text"):Connect(function() caption.Text = textButton.Text end)
		textButton:GetPropertyChangedSignal("TextTransparency"):Connect(function()
			if textButton.TextTransparency < 1 then textButton.TextTransparency = 1 end
		end)
	end
	local glare = Theme.glare(button, {period = o.period or 0, radius = radius, width = 90})
	return Theme.interact(button, {scale = o.scale, glare = glare, hover = o.hover, press = o.press, tilt = o.tilt})
end

return Theme
