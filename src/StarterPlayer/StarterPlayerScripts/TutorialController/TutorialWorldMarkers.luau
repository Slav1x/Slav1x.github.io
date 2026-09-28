--!strict
--[[
	TutorialWorldMarkers (client) -- world guidance in the Skipstone style

	pointTo(target, opts) draws:
	  * Beacon: a screen-projected medallion badge (icon + label bubble +
	    distance chip + pointer tail) that is always readable and a constant
	    size at any distance
	  * Edge badge: when the target is off screen / behind the camera, a
	    medallion rides an ellipse inside the screen with an arrow orbiting it
	  * Ground ripples: rings spreading on the floor at the destination
	  * Skip path: a faint dotted trail with a little stone hopping along it,
	    leaving a ripple at every bounce (while the player is far away)
	highlight(target) adds a pulsing Highlight once the instance streams in.

	Targets may be a Vector3, BasePart, Model or a function returning one;
	opts.fallback (Vector3) is used while StreamingEnabled has it streamed out.
	Everything is local-only and cleaned up by destroy().
]]

local Players = game:GetService("Players")

local Theme = require(script.Parent:WaitForChild("TutorialTheme"))

local new = Theme.new
local player = Players.LocalPlayer

export type Marker = {update: (number) -> (), destroy: () -> ()}

local WorldMarkers = {}
WorldMarkers.__index = WorldMarkers

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Resolves any supported target to (top-of-target position, instance?).
local function resolve(target: any, fallback: Vector3?): (Vector3?, Instance?)
	local value = if type(target) == "function" then target() else target
	if typeof(value) == "Vector3" then
		return value, nil
	elseif typeof(value) == "Instance" and value:IsDescendantOf(workspace) then
		if value:IsA("BasePart") then
			return value.Position + Vector3.new(0, value.Size.Y / 2, 0), value
		elseif value:IsA("Model") then
			local ok, cf, size = pcall(function() return value:GetBoundingBox() end)
			if ok and cf and size then
				return cf.Position + Vector3.new(0, size.Y / 2, 0), value
			end
		end
	end
	return fallback, nil
end
WorldMarkers.resolve = resolve

function WorldMarkers.new(layer: Instance)
	local self = setmetatable({}, WorldMarkers) :: any
	self.layer = layer
	local existing = workspace:FindFirstChild("TutorialGuides")
	if existing then existing:Destroy() end
	self.folder = new("Folder", {Name = "TutorialGuides", Parent = workspace})
	self.rayParams = RaycastParams.new()
	self.rayParams.FilterType = Enum.RaycastFilterType.Exclude
	self.rayParams.IgnoreWater = false
	self.rayParams.RespectCanCollide = true -- walkable surfaces, not trigger volumes
	return self
end

-- First walkable surface below (x, top, z), searching down to point.Y - 60.
-- `ignore` keeps the target itself (an NPC) from counting as floor.
function WorldMarkers:_ground(point: Vector3, top: number, ignore: Instance?): Vector3?
	local character = player.Character
	local filter: {Instance} = {self.folder}
	if character then table.insert(filter, character) end
	if ignore then table.insert(filter, ignore) end
	self.rayParams.FilterDescendantsInstances = filter
	local hit = workspace:Raycast(Vector3.new(point.X, top, point.Z), Vector3.new(0, -(top - point.Y) - 60, 0), self.rayParams)
	return hit and hit.Position
end

-- A flat, invisible plate carrying a SurfaceGui: crisp rings drawn in world space.
function WorldMarkers:_ripplePlate(size: number, color: Color3, rings: number): {part: BasePart, frames: {Frame}, strokes: {UIStroke}}
	local part = new("Part", {Name = "TutorialRipple", Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false,
		CastShadow = false, Transparency = 1, Size = Vector3.new(size, .05, size), Parent = self.folder})
	local surface = new("SurfaceGui", {Face = Enum.NormalId.Top, LightInfluence = 0, AlwaysOnTop = false,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 24, Parent = part})
	local frames, strokes = {}, {}
	for index = 1, rings do
		local frame = new("Frame", {AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
			Size = UDim2.fromScale(0, 0), BackgroundTransparency = 1, Parent = surface}, {Theme.corner()})
		local stroke = Theme.stroke(color, 10)
		stroke.Parent = frame
		frames[index], strokes[index] = frame, stroke
	end
	return {part = part, frames = frames, strokes = strokes}
