--!strict

--[[

	ThrowService (server)

	Owns the entire pebble lifecycle.

	The client only ever sends INPUT: "I started charging", "I released at

	needle fraction F aiming along D", "I am steering left". Everything that

	determines reward -- where the rock actually went, how many times it really

	skipped, how far it travelled -- is simulated and measured here, from the

	real part's position. That makes distance and skip count unforgeable.

	Two things this fixes from the old client-only version:

	  1. The pebble is parented on the SERVER, so every player sees every

	     throw. The old client-side clone was invisible to everyone else,

	     which made cosmetics pointless.

	  2. Score is measured, not reported. The old code called

	     comboEvent:FireServer(skipCount) -- the client naming its own score.

	Skip detection uses analytic plane-crossing against the water level rather

	than .Touched. Touched tunnels at 320 studs/sec and fired on walls too,

	which is why the old combo counter incremented when you hit a fence.

	Physical tagged lake parts define the surface height and rectangular bounds.

	The swept crossing point is tested against those live bounds.

]]

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")

local Debris = game:GetService("Debris")

local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local ThrowConfig = require(Shared:WaitForChild("ThrowConfig"))
local ProgressionConfig = require(Shared:WaitForChild("ProgressionConfig"))

local WaterSurface = require(Shared:WaitForChild("WaterSurface"))

local RockCatalog = require(Shared:WaitForChild("RockCatalog"))
local AbilityCatalog = require(Shared:WaitForChild("AbilityCatalog"))
local AbilityVisuals = require(Shared:WaitForChild("AbilityVisuals"))
local RockAppearance = require(Shared:WaitForChild("RockAppearance"))

local Remotes = require(Shared:WaitForChild("Remotes"))

local ThrowMovementLock = require(script.Parent:WaitForChild("ThrowMovementLock"))

local ThrowSink = require(script.Parent:WaitForChild("ThrowSink"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))

local StyleTargets = require(script.Parent:WaitForChild("ThrowStyleTargets"))
local Encounters = require(script.Parent:WaitForChild("ThrowEncounters"))
local ZoneProgression=require(script.Parent:WaitForChild("ZoneProgression"))
local WorldProgression=require(script.Parent:WaitForChild("WorldProgression"))
local MoneyService=require(script.Parent:WaitForChild("MoneyService"))
local ThrowService = {}

-- Visible lake obstacles do not physically deflect the pebble; a dedicated
-- swept query breaks them before the normal terrain collision test.
local hazardRayParams=RaycastParams.new()
hazardRayParams.FilterType=Enum.RaycastFilterType.Include
hazardRayParams.CollisionGroup=ThrowConfig.PebbleCollisionGroup
hazardRayParams.RespectCanCollide=false
local hazardCount=0
local function refreshHazards()
 local models={}
 for _,model in ipairs(CollectionService:GetTagged("SkipHazard")) do
  if model:IsDescendantOf(workspace) then table.insert(models,model) end
 end
 hazardCount=#models
 hazardRayParams.FilterDescendantsInstances=models
end
refreshHazards()
CollectionService:GetInstanceAddedSignal("SkipHazard"):Connect(refreshHazards)
CollectionService:GetInstanceRemovedSignal("SkipHazard"):Connect(refreshHazards)

--[[

	Injected by the bootstrap so ThrowService depends on neither the shop nor

	profiles, and still works standalone if either is removed. Must sit below

	the ThrowService declaration -- defining a method on it before it exists

	is what produced "attempt to index nil with 'setRockProvider'".

]]

local rockProvider: ((Player) -> RockCatalog.Rock)? = nil

local modifierProvider: ((Player) -> {[string]: any})? = nil

function ThrowService.setRockProvider(provider: (Player) -> RockCatalog.Rock)

	rockProvider = provider

end

function ThrowService.setModifierProvider(provider: (Player) -> {[string]: any})

	modifierProvider = provider

end

local function equippedRock(player: Player): RockCatalog.Rock

	if rockProvider then

		local ok, rock = pcall(rockProvider, player)

		if ok and rock then

			return rock

		end

	end

	return RockCatalog.get(nil)

end

local function hasHeldRockTool(player: Player, autoEquip: boolean?): boolean
	local character = player.Character
	if not character then return false end
	local expectedRockId = equippedRock(player).id
	if not Profiles.has(player) then return false end
	local profile = Profiles.get(player)
	if not profile.loaded or not profile.rocksOwned[expectedRockId] then return false end
	local copyId = profile.rockEquippedInstance
	if copyId then
		local copy = profile.traitedRocks[copyId]
		if not copy or copy.rockId ~= expectedRockId then return false end
	elseif Profiles.untraitedCount(profile, expectedRockId) < 1 then
		return false
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("IsRockTool") == true
			and child:GetAttribute("RockId") == expectedRockId
		then
			return true
		end
	end
	if autoEquip then
		local backpack = player:FindFirstChildOfClass("Backpack")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if backpack and humanoid and humanoid.Health > 0 then
			for _, child in backpack:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("IsRockTool") == true
					and child:GetAttribute("RockId") == expectedRockId then
					humanoid:EquipTool(child)
					return child.Parent == character
				end
			end
		end
	end
	return false
end

local NEUTRAL_MODIFIERS = {

	spinStrength = ProgressionConfig.StartingSpinStrength,
	effectiveStrength = ProgressionConfig.StartingSpinStrength,
	rebirths = 0,
	rockStats = {strengthMultiplier=1, launchSpeed=1, waterLoss=1, bounceLift=1},

	moneyMul = 0,

	magnetBonus = 0,

	luckBonus = 0,

	sweetZoneMul = 1,

}

local function modifiersFor(player: Player): {[string]: any}

	if modifierProvider then

		local ok, mods = pcall(modifierProvider, player)

		if ok and mods then

			return mods

		end

	end

	return NEUTRAL_MODIFIERS

end

type Throw = {

	player: Player,

	pebble: Model,

	mainPart: BasePart,

	launchPos: Vector3,

	lastPos: Vector3,
	lastWaterLevel: number?,

	startedAt: number,

	skips: number,

	maxDistance: number,

	steer: number,
	steerSmoothed: number,
	laneForward: Vector3,
	lateralSpeed: number,
	lastBankAt: number,
	lastSteerAt: number,

	moneyMul: number,

	magnetBonus: number,

	isSonicBoom: boolean,

	isPerfect: boolean,

	quality: string,

	releaseFraction: number,

	requestId: number?,

	throwId: number,

	physics: any,
	currentSpin: number,
	spinStrengthAtLaunch: number,
	rebirthsAtLaunch: number,
	spinStrengthRewarded: number,
	spinStrengthGain: number,
	luckBonus: number,

	bounceReducer: number,

	rayParams: RaycastParams,

	ending: boolean,

	unlockMovement: (() -> ())?,
	abilityId: string?,
	abilityScale: number,
	jetForce: VectorForce?,
	jetAttachment: Attachment?,

}

