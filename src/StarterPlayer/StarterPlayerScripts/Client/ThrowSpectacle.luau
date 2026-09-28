--!strict
-- Cosmetic lake choreography. Server skip/result messages are the only triggers.
-- One bounded sampler, short-lived anchors, no physical or scoring changes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WaterSurface = require(Shared:WaitForChild("WaterSurface"))
local RockCatalog = require(Shared:WaitForChild("RockCatalog"))
local player = Players.LocalPlayer

local Spectacle = {}
local CYAN = Color3.fromRGB(87, 235, 255)
local GOLD = Color3.fromRGB(255, 217, 119)
local VIOLET = Color3.fromRGB(176, 114, 255)
local MAX_ANCHORS = 24
local MAX_PATH = 180
local MAX_CONTACTS = 48
local MAX_PATH_SEGMENTS = 42
local MAX_REMOTE_DISTANCE = 360

type Sample = {p: Vector3, t: number}
type Flight = {
	pebble: Model, part: BasePart, mine: boolean, quality: string,
	rockId: string?, variant: string?, abilityId: string?, throwId: number?, started: number, sampledAt: number,
	path: {Sample}, contacts: {Vector3}, lastSkip: number, lastFx: number,
	lastContact: Vector3?, done: boolean,
}
type Ghost = {part: BasePart, path: {Sample}, started: number, cursor: number, anchor: BasePart}
local flights: {[Model]: Flight} = {}
local anchors: {BasePart} = {}
local effectThrowId: number? = nil
local effectOwnerId: number? = nil
local localFlight: Flight? = nil
local lastFlight: Flight? = nil
local bestPath: {Sample}? = nil
local bestRockId: string? = nil
local bestVariant: string? = nil
local bestAbility: string? = nil
local bestQuality = "normal"
local ghost: Ghost? = nil
local ghostPath: BasePart? = nil
local recordLine: BasePart? = nil
local sampleConnection: RBXScriptConnection? = nil
local folder: Folder? = nil
local lastReaction = 0
local lastSky = 0
local reactiveCooldown: {[BasePart]: number} = setmetatable({}, {__mode = "k"}) :: any

local function reduced(): boolean
	local scale = player:GetAttribute("ThrowMotionScale")
	return player:GetAttribute("ReducedMotion") == true or (typeof(scale) == "number" and scale < 0.5)
end

local function fxFolder(): Folder
	if folder and folder.Parent then return folder end
	local created = Instance.new("Folder")
	created.Name = "LocalLakeSpectacle"
	created.Parent = workspace
	folder = created
	return created
end

local function anchorAt(position: Vector3, lifetime: number, name: string): BasePart
	for i = #anchors, 1, -1 do
		if not anchors[i].Parent then table.remove(anchors, i) end
	end
	while #anchors >= MAX_ANCHORS do
		local evict = 1
		for i, candidate in anchors do
			if candidate:GetAttribute("PersistentRoute") ~= true then evict = i; break end
		end
		local oldest = table.remove(anchors, evict)
		oldest:Destroy()
	end
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.CFrame = CFrame.new(position)
	part:SetAttribute("EffectThrowId", effectThrowId)
	part:SetAttribute("EffectOwnerId", effectOwnerId)
	part.Parent = fxFolder()
	table.insert(anchors, part)
	Debris:AddItem(part, lifetime + 0.15)
	return part
end

local function waterPoint(position: Vector3): Vector3
	local level = WaterSurface.at(position)
	return Vector3.new(position.X, (level or position.Y) + 0.13, position.Z)
end

local function heading(velocity: Vector3?): Vector3
	local v = velocity or Vector3.new(0, 0, -1)
	local flat = Vector3.new(v.X, 0, v.Z)
	return if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
end

local function visible(position: Vector3, mine: boolean?): boolean
	if mine then return true end
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude < MAX_REMOTE_DISTANCE
end

local function point(anchor: BasePart, world: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Position = world - anchor.Position
	a.Parent = anchor
	return a
end

local function ribbon(anchor: BasePart, a: Attachment, b: Attachment, color: Color3, width: number, lifetime: number, opacity: number?): Beam
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a, b
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(color)
	beam.Width0, beam.Width1 = width, width * 0.74
	beam.LightEmission = if reduced() then 0.3 else 0.65
	beam.LightInfluence = 0
	beam.Transparency = NumberSequence.new(opacity or 0.32)
	beam.Segments = 1
	beam.Parent = anchor
	TweenService:Create(beam, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Width0 = 0, Width1 = 0}):Play()
	return beam
