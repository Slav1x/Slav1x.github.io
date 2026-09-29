--!strict
--[[
	ThrowConfig

	Single source of truth for every pebble-throw tunable, shared by the server
	simulation and the client presentation layer.

	Anything that affects SCORING is read by the server and is authoritative.
	Purely cosmetic values live here too so there is one file to tune.
]]

local ProgressionConfig = require(script.Parent:WaitForChild("ProgressionConfig"))
local ThrowConfig = {}

-- CollectionService tag every in-flight pebble carries. Clients watch for this
-- instead of receiving the instance over a remote, which avoids a replication
-- race on the receiving end.
ThrowConfig.PebbleTag = "SkippingPebble"

-- Collision groups. The pebble must NOT physically collide with the lake:
-- skip detection is analytic (centre crossing WaterLevel downward), and a
-- solid surface stops the centre ever getting there -- the rock just skims
-- along the top and never registers a skip. It still collides with land and
-- walls. LakeSwimming supplies character buoyancy for this part-based lake.
ThrowConfig.PebbleCollisionGroup = "SkipPebble"
ThrowConfig.WaterCollisionGroup = "LakeWater"

-- ============================================================================
-- Launch: progression is converted to bounded physics, never a skip budget.
-- ============================================================================
ThrowConfig.SpinPhysics = {
	MinLaunchSpeed = 32,
	MaxLaunchSpeed = 900, -- normal throw; Hermes applies its 2x after this bound
	BaseSpeed = 75,
	SpeedRange = 850,
	SpeedDecades = 3,
	ExecutionFloor = 0.65,
	ExecutionRange = 0.45,
	PerfectSpeedMultiplier = 1.10,
	BaseWaterLoss = 0.18,
	EarlyLossImprovement = 0.05,
	EarlyLossDecades = 4,
	EnduranceStartsAtDecade = 1.5,
	EnduranceDecades = 2,
	MinWaterLoss = 0.0025,
	HighStrengthEnduranceStartsAtDecade = 5,
	HighStrengthEnduranceDecades = 2,
	MaxWaterLoss = 0.35,
	BaseSpin = 55,
	SpinRange = 45,
	MaxSpin = 140,
	AirSpinDrag = 0.0005, -- per second; contact losses remain separate
	SpinLossPerWaterLoss = 0.25,
	MinSpinLoss = 0.0008,
	MaxSpinLoss = 0.08,
	BounceSpeedReference = 65,
	BounceLift = 36,
	MinBounceLift = 8,
	MaxBounceLift = 80,
	ReadableOpeningArcs = {0.52, 0.49, 0.46, 0.44, 0.42, 0.40},
}

-- Adjacent authored water tiles may sit at slightly different heights.
-- Carry only near-surface rocks across a continuous seam; never bridge land.
ThrowConfig.WaterTransition = {
	MaxHeightChange = 12,
	MaxClearance = 12,
	MinClearance = 0.05,
	MaxStepDistance = 32,
	SampleSpacing = 2,
}

local function finiteNumber(value: any, fallback: number, minimum: number, maximum: number): number
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.clamp(value, minimum, maximum)
end

-- Both server launch and cosmetic client preview use this function. Only the
-- server supplies authoritative effective strength and resolved rock stats.
function ThrowConfig.physicsFor(effectiveStrength: number?, rockStats: any?): any
	local c = ThrowConfig.SpinPhysics
	local reference = finiteNumber(ProgressionConfig.StartingSpinStrength, 10, 1e-6, 1e300)
	local strength = finiteNumber(effectiveStrength, reference, 0, 1e300)
	local stats = if typeof(rockStats) == "table" then rockStats else {}
	local progress = math.max(0, math.log10(math.max(strength, reference)) - math.log10(reference))
	local power = progress / (progress + c.SpeedDecades)
	local launchMultiplier = finiteNumber(stats.launchSpeed, 1, 0.5, 2)
	local lossMultiplier = finiteNumber(stats.waterLoss, 1, 0.35, 2)
	local liftMultiplier = finiteNumber(stats.bounceLift, 1, 0.6, 1.5)
	local earlyLoss = c.BaseWaterLoss - c.EarlyLossImprovement * progress / (progress + c.EarlyLossDecades)
	local tail = math.exp(-math.max(0, progress-c.EnduranceStartsAtDecade) / c.EnduranceDecades
		-math.max(0, progress-c.HighStrengthEnduranceStartsAtDecade) / c.HighStrengthEnduranceDecades)
	local loss = math.clamp((c.MinWaterLoss + (earlyLoss-c.MinWaterLoss)*tail) * lossMultiplier, c.MinWaterLoss, c.MaxWaterLoss)
	return table.freeze({
		effectiveStrength = strength,
		baseSpeed = math.clamp((c.BaseSpeed+c.SpeedRange*power)*launchMultiplier, c.MinLaunchSpeed, c.MaxLaunchSpeed),
		waterRetention = 1-loss,
		bounceLift = liftMultiplier,
		launchSpin = math.clamp(c.BaseSpin+c.SpinRange*power, 0, c.MaxSpin),
		spinRetention = 1-math.clamp(loss*c.SpinLossPerWaterLoss, c.MinSpinLoss, c.MaxSpinLoss),
	})
end

-- ============================================================================
-- Power meter
--
-- The needle is a deterministic triangle wave of elapsed charge time, which is
-- what lets the server independently recompute what the client should have seen
-- instead of taking the client's word for it.
-- ============================================================================
ThrowConfig.NeedlePeriod = 1.1       -- seconds for one full 0 -> 1 -> 0 sweep
ThrowConfig.SweetZoneMin = 0.82
ThrowConfig.SweetZoneMax = 0.97
ThrowConfig.SweetZoneRandomize = true
ThrowConfig.SweetZoneShiftRange = 0.08
ThrowConfig.SweetZoneMinWidth = 0.05