type Charge = {

	startedAt: number,

	sweetMin: number,

	sweetMax: number,

	requestId: number?,

}

-- Anything that wants to react to a skip (money pickups, quests, ...)

-- registers here, so this module stays unaware of what consumes them.

type SkipListener = (player: Player, position: Vector3, skipIndex: number, distance: number, isPerfect: boolean, context: Throw) -> ()

local skipListeners: {SkipListener} = {}

function ThrowService.onSkip(listener: SkipListener)

	table.insert(skipListeners, listener)

end

local function fireSkip(throw: Throw, position: Vector3)

	for _, listener in skipListeners do

		local ok, err = pcall(listener, throw.player, position, throw.skips, throw.maxDistance, throw.isPerfect, throw)

		if not ok then

			warn("[ThrowService] skip listener failed: " .. tostring(err))

		end

	end

end

-- Fired when a throw finishes, so progression can bank XP and stats without

-- ThrowService knowing those systems exist. The listener returns whether the

-- throw was a personal best, which decides how the client celebrates.

type EndListener = (player: Player, distance: number, skips: number, isPerfect: boolean, isSonicBoom: boolean, context: any?) -> boolean?

local endListeners: {EndListener} = {}

function ThrowService.onThrowEnded(listener: EndListener)

	table.insert(endListeners, listener)

end

local function fireThrowEnded(

	player: Player,

	distance: number,

	skips: number,

	isPerfect: boolean,

	isSonicBoom: boolean,
	context: any?

): boolean

	local isRecord = false

	for _, listener in endListeners do

		local ok, value = pcall(listener, player, distance, skips, isPerfect, isSonicBoom, context)

		if not ok then

			warn("[ThrowService] end listener failed: " .. tostring(value))

		elseif value == true then

			isRecord = true

		end

	end

	return isRecord

end

-- Fired every simulation step of a live throw, for anything that needs to

-- track the rock's whole path rather than just its touchdowns.

type StepListener = (player: Player, position: Vector3, moneyMul: number, magnetBonus: number, luckBonus: number) -> ()

local stepListeners: {StepListener} = {}

function ThrowService.onFlightStep(listener: StepListener)

	table.insert(stepListeners, listener)

end

local function fireFlightStep(player: Player, position: Vector3, moneyMul: number, magnetBonus: number, luckBonus: number)

	for _, listener in stepListeners do

		local ok, err = pcall(listener, player, position, moneyMul, magnetBonus, luckBonus)

		if not ok then

			warn("[ThrowService] flight-step listener failed: " .. tostring(err))

		end

	end

end

-- Per-player state, keyed by Player so cleanup on leave is trivial.

local charges: {[Player]: Charge} = {}

local throws: {[Player]: Throw} = {}

function ThrowService.isActive(player: Player): boolean
	return throws[player] ~= nil
end

local lastThrowAt: {[Player]: number} = {}
local lastChargeAt: {[Player]: number} = {}
local lastRejectAt: {[Player]: number} = {}

local nextThrowId = 0

-- Attachments modify the live throw only. They never write base player stats.
local jetpackStates: {[Player]: any} = {}
local JET = AbilityCatalog.Jetpack
local function currentAbility(player: Player): string?
	if not Profiles.has(player) then return nil end
	local profile = Profiles.get(player)
	local id = profile.abilityEquipped
	return if id and profile.abilitiesOwned and profile.abilitiesOwned[id] and AbilityCatalog.get(id) then id else nil
end
local function fuelState(player: Player)
	if not jetpackStates[player] then
		jetpackStates[player] = {fuel=JET.MaxFuel, held=false, exhausted=false, active=false, lastInput=0, lastUse=-math.huge, lastPublish=0}
	end
	return jetpackStates[player]
end
local function stopThrust(throw: Throw)
	if throw.jetForce then throw.jetForce.Force = Vector3.zero end
	AbilityVisuals.setActive(throw.pebble, false)
end
local function syncAbility(throw: Throw)
	local id = currentAbility(throw.player)
	local multiplier = AbilityCatalog.speedMultiplier(id)
	if multiplier ~= throw.abilityScale then
		local velocity = throw.mainPart.AssemblyLinearVelocity
		local ratio = multiplier / throw.abilityScale
		throw.mainPart.AssemblyLinearVelocity = Vector3.new(velocity.X * ratio, velocity.Y, velocity.Z * ratio)
		throw.abilityScale = multiplier
		throw.pebble:SetAttribute("AbilitySpeedMultiplier", multiplier)
	end
	if id ~= throw.abilityId then
		stopThrust(throw)
		throw.abilityId = id
		AbilityVisuals.attach(throw.pebble, id)
		throw.pebble:SetAttribute("EquippedAbility", id or "")
	end
end
local function stepAbility(throw: Throw, dt: number)
	local state = fuelState(throw.player)
	local now = os.clock()
	if now - state.lastInput > JET.InputTimeout then state.held = false end
	local active = throw.abilityId == "jetpack_rock" and state.held and not state.exhausted
		and state.fuel > 0 and not throw.mainPart.Anchored
	if not active then stopThrust(throw); return end
	if not throw.jetForce then
		local attachment = Instance.new("Attachment")
		attachment.Name = "JetpackThrustAttachment"
		attachment.Parent = throw.mainPart
		local force = Instance.new("VectorForce")
		force.Name = "JetpackThrust"
		force.Attachment0 = attachment
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.ApplyAtCenterOfMass = true
		force.Parent = throw.mainPart
		throw.jetForce, throw.jetAttachment = force, attachment
	end
	local used = math.min(math.max(dt, 0), state.fuel)
	local fraction = if dt > 0 then used/dt else 0
	local vy = throw.mainPart.AssemblyLinearVelocity.Y
	local acceleration = math.clamp((JET.UpSpeed-vy)*JET.VerticalResponse, -JET.MaxLiftAcceleration, JET.MaxLiftAcceleration)
	throw.jetForce.Force = Vector3.new(0, throw.mainPart.AssemblyMass * (workspace.Gravity + acceleration) * fraction, 0)
	state.fuel = math.max(0, state.fuel-used)
	state.active = true
	state.lastUse = now
	if state.fuel <= 0 then state.exhausted = true end
	AbilityVisuals.setActive(throw.pebble, true)
end
local function updateFuel(player: Player, state, dt: number)
	if not state.active and not state.held and os.clock()-state.lastUse >= JET.RechargeDelay then
		state.fuel = math.min(JET.MaxFuel, state.fuel + math.max(dt,0)*JET.RechargeRate)
	end
	if os.clock()-state.lastPublish >= .1 then
		state.lastPublish = os.clock()
		player:SetAttribute("JetpackFuel", state.fuel)
		player:SetAttribute("JetpackActive", state.active)
		player:SetAttribute("JetpackExhausted", state.exhausted and state.held)
	end