end

local function polyline(anchor: BasePart, positions: {Vector3}, color: Color3, width: number, lifetime: number, opacity: number?)
	local previous: Attachment? = nil
	for _, position in positions do
		local a = point(anchor, position)
		if previous then ribbon(anchor, previous, a, color, width, lifetime, opacity) end
		previous = a
	end
end

local function pulse(position: Vector3, radius: number, color: Color3, lifetime: number, inward: boolean?)
	local anchor = anchorAt(position, lifetime, if inward then "VoidUndertow" else "SurfacePulse")
	local count = if reduced() then 10 else 16
	local previous: Attachment? = nil
	for i = 0, count do
		local angle = i / count * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local initial = if inward then radius else radius * 0.18
		local target = if inward then 0.5 else radius
		local a = point(anchor, position + direction * (if reduced() then radius * 0.7 else initial))
		if not reduced() then
			TweenService:Create(a, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = direction * target}):Play()
		end
		if previous then ribbon(anchor, previous, a, color, if inward then 0.45 else 0.25, lifetime, 0.38) end
		previous = a
	end
end

local function wake(position: Vector3, direction: Vector3, length: number, color: Color3, lifetime: number, width: number)
	local anchor = anchorAt(position, lifetime, "SplitWake")
	local side = Vector3.new(-direction.Z, 0, direction.X)
	for _, sign in {-1, 1} do
		local positions: {Vector3} = {}
		for i = 0, 5 do
			local f = i / 5
			table.insert(positions, position - direction * length * f + side * sign * (0.45 + f * f * 4.2))
		end
		polyline(anchor, positions, color, width, lifetime)
	end
end

local function waterPart(position: Vector3, direction: Vector3)
	local lifetime = if reduced() then 0.8 else 1.15
	local anchor = anchorAt(position, lifetime, "PerfectPartedWater")
	local side = Vector3.new(-direction.Z, 0, direction.X)
	-- Two open crests peel apart, preserving the stone's central silhouette.
	for _, sign in {-1, 1} do
		local previous: Attachment? = nil
		for i = 0, 6 do
			local f = i / 6
			local forward = direction * (f * 27 - 5)
			local spread = math.sin(f * math.pi) * 4.4
			local a = point(anchor, position + forward + side * sign * (if reduced() then spread else 0.55))
			if not reduced() then
				TweenService:Create(a, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Position = forward + side * sign * (spread + 0.55) + Vector3.new(0, spread * 0.4, 0),
				}):Play()
			end
			if previous then ribbon(anchor, previous, a, CYAN, 0.9, lifetime, 0.3) end
			previous = a
		end
	end
	local centerA = point(anchor, position - direction * 4)
	local centerB = point(anchor, position + direction * 20)
	ribbon(anchor, centerA, centerB, Color3.fromRGB(9, 70, 93), 1.8, lifetime, 0.72).LightEmission = 0
end

local function energyRibbon(position: Vector3, direction: Vector3)
	local anchor = anchorAt(position, 1.25, "SurgeBraids")
	local side = Vector3.new(-direction.Z, 0, direction.X)
	for strand = 0, 1 do
		local positions: {Vector3} = {}
		for i = 0, 9 do
			local f = i / 9
			local angle = f * math.pi * 2 + strand * math.pi
			table.insert(positions, position - direction * f * 32 + side * math.cos(angle) * 1.8
				+ Vector3.new(0, math.sin(angle) * 0.75 + 1, 0))
		end
		polyline(anchor, positions, if strand == 0 then CYAN else Color3.fromRGB(103, 156, 255), 0.45, 1.25)
	end
end

local function directionalWave(position: Vector3, direction: Vector3, size: number, lifetime: number, color: Color3)
	local anchor = anchorAt(position, lifetime, "DirectionalTidalCrest")
	local side = Vector3.new(-direction.Z, 0, direction.X)
	local previous: Attachment? = nil
	for i = 0, 10 do
		local u = (i / 10 - 0.5) * 2
		local height = (1 - u * u) * size * 0.14
		local start = side * u * size * 0.23 - direction * u * u * size * 0.12
		local target = side * u * size * 0.52 + direction * (1 - u * u) * size * 0.48
			+ Vector3.new(0, if reduced() then 0.1 else height, 0)
		local a = point(anchor, position + (if reduced() then target else start))
		if not reduced() then
			TweenService:Create(a, TweenInfo.new(lifetime, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = target}):Play()
		end
		if previous then ribbon(anchor, previous, a, color, if reduced() then 0.5 else 1.8, lifetime, 0.48) end
		previous = a
	end
