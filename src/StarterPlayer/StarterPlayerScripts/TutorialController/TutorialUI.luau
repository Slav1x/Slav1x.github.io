--!strict
--[[
	TutorialUI (client) -- Skipstone quest card, banners, dialog, confetti

	  TutorialUI.new(playerGui) -> ui
	  ui:showObjective(spec)       ShowObjective; animates only when spec.key changes
	  ui:completeObjective(text)   CompleteObjective; check stamp + sparkle burst
	  ui:hideObjective()
	  ui:banner(title, subtitle, swatch, seconds)
	  ui:confirm(title, body, yesText, noText, onYes)
	  ui:confetti(point, count, power)
	  ui.guidanceLayer             full-screen layer for pointers (TutorialGuidance)

	Anatomy of the quest card
	  [medallion]  [STEP 2/5 . o o O o o]              [SKIP]
	               TITLE IN LUCKIEST GUY
	               One short sentence of body copy.
	               [mouse] HOLD > RELEASE IN [GREEN]      <- input row
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent:WaitForChild("TutorialTheme"))
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("TutorialConfig"))

local new = Theme.new
local IMG = Theme.Images
local _player = Players.LocalPlayer

export type Chip = {label: string, value: string, swatch: string?}
export type InputToken = {kind: string, text: string?, swatch: string?}
export type ObjectiveSpec = {
	key: string,
	step: number?,
	title: string,
	body: string,
	icon: string?,
	accent: string?,
	chips: {Chip}?,
	inputs: {InputToken}?,
	loop: boolean?,
	button: {text: string, callback: () -> ()}?,
	timer: number?,
	skippable: boolean?,
	onSkip: (() -> ())?,
	placement: string?,
}

local TutorialUI = {}
TutorialUI.__index = TutorialUI

-- Layouts ignore a child's Rotation, so a rotated icon in a row needs a
-- plain holder frame. The arrow art points down; -90 turns it right.
local function rightArrow(parent: Instance, size: number, transparency: number, zIndex: number): Frame
	local holder = new("Frame", {Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, ZIndex = zIndex,
		Parent = parent})
	new("ImageLabel", {Size = UDim2.fromScale(1, 1), Rotation = -90, BackgroundTransparency = 1, Image = IMG.Arrow,
		ImageTransparency = transparency, ZIndex = zIndex, Parent = holder})
	return holder
end
TutorialUI.hex = Theme.hex

local CARD_W = 560
local PAD_L, PAD_T, PAD_R, PAD_B = 34, 30, 20, 26 -- canvas margin so overhangs are not clipped
local MEDALLION = 104
local TEXT_X = 118

-- ============================================================================
-- Construction
-- ============================================================================