end


-- ============================================================================

-- Helpers

-- ============================================================================

local function isFinite(value: number): boolean

	return value == value and math.abs(value) < math.huge

end

local function rejectInput(player: Player, requestId: any, reason: string)
	-- A rejection clears only the matching cosmetic request. Limit responses
	-- so malformed/spammed inputs cannot turn into a notification flood.
	local now = os.clock()
	if now - (lastRejectAt[player] or -math.huge) < 0.15 then return end
	lastRejectAt[player] = now
	local safeId = if typeof(requestId) == "number" and isFinite(requestId) then requestId else nil
	Remotes.ChargeInfo:FireClient(player, nil, nil, nil, safeId, reason)
end

local function rotateVectorY(vec: Vector3, angle: number): Vector3

	local cosA, sinA = math.cos(angle), math.sin(angle)

	return Vector3.new(

		vec.X * cosA - vec.Z * sinA,

		vec.Y,

		vec.X * sinA + vec.Z * cosA

	)

end

local function rollSweetZone(widthMul: number): (number, number)

	local baseWidth = (ThrowConfig.SweetZoneMax - ThrowConfig.SweetZoneMin) * widthMul

	if not ThrowConfig.SweetZoneRandomize then

		local centre = (ThrowConfig.SweetZoneMin + ThrowConfig.SweetZoneMax) / 2

		return math.clamp(centre - baseWidth / 2, 0, 1), math.clamp(centre + baseWidth / 2, 0, 1)

	end

	local shift = (math.random() * 2 - 1) * ThrowConfig.SweetZoneShiftRange

	local width = math.max(baseWidth, ThrowConfig.SweetZoneMinWidth)

	local minBound = math.clamp(ThrowConfig.SweetZoneMin + shift, 0, 1 - width)

	local maxBound = math.clamp(

		minBound + width,

		minBound + ThrowConfig.SweetZoneMinWidth,

		1

	)

	return minBound, maxBound

end

-- Returns character, root, hand -- or nils if the player cannot throw.

local function getCharacterParts(player: Player): (Model?, BasePart?, BasePart?)

	local character = player.Character

	if not character then

		return nil, nil, nil

	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not humanoid or humanoid.Health <= 0 then

		return nil, nil, nil

	end

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?

	if not root then

		return nil, nil, nil

	end

	-- Prefer the actual throwing hand so the release matches the animation.

	local hand = (character:FindFirstChild("RightHand")

		or character:FindFirstChild("Right Arm")) :: BasePart?

	return character, root, hand

end

local function isOverWater(position: Vector3): boolean

	return WaterSurface.at(position) ~= nil

end

-- Counteracts gravity and ramps the rock up to full speed over the slow-mo

-- window so it floats through the first part of its arc. Roblox has no real

-- per-object time scale, so this is a force-based approximation.

local function applySlowMotion(mainPart: BasePart, direction: Vector3, speed: number)
	-- Release is immediate; the shared preview uses the same ballistic path.
	mainPart.AssemblyLinearVelocity = direction * speed
end

-- ============================================================================

-- Lifecycle

-- ============================================================================

local function finishThrow(throw: Throw, endReason: string?, endPosition: Vector3?)

	if throw.ending then

		return

	end

	throw.ending = true
	WorldProgression.finish(throw,endReason)
	MoneyService.endThrow(throw.player)
	stopThrust(throw)
	if throw.jetForce then throw.jetForce:Destroy(); throw.jetForce = nil end
	if throw.jetAttachment then throw.jetAttachment:Destroy(); throw.jetAttachment = nil end
	local abilityState = fuelState(throw.player)
	abilityState.held, abilityState.active = false, false
	throw.player:SetAttribute("JetpackActive", false)
	throw.player:SetAttribute("RockInFlight", false)
	throw.pebble:SetAttribute("ThrowFinished", true)
	Encounters.finish(throw.pebble)

	if throw.unlockMovement then throw.unlockMovement(); throw.unlockMovement = nil end

	local player = throw.player

	throws[player] = nil

	local mainPart = throw.mainPart
	-- Character remains the primary focus for the entire flight. Retire only
 -- the extra pebble focus after its sink presentation; shore never unloads.
 task.delay(3, function()
  if player.Parent then player:RemoveReplicationFocus(mainPart) end
 end)

	if mainPart.Parent then

		local waterY = WaterSurface.at(endPosition or mainPart.Position)

		if waterY and endReason == "sunk" then

			local at = endPosition or mainPart.Position

			ThrowSink.play(throw.pebble, mainPart, Vector3.new(at.X, waterY, at.Z))

		else

			mainPart.AssemblyLinearVelocity = Vector3.new(0, -5, 0)

		end

	end

	local distance = math.floor(throw.maxDistance)

	local baseScore = ThrowConfig.scoreFor(distance, throw.skips, throw.isPerfect)
	local styleScore = throw.pebble:GetAttribute("StyleScore") or 0
	local score = baseScore + styleScore
	StyleTargets.finish(throw.pebble)

	-- Progression decides what counts as a record, because it owns the saved

	-- best; the client no longer guesses from a session-local variable.

	local isRecord = false
	local previousBestDistance = if Profiles.has(player) then Profiles.get(player).bestDistance else 0

	local progressionContext = {
		spinStrengthAtLaunch = throw.spinStrengthAtLaunch,
		rebirthsAtLaunch = throw.rebirthsAtLaunch,
		spinStrengthRewarded = throw.spinStrengthRewarded,
		spinStrengthGain = throw.spinStrengthGain,
		rewardPosition = endPosition or (if mainPart.Parent then mainPart.Position else throw.lastPos),
		flightSeconds = math.max(0, os.clock()-throw.startedAt),
		quality = throw.quality,
		rockId=throw.rockId,
		rockInstanceId=throw.rockInstanceId,
		forwardDistance=math.max(0,throw.lastMilestoneX-throw.launchPos.X),
		endReason = endReason or "sunk",
	}
	if player.Parent then

		isRecord = fireThrowEnded(player, distance, throw.skips, throw.isPerfect, throw.isSonicBoom, progressionContext)

	end

	if player.Parent then

		Remotes.ThrowEnded:FireClient(player, {

			distance = distance,

			skips = throw.skips,

			score = score,
			spinStrengthGain = progressionContext.spinStrengthGain or 0,

			isPerfect = throw.isPerfect,

			quality = throw.quality,

			releaseFraction = throw.releaseFraction,

			requestId = throw.requestId,

			throwId = throw.throwId,

			endReason = endReason or "sunk",

			isRecord = isRecord,
			previousBestDistance = previousBestDistance,
			bestDistance = math.max(previousBestDistance, distance),
			breakdown = {
				distance = distance * ThrowConfig.ScorePerStud,
				skips = throw.skips * ThrowConfig.ScorePerSkip,
				perfect = baseScore - (distance * ThrowConfig.ScorePerStud + throw.skips * ThrowConfig.ScorePerSkip),
				style = styleScore,
			},

			position = endPosition or (if mainPart.Parent then mainPart.Position else throw.lastPos),

		})

	end

	Debris:AddItem(throw.pebble, 3)