end

function WorldMarkers:_scale(): number
	return (Theme.viewScale())
end

-- ============================================================================
-- pointTo
-- ============================================================================

function WorldMarkers:pointTo(target: any, opts: {[string]: any}): Marker
	local swatchName: string = opts.swatch or "sun"
	local tone = Theme.swatch(swatchName)
	local label: string = opts.label or "GO HERE"
	local nearLabel: string = opts.nearLabel or label
	local arriveRadius: number = opts.arriveRadius or 14
	local heightOffset: number = opts.height or 3
	local useTrail: boolean = opts.trail == true
	local showDistance: boolean = opts.showDistance ~= false
	local showRipples: boolean = opts.ripples ~= false
	local fallback: Vector3? = opts.fallback
	local iconName: string? = opts.icon

	-- Beacon ---------------------------------------------------------------
	local beacon = new("Frame", {Name = "TutorialBeacon", AnchorPoint = Vector2.new(.5, 1), Size = UDim2.fromOffset(220, 150),
		BackgroundTransparency = 1, Visible = false, ZIndex = 19, Parent = self.layer})
	local beaconScale = new("UIScale", {Parent = beacon})
	local bubble = Theme.bubble(beacon, label, swatchName, 24)
	bubble.Position = UDim2.new(.5, 0, 0, 44)
	local medallion = Theme.medallion(beacon, 60, 20)
	medallion.root.Position = UDim2.new(.5, 0, 1, -52)
	medallion.setIcon(iconName, tone)
	if not iconName then
		medallion.icon.Image = Theme.Images.Arrow
		medallion.icon.Size = UDim2.fromScale(.62, .62)
	end
	new("ImageLabel", {Name = "Tail", AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, 1, -24),
		Size = UDim2.fromOffset(26, 17), BackgroundTransparency = 1, Image = Theme.Images.Tail, ZIndex = 19, Parent = beacon})
	local chip = new("Frame", {Name = "Distance", AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(.5, 24, 1, -40),
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), BackgroundColor3 = Theme.Ink, BorderSizePixel = 0,
		ZIndex = 26, Parent = beacon}, {Theme.corner(), Theme.padding(8, 8, 0, 0)})
	local chipText = Theme.label({AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), FontFace = Theme.Display,
		TextSize = 14, TextColor3 = Color3.new(1, 1, 1), ZIndex = 27, Parent = chip})

	-- Edge badge -------------------------------------------------------------
	local edge = new("Frame", {Name = "TutorialEdgeBadge", AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(120, 120),
		BackgroundTransparency = 1, Visible = false, ZIndex = 21, Parent = self.layer})
	local edgeScale = new("UIScale", {Parent = edge})
	local edgeMedallion = Theme.medallion(edge, 58, 22)
	edgeMedallion.root.Position = UDim2.fromScale(.5, .5)
	edgeMedallion.setIcon(iconName, tone)
	if not iconName then
		edgeMedallion.icon.Image = Theme.Images.Arrow
		edgeMedallion.icon.Size = UDim2.fromScale(.62, .62)
	end
	local orbit = new("ImageLabel", {Name = "Pointer", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
		Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1, Image = Theme.Images.Arrow, ZIndex = 29, Parent = edge})
	local edgeChip = new("Frame", {Name = "Caption", AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, .5, 36),
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), BackgroundColor3 = Theme.Ink, BorderSizePixel = 0,
		ZIndex = 30, Parent = edge}, {Theme.corner(), Theme.padding(9, 9, 0, 0)})
	local edgeText = Theme.label({AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), FontFace = Theme.Display,
		TextSize = 14, TextColor3 = Color3.new(1, 1, 1), ZIndex = 31, Parent = edgeChip})
	local edgeRipples = Theme.ripples(edge, 2, tone.top, 21, 1.6, 26, 3)

	-- Ground ripples at the destination --------------------------------------
	local destination = if showRipples then self:_ripplePlate(16, Color3.new(1, 1, 1), 3) else nil
	local destinationFloor: Vector3? = nil
	local floorCheckedAt = -math.huge

	-- Skip path --------------------------------------------------------------
	local dots: {BasePart} = {}
	local DOT_SPACING = 4.5
	local DOT_MAX = 18
	local WATER = Theme.Swatches.lagoon
	local DOT_COLOR = Color3.fromRGB(60, 190, 255)
	local stone: BasePart? = nil
	local stoneTrail: Trail? = nil
	local splash: ParticleEmitter? = nil
	local splashPart: BasePart? = nil
	local bounceRipples: {{part: BasePart, frames: {Frame}, strokes: {UIStroke}, born: number}} = {}
	local stoneTravel = 0
	local stoneLastBounce = 0
	local pathPoints: {Vector3} = {}
	if useTrail then
		-- The stone: a mid blue-grey so it reads on both the white plaza and grass.
		stone = new("Part", {Name = "TutorialSkipStone", Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false,
			CastShadow = false, Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(128, 150, 178),
			Size = Vector3.new(1.5, 1.5, 1.5), Transparency = 1, Parent = self.folder},
			{new("SpecialMesh", {MeshType = Enum.MeshType.Sphere, Scale = Vector3.new(1.3, .55, 1)})})
		-- A short spray streak behind it while it flies.
		local top = new("Attachment", {Position = Vector3.new(0, .3, 0), Parent = stone})
		local bottom = new("Attachment", {Position = Vector3.new(0, -.3, 0), Parent = stone})
		stoneTrail = new("Trail", {Attachment0 = top, Attachment1 = bottom, FaceCamera = true, Lifetime = .22,
			LightEmission = .6, Color = ColorSequence.new(Color3.fromRGB(210, 244, 255), WATER.top),
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, .15), NumberSequenceKeypoint.new(1, 1)}),
			WidthScale = NumberSequence.new(1, .2), Enabled = false, Parent = stone})
		-- One reusable emitter: a burst of droplets at every bounce.
		splashPart = new("Part", {Name = "TutorialSplash", Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false,
			CastShadow = false, Transparency = 1, Size = Vector3.new(.2, .2, .2), Parent = self.folder})
		splash = new("ParticleEmitter", {Enabled = false, Texture = Theme.Images.Glow, LightEmission = .5, LightInfluence = .2,
			Color = ColorSequence.new(Color3.fromRGB(225, 248, 255), WATER.top),
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, .55), NumberSequenceKeypoint.new(1, .1)}),
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(.7, .25),
				NumberSequenceKeypoint.new(1, 1)}),
			Lifetime = NumberRange.new(.35, .6), Speed = NumberRange.new(7, 12), SpreadAngle = Vector2.new(32, 32),
			Acceleration = Vector3.new(0, -45, 0), Drag = 1, EmissionDirection = Enum.NormalId.Top, Parent = splashPart})
		for index = 1, 4 do
			local plate = self:_ripplePlate(8, WATER.top, 2) :: any
			plate.born = -math.huge
			bounceRipples[index] = plate
		end
	end
	local function hideRipple(ripple: {strokes: {UIStroke}})
		for _, stroke in ripple.strokes do stroke.Transparency = 1 end
	end
	local function hidePath()
		for _, dot in dots do dot.Transparency = 1 end
		if stone then stone.Transparency = 1 end
		if stoneTrail then stoneTrail.Enabled = false end
		for _, ripple in bounceRipples do hideRipple(ripple) end
		table.clear(pathPoints)
	end

	local clock = 0
	local pathAccumulator = 0
	local function update(dt: number)
		clock += dt
		local calm = Theme.reducedMotion()
		local position, instance = resolve(target, fallback)
		local root = rootPart()
		local camera = workspace.CurrentCamera
		local suppressed = self.suppressor ~= nil and self.suppressor()
		if not position or not camera or suppressed then
			beacon.Visible = false
			edge.Visible = false
			edgeRipples.setVisible(false)
			if destination then destination.part.Parent = nil end
			hidePath()
			return
		end
		local markerPosition = position + Vector3.new(0, heightOffset, 0)
		local distance = if root then (Vector3.new(position.X, root.Position.Y, position.Z) - root.Position).Magnitude else 0
		local near = distance <= arriveRadius
		local scale = self:_scale()

		-- Ground ripples (floor re-found occasionally: streaming, moving targets).
		if destination then
			destination.part.Parent = self.folder
			if clock - floorCheckedAt > 1 or not destinationFloor then
				floorCheckedAt = clock
				destinationFloor = self:_ground(position, position.Y + 6, instance) or position
			end
			local floor = destinationFloor :: Vector3
			destination.part.CFrame = CFrame.new(floor + Vector3.new(0, .08, 0))
			for index, frame in destination.frames do
				local phase = if calm then .5 else ((clock / 2) + (index - 1) / #destination.frames) % 1
				frame.Size = UDim2.fromScale(.2 + phase * .8, .2 + phase * .8)
				destination.strokes[index].Transparency = .1 + phase * .9
				destination.strokes[index].Thickness = 12 - phase * 6
			end
		end

		-- Beacon
		local text = if near then nearLabel else label
		Theme.setBubbleText(bubble, text)
		chip.Visible = showDistance and not near and root ~= nil
		chipText.Text = string.format("%dm", math.floor(distance))
		local viewportPoint, onScreen = camera:WorldToViewportPoint(markerPosition)
		local viewport = camera.ViewportSize
		local bob = if calm then 0 else math.sin(clock * 3.2) * 6
		beaconScale.Scale = scale
		beacon.Visible = onScreen and viewportPoint.Z > 0
		if beacon.Visible then
			local x, y = viewportPoint.X, viewportPoint.Y + bob * scale
			if self.avoid then
				local avoidPosition, avoidSize = self.avoid()
				if avoidPosition and avoidSize then
					local height, halfWidth = 150 * scale, 110 * scale
					local overlapsX = x + halfWidth > avoidPosition.X and x - halfWidth < avoidPosition.X + avoidSize.X
					if overlapsX and y - height < avoidPosition.Y + avoidSize.Y + 6 and y > avoidPosition.Y then
						y = avoidPosition.Y + avoidSize.Y + 6 + height
					end
				end
			end
			beacon.Position = UDim2.fromOffset(x, y)
			medallion.root.Rotation = if calm then 0 else math.sin(clock * 2.4) * 4
		end

		-- Edge badge
		local margin = 80 * scale
		local inside = onScreen and viewportPoint.Z > 0 and viewportPoint.X > margin * .5 and viewportPoint.X < viewport.X - margin * .5
			and viewportPoint.Y > margin * .5 and viewportPoint.Y < viewport.Y - margin * .5
		if inside or near then
			edge.Visible = false
			edgeRipples.setVisible(false)
		else
			local center = Vector2.new(viewport.X / 2, viewport.Y * .52)
			local point = Vector2.new(viewportPoint.X, viewportPoint.Y)
			local direction = point - viewport / 2
			if viewportPoint.Z < 0 then direction = -direction end
			if direction.Magnitude < 1 then direction = Vector2.new(0, 1) end
			direction = direction.Unit
			local radiusX, radiusY = viewport.X * .36, viewport.Y * .3
			local factor = 1 / math.sqrt((direction.X / radiusX) ^ 2 + (direction.Y / radiusY) ^ 2)
			local at = center + direction * factor
			edge.Visible = true
			edgeScale.Scale = scale
			edge.Position = UDim2.fromOffset(at.X, at.Y)
			local angle = math.atan2(direction.Y, direction.X)
			local reach = 44 + (if calm then 0 else math.abs(math.sin(clock * 4)) * 6)
			orbit.Position = UDim2.new(.5, math.cos(angle) * reach, .5, math.sin(angle) * reach)
			orbit.Rotation = math.deg(angle) - 90
			edgeText.Text = if root and showDistance then string.format("%s  %dm", label, math.floor(distance)) else label
			edgeRipples.setVisible(true)
			edgeRipples.step(Vector2.new(60, 60), Vector2.new(58, 58), clock)
		end

		-- Skip path
		if useTrail and root and stone and distance > arriveRadius * 1.5 then
			pathAccumulator += dt
			if pathAccumulator >= 1 / 20 then
				pathAccumulator = 0
				local from = root.Position - Vector3.new(0, 2.5, 0)
				local flat = Vector3.new(position.X - from.X, 0, position.Z - from.Z)
				local length = math.min(flat.Magnitude - arriveRadius * .6, DOT_SPACING * DOT_MAX)
				local directionFlat = flat.Unit
				local span = math.max(flat.Magnitude, 1)
				local count = math.clamp(math.floor(length / DOT_SPACING), 1, DOT_MAX)
				local flow = if calm then 0 else (clock * 5) % DOT_SPACING
				table.clear(pathPoints)
				for index = 1, count do
					local travel = 3 + (index - 1) * DOT_SPACING + flow
					local sample = from + directionFlat * travel
					-- Cast from a little above the straight line between player and
					-- target: follows stairs and ramps, but stays under roofs.
					local lineY = from.Y + (position.Y - from.Y) * math.clamp(travel / span, 0, 1)
					local ground = self:_ground(Vector3.new(sample.X, lineY - 14, sample.Z), lineY + 6, instance)
					local dot = dots[index]
					if not dot then
						-- Glowing water-blue stepping dots.
						dot = new("Part", {Name = "TutorialPathDot", Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false,
							CastShadow = false, Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon,
							Color = DOT_COLOR, Size = Vector3.new(.14, 1.1, 1.1), Parent = self.folder})
						dots[index] = dot
					end
					if ground then
						dot.CFrame = CFrame.new(ground + Vector3.new(0, .1, 0)) * CFrame.Angles(0, 0, math.pi / 2)
						local fadeIn = math.clamp((travel - 2) / 4, 0, 1)
						local fadeOut = math.clamp((length - travel) / 8, 0, 1)
						-- A brightness wave rolls along the path toward the target.
						local wave = if calm then .5 else (math.sin(clock * 6 - index * .9) + 1) / 2
						dot.Transparency = 1 - (.55 + .4 * wave) * math.min(fadeIn, fadeOut)
						table.insert(pathPoints, ground)
					else
						dot.Transparency = 1
					end
				end
				for index = count + 1, #dots do dots[index].Transparency = 1 end
			end

			-- The hopping stone: one bounce every 5 studs, a ripple where it lands.
			if not calm and #pathPoints >= 2 then
				stoneTravel += dt * 16
				local total = (#pathPoints - 1) * DOT_SPACING
				if stoneTravel > total + 8 then
					stoneTravel = 0
					stoneLastBounce = 0
					if stoneTrail then stoneTrail.Enabled = false; stoneTrail:Clear() end
				end
				local along = math.min(stoneTravel, total)
				local segment = math.clamp(math.floor(along / DOT_SPACING) + 1, 1, #pathPoints - 1)
				local t = (along - (segment - 1) * DOT_SPACING) / DOT_SPACING
				local ground = pathPoints[segment]:Lerp(pathPoints[segment + 1], t)
				local bounceLength = 5
				local hop = math.sin(((along % bounceLength) / bounceLength) * math.pi)
				local shrink = math.clamp((total - along) / 10, 0, 1)
				stone.Transparency = if stoneTravel > total then 1 else .05 + (1 - shrink) * .8
				stone.CFrame = CFrame.new(ground + Vector3.new(0, .45 + hop * 2.2 * shrink, 0)) * CFrame.Angles(0, clock * 6, 0)
				if stoneTrail then stoneTrail.Enabled = stoneTravel <= total and stoneTravel > .5 end
				local bounceIndex = math.floor(along / bounceLength)
				if bounceIndex > stoneLastBounce and stoneTravel <= total then
					-- Touchdown: a ring pair spreads on the ground and droplets fly.
					stoneLastBounce = bounceIndex
					local ripple = bounceRipples[bounceIndex % #bounceRipples + 1]
					ripple.born = clock
					ripple.part.CFrame = CFrame.new(ground + Vector3.new(0, .07, 0))
					if splash and splashPart then
						splashPart.CFrame = CFrame.new(ground + Vector3.new(0, .2, 0))
						splash:Emit(math.floor(6 + 6 * shrink))
					end
				end
			else
				stone.Transparency = 1
				if stoneTrail then stoneTrail.Enabled = false end
			end
			for _, ripple in bounceRipples do
				for ring, frame in ripple.frames do
					local age = (clock - ripple.born - (ring - 1) * .14) / .75
					local stroke = ripple.strokes[ring]
					if age >= 0 and age <= 1 then
						frame.Size = UDim2.fromScale(.15 + age * .85, .15 + age * .85)
						stroke.Transparency = .05 + age * .95
						stroke.Thickness = 14 - age * 8
					else
						stroke.Transparency = 1
					end
				end
			end
		else
			hidePath()
		end
	end

	return {
		update = update,
		destroy = function()
			beacon:Destroy()
			edge:Destroy()
			edgeRipples.destroy()
			if destination then destination.part:Destroy() end
			for _, dot in dots do dot:Destroy() end
			if stone then stone:Destroy() end
			if splashPart then splashPart:Destroy() end
			for _, ripple in bounceRipples do ripple.part:Destroy() end
		end,
	}
end

function WorldMarkers:highlight(target: any, opts: {[string]: any}): Marker
	local tone = Theme.swatch(opts.swatch or "sun")
	local highlight = new("Highlight", {Name = "TutorialHighlight", FillColor = tone.top, OutlineColor = Color3.new(1, 1, 1),
		FillTransparency = .8, OutlineTransparency = 0, DepthMode = opts.depthMode or Enum.HighlightDepthMode.AlwaysOnTop,
		Enabled = false, Parent = self.folder})
	local clock = 0
	local resolveAt = -math.huge
	local function update(dt: number)
		clock += dt
		if clock - resolveAt > .3 then
			resolveAt = clock
			local _, instance = resolve(target, nil)
			if instance and (instance:IsA("Model") or instance:IsA("BasePart")) and not (self.suppressor and self.suppressor()) then
				if highlight.Adornee ~= instance then highlight.Adornee = instance end
				highlight.Enabled = true
			else
				highlight.Adornee = nil
				highlight.Enabled = false
			end
		end
		local pulse = if Theme.reducedMotion() then .5 else math.sin(clock * 4) * .5 + .5
		highlight.FillTransparency = .6 + pulse * .28
		highlight.OutlineTransparency = pulse * .4
	end
	return {update = update, destroy = function() highlight:Destroy() end}
end

-- Hide world guidance while something else owns the screen (menus, dialogs).
function WorldMarkers:setSuppressor(callback: () -> boolean)
	self.suppressor = callback
end

-- A screen rect (layer coords) beacons should not sit underneath.
function WorldMarkers:setAvoid(callback: () -> (Vector2?, Vector2?))
	self.avoid = callback
end

function WorldMarkers:destroy()
	self.folder:Destroy()
end

return WorldMarkers
