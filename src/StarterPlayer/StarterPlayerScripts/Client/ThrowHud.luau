--!strict
--[[
	ThrowHud (client) -- Skipstone edition

	The in-flight HUD: charge meter with sweet-zone band and sweeping needle,
	release rating, skip counter, live distance readout and the end-of-throw
	result card. Built from ReplicatedStorage.SharedUI.SkipstoneTheme (the
	same white-sticker language as the tutorial), so ArcadeVisualStyle skips
	it via the "Skipstone" attribute on the ScreenGui.

	Public API is unchanged: create, showCharge, setSweetZone, updateCharge,
	hideCharge, showRelease, confirmRelease, setFlightMode, dismissResult,
	showQualityCallout, showPerfect, setCombo, setDistance, clearFlight,
	setLevel, showResult. Instance names other scripts look up are kept:
	ResultHolder, StoneCamReplay, SweetZone, QualityCallout.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ThrowConfig = require(Shared:WaitForChild("ThrowConfig"))
local ProgressionConfig = require(Shared:WaitForChild("ProgressionConfig"))
local Theme = require(ReplicatedStorage:WaitForChild("SharedUI"):WaitForChild("SkipstoneTheme"))
local HUD = ThrowConfig.Presentation.Hud

local new = Theme.new
local S = Theme.Swatches
local IMG = Theme.Images
local INK = Theme.Ink

local ThrowHud = {}
ThrowHud.__index = ThrowHud

export type ThrowHud = typeof(setmetatable({} :: {
	gui: ScreenGui,
	fxLayer: Frame,
	chargeCard: Frame,
	chargeBar: Frame,
	chargeFill: Frame,
	chargeStroke: UIStroke,
	sweetBand: Frame,
	needle: Frame,
	releaseMarker: Frame,
	chargeLabel: TextLabel,
	chargeReadout: TextLabel,
	chargeMedallion: any,
	comboHolder: Frame,
	comboLabel: TextLabel,
	comboMedallion: any,
	distancePill: Frame,
	perfectLabel: TextLabel,
	perfectArt: CanvasGroup,
	perfectFlash: Frame,
	perfectRing: Frame,
	distanceLabel: TextLabel,
	resultHolder: Frame,
	resultLabel: TextLabel,
	resultMedallion: any,
	levelHolder: Frame,
	levelLabel: TextLabel,
	xpFill: Frame,
	xpLabel: TextLabel,
	hudScale: number,
	perfectToken: number,
	resultToken: number,
	releaseToken: number,
	releaseActive: boolean,
	flightActive: boolean,
	uiFadeToken: number,
	uiSnapshots: {[Instance]: any},
	uiTweens: {Tween},
	latestSkips: number,
	milestoneToken: number,
	milestoneShowing: boolean,
}, ThrowHud))

local RESULT_LABEL_TIME = HUD.ResultTime

local COLOR_CHARGE = Color3.fromRGB(46, 176, 255)
local COLOR_PERFECT = Color3.fromRGB(88, 226, 96)
local COLOR_STRAIN = HUD.StrainColor
local RIM_REST = INK

-- These are server quality buckets, not measured accuracy percentages.
local QUALITY_STYLES: {[string]: {title: string, subtitle: string, color: Color3}} = HUD.QualityStyles
-- Swatch + medallion icon per quality bucket.
local QUALITY_LOOK: {[string]: {swatch: string, icon: string}} = {
	perfect = {swatch = "lime", icon = "check"},
	nearMiss = {swatch = "sun", icon = "splash"},
	normal = {swatch = "lagoon", icon = "throw"},
	weak = {swatch = "coral", icon = "splash"},
}

local RESULT_W, RESULT_H = 520, 372

local function reducedMotion(): boolean
	return Players.LocalPlayer:GetAttribute("ReducedMotion") == true
end

local function numberText(value: number): string
	local whole = tostring(math.floor(math.max(value, 0)))
	local grouped = string.reverse(string.gsub(string.reverse(whole), "(%d%d%d)", "%1,"))
	return (string.gsub(grouped, "^,", ""))
end

local function nextMilestone(count: number): any
	for _, milestone in ThrowConfig.Presentation.Fx.Crescendo.Milestones do
		if milestone.Skips > count then return milestone end
	end
	return nil
end

-- Luckiest Guy label with an ink outline, the Skipstone headline look.
local function display(props: {[string]: any}, strokeThickness: number?): TextLabel
	props.FontFace = props.FontFace or Theme.Display
	local label = Theme.label(props)
	if strokeThickness then Theme.textStroke(INK, strokeThickness).Parent = label end
	return label
end

local function sizeLimit(label: TextLabel, minSize: number, maxSize: number)
	label.TextScaled = true
	new("UITextSizeConstraint", {MinTextSize = minSize, MaxTextSize = maxSize, Parent = label})
end

-- A capsule track with an ink rim and a fill. Returns (track, fill).
local function track(parent: Instance, name: string, height: number, zIndex: number): (Frame, Frame)
	local frame = new("Frame", {Name = name, Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = Theme.Mist,
		BorderSizePixel = 0, ZIndex = zIndex, Parent = parent}, {Theme.corner(), Theme.stroke(INK, 2.5)})
	local fill = new("Frame", {Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, ZIndex = zIndex + 1, Parent = frame}, {Theme.corner(),
		Theme.gradient(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205))})
	return frame, fill
end

-- Colored pill with white outlined text (result chips, badges).
local function chip(parent: Instance, text: string, color: Color3, order: number): Frame
	local pill = new("Frame", {Name = "Chip", LayoutOrder = order, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = parent},
		{Theme.corner(), Theme.stroke(INK, 2.5), Theme.gradient(color:Lerp(Color3.new(1, 1, 1), .28), color),
			Theme.padding(12, 12, 0, 0)})
	display({AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), TextSize = 15, Text = text,
		TextColor3 = Color3.new(1, 1, 1), Parent = pill}, 1.8)
	return pill
end

local function restScale(scale: UIScale): number
	return (scale:GetAttribute("RestScale") :: number?) or 1
end

local function pop(scale: UIScale, from: number, seconds: number?, style: Enum.EasingStyle?)
	local rest = restScale(scale)
	if reducedMotion() then scale.Scale = rest return end
	scale.Scale = rest * from
	TweenService:Create(scale, TweenInfo.new(seconds or HUD.Theme.PopTime, style or Enum.EasingStyle.Back,
		Enum.EasingDirection.Out), {Scale = rest}):Play()
end

local function playPerfectPopSounds()
	local soundParent = if HUD.PerfectSoundAnchor == "SoundService" then SoundService else nil
	for _, soundConfig in HUD.PerfectPopSounds do
		task.delay(soundConfig.Delay or 0, function()
			local sound = Instance.new("Sound")
			sound.Name = "PerfectReleasePop"
			sound.SoundId = soundConfig.SoundId
			sound.Volume = soundConfig.Volume
			sound.PlaybackSpeed = soundConfig.PlaybackSpeed
			sound.Parent = soundParent or SoundService
			sound.Ended:Once(function()
				sound:Destroy()
			end)
			task.delay(3, function()
				if sound.Parent then sound:Destroy() end
			end)
			sound:Play()
		end)
	end
end

-- Sparkle burst from a screen point, used for milestones and records.
local function sparkleBurst(parent: Instance, center: Vector2, count: number, color: Color3, distance: number)
	if reducedMotion() then return end
	for index = 1, count do
		local angle = (index / count) * math.pi * 2 + math.random() * .5
		local size = math.random(14, 24)
		local sparkle = new("ImageLabel", {AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(center.X, center.Y),
			Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, Image = IMG.Sparkle,
			ImageColor3 = if index % 2 == 0 then color else Color3.new(1, 1, 1), ZIndex = 60, Parent = parent})
		local target = center + Vector2.new(math.cos(angle), math.sin(angle)) * (distance * (.7 + math.random() * .4))
		Theme.tween(sparkle, .55, {Position = UDim2.fromOffset(target.X, target.Y), Rotation = 180, ImageTransparency = 1,
			Size = UDim2.fromOffset(size * .4, size * .4)}, Enum.EasingStyle.Quart)
		task.delay(.6, function() sparkle:Destroy() end)
	end