end

-- Preserve height above contiguous authored water across a bounded elevation
-- seam. This changes neither velocity nor spin and cannot generate a skip:
-- both endpoint samples must still be above the old surface before carrying.
local function normalizeWaterTransition(throw: Throw, position: Vector3): (Vector3, number?)
	local level = WaterSurface.at(position)
	local previousLevel = throw.lastWaterLevel
	throw.lastWaterLevel = level
	local c = ThrowConfig.WaterTransition
	if not level or not previousLevel then return position, level end
	local heightChange = level-previousLevel
	if math.abs(heightChange) < 0.05 or math.abs(heightChange) > c.MaxHeightChange then return position, level end
	local from = throw.lastPos
	local fromClearance, toClearance = from.Y-previousLevel, position.Y-previousLevel
	if fromClearance <= c.MinClearance or toClearance <= c.MinClearance
		or fromClearance > c.MaxClearance or toClearance > c.MaxClearance then return position, level end
	local travel = position-from
	if travel.Magnitude > c.MaxStepDistance then return position, level end
	local sampleCount = math.max(1, math.ceil(Vector3.new(travel.X,0,travel.Z).Magnitude/c.SampleSpacing))
	for i=1,sampleCount-1 do
		if not WaterSurface.at(from:Lerp(position,i/sampleCount)) then return position, level end
	end
	local shift = Vector3.new(0,heightChange,0)
	-- These two extra casts occur only on a qualified seam, never every frame.
	if workspace:Raycast(from,travel,throw.rayParams) or workspace:Raycast(position,shift,throw.rayParams) then return position, level end
	local velocity, angular = throw.mainPart.AssemblyLinearVelocity, throw.mainPart.AssemblyAngularVelocity
	throw.pebble:PivotTo(throw.pebble:GetPivot()+shift)
	throw.mainPart.AssemblyLinearVelocity, throw.mainPart.AssemblyAngularVelocity = velocity, angular
	throw.lastPos = from+shift
	throw.pebble:SetAttribute("WaterTransitions",(throw.pebble:GetAttribute("WaterTransitions") or 0)+1)
	return position+shift, level
end