function TutorialUI.new(playerGui: Instance)
	local self = setmetatable({}, TutorialUI) :: any

	local old = playerGui:FindFirstChild("TutorialUI")
	if old then old:Destroy() end
	local gui = new("ScreenGui", {Name = "TutorialUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 150,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui})
	self.gui = gui
	self.guidanceLayer = new("Frame", {Name = "Guidance", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		ZIndex = 1, Parent = gui})

	-- ---- Quest card -----------------------------------------------------
	local holder = new("Frame", {Name = "ObjectiveHolder", AnchorPoint = Vector2.new(.5, 0),
		Position = UDim2.new(.5, 0, 0, 90), Size = UDim2.fromOffset(CARD_W + PAD_L + PAD_R, 172),
		BackgroundTransparency = 1, Visible = false, ZIndex = 5, Parent = gui})
	self.holder = holder
	self.holderScale = new("UIScale", {Parent = holder})

	-- Soft halo + ripples sit outside the canvas so they can spill freely.
	self.halo = new("ImageLabel", {Name = "Halo", AnchorPoint = Vector2.new(.5, .5),
		Position = UDim2.fromOffset(PAD_L + 40, PAD_T + 50), Size = UDim2.fromOffset(190, 190), BackgroundTransparency = 1,
		Image = IMG.Glow, ImageTransparency = .45, ZIndex = 5, Parent = holder})

	local canvas = new("CanvasGroup", {Name = "Canvas", Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, ZIndex = 6, Parent = holder}, {Theme.padding(PAD_L, PAD_R, PAD_T, PAD_B)})
	self.canvas = canvas

	local card, body = Theme.sticker(canvas, 24, 7, "Card")
	-- Heights are set by hand from the content (see resize below): chained
	-- AutomaticSize frames grow but do not reliably shrink back.
	card.Size = UDim2.new(1, 0, 0, 116)
	card.ZIndex = 6
	body.Size = UDim2.fromScale(1, 1)
	Theme.padding(TEXT_X, 24, 24, 18).Parent = body
	self.card, self.cardBody = card, body
	self.cardStroke = body:FindFirstChildOfClass("UIStroke")

	-- The card's paper gradient ends in a pale band of the accent colour (a
	-- water line). Done in the gradient so it never affects auto-sizing.
	self.cardGradient = body:FindFirstChildOfClass("UIGradient")

	local content = new("Frame", {Name = "Content", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, ZIndex = 3, Parent = body},
		{new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})})
	self.content = content
	self.contentScale = nil
	local function resize()
		local scale = math.max(self.holderScale.Scale, .01)
		local bodyHeight = math.max(116, math.ceil(content.AbsoluteSize.Y / scale) + 24 + 18)
		card.Size = UDim2.new(1, 0, 0, bodyHeight)
		holder.Size = UDim2.fromOffset(CARD_W + PAD_L + PAD_R, bodyHeight + PAD_T + PAD_B)
	end
	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	self.holderScale:GetPropertyChangedSignal("Scale"):Connect(resize)
	self.title = Theme.label({Name = "Title", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 34), FontFace = Theme.Display,
		TextSize = 32, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Bottom,
		TextColor3 = Theme.Ink, ZIndex = 4, Parent = content})
	self.body = Theme.label({Name = "Body", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, TextSize = 18, RichText = true, TextWrapped = true, TextColor3 = Theme.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LineHeight = 1.05,
		ZIndex = 4, Parent = content})
	self.extras = new("Frame", {Name = "Extras", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 4, Parent = content},
		{new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})})
	local timerTrack = new("Frame", {Name = "Timer", LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = Theme.Mist, BorderSizePixel = 0, Visible = false, ZIndex = 4, Parent = content},
		{Theme.corner(), Theme.stroke(Theme.Ink, 2)})
	self.timerTrack = timerTrack
	self.timerFill = new("Frame", {Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, ZIndex = 5, Parent = timerTrack},
		{Theme.corner(), Theme.gradient(Theme.Swatches.sun.top, Theme.Swatches.sun.bottom, 0)})

	-- White flash overlay for completion.
	self.flash = new("Frame", {Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 9, Parent = card}, {Theme.corner(24)})

	-- Medallion (overhangs the card's left edge). Canvas children are laid
	-- out inside its UIPadding, so these offsets are card-relative.
	local medallion = Theme.medallion(canvas, MEDALLION, 12)
	medallion.root.Position = UDim2.fromOffset(40, 50)
	self.medallion = medallion

	-- Step tab with the skip trail: pebbles hop between slots on progress.
	local stepTab = new("Frame", {Name = "StepTab", Position = UDim2.fromOffset(TEXT_X - 6, -16),
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30), BackgroundColor3 = Theme.Ink,
		BorderSizePixel = 0, ZIndex = 14, Parent = canvas},
		{Theme.corner(), Theme.padding(12, 10, 0, 0), new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder})})
	self.stepTab = stepTab
	self.stepLabel = Theme.label({Name = "Step", LayoutOrder = 1, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30), FontFace = Theme.Display, TextSize = 16, TextColor3 = Color3.new(1, 1, 1),
		Text = "STEP 1/5", ZIndex = 15, Parent = stepTab})
	local trail = new("Frame", {Name = "Trail", LayoutOrder = 2, Size = UDim2.fromOffset(Config.TotalSteps * 24 - 4, 30),
		BackgroundTransparency = 1, ZIndex = 15, Parent = stepTab})
	self.trail = trail
	self.slots = {}
	for index = 1, Config.TotalSteps do
		local x = (index - 1) * 24 + 10
		self.slots[index] = new("ImageLabel", {Name = "Pebble" .. index, AnchorPoint = Vector2.new(.5, .5),
			Position = UDim2.fromOffset(x, 16), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1,
			Image = IMG.PebbleEmpty, ZIndex = 16, Parent = trail})
		if index < Config.TotalSteps then
			-- three dots on a little arc: the skip path.
			for dot = 1, 3 do
				local dx = x + 6 * dot
				local dy = 16 - math.sin(dot / 4 * math.pi) * 7
				new("Frame", {Name = "Dot", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(dx, dy),
					Size = UDim2.fromOffset(3, 3), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = .55,
					BorderSizePixel = 0, ZIndex = 15, Parent = trail}, {Theme.corner()})
			end
		end
	end
	self.hopper = new("ImageLabel", {Name = "Hopper", AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1, Image = IMG.PebbleCurrent, Visible = false, ZIndex = 17, Parent = trail})

	-- Skip tab (deliberately quiet: small, white, muted text).
	local skipRoot = new("Frame", {Name = "SkipTab", AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -22, 0, -14), Size = UDim2.fromOffset(64, 26), BackgroundTransparency = 1,
		ZIndex = 14, Parent = canvas})
	new("Frame", {Name = "Lip", Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 3), BackgroundColor3 = Theme.Ink,
		BorderSizePixel = 0, ZIndex = 14, Parent = skipRoot}, {Theme.corner()})
	local skip = new("TextButton", {Name = "Skip", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Paper,
		AutoButtonColor = false, Text = "SKIP", FontFace = Theme.Body, TextSize = 13, TextColor3 = Theme.InkSoft,
		BorderSizePixel = 0, ZIndex = 15, Parent = skipRoot}, {Theme.corner(), Theme.stroke(Theme.Ink, 2.5)})
	skip.MouseEnter:Connect(function() Theme.tween(skip, .1, {TextColor3 = Theme.Swatches.coral.text}) end)
	skip.MouseLeave:Connect(function() Theme.tween(skip, .1, {TextColor3 = Theme.InkSoft}) end)
	skip.Activated:Connect(function()
		local handler = self.onSkip
		if handler then handler() end
	end)
	self.skip = skipRoot

	-- Idle-life rings around the medallion (outside the canvas: can spill).
	self.medallionRipples = Theme.ripples(holder, 2, Color3.new(1, 1, 1), 5, 2.2, 34, 4)

	-- ---- Banner ----------------------------------------------------------
	local banner = new("Frame", {Name = "Banner", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .4),
		Size = UDim2.fromOffset(640, 320), BackgroundTransparency = 1, Visible = false, ZIndex = 30, Parent = gui})
	self.bannerFrame = banner
	self.bannerScale = new("UIScale", {Parent = banner})
	self.bannerBurst = new("ImageLabel", {Name = "Sunburst", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .42),
		Size = UDim2.fromOffset(620, 620), BackgroundTransparency = 1, Image = IMG.Sunburst, ImageTransparency = .2,
		ZIndex = 30, Parent = banner})
	self.bannerGlow = new("ImageLabel", {Name = "Glow", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .42),
		Size = UDim2.fromOffset(460, 300), BackgroundTransparency = 1, Image = IMG.Glow, ImageTransparency = .35,
		ZIndex = 31, Parent = banner})
	local ribbon = new("ImageLabel", {Name = "Ribbon", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .42),
		Size = UDim2.fromOffset(620, 174), BackgroundTransparency = 1, Image = IMG.Ribbon, ZIndex = 32, Parent = banner})
	self.ribbon = ribbon
	self.ribbonScale = new("UIScale", {Parent = ribbon})
	local bannerTitle = Theme.label({Name = "Title", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .44),
		Size = UDim2.fromScale(.74, .46), FontFace = Theme.Display, TextScaled = true, TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 34, Parent = ribbon})
	Theme.textStroke(Theme.Ink, 4).Parent = bannerTitle
	new("UITextSizeConstraint", {MaxTextSize = 50, MinTextSize = 18, Parent = bannerTitle})
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 240, 190)),
		Parent = bannerTitle})
	self.bannerTitle = bannerTitle
	local subPill = new("Frame", {Name = "Subtitle", AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, .42, 94),
		AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), BackgroundColor3 = Theme.Ink,
		BackgroundTransparency = .12, BorderSizePixel = 0, ZIndex = 33, Parent = banner},
		{Theme.corner(), Theme.padding(20, 20, 8, 9), new("UISizeConstraint", {MaxSize = Vector2.new(600, 200)})})
	self.bannerSubPill = subPill
	self.bannerSubtitle = Theme.label({Name = "Text", AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromOffset(540, 0),
		TextSize = 21, RichText = true, TextWrapped = true, TextColor3 = Color3.new(1, 1, 1), ZIndex = 34, Parent = subPill})
	self.bannerSparkles = {}
	for index, spec in {{-.36, .08, 46}, {.4, .1, 34}, {.3, .72, 28}} do
		self.bannerSparkles[index] = new("ImageLabel", {Name = "Sparkle", AnchorPoint = Vector2.new(.5, .5),
			Position = UDim2.fromScale(.5 + spec[1], spec[2]), Size = UDim2.fromOffset(spec[3], spec[3]),
			BackgroundTransparency = 1, Image = IMG.Sparkle, ImageTransparency = 1, ZIndex = 35, Parent = banner})
	end

	self.confettiLayer = new("Frame", {Name = "Confetti", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		ZIndex = 40, Parent = gui})
	self.confirmLayer = new("Frame", {Name = "ConfirmLayer", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		Visible = false, ZIndex = 50, Parent = gui})

	self.visible = false
	self.placement = "top"
	self.currentKey = nil
	self.token = 0
	self.step = nil
	self.placementY = 90
	self.uiScale = 1

	local function fit()
		local camera = workspace.CurrentCamera
		if not camera then return end
		local viewport = camera.ViewportSize
		local scale, compact = Theme.viewScale()
		scale = math.min(scale, (viewport.X - 16) / (CARD_W + PAD_L + PAD_R))
		self.holderScale.Scale = scale
		self.bannerScale.Scale = math.clamp(math.min(viewport.X / 900, viewport.Y / 560), .45, 1)
		self.uiScale = scale
		self.compact = compact
		local inset = GuiService:GetGuiInset().Y
		if self.placement == "bottom" then
			holder.AnchorPoint = Vector2.new(.5, 1)
			self.placementY = viewport.Y - (if compact then 92 else 138) * scale
		else
			holder.AnchorPoint = Vector2.new(.5, 0)
			-- Clears the top-centre Pebble Plaza button of the main HUD.
			self.placementY = inset + (if compact then 30 else 50) - PAD_T * scale
		end
		if not self.animating then holder.Position = UDim2.new(.5, 0, 0, self.placementY) end
	end
	self.fit = fit
	local cameraConnection: RBXScriptConnection? = nil
	local function watchCamera()
		if cameraConnection then cameraConnection:Disconnect() end
		local camera = workspace.CurrentCamera
		if camera then cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
		fit()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()

	-- Idle life: medallion bob + ripples + halo breathing, trail bounce, banner spin.
	local clock = 0
	RunService.RenderStepped:Connect(function(dt)
		clock += dt
		local calm = Theme.reducedMotion()
		if holder.Visible then
			local medallionCenter = Vector2.new(PAD_L + 40, PAD_T + 50)
			self.medallionRipples.step(medallionCenter, Vector2.new(MEDALLION, MEDALLION), clock)
			if not calm then
				self.medallion.icon.Rotation = math.sin(clock * 2.1) * 5
				self.medallion.icon.Position = UDim2.new(.5, 0, .52, math.sin(clock * 2.6) * 2)
				self.halo.ImageTransparency = .5 + math.sin(clock * 2) * .12
				local current = self.step and self.slots[self.step]
				if current and not self.hopper.Visible then
					local hop = math.max(0, math.sin(clock * 5))
					current.Position = UDim2.fromOffset((self.step - 1) * 24 + 10, 16 - hop * 4)
				end
			end
		end
		if banner.Visible and not calm then
			self.bannerBurst.Rotation += dt * 16
		end
	end)

	return self