end

-- ============================================================================
-- Construction
-- ============================================================================

function ThrowHud.create(): ThrowHud
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("ThrowHud")
	if old then old:Destroy() end

	local gui = new("ScreenGui", {
		Name = "ThrowHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 50, -- above the default hotbar/backpack
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	gui:SetAttribute("Skipstone", true)
	-- Full-screen layer for sparkles; also the reference for AbsolutePosition maths
	-- (children of an IgnoreGuiInset gui report positions below the top bar).
	local fxLayer = new("Frame", {Name = "FxLayer", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		ZIndex = 60, Parent = gui})

	-- ---- Skip counter ----------------------------------------------------
	local comboHolder = new("Frame", {Name = "ComboHolder", AnchorPoint = Vector2.new(.5, 0),
		Position = UDim2.new(.5, 12, 0, 20), Size = UDim2.fromOffset(250, 100), BackgroundTransparency = 1,
		Visible = false, ZIndex = 11, Parent = gui})
	new("UIScale", {Name = "Scale", Parent = comboHolder})
	local comboCard, comboBody = Theme.sticker(comboHolder, 24, 6, "Card")
	comboCard.Size = UDim2.fromScale(1, 1)
	local comboMedallion = Theme.medallion(comboHolder, 74, 6)
	comboMedallion.root.Position = UDim2.fromOffset(4, 50)
	comboMedallion.setIcon("splash")
	local comboLabel = display({Name = "ComboLabel", Position = UDim2.fromOffset(46, 8), Size = UDim2.new(1, -58, 0, 46),
		Text = "0 SKIPS", TextColor3 = HUD.Theme.GoldLight, ZIndex = 5, Parent = comboBody}, 3)
	sizeLimit(comboLabel, 18, 42)
	new("UIScale", {Name = "Bump", Parent = comboLabel})
	display({Name = "MilestoneHint", Position = UDim2.fromOffset(46, 55), Size = UDim2.new(1, -58, 0, 16),
		Text = "BUILD YOUR SKIP STREAK", TextSize = 14, TextColor3 = Theme.InkSoft, ZIndex = 5, Parent = comboBody})
	local milestoneTrack = track(comboBody, "MilestoneProgress", 11, 5)
	milestoneTrack.Position = UDim2.fromOffset(52, 76)
	milestoneTrack.Size = UDim2.new(1, -68, 0, 11)

	-- ---- Distance pill -----------------------------------------------------
	local distancePill = new("Frame", {Name = "DistancePill", AnchorPoint = Vector2.new(.5, 0),
		Position = UDim2.new(.5, 12, 0, 130), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 34),
		BackgroundColor3 = INK, BorderSizePixel = 0, Visible = false, ZIndex = 11, Parent = gui},
		{Theme.corner(), Theme.padding(8, 16, 0, 0), new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})})
	new("UIScale", {Name = "Scale", Parent = distancePill})
	new("ImageLabel", {Name = "Icon", LayoutOrder = 1, Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1,
		Image = IMG.Throw, ZIndex = 12, Parent = distancePill})
	local distanceLabel = display({Name = "DistanceLabel", LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 34), TextSize = 20, TextColor3 = Color3.new(1, 1, 1), Text = "", ZIndex = 12,
		Parent = distancePill})

	-- Legacy label kept hidden for any old reference.
	local perfectLabel = display({Name = "PerfectLabel", Size = UDim2.fromOffset(320, 60), Text = "PERFECT!",
		Visible = false, Parent = gui})

	-- ---- Charge meter ------------------------------------------------------
	local chargeCard = new("Frame", {Name = "ChargeCard", AnchorPoint = Vector2.new(.5, .5),
		Position = UDim2.fromScale(.5, HUD.Theme.ChargeY), Size = UDim2.new(HUD.ChargeWidthScale, 0, 0, 118),
		BackgroundTransparency = 1, Visible = false, ZIndex = 10, Parent = gui})
	new("UISizeConstraint", {MaxSize = Vector2.new(380, 118), Parent = chargeCard})
	new("UIScale", {Name = "Scale", Parent = chargeCard})
	local chargeSticker, chargeBody = Theme.sticker(chargeCard, 22, 6, "Card")
	chargeSticker.Size = UDim2.fromScale(1, 1)
	local chargeMedallion = Theme.medallion(chargeCard, 62, 6)
	chargeMedallion.root.Position = UDim2.fromOffset(8, 30)
	chargeMedallion.setIcon("throw")
	local chargeLabel = display({Name = "ChargeLabel", Position = UDim2.fromOffset(40, 12), Size = UDim2.new(1, -122, 0, 28),
		Text = "LINE UP YOUR SKIP", TextColor3 = INK, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
		Parent = chargeBody})
	sizeLimit(chargeLabel, 12, 22)
	local readoutPill = new("Frame", {Name = "Readout", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12),
		Size = UDim2.fromOffset(66, 28), BackgroundColor3 = INK, BorderSizePixel = 0, ZIndex = 5, Parent = chargeBody},
		{Theme.corner()})
	local chargeReadout = display({Name = "ChargeReadout", Size = UDim2.fromScale(1, 1), Text = "0%", TextSize = 18,
		TextColor3 = Color3.new(1, 1, 1), ZIndex = 6, Parent = readoutPill})

	local chargeBar = new("Frame", {Name = "ChargeBar", AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, 0, 50),
		Size = UDim2.new(1, -36, 0, 30), BackgroundColor3 = Theme.Mist, BorderSizePixel = 0, ZIndex = 5,
		Parent = chargeBody}, {Theme.corner()})
	-- Doubles as the hold-strain readout: ink at rest, red and pulsing as strain climbs.
	local chargeStroke = new("UIStroke", {Color = RIM_REST, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = chargeBar})
	local chargeFill = new("Frame", {Name = "Fill", Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = COLOR_CHARGE,
		BorderSizePixel = 0, ZIndex = 6, Parent = chargeBar}, {Theme.corner(),
		Theme.gradient(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))})
	new("Frame", {Name = "FillGloss", Position = UDim2.new(0, 6, 0, 4), Size = UDim2.new(1, -12, .28, 0),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = .55, BorderSizePixel = 0, ZIndex = 7,
		Parent = chargeFill}, {Theme.corner()})
	local sweetBand = new("Frame", {Name = "SweetZone", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = .25,
		BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Visible = false, ZIndex = 8, Parent = chargeBar},
		{Theme.corner(), Theme.stroke(INK, 2.5), Theme.gradient(S.lime.top, S.lime.bottom)})
	new("TextLabel", {Name = "SweetZoneLabel", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
		ZIndex = 9, Parent = sweetBand})
	for i = 1, 3 do
		new("Frame", {Name = "TimingTick" .. i, AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(i / 4, .5),
			Size = UDim2.new(0, 2, 1, -12), BackgroundColor3 = INK, BackgroundTransparency = .72, BorderSizePixel = 0,
			ZIndex = 9, Parent = chargeBar})
	end
	local needle = new("Frame", {Name = "Needle", AnchorPoint = Vector2.new(.5, .5), Size = UDim2.new(0, 7, 1, 16),
		Position = UDim2.new(0, 0, .5, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 11,
		Parent = chargeBar}, {Theme.corner(), Theme.stroke(INK, 2.5)})
	local releaseMarker = new("Frame", {Name = "ReleaseMarker", AnchorPoint = Vector2.new(.5, .5),
		Size = UDim2.new(0, 10, 1, 20), Position = UDim2.new(0, 0, .5, 0), BackgroundColor3 = HUD.ReleasePendingColor,
		BorderSizePixel = 0, Visible = false, ZIndex = 12, Parent = chargeBar}, {Theme.corner(), Theme.stroke(INK, 2.5)})
	local instruction = Theme.label({Name = "ThrowInstruction", AnchorPoint = Vector2.new(.5, 0),
		Position = UDim2.new(.5, 0, 0, 88), Size = UDim2.new(1, -36, 0, 18), Text = "HOLD TO CHARGE  •  RELEASE IN THE ZONE",
		TextColor3 = Theme.InkSoft, ZIndex = 5, Parent = chargeBody})
	sizeLimit(instruction, 9, 13)

	-- ---- Release rating (non-perfect) --------------------------------------
	local qualityPanel = new("Frame", {Name = "QualityCallout", AnchorPoint = Vector2.new(.5, .5),
		Position = UDim2.new(0, -HUD.QualityMaxWidth, HUD.QualityY, 0), Size = UDim2.new(HUD.QualityWidthScale, 0, 0, 96),
		BackgroundTransparency = 1, Visible = false, ZIndex = 30, Parent = gui})
	new("UISizeConstraint", {MaxSize = Vector2.new(HUD.QualityMaxWidth, 96), Parent = qualityPanel})
	new("UIScale", {Name = "PopScale", Parent = qualityPanel})
	local qualitySticker, qualityBody = Theme.sticker(qualityPanel, 22, 6, "Card")
	qualitySticker.Size = UDim2.fromScale(1, 1)
	local qualityMedallion = Theme.medallion(qualityPanel, 66, 6)
	qualityMedallion.root.Position = UDim2.fromOffset(10, 45)
	local qualityTitle = display({Name = "Title", Position = UDim2.fromOffset(40, 14), Size = UDim2.new(1, -54, 0, 38),
		Text = "STEADY", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = qualityBody}, 3)
	sizeLimit(qualityTitle, 14, 32)
	local qualitySubtitle = Theme.label({Name = "Subtitle", Position = UDim2.fromOffset(42, 54), Size = UDim2.new(1, -56, 0, 20),
		Text = "", TextColor3 = Theme.InkSoft, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = qualityBody})
	sizeLimit(qualitySubtitle, 9, 14)

	-- ---- Perfect release badge --------------------------------------------
	local perfectArt = new("CanvasGroup", {Name = "PerfectReleaseArt", AnchorPoint = Vector2.new(.5, 0),
		Position = UDim2.new(.5, 12, 0, 178), Size = UDim2.fromOffset(340, 112), BackgroundTransparency = 1,
		GroupTransparency = 1, Visible = false, ZIndex = 45, Parent = gui})
	new("UIScale", {Name = "PopScale", Parent = perfectArt})
	local perfectSticker, perfectBody = Theme.sticker(perfectArt, 24, 6, "Card")
	perfectSticker.Position = UDim2.fromOffset(38, 10)
	perfectSticker.Size = UDim2.new(1, -46, 1, -24)
	local perfectMedallion = Theme.medallion(perfectArt, 80, 6)
	perfectMedallion.root.Position = UDim2.fromOffset(44, 50)
	perfectMedallion.setIcon("check")
	local perfectTitle = display({Name = "Title", Position = UDim2.fromOffset(48, 6), Size = UDim2.new(1, -60, 0, 48),
		Text = "PERFECT!", TextColor3 = Color3.fromRGB(150, 246, 96), TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5, Parent = perfectBody}, 3.5)
	sizeLimit(perfectTitle, 18, 44)
	Theme.label({Name = "Subtitle", Position = UDim2.fromOffset(50, 52), Size = UDim2.new(1, -60, 0, 18),
		Text = "PINPOINT RELEASE", TextSize = 15, TextColor3 = Theme.InkSoft, TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5, Parent = perfectBody})
	for index, spec in {{.93, .12, 30}, {.62, .9, 22}} do
		new("ImageLabel", {Name = "Sparkle" .. index, AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(spec[1], spec[2]),
			Size = UDim2.fromOffset(spec[3], spec[3]), BackgroundTransparency = 1, Image = IMG.Sparkle,
			ImageColor3 = S.sun.top, ZIndex = 20, Parent = perfectArt})
	end

	local perfectFlash = new("Frame", {Name = "PerfectReleaseFlash", Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = HUD.PerfectFlashColor, BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
		ZIndex = 42, Parent = gui})
	local perfectRing = new("Frame", {Name = "PerfectReleaseRing", AnchorPoint = Vector2.new(.5, .5),
		Position = UDim2.new(.5, 0, HUD.PerfectRingY, 0), Size = UDim2.fromOffset(HUD.PerfectRingStartSize, HUD.PerfectRingStartSize),
		BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 44, Parent = gui}, {Theme.corner()})
	new("UIStroke", {Name = "RingStroke", Color = S.sun.top, Thickness = HUD.PerfectRingThickness, Parent = perfectRing})

	-- ---- Result card -------------------------------------------------------
	local resultHolder = new("Frame", {Name = "ResultHolder", AnchorPoint = Vector2.new(.5, .5),
		Position = UDim2.fromScale(.5, .46), Size = UDim2.fromOffset(RESULT_W, RESULT_H), BackgroundTransparency = 1,
		Visible = false, ZIndex = 16, Parent = gui})
	new("UIScale", {Name = "ViewportScale", Parent = resultHolder})
	new("ImageLabel", {Name = "Sunburst", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .45),
		Size = UDim2.fromOffset(760, 760), BackgroundTransparency = 1, Image = IMG.Sunburst, ImageColor3 = S.sun.top,
		ImageTransparency = .35, Visible = false, ZIndex = 1, Parent = resultHolder})
	local resultSticker, resultBody = Theme.sticker(resultHolder, 28, 8, "Card")
	resultSticker.Size = UDim2.new(1, 0, 1, -8)
	resultSticker.ZIndex = 2
	local header = new("Frame", {Name = "Header", Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 68),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3, Parent = resultBody},
		{Theme.corner(24), Theme.gradient(S.lagoon.top, S.lagoon.bottom)})
	new("Frame", {Name = "HeaderFoot", Position = UDim2.new(0, 0, 1, -24), Size = UDim2.new(1, 0, 0, 24),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3, Parent = header},
		{Theme.gradient(S.lagoon.base, S.lagoon.bottom)})
	new("Frame", {Name = "HeaderGloss", Position = UDim2.new(0, 110, 0, 7), Size = UDim2.new(1, -220, 0, 12),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = .72, BorderSizePixel = 0, ZIndex = 4,
		Parent = header}, {Theme.corner()})
	new("Frame", {Name = "HeaderRule", Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = INK, BorderSizePixel = 0, ZIndex = 4, Parent = resultBody})
	local resultLabel = display({Name = "ResultLabel", Position = UDim2.fromOffset(104, 12), Size = UDim2.new(1, -170, 0, 50),
		Text = "", TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
		Parent = resultBody}, 3.5)
	sizeLimit(resultLabel, 16, 40)
	local resultMedallion = Theme.medallion(resultHolder, 100, 10)
	resultMedallion.root.Position = UDim2.fromOffset(46, 38)

	local close = Theme.button(resultBody, "X", "coral", UDim2.fromOffset(42, 42), 7)
	close.Name = "DismissResult"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -16, 0, 14)
	close.Activated:Connect(function() resultHolder.Visible = false end)

	local stats = new("Frame", {Name = "ThrowStats", Position = UDim2.fromOffset(20, 90), Size = UDim2.new(1, -40, 0, 92),
		BackgroundTransparency = 1, ZIndex = 5, Parent = resultBody}, {new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder})})
	for index, spec in {{"DISTANCE", "lagoon", IMG.Throw}, {"SKIPS", "lime", IMG.Splash}, {"SCORE", "sun", IMG.Sparkle}} do
		local tone = S[spec[2]]
		local tile = new("Frame", {Name = spec[1], LayoutOrder = index, Size = UDim2.new(1 / 3, -8, 1, 0),
			BackgroundTransparency = 1, ZIndex = 5, Parent = stats})
		new("UIScale", {Name = "Pop", Parent = tile})
		new("Frame", {Name = "Lip", Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 1, -5), BackgroundColor3 = INK,
			BorderSizePixel = 0, ZIndex = 5, Parent = tile}, {Theme.corner(18)})
		local face = new("Frame", {Name = "Face", Size = UDim2.new(1, 0, 1, -5), BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0, ZIndex = 6, Parent = tile}, {Theme.corner(18), Theme.stroke(INK, 3),
			Theme.gradient(tone.top, tone.bottom)})
		new("Frame", {Name = "Gloss", Position = UDim2.new(0, 10, 0, 5), Size = UDim2.new(1, -20, 0, 12),
			BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = .65, BorderSizePixel = 0, ZIndex = 7,
			Parent = face}, {Theme.corner()})
		new("ImageLabel", {Name = "Icon", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -12),
			Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1, Image = spec[3], ZIndex = 9, Parent = tile})
		local value = display({Name = "Value", Position = UDim2.fromOffset(6, 12), Size = UDim2.new(1, -12, 0, 40),
			Text = "0", TextColor3 = Color3.new(1, 1, 1), ZIndex = 8, Parent = tile}, 2.8)
		sizeLimit(value, 12, 36)
		display({Name = "Caption", Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 18), Text = spec[1],
			TextSize = 15, TextColor3 = Color3.new(1, 1, 1), ZIndex = 8, Parent = tile}, 1.8)
	end

	new("Frame", {Name = "ResultDetail", Position = UDim2.fromOffset(16, 194), Size = UDim2.new(1, -32, 0, 30),
		BackgroundTransparency = 1, ZIndex = 5, Parent = resultBody}, {new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})})
	local breakdown = Theme.label({Name = "ScoreBreakdown", Position = UDim2.fromOffset(20, 230), Size = UDim2.new(1, -40, 0, 18),
		Text = "", TextColor3 = Theme.InkSoft, ZIndex = 5, Parent = resultBody})
	sizeLimit(breakdown, 9, 14)
	local bestDelta = display({Name = "BestDelta", Position = UDim2.fromOffset(20, 250), Size = UDim2.new(1, -40, 0, 24),
		Text = "", TextColor3 = S.lagoon.text, ZIndex = 5, Parent = resultBody})
	sizeLimit(bestDelta, 12, 20)
	local nextRow = new("Frame", {Name = "NextRow", Position = UDim2.fromOffset(44, 280), Size = UDim2.new(1, -88, 0, 36),
		BackgroundTransparency = 1, ZIndex = 5, Parent = resultBody})
	local nextTarget = display({Name = "NextTarget", Size = UDim2.new(1, 0, 0, 18), Text = "", TextColor3 = INK,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = nextRow})
	sizeLimit(nextTarget, 9, 15)
	local nextTrack = track(nextRow, "NextTrack", 11, 5)
	nextTrack.Position = UDim2.fromOffset(0, 22)

	local hint = Theme.label({Name = "NextThrowHint", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -20),
		Size = UDim2.new(1, -48, 0, 20), Text = "HOLD CLICK OR E TO GO AGAIN", TextColor3 = Theme.InkSoft,
		ZIndex = 5, Parent = resultBody})
	sizeLimit(hint, 9, 14)
	local replay = Theme.button(resultBody, "STONE CAM", "lagoon", UDim2.fromOffset(138, 42), 7)
	replay.Name = "StoneCamReplay"
	replay.AnchorPoint = Vector2.new(1, 1)
	replay.Position = UDim2.new(1, -18, 1, -12)
	replay.Visible = false

	-- ---- Responsive scaling ------------------------------------------------
	local self: any
	local function fitViewport()
		local camera = workspace.CurrentCamera
		if not camera then return end
		local viewport = camera.ViewportSize
		local scale = (Theme.viewScale())
		local compact = viewport.X < 600
		for _, root in {comboHolder, distancePill, chargeCard} do
			local uiScale = root:FindFirstChild("Scale") :: UIScale
			uiScale:SetAttribute("RestScale", scale)
			uiScale.Scale = scale
		end
		distancePill.Position = UDim2.new(.5, 12, 0, 20 + 110 * scale)
		chargeCard.Position = UDim2.fromScale(.5, if compact then .62 else HUD.Theme.ChargeY)
		local qualityScale = qualityPanel:FindFirstChild("PopScale") :: UIScale
		qualityScale:SetAttribute("RestScale", scale)
		qualityScale.Scale = scale
		local perfectScale = perfectArt:FindFirstChild("PopScale") :: UIScale
		perfectScale:SetAttribute("RestScale", scale)
		perfectScale.Scale = scale
		resultHolder.Position = UDim2.fromScale(.5, if compact then .5 else .46)
		local resultScale = resultHolder:FindFirstChild("ViewportScale") :: UIScale
		local fit = math.clamp(math.min((viewport.Y - 70) / RESULT_H, (viewport.X - 24) / RESULT_W), .5, 1)
		resultScale:SetAttribute("RestScale", fit)
		resultScale.Scale = fit
		if self then self.hudScale = scale end
	end
	fitViewport()
	local viewportConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitViewport)
	gui.Destroying:Once(function() viewportConnection:Disconnect() end)

	-- Level/XP presentation is an editable StarterGui.MainHUD hierarchy.
	local levelHolder = playerGui:WaitForChild("MainHUD"):WaitForChild("LevelHolder") :: Frame
	local levelLabel = levelHolder:WaitForChild("LevelLabel") :: TextLabel
	local xpTrack = levelHolder:WaitForChild("XpTrack") :: Frame
	local xpFill = xpTrack:WaitForChild("XpFill") :: Frame
	local xpLabel = xpTrack:WaitForChild("XpLabel") :: TextLabel

	-- Result sunburst spin while visible.
	local sunburst = resultHolder:FindFirstChild("Sunburst") :: ImageLabel
	local spin = RunService.RenderStepped:Connect(function(dt)
		if resultHolder.Visible and sunburst.Visible and not reducedMotion() then
			sunburst.Rotation += dt * 14
		end
	end)
	gui.Destroying:Once(function() spin:Disconnect() end)

	self = setmetatable({
		gui = gui,
		fxLayer = fxLayer,
		chargeCard = chargeCard,
		chargeBar = chargeBar,
		chargeFill = chargeFill,
		chargeStroke = chargeStroke,
		sweetBand = sweetBand,
		needle = needle,
		releaseMarker = releaseMarker,
		chargeLabel = chargeLabel,
		chargeReadout = chargeReadout,
		chargeMedallion = chargeMedallion,
		comboHolder = comboHolder,
		comboLabel = comboLabel,
		comboMedallion = comboMedallion,
		distancePill = distancePill,
		perfectLabel = perfectLabel,
		perfectArt = perfectArt,
		perfectFlash = perfectFlash,
		perfectRing = perfectRing,
		distanceLabel = distanceLabel,
		resultHolder = resultHolder,
		resultLabel = resultLabel,
		resultMedallion = resultMedallion,
		levelHolder = levelHolder,
		levelLabel = levelLabel,
		xpFill = xpFill,
		xpLabel = xpLabel,
		hudScale = (Theme.viewScale()),
		perfectToken = 0,
		resultToken = 0,
		releaseToken = 0,
		releaseActive = false,
		flightActive = false,
		uiFadeToken = 0,
		uiSnapshots = {},
		uiTweens = {},
		latestSkips = 0,
		milestoneToken = 0,
		milestoneShowing = false,
	}, ThrowHud)
	return self :: ThrowHud