local function stepThrow(throw: Throw, dt: number)

	local mainPart = throw.mainPart

	if not mainPart.Parent or not throw.pebble.Parent then

		finishThrow(throw, "removed")

		return

	end

	if os.clock() - throw.startedAt > ThrowConfig.MaxFlightTime then

		finishThrow(throw, "expired")

		return

	end

	syncAbility(throw)
	if Encounters.hold(throw) then throw.lastWaterLevel = nil; stopThrust(throw); return end
	stepAbility(throw, dt)
	-- Use explicit bounded spin decay instead of the engine's unrelated angular
	-- damping, which otherwise caps every strength at roughly 30 seconds.
	throw.currentSpin = math.clamp(throw.currentSpin * math.exp(-ThrowConfig.SpinPhysics.AirSpinDrag*math.max(0,dt)), 0, ThrowConfig.SpinPhysics.MaxSpin)
	local rotation = mainPart.AssemblyAngularVelocity
	mainPart.AssemblyAngularVelocity = Vector3.new(rotation.X, throw.currentSpin, rotation.Z)
	local position, waterLevel = normalizeWaterTransition(throw, mainPart.Position)

	local velocity = mainPart.AssemblyLinearVelocity

	-- Distance (authoritative): furthest horizontal displacement reached.

	local horizontalDelta = Vector3.new(

		position.X - throw.launchPos.X,

		0,

		position.Z - throw.launchPos.Z

	)

	throw.maxDistance = math.max(throw.maxDistance, horizontalDelta.Magnitude)

	fireFlightStep(throw.player, position, throw.moneyMul, throw.magnetBonus, throw.luckBonus)

	-- Steering rotates the CURRENT heading, so neither side is bounded by
	-- the original throw angle. A reversal sheds turn input, not forward speed.
	if os.clock() - throw.lastSteerAt > 0.6 then throw.steer = 0 end
	velocity, throw.steerSmoothed = ThrowConfig.steerVelocity(velocity, throw.steerSmoothed, throw.steer, dt)
	local horizontalSteer = Vector3.new(velocity.X, 0, velocity.Z)
	if horizontalSteer.Magnitude > 0.01 then throw.laneForward = horizontalSteer.Unit end
	throw.lateralSpeed = 0
	mainPart.AssemblyLinearVelocity = velocity
	if os.clock() - throw.lastBankAt >= 1 / 30 then
		throw.lastBankAt = os.clock()
		throw.pebble:SetAttribute("SteerBank", throw.steerSmoothed)
	end

	-- Solid geometry ends the throw. Swept along the step rather than tested at

	-- a point, so it cannot be tunnelled through at 240 studs/sec. The

	-- raycast runs in the pebble's collision group, which is why it ignores

	-- the lake for free while still seeing walls, terrain and the lakebed.

	local impactPosition = if velocity.Y < 0 then WaterSurface.crossing(throw.lastPos, position) else nil
	local delta = (impactPosition or position) - throw.lastPos

	if delta.Magnitude > 0.01 then
  -- Sweep the rock's volume against the animated breakables, even at high speed.
  Encounters.sweepPhysical(throw,throw.lastPos,throw.lastPos+delta)

		if hazardCount>0 then
			local hazardHit=workspace:Raycast(throw.lastPos,delta,hazardRayParams)
			if hazardHit then
				local hazard=hazardHit.Instance:FindFirstAncestorWhichIsA("Model")
				if hazard and hazard:GetAttribute("SkipHazardSeverity") and not throw.pebble:GetAttribute("Hit_"..hazard.Name) then
					throw.pebble:SetAttribute("Hit_"..hazard.Name,true)
					local severity=hazard:GetAttribute("SkipHazardSeverity")
					local factor=severity=="major" and .57 or (severity=="medium" and .78 or .93)
					local v=mainPart.AssemblyLinearVelocity
					local side=Vector3.new(0,0,(position.Z>=hazardHit.Position.Z and 1 or -1))
					local nextVelocity=Vector3.new(v.X*factor,v.Y*.85,v.Z*factor)+side*(severity=="major" and 18 or severity=="medium" and 9 or 3)
					mainPart.AssemblyLinearVelocity=nextVelocity
					velocity=nextVelocity
					throw.pebble:SetAttribute("HazardHits",(throw.pebble:GetAttribute("HazardHits") or 0)+1)
					throw.pebble:SetAttribute("LastHazard",hazard.Name)
				end
			end
		end
		local hit = workspace:Raycast(throw.lastPos, delta, throw.rayParams)

		if hit then

			ZoneProgression.observeThrow(throw.player,hit.Position)
			WorldProgression.observe(throw,hit.Position)
			finishThrow(throw, "collision", hit.Position)

			return

		end

	end

	ZoneProgression.observeThrow(throw.player,position)
	if WorldProgression.observe(throw,position) then finishThrow(throw,"courseComplete",position); return end
	StyleTargets.step(throw.pebble, throw.lastPos, position)
	if Encounters.step(throw, throw.lastPos, position) then
		throw.lastWaterLevel = nil
		throw.lastPos = mainPart.Position
		return
	end

	-- Test the exact intersection, not the end of a fast physics step.

	local primary = WaterSurface.getPrimary()

	local lowestLevel = waterLevel or (if primary then WaterSurface.getLevel(primary) else nil)

	throw.lastPos = position

	if not impactPosition then

		if lowestLevel and position.Y < lowestLevel - ThrowConfig.SinkDepth

			and velocity.Y <= 0 and os.clock() - throw.startedAt > 0.25 then

			finishThrow(throw, if waterLevel then "sunk" else "outOfBounds")

		end

		return

	end

	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local forwardAtImpact = horizontal.Magnitude
	if forwardAtImpact > 0.01 then throw.laneForward = horizontal.Unit end
	local contactGrade, contactRetention, contactLift = ThrowConfig.waterContact(
		forwardAtImpact, -velocity.Y, mainPart.AssemblyAngularVelocity.Y,
		math.abs(throw.steerSmoothed) * 0.45
	)
	local baseRetention = throw.bounceReducer
	-- Ordinary contacts pay momentum costs. Eternal Cadence preserves speed
	-- and spin on every second viable contact, from the immutable snapshot.
	local preserveMomentum = ThrowConfig.preservesSkipMomentum(throw.physics,throw.skips)
	local activeRetention = baseRetention * contactRetention
	if (throw.pebble:GetAttribute("BoostUntil") or 0) > workspace:GetServerTimeNow() then
		activeRetention = math.max(activeRetention, 0.998)
	end

	local newHorizontalSpeed, bounceHeight, survives = ThrowConfig.nextSkipBounce(

		forwardAtImpact / throw.abilityScale,
		throw.skips, activeRetention, workspace.Gravity, throw.physics

	)

	-- Validate the actual outgoing contact lift before awarding a skip.
	bounceHeight = math.min(bounceHeight*contactLift, ThrowConfig.SpinPhysics.MaxBounceLift*math.sqrt(throw.physics.traitBounceHeight or 1))
	local flightTime = 2*bounceHeight/workspace.Gravity
	survives = survives and flightTime >= ThrowConfig.MinSkipFlightTime
		and bounceHeight*bounceHeight/(2*workspace.Gravity) >= ThrowConfig.MinSkipApex
		and newHorizontalSpeed*flightTime >= ThrowConfig.MinSkipTravel
	-- A terminal water entry is a sink, not an extra scored skip.
	if not survives then

		finishThrow(throw, "sunk", impactPosition)

		return

	end

	debug.profilebegin("Skip.ServerImpact")
	throw.skips += 1
	debug.profilebegin("Skip.WorldProgression")
	WorldProgression.skip(throw,impactPosition)
	debug.profileend()
	local angular = mainPart.AssemblyAngularVelocity
	throw.currentSpin *= ThrowConfig.skipSpinRetention(throw.physics,throw.skips-1)
	throw.pebble:SetAttribute("TraitMomentumPreserved",preserveMomentum)
	mainPart.AssemblyAngularVelocity = Vector3.new(angular.X, throw.currentSpin, angular.Z)
	if contactGrade == "skim" then
		throw.pebble:SetAttribute("StyleScore", (throw.pebble:GetAttribute("StyleScore") or 0) + 25)
	end
	throw.pebble:SetAttribute("LastSkipIndex", throw.skips)
	throw.pebble:SetAttribute("LastContactGrade", contactGrade)
	local _, _, nextSurvives = ThrowConfig.nextSkipBounce(newHorizontalSpeed, throw.skips, baseRetention, workspace.Gravity, throw.physics)
	local terminalArc = not nextSurvives
	throw.pebble:SetAttribute("TerminalArc", terminalArc)
	if terminalArc then
		-- Add terminal tumble without reducing the already-validated arc.
		-- The next non-viable water entry remains unscored.
		if not preserveMomentum then throw.currentSpin = math.max(0,throw.currentSpin-3) end
		local terminalRotation = mainPart.AssemblyAngularVelocity
		mainPart.AssemblyAngularVelocity = Vector3.new(terminalRotation.X+3.8, throw.currentSpin, terminalRotation.Z+2.6)
	end

	local tier = ThrowConfig.getComboTier(throw.skips)

	-- Ordinary contacts change velocity only. Pivoting every bounce interrupts
	-- network interpolation and makes a fast stone visibly stop/catch up.
	local outgoing = throw.laneForward * (newHorizontalSpeed * throw.abilityScale)
	local depth = math.max(0, impactPosition.Y - position.Y)
	if depth > 3 then
		-- A large fall or stalled physics step still needs swept recovery.
		-- Only this exceptional case corrects position.
		local recovered = Vector3.new(position.X, impactPosition.Y + 0.08, position.Z)
		throw.pebble:PivotTo(throw.pebble:GetPivot() + (recovered - mainPart.Position))
		mainPart.AssemblyLinearVelocity = outgoing + Vector3.new(0, bounceHeight, 0)
	else
		-- Pay back the energy needed to emerge from a shallow dip, preserving
		-- the intended apex above water without teleporting the visible rock.
		local lift = math.sqrt(bounceHeight * bounceHeight + 2 * workspace.Gravity * depth)
		mainPart.AssemblyLinearVelocity = outgoing + Vector3.new(0, lift, 0)
	end
	throw.lastPos = mainPart.Position

	-- Quality and throw ID are trailing, additive arguments. Older listeners

	-- keep their positional arguments; presentation can correlate each skip

	-- with its replicated pebble and dampen a fumbled release's effects.

	Remotes.Skip:FireAllClients(throw.player.UserId, impactPosition, throw.skips, tier, velocity, throw.quality, throw.throwId, contactGrade)

	debug.profilebegin("Skip.RewardListeners")
	fireSkip(throw, impactPosition)
	debug.profileend()
	debug.profileend()

end

-- ============================================================================

-- Input handlers

-- ============================================================================