end

-- ============================================================================
-- Objective card
-- ============================================================================

function TutorialUI:_setStep(step: number?)
	local previous = self.step
	self.step = step
	self.stepTab.Visible = step ~= nil
	if not step then return end
	self.stepLabel.Text = if step >= Config.TotalSteps then "FINAL STEP" else string.format("STEP %d/%d", step, Config.TotalSteps)
	local function paint()
		for index, slot in self.slots do
			slot.Image = if index < step then IMG.PebbleDone elseif index == step then IMG.PebbleCurrent else IMG.PebbleEmpty
			slot.Size = UDim2.fromOffset(if index == step then 22 else 18, if index == step then 22 else 18)
			slot.Position = UDim2.fromOffset((index - 1) * 24 + 10, 16)
		end
	end
	if previous and step > previous and not Theme.reducedMotion() then
		-- The pebble skips from the old slot to the new one.
		local from = Vector2.new((previous - 1) * 24 + 10, 16)
		local to = Vector2.new((step - 1) * 24 + 10, 16)
		self.slots[previous].Image = IMG.PebbleDone
		self.slots[step].Image = IMG.PebbleEmpty
		local hopper = self.hopper
		hopper.Visible = true
		local started = os.clock()
		local duration = .42 + (step - previous - 1) * .12
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			local t = math.clamp((os.clock() - started) / duration, 0, 1)
			local point = from:Lerp(to, t)
			local arc = math.sin(t * math.pi * (step - previous)) -- one bounce per slot crossed
			hopper.Position = UDim2.fromOffset(point.X, point.Y - math.abs(arc) * 12)
			hopper.Rotation = t * 360
			if t >= 1 then
				connection:Disconnect()
				hopper.Visible = false
				paint()
				local landed = self.slots[step]
				landed.Size = UDim2.fromOffset(30, 30)
				Theme.tween(landed, .3, {Size = UDim2.fromOffset(22, 22)}, Enum.EasingStyle.Back)
			end
		end)
	else
		paint()
	end