end

-- ============================================================================
-- Charge meter
-- ============================================================================

local function setChargeTone(self: ThrowHud, labelColor: Color3, swatchName: string, icon: string)
	self.chargeLabel.TextColor3 = labelColor
	self.chargeMedallion.setIcon(icon, S[swatchName])
end

function ThrowHud.showCharge(self: ThrowHud)
	self.resultToken += 1
	self.resultHolder.Visible = false
	self.perfectToken += 1
	self.perfectArt.Visible = false
	self.perfectFlash.Visible = false
	self.perfectRing.Visible = false
	local qualityPanel = self.gui:FindFirstChild("QualityCallout") :: Frame?
	if qualityPanel then qualityPanel.Visible = false end
	self.releaseToken += 1
	self.releaseActive = false
	self.releaseMarker.Visible = false
	self.needle.Visible = true
	self.chargeCard.Visible = true
	pop(self.chargeCard:FindFirstChild("Scale") :: UIScale, .86)
	self.chargeFill.Size = UDim2.new(0, 0, 1, 0)
	self.chargeFill.BackgroundColor3 = COLOR_CHARGE
	self.needle.Position = UDim2.new(0, 0, .5, 0)
	self.chargeLabel.Text = "LINE UP YOUR SKIP"
	setChargeTone(self, INK, "lagoon", "throw")
	local lastInput = UserInputService:GetLastInputType()
	local instruction = self.chargeCard:FindFirstChild("ThrowInstruction", true) :: TextLabel
	instruction.Text = if UserInputService.MouseEnabled and lastInput ~= Enum.UserInputType.Touch
		and not string.find(lastInput.Name, "Gamepad") then "MOVE CURSOR TO AIM  •  RELEASE IN THE ZONE"
		else "HOLD TO CHARGE  •  RELEASE IN THE ZONE"
	self.chargeReadout.Text = "0%"
	self.chargeStroke.Color = RIM_REST
	self.chargeStroke.Transparency = 0
	self.chargeStroke.Thickness = 3
	-- Zone stays hidden until the server tells us where it rolled.
	self.sweetBand.Size = UDim2.fromScale(0, 1)
	self.sweetBand.Visible = false