-- Deprecated compatibility field. The server now grades exclusively from
-- its charge/release clock; reported needle fractions cannot influence launch.
ThrowConfig.NeedleTolerance = 0.15

-- ============================================================================
-- Hold strain (risk/reward on hold duration)
--
-- Purely a presentation cost -- it never changes what the server accepts or
-- how a throw scores. The first full sweep of the needle is free (you always
-- get one honest, steady look at the zone); holding past that ramps a 0->1
-- "strain" value that the client uses to shake the camera, pulse the border
-- and darken the charge bar. The point is to make waiting for a better window
-- feel like it costs something, without actually punishing the player's
-- score for being patient.
-- ============================================================================
ThrowConfig.StrainGraceTime = ThrowConfig.NeedlePeriod  -- seconds of free hold before strain starts
ThrowConfig.StrainRampTime = 2.5                        -- seconds after grace before strain maxes out

function ThrowConfig.strainFraction(elapsed: number): number
	if elapsed <= ThrowConfig.StrainGraceTime then
		return 0
	end
	if ThrowConfig.StrainRampTime <= 0 then
		return 1
	end
	return math.clamp((elapsed - ThrowConfig.StrainGraceTime) / ThrowConfig.StrainRampTime, 0, 1)
end

-- ============================================================================
-- Skip physics (simulated server-side)
-- ============================================================================
-- Legacy readers stay compatible; live physical geometry updates these values.
local WaterSurface = require(script.Parent:WaitForChild("WaterSurface"))
ThrowConfig.WaterLevel = 0
ThrowConfig.WaterHalfExtent = 0
local function syncWaterConfig()
	local part = WaterSurface.getPrimary()
	ThrowConfig.WaterLevel = if part then WaterSurface.getLevel(part) else 0
	ThrowConfig.WaterHalfExtent = if part then math.max(part.Size.X, part.Size.Z) * 0.5 else 0
end
WaterSurface.Changed:Connect(syncWaterConfig)
syncWaterConfig()
-- The dominant lever on total distance. Retained speed r gives a run of
-- roughly 1/(1-r) skip-lengths, so 0.94 was worth ~16.7 and 0.91 is ~11.1.
ThrowConfig.MinSpeedToSurvive = 18
-- Bounce arc heights, in studs/sec of upward impulse. Apex is v^2/(2*gravity),
-- so the old minimum of 8 produced a 0.16-stud hop -- dozens of sub-stud
-- bounces a second, which read as the rock vibrating rather than skipping.
-- The floor is now high enough that every skip arcs visibly.
ThrowConfig.BounceHeightBase = 38
ThrowConfig.BounceHeightMin = 15

-- How far below the surface counts as "gone" (ricocheted off a wall, sank).
-- Only applied while descending, so a deep dip on a legitimate skip is never
-- mistaken for a sink.
ThrowConfig.SinkDepth = 2
-- Reject low-energy chatter instead of injecting the minimum bounce forever.
ThrowConfig.BounceSpeedReference = 90
ThrowConfig.MinSkipApex = 0.8
ThrowConfig.MinSkipFlightTime = 0.18
ThrowConfig.MinSkipTravel = 5
ThrowConfig.SinkAnimation = {
	Duration = 1.35,
	Depth = 6,
	GlideTime = 0.08,
	MaxGlide = 4,
	PitchDegrees = 55,
	RollDegrees = 24,
	FadeStart = 0.65,
	WobbleDegrees = 9,
	SubmergedFadeDepth = 0.6,
}

-- Water contacts consume momentum and spin. Remaining physical energy decides
-- whether the next skip survives; no rarity or rock-specific skip limit exists.
function ThrowConfig.nextSkipBounce(speed: number, completedSkips: number, retention: number, gravity: number, physics: any?): (number, number, boolean)
	local c = ThrowConfig.SpinPhysics
	local forwardSpeed = finiteNumber(speed, 0, 0, 10000) * finiteNumber(retention, 0, 0, 0.999)
	local liftMultiplier = if typeof(physics) == "table" then finiteNumber(physics.bounceLift, 1, 0.6, 1.5) else 1
	local lift = math.clamp(c.BounceLift*liftMultiplier*math.sqrt(forwardSpeed/c.BounceSpeedReference), c.MinBounceLift, c.MaxBounceLift)
	local g = finiteNumber(gravity, 196.2, 1, 10000)
	local baselineFlight = 2*lift/g
	local baselineSurvives = forwardSpeed >= ThrowConfig.MinSpeedToSurvive
		and baselineFlight >= ThrowConfig.MinSkipFlightTime
		and lift*lift/(2*g) >= ThrowConfig.MinSkipApex
		and forwardSpeed*baselineFlight >= ThrowConfig.MinSkipTravel
	-- Keep the established readable opening cadence only when the underlying
	-- energy already supports another skip. This never manufactures survival.
	local index = math.floor(finiteNumber(completedSkips, 0, 0, 1e6))+1
	local readableTime = c.ReadableOpeningArcs[index]
	if baselineSurvives and readableTime then
		lift = math.clamp(math.max(lift, g*readableTime*0.5*liftMultiplier), c.MinBounceLift, c.MaxBounceLift)
	end
	local flightTime = 2*lift/g
	local survives = baselineSurvives and flightTime >= ThrowConfig.MinSkipFlightTime
		and lift*lift/(2*g) >= ThrowConfig.MinSkipApex
		and forwardSpeed*flightTime >= ThrowConfig.MinSkipTravel
	return forwardSpeed, lift, survives