end

function TutorialUI:_setAccent(swatchName: string?)
	local tone = Theme.swatch(swatchName)
	self.halo.ImageColor3 = tone.top
	self.cardGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.Paper),
		ColorSequenceKeypoint.new(.6, Theme.PaperShade),
		ColorSequenceKeypoint.new(1, tone.top:Lerp(Theme.Paper, .62)),
	})
end

function TutorialUI:_clearExtras()
	for _, child in self.extras:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	self.loopToken = (self.loopToken or 0) + 1
end

function TutorialUI:_row(order: number, height: number?): Frame
	return new("Frame", {Name = "Row", LayoutOrder = order, Size = UDim2.new(1, 0, 0, height or 34),
		AutomaticSize = if height then Enum.AutomaticSize.None else Enum.AutomaticSize.Y, BackgroundTransparency = 1,
		ZIndex = 5, Parent = self.extras}, {new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 7), Wraps = true,
		SortOrder = Enum.SortOrder.LayoutOrder})})
end

-- Visual input hints: keycaps, mouse, tap, words, arrows, coloured pills.
function TutorialUI:_inputs(tokens: {InputToken})
	local row = self:_row(1, 36)
	for index, token in tokens do
		local node: GuiObject
		if token.kind == "key" then
			node = Theme.keycap(row, token.text or "E", 6)
		elseif token.kind == "mouse" or token.kind == "tap" then
			node = new("ImageLabel", {Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1,
				Image = if token.kind == "mouse" then IMG.Mouse else IMG.Tap, ZIndex = 6, Parent = row})
		elseif token.kind == "arrow" then
			node = rightArrow(row, 18, 0, 6)
		elseif token.kind == "pill" then
			local tone = Theme.swatch(token.swatch or "lime")
			node = new("Frame", {AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28),
				BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 6, Parent = row},
				{Theme.corner(), Theme.stroke(Theme.Ink, 2.5), Theme.gradient(tone.top, tone.bottom), Theme.padding(10, 10, 0, 0)})
			local text = Theme.label({AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28),
				FontFace = Theme.Display, TextSize = 16, Text = token.text or "", TextColor3 = Color3.new(1, 1, 1), ZIndex = 7,
				Parent = node})
			Theme.textStroke(Theme.Ink, 1.8).Parent = text
		else
			node = Theme.label({AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 32), FontFace = Theme.Display,
				TextSize = 19, Text = token.text or "", TextColor3 = Theme.Ink, ZIndex = 6, Parent = row})
		end
		node.LayoutOrder = index
	end
end

function TutorialUI:_chips(chips: {Chip})
	local row = self:_row(2)
	for index, chip in chips do
		local tone = Theme.swatch(chip.swatch or "lagoon")
		local pill = new("Frame", {Name = "Chip", LayoutOrder = index, AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 28), BackgroundColor3 = Theme.Paper, BorderSizePixel = 0, ZIndex = 6, Parent = row},
			{Theme.corner(), Theme.stroke(Theme.Ink, 2.5), Theme.padding(4, 12, 0, 0),
				new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder})})
		local tag = new("Frame", {Name = "Tag", LayoutOrder = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20),
			BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 7, Parent = pill},
			{Theme.corner(), Theme.gradient(tone.top, tone.bottom), Theme.padding(8, 8, 0, 0)})
		local tagText = Theme.label({AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), FontFace = Theme.Display,
			TextSize = 14, Text = chip.label, TextColor3 = Color3.new(1, 1, 1), ZIndex = 8, Parent = tag})
		Theme.textStroke(Theme.Ink, 1.5).Parent = tagText
		Theme.label({LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), TextSize = 14,
			Text = chip.value, TextColor3 = Theme.Ink, ZIndex = 7, Parent = pill})
	end
end