end

function ThrowHud.setSweetZone(self: ThrowHud, minBound: number, maxBound: number)
	self.sweetBand.Position = UDim2.fromScale(minBound, 0)
	self.sweetBand.Size = UDim2.fromScale(0, 1)
	self.sweetBand.Visible = true
	TweenService:Create(self.sweetBand, TweenInfo.new(if reducedMotion() then 0 else .18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(maxBound - minBound, 1),
	}):Play()
end

--[[
	`strain` (optional, 0-1) is ThrowConfig.strainFraction(elapsed): how long
	the hold has gone on past its free grace window. It only ever touches
	presentation here: the rim pulses and reddens. The visible needle
	always matches the actual charge fraction, including on the return sweep.
]]
function ThrowHud.updateCharge(self: ThrowHud, fraction: number, inSweetZone: boolean, strain: number?)
	if self.releaseActive or not self.chargeCard.Visible then return end
	local strainAmount = math.clamp(strain or 0, 0, 1)
	local renderedFraction = math.clamp(fraction, 0, 1)

	self.chargeFill.Size = UDim2.fromScale(renderedFraction, 1)
	-- The needle remains exact so the visible release timing matches the server.
	self.needle.Position = UDim2.new(renderedFraction, 0, .5, 0)
	self.chargeReadout.Text = string.format("%d%%", math.floor(renderedFraction * 100 + .5))

	if inSweetZone then
		self.chargeFill.BackgroundColor3 = COLOR_PERFECT
		self.chargeLabel.Text = "RELEASE NOW!"
		setChargeTone(self, S.lime.text, "lime", "check")
	elseif strainAmount >= HUD.StrainWarningThreshold then
		self.chargeFill.BackgroundColor3 = COLOR_CHARGE
		self.chargeLabel.Text = "SLIPPING!"
		setChargeTone(self, S.coral.text, "coral", "throw")
	elseif strainAmount > 0 then
		self.chargeFill.BackgroundColor3 = COLOR_CHARGE
		self.chargeLabel.Text = "HOLD STEADY..."
		setChargeTone(self, INK, "sun", "throw")
	else
		self.chargeFill.BackgroundColor3 = COLOR_CHARGE
		self.chargeLabel.Text = "FIND THE GREEN ZONE"
		setChargeTone(self, INK, "lagoon", "throw")
	end

	local pulse = if reducedMotion() then 0 else (math.sin(os.clock() * math.pi * 2 * HUD.StrainPulseHz) + 1) / 2
	self.chargeStroke.Color = (if inSweetZone then S.lime.deep else RIM_REST):Lerp(COLOR_STRAIN, strainAmount)
	self.chargeStroke.Transparency = 0
	self.chargeStroke.Thickness = 3 + 2.5 * strainAmount * pulse
	local medallionScale = self.chargeMedallion.scale :: UIScale
	medallionScale.Scale = if inSweetZone and not reducedMotion() then 1.08 + .06 * math.sin(os.clock() * 18) else 1