end
ThrowConfig.MaxFlightTime = 300 -- Expanded 109,610-stud route; endurance still determines survival.

-- ============================================================================
-- Steering (applied server-side from client input)
-- ============================================================================
ThrowConfig.BaseTurnRate = math.rad(70)
ThrowConfig.MinSpeedForTurn = 5
ThrowConfig.ReferenceSpeed = 150
ThrowConfig.MinSpeedFactor = 0.85
ThrowConfig.MaxSpeedFactor = 1.3
-- Used for encounter reachability and visual hints; steering itself rotates the current heading.
ThrowConfig.BankMaxLateralSpeed = 120
ThrowConfig.BankResponse = 7.5
-- Release input sheds side speed promptly while preserving the forward heading.
ThrowConfig.BankReleaseResponse = 8

-- A flatter, stable stone skims; a steep or unstable entry loses energy.
-- These are deliberately modest so a rough contact changes the feel without
-- wiping out a long run before momentum naturally runs out.
function ThrowConfig.waterContact(forwardSpeed: number, downSpeed: number, spin: number, bankRatio: number): (string, number, number)
	local angle = math.atan2(math.max(0, downSpeed), math.max(1, forwardSpeed))
	local stable = math.abs(spin) / ThrowConfig.LaunchSpin
	if angle > math.rad(36) or stable < 0.48 then
		return "rough", 0.94, 0.90
	end
	if angle < math.rad(19) and angle > math.rad(5) and stable >= 0.72 and bankRatio < 0.38 then
		return "skim", 1, 0.95
	end
	return "solid", 1, 1
end

-- ============================================================================
-- Spin
--
-- A real skipping stone is gyroscopically stabilised by spin about its flat
-- axis. The old code actively zeroed RotVelocity every frame, so the rock slid
-- through the air without rotating at all.
-- ============================================================================
ThrowConfig.LaunchSpin = 55          -- rad/sec about the stone's flat axis
ThrowConfig.PerfectSpinBonus = 25
ThrowConfig.WeakSpinMultiplier = 0.4 -- a fumbled release spins true far less
ThrowConfig.WeakWobbleMagnitude = 6  -- rad/sec of stray tumble added on a weak release

-- ============================================================================
-- Slow-motion on release
-- ============================================================================
ThrowConfig.SlowMoDuration = 0.5
ThrowConfig.SlowMoStartFactor = 0.3

-- ============================================================================
-- Anti-spam
-- ============================================================================
ThrowConfig.MinThrowInterval = 0.35  -- seconds between accepted charge starts
ThrowConfig.MaxChargeTime = 30       -- a charge older than this is abandoned

-- ============================================================================
-- Scoring
-- ============================================================================
ThrowConfig.ScorePerStud = 1
ThrowConfig.ScorePerSkip = 25
ThrowConfig.PerfectScoreMultiplier = 1.25

-- ============================================================================
-- Throw quality (miss-state feedback)
--
-- Distinct from isPerfect, which only gates scoring/sonic-boom eligibility.
-- Quality buckets how CONFIDENT a release looked, purely so presentation can
-- react: a release far outside the sweet zone should read as a fumble, not
-- just "a bit shorter". "perfect" is included as one of the buckets so a
-- single value drives every quality-based callout/effect rather than juggling
-- isPerfect and a separate miss category everywhere.
-- ============================================================================
ThrowConfig.NearMissThreshold = 0.08  -- fraction-distance from the zone edge counted as "so close"
ThrowConfig.WeakQualityThreshold = 0.35 -- fraction-distance from the zone edge counted as "weak"

function ThrowConfig.qualityFor(fraction: number, sweetMin: number, sweetMax: number): string
	if fraction >= sweetMin and fraction <= sweetMax then
		return "perfect"
	end
	local distance = if fraction < sweetMin then sweetMin - fraction else fraction - sweetMax
	if distance <= ThrowConfig.NearMissThreshold then
		return "nearMiss"
	elseif distance >= ThrowConfig.WeakQualityThreshold then
		return "weak"
	end
	return "normal"
end

function ThrowConfig.getComboTier(count: number): number
	if count >= 10 then
		return 3
	elseif count >= 5 then
		return 2
	end
	return 1
end

-- Triangle wave 0 -> 1 -> 0 -> ... from elapsed charge time.
function ThrowConfig.needleFraction(elapsed: number): number
	local t = (elapsed % ThrowConfig.NeedlePeriod) / ThrowConfig.NeedlePeriod
	if t < 0.5 then
		return t * 2
	end
	return 2 - t * 2
end

function ThrowConfig.scoreFor(distance: number, skips: number, isPerfect: boolean): number
	local score = distance * ThrowConfig.ScorePerStud + skips * ThrowConfig.ScorePerSkip
	if isPerfect then
		score *= ThrowConfig.PerfectScoreMultiplier
	end
	return math.floor(score)
end