end

local function beacon(position: Vector3, lifetime: number, color: Color3)
	local anchor = anchorAt(position, lifetime, "LegendaryBeacon")
	local bottom = point(anchor, position + Vector3.new(0, 1, 0))
	local top = point(anchor, position + Vector3.new(0, 70, 0))
	local beam = ribbon(anchor, bottom, top, color, if reduced() then 0.75 else 1.6, lifetime, 0.48)
	beam.Width1 = 0.05
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = color, 1.4, 24, false
	light.Parent = anchor
	TweenService:Create(light, TweenInfo.new(lifetime), {Brightness = 0}):Play()
	pulse(position, 18, color, math.min(lifetime, 2.2))
end

local function skyPulse()
	if reduced() or player:GetAttribute("ReducedThrowFlashes") == true or os.clock() - lastSky < 3 then return end
	lastSky = os.clock()
	-- This effect owns its state; it never changes the experience's exposure.
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "TsunamiSkyPulse"
	effect.Brightness = 0.025
	effect.TintColor = Color3.fromRGB(237, 250, 255)
	effect.Parent = Lighting
	TweenService:Create(effect, TweenInfo.new(0.55), {Brightness = 0, TintColor = Color3.new(1, 1, 1)}):Play()
	Debris:AddItem(effect, 0.6)
end

local function reactiveProp(part: BasePart): boolean
	if CollectionService:HasTag(part, "SkipReactive") then return true end
	local n = string.lower(part.Name)
	local parent = part.Parent
	return (parent ~= nil and parent.Name == "MoneyPickups") or string.find(n, "buoy", 1, true) ~= nil
		or string.find(n, "reed", 1, true) ~= nil or string.find(n, "lantern", 1, true) ~= nil
end

local function reactToLake(position: Vector3, major: boolean, color: Color3)
	local now = os.clock()
	if now - lastReaction < (if major then 0.1 else 0.24) then return end
	lastReaction = now
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: {Instance} = {fxFolder()}
	if player.Character then table.insert(exclude, player.Character) end
	params.FilterDescendantsInstances = exclude
	params.MaxParts = 48
	local found = workspace:GetPartBoundsInRadius(position, if major then 64 else 16, params)
	local count = 0
	for _, part in found do
		if count >= (if major then 6 else 2) then break end
		if not reactiveProp(part) or now - (reactiveCooldown[part] or -10) < 1.4 then continue end
		if part.Size.Magnitude > 45 then continue end
		reactiveCooldown[part] = now
		count += 1
		-- Adornee feedback never moves or hides authoritative collectibles.
		local highlight = Instance.new("Highlight")
		highlight.Adornee = part
		highlight.FillColor, highlight.OutlineColor = color, color
		highlight.FillTransparency, highlight.OutlineTransparency = 0.85, 0.35
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = fxFolder()
		TweenService:Create(highlight, TweenInfo.new(0.8), {FillTransparency = 1, OutlineTransparency = 1}):Play()
		Debris:AddItem(highlight, 0.85)
		local attachment = Instance.new("Attachment")
		attachment.Parent = part
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Shadows = color, if reduced() then 0.3 else 1.2, 10, false
		light.Parent = attachment
		TweenService:Create(light, TweenInfo.new(0.65), {Brightness = 0}):Play()
		Debris:AddItem(attachment, 0.8)
	end
end