end

function ThrowHud.hideCharge(self: ThrowHud)
	self.releaseToken += 1
	self.releaseActive = false
	self.releaseMarker.Visible = false
	self.chargeCard.Visible = false
end

-- Immediate local acknowledgment, followed by server-confirmed quality only.
-- Starting another charge or cancelling it invalidates the delayed hide.
function ThrowHud.showRelease(self: ThrowHud, fraction: number, quality: string?)
	self.releaseToken += 1
	local token = self.releaseToken
	self.releaseActive = true
	local releasedFraction = math.clamp(fraction, 0, 1)
	self.chargeCard.Visible = true
	self.needle.Visible = false
	self.releaseMarker.Visible = true
	self.releaseMarker.Position = UDim2.new(releasedFraction, 0, .5, 0)
	self.releaseMarker.BackgroundColor3 = HUD.ReleasePendingColor
	self.chargeFill.Size = UDim2.fromScale(releasedFraction, 1)
	self.chargeFill.BackgroundColor3 = HUD.ReleasePendingColor
	self.chargeLabel.Text = "RELEASED"
	setChargeTone(self, INK, "stone", "throw")
	self.chargeStroke.Color = RIM_REST
	self.chargeStroke.Thickness = 3
	if quality then
		self:confirmRelease(nil, quality)
	end
	task.delay(HUD.ReleaseHoldTime, function()
		if self.releaseToken == token and self.gui.Parent then
			self:hideCharge()
		end
	end)
end

-- Call only for the matching server launch. A late confirmation cannot revive
-- a hidden release marker or overwrite an in-progress charge.
function ThrowHud.confirmRelease(self: ThrowHud, fraction: number?, quality: string)
	if not self.releaseActive or not self.chargeCard.Visible then return end
	local style = QUALITY_STYLES[quality]
	if not style then return end
	if fraction ~= nil then
		local confirmedFraction = math.clamp(fraction, 0, 1)
		TweenService:Create(self.releaseMarker, TweenInfo.new(.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(confirmedFraction, 0, .5, 0),
		}):Play()
		TweenService:Create(self.chargeFill, TweenInfo.new(.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(confirmedFraction, 1),
		}):Play()
	end
	local look = QUALITY_LOOK[quality] or QUALITY_LOOK.normal
	self.releaseMarker.BackgroundColor3 = style.color
	self.chargeFill.BackgroundColor3 = style.color
	self.chargeLabel.Text = style.title
	setChargeTone(self, S[look.swatch].text, look.swatch, look.icon)
end

-- ============================================================================
-- Flight
-- ============================================================================