-- The core loop as four medallion tokens that light up in order.
function TutorialUI:_loop(buttonSpec: {text: string, callback: () -> ()}?)
	local row = self:_row(3, 58)
	local list = row:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	list.Padding = UDim.new(0, 2)
	local steps = {{"THROW", IMG.Throw, "lagoon"}, {"SKIP", IMG.Splash, "lagoon"}, {"EARN", IMG.Cash, "lime"},
		{"UPGRADE", IMG.Upgrade, "sun"}}
	local tokens = {}
	for index, entry in steps do
		local token = new("Frame", {Name = entry[1], LayoutOrder = index * 2, Size = UDim2.fromOffset(56, 58),
			BackgroundTransparency = 1, ZIndex = 6, Parent = row})
		local disc = new("Frame", {Name = "Disc", AnchorPoint = Vector2.new(.5, 0), Position = UDim2.fromScale(.5, 0),
			Size = UDim2.fromOffset(40, 40), BackgroundColor3 = Theme.Paper, BorderSizePixel = 0, ZIndex = 6, Parent = token},
			{Theme.corner()})
		local stroke = Theme.stroke(Theme.Ink, 2.5)
		stroke.Parent = disc
		local icon = new("ImageLabel", {AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
			Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 1, Image = entry[2], ImageTransparency = .45,
			ZIndex = 7, Parent = disc})
		local label = Theme.label({AnchorPoint = Vector2.new(.5, 1), Position = UDim2.fromScale(.5, 1), Size = UDim2.new(1, 8, 0, 14),
			FontFace = Theme.Display, TextSize = 13, Text = entry[1], TextColor3 = Theme.InkSoft, TextTransparency = .3,
			ZIndex = 7, Parent = token})
		local scale = new("UIScale", {Parent = disc})
		tokens[index] = {disc = disc, stroke = stroke, icon = icon, label = label, scale = scale, swatch = entry[3]}
		if index < #steps then
			rightArrow(row, 14, .35, 6).LayoutOrder = index * 2 + 1
		end
	end
	if buttonSpec then
		new("Frame", {Name = "Gap", LayoutOrder = 98, Size = UDim2.fromOffset(6, 10), BackgroundTransparency = 1, Parent = row})
		local button = Theme.button(row, buttonSpec.text, "lime", UDim2.fromOffset(112, 42), 6)
		button.LayoutOrder = 99
		button.Activated:Connect(function() buttonSpec.callback() end)
	end
	local token = self.loopToken
	task.spawn(function()
		local lit = 0
		while self.loopToken == token and row.Parent do
			lit = lit % #tokens + 1
			for index, entry in tokens do
				local on = index <= lit
				Theme.tween(entry.icon, .2, {ImageTransparency = if on then 0 else .45})
				Theme.tween(entry.label, .2, {TextTransparency = if on then 0 else .3, TextColor3 = if on then Theme.Ink else Theme.InkSoft})
				entry.stroke.Color = if index == lit then Theme.swatch(entry.swatch).bottom else Theme.Ink
				entry.stroke.Thickness = if index == lit then 3.5 else 2.5
				if index == lit and not Theme.reducedMotion() then
					entry.scale.Scale = 1.28
					Theme.tween(entry.scale, .35, {Scale = 1.08}, Enum.EasingStyle.Back)
				elseif index ~= lit then
					Theme.tween(entry.scale, .2, {Scale = 1})
				end
			end
			task.wait(if lit == #tokens then 1.2 else .5)
		end
	end)
end

function TutorialUI:_button(spec: {text: string, callback: () -> ()})
	local row = new("Frame", {Name = "ButtonRow", LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1,
		ZIndex = 5, Parent = self.extras})
	local button = Theme.button(row, spec.text, "lime", UDim2.fromOffset(150, 44), 6)
	button.Activated:Connect(function() spec.callback() end)
end

function TutorialUI:_startTimer(seconds: number?)
	if not seconds or seconds <= 0 then
		self.timerTrack.Visible = false
		return
	end
	self.timerTrack.Visible = true
	self.timerFill.Size = UDim2.fromScale(1, 1)
	Theme.tween(self.timerFill, seconds, {Size = UDim2.fromScale(0, 1)}, Enum.EasingStyle.Linear)
end

function TutorialUI:_fill(spec: ObjectiveSpec)
	self.title.Text = spec.title
	self.body.Text = spec.body
	self.body.Visible = spec.body ~= ""
	self.medallion.setIcon(spec.icon)
	self:_setAccent(spec.accent or (Theme.Icons[spec.icon or "throw"] or Theme.Icons.throw).swatch)
	self:_setStep(spec.step)
	self.skip.Visible = spec.skippable ~= false
	self.onSkip = spec.onSkip
	self:_clearExtras()
	if spec.inputs and #spec.inputs > 0 then self:_inputs(spec.inputs) end
	if spec.chips and #spec.chips > 0 then self:_chips(spec.chips) end
	-- With the loop row the button sits at the end of it, keeping the card
	-- short enough not to cover the game's own throw results panel.
	if spec.loop then self:_loop(spec.button) end
	if spec.button and not spec.loop then self:_button(spec.button) end
	self:_startTimer(spec.timer)
end

function TutorialUI:setPlacement(placement: string)
	if self.placement == placement then return end
	self.placement = placement
	self.animating = false
	self.fit()
	if self.visible and not Theme.reducedMotion() then
		local target = self.holder.Position
		self.holder.Position = target + UDim2.fromOffset(0, if placement == "bottom" then 50 else -50)
		Theme.tween(self.holder, .4, {Position = target}, Enum.EasingStyle.Back)
	end
end

function TutorialUI:showObjective(spec: ObjectiveSpec)
	self:setPlacement(spec.placement or "top")
	if self.visible and self.currentKey == spec.key then
		if self.title.Text ~= spec.title then self.title.Text = spec.title end
		if self.body.Text ~= spec.body then self.body.Text = spec.body end
		return
	end
	self.token += 1
	local token = self.token
	self.currentKey = spec.key
	local holder, canvas, medallion = self.holder, self.canvas, self.medallion

	if not self.visible then
		self.visible = true
		self.step = nil
		self:_fill(spec)
		holder.Visible = true
		self.medallionRipples.setVisible(true)
		self.content.Position = UDim2.fromOffset(0, 0)
		if Theme.reducedMotion() then
			canvas.GroupTransparency = 0
			holder.Position = UDim2.new(.5, 0, 0, self.placementY)
			return
		end
		-- Drop in like a stone landing: fall, overshoot, settle; medallion spins in.
		self.animating = true
		local from = if self.placement == "bottom" then 60 else -60
		holder.Position = UDim2.new(.5, 0, 0, self.placementY + from)
		holder.Rotation = -3
		canvas.GroupTransparency = 1
		medallion.scale.Scale = .2
		medallion.root.Rotation = -120
		Theme.tween(holder, .55, {Position = UDim2.new(.5, 0, 0, self.placementY), Rotation = 0}, Enum.EasingStyle.Back)
		Theme.tween(canvas, .22, {GroupTransparency = 0})
		Theme.tween(medallion.scale, .55, {Scale = 1}, Enum.EasingStyle.Back, nil, .12)
		Theme.tween(medallion.root, .55, {Rotation = 0}, Enum.EasingStyle.Back, nil, .12)
		task.delay(.6, function() if self.token == token then self.animating = false end end)
		return
	end

	-- Swap: medallion flips to the new icon, content slides up into place.
	if Theme.reducedMotion() then
		self:_fill(spec)
		return
	end
	Theme.tween(self.content, .12, {Position = UDim2.fromOffset(0, -10)})
	Theme.tween(medallion.scale, .12, {Scale = .82})
	task.delay(.12, function()
		if self.token ~= token then return end
		self:_fill(spec)
		self.content.Position = UDim2.fromOffset(0, 14)
		Theme.tween(self.content, .35, {Position = UDim2.fromOffset(0, 0)}, Enum.EasingStyle.Back)
		Theme.tween(medallion.scale, .4, {Scale = 1}, Enum.EasingStyle.Back)
		medallion.root.Rotation = 25
		Theme.tween(medallion.root, .4, {Rotation = 0}, Enum.EasingStyle.Back)
	end)
end

function TutorialUI:hideObjective()
	if not self.visible then return end
	self.visible = false
	self.currentKey = nil
	self.token += 1
	self.loopToken = (self.loopToken or 0) + 1
	self.medallionRipples.setVisible(false)
	local token = self.token
	local holder = self.holder
	if Theme.reducedMotion() then
		holder.Visible = false
		return
	end
	local away = if self.placement == "bottom" then 40 else -40
	Theme.tween(holder, .28, {Position = UDim2.new(.5, 0, 0, self.placementY + away)}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	Theme.tween(self.canvas, .22, {GroupTransparency = 1}, nil, nil, .06)
	task.delay(.3, function()
		if self.token == token then
			holder.Visible = false
			holder.Position = UDim2.new(.5, 0, 0, self.placementY)
		end
	end)
end

-- AbsolutePosition is measured below the top bar; our layers start at y = 0.
function TutorialUI:toLayer(absolute: Vector2): Vector2
	return absolute - self.guidanceLayer.AbsolutePosition
end

function TutorialUI:cardCenter(): Vector2
	return self:toLayer(self.holder.AbsolutePosition + self.holder.AbsoluteSize / 2)
end

-- CompleteObjective: medallion stamps a green check, card flashes, sparkles fly.
function TutorialUI:completeObjective(text: string?): Vector2?
	if not self.visible then return nil end
	self.token += 1
	self.currentKey = "__complete"
	self:_clearExtras()
	self:_startTimer(nil)
	self.skip.Visible = false
	self.canvas.GroupTransparency = 0
	self.medallion.setIcon("check")
	self:_setAccent("lime")
	self.title.Text = text or "NICE!"
	self.body.Text = ""
	self.body.Visible = false
	local medallion = self.medallion
	if not Theme.reducedMotion() then
		medallion.scale.Scale = 1.4
		Theme.tween(medallion.scale, .5, {Scale = 1}, Enum.EasingStyle.Back)
		self.flash.BackgroundTransparency = .25
		Theme.tween(self.flash, .45, {BackgroundTransparency = 1})
		self.content.Position = UDim2.fromOffset(0, 12)
		Theme.tween(self.content, .35, {Position = UDim2.fromOffset(0, 0)}, Enum.EasingStyle.Back)
	end
	local center = self:toLayer(medallion.root.AbsolutePosition + medallion.root.AbsoluteSize / 2)
	self:_sparkleBurst(center, 8)
	return center
end

function TutorialUI:_sparkleBurst(center: Vector2, count: number)
	if Theme.reducedMotion() then return end
	local scale = self.uiScale or 1
	for index = 1, count do
		local angle = (index / count) * math.pi * 2 + math.random() * .4
		local size = math.random(16, 26) * scale
		local sparkle = new("ImageLabel", {AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(center.X, center.Y),
			Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, Image = IMG.Sparkle,
			ImageColor3 = if index % 2 == 0 then Theme.Swatches.sun.top else Color3.new(1, 1, 1), ZIndex = 41,
			Parent = self.confettiLayer})
		local distance = (70 + math.random() * 30) * scale
		local target = center + Vector2.new(math.cos(angle), math.sin(angle)) * distance
		Theme.tween(sparkle, .55, {Position = UDim2.fromOffset(target.X, target.Y), Rotation = 180,
			ImageTransparency = 1, Size = UDim2.fromOffset(size * .4, size * .4)}, Enum.EasingStyle.Quart)
		task.delay(.6, function() sparkle:Destroy() end)
	end
end

-- ============================================================================
-- Banner
-- ============================================================================

function TutorialUI:banner(title: string, subtitle: string, swatchName: string?, seconds: number?)
	local banner = self.bannerFrame
	self.bannerToken = (self.bannerToken or 0) + 1
	local token = self.bannerToken
	local tone = Theme.swatch(swatchName or "sun")
	self.bannerTitle.Text = title
	self.bannerSubtitle.Text = subtitle
	-- Auto-sized wrapped text never widens past its first wrap, so measure
	-- the line and give the pill an explicit width (max 540).
	task.spawn(function()
		local ok, bounds = pcall(function()
			local params = Instance.new("GetTextBoundsParams")
			params.Text = (subtitle:gsub("<[^>]->", ""))
			params.Font = Theme.Body
			params.Size = 21
			params.Width = 540
			return TextService:GetTextBoundsAsync(params)
		end)
		if ok and bounds and self.bannerToken == token then
			self.bannerSubtitle.Size = UDim2.fromOffset(math.min(540, math.ceil(bounds.X) + 6), 0)
		end
	end)
	self.bannerBurst.ImageColor3 = tone.top
	self.bannerGlow.ImageColor3 = tone.top
	banner.Visible = true
	local calm = Theme.reducedMotion()
	self.ribbonScale.Scale = if calm then 1 else .2
	self.ribbon.Rotation = if calm then 0 else -8
	self.ribbon.ImageTransparency = 0
	self.bannerTitle.TextTransparency = 0
	self.bannerBurst.ImageTransparency = 1
	self.bannerGlow.ImageTransparency = 1
	self.bannerSubPill.BackgroundTransparency = 1
	self.bannerSubtitle.TextTransparency = 1
	local titleStroke = self.bannerTitle:FindFirstChildOfClass("UIStroke")
	if titleStroke then titleStroke.Transparency = 0 end
	Theme.tween(self.ribbonScale, .6, {Scale = 1}, Enum.EasingStyle.Back)
	Theme.tween(self.ribbon, .6, {Rotation = 0}, Enum.EasingStyle.Back)
	Theme.tween(self.bannerBurst, .5, {ImageTransparency = .2})
	Theme.tween(self.bannerGlow, .5, {ImageTransparency = .35})
	Theme.tween(self.bannerSubPill, .3, {BackgroundTransparency = .12}, nil, nil, .3)
	Theme.tween(self.bannerSubtitle, .3, {TextTransparency = 0}, nil, nil, .3)
	for index, sparkle in self.bannerSparkles do
		sparkle.ImageTransparency = 1
		sparkle.Rotation = 0
		task.delay(.25 + index * .12, function()
			if self.bannerToken ~= token then return end
			sparkle.ImageTransparency = 0
			sparkle.Size = UDim2.fromOffset(4, 4)
			local full = ({46, 34, 28})[index]
			Theme.tween(sparkle, .35, {Size = UDim2.fromOffset(full, full), Rotation = 90}, Enum.EasingStyle.Back)
			Theme.tween(sparkle, .6, {ImageTransparency = 1}, nil, nil, .5)
		end)
	end
	task.delay(seconds or 3.2, function()
		if self.bannerToken ~= token then return end
		Theme.tween(self.ribbonScale, .3, {Scale = 1.1})
		Theme.tween(self.ribbon, .3, {ImageTransparency = 1})
		Theme.tween(self.bannerTitle, .25, {TextTransparency = 1})
		if titleStroke then Theme.tween(titleStroke, .25, {Transparency = 1}) end
		Theme.tween(self.bannerBurst, .3, {ImageTransparency = 1})
		Theme.tween(self.bannerGlow, .3, {ImageTransparency = 1})
		Theme.tween(self.bannerSubPill, .25, {BackgroundTransparency = 1})
		Theme.tween(self.bannerSubtitle, .25, {TextTransparency = 1})
		task.delay(.32, function()
			if self.bannerToken == token then banner.Visible = false end
		end)
	end)
end

-- ============================================================================
-- Confirm dialog
-- ============================================================================

function TutorialUI:confirm(title: string, message: string, yesText: string, noText: string, onYes: () -> ())
	local layer = self.confirmLayer
	for _, child in layer:GetChildren() do child:Destroy() end
	layer.Visible = true
	local backdrop = new("TextButton", {Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Ink,
		BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Modal = true, ZIndex = 50, Parent = layer})
	local group = new("CanvasGroup", {Name = "Dialog", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
		Size = UDim2.fromOffset(470, 300), BackgroundTransparency = 1, GroupTransparency = 1, ZIndex = 51, Parent = layer})
	local scale = new("UIScale", {Scale = (self.uiScale or 1) * .85, Parent = group})
	local panel, body = Theme.sticker(group, 26, 8, "Panel")
	panel.Position = UDim2.fromOffset(10, 44)
	panel.Size = UDim2.new(1, -20, 1, -60)
	panel.ZIndex = 52
	local medallion = Theme.medallion(group, 92, 60)
	medallion.root.Position = UDim2.new(.5, 0, 0, 46)
	medallion.setIcon("splash")
	Theme.label({Name = "Title", Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 36), FontFace = Theme.Display,
		TextSize = 32, Text = title, ZIndex = 55, Parent = body})
	Theme.label({Name = "Body", Position = UDim2.fromOffset(30, 94), Size = UDim2.new(1, -60, 0, 44), TextSize = 18,
		TextWrapped = true, Text = message, TextColor3 = Theme.InkSoft, ZIndex = 55, Parent = body})
	local buttons = new("Frame", {Name = "Buttons", AnchorPoint = Vector2.new(.5, 1), Position = UDim2.new(.5, 0, 1, -18),
		Size = UDim2.new(1, -40, 0, 50), BackgroundTransparency = 1, ZIndex = 55, Parent = body},
		{new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14),
			HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder})})
	local keep = Theme.button(buttons, noText, "lime", UDim2.fromOffset(200, 50), 56)
	keep.Name, keep.LayoutOrder = "Keep", 1
	local yes = Theme.button(buttons, yesText, "stone", UDim2.fromOffset(150, 50), 56)
	yes.Name, yes.LayoutOrder = "Confirm", 2
	local yesLabel = yes:FindFirstChild("Label", true)
	if yesLabel and yesLabel:IsA("TextLabel") then yesLabel.TextColor3 = Theme.InkSoft
		local s = yesLabel:FindFirstChildOfClass("UIStroke"); if s then s.Enabled = false end end

	local closed = false
	local escConnection: RBXScriptConnection? = nil
	local function close()
		if closed then return end
		closed = true
		if escConnection then escConnection:Disconnect() end
		Theme.tween(group, .16, {GroupTransparency = 1})
		Theme.tween(scale, .16, {Scale = (self.uiScale or 1) * .9})
		Theme.tween(backdrop, .16, {BackgroundTransparency = 1})
		task.delay(.17, function()
			if layer:FindFirstChild("Dialog") == group then
				layer.Visible = false
				for _, child in layer:GetChildren() do child:Destroy() end
			end
		end)
	end
	keep.Activated:Connect(close)
	backdrop.Activated:Connect(close)
	yes.Activated:Connect(function()
		close()
		onYes()
	end)
	escConnection = UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then close() end
	end)
	Theme.tween(backdrop, .2, {BackgroundTransparency = .5})
	Theme.tween(group, .2, {GroupTransparency = 0})
	Theme.tween(scale, .4, {Scale = self.uiScale or 1}, Enum.EasingStyle.Back)
	medallion.scale.Scale = .3
	Theme.tween(medallion.scale, .5, {Scale = 1}, Enum.EasingStyle.Back, nil, .08)