local throwRegion = workspace:WaitForChild("ThrowZone"):WaitForChild("ValidRegion")
local function insideThrowZone(player: Player): boolean
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if not root then return false end
 local p=throwRegion.CFrame:PointToObjectSpace(root.Position)
 return math.abs(p.X)<=throwRegion.Size.X/2 and math.abs(p.Y)<=throwRegion.Size.Y/2 and math.abs(p.Z)<=throwRegion.Size.Z/2
end

local function onChargeStart(player: Player, reportedRequestId: unknown)
	if player:GetAttribute("RebirthCinematic") == true or player:GetAttribute("TrainingAFK") == true then return end
	local equipped = player.Character and player.Character:FindFirstChildWhichIsA("Tool")
	if equipped and equipped:GetAttribute("IsTrainingTool") == true then return end

	local now = os.clock()
	if not Profiles.has(player) or not Profiles.get(player).loaded then
		rejectInput(player, reportedRequestId, "Still loading your save")
		return
	end
	if now - (lastChargeAt[player] or -math.huge) < 0.08 then return end
	lastChargeAt[player] = now

	if not insideThrowZone(player) then
		rejectInput(player, reportedRequestId, "Stand in the Throw Zone")
		return
	end

	if not hasHeldRockTool(player, true) then
		rejectInput(player, reportedRequestId, "Equip a rock first")
		return
	end

	if throws[player] then

		rejectInput(player, reportedRequestId, "Rock already in flight")
		return

	end

	local last = lastThrowAt[player]

	if last and os.clock() - last < ThrowConfig.MinThrowInterval then

		rejectInput(player, reportedRequestId, "Ready in a moment")
		return

	end

	local character = getCharacterParts(player)

	if not character then

		return

	end

	-- Echo only: this ID correlates presentation and never authorizes a throw.

	local requestId: number? = nil

	if typeof(reportedRequestId) == "number" and isFinite(reportedRequestId)

		and reportedRequestId >= 0 and reportedRequestId % 1 == 0

	then

		requestId = reportedRequestId

	end

	-- TutorialService sets this server-side attribute only for a new player's
	-- first throw, so the very first attempt is a little more forgiving.
	local tutorialMul = player:GetAttribute("TutorialSweetZoneMul")
	local tutorialWidth = if typeof(tutorialMul) == "number" and isFinite(tutorialMul) then math.clamp(tutorialMul, 1, 2) else 1
	local sweetMin, sweetMax = rollSweetZone((modifiersFor(player).sweetZoneMul or 1) * tutorialWidth)

	local startedAt = workspace:GetServerTimeNow()

	charges[player] = {

		startedAt = startedAt,

		sweetMin = sweetMin,

		sweetMax = sweetMax,

		requestId = requestId,

	}

	-- The shared clock origin lets clients draw a matching preview. Only the

	-- server measures release time; the optional request ID is cosmetic.

	Remotes.ChargeInfo:FireClient(player, sweetMin, sweetMax, startedAt, requestId)

end