ThrowConfig.Presentation = {
	Input = {
		AnimationId = "rbxassetid://76678476739562",
		UseSidearmPose = true,
		Sidearm = {
			SnapDuration = 0.16,
			RecoveryDuration = 0.38,
			IdleToss = {
				Delay = 5,
				Duration = 0.95,
				Height = 2.4,
				ForwardDrift = 0.18,
				SpinTurns = 1.25,
				HandOffset = CFrame.new(0, -0.35, -0.5) * CFrame.Angles(0, 0, math.rad(8)),
				Pose = {
					RightShoulder = Vector3.new(-18, 0, 8),
					RightElbow = Vector3.new(-28, 0, 0),
					RightWrist = Vector3.new(16, 0, -8),
					Neck = Vector3.new(-8, 0, 0),
				},
			},
			Ready = {
				Waist = Vector3.new(-10, -28, -5),
				RootJoint = Vector3.new(-8, -22, -4),
				Neck = Vector3.new(5, 18, 0),
				RightShoulder = Vector3.new(-32, -24, 38),
				RightElbow = Vector3.new(32, 0, 0),
				RightWrist = Vector3.new(0, -12, -12),
				LeftShoulder = Vector3.new(22, 10, -16),
				LeftElbow = Vector3.new(25, 0, 0),
				RightHip = Vector3.new(-8, 0, 0),
				LeftHip = Vector3.new(-8, 0, 0),
				RightKnee = Vector3.new(15, 0, 0),
				LeftKnee = Vector3.new(15, 0, 0),
			},
			Finish = {
				Waist = Vector3.new(-7, 28, 4),
				RootJoint = Vector3.new(-5, 22, 3),
				Neck = Vector3.new(3, -18, 0),
				RightShoulder = Vector3.new(62, 30, -48),
				RightElbow = Vector3.new(12, 0, 0),
				RightWrist = Vector3.new(0, 18, 12),
				LeftShoulder = Vector3.new(-14, 0, -12),
				LeftElbow = Vector3.new(12, 0, 0),
			},
		},
		HoldMarker = "Hold",
		HoldFraction = 0.7,
		WindupFadeTime = 0.06,
		WindupSpeed = 3,
		WindupDuration = 0.4,
		FollowThroughDuration = 0.24,
		HandTrailLifetime = 0.12,
		HandTrailWidth = 0.22,
		HandTrailColor = Color3.fromRGB(145, 225, 255),
		ReleaseSpeed = 1.35,
		ReleaseSpeedByQuality = {weak = 0.95, normal = 1.2, nearMiss = 1.4, perfect = 1.6},
		SonicReleaseSpeed = 1.75,
		CancelFadeTime = 0.08,
		ChargeMinVolume = 0.22,
		ChargeVolumeRange = 0.38,
		StrainPitchFrequency = 22,
		StrainPitchAmount = 0.025,
		AcceptanceTimeout = 3,
	},
	Fx = {
		ChargeSoundMinPitch = 0.6,
		ChargeSoundMaxPitch = 1.6,
		Audio = {
			MaxImpactVoices = 12,
			MaxFlightVoices = 8,
			MaxBooms = 2,
			WooshMaxVolume = 0.55,
			WooshMinVolume = 0.025,
			WooshMinSpeed = 3,
			WooshMinPitch = 0.7,
			WooshMaxPitch = 1.4,
			ImpactRollOffMin = 12,
			ImpactRollOffMax = 180,
			FlightRollOffMin = 10,
			FlightRollOffMax = 160,
		},
		Quality = {
			weak = {TrailLifetime = 0.16, TrailWidth = 0.45, TrailEmission = 0.15, TrailTransparency = 0.45, WooshScale = 0.4, SplashStrength = 0.6, SplashVolume = 0.6, FovKick = 0.7, RumbleMagnitude = 0.025},
			normal = {TrailLifetime = 0.28, TrailWidth = 0.8, TrailEmission = 0.35, TrailTransparency = 0.24, WooshScale = 0.75, SplashStrength = 0.9, SplashVolume = 0.85, FovKick = 2, RumbleMagnitude = 0.07},
			nearMiss = {TrailLifetime = 0.34, TrailWidth = 0.95, TrailEmission = 0.5, TrailTransparency = 0.16, WooshScale = 0.9, SplashStrength = 1, SplashVolume = 0.95, FovKick = 3, RumbleMagnitude = 0.1},
			perfect = {TrailLifetime = 0.42, TrailWidth = 1.1, TrailEmission = 0.75, TrailTransparency = 0.08, WooshScale = 1, SplashStrength = 1.12, SplashVolume = 1, FovKick = 4.5, RumbleMagnitude = 0.15},
		},
		Splash = {
			ReferenceSpeed = 60,
			FallbackVerticalSpeed = -30,
			MinimumStrength = 0.18,
			MaximumStrength = 1,
			ComboGrowthPerSkip = 0.018,
			ComboGrowthCap = 0.18,
			AnchorLifetime = 3,
			VolumeBase = 0.22,
			VolumeStrength = 0.42,
			PitchBase = 1.25,
			PitchStrength = 0.35,
			ComboVolume = 0.28,
			ComboPitchBase = 1,
			ComboPitchPerSkip = 0.07,
			ComboPitchMax = 1.75,
			TierVolume = 0.55,
			TierPitchBase = 1,
			TierPitchPerTier = 0.15,
		},
		Sink = {
			SuccessMinSkips = 3,
			SuccessGrowthPerSkip = 0.012,
			SuccessGrowthCap = 0.3,
			FailureScale = 0.38,
			AnchorLifetime = 3,
			Volume = 0.6,
			FailureVolume = 0.26,
			Pitch = 0.82,
			FailurePitch = 0.72,
			RippleDiameter = 28,
			RippleDuration = 0.9,
			CoreDiameter = 12,
			CoreDuration = 0.45,
			PlumeSize = 2.1,
			PlumeEndSize = 0.2,
			PlumeLifeMin = 0.3,
			PlumeLifeMax = 0.65,
			PlumeSpeedMin = 7,
			PlumeSpeedMax = 21,
			PlumeCount = 26,
		},
		Trail = {
			SonicLifetime = 0.5,
			SonicWidth = 1.25,
			SonicEmission = 0.9,
			SonicTransparency = 0.05,
			SonicLightBrightness = 3.5,
			SonicLightRange = 22,
			EnergyFloor = 0.35,
			CleanupPadding = 0.1,
			ParticleRate = {weak = 0, normal = 4, nearMiss = 12, perfect = 24},
			ParticleLifetime = 0.22,
			ParticleSpeed = 1.4,
			ParticleSize = 0.18,
			WeakSmokeRate = 9,
		},
		Launch = {
			AnchorLifetime = 1.2,
			RippleDiameter = {weak = 10, normal = 16, nearMiss = 28, perfect = 44},
			RippleDuration = 0.42,
			SparkCount = {weak = 4, normal = 10, nearMiss = 22, perfect = 44},
			SparkSpeedMin = 18,
			SparkSpeedMax = 48,
			SparkLifetimeMin = 0.12,
			SparkLifetimeMax = 0.46,
			SmokeCount = {weak = 14, normal = 8, nearMiss = 5, perfect = 0},
			SmokeSpeedMin = 4,
			SmokeSpeedMax = 14,
		},
		SkipLabel = {
			Enabled = true,
			Height = 4.2,
			StudsOffset = 1.35,
			Duration = 0.58,
			MaxDistance = 180,
			TextSize = 22,
			PerfectColor = Color3.fromRGB(255, 224, 92),
			NormalColor = Color3.fromRGB(210, 246, 255),
			WeakColor = Color3.fromRGB(185, 195, 205),
		},
		Sonic = {
			RingInterval = 0.075,
			RingSpeedFraction = 0.75,
			RollOffMin = 75,
			RollOffMax = 700,
			AnchorLifetime = 7,
			CrackVolume = 0.385,
			CrackPitch = 1.35,
			BodyVolume = 0.28,
			BodyPitch = 0.55,
			SubVolume = 0.1575,
			SubPitch = 0.28,
			SubDelay = 0.055,
			TailVolume = 0.1225,
			TailPitch = 0.92,
			TailDelay = 0.26,
			RollVolume = 0.063,
			RollPitch = 0.78,
			RollDelay = 1.05,
			FlashStrength = 0.35,
			FlashFade = 0.3,
			FlashMaxDistance = 400,
		},
		Camera = {
			RumbleDuration = 0.2,
			FovKickTime = 0.38,
			SonicFovKick = 6,
			SonicRumbleMagnitude = 0.22,
			SwitchDelay = 0.7,
			TransitionTime = 0.28,
			FollowDistance = 8,
			FollowHeight = 3,
			FollowMinSpeed = 0.1,
			FollowEasePower = 3,
			SinkHoldTime = 2,
			SinkFrameBlendTime = 0.3,
			SinkViewDistance = 14,
			SinkViewHeight = 6,
			SinkMaxViewDistance = 55,
			ReturnMinTime = 1.35,
			ReturnMaxTime = 2.2,
			ReturnAccelerationPower = 2.2,
			ReturnStudsPerSecond = 200,
			ReturnArcFraction = 0.045,
			ReturnArcMax = 16,
			ReturnWallPadding = 0.6,
			TensionMaxFovPullIn = 4,
			TensionZonePulseAmplitude = 0.45,
			TensionZonePulseSpeed = 9,
			StrainMaxShake = 0.12,
			StrainFrequency = 16,
			ReleaseRecoveryTime = 0.14,
		},
	},
	Hud = {
		-- Cosmetic only. Server quality is the sole source of release labels.
		ResultTime = 3,
		FailedResultTime = 1.65,
		ReleaseHoldTime = 0.65,
		ReleaseMarkerWidth = 4,
		ReleaseMarkerExtraHeight = 16,
		ReleasePendingColor = Color3.fromRGB(224, 234, 245),
		ReleaseStrokeTransparency = 0.25,
		StrokeRestTransparency = 0.7,
		StrokeRestThickness = 2,
		StrainWarningThreshold = 0.85,
		StrainPulseHz = 4,
		StrainStrokeOpacity = 0.3,
		StrainPulseOpacity = 0.16,
		StrainPulseThickness = 1.5,
		SweetBandTransparency = 0.55,
		SweetBandStrokeThickness = 1,
		SweetBandStrokeTransparency = 0.25,
		ChargeColor = Color3.fromRGB(255, 150, 40),
		PerfectColor = Color3.fromRGB(80, 255, 120),
		StrainColor = Color3.fromRGB(255, 60, 60),
		FailedResultColor = Color3.fromRGB(255, 155, 150),
		ChargeWidthScale = 0.84,
		ChargeMaxWidth = 320,
		ChargeHeight = 34,
		ResultWidthScale = 0.9,
		ResultMaxWidth = 580,
		QualityWidthScale = 0.84,
		QualityMaxWidth = 312,
		QualityHeight = 108,
		QualityY = 0.40,
		QualityPadding = 12,
		QualityAccentWidth = 5,
		QualityTextInset = 28,
		QualityKickerHeight = 16,
		QualityKickerTextSize = 11,
		QualityTitleHeight = 34,
		QualityTitleY = 31,
		QualityTitleTextSize = 30,
		QualitySubtitleHeight = 20,
		QualitySubtitleY = 71,
		QualitySubtitleTextSize = 12,
		QualityMinTextSize = 8,
		QualityPopScale = 0.94,
		QualityInTime = 0.2,
		QualityPopTime = 0.18,
		QualityTime = 1.1,
		NormalQualityTime = 0.75,
		QualityOutTime = 0.18,
		PerfectArtAssetId = "rbxassetid://106037291613026",
		PerfectArtWidthScale = 0.46,
		PerfectArtMaxWidth = 420,
		PerfectArtAspectRatio = 1672 / 941,
		PerfectArtY = 0,
		PerfectArtTop = 94,
		PerfectArtRight = 22,
		PerfectArtPopScale = 0.62,
		PerfectArtInTime = 0.28,
		PerfectArtHoldTime = 1.6,
		PerfectArtOutTime = 0.24,
		PerfectArtPunchScale = 1.14,
		PerfectArtPunchTime = 0.1,
		PerfectFlashColor = Color3.fromRGB(255, 238, 175),
		PerfectFlashPeakTransparency = 0.62,
		PerfectFlashOutTime = 0.28,
		PerfectRingColor = Color3.fromRGB(255, 218, 96),
		PerfectRingY = 0.66,
		PerfectRingStartSize = 88,
		PerfectRingEndSize = 430,
		PerfectRingThickness = 8,
		PerfectRingOutTime = 0.42,
		PerfectSoundAnchor = "SoundService",
		PerfectPopSounds = {
			{SoundId = "rbxassetid://135949229385709", Volume = 0.65, PlaybackSpeed = 1, Delay = 0.08},
			{SoundId = "rbxassetid://94689014718800", Volume = 0.6, PlaybackSpeed = 1.18, Delay = 0},
			{SoundId = "rbxassetid://9125577419", Volume = 0.28, PlaybackSpeed = 1.72, Delay = 0.035},
			{SoundId = "rbxassetid://9113586144", Volume = 0.24, PlaybackSpeed = 1.65, Delay = 0.075},
		},
		ComboTierColors = {
			[1] = Color3.fromRGB(255, 100, 0),
			[2] = Color3.fromRGB(255, 200, 0),
			[3] = Color3.fromRGB(75, 199, 255),
		},
		QualityStyles = {
			perfect = {title = "PERFECT", subtitle = "PINPOINT RELEASE", color = Color3.fromRGB(80, 255, 120)},
			nearMiss = {title = "NEAR PERFECT", subtitle = "JUST OUTSIDE THE ZONE", color = Color3.fromRGB(255, 204, 66)},
			normal = {title = "STEADY", subtitle = "AIM FOR THE HIGHLIGHTED ZONE", color = Color3.fromRGB(104, 196, 255)},
			weak = {title = "OFF TARGET", subtitle = "RELEASE IN THE HIGHLIGHTED ZONE", color = Color3.fromRGB(255, 100, 110)},
		},
	},
}
-- Keep the held, tossed, predicted, and flying stones at the same readable size.
ThrowConfig.RockVisualScale = 1.4


-- Cosmetic milestones are driven by the existing server-confirmed skip event.
ThrowConfig.Presentation.Fx.Crescendo = {
	Enabled = true,
	
	Milestones = {
		{Skips = 5, Name = "FLOW", Color = Color3.fromRGB(70, 255, 179), Radius = 16},
		{Skips = 10, Name = "SURGE", Color = Color3.fromRGB(60, 170, 255), Radius = 24},
		{Skips = 20, Name = "CRESCENDO", Color = Color3.fromRGB(164, 100, 255), Radius = 34},
		{Skips = 30, Name = "TIDAL", Color = Color3.fromRGB(255, 86, 189), Radius = 46},
		{Skips = 50, Name = "TSUNAMI", Color = Color3.fromRGB(255, 144, 51), Radius = 62},
		{Skips = 100, Name = "LEGENDARY", Color = Color3.fromRGB(255, 226, 102), Radius = 84},
	},
	UpgradeSoundId = "rbxassetid://94689014718800",
	UpgradeVolume = 0.42,
	UpgradeNotes = {1, 1.25, 1.5},
	UpgradeNoteDelay = 0.09,
	WaveRings = 3,
	WaveRingDelay = 0.1,

	MaxVisualSkip = 15,
	NearColor = Color3.fromRGB(74, 235, 255),
	PeakColor = Color3.fromRGB(255, 207, 88),
	WeakColor = Color3.fromRGB(151, 191, 202),
	Notes = {0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24},
	BasePitch = 0.65,
	LocalNoteVolume = 0.65,
	MaxNoteVoices = 4,
	NoteLifetime = 2,
	MaxPitch = 2.6,
	Labels = {"FLOW", "SURGE", "CRESCENDO"},
	RingSegments = 24,
	RingRadius = 3,
	RingGrowth = 7,
	RingDuration = 0.65,
	MilestoneDuration = 1.05,
	RingWidth = 0.18,
	CrownHeight = 5.5,
	LabelWidth = 240,
	LabelHeight = 48,
	LabelPunchScale = 0.65,
	LabelPunchTime = 0.2,
	MaxDistance = 350,
	MinInterval = 0.045,
}

-- Shared cosmetic lookup; never used to award score or alter physics.
function ThrowConfig.getSkipMilestone(skips: number)
	local selected = nil
	local index = 0
	for i, milestone in ThrowConfig.Presentation.Fx.Crescendo.Milestones do
		if skips < milestone.Skips then break end
		selected = milestone
		index = i
	end
	return selected, index
end

ThrowConfig.Presentation.Hud.Theme = {
	Panel = Color3.fromRGB(4, 29, 46),
	PanelTop = Color3.fromRGB(15, 58, 83),
	Gold = Color3.fromRGB(54, 223, 64),
	GoldLight = Color3.fromRGB(180, 255, 94),
	Text = Color3.fromRGB(239, 249, 255),
	Muted = Color3.fromRGB(156, 193, 213),
	Ember = Color3.fromRGB(215, 82, 45),
	PopTime = 0.2,
	ChargeY = 0.76,
	ChargeFrameHeight = 124,
	ResultHeight = 250,
	Edge = Color3.fromRGB(62, 133, 172),
	Radius = 14,
	Texture = "rbxassetid://6927295847",
	PebbleImage = "rbxassetid://84708459117473",
	TextureTransparency = 0.9,
	GlowRest = 0.91,
	GlowHover = 0.5,
	HoverTime = 0.12,
	HoverScale = 1.035,
	PressScale = 0.95,
}
-- Throw polish tuning; gameplay values remain server-owned.
ThrowConfig.ReleaseLatencyLimit = 0.25
ThrowConfig.ReleaseClockSlack = 0.035
ThrowConfig.ReleaseGraceSeconds = 0.018
ThrowConfig.ReleaseGraceMaxFraction = 0.035
-- Gentle buildup makes taps precise; release brakes promptly so the turn does not linger.
ThrowConfig.SteerResponse = 7
ThrowConfig.SteerReleaseResponse = 18
ThrowConfig.SteerMaxAcceleration = 10
ThrowConfig.SteerReverseResponse = 14
ThrowConfig.SteerDeadZone = 0.015
ThrowConfig.AimMinPitch = math.rad(-18)
ThrowConfig.AimMaxPitch = math.rad(32)
ThrowConfig.LaunchLaneSeconds = 2.4
ThrowConfig.LaunchLaneStep = 1 / 30
ThrowConfig.LaunchCorridorRadius = 0.3
ThrowConfig.SlowMoDuration = 0
ThrowConfig.SlowMoStartFactor = 1
ThrowConfig.BounceHeightBase = 36
ThrowConfig.SinkAnimation.Duration = 0.72
ThrowConfig.SinkAnimation.FadeStart = 0.4
local input = ThrowConfig.Presentation.Input
input.GamepadDeadZone = 0.10
input.GamepadSteerStrength = 1
input.TouchSteerStrength = 1
input.SteerSendInterval = 1 / 30
input.InputBufferSeconds = 0.35
input.FeedbackCooldown = 0.85
input.WindupDuration = 0.28
input.Sidearm.SnapDuration = 0.11
input.Sidearm.RecoveryDuration = 0.32
input.Sidearm.Ready.Waist = Vector3.new(-12, -34, -7)
input.Sidearm.Finish.Waist = Vector3.new(-8, 34, 5)
input.Sidearm.Ready.RightElbow = Vector3.new(42, 0, 0)
input.Sidearm.Finish.RightWrist = Vector3.new(-12, 24, 18)
local fx = ThrowConfig.Presentation.Fx
fx.Camera.SwitchDelay = 0.32
fx.Camera.TransitionTime = 0.32
fx.Camera.SinkHoldTime = 0.78
fx.Camera.ReturnMinTime = 0.45
fx.Camera.ReturnMaxTime = 0.8
fx.Camera.ReturnAccelerationPower = 1.4
fx.Camera.ReturnArcMax = 5
fx.Camera.StrainMaxShake = 0.035
fx.Camera.TensionZonePulseAmplitude = 0.12
fx.Camera.FovKickTime = 0.24
fx.Camera.SonicFovKick = 4
fx.Camera.SonicRumbleMagnitude = 0.12
fx.Sonic.RingInterval = 0.13
fx.Sonic.FlashStrength = 0.16
fx.Splash.ComboVolume = 0.18
fx.Splash.TierVolume = 0.28
fx.Crescendo.LocalNoteVolume = 0.38
fx.Crescendo.UpgradeVolume = 0.34
fx.Crescendo.Notes = {0, 2, 4, 7, 9, 7, 4, 2}
fx.Crescendo.BasePitch = 0.85
fx.Crescendo.RingSegments = 16
fx.SkipLabel.Duration = 0.38
fx.SkipLabel.TextSize = 18
fx.Launch.SparkCount = {weak = 3, normal = 7, nearMiss = 14, perfect = 24}
fx.Launch.RippleDiameter = {weak = 5, normal = 8, nearMiss = 12, perfect = 18}