end

-- ============================================================================
-- Confetti: paper bits, pebbles and sparkles
-- ============================================================================

function TutorialUI:confetti(origin: Vector2, count: number, power: number?)
	if Theme.reducedMotion() then count = math.min(count, 8) end
	local palette = {Theme.Swatches.sun.top, Theme.Swatches.lime.top, Theme.Swatches.lagoon.top, Theme.Swatches.grape.top,
		Theme.Swatches.coral.top, Color3.new(1, 1, 1)}
	local pebbles = {IMG.PebbleDone, IMG.PebbleCurrent, IMG.PebbleEmpty}
	local pieces = {}
	local strength = power or 1
	local scale = self.uiScale or 1
	for _ = 1, count do
		local piece: GuiObject
		local roll = math.random()
		if roll < .18 then
			local size = math.random(14, 20) * scale
			piece = new("ImageLabel", {AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(size, size),
				BackgroundTransparency = 1, Image = pebbles[math.random(1, #pebbles)], ZIndex = 41, Parent = self.confettiLayer})
		elseif roll < .3 then
			local size = math.random(12, 20) * scale
			piece = new("ImageLabel", {AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(size, size),
				BackgroundTransparency = 1, Image = IMG.Sparkle, ImageColor3 = palette[math.random(1, #palette)], ZIndex = 41,
				Parent = self.confettiLayer})
		else
			local w = math.random(7, 12) * scale
			piece = new("Frame", {AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(w, w * (if math.random() < .5 then .5 else 1)),
				BackgroundColor3 = palette[math.random(1, #palette)], BorderSizePixel = 0, ZIndex = 41, Parent = self.confettiLayer},
				{Theme.corner(2), Theme.stroke(Theme.Ink, 1.2)})
		end
		local angle = math.random() * math.pi * 2
		local speed = (220 + math.random() * 380) * strength * scale
		table.insert(pieces, {frame = piece, position = origin,
			velocity = Vector2.new(math.cos(angle) * speed, math.sin(angle) * speed * .8 - 300 * strength * scale),
			spin = (math.random() - .5) * 900, image = piece:IsA("ImageLabel")})
	end
	local age = 0
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt)
		age += dt
		local fade = math.clamp((age - 1.2) / .5, 0, 1)
		for _, piece in pieces do
			piece.velocity = Vector2.new(piece.velocity.X * (1 - 1.8 * dt), piece.velocity.Y + 1000 * dt * scale)
			piece.position += piece.velocity * dt
			piece.frame.Position = UDim2.fromOffset(piece.position.X, piece.position.Y)
			piece.frame.Rotation += piece.spin * dt
			if piece.image then (piece.frame :: ImageLabel).ImageTransparency = fade
			else piece.frame.BackgroundTransparency = fade end
		end
		if age > 1.8 then
			connection:Disconnect()
			for _, piece in pieces do piece.frame:Destroy() end
		end
	end)
end

return TutorialUI