-- Only root visibility changes at launch/return. Fading every descendant
-- (including closed inventory/shop menus) created thousands of tweens and
-- stalled the frame twice per throw.
function ThrowHud.setFlightMode(self: ThrowHud, active: boolean)
	if self.flightActive == active then return end
	self.flightActive = active
	self.uiFadeToken += 1
	for _, tween in self.uiTweens do tween:Cancel() end
	table.clear(self.uiTweens)
	if not active then
		for root, state in self.uiSnapshots do
			if root.Parent then (root :: any)[state.property] = state.visible end
		end
		table.clear(self.uiSnapshots)
		local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		local mainHud = playerGui and playerGui:FindFirstChild("MainHUD")
		if mainHud then mainHud:SetAttribute("SkipFlightActive", false) end
		return
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return end
	local roots: {Instance} = {self.levelHolder}
	local mainHud = playerGui:FindFirstChild("MainHUD")
	if mainHud then
		for _, name in {"LeftNav", "StatsBar", "inventoryui", "shopui", "dailyrewardsopenFrame",
			"settingsopenframe", "settingsui", "upgradesui", "Inventory", "questsopenFrame",
			"playtimerewardsopenFrame", "SummonGroveQuickButton"} do
			local root = mainHud:FindFirstChild(name)
			if root and root:IsA("GuiObject") then table.insert(roots, root) end
		end
	end
	for _, root in playerGui:GetChildren() do
		if root:IsA("ScreenGui") and (root.Name == "DailyRewardsUI" or root.Name == "PlaytimeGiftsUI" or root.Name == "QuestsUI"
			or root.Name == "HotbarGui" or root.Name == "SummonPromptUI") then
			table.insert(roots, root)
		end
	end
	for _, root in roots do
		local property = if root:IsA("ScreenGui") then "Enabled" else "Visible"
		self.uiSnapshots[root] = {property = property, visible = (root :: any)[property], items = {}}
		(root :: any)[property] = false
	end
	if mainHud then mainHud:SetAttribute("SkipFlightActive", true) end
end

function ThrowHud.dismissResult(self: ThrowHud)
	self.resultToken += 1
	self.resultHolder.Visible = false
end

--[[
	Shows the server-confirmed ThrowConfig quality bucket. We display words
	instead of invented accuracy percentages; normal throws are restrained.
]]
function ThrowHud.showQualityCallout(self: ThrowHud, quality: string)
	local style = QUALITY_STYLES[quality]
	if not style then return end
	local panel = self.gui:FindFirstChild("QualityCallout") :: Frame?
	if not panel then return end
	self.perfectToken += 1
	local token = self.perfectToken
	self.perfectLabel.Visible = false

	if quality == "perfect" then playPerfectPopSounds() end
	if quality == "perfect" and not reducedMotion() then
		panel.Visible = false
		local art = self.perfectArt
		local flash = self.perfectFlash
		local ring = self.perfectRing
		local ringStroke = ring:FindFirstChild("RingStroke") :: UIStroke?
		local artScale = art:FindFirstChild("PopScale") :: UIScale?
		if not artScale or not ringStroke then return end
		local rest = restScale(artScale)
		flash.Visible = Players.LocalPlayer:GetAttribute("ReducedThrowFlashes") ~= true
		flash.BackgroundTransparency = HUD.PerfectFlashPeakTransparency
		TweenService:Create(flash, TweenInfo.new(HUD.PerfectFlashOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()
		task.delay(HUD.PerfectFlashOutTime, function()
			if self.perfectToken == token then flash.Visible = false end
		end)

		-- Under the skip counter + distance pill.
		local badgeTop = 20 + (110 + 34 + 10) * self.hudScale
		ring.Position = UDim2.new(.5, 12, 0, badgeTop + 56 * rest)
		ring.Visible = true
		ring.Size = UDim2.fromOffset(HUD.PerfectRingStartSize, HUD.PerfectRingStartSize)
		ringStroke.Transparency = 0
		ringStroke.Thickness = HUD.PerfectRingThickness
		TweenService:Create(ring, TweenInfo.new(HUD.PerfectRingOutTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(HUD.PerfectRingEndSize, HUD.PerfectRingEndSize),
		}):Play()
		TweenService:Create(ringStroke, TweenInfo.new(HUD.PerfectRingOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
			Thickness = 1,
		}):Play()
		task.delay(HUD.PerfectRingOutTime, function()
			if self.perfectToken == token then ring.Visible = false end
		end)

		art.Visible = true
		art.GroupTransparency = 1
		art.Position = UDim2.new(.5, 12, 0, badgeTop - 18)
		art.Rotation = -8
		artScale.Scale = HUD.PerfectArtPopScale * rest
		TweenService:Create(art, TweenInfo.new(HUD.PerfectArtInTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			GroupTransparency = 0,
			Rotation = 0,
			Position = UDim2.new(.5, 12, 0, badgeTop),
		}):Play()
		TweenService:Create(artScale, TweenInfo.new(HUD.PerfectArtInTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = rest,
		}):Play()
		for _, name in {"Sparkle1", "Sparkle2"} do
			local sparkle = art:FindFirstChild(name) :: ImageLabel?
			if sparkle then
				sparkle.Rotation = 0
				TweenService:Create(sparkle, TweenInfo.new(HUD.PerfectArtHoldTime, Enum.EasingStyle.Linear), {Rotation = 180}):Play()
			end
		end
		task.delay(HUD.PerfectArtInTime, function()
			if self.perfectToken ~= token or not art.Parent then return end
			artScale.Scale = HUD.PerfectArtPunchScale * rest
			TweenService:Create(artScale, TweenInfo.new(HUD.PerfectArtPunchTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = rest,
			}):Play()
		end)
		task.delay(HUD.PerfectArtHoldTime, function()
			if self.perfectToken ~= token or not art.Parent then return end
			local out = TweenService:Create(art, TweenInfo.new(HUD.PerfectArtOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				GroupTransparency = 1,
				Position = UDim2.new(.5, 12, 0, badgeTop - 10),
			})
			out:Play()
			out.Completed:Once(function()
				if self.perfectToken == token then art.Visible = false end
			end)
		end)
		return
	end

	self.perfectArt.Visible = false
	local title = panel:FindFirstChild("Title", true) :: TextLabel?
	local subtitle = panel:FindFirstChild("Subtitle", true) :: TextLabel?
	local popScale = panel:FindFirstChild("PopScale") :: UIScale?
	local medallion = panel:FindFirstChild("Medallion") :: Frame?
	if not title or not subtitle or not popScale or not medallion then return end
	local look = QUALITY_LOOK[quality] or QUALITY_LOOK.normal
	local tone = S[look.swatch]
	title.Text, subtitle.Text = style.title, style.subtitle
	title.TextColor3 = tone.top:Lerp(tone.bottom, .35)
	local icon = medallion:FindFirstChild("Icon", true) :: ImageLabel?
	local disc = medallion:FindFirstChild("Disc", true)
	local discGradient = disc and disc:FindFirstChildOfClass("UIGradient")
	if icon then icon.Image = (Theme.icon(look.icon)) end
	if discGradient then discGradient.Color = ColorSequence.new(tone.top:Lerp(Color3.new(1, 1, 1), .25), tone.bottom) end
	panel.Position = if reducedMotion() then UDim2.new(.5, 0, HUD.QualityY, 0) else UDim2.new(0, -HUD.QualityMaxWidth, HUD.QualityY, 0)
	panel.Visible = true
	pop(popScale, HUD.QualityPopScale, HUD.QualityPopTime)
	TweenService:Create(panel, TweenInfo.new(if reducedMotion() then 0 else HUD.QualityInTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(.5, 0, HUD.QualityY, 0),
	}):Play()
	local holdTime = if quality == "normal" then HUD.NormalQualityTime else HUD.QualityTime
	task.delay(holdTime, function()
		if self.perfectToken ~= token or not panel.Parent then return end
		if reducedMotion() then panel.Visible = false return end
		local out = TweenService:Create(panel, TweenInfo.new(HUD.QualityOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0, -HUD.QualityMaxWidth, HUD.QualityY, 0),
		})
		out:Play()
		out.Completed:Once(function()
			if self.perfectToken == token then panel.Visible = false end
		end)
	end)
end

-- Thin alias kept for any existing call site that only knows about "perfect".
function ThrowHud.showPerfect(self: ThrowHud)
	self:showQualityCallout("perfect")
end

function ThrowHud.setCombo(self: ThrowHud, count: number, tier: number)
	count = math.max(0, math.floor(count))
	local previousCount = self.latestSkips
	self.latestSkips = count
	local wasVisible = self.comboHolder.Visible
	self.comboHolder.Visible = true
	local holderScale = self.comboHolder:FindFirstChild("Scale") :: UIScale
	if not wasVisible then pop(holderScale, .8) end
	local stage = ThrowConfig.getSkipMilestone(count)
	local stageColor = if stage then stage.Color else S.lagoon.top
	self.comboLabel.TextColor3 = if stage then stage.Color else HUD.Theme.GoldLight
	self.comboMedallion.discGradient.Color = ColorSequence.new(stageColor:Lerp(Color3.new(1, 1, 1), .3), stageColor:Lerp(INK, .15))

	local body = self.comboHolder:FindFirstChild("Body", true) :: Frame
	local hint = body:FindFirstChild("MilestoneHint") :: TextLabel
	local progressTrack = body:FindFirstChild("MilestoneProgress") :: Frame
	local fill = progressTrack:FindFirstChild("Fill") :: Frame
	local nextStage = nextMilestone(count)
	hint.Text = if nextStage then string.format("%d TO %s", nextStage.Skips - count, nextStage.Name)
		else "LEGENDARY • KEEP GOING"
	fill.BackgroundColor3 = if nextStage then nextStage.Color else stageColor
	local previous = if stage then stage.Skips else 0
	local progress = if nextStage then (count - previous) / (nextStage.Skips - previous) else 1
	TweenService:Create(fill, TweenInfo.new(if reducedMotion() then 0 else .16), {
		Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1),
	}):Play()
	-- A milestone uses the counter's existing space, never another stacked panel.
	if stage and count >= stage.Skips and previousCount < stage.Skips then
		self.milestoneToken += 1
		local token = self.milestoneToken
		self.milestoneShowing = true
		self.comboLabel.Text = stage.Name
		pop(holderScale, 1.18, .35)
		local medallion = self.comboMedallion.root :: Frame
		local center = medallion.AbsolutePosition + medallion.AbsoluteSize / 2 - self.fxLayer.AbsolutePosition
		sparkleBurst(self.fxLayer, center, 10, stage.Color, 90)
		task.delay(.72, function()
			if self.milestoneToken ~= token or not self.gui.Parent then return end
			self.milestoneShowing = false
			self.comboLabel.Text = string.format("%d SKIPS", self.latestSkips)
		end)
	elseif not self.milestoneShowing then
		self.comboLabel.Text = string.format("%d SKIPS", count)
	end
	if count ~= previousCount and count > 0 and not reducedMotion() then
		-- Each skip bumps the number, like a stone kissing the water.
		local bump = self.comboLabel:FindFirstChild("Bump") :: UIScale
		bump.Scale = 1.22
		TweenService:Create(bump, TweenInfo.new(.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		local medallionScale = self.comboMedallion.scale :: UIScale
		medallionScale.Scale = 1.15
		TweenService:Create(medallionScale, TweenInfo.new(.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	end
end

function ThrowHud.setDistance(self: ThrowHud, studs: number)
	if not self.distancePill.Visible then
		self.distancePill.Visible = true
		pop(self.distancePill:FindFirstChild("Scale") :: UIScale, .7)
	end
	self.distanceLabel.Text = string.format("%s STUDS", numberText(studs))
end

function ThrowHud.clearFlight(self: ThrowHud)
	self.milestoneToken += 1
	self.latestSkips = 0
	self.milestoneShowing = false
	self.comboHolder.Visible = false
	self.distancePill.Visible = false
end

function ThrowHud.setLevel(self: ThrowHud, level: number, into: number, need: number)
	self.levelLabel.Text = "LEVEL " .. level
	if need <= 0 then
		-- Max level: a full bar reads better than an empty one.
		self.xpFill.Size = UDim2.fromScale(1, 1)
		self.xpLabel.Text = "MAX"
		return
	end
	self.xpFill.Size = UDim2.fromScale(math.clamp(into / need, 0, 1), 1)
	self.xpLabel.Text = string.format("%d / %d XP", into, need)
end

-- ============================================================================
-- Result card
-- ============================================================================

local function paintHeader(holder: Frame, swatchName: string)
	local tone = S[swatchName]
	local header = holder:FindFirstChild("Header", true) :: Frame
	local gradient = header:FindFirstChildOfClass("UIGradient") :: UIGradient
	gradient.Color = ColorSequence.new(tone.top, tone.bottom)
	local foot = header:FindFirstChild("HeaderFoot") :: Frame
	local footGradient = foot:FindFirstChildOfClass("UIGradient") :: UIGradient
	footGradient.Color = ColorSequence.new(tone.base, tone.bottom)
end

function ThrowHud.showResult(self: ThrowHud, result: {
	spinStrengthGain: number?,
	distance: number,
	skips: number,
	score: number,
	isPerfect: boolean,
	quality: string?,
	endReason: string?,
	previousBestDistance: number?,
	bestDistance: number?,
	breakdown: {distance: number, skips: number, perfect: number, style: number?}?,
	}, isRecord: boolean)
	self.resultToken += 1
	local token = self.resultToken
	self.perfectToken += 1
	self.perfectArt.Visible = false
	self.perfectFlash.Visible = false
	self.perfectRing.Visible = false
	local qualityPanel = self.gui:FindFirstChild("QualityCallout") :: Frame?
	if qualityPanel then qualityPanel.Visible = false end

	local holder = self.resultHolder
	local quality = result.quality or (if result.isPerfect then "perfect" else "normal")
	local noSkips = result.skips == 0
	local headline = if isRecord then "NEW BEST!"
		elseif noSkips then "NO SKIPS"
		elseif quality == "perfect" then "PERFECT RUN"
		elseif quality == "nearMiss" then "CLEAN RUN"
		elseif quality == "weak" then "OFF-TARGET RELEASE"
		else "NICE SKIPS"
	local detail = ""
	if result.endReason == "collision" then
		detail = "HIT AN OBSTACLE"
	elseif result.endReason == "outOfBounds" then
		detail = "LEFT THE WATER"
	elseif noSkips and quality == "weak" then
		detail = "AIM FOR THE ZONE"
	end
	local interrupted = result.endReason == "interrupted" or result.endReason == "removed"
	if interrupted then
		headline = if isRecord then "NEW BEST!" else "THROW ENDED"
		detail = ""
	end
	self.resultLabel.Text = headline

	-- Outcome colour + medallion.
	local swatchName, iconImage = "lagoon", IMG.Throw
	if isRecord then swatchName, iconImage = "sun", IMG.Sparkle
	elseif interrupted then swatchName, iconImage = "stone", IMG.Throw
	elseif noSkips or quality == "weak" then swatchName, iconImage = "coral", IMG.Splash
	elseif quality == "perfect" then swatchName, iconImage = "lime", IMG.Check
	end
	paintHeader(holder, swatchName)
	local tone = S[swatchName]
	self.resultMedallion.icon.Image = iconImage
	self.resultMedallion.discGradient.Color = ColorSequence.new(tone.top:Lerp(Color3.new(1, 1, 1), .25), tone.bottom)
	local sunburst = holder:FindFirstChild("Sunburst") :: ImageLabel
	sunburst.Visible = isRecord

	local stats = holder:FindFirstChild("ThrowStats", true) :: Frame
	local distanceValue = (stats:FindFirstChild("DISTANCE") :: Frame):FindFirstChild("Value") :: TextLabel
	local skipValue = (stats:FindFirstChild("SKIPS") :: Frame):FindFirstChild("Value") :: TextLabel
	local scoreValue = (stats:FindFirstChild("SCORE") :: Frame):FindFirstChild("Value") :: TextLabel
	local function setValues(alpha: number)
		distanceValue.Text = numberText(result.distance * alpha)
		skipValue.Text = numberText(result.skips * alpha)
		scoreValue.Text = "+" .. numberText(result.score * alpha)
	end
	setValues(if reducedMotion() then 1 else 0)

	-- Chips: release quality, milestone / end reason, spin strength reward.
	local chips = holder:FindFirstChild("ResultDetail", true) :: Frame
	for _, child in chips:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local qualityStyle = QUALITY_STYLES[quality]
	local look = QUALITY_LOOK[quality] or QUALITY_LOOK.normal
	local releaseName = if qualityStyle then qualityStyle.title else string.upper(quality)
	chip(chips, releaseName .. " RELEASE", S[look.swatch].bottom, 1)
	local milestone = ThrowConfig.getSkipMilestone(result.skips)
	if detail ~= "" then
		chip(chips, detail, S.coral.bottom, 2)
	elseif milestone then
		chip(chips, milestone.Name, milestone.Color:Lerp(INK, .12), 2)
	end
	-- Reward is server-authored in ThrowEnded.
	local spinGain = result.spinStrengthGain
	if typeof(spinGain) == "number" and ProgressionConfig.isFinite(spinGain) and spinGain > 0 then
		chip(chips, "+" .. ProgressionConfig.formatStrength(spinGain :: number) .. " SPIN STRENGTH", S.grape.bottom, 3)
	end

	local distancePoints = math.floor(result.distance * ThrowConfig.ScorePerStud)
	local skipPoints = math.floor(result.skips * ThrowConfig.ScorePerSkip)
	local perfectPoints = math.max(0, result.score - distancePoints - skipPoints)
	if result.breakdown then
		distancePoints, skipPoints, perfectPoints = result.breakdown.distance, result.breakdown.skips, result.breakdown.perfect
	end
	local breakdown = holder:FindFirstChild("ScoreBreakdown", true) :: TextLabel
	breakdown.Text = string.format("DISTANCE %s  +  SKIPS %s  +  BONUS %s",
		numberText(distancePoints), numberText(skipPoints), numberText(perfectPoints))
	if result.breakdown and (result.breakdown.style or 0) > 0 then
		breakdown.Text ..= "  +  STYLE " .. numberText(result.breakdown.style or 0)
	end
	local priorBest = result.previousBestDistance or result.bestDistance or 0
	local delta = math.floor(result.distance - priorBest)
	local bestLabel = holder:FindFirstChild("BestDelta", true) :: TextLabel
	bestLabel.Text = if isRecord and priorBest <= 0 then "YOUR FIRST PERSONAL BEST!"
		elseif isRecord then string.format("PERSONAL BEST  +%s STUDS", numberText(math.max(0, delta)))
		elseif delta < 0 then string.format("%s STUDS TO YOUR PERSONAL BEST", numberText(-delta))
		elseif priorBest > 0 then "PERSONAL BEST MATCHED" else "MAKE YOUR FIRST SKIP"
	bestLabel.TextColor3 = if isRecord then S.sun.text else S.lagoon.text

	local nextRow = holder:FindFirstChild("NextRow", true) :: Frame
	local targetLabel = nextRow:FindFirstChild("NextTarget") :: TextLabel
	local nextTrack = nextRow:FindFirstChild("NextTrack") :: Frame
	local nextFill = nextTrack:FindFirstChild("Fill") :: Frame
	local target = nextMilestone(result.skips)
	if target then
		targetLabel.Text = string.format("NEXT: %s  •  %d SKIPS  •  %d MORE", target.Name, target.Skips, target.Skips - result.skips)
		nextFill.BackgroundColor3 = target.Color
		nextFill.Size = UDim2.fromScale(0, 1)
		TweenService:Create(nextFill, TweenInfo.new(if reducedMotion() then 0 else .8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, 0, false, .35), {
			Size = UDim2.fromScale(math.clamp(result.skips / target.Skips, 0, 1), 1),
		}):Play()
	else
		targetLabel.Text = string.format("LEGENDARY REACHED  •  NEXT: %s STUDS",
			numberText(math.floor(math.max(result.bestDistance or 0, result.distance) / 100 + 1) * 100))
		nextFill.BackgroundColor3 = S.sun.top
		nextFill.Size = UDim2.fromScale(1, 1)
	end

	local hint = holder:FindFirstChild("NextThrowHint", true) :: TextLabel
	local replay = holder:FindFirstChild("StoneCamReplay", true) :: TextButton
	replay.Visible = isRecord and not reducedMotion()
	hint.TextXAlignment = if replay.Visible then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
	hint.Size = if replay.Visible then UDim2.new(1, -190, 0, 20) else UDim2.new(1, -48, 0, 20)
	local lastInput = UserInputService:GetLastInputType()
	hint.Text = if UserInputService.TouchEnabled and lastInput == Enum.UserInputType.Touch then "HOLD THROW TO GO AGAIN"
		elseif string.find(lastInput.Name, "Gamepad") then "HOLD RT TO GO AGAIN"
		else "HOLD CLICK OR E TO GO AGAIN"

	-- Entrance: card pops, medallion spins in, tiles land one after another.
	holder.Visible = true
	pop(holder:FindFirstChild("ViewportScale") :: UIScale, .82, .45)
	if not reducedMotion() then
		local medallionScale = self.resultMedallion.scale :: UIScale
		local medallionRoot = self.resultMedallion.root :: Frame
		medallionScale.Scale = .2
		medallionRoot.Rotation = -140
		TweenService:Create(medallionScale, TweenInfo.new(.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, .1), {Scale = 1}):Play()
		TweenService:Create(medallionRoot, TweenInfo.new(.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, .1), {Rotation = 0}):Play()
		for index, name in {"DISTANCE", "SKIPS", "SCORE"} do
			local tileScale = (stats:FindFirstChild(name) :: Frame):FindFirstChild("Pop") :: UIScale
			tileScale.Scale = .4
			TweenService:Create(tileScale, TweenInfo.new(.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, .12 + index * .08),
				{Scale = 1}):Play()
		end
		if isRecord then
			task.delay(.35, function()
				if self.resultToken ~= token or not holder.Visible then return end
				local root = self.resultMedallion.root :: Frame
				local center = root.AbsolutePosition + root.AbsoluteSize / 2 - self.fxLayer.AbsolutePosition
				sparkleBurst(self.fxLayer, center, 14, S.sun.top, 130)
			end)
		end
		task.spawn(function()
			local start = os.clock()
			local duration = if isRecord then 1.45 else 1.1
			while self.resultToken == token and self.gui.Parent and holder.Visible do
				if reducedMotion() then setValues(1) break end
				local alpha = math.clamp((os.clock() - start) / duration, 0, 1)
				setValues(1 - (1 - alpha) ^ 3)
				if alpha >= 1 then break end
				RunService.RenderStepped:Wait()
			end
		end)
	end

	local holdTime = if isRecord then math.max(8.5, RESULT_LABEL_TIME)
		elseif result.skips >= 20 then math.max(7, RESULT_LABEL_TIME)
		elseif noSkips then math.max(3.8, HUD.FailedResultTime)
		else math.max(5.5, RESULT_LABEL_TIME)
	task.delay(holdTime, function()
		if self.resultToken == token and self.gui.Parent then
			holder.Visible = false
		end
	end)
end

return ThrowHud