local function onChargeRelease(player: Player, reportedFraction: unknown, aimDirection: unknown, releasedAt: unknown, requestId: unknown)
	if player:GetAttribute("RebirthCinematic") == true or player:GetAttribute("TrainingAFK") == true then charges[player] = nil; return end
	local equipped = player.Character and player.Character:FindFirstChildWhichIsA("Tool")
	if equipped and equipped:GetAttribute("IsTrainingTool") == true then charges[player] = nil; return end

	if not Profiles.has(player) or not Profiles.get(player).loaded then
		charges[player] = nil
		rejectInput(player, requestId, "Still loading your save")
		return
	end
	local charge = charges[player]

	if not charge then
		rejectInput(player, requestId, "Press and hold to charge")
		return
	end

	if requestId ~= nil and requestId ~= charge.requestId then return end
	charges[player] = nil

	if not insideThrowZone(player) then
		rejectInput(player, requestId, "Return to the Throw Zone")
		return
	end

	if not hasHeldRockTool(player) then
		rejectInput(player, requestId, "Equip a rock first")
		return
	end

	if throws[player] then
		rejectInput(player, requestId, "Rock already in flight")
		return
	end

	local receivedAt = workspace:GetServerTimeNow()
	local ping = math.clamp(player:GetNetworkPing(), 0, ThrowConfig.ReleaseLatencyLimit)
	local eventTime = receivedAt
	-- Only accept a synchronized input timestamp close to measured transit time.
	-- Never accept a future time or the client's claimed needle fraction.
	if typeof(releasedAt) == "number" and isFinite(releasedAt) then
		local age = receivedAt - releasedAt
		if age >= 0 and age <= ThrowConfig.ReleaseLatencyLimit
			and math.abs(age - ping) <= ThrowConfig.ReleaseClockSlack then
			eventTime = math.max(charge.startedAt, releasedAt)
		end
	end
	local elapsed = eventTime - charge.startedAt

	if elapsed > ThrowConfig.MaxChargeTime then
		rejectInput(player, requestId, "Charge expired — try again")
		return
	end

	-- Keep reportedFraction in the remote signature for older clients, but do

	-- not use it: release quality, launch speed and bonuses use server time.

	local fraction = ThrowConfig.needleFraction(elapsed)

	-- The server decides whether it was perfect, not the client.

	-- Fixed, small boundary grace is derived from the server clock alone.
	-- It cannot be widened by reported fractions, ping, or client timestamps.
	local grace = math.min(ThrowConfig.ReleaseGraceMaxFraction, 2 * ThrowConfig.ReleaseGraceSeconds / ThrowConfig.NeedlePeriod)
	local isPerfect = fraction >= charge.sweetMin - grace and fraction <= charge.sweetMax + grace
	local quality = if isPerfect then "perfect" else ThrowConfig.qualityFor(fraction, charge.sweetMin, charge.sweetMax)

	local character, root, hand = getCharacterParts(player)

	if not character or not root then

		return

	end

	-- Cursor or camera aim is client-supplied and pitch-clamped here.

	local direction: Vector3

	if typeof(aimDirection) == "Vector3"

		and isFinite(aimDirection.X) and isFinite(aimDirection.Y) and isFinite(aimDirection.Z)

		and isFinite(aimDirection.Magnitude) and aimDirection.Magnitude > 0.01

	then

		direction = aimDirection.Unit

	else

		direction = root.CFrame.LookVector

	end

	direction = ThrowConfig.cameraAimDirection(direction, root.CFrame.LookVector)

	local rock = equippedRock(player)

	local mods = modifiersFor(player)
	-- Resolve once per accepted release. Training/equipment changes cannot
	-- rewrite the physical conditions or reward context of a rock in flight.
	local physics = ThrowConfig.physicsFor(mods.effectiveStrength, mods.rockStats)
	local spinStrengthAtLaunch = if typeof(mods.spinStrength) == "number" and isFinite(mods.spinStrength) then math.clamp(mods.spinStrength,0,1e300) else ProgressionConfig.StartingSpinStrength
	local rebirthsAtLaunch = if typeof(mods.rebirths) == "number" and isFinite(mods.rebirths) then math.max(0,math.floor(mods.rebirths)) else 0
	local speed = ThrowConfig.launchSpeed(fraction, isPerfect, physics)
	local abilityId = currentAbility(player)
	local abilityScale = AbilityCatalog.speedMultiplier(abilityId)
	speed *= abilityScale

	local isSonicBoom = isPerfect or fraction >= 0.999

	local templates = ReplicatedStorage:FindFirstChild("RockModels")

	local template = (templates and templates:FindFirstChild(rock.id)) or ReplicatedStorage:FindFirstChild("Pebble")

	if not template or not template:IsA("Model") then

		warn("[ThrowService] ReplicatedStorage.Pebble is missing or not a Model")

		return

	end

	local spawnPos = ThrowConfig.launchOrigin(root, hand, direction)
	local launchParams = RaycastParams.new()
	launchParams.FilterType = Enum.RaycastFilterType.Exclude
	launchParams.FilterDescendantsInstances = {character}
	launchParams.CollisionGroup = ThrowConfig.PebbleCollisionGroup
	launchParams.RespectCanCollide = true
	local handBlocked = workspace:Raycast(root.Position, spawnPos - root.Position, launchParams)
	local lane = ThrowConfig.launchLane(spawnPos, direction, speed, character)
	if handBlocked or not lane.clear then
		rejectInput(player, requestId, "Move closer to open water")
		return
	end

	local pebble = template:Clone()
	pebble:ScaleTo(ThrowConfig.RockVisualScale)
	local variant = if Profiles.has(player) then Profiles.equippedVariant(Profiles.get(player)) else "Normal"
	RockAppearance.apply(pebble, rock.id, variant)

	-- The template ships with no PrimaryPart set, so resolve and assign one:

	-- the rest of the simulation depends on a stable main part.

	local mainPart = pebble.PrimaryPart or pebble:FindFirstChildWhichIsA("BasePart", true)

	if not mainPart then

		pebble:Destroy()

		warn("[ThrowService] Pebble template has no BasePart")

		return

	end

	pebble.PrimaryPart = mainPart
	-- Decorative facets share one rigid assembly; otherwise matching launch
	-- velocities still let spinning accents drift away from their stone.
	mainPart.Massless = false
	for _, part in pebble:GetDescendants() do
		if part:IsA("BasePart") and part ~= mainPart then
			part.Massless = true
			local linked = false
			for _, joint in pebble:GetDescendants() do
				if joint:IsA("WeldConstraint") and ((joint.Part0 == mainPart and joint.Part1 == part)
					or (joint.Part1 == mainPart and joint.Part0 == part)) then linked = true; break end
			end
			if not linked then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "RockAssemblyWeld"
				weld.Part0, weld.Part1 = mainPart, part
				weld.Parent = part
			end
		end
	end

	-- Orient the stone flat and edge-on to its travel: the mesh's long axis is

	-- Z and its thin axis is Y, so lookAt puts it belly-down like a thrown

	-- skimmer instead of inheriting whatever angle the hand happened to be at.

	pebble:PivotTo(CFrame.lookAt(spawnPos, spawnPos + direction))

	-- Attributes and tag are set BEFORE parenting so they replicate atomically

	-- with the instance. Clients discover the pebble via the tag rather than

	-- through a remote argument, which can arrive nil if the instance has not

	-- replicated to that client yet.

	-- The client reads RockId to pick the trail colours, so cosmetics need no

	-- Quality is replicated as an attribute so spectators see the same release effects.

	nextThrowId += 1

	local throwId = nextThrowId

	pebble:SetAttribute("RockId", rock.id)
	pebble:SetAttribute("Variant", variant)
	pebble:SetAttribute("EquippedAbility", abilityId or "")
	pebble:SetAttribute("AbilitySpeedMultiplier", abilityScale)

	pebble:SetAttribute("EffectiveStrength", physics.effectiveStrength)
	pebble:SetAttribute("SpinStrengthAtLaunch", spinStrengthAtLaunch)

	pebble:SetAttribute("ThrowerUserId", player.UserId)

	pebble:SetAttribute("IsSonicBoom", isSonicBoom)

	pebble:SetAttribute("IsPerfect", isPerfect)

	pebble:SetAttribute("Quality", quality)

	pebble:SetAttribute("LaunchSpeed", speed)
	pebble:SetAttribute("LaunchOrigin", spawnPos)
	pebble:SetAttribute("LaunchDirection", direction)
	pebble:SetAttribute("LastSkipIndex", 0)
	pebble:SetAttribute("SteerBank", 0)
	pebble:SetAttribute("TerminalArc", false)

	pebble:SetAttribute("ReleaseFraction", fraction)

	pebble:SetAttribute("SweetMin", charge.sweetMin)

	pebble:SetAttribute("SweetMax", charge.sweetMax)

	pebble:SetAttribute("ChargeRequestId", charge.requestId)

	pebble:SetAttribute("ThrowId", throwId)

	CollectionService:AddTag(pebble, ThrowConfig.PebbleTag)

	-- The thrower receives the complete rock for camera and steering,
	-- even when it travels beyond the character stream radius.
	pebble.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
	pebble:AddPersistentPlayer(player)
	pebble.Parent = workspace

	-- Spin about the stone's own flat (Y) axis, which after the lookAt above is

	-- world up. The server owns explicit air and water-contact spin loss.

	-- A "weak" release (well

	-- outside the sweet zone in either direction) spins far less true and

	-- picks up a little stray tumble on the other two axes, so a fumbled

	-- throw visibly wobbles through the air instead of just going a shorter,

	-- otherwise-identical distance.

	local isWeak = quality == "weak"

	local spin = math.clamp((physics.launchSpin + (isPerfect and ThrowConfig.PerfectSpinBonus or 0))
		* (if isWeak then ThrowConfig.WeakSpinMultiplier else 1), 0, ThrowConfig.SpinPhysics.MaxSpin)

	local wobbleX = if isWeak then (math.random() - 0.5) * 2 * ThrowConfig.WeakWobbleMagnitude else 0

	local wobbleZ = if isWeak then (math.random() - 0.5) * 2 * ThrowConfig.WeakWobbleMagnitude else 0

	for _, descendant in pebble:GetDescendants() do

		if descendant:IsA("BasePart") then

			descendant.Anchored = false

			-- The rock collides with NOTHING. Every interaction is decided

			-- here: skips by plane crossing, solid hits by segment raycast.

			-- While it physically collided with walls the engine would

			-- ricochet it -- measured a 107 degree turn with speed collapsing

			-- 270 -> 65, after which it racked up 40 bogus skips travelling

			-- backwards. The collision group is retained because the raycast

			-- uses it to ignore the lake.

			descendant.CanCollide = false

			if not pebble:GetAttribute("CustomRockAppearance") then

				descendant.Color = rock.color

				descendant.Material = rock.material

			end

			descendant.CollisionGroup = ThrowConfig.PebbleCollisionGroup

			descendant.AssemblyLinearVelocity = direction * speed

			descendant.AssemblyAngularVelocity = Vector3.new(wobbleX, spin, wobbleZ)

		end

	end

	-- Keep simulation on the server so position -- and therefore score --

	-- cannot be rewritten by the thrower's client.

	pcall(function()

		mainPart:SetNetworkOwner(nil)

	end)

	applySlowMotion(mainPart, direction, speed)
	AbilityVisuals.attach(pebble, abilityId)
	player:SetAttribute("RockInFlight", true)

	-- Excludes the pebble and the thrower so the very first step cannot

	-- register a hit on the hand it left.

	local rayParams = RaycastParams.new()

	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	rayParams.FilterDescendantsInstances = {pebble, character}

	rayParams.CollisionGroup = ThrowConfig.PebbleCollisionGroup

	rayParams.RespectCanCollide = true

	local launchPos = mainPart.Position

	-- Keep the launch area resident while also streaming the moving pebble.
 -- Replacing the primary focus unloaded the shore, then restored it 3s late.
 player.ReplicationFocus = nil
 player:AddReplicationFocus(mainPart)
 pebble:SetAttribute("HasFlightStreamingFocus", true)

	throws[player] = {

		player = player,

		pebble = pebble,

		mainPart = mainPart,

		launchPos = launchPos,

		lastPos = launchPos,
		lastWaterLevel = WaterSurface.at(launchPos),

		startedAt = os.clock(),

		skips = 0,

		maxDistance = 0,

		steer = 0,
		steerSmoothed = 0, -- never inherit a held key from the previous throw
		laneForward = Vector3.new(direction.X, 0, direction.Z).Unit,
		lateralSpeed = 0,
		lastBankAt = 0,
		lastSteerAt = os.clock(),

		isSonicBoom = isSonicBoom,

		isPerfect = isPerfect,

		quality = quality,

		releaseFraction = fraction,

		requestId = charge.requestId,

		throwId = throwId,

		moneyMul = 1 + (mods.moneyMul or 0),

		magnetBonus = mods.magnetBonus or 0,

		physics = physics,
		currentSpin = spin,
		spinStrengthAtLaunch = spinStrengthAtLaunch,
		rebirthsAtLaunch = rebirthsAtLaunch,
		spinStrengthRewarded = 0,
		spinStrengthGain = 0,
		luckBonus = mods.luckBonus or 0,
		bounceReducer = physics.waterRetention,

		rayParams = rayParams,

		ending = false,

		unlockMovement = ThrowMovementLock.acquire(character, ThrowConfig.MaxFlightTime + 2),
		abilityId = abilityId,
		abilityScale = abilityScale,

	}

	-- Acknowledge acceptance independently of model streaming.
	Remotes.ThrowAccepted:FireClient(player, charge.requestId, throwId)
	WorldProgression.begin(throws[player])
	MoneyService.beginThrow(player,launchPos)
	lastThrowAt[player] = os.clock()