local function signature(position: Vector3, rockId: string?)
	if not rockId then return end
	local rock = RockCatalog.get(rockId)
	local id = string.lower(rockId)
	if rock.material == Enum.Material.CrackedLava or string.find(id, "lava", 1, true) then
		local anchor = anchorAt(position, 1.4, "LavaSteam")
		local steam = Instance.new("ParticleEmitter")
		steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
		steam.Rate = 0
		steam.Color = ColorSequence.new(Color3.fromRGB(242, 221, 185), Color3.fromRGB(204, 219, 232))
		steam.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(1, 4.5)})
		steam.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.58), NumberSequenceKeypoint.new(1, 1)})
		steam.Lifetime = NumberRange.new(0.65, 1.15)
		steam.Speed = NumberRange.new(3, 7)
		steam.Acceleration = Vector3.new(0, 7, 0)
		steam.SpreadAngle = Vector2.new(35, 35)
		steam.Parent = anchor
		steam:Emit(if reduced() then 3 else 7)
	elseif id == "obsidian" or id == "astral_core" or string.find(id, "void", 1, true) then
		pulse(position, 6.5, VIOLET, 0.8, true)
	elseif id == "quartz" or rock.material == Enum.Material.Ice or rock.material == Enum.Material.Glacier
		or string.find(id, "frost", 1, true) or string.find(id, "ice", 1, true) then
		local anchor = anchorAt(position, 1.35, "CrystalFrostRing")
		local positions: {Vector3} = {}
		for i = 0, 6 do
			local angle = i / 6 * math.pi * 2
			table.insert(positions, position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 4.5)
		end
		polyline(anchor, positions, Color3.fromRGB(190, 247, 255), 0.32, 1.35, 0.26)
		for i = 1, 6 do
			local a = point(anchor, positions[i])
			local b = point(anchor, position + (positions[i] - position) * 1.4)
			ribbon(anchor, a, b, Color3.fromRGB(232, 253, 255), 0.18, 1.35, 0.3)
		end
	end
end