-- Shared launch helpers keep the preview, predicted pebble and server launch
-- in agreement. Only the server uses the lane result to accept a release.
function ThrowConfig.cameraAimDirection(cameraLook: Vector3, fallback: Vector3): Vector3
	local function valid(value: any): boolean
		return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y and value.Z == value.Z
			and value.Magnitude > 0.001 and value.Magnitude < math.huge
	end
	local safeFallback = if valid(fallback) then fallback.Unit else Vector3.new(0,0,-1)
	local look = if valid(cameraLook) then cameraLook.Unit else safeFallback
	local flat = Vector3.new(look.X,0,look.Z)
	if flat.Magnitude < 0.01 then flat = Vector3.new(safeFallback.X,0,safeFallback.Z) end
	if flat.Magnitude < 0.01 then flat = Vector3.new(0,0,-1) end
	local pitch = math.clamp(math.asin(math.clamp(look.Y,-1,1)), ThrowConfig.AimMinPitch, ThrowConfig.AimMaxPitch)
	return flat.Unit*math.cos(pitch)+Vector3.new(0,math.sin(pitch),0)
end

function ThrowConfig.launchOrigin(root: BasePart, hand: BasePart?, direction: Vector3): Vector3
	return (if hand then hand.Position else root.Position) + direction * (if hand then 1.15 else 2.5) + Vector3.new(0, 0.18, 0)
end

function ThrowConfig.launchSpeed(fraction: number, perfect: boolean, physics: any): number
	local c = ThrowConfig.SpinPhysics
	local state = if typeof(physics) == "table" then physics else ThrowConfig.physicsFor(nil, nil)
	local base = finiteNumber(state.baseSpeed, c.BaseSpeed, c.MinLaunchSpeed, c.MaxLaunchSpeed)
	local execution = c.ExecutionFloor+c.ExecutionRange*finiteNumber(fraction, 0, 0, 1)
	return math.clamp(base*execution*(if perfect == true then c.PerfectSpeedMultiplier else 1), c.MinLaunchSpeed, c.MaxLaunchSpeed)
end

-- Exact trajectory of the initial gravity/velocity ramp (before any skips).
function ThrowConfig.releaseOffset(direction: Vector3, speed: number, elapsed: number, gravity: number): Vector3
	if ThrowConfig.SlowMoDuration <= 0 then
		return direction * speed * elapsed - Vector3.new(0, 0.5 * gravity * elapsed * elapsed, 0)
	end
	local rampTime = math.max(ThrowConfig.SlowMoDuration, 0.001)
	local t = math.min(math.max(elapsed, 0), rampTime)
	local initialSpeed = speed * ThrowConfig.SlowMoStartFactor
	local distance = initialSpeed * t + 0.5 * (speed - initialSpeed) / rampTime * t * t
	local offset = direction * distance - Vector3.new(0, gravity * t * t * t / (6 * rampTime), 0)
	if elapsed > rampTime then
		local after = elapsed - rampTime
		offset += (direction * speed - Vector3.new(0, gravity * rampTime * 0.5, 0)) * after
			- Vector3.new(0, 0.5 * gravity * after * after, 0)
	end
	return offset
end

export type LaunchLane = {clear: boolean, contact: Vector3?, obstacle: Vector3?, time: number?, reason: string?}
function ThrowConfig.launchLane(origin: Vector3, direction: Vector3, speed: number, character: Model?): LaunchLane
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if character then {character} else {}
	params.CollisionGroup = ThrowConfig.PebbleCollisionGroup
	params.RespectCanCollide = true
	local previous = origin
	local radius = ThrowConfig.LaunchCorridorRadius
	local side = Vector3.new(-direction.Z, 0, direction.X).Unit * radius
	local originWater = WaterSurface.at(origin)
	if originWater and origin.Y <= originWater then
		return {clear = false, reason = "Move closer to open water"}
	end
	-- The old fixed 2.4-second window rejected valid high arcs before they
	-- descended to water. Cover the possible return from the launch pitch,
	-- plus time for a shoreline or a lower water surface.
	local gravity = math.max(workspace.Gravity, 1)
	local risingTime = 2 * math.max(0, direction.Y * speed) / gravity
	local maxTime = math.min(12.5, ThrowConfig.LaunchLaneSeconds + risingTime)
	local previousTime = 0
	while previousTime < maxTime do
		-- Keep the first half-second precise near the hand and shoreline. Longer
		-- airborne sweeps use 0.1s segments; their chord deviates less than
		-- 0.25 stud from the parabola at normal gravity.
		local step = if previousTime < .5 then ThrowConfig.LaunchLaneStep else .1
		local t = math.min(previousTime + step, maxTime)
		local current = origin + ThrowConfig.releaseOffset(direction, speed, t, workspace.Gravity)
		local contact = WaterSurface.crossing(previous, current)
		local destination = contact or current
		-- Three slim rays guard the launch corridor without treating water as
		-- an obstacle or teleporting through scenery to manufacture a skip.
		for _, offset in {Vector3.zero, side, -side} do
			local hit = workspace:Raycast(previous + offset, destination - previous, params)
			if hit then
				local path = destination - previous
				local fraction = if path:Dot(path) > 1e-5 then math.clamp((hit.Position - previous):Dot(path) / path:Dot(path), 0, 1) else 1
				return {clear = false, obstacle = hit.Position, contact = contact, time = previousTime + (t - previousTime) * fraction, reason = "Move closer to open water"
			end
		end
		if contact then
			local path = current - previous
			local fraction = if path:Dot(path) > 1e-5 then math.clamp((contact - previous):Dot(path) / path:Dot(path), 0, 1) else 1
			return {clear = true, contact = contact, time = previousTime + (t - previousTime) * fraction}
		end
		previous = current
		previousTime = t
	end
	return {clear = false, reason = "Move closer to open water"}
end
-- Short exponential easing keeps direction changes continuous at any frame rate.
-- Reversals shed the old turn quickly; release eases cleanly back to straight.
function ThrowConfig.smoothSteering(current: number, target: number, dt: number): number
	local reversing = current * target < 0
	local response = if reversing then ThrowConfig.SteerReverseResponse
		elseif math.abs(target) < math.abs(current) then ThrowConfig.SteerReleaseResponse
		else ThrowConfig.SteerResponse
	local change = (target-current) * (1-math.exp(-response*math.max(0,dt)))
	local limit = ThrowConfig.SteerMaxAcceleration * math.max(0,dt)
	return math.clamp(current + math.clamp(change,-limit,limit),-1,1)
end


-- Turn the current horizontal heading instead of adding velocity inside a
-- cone around the launch angle. Speed and vertical momentum are preserved.
-- Small fixed substeps give server steering and the aim arc the same response.
function ThrowConfig.steerVelocity(velocity: Vector3, current: number, target: number, dt: number): (Vector3, number, Vector3)
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local speed = horizontal.Magnitude
	local duration = math.clamp(dt, 0, 0.25)
	local steps = math.max(1, math.ceil(duration * 120))
	local step = duration / steps
	local displacement = Vector3.zero
	for _ = 1, steps do
		local nextInput = ThrowConfig.smoothSteering(current, target, step)
		local nextHorizontal = horizontal
		if speed >= ThrowConfig.MinSpeedForTurn then
			local angle = -(current + nextInput) * 0.5 * ThrowConfig.BaseTurnRate * step
			nextHorizontal = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(horizontal)
			nextHorizontal = nextHorizontal.Unit * speed
		end
		displacement += (horizontal + nextHorizontal) * (0.5 * step)
		horizontal, current = nextHorizontal, nextInput
	end
	return horizontal + Vector3.yAxis * velocity.Y, current, displacement
end

return ThrowConfig