end

local function onSteer(player: Player, direction: unknown)

	local throw = throws[player]

	if not throw then

		return

	end

	if typeof(direction) ~= "number" or not isFinite(direction) then

		return

	end

	throw.steer = if math.abs(direction) < ThrowConfig.SteerDeadZone then 0 else math.clamp(direction, -1, 1)
	throw.lastSteerAt = os.clock()

end

-- ============================================================================

-- Wiring

-- ============================================================================

function ThrowService.start()
	StyleTargets.start()
	Encounters.start()
	Remotes.FlightAction.OnServerEvent:Connect(function(player, throwId, mode)
		local throw = throws[player]
		if not throw or throw.ending or throwId ~= throw.throwId then return end
		if Encounters.action(throw, throwId, mode) then return end
	end)

	Remotes.ChargeStart.OnServerEvent:Connect(onChargeStart)

	Remotes.ChargeRelease.OnServerEvent:Connect(onChargeRelease)

	Remotes.Steer.OnServerEvent:Connect(onSteer)
	Remotes.AbilityInput.OnServerEvent:Connect(function(player, held)
		if typeof(held) ~= "boolean" then return end
		local state = fuelState(player)
		if not held then
			state.held, state.exhausted = false, false
			local live = throws[player]
			if live then stopThrust(live) end
			player:SetAttribute("JetpackActive", false)
			return
		end
		if not throws[player] or currentAbility(player) ~= "jetpack_rock" then return end
		if not state.held and state.fuel < JET.MinRestartFuel then return end
		state.held = true
		state.lastInput = os.clock()
	end)

	RunService.Heartbeat:Connect(function(dt)
		for _, state in jetpackStates do state.active = false end

		for _, throw in throws do

			stepThrow(throw, dt)

		end
		for player, state in jetpackStates do
			if player.Parent then updateFuel(player, state, dt) end
		end

	end)

	local function onPlayerAdded(player: Player)
		fuelState(player)
		player:SetAttribute("JetpackFuel", JET.MaxFuel)
		player:SetAttribute("RockInFlight", false)
		player:GetAttributeChangedSignal("EquippedAbility"):Connect(function()
			local state = fuelState(player)
			state.held, state.active, state.exhausted = false, false, false
			local live = throws[player]
			if live and live.mainPart.Parent then syncAbility(live); stopThrust(live) end
			player:SetAttribute("JetpackActive", false)
		end)

		player.CharacterRemoving:Connect(function()

			charges[player] = nil
			local state = fuelState(player)
			state.held, state.active, state.exhausted = false, false, false

			local throw = throws[player]

			if throw then

				finishThrow(throw, "interrupted")

			end

		end)

	end

	Players.PlayerAdded:Connect(onPlayerAdded)

	for _, player in Players:GetPlayers() do

		onPlayerAdded(player)

	end

	Players.PlayerRemoving:Connect(function(player)
		jetpackStates[player] = nil
		MoneyService.endThrow(player)

		charges[player] = nil

		lastThrowAt[player] = nil
		lastChargeAt[player] = nil
		lastRejectAt[player] = nil

		local throw = throws[player]

		if throw then

			throws[player] = nil
			StyleTargets.finish(throw.pebble)
			Encounters.finish(throw.pebble)
			pcall(function() player:RemoveReplicationFocus(throw.mainPart) end)

			if throw.unlockMovement then throw.unlockMovement(); throw.unlockMovement = nil end

			if throw.pebble.Parent then

				throw.pebble:Destroy()

			end

		end

	end)

end

return ThrowService