local function pathLine(path: {Sample}, color: Color3, lifetime: number, name: string): BasePart?
	if #path < 2 then return nil end
	local anchor = anchorAt(waterPoint(path[1].p), lifetime, name)
	anchor:SetAttribute("PersistentRoute", true)
	local stride = math.max(1, math.ceil((#path - 1) / MAX_PATH_SEGMENTS))
	local positions: {Vector3} = {}
	for i = 1, #path, stride do table.insert(positions, waterPoint(path[i].p)) end
	table.insert(positions, waterPoint(path[#path].p))
	polyline(anchor, positions, color, if name == "PersonalBestRecordLine" then 0.38 else 0.16, lifetime, 0.55)
	return anchor
end

local function stopGhost()
	if ghost then ghost.anchor:Destroy(); ghost = nil end
	if ghostPath then ghostPath:Destroy(); ghostPath = nil end
end

function Spectacle.clearThrow(throwId: number?)
 for i=#anchors,1,-1 do
  local anchor=anchors[i]
  if not anchor.Parent or (anchor:GetAttribute("EffectOwnerId")==player.UserId
    and (throwId==nil or anchor:GetAttribute("EffectThrowId")==throwId)) then
   anchor:Destroy();table.remove(anchors,i)
  end
 end
 if recordLine and not recordLine.Parent then recordLine=nil end
end

local function startGhost(flight: Flight)
	stopGhost()
	local path = bestPath
	if not path or #path < 2 or (path[1].p - flight.part.Position).Magnitude > 180 then return end
	local lifetime = math.min(path[#path].t + 1.5, 100)
	local anchor = anchorAt(path[1].p, lifetime, "PersonalBestGhostAnchor")
	ghostPath = anchor
	if not anchor or reduced() then return end
	local stone = Instance.new("Part")
	stone.Name = "PersonalBestGhost"
	stone.Shape = Enum.PartType.Ball
	stone.Size = Vector3.new(0.75, 0.3, 1.05)
	stone.Material, stone.Color = Enum.Material.Neon, Color3.fromRGB(164, 219, 255)
	stone.Transparency = 0.55
	stone.Anchored, stone.CanCollide, stone.CanTouch, stone.CanQuery, stone.CastShadow = true, false, false, false, false
	stone.Position = path[1].p
	stone.Parent = anchor
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(86, 22)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
	billboard.MaxDistance, billboard.AlwaysOnTop = 180, false
	billboard.Parent = stone
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	text.Text, text.TextSize, text.Font = "YOUR BEST", 10, Enum.Font.GothamMedium
	text.TextColor3, text.TextTransparency, text.TextStrokeTransparency = Color3.fromRGB(185, 225, 244), 0.15, 0.6
	text.Parent = billboard
	ghost = {part = stone, path = path, started = os.clock(), cursor = 1, anchor = anchor}
end

local function sample(flight: Flight, now: number, force: boolean?)
	if not flight.part.Parent or (not force and now - flight.sampledAt < 0.09) then return end
	flight.sampledAt = now
	local position = flight.part.Position
	local path = flight.path
	if #path > 0 and not force and (path[#path].p - position).Magnitude < 0.65 then return end
	if #path >= MAX_PATH then
		-- Adaptive decimation preserves the whole race and its original timestamps.
		local compact: {Sample} = {path[1]}
		for i = 3, #path - 1, 2 do table.insert(compact, path[i]) end
		table.insert(compact, path[#path])
		flight.path, path = compact, compact
	end
	table.insert(path, {p = position, t = now - flight.started})
end

local function ensureSampler()
	if sampleConnection then return end
	sampleConnection = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local flight = localFlight
		if flight and not flight.done then
			if flight.part.Parent then sample(flight, now) else flight.done = true; lastFlight = flight; localFlight = nil end
		end
		local active = ghost
		if active then
			local elapsed = now - active.started
			local path = active.path
			if not active.anchor.Parent or elapsed >= path[#path].t then
				stopGhost()
			else
				while active.cursor < #path - 1 and path[active.cursor + 1].t < elapsed do active.cursor += 1 end
				local a, b = path[active.cursor], path[active.cursor + 1]
				local alpha = math.clamp((elapsed - a.t) / math.max(b.t - a.t, 0.001), 0, 1)
				active.part.Position = a.p:Lerp(b.p, alpha)
			end
		end
		if not localFlight and not ghost and sampleConnection then sampleConnection:Disconnect(); sampleConnection = nil end
	end)
end

function Spectacle.begin(pebble: Model, mainPart: BasePart, quality: string?): () -> ()
	local existing = flights[pebble]
	if existing then return function() end end
	local rockId = pebble:GetAttribute("RockId")
	local throwId = pebble:GetAttribute("ThrowId")
	local now = os.clock()
	local flight: Flight = {
		pebble = pebble, part = mainPart, mine = pebble:GetAttribute("ThrowerUserId") == player.UserId,
		quality = quality or "normal", rockId = if typeof(rockId) == "string" then rockId else nil,
		variant = pebble:GetAttribute("Variant"), abilityId = pebble:GetAttribute("EquippedAbility"),
		throwId = if typeof(throwId) == "number" then throwId else nil,
		started = now, sampledAt = 0, path = {}, contacts = {}, lastSkip = 0, lastFx = 0, done = false,
		lastContact = nil,
	}
	flights[pebble] = flight
	if flight.mine then
		if localFlight then localFlight.done = true end
		localFlight = flight
		sample(flight, now, true)
		effectThrowId, effectOwnerId = flight.throwId, player.UserId
		startGhost(flight)
		effectThrowId, effectOwnerId = nil, nil
		ensureSampler()
	end
	return function()
		if flight.done then flights[pebble] = nil; return end
		if flight.mine then
			sample(flight, os.clock(), true)
			lastFlight = flight
			if localFlight == flight then localFlight = nil; stopGhost(); Spectacle.clearThrow(flight.throwId) end
		end
		flight.done = true
		flights[pebble] = nil
	end
end

function Spectacle.skip(pebble: Model?, position: Vector3, count: number, impactVelocity: Vector3?, quality: string?, isLocal: boolean?)
	local flight = if pebble then flights[pebble] else nil
	local mine = isLocal == true or (flight ~= nil and flight.mine)
	if not visible(position, mine) then return end
	if flight and count <= flight.lastSkip then return end
	local now = os.clock()
	local milestone = count == 5 or count == 10 or count == 20 or count == 30 or count == 50 or count == 100
	local first = count == 1
	local p = waterPoint(position)
	local direction = heading(impactVelocity)
	local previous: Vector3? = nil
	if flight then
		previous = flight.lastContact
		flight.lastContact, flight.lastSkip = p, count
		if #flight.contacts >= MAX_CONTACTS then table.remove(flight.contacts, 1) end
		table.insert(flight.contacts, p)
		if not first and not milestone and now - flight.lastFx < 0.085 then return end
		flight.lastFx = now
	end
	effectThrowId = if flight then flight.throwId else nil
	effectOwnerId = if flight then flight.pebble:GetAttribute("ThrowerUserId") else nil
	if previous and (p - previous).Magnitude < 150 then
		-- A brief contact mark keeps skip direction readable without drawing a long beam across the river.
		local delta = p - previous
		if delta.Magnitude > 1 then
			local anchor = anchorAt(p, 0.24, "ContactWaterThread")
			local start = p - delta.Unit * math.min(9, delta.Magnitude)
			polyline(anchor, {start, p}, if count >= 100 then GOLD else CYAN, 0.07, 0.2, 0.78)
		end
	end
	if first then
		pulse(p, 9, CYAN, 0.85)
		if (quality or (if flight then flight.quality else "normal")) == "perfect" then waterPart(p, direction) end
	end
	if count == 5 then
		wake(p, direction, 26, CYAN, 1.4, 0.35)
	elseif count == 10 then
		energyRibbon(p, direction)
	elseif count == 20 then
		pulse(p, 24, VIOLET, 1.55)
		pulse(p + Vector3.new(0, 0.08, 0), 15, CYAN, 1.05)
	elseif count == 30 then
		directionalWave(p, direction, 40, 1.55, Color3.fromRGB(114, 227, 255))
	elseif count == 50 then
		directionalWave(p, direction, 66, 2.0, CYAN)
		wake(p, direction, 62, Color3.fromRGB(179, 242, 255), 2.3, 0.55)
		if mine then skyPulse() end
	elseif count == 100 then
		beacon(p, 1.25, GOLD)
		if flight then
			local anchor = anchorAt(p, 1.1, "LegendaryGoldenPath")
			polyline(anchor, flight.contacts, GOLD, 0.46, 1.1, 0.4)
		end
	end
	if flight and (first or milestone or count % 3 == 0) then signature(p, flight.rockId) end
	if mine or milestone then reactToLake(p, count >= 50 and milestone, if count >= 100 then GOLD else CYAN) end
	effectThrowId, effectOwnerId = nil, nil
end

function Spectacle.finish(result: {[string]: any})
	local flight = localFlight or lastFlight
	if not flight or (typeof(result.throwId) == "number" and flight.throwId ~= result.throwId) then return end
	if not flight.done then sample(flight, os.clock(), true) end
	flight.done = true
	flights[flight.pebble] = nil
	if localFlight == flight then localFlight = nil end
	lastFlight = flight
	stopGhost()
	local endedId = flight.throwId
	task.delay(1.3, function() Spectacle.clearThrow(endedId) end)
	if result.isRecord ~= true or #flight.path < 2 then return end
	if typeof(result.position) == "Vector3" then
		table.insert(flight.path, {p = result.position, t = math.max(os.clock() - flight.started, flight.path[#flight.path].t + 0.001)})
	end
	bestPath = table.clone(flight.path)
	bestRockId, bestQuality = flight.rockId, flight.quality
	bestVariant, bestAbility = flight.variant, flight.abilityId
	if recordLine then recordLine:Destroy() end
	effectThrowId, effectOwnerId = flight.throwId, player.UserId
	recordLine = pathLine(flight.path, GOLD, 1.1, "PersonalBestRecordLine")
	local endpoint = waterPoint(flight.path[#flight.path].p)
	beacon(endpoint, 1.1, GOLD)
	reactToLake(endpoint, true, GOLD)
	effectThrowId, effectOwnerId = nil, nil
end

function Spectacle.getReplay(): {samples: {{position: Vector3, time: number}}, rockId: string?, variant: string?, abilityId: string?, quality: string}?
	local path = bestPath
	if not path or #path < 2 then return nil end
	local samples: {{position: Vector3, time: number}} = {}
	for _, entry in path do table.insert(samples, {position = entry.p, time = entry.t}) end
	return {samples = samples, rockId = bestRockId, variant = bestVariant, abilityId = bestAbility, quality = bestQuality}
end

function Spectacle.shutdown()
	if sampleConnection then sampleConnection:Disconnect(); sampleConnection = nil end
	stopGhost()
	for _, flight in flights do flight.done = true end
	table.clear(flights)
	localFlight, lastFlight = nil, nil
	for _, anchor in anchors do anchor:Destroy() end
	table.clear(anchors)
	if folder then folder:Destroy(); folder = nil end
	recordLine = nil
end

-- Ghost movement immediately stops if accessibility changes mid-flight.
player:GetAttributeChangedSignal("ReducedMotion"):Connect(function() if reduced() then stopGhost() end end)
player:GetAttributeChangedSignal("ThrowMotionScale"):Connect(function() if reduced() then stopGhost() end end)
player.CharacterRemoving:Connect(Spectacle.shutdown)
return Spectacle