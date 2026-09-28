--!strict
--[[
	ThrowFx (client)

	Every cosmetic effect that rides along with a pebble in flight: trail,
	woosh, sonic boom, sonic rings, water impacts, camera pan, rumble and FOV.

	All of it runs off the REPLICATED pebble, so these effects play for other
	players' throws too, not just your own. This is the single hook every
	trail / splash / ring skin will plug into -- swap the constants in the
	COSMETIC block per equipped item and the whole look changes.
]]

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local ThrowConfig = require(SharedFolder:WaitForChild("ThrowConfig"))
local WaterSurface = require(SharedFolder:WaitForChild("WaterSurface"))
local RockCatalog = require(SharedFolder:WaitForChild("RockCatalog"))
local RockAppearance = require(SharedFolder:WaitForChild("RockAppearance"))
local AbilityVisuals = require(SharedFolder:WaitForChild("AbilityVisuals"))
local AbilityCatalog = require(SharedFolder:WaitForChild("AbilityCatalog"))
local FX = ThrowConfig.Presentation.Fx

local Spectacle = require(script.Parent:WaitForChild("ThrowSpectacle"))
local ThrowFx = {}
local localPlayer = game:GetService("Players").LocalPlayer
local function motionScale(): number
	if localPlayer:GetAttribute("ReducedMotion") == true then return 0 end
	local value = localPlayer:GetAttribute("ThrowMotionScale")
	return if typeof(value) == "number" then math.clamp(value, 0, 1) else 1
end
local endingComplete: (() -> ())? = nil
local lastZoneCue = 0
local impactPulse = 0
local milestoneFov = 0
local nearMissWhip = 0
local flightRestFov: number? = nil
local flightImpacts: {[Model]: number} = {}
local flightSkipCounts: {[Model]: number} = {}
local lastOwnerMelody = 0
local lastOwnerVisual = 0
function ThrowFx.dismissEnding(): boolean
	local done = endingComplete
	if not done then return false end
	endingComplete = nil
	ThrowFx.restoreCamera(localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid"))
	done()
	return true
end

-- Captured once, so repeated flashes always tween back to the real value
-- instead of drifting upward when two booms overlap.
local baseExposure = Lighting.ExposureCompensation
local flashActive = false

-- ============================================================================
-- Audio assets
-- ============================================================================
local CHARGE_SOUND_ID = "rbxassetid://140049602451857"
local SONIC_BOOM_SOUND_ID = "rbxassetid://9125577419"
local WOOSH_SOUND_ID = "rbxassetid://9113586144"
local SPLASH_SOUND_ID = "rbxassetid://119214808310856"
local COMBO_SOUND_ID = "rbxassetid://94689014718800"

local TIER_SOUND_IDS: {[number]: string} = {[2] = COMBO_SOUND_ID, [3] = COMBO_SOUND_ID}

ThrowFx.ChargeSoundId = CHARGE_SOUND_ID
ThrowFx.ChargeSoundMinPitch = FX.ChargeSoundMinPitch
ThrowFx.ChargeSoundMaxPitch = FX.ChargeSoundMaxPitch

-- ============================================================================
-- COSMETIC block -- this is what a skin would override
-- ============================================================================
local TRAIL_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(215, 245, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 205, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 140, 220)),
})
local TRAIL_COLOR_BOOM = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 235)),
	ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 180, 70)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 40)),
})
-- A dulled, uncommitted-looking trail for a fumbled ("weak") release -- the
-- rock still throws, it just doesn't get to look proud of itself.
local TRAIL_COLOR_WEAK = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(195, 195, 195)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 100, 100)),
})
local SPLASH_COLOR = Color3.fromRGB(180, 240, 255)
local RIPPLE_COLOR = Color3.fromRGB(225, 250, 255)
local BOOM_LIGHT_COLOR = Color3.fromRGB(255, 170, 80)

-- Built-in textures, so there are no asset IDs that can fail to load.
local PARTICLE_SOFT = "rbxasset://textures/particles/smoke_main.dds"
local PARTICLE_SPARK = "rbxasset://textures/particles/sparkles_main.dds"

-- ============================================================================
-- Tuning
-- ============================================================================
local WOOSH_MAX_VOLUME = FX.Audio.WooshMaxVolume
local WOOSH_MIN_VOLUME = FX.Audio.WooshMinVolume
local WOOSH_MIN_SPEED = FX.Audio.WooshMinSpeed
local WOOSH_MIN_PITCH = FX.Audio.WooshMinPitch
local WOOSH_MAX_PITCH = FX.Audio.WooshMaxPitch
local SONIC_RING_INTERVAL = FX.Sonic.RingInterval

-- ============================================================================
-- Sound barrier break
--
-- The boom is deliberately NOT a 2D sound. A 2D sound plays at identical
-- volume everywhere on the map, which sounds wrong for an event with an
-- obvious location. Instead it stays 3D with a very wide flat core: full
-- volume anywhere inside RollOffMin, then a linear fade to silence at
-- RollOffMax. That reads as "loud and everywhere" nearby while still
-- being locatable and still cutting off at range.
-- ============================================================================
local BOOM_ROLLOFF_MIN = FX.Sonic.RollOffMin
local BOOM_ROLLOFF_MAX = FX.Sonic.RollOffMax

-- The crack, body and sub-bass are layered from the one boom sample at
-- different pitches. The tail is a real thunder recording, so it is played
-- near its natural pitch rather than dragged down like the synthesised
-- layers -- pitching a real thunder sample to 0.26 just turns it to mud.
local THUNDER_SOUND_ID = "rbxassetid://130457325001606"

local FLASH_STRENGTH = FX.Sonic.FlashStrength
local FLASH_FADE = FX.Sonic.FlashFade
local FLASH_MAX_DISTANCE = FX.Sonic.FlashMaxDistance

local RUMBLE_DURATION = FX.Camera.RumbleDuration
local FOV_KICK_TIME = FX.Camera.FovKickTime
local CAMERA_SWITCH_DELAY = FX.Camera.SwitchDelay
local CAMERA_TRANSITION_TIME = FX.Camera.TransitionTime

-- Impact strength is normalised against this vertical speed, so a fast early
-- skip throws a big plume and a dying late one barely plops.
local IMPACT_REFERENCE_SPEED = FX.Splash.ReferenceSpeed

-- ============================================================================
-- Charge tension (anticipation build + hold strain)
--
-- Two client-only feelings layered on top of the existing charge sound/HUD:
--   * Anticipation: FOV tightens toward the throw as charge builds, with a
--     small pulse while the needle sits in the sweet zone -- the "this is
--     gonna be good" telegraph.
--   * Strain: once ThrowConfig says the hold has gone on long enough to
--     matter, the aim gets shaky (camera offset jitter). It never touches
--     the server's numbers -- purely the body language of "my arm is tired,
--     release already".
-- ============================================================================
local TENSION_MAX_FOV_PULLIN = FX.Camera.TensionMaxFovPullIn
local TENSION_ZONE_PULSE_AMPLITUDE = FX.Camera.TensionZonePulseAmplitude
local TENSION_ZONE_PULSE_SPEED = FX.Camera.TensionZonePulseSpeed
local STRAIN_MAX_SHAKE = FX.Camera.StrainMaxShake

-- Restored to this exact value on release, so repeated charges never drift
-- the player's real FOV setting.
local restFov: number? = nil
local tensionCamera: Camera? = nil
local offsetHumanoid: Humanoid? = nil
local restOffset: Vector3? = nil
local cameraTween: Tween? = nil
local offsetTween: Tween? = nil
local rumbleConnection: RBXScriptConnection? = nil
local cameraGeneration = 0
local followGeneration = 0
local followConnection: RBXScriptConnection? = nil
local followInputConnection: RBXScriptConnection? = nil
local followBeginConnection: RBXScriptConnection? = nil
local followEndConnection: RBXScriptConnection? = nil
local followLookHeld = false
local followPriorMouseBehavior: Enum.MouseBehavior? = nil
local flightZoomDistance = 10
local followCamera: Camera? = nil
local returnView: CFrame? = nil
local returnRootPosition: Vector3? = nil

local impactVoices: {Sound} = {}
local melodyVoices: {Sound} = {}
local upgradeVoices: {Sound} = {}
local flightColors: {[Model]: (Color3) -> ()} = {}
local flightVoices: {Sound} = {}
local boomAnchors: {BasePart} = {}

local function qualityProfile(quality: string?)
	return FX.Quality[quality or "normal"] or FX.Quality.normal
end

-- A busy lake must not multiply impact/flight volume without bound. Oldest
-- voices give way to the newest event; destroyed anchors are pruned as well.
local function playBudgeted(sound: Sound, voices: {Sound}, limit: number)
	for index = #voices, 1, -1 do
		if not voices[index].Parent or not voices[index].IsPlaying then
			table.remove(voices, index)
		end
	end
	while #voices >= math.max(1, limit) do
		local oldest = table.remove(voices, 1)
		oldest:Stop()
		if not oldest:GetAttribute("SkipPooled") then oldest:Destroy() end
	end
	table.insert(voices, sound)
	sound.SoundGroup = game:GetService("SoundService"):FindFirstChild("SFX") :: SoundGroup?
	sound:Play()
end

local function playImpact(sound: Sound)
	sound.RollOffMinDistance = FX.Audio.ImpactRollOffMin
	sound.RollOffMaxDistance = FX.Audio.ImpactRollOffMax
	playBudgeted(sound, impactVoices, FX.Audio.MaxImpactVoices)
end

local prepareSkipPools
function ThrowFx.preload()
	if prepareSkipPools then prepareSkipPools() end
	task.spawn(function()
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync({
				CHARGE_SOUND_ID,
				SONIC_BOOM_SOUND_ID,
				WOOSH_SOUND_ID,
				SPLASH_SOUND_ID,
				COMBO_SOUND_ID,
				THUNDER_SOUND_ID,
				PARTICLE_SPARK,
				PARTICLE_SOFT,
			})
		end)
		if not ok then
			warn("[ThrowFx] Sound preload failed: " .. tostring(err))
		end
	end)
end

-- ============================================================================
-- Water impact
-- ============================================================================

local function makeAnchor(position: Vector3, lifetime: number): BasePart
	local anchor = Instance.new("Part")
	anchor.Name = "SplashFx"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace
	Debris:AddItem(anchor, lifetime)
	return anchor
end

--[[
	A flat disc lying on the water that expands and fades -- the ripple a skip
	leaves behind. A Roblox cylinder's circular faces sit on its X axis, so it
	is rotated 90 degrees about Z to lie flat, which is why Size.X is the
	thickness and Y/Z are the diameter.
]]
-- One controller advances the existing rings; each impact no longer creates 33 tweens.
local RIPPLE_SEGMENTS = 16
local RIPPLE_POOL_LIMIT = 12
local ripplePool = {}
local activeRipples = {}
local splashPool = {}
local activeSplashes = {}
local directions = {}
for i=0,RIPPLE_SEGMENTS do
 local angle=i/RIPPLE_SEGMENTS*math.pi*2
 directions[i+1]=Vector3.new(math.cos(angle),0,math.sin(angle))
end
local function rippleRig()
 local reused=table.remove(ripplePool)
 if reused then return reused end
 local anchor=Instance.new("Part")
 anchor.Name="SplashRipple";anchor.Anchored=true;anchor.CanCollide=false;anchor.CanQuery=false;anchor.CanTouch=false;anchor.Transparency=1;anchor.Size=Vector3.one
 local points,beams={},{}
 for i=0,RIPPLE_SEGMENTS do
  local point=Instance.new("Attachment");point.Parent=anchor;points[i+1]=point
  if i>0 then
   local beam=Instance.new("Beam");beam.Attachment0=points[i];beam.Attachment1=point
   beam.FaceCamera=true;beam.Transparency=NumberSequence.new(.4);beam.LightEmission=.3;beam.Parent=anchor;beams[i]=beam
  end
 end
 return {anchor=anchor,points=points,beams=beams}
end
local function spawnRipple(position,diameter,duration,color)
 local rig=rippleRig()
 rig.anchor.CFrame=CFrame.new(position+Vector3.new(0,.06,0));rig.anchor.Parent=workspace
 rig.started=os.clock();rig.duration=duration;rig.diameter=diameter
 for i,point in rig.points do point.Position=directions[i]*diameter*.12 end
 local sequence=ColorSequence.new(color)
 for _,beam in rig.beams do beam.Color=sequence;beam.Width0=.13;beam.Width1=.13;beam.Enabled=true end
 table.insert(activeRipples,rig)
end
local function splashRig()
 local rig=table.remove(splashPool)
 if rig then return rig end
 local anchor=Instance.new("Part")
 anchor.Name="SplashFx";anchor.Anchored=true;anchor.CanCollide=false;anchor.CanQuery=false;anchor.CanTouch=false;anchor.Transparency=1;anchor.Size=Vector3.one
 return {anchor=anchor,components={},tweens={}}
end
local function component(rig,name,className,parent)
 local object=rig.components[name]
 if not object then
  object=Instance.new(className);object.Name=name;rig.components[name]=object
  if object:IsA("Sound") then object:SetAttribute("SkipPooled",true) end
 end
 object.Parent=parent
 return object
end
RunService.Heartbeat:Connect(function()
 local now=os.clock()
 for i=#activeRipples,1,-1 do
  local rig=activeRipples[i];local alpha=math.clamp((now-rig.started)/rig.duration,0,1)
  if alpha>=1 then
   for _,beam in rig.beams do beam.Enabled=false end
   rig.anchor.Parent=nil;table.remove(activeRipples,i)
   if #ripplePool<RIPPLE_POOL_LIMIT then table.insert(ripplePool,rig) else rig.anchor:Destroy() end
  else
   local eased=1-(1-alpha)^2;local radius=rig.diameter*(.12+.38*eased)
   for j,point in rig.points do point.Position=directions[j]*radius end
   local width=.13*(1-alpha)
   for _,beam in rig.beams do beam.Width0=width;beam.Width1=width end
  end
 end
 for i=#activeSplashes,1,-1 do
  local rig=activeSplashes[i]
  if now>=rig.expires then
   for _,tween in rig.tweens do tween:Cancel() end;table.clear(rig.tweens)
   for _,object in rig.components do
    if object:IsA("ParticleEmitter") then object:Clear();object.Enabled=false
    elseif object:IsA("Sound") then object:Stop();object.Parent=rig.anchor
    elseif object:IsA("BasePart") then object.Transparency=1 end
   end
   rig.anchor.Parent=nil;table.remove(activeSplashes,i)
   if #splashPool<16 then table.insert(splashPool,rig) else rig.anchor:Destroy() end
  end
 end
end)
local skipPoolsPrepared=false
prepareSkipPools=function()
 if skipPoolsPrepared then return end
 skipPoolsPrepared=true
 task.spawn(function()
  local warmed={}
  for _=1,12 do table.insert(warmed,rippleRig());RunService.Heartbeat:Wait() end
  for _,rig in warmed do if #ripplePool<RIPPLE_POOL_LIMIT then table.insert(ripplePool,rig) else rig.anchor:Destroy() end end
  local splashWarmed={}
  for _=1,16 do
   local rig=splashRig()
   local attachment=component(rig,"SprayAnchor","Attachment",rig.anchor)
   for _,name in {"Spray","Droplets","Mist","Glint"} do
    local emitter=component(rig,name,"ParticleEmitter",attachment);emitter.Rate=0;emitter.Enabled=false
   end
   for _,name in {"Splash","Combo","Tier","Body"} do component(rig,name,"Sound",rig.anchor) end
   for _,name in {"Wake-1","Wake1"} do
    local wake=component(rig,name,"Part",rig.anchor);wake.Anchored=true;wake.CanCollide=false;wake.CanTouch=false;wake.CanQuery=false;wake.Transparency=1
   end
   table.insert(splashWarmed,rig);RunService.Heartbeat:Wait()
  end
  for _,rig in splashWarmed do if #splashPool<16 then table.insert(splashPool,rig) else rig.anchor:Destroy() end end
 end)
end

function ThrowFx.playZoneCue()
	if os.clock() - lastZoneCue < 0.18 then return end
	lastZoneCue = os.clock()
	local cue = Instance.new("Sound")
	cue.SoundId, cue.Volume, cue.PlaybackSpeed = COMBO_SOUND_ID, 0.09, 1.5
	cue.Parent = game:GetService("SoundService")
	Debris:AddItem(cue, 0.3)
	playBudgeted(cue, melodyVoices, 4)
end

local function countForQuality(values: {[string]: number}, quality: string?, fallback: number): number
	local value = values[quality or "normal"]
	if typeof(value) == "number" then
		return value
	end
	return fallback
end

local function colorForQuality(quality: string?): Color3
	if quality == "perfect" then
		return FX.SkipLabel.PerfectColor
	elseif quality == "weak" then
		return FX.SkipLabel.WeakColor
	end
	return FX.SkipLabel.NormalColor
end


-- Procedural open water crowns: no filled disc obscures the pebble.
-- Bounded segments and Debris cleanup keep long throws inexpensive.
local function spawnCrescendo(position: Vector3, skipIndex: number, quality: string?)
	local c = FX.Crescendo
	if not c.Enabled or skipIndex < 1 then return end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - position).Magnitude > c.MaxDistance then return end
	local stage = ThrowConfig.getSkipMilestone(skipIndex)
	local milestone = stage ~= nil and skipIndex == stage.Skips
	local color = if stage then stage.Color else colorForQuality(quality)
	local duration = if milestone then c.MilestoneDuration else c.RingDuration
	local radius = if milestone then stage.Radius else c.RingRadius + c.RingGrowth
	for ringIndex = 1, (if milestone then c.WaveRings else 1) do
		task.delay((ringIndex - 1) * c.WaveRingDelay, function()
			local anchor = makeAnchor(position + Vector3.new(0, 0.15, 0), duration + 0.15)
			anchor.Name = "SkipCrescendo"
			anchor:SetAttribute("MilestoneWave", milestone)
			anchor:SetAttribute("TargetRadius", radius)
			local points: {Attachment} = {}
			for i = 0, c.RingSegments do
				local angle = i / c.RingSegments * math.pi * 2
				local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
				local point = Instance.new("Attachment")
				point.Position = direction * c.RingRadius
				point.Parent = anchor
				table.insert(points, point)
				local height = if milestone and i % 2 == 1 then c.CrownHeight else 0
				TweenService:Create(point, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = direction * radius + Vector3.new(0, height, 0),
				}):Play()
				if i > 0 then
					local beam = Instance.new("Beam")
					beam.Name = "WaterCrown"
					beam.Attachment0 = points[i]
					beam.Attachment1 = point
					beam.FaceCamera = true
					beam.Color = ColorSequence.new(color)
					beam.LightEmission = 1
					beam.Transparency = NumberSequence.new(0.15)
					beam.Width0 = c.RingWidth * (if milestone then 6 else 1)
					beam.Width1 = beam.Width0
					beam.Parent = anchor
					TweenService:Create(beam, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Width0 = 0, Width1 = 0,
					}):Play()
				end
			end
		end)
	end
end

function ThrowFx.setFlightMilestone(pebble: Model, skips: number)
	flightSkipCounts[pebble] = skips
	flightImpacts[pebble] = os.clock()
	local stage = ThrowConfig.getSkipMilestone(skips)
	local setColor = flightColors[pebble]
	if stage and setColor then setColor(stage.Color) end
end

function ThrowFx.onSkipSpectacle(pebble: Model?, position: Vector3, skips: number, velocity: Vector3?, quality: string?, isLocal: boolean?)
	Spectacle.skip(pebble, position, skips, velocity, quality, isLocal)
end

function ThrowFx.finishSpectacle(result)
	Spectacle.finish(result)
end

-- Duck only ambience/music groups through an equalizer, preserving volume sliders.
local duckGeneration = 0
local duckEffects: {EqualizerSoundEffect} = {}
local function duckAmbience(strength: number)
	duckGeneration += 1
	local token = duckGeneration
	if #duckEffects == 0 then
		for _, item in game:GetService("SoundService"):GetDescendants() do
			local name = string.lower(item.Name)
			if (item:IsA("SoundGroup") or item:IsA("Sound")) and (string.find(name,"ambien") or string.find(name,"music")) then
				local eq = Instance.new("EqualizerSoundEffect")
				eq.Name = "ThrowFocusDuck"; eq.Parent = item
				table.insert(duckEffects, eq)
			end
		end
	end
	for _, eq in duckEffects do
		if eq.Parent then eq.LowGain = -strength; eq.MidGain = -strength; eq.HighGain = -strength end
	end
	task.delay(0.14, function()
		if token ~= duckGeneration then return end
		for _, eq in duckEffects do
			if eq.Parent then TweenService:Create(eq, TweenInfo.new(0.45), {LowGain=0,MidGain=0,HighGain=0}):Play() end
		end
	end)
end

function ThrowFx.duckPerfect()
	duckAmbience(7)
end

function ThrowFx.duckRecord()
	duckAmbience(8)
end

local function playUpgrade(anchor: BasePart, isLocalThrow: boolean?)
	local c = FX.Crescendo
	for i, pitch in c.UpgradeNotes do
		task.delay((i - 1) * c.UpgradeNoteDelay, function()
			if not anchor.Parent then return end
			local sound = Instance.new("Sound")
			sound.Name = "SkipUpgrade"
			sound.SoundId = c.UpgradeSoundId
			sound.Volume = c.UpgradeVolume
			sound.PlaybackSpeed = pitch
			sound.Parent = if isLocalThrow then game:GetService("SoundService") else anchor
			sound.RollOffMinDistance = FX.Audio.ImpactRollOffMin
			sound.RollOffMaxDistance = FX.Audio.ImpactRollOffMax
			Debris:AddItem(sound, c.NoteLifetime)
			playBudgeted(sound, upgradeVoices, c.MaxNoteVoices)
		end)
	end
end

local function spawnSkipLabel(position: Vector3, skipIndex: number, quality: string?)
	if not FX.SkipLabel.Enabled then
		return
	end
	local anchor = makeAnchor(position + Vector3.new(0, FX.SkipLabel.Height, 0), FX.SkipLabel.Duration + 0.15)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SkipLabel"
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = FX.SkipLabel.MaxDistance
	local c = FX.Crescendo
	local stage = ThrowConfig.getSkipMilestone(skipIndex)
	local milestone = c.Enabled and stage ~= nil and skipIndex == stage.Skips
	billboard.Size = UDim2.fromOffset(c.LabelWidth, c.LabelHeight)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, FX.SkipLabel.StudsOffset, 0)
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	local milestoneName = if stage then stage.Name else ""
	label.Text = if milestone then string.format("%s • %d", milestoneName, skipIndex) else string.format("SKIP %d", skipIndex)
	label.TextColor3 = if stage then stage.Color else colorForQuality(quality)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.32
	label.Font = Enum.Font.GothamBlack
	label.TextSize = FX.SkipLabel.TextSize
	label.Parent = billboard
	local pop = Instance.new("UIScale")
	pop.Scale = c.LabelPunchScale
	pop.Parent = label
	TweenService:Create(pop, TweenInfo.new(c.LabelPunchTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()

	TweenService:Create(billboard, TweenInfo.new(FX.SkipLabel.Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(0, FX.SkipLabel.StudsOffset + 2.2, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(FX.SkipLabel.Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
end

function ThrowFx.playReleaseBurst(position: Vector3, direction: Vector3, quality: string?, isSonicBoom: boolean?)
	local launch = FX.Launch
	local releaseAnchor = makeAnchor(position, 1.4)
	for i, layer in {{WOOSH_SOUND_ID, 0.16, 1.8}, {COMBO_SOUND_ID, 0.10, 0.62}, {WOOSH_SOUND_ID, 0.11, 0.7}} do
		local sound = Instance.new("Sound")
		sound.Name = "ReleaseLayer" .. i; sound.SoundId = layer[1]; sound.Volume = layer[2]; sound.PlaybackSpeed = layer[3]
		sound.Parent = releaseAnchor; playImpact(sound)
	end
	if quality == "perfect" then duckAmbience(7) end
	local safeDirection = if direction.Magnitude > 0.001 then direction.Unit else Vector3.new(0, 0, -1)
	local anchor = makeAnchor(position, launch.AnchorLifetime)
	local forward = Instance.new("Attachment")
	forward.CFrame = CFrame.lookAt(Vector3.zero, (safeDirection + Vector3.new(0, 0.24, 0)).Unit)
	forward.Parent = anchor

	local rippleDiameter = countForQuality(launch.RippleDiameter, quality, launch.RippleDiameter.normal)
	local waterY = WaterSurface.at(position)
	if waterY then
		spawnRipple(Vector3.new(position.X, waterY + 0.05, position.Z), rippleDiameter, launch.RippleDuration, if quality == "perfect" then Color3.fromRGB(255, 238, 145) else RIPPLE_COLOR)
	end

	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = PARTICLE_SPARK
	sparks.Color = if isSonicBoom
		then ColorSequence.new(Color3.fromRGB(255, 190, 70), Color3.fromRGB(255, 255, 235))
		else ColorSequence.new(colorForQuality(quality))
	sparks.LightEmission = if quality == "weak" then 0.35 else 1
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if isSonicBoom then 0.42 else 0.28),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Lifetime = NumberRange.new(launch.SparkLifetimeMin, launch.SparkLifetimeMax)
	sparks.Speed = NumberRange.new(launch.SparkSpeedMin, if isSonicBoom then launch.SparkSpeedMax * 1.35 else launch.SparkSpeedMax)
	sparks.SpreadAngle = Vector2.new(32, 46)
	sparks.Drag = 3
	sparks.Rate = 0
	sparks.Enabled = false
	sparks.Parent = forward
	sparks:Emit(countForQuality(launch.SparkCount, quality, launch.SparkCount.normal))

	local smokeCount = countForQuality(launch.SmokeCount, quality, launch.SmokeCount.normal)
	if smokeCount > 0 then
		local dust = Instance.new("ParticleEmitter")
		dust.Texture = PARTICLE_SOFT
		dust.Color = ColorSequence.new(if quality == "weak" then Color3.fromRGB(145, 145, 145) else Color3.fromRGB(215, 236, 245))
		dust.LightEmission = 0.15
		dust.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.38),
			NumberSequenceKeypoint.new(1, 1),
		})
		dust.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, if quality == "weak" then 1.25 else 0.75),
			NumberSequenceKeypoint.new(1, 0.08),
		})
		dust.Lifetime = NumberRange.new(0.25, 0.5)
		dust.Speed = NumberRange.new(launch.SmokeSpeedMin, launch.SmokeSpeedMax)
		dust.SpreadAngle = Vector2.new(42, 42)
		dust.Drag = 4
		dust.Rate = 0
		dust.Enabled = false
		dust.Parent = forward
		dust:Emit(smokeCount)
	end
end

--[[
	Plays a water impact. `impactVelocity` is the rock's velocity at the moment
	it crossed the surface, which sets how violent the plume is and which way
	the spray leans. `quality` (optional) is the ThrowConfig quality tier for
	the THROW the skip belongs to ("perfect" | "nearMiss" | "normal" | "weak");
	a "weak" throw gets a visibly and audibly smaller splash on every skip, not
	just a shorter flight.
]]
function ThrowFx.playSplash(
	position: Vector3,
	skipIndex: number,
	tier: number,
	impactVelocity: Vector3?,
	tierUp: boolean?,
	quality: string?,
	isLocalThrow: boolean?,
	contactGrade: string?
)
	local camera = workspace.CurrentCamera
	local distance = if camera then (camera.CFrame.Position - position).Magnitude else 0
	if not isLocalThrow and distance > 220 then return end
	local distant = not isLocalThrow and distance > 95
	local profile = qualityProfile(quality)
	local velocity = impactVelocity or Vector3.new(0, FX.Splash.FallbackVerticalSpeed, 0)
	local comboGrowth = math.min(math.max(0, skipIndex - 1) * FX.Splash.ComboGrowthPerSkip, FX.Splash.ComboGrowthCap)
	local strength = math.clamp(
		math.abs(velocity.Y) / IMPACT_REFERENCE_SPEED,
		FX.Splash.MinimumStrength,
		FX.Splash.MaximumStrength
	) * profile.SplashStrength * (1 + comboGrowth)
	strength = math.min(strength, FX.Splash.MaximumStrength)
	if contactGrade == "skim" then strength *= 0.74
	elseif contactGrade == "rough" then strength = math.min(strength * 1.18, 1.2) end

	local rig=splashRig()
 local anchor=rig.anchor
 anchor.CFrame=CFrame.new(position);anchor.Parent=workspace
 rig.expires=os.clock()+math.max(math.min(FX.Splash.AnchorLifetime,1.1),FX.Crescendo.NoteLifetime)
 table.insert(activeSplashes,rig)
	local volumeScale = profile.SplashVolume
	local milestone = ThrowConfig.getSkipMilestone(skipIndex)
	local atMilestone = milestone ~= nil and milestone.Skips == skipIndex
	if not distant and (skipIndex <= 3 or atMilestone) then spawnSkipLabel(position, skipIndex, quality) end
	if not distant and atMilestone then spawnCrescendo(position, skipIndex, quality) end
	if isLocalThrow then
		impactPulse = -(if skipIndex == 1 then 0.32 elseif atMilestone then 0.24 else 0.07)
		if atMilestone then milestoneFov = 3.8 end
		if skipIndex == 1 or atMilestone then duckAmbience(if atMilestone then 8 else 5) end
	end
	local stage = ThrowConfig.getSkipMilestone(skipIndex)
	local effectColor = if contactGrade == "rough" then Color3.fromRGB(239, 250, 255)
		elseif stage then stage.Color elseif quality == "perfect" then Color3.fromRGB(138, 247, 255) else SPLASH_COLOR
	if stage and skipIndex == stage.Skips then playUpgrade(anchor, isLocalThrow) end

	local splash = component(rig,"Splash","Sound",anchor)
	splash.SoundId = SPLASH_SOUND_ID
	splash.Volume = (FX.Splash.VolumeBase + FX.Splash.VolumeStrength * strength) * volumeScale
		* (if contactGrade == "skim" then 0.46 elseif contactGrade == "rough" then 0.9 else 0.65)
	splash.PlaybackSpeed = (FX.Splash.PitchBase - FX.Splash.PitchStrength * strength)
		* ({0.94, 1.02, 1.08})[(skipIndex - 1) % 3 + 1]
		* (if contactGrade == "skim" then 1.12 elseif contactGrade == "rough" then 0.82 else 1)
	splash.Parent = anchor
	playImpact(splash)

	local playNote = contactGrade ~= "rough" and (skipIndex == 1 or atMilestone
		or (skipIndex % 3 == 0 and os.clock() - lastOwnerMelody >= 0.4))
	if playNote then
	if isLocalThrow then lastOwnerMelody = os.clock() end
	local combo = component(rig,"Combo","Sound",anchor)
	combo.SoundId = COMBO_SOUND_ID
	combo.Volume = FX.Splash.ComboVolume * volumeScale * 0.45
	local melody = FX.Crescendo
	local note = melody.Notes[(skipIndex - 1) % #melody.Notes + 1] + math.min(12, math.floor((skipIndex - 1) / #melody.Notes) * 2)
	combo.PlaybackSpeed = if melody.Enabled then math.min(melody.BasePitch * 2 ^ (note / 12), melody.MaxPitch)
		else math.min(FX.Splash.ComboPitchBase + skipIndex * FX.Splash.ComboPitchPerSkip, FX.Splash.ComboPitchMax)
	combo.Name = "SkipMelody"
	if isLocalThrow and melody.Enabled then
		-- Owner feedback stays audible even when the pebble leaves the listener.
		combo.Volume = melody.LocalNoteVolume * 0.45
		combo.Parent = game:GetService("SoundService")
		-- The pooled rig retires after the full note lifetime.
		playBudgeted(combo, melodyVoices, melody.MaxNoteVoices)
	else
		combo.Parent = anchor
		playImpact(combo)
	end

	end
	-- Only on the skip that CROSSES into a new tier. Playing it on every skip
	-- meant a 43-skip throw fired the tier stinger ~38 times.
	local tierSoundId = if tierUp and not atMilestone then TIER_SOUND_IDS[tier] else nil
	if tierSoundId then
		local tierSound = component(rig,"Tier","Sound",anchor)
		tierSound.SoundId = tierSoundId
		tierSound.Volume = FX.Splash.TierVolume * volumeScale
		tierSound.PlaybackSpeed = FX.Splash.TierPitchBase + (tier - 1) * FX.Splash.TierPitchPerTier
		tierSound.Parent = anchor
		playImpact(tierSound)
	end

	if skipIndex == 1 or atMilestone then
		local body = component(rig,"Body","Sound",anchor)
		body.Name = "WaterBody"; body.SoundId = SPLASH_SOUND_ID; body.Volume = 0.14; body.PlaybackSpeed = 0.58
		body.Parent = anchor; playImpact(body)
	end
	if distant then return end
	if isLocalThrow then
		if not atMilestone and skipIndex > 3 and os.clock() - lastOwnerVisual < 0.10 then return end
		lastOwnerVisual = os.clock()
	end
	if skipIndex == 1 then strength = math.min(1.3, strength * 1.3) end
	-- Thin open ripples preserve the silhouette of the stone.
	spawnRipple(position, 5 + 12 * strength, 0.36 + 0.2 * strength, effectColor)
	if strength > 0.55 then
		spawnRipple(position, 2.5 + 4 * strength, 0.22, Color3.fromRGB(245, 255, 255))
	end

	-- Spray: a cone kicked up and slightly along the direction of travel.
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local lean = if horizontal.Magnitude > 1 then horizontal.Unit else Vector3.zero
	local sprayAnchor = component(rig,"SprayAnchor","Attachment",anchor)
	sprayAnchor.CFrame = CFrame.lookAt(Vector3.zero, (Vector3.new(0, 1, 0) + lean * 0.85).Unit)
	sprayAnchor.Parent = anchor

	local spray = component(rig,"Spray","ParticleEmitter",sprayAnchor)
	spray.Texture = PARTICLE_SPARK
	spray.EmissionDirection = Enum.NormalId.Front
	spray.Color = ColorSequence.new(effectColor)
	spray.LightEmission = 0.45
	spray.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	spray.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2 + 0.5 * strength),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	spray.Lifetime = NumberRange.new(0.22, 0.5)
	spray.Speed = NumberRange.new(12 * strength, 34 * strength)
	spray.SpreadAngle = Vector2.new(18, 30)
	spray.Drag = 3
	spray.Acceleration = Vector3.new(0, -70, 0) + horizontal * 0.28
	spray.Rate = 0
	spray.Enabled = false
	spray.Parent = sprayAnchor
	spray:Emit(math.floor(8 + 18 * strength))

	-- A bright, short-lived crown and soft spray give the water contact some
	-- volume. These share the splash anchor, so no particles can linger after it.
	local droplets = component(rig,"Droplets","ParticleEmitter",sprayAnchor)
	droplets.Texture = PARTICLE_SOFT
	droplets.EmissionDirection = Enum.NormalId.Front
	droplets.Color = ColorSequence.new(Color3.fromRGB(218, 251, 255))
	droplets.LightEmission = 0.55
	droplets.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(0.55, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	droplets.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.28 + 0.34 * strength),
		NumberSequenceKeypoint.new(0.6, 0.4 + 0.4 * strength),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	droplets.Lifetime = NumberRange.new(0.28, 0.52)
	droplets.Speed = NumberRange.new(8 * strength, 22 * strength)
	droplets.SpreadAngle = Vector2.new(62, 62)
	droplets.Drag = 1.5
	droplets.Acceleration = Vector3.new(0, -56, 0)
	droplets.Rate = 0
	droplets.Enabled = false
	droplets.Parent = sprayAnchor
	droplets:Emit(math.floor(8 + 12 * strength))

	if strength > 0.45 then
		local mist = component(rig,"Mist","ParticleEmitter",sprayAnchor)
		mist.Texture = PARTICLE_SOFT
		mist.EmissionDirection = Enum.NormalId.Front
		mist.Color = ColorSequence.new(Color3.fromRGB(231, 251, 255))
		mist.LightEmission = 0.25
		mist.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.65),
			NumberSequenceKeypoint.new(1, 1),
		})
		mist.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.8 * strength),
			NumberSequenceKeypoint.new(1, 2.4 * strength),
		})
		mist.Lifetime = NumberRange.new(0.2, 0.38)
		mist.Speed = NumberRange.new(3, 9)
		mist.SpreadAngle = Vector2.new(45, 45)
		mist.Drag = 5
		mist.Rate = 0
		mist.Enabled = false
		mist.Parent = sprayAnchor
		mist:Emit(math.floor(3 + 5 * strength))
	end

	-- Brief parallel wakes make the stone's travel direction readable from the
	-- chase camera. They fade before the next water contact.
	if lean.Magnitude > 0 and strength > 0.4 then
		local sideways = Vector3.new(-lean.Z, 0, lean.X)
		for side = -1, 1, 2 do
			local start = position + lean * 1.2 + sideways * side * (0.5 + strength * 0.3) + Vector3.new(0, 0.11, 0)
			local wake = component(rig,"Wake"..side,"Part",anchor)
			wake.Name = "SplashWake"
			wake.Anchored = true
			wake.CanCollide = false
			wake.CanQuery = false
			wake.CanTouch = false
			wake.Material = Enum.Material.Neon
			wake.Color = Color3.fromRGB(226, 252, 255)
			wake.Transparency = 0.45
			wake.Size = Vector3.new(0.13 + 0.12 * strength, 0.025, 0.8)
			wake.CFrame = CFrame.lookAt(start, start + lean)
			wake.Parent = anchor
			-- Reused with this impact rig after the wake finishes.
			local wakeTween=TweenService:Create(wake, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = wake.CFrame + lean * (2 + 2 * strength),
				Size = Vector3.new(0.05, 0.025, 3 + 3 * strength),
				Transparency = 1,
			})
            table.insert(rig.tweens,wakeTween);wakeTween:Play()
		end
	end

	-- A few sharp glints on harder impacts only.
	if strength > 0.45 then
		local glint = component(rig,"Glint","ParticleEmitter",sprayAnchor)
		glint.Texture = PARTICLE_SPARK
		glint.Color = ColorSequence.new(effectColor)
		glint.LightEmission = 1
		glint.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		glint.Size = NumberSequence.new(0.35 * strength)
		glint.Lifetime = NumberRange.new(0.15, 0.3)
		glint.Speed = NumberRange.new(18 * strength, 40 * strength)
		glint.SpreadAngle = Vector2.new(55, 55)
		glint.Acceleration = Vector3.new(0, -90, 0)
		glint.Rate = 0
		glint.Enabled = false
		glint.Parent = sprayAnchor
		glint:Emit(math.floor(4 + 10 * strength))
	end
end

-- Water endings use the confirmed result. A failed launch gets a short plunk;
-- a completed run resolves with a fuller ripple, without another combo reward.
function ThrowFx.playSink(position: Vector3, quality: string?, skips: number?, endReason: string?)
	if endReason and endReason ~= "sunk" and endReason ~= "skipLimit" then
		if endReason == "obstacle" or endReason == "collision" then
			local anchor = makeAnchor(position, 1)
			local clack = Instance.new("Sound"); clack.SoundId = COMBO_SOUND_ID
			clack.Volume = 0.2; clack.PlaybackSpeed = 0.48; clack.Parent = anchor; playImpact(clack)
		end
		return
	end
	local waterY = WaterSurface.at(position)
	if not waterY then return end
	position = Vector3.new(position.X, waterY, position.Z)
	local count = math.max(0, skips or 0)
	-- No optional result data preserves the former, full-sized sink effect.
	local stage = ThrowConfig.getSkipMilestone(skips or 0)
	local sinkColor = if stage then stage.Color else SPLASH_COLOR
	local failed = if skips ~= nil then count < FX.Sink.SuccessMinSkips else quality == "weak"
	local scale = if failed then FX.Sink.FailureScale else 1 + math.min(count * FX.Sink.SuccessGrowthPerSkip, FX.Sink.SuccessGrowthCap)
	local anchor = makeAnchor(position, FX.Sink.AnchorLifetime)

	local splash = Instance.new("Sound")
	splash.SoundId = SPLASH_SOUND_ID
	splash.Volume = if failed then FX.Sink.FailureVolume else FX.Sink.Volume
	splash.PlaybackSpeed = if failed then FX.Sink.FailurePitch else FX.Sink.Pitch
	splash.Parent = anchor
	playImpact(splash)
	local resolve = Instance.new("Sound")
	resolve.SoundId = COMBO_SOUND_ID; resolve.Volume = if failed then 0.08 else 0.19
	resolve.PlaybackSpeed = if failed then 0.5 else 1; resolve.Parent = anchor; playImpact(resolve)

	spawnRipple(position, FX.Sink.RippleDiameter * scale, FX.Sink.RippleDuration, sinkColor)
	spawnRipple(position, FX.Sink.CoreDiameter * scale, FX.Sink.CoreDuration, sinkColor)

	local up = Instance.new("Attachment")
	up.CFrame = CFrame.lookAt(Vector3.zero, Vector3.new(0, 1, 0))
	up.Parent = anchor

	local plume = Instance.new("ParticleEmitter")
	plume.Texture = PARTICLE_SOFT
	plume.Color = ColorSequence.new(sinkColor)
	plume.LightEmission = 0.4
	plume.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	plume.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, FX.Sink.PlumeSize * scale),
		NumberSequenceKeypoint.new(1, FX.Sink.PlumeEndSize),
	})
	plume.Lifetime = NumberRange.new(FX.Sink.PlumeLifeMin, FX.Sink.PlumeLifeMax)
	plume.Speed = NumberRange.new(FX.Sink.PlumeSpeedMin * scale, FX.Sink.PlumeSpeedMax * scale)
	plume.SpreadAngle = Vector2.new(30, 30)
	plume.Drag = 2.5
	plume.Acceleration = Vector3.new(0, -60, 0)
	plume.Rate = 0
	plume.Enabled = false
	plume.Parent = up
	plume:Emit(math.floor(FX.Sink.PlumeCount * scale))
end

-- ============================================================================
-- Sonic rings
-- ============================================================================

-- Open rings keep the rock and water visible during a sonic break.
local function spawnFlightOutline(position: Vector3, direction: Vector3, diameter: number, duration: number, color: Color3, name: string)
	local axis = if direction.Magnitude > 0.001 then direction.Unit else Vector3.xAxis
	local frame = CFrame.lookAt(position, position + axis)
	local right, up = frame.RightVector, frame.UpVector
	local segments = if diameter > 20 then 14 else 10
	local startRadius = if diameter > 20 then 2 else 1.5
	local endRadius = diameter * 0.5
	local thickness = if diameter > 20 then 0.42 else 0.18
	local group = Instance.new("Folder")
	group.Name = name
	group.Parent = workspace
	local function segmentFrame(index: number, radius: number)
		local a = 2 * math.pi * (index - 1) / segments
		local b = 2 * math.pi * index / segments
		local p1 = position + radius * (right * math.cos(a) + up * math.sin(a))
		local p2 = position + radius * (right * math.cos(b) + up * math.sin(b))
		return CFrame.lookAt((p1 + p2) * 0.5, p2), (p2 - p1).Magnitude
	end
	for index = 1, segments do
		local ringEdge = Instance.new("Part")
		ringEdge.Name = "Edge"
		ringEdge.Anchored = true
		ringEdge.CanCollide = false
		ringEdge.CanQuery = false
		ringEdge.CanTouch = false
		ringEdge.CastShadow = false
		ringEdge.Material = Enum.Material.Neon
		ringEdge.Color = color
		ringEdge.Transparency = if diameter > 20 then 0.25 else 0.4
		local fromFrame, fromLength = segmentFrame(index, startRadius)
		local toFrame, toLength = segmentFrame(index, endRadius)
		ringEdge.CFrame = fromFrame
		ringEdge.Size = Vector3.new(thickness, thickness, fromLength)
		ringEdge.Parent = group
		TweenService:Create(ringEdge, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = toFrame,
			Size = Vector3.new(thickness * 0.35, thickness * 0.35, toLength),
			Transparency = 1,
		}):Play()
	end
	Debris:AddItem(group, duration + 0.12)
end

local function spawnSonicRing(position: Vector3, direction: Vector3, color: Color3?)
	spawnFlightOutline(position, direction, 9, 0.3, color or Color3.fromRGB(230, 249, 255), "SonicRing")
end

-- ============================================================================
-- Sound barrier break: the grand version
-- ============================================================================

local function configureBoomSound(sound: Sound, volume: number, pitch: number)
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMinDistance = BOOM_ROLLOFF_MIN
	sound.RollOffMaxDistance = BOOM_ROLLOFF_MAX
end

local function lightningFlash(position: Vector3)
	local camera = workspace.CurrentCamera
	if motionScale() == 0 or localPlayer:GetAttribute("ReducedThrowFlashes") == true or not camera or flashActive then
		return
	end
	if (camera.CFrame.Position - position).Magnitude > FLASH_MAX_DISTANCE then
		return
	end

	flashActive = true
	Lighting.ExposureCompensation = baseExposure + FLASH_STRENGTH
	local tween = TweenService:Create(
		Lighting,
		TweenInfo.new(FLASH_FADE, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ExposureCompensation = baseExposure}
	)
	tween.Completed:Once(function()
		Lighting.ExposureCompensation = baseExposure
		flashActive = false
	end)
	tween:Play()
end

-- A single jagged bolt: a few segments, each kinked off the last, so it reads
-- as lightning rather than a straight laser.
local function spawnBolt(origin: Vector3, direction: Vector3)
	local cursor = origin
	local heading = direction

	for _ = 1, 3 do
		local length = 12 + math.random() * 20
		heading = (heading + Vector3.new(
			(math.random() - 0.5) * 1.1,
			(math.random() - 0.5) * 0.8,
			(math.random() - 0.5) * 1.1
			)).Unit
		local finish = cursor + heading * length

		local bolt = Instance.new("Part")
		bolt.Name = "BoomArc"
		bolt.Size = Vector3.new(0.4, 0.4, length)
		bolt.Material = Enum.Material.Neon
		bolt.Color = Color3.fromRGB(215, 238, 255)
		bolt.Anchored = true
		bolt.CanCollide = false
		bolt.CanQuery = false
		bolt.CanTouch = false
		bolt.CastShadow = false
		bolt.CFrame = CFrame.lookAt((cursor + finish) / 2, finish)
		bolt.Parent = workspace

		TweenService:Create(bolt, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1,
			Size = Vector3.new(0.05, 0.05, length),
		}):Play()
		Debris:AddItem(bolt, 0.35)

		cursor = finish
	end
end

-- A big shock ring perpendicular to travel, distinct from the small trailing
-- rings the rock leaves while it is still supersonic.
local function spawnShockRing(position: Vector3, direction: Vector3, maxSize: number, duration: number)
	spawnFlightOutline(position, direction, maxSize, duration, Color3.fromRGB(226, 246, 255), "BoomShockRing")
end

--[[
	Fires once, at release, for a throw that breaks the sound barrier.

	Layered audio (crack / body / sub / thunder tail), three staggered shock
	rings, a shock ripple across the water beneath, a burst of bolts and a
	lightning flash. Only runs on sonic-boom throws, so the cost is paid rarely
	and it is allowed to be expensive.
]]
function ThrowFx.sonicBoomBreak(position: Vector3, direction: Vector3)
	for index = #boomAnchors, 1, -1 do
		if not boomAnchors[index].Parent then
			table.remove(boomAnchors, index)
		end
	end
	while #boomAnchors >= math.max(1, FX.Audio.MaxBooms) do
		table.remove(boomAnchors, 1):Destroy()
	end
	local anchor = Instance.new("Part")
	anchor.Name = "SonicBoomBreak"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace
	Debris:AddItem(anchor, FX.Sonic.AnchorLifetime)
	table.insert(boomAnchors, anchor)

	-- Sharp leading crack.
	local crack = Instance.new("Sound")
	crack.SoundId = SONIC_BOOM_SOUND_ID
	configureBoomSound(crack, FX.Sonic.CrackVolume, FX.Sonic.CrackPitch)
	crack.Parent = anchor
	crack:Play()

	-- Body of the boom.
	local body = Instance.new("Sound")
	body.SoundId = SONIC_BOOM_SOUND_ID
	configureBoomSound(body, FX.Sonic.BodyVolume, FX.Sonic.BodyPitch)
	body.Parent = anchor
	body:Play()

	-- Sub-bass, slightly behind so it lands as a thump rather than a click.
	task.delay(FX.Sonic.SubDelay, function()
		if not anchor.Parent then
			return
		end
		local sub = Instance.new("Sound")
		sub.SoundId = SONIC_BOOM_SOUND_ID
		configureBoomSound(sub, FX.Sonic.SubVolume, FX.Sonic.SubPitch)
		sub.Parent = anchor
		sub:Play()
	end)

	-- Thunder tail, close behind the crack.
	task.delay(FX.Sonic.TailDelay, function()
		if not anchor.Parent then
			return
		end
		local thunder = Instance.new("Sound")
		thunder.SoundId = THUNDER_SOUND_ID
		configureBoomSound(thunder, FX.Sonic.TailVolume, FX.Sonic.TailPitch)
		thunder.Parent = anchor
		thunder:Play()
	end)

	-- A second, quieter, lower clap further back, so the thunder rolls away
	-- instead of stopping dead.
	task.delay(FX.Sonic.RollDelay, function()
		if not anchor.Parent then
			return
		end
		local roll = Instance.new("Sound")
		roll.SoundId = THUNDER_SOUND_ID
		configureBoomSound(roll, FX.Sonic.RollVolume, FX.Sonic.RollPitch)
		roll.Parent = anchor
		roll:Play()
	end)

	-- Three rings, staggered, growing: one event expanding rather than three.
	spawnShockRing(position, direction, 60, 0.45)
	task.delay(0.05, function()
		spawnShockRing(position, direction, 105, 0.6)
	end)
	task.delay(0.12, function()
		spawnShockRing(position, direction, 165, 0.85)
	end)

	-- Shock spreading across the water directly beneath the break.
	local waterY = WaterSurface.at(position)
	if waterY then
		local surface = Vector3.new(position.X, waterY + 0.06, position.Z)
		spawnRipple(surface, 150, 0.95, Color3.fromRGB(235, 250, 255))
		spawnRipple(surface, 70, 0.5, Color3.fromRGB(255, 255, 255))
	end

	-- Bolts radiating out, biased along the direction of travel.
	for _ = 1, 7 do
		local scatter = Vector3.new(
			(math.random() - 0.5) * 2,
			(math.random() - 0.5) * 1.2,
			(math.random() - 0.5) * 2
		)
		spawnBolt(position, (direction * 0.6 + scatter).Unit)
	end

	lightningFlash(position)
end

-- ============================================================================
-- Flight effects: attached to any pebble, local or remote
-- ============================================================================

--[[
	Attaches trail, woosh and sonic rings to a pebble in flight. The layered
	launch boom lives exclusively in sonicBoomBreak, avoiding a duplicate hit.
	`throwerRoot` remains accepted for existing callers. Optional server quality
	scales trail and woosh without changing the equipped trail's color.
	Returns a cleanup function.
]]
function ThrowFx.attachFlight(
	pebble: Model,
	mainPart: BasePart,
	isSonicBoom: boolean,
	launchSpeed: number,
	throwerRoot: BasePart?,
	rockId: string?,
	quality: string?,
	localSteer: (() -> number)?
): () -> ()
	local isOwner = pebble:GetAttribute("ThrowerUserId") == localPlayer.UserId
	local spectacleCleanup = Spectacle.begin(pebble, mainPart, quality)
	local isWeak = quality == "weak"
	local profile = qualityProfile(quality)
	local trailLifetime = math.min(if isOwner then 0.045 else 0.12, if isSonicBoom then FX.Trail.SonicLifetime else profile.TrailLifetime)
	local ribbonHalfWidth = if isOwner then 0.07 else 0.18

	-- Trail down the stone's long axis. This is the primary cosmetic surface:
	-- it is what other players actually see of someone else's throw.
	local tailAttachment = Instance.new("Attachment")
	tailAttachment.Name = "TrailTail"
	tailAttachment.Position = Vector3.new(-ribbonHalfWidth, 0, 0.25)
	tailAttachment.Parent = mainPart

	local headAttachment = Instance.new("Attachment")
	headAttachment.Name = "TrailHead"
	headAttachment.Position = Vector3.new(ribbonHalfWidth, 0, 0.25)
	headAttachment.Parent = mainPart

	local trail = Instance.new("Trail")
	trail.Attachment0 = headAttachment
	trail.Attachment1 = tailAttachment
	trail.Lifetime = trailLifetime
	trail.MinLength = 0
	trail.FaceCamera = false
	trail.LightEmission = (if isSonicBoom then FX.Trail.SonicEmission else profile.TrailEmission) * (if isOwner then 0.65 else 1)
	-- The equipped rock owns its trail. A sonic boom still overrides it,
	-- because breaking the barrier should look the same whatever you threw.
	-- A weak throw overrides it the other way: however nice the equipped
	-- rock's trail is, a fumbled release doesn't get to show it off.
	trail.Color = if isSonicBoom
		then TRAIL_COLOR_BOOM
		elseif isWeak
		then TRAIL_COLOR_WEAK
		else RockCatalog.trailSequence(RockCatalog.get(rockId))
	if pebble:GetAttribute("Variant") == "Enchanted" then
		local _, accent, glow = RockAppearance.palette(rockId or RockCatalog.Default)
		trail.Color = ColorSequence.new(accent, glow)
	end
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, math.max(0.38, if isSonicBoom then FX.Trail.SonicTransparency else profile.TrailTransparency)),
		NumberSequenceKeypoint.new(0.32, 0.72),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Parent = mainPart

	local flightEmitter: ParticleEmitter? = nil
	local flightRate = countForQuality(FX.Trail.ParticleRate, quality, FX.Trail.ParticleRate.normal)
	if isSonicBoom then
		flightRate *= 1.7
	end
	if flightRate > 0 then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "PebbleFlightSparkles"
		emitter.Texture = PARTICLE_SPARK
		emitter.Color = if isSonicBoom
			then TRAIL_COLOR_BOOM
			else ColorSequence.new(colorForQuality(quality))
		emitter.LightEmission = if isWeak then 0.35 else 1
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, if isWeak then 0.45 else 0.08),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, if isSonicBoom then FX.Trail.ParticleSize * 1.6 else FX.Trail.ParticleSize),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Lifetime = NumberRange.new(FX.Trail.ParticleLifetime * 0.7, FX.Trail.ParticleLifetime)
		emitter.Speed = NumberRange.new(0, FX.Trail.ParticleSpeed)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Drag = 2
		emitter.Rate = flightRate
		emitter.Parent = tailAttachment
		flightEmitter = emitter
	elseif isWeak and FX.Trail.WeakSmokeRate > 0 then
		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = "PebbleWeakSmoke"
		smoke.Texture = PARTICLE_SOFT
		smoke.Color = ColorSequence.new(Color3.fromRGB(145, 145, 145))
		smoke.LightEmission = 0.05
		smoke.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		smoke.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.38),
			NumberSequenceKeypoint.new(1, 0.05),
		})
		smoke.Lifetime = NumberRange.new(0.18, 0.32)
		smoke.Speed = NumberRange.new(0.2, 0.9)
		smoke.SpreadAngle = Vector2.new(180, 180)
		smoke.Rate = FX.Trail.WeakSmokeRate
		smoke.Parent = tailAttachment
		flightEmitter = smoke
	end

	local boomLight: PointLight? = nil
	if isSonicBoom then
		local light = Instance.new("PointLight")
		light.Color = BOOM_LIGHT_COLOR
		light.Brightness = FX.Trail.SonicLightBrightness
		light.Range = FX.Trail.SonicLightRange
		light.Shadows = false
		light.Parent = mainPart
		boomLight = light
	end

	local wooshVolumeScale = profile.WooshScale

	local woosh = Instance.new("Sound")
	woosh.Name = "WooshSound"
	woosh.SoundId = WOOSH_SOUND_ID
	woosh.Looped = true
	woosh.Volume = WOOSH_MAX_VOLUME * wooshVolumeScale
	woosh.PlaybackSpeed = WOOSH_MAX_PITCH
	woosh.RollOffMinDistance = FX.Audio.FlightRollOffMin
	woosh.RollOffMaxDistance = FX.Audio.FlightRollOffMax
	woosh.Parent = mainPart
	playBudgeted(woosh, flightVoices, FX.Audio.MaxFlightVoices)

	local milestoneColor: Color3? = nil
	local baseTrailColor = trail.Color
	local baseEmitterColor = if flightEmitter then flightEmitter.Color else ColorSequence.new(Color3.new(1, 1, 1))
	local function refreshTrailColor()
		trail.Color = if milestoneColor then ColorSequence.new(milestoneColor) else baseTrailColor
		if flightEmitter then
			flightEmitter.Color = if milestoneColor then ColorSequence.new(milestoneColor) else baseEmitterColor
		end
		if boomLight then boomLight.Color = milestoneColor or BOOM_LIGHT_COLOR end
	end
	flightColors[pebble] = function(color: Color3)
		milestoneColor = color
		refreshTrailColor()
	end
	refreshTrailColor()
	local ringMinSpeed = launchSpeed * FX.Sonic.RingSpeedFraction
	local listenerDistance: number? = nil
	local visualBank = 0
	local lastNearAt = 0
	local nearParams = RaycastParams.new()
	nearParams.FilterType = Enum.RaycastFilterType.Exclude
	nearParams.FilterDescendantsInstances = {pebble, localPlayer.Character or pebble}
	nearParams.RespectCanCollide = true
	nearParams.CollisionGroup = ThrowConfig.PebbleCollisionGroup
	local lastRingAt = 0
	local cleaned = false
	local conn: RBXScriptConnection? = nil
	local function cleanup()
		if cleaned then
			return
		end
		cleaned = true
  -- Authored rock emitters also need retiring; some otherwise keep firing
  -- throughout the server's sink/debris delay.
  for _, effect in pebble:GetDescendants() do
   if effect:IsA("ParticleEmitter") then effect.Enabled=false;effect:Clear()
   elseif effect:IsA("Trail") then effect.Enabled=false;effect:Clear()
   elseif effect:IsA("Beam") then effect.Enabled=false end
  end
		spectacleCleanup()
		flightColors[pebble] = nil
		flightImpacts[pebble] = nil
		flightSkipCounts[pebble] = nil
		if conn then
			conn:Disconnect()
			conn = nil
		end
		if woosh.Parent then
			woosh:Stop()
			woosh:Destroy()
		end
		if boomLight then
			boomLight:Destroy()
			boomLight = nil
		end
		if flightEmitter then
			flightEmitter.Enabled = false
			Debris:AddItem(flightEmitter, trailLifetime + FX.Trail.CleanupPadding)
			flightEmitter = nil
		end
		-- Keep the existing trail's fade, then retire its attachments too.
		if trail.Parent then
			trail.Enabled = false
		end
		local linger = trailLifetime + FX.Trail.CleanupPadding
		Debris:AddItem(trail, linger)
		Debris:AddItem(headAttachment, linger)
		Debris:AddItem(tailAttachment, linger)
	end

	conn = RunService.Heartbeat:Connect(function(dt)
		if not mainPart.Parent or not pebble.Parent or pebble:GetAttribute("Sinking") == true or pebble:GetAttribute("ThrowFinished") == true then
			cleanup()
			return
		end

		local velocity = mainPart.AssemblyLinearVelocity
		local speed = velocity.Magnitude
		local factor = math.clamp(speed / math.max(launchSpeed, 1), 0, 1)

		if woosh.Parent then
			if speed < WOOSH_MIN_SPEED then
				woosh.Volume = 0
			else
				woosh.Volume = (WOOSH_MIN_VOLUME + (WOOSH_MAX_VOLUME - WOOSH_MIN_VOLUME) * factor) * wooshVolumeScale
				local camera = workspace.CurrentCamera
				local distance = if camera then (camera.CFrame.Position-mainPart.Position).Magnitude else 0
				local radial = if listenerDistance then (distance-listenerDistance)/math.max(dt,0.001) else 0
				listenerDistance = distance
				local doppler = math.clamp(340/(340+math.clamp(radial,-85,120)),0.82,1.25)
				woosh.PlaybackSpeed = (WOOSH_MIN_PITCH + (WOOSH_MAX_PITCH - WOOSH_MIN_PITCH) * factor) * doppler
			end
		end

		-- Trail thins out and the boom glow dims as the rock loses energy, so
		-- a dying throw visibly runs out of steam.
		local sinceImpact = os.clock() - (flightImpacts[pebble] or 0)
		local terminal = pebble:GetAttribute("TerminalArc") == true
		local punctuation = (if sinceImpact < 0.09 then 0.38 else 1) * (if terminal then 0.45 else 1)
		trail.Lifetime = math.min(math.max(0.012, trailLifetime * (FX.Trail.EnergyFloor + (1 - FX.Trail.EnergyFloor) * factor) * punctuation), (if isOwner then 10 else 16) / math.max(speed, 1))
		local width = ((if isOwner then 0.18 else 0.25) + factor * (if isOwner then 0.18 else 0.24)) * punctuation
		trail.WidthScale = NumberSequence.new(width, 0)
		if isOwner and speed > 25 and os.clock() - lastNearAt > 0.45 then
			local flat = Vector3.new(velocity.X, 0, velocity.Z)
			if flat.Magnitude > 1 then
				local side = flat.Unit:Cross(Vector3.yAxis)
				for _, sign in {-1, 1} do
					local hit = workspace:Raycast(mainPart.Position, side * sign * 3.8, nearParams)
					if hit and hit.Distance > 0.9 then
						lastNearAt = os.clock()
						local sparkAnchor = makeAnchor(hit.Position, 0.5)
						local sparks = Instance.new("ParticleEmitter"); sparks.Texture = PARTICLE_SPARK
						sparks.Color = ColorSequence.new(Color3.fromRGB(255, 214, 119)); sparks.LightEmission = 1
						sparks.Lifetime = NumberRange.new(0.15,0.3); sparks.Speed = NumberRange.new(8,16)
						sparks.Size = NumberSequence.new(0.14,0); sparks.Rate = 0; sparks.Parent = sparkAnchor; sparks:Emit(6)
						milestoneFov = math.max(milestoneFov, 1.4)
						nearMissWhip = sign * 0.07
						break
					end
				end
			end
		end
		local bankTarget = if isOwner and localSteer then localSteer() else (pebble:GetAttribute("SteerBank") or 0)
		visualBank += (bankTarget-visualBank)*(1-math.exp(-18*dt))
		-- Bank the ribbon in world space, while the rock's authored surface spins.
		local flat = Vector3.new(velocity.X,0,velocity.Z)
		if flat.Magnitude > 0.1 then
			local right = flat.Unit:Cross(Vector3.yAxis)
			local bank = visualBank*0.5
			local axis = right*math.cos(bank)+Vector3.yAxis*math.sin(bank)
			headAttachment.Position = mainPart.CFrame:VectorToObjectSpace(axis*ribbonHalfWidth)
			tailAttachment.Position = mainPart.CFrame:VectorToObjectSpace(-axis*ribbonHalfWidth)
		end
		if boomLight then
			boomLight.Brightness = FX.Trail.SonicLightBrightness * factor
		end

		if isSonicBoom and speed >= ringMinSpeed and speed > 0 then
			local now = os.clock()
			if now - lastRingAt >= math.max(SONIC_RING_INTERVAL, if isOwner then 0.23 else 0.16) then
				lastRingAt = now
				spawnSonicRing(mainPart.Position, velocity.Unit, milestoneColor)
			end
		end
	end)

	return cleanup
end

-- ============================================================================
-- Camera
-- ============================================================================

local function cancelCameraMotion(restoreBase: boolean)
	cameraGeneration += 1
	if cameraTween then
		cameraTween:Cancel()
		cameraTween = nil
	end
	if offsetTween then
		offsetTween:Cancel()
		offsetTween = nil
	end
	if rumbleConnection then
		rumbleConnection:Disconnect()
		rumbleConnection = nil
	end
	if restoreBase then
		if tensionCamera and tensionCamera.Parent and restFov then
			tensionCamera.FieldOfView = restFov
		end
		if offsetHumanoid and offsetHumanoid.Parent and restOffset then
			offsetHumanoid.CameraOffset = restOffset
		end
		tensionCamera = nil
		restFov = nil
		offsetHumanoid = nil
		restOffset = nil
	end
end

local function captureOffset(humanoid: Humanoid?)
	if humanoid and humanoid.Parent and humanoid ~= offsetHumanoid then
		if offsetHumanoid and offsetHumanoid.Parent and restOffset then
			offsetHumanoid.CameraOffset = restOffset
		end
		offsetHumanoid = humanoid
		restOffset = humanoid.CameraOffset
	end
end

local function finishCameraMotionAfter(duration: number)
	local generation = cameraGeneration
	task.delay(duration, function()
		if generation == cameraGeneration then
			cancelCameraMotion(true)
		end
	end)
end

local function cancelFollow()
	followGeneration += 1
	if followConnection then
		followConnection:Disconnect()
		followConnection = nil
	end
	if followInputConnection then
		followInputConnection:Disconnect()
		followInputConnection = nil
	end
	if followBeginConnection then
		followBeginConnection:Disconnect()
		followBeginConnection = nil
	end
	if followEndConnection then
		followEndConnection:Disconnect()
		followEndConnection = nil
	end
	if followLookHeld and followPriorMouseBehavior then
		UserInputService.MouseBehavior = followPriorMouseBehavior
	end
	followLookHeld = false
	followPriorMouseBehavior = nil
	if followCamera and followCamera.Parent then
		if flightRestFov then followCamera.FieldOfView = flightRestFov end
		if followCamera.CameraType == Enum.CameraType.Scriptable then followCamera.CameraType = Enum.CameraType.Custom end
	end
	flightRestFov = nil
	followCamera = nil
end

--[[
	A new charge cancels old recovery/rumble/pan work before capturing the true
	resting FOV and optional humanoid offset. Old call sites may omit humanoid.
]]
function ThrowFx.beginChargeTension(humanoid: Humanoid?)
	cancelFollow()
	cancelCameraMotion(true)
	local camera = workspace.CurrentCamera
	if camera then
		tensionCamera = camera
		restFov = camera.FieldOfView
	end
	captureOffset(humanoid)
end

--[[
	Called every heartbeat while charging. `fraction` and `inZone` drive the
	anticipation pull-in/pulse; `strain` (0-1, from ThrowConfig.strainFraction)
	drives the humanoid's CameraOffset shake around its captured base. The
	needle stays exact; this restrained camera motion only conveys arm strain.
]]
function ThrowFx.updateChargeTension(humanoid: Humanoid?, fraction: number, inZone: boolean, strain: number)
	local camera = workspace.CurrentCamera
	if camera and camera ~= tensionCamera then
		cancelCameraMotion(true)
		tensionCamera = camera
		restFov = camera.FieldOfView
	end
	captureOffset(humanoid)
	if camera and restFov then
		local pullIn = TENSION_MAX_FOV_PULLIN * math.clamp(fraction, 0, 1) * motionScale()
		local pulse = 0
		if inZone then
			pulse = math.sin(os.clock() * TENSION_ZONE_PULSE_SPEED) * TENSION_ZONE_PULSE_AMPLITUDE * motionScale()
		end
		camera.FieldOfView = restFov - pullIn + pulse
	end

	if humanoid and humanoid.Parent and restOffset then
		local shake = math.clamp(strain, 0, 1) * STRAIN_MAX_SHAKE * motionScale() * (localPlayer:GetAttribute('ThrowShakeEnabled') == false and 0 or math.clamp(localPlayer:GetAttribute('ThrowShakeScale') or .75, 0, 1))
		local now = os.clock() * FX.Camera.StrainFrequency
		humanoid.CameraOffset = restOffset + Vector3.new(0.55 * fraction * motionScale(), 0.10 * fraction * motionScale(), -0.3 * fraction * motionScale()) + Vector3.new(
			math.noise(now, 0) * shake,
			math.noise(0, now) * shake,
			0
		)
	end
end

--[[
	Release eases out of tension. Pass immediate=true on cancellation/respawn
	to restore exact captured values synchronously. Recovery is invalidated by
	any newer charge, rumble or camera restoration.
]]
function ThrowFx.endChargeTension(humanoid: Humanoid?, immediate: boolean?)
	cancelCameraMotion(false)
	if immediate then
		cancelCameraMotion(true)
		return
	end
	local duration = FX.Camera.ReleaseRecoveryTime
	if tensionCamera and tensionCamera.Parent and restFov then
		cameraTween = TweenService:Create(tensionCamera, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			FieldOfView = restFov,
		})
		cameraTween:Play()
	end
	if offsetHumanoid and offsetHumanoid.Parent and restOffset then
		offsetTween = TweenService:Create(offsetHumanoid, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CameraOffset = restOffset,
		})
		offsetTween:Play()
	end
	finishCameraMotionAfter(duration)
end

function ThrowFx.rumble(humanoid: Humanoid, quality: string?, isSonicBoom: boolean?)
	cancelCameraMotion(true)
	local camera = workspace.CurrentCamera
	local profile = qualityProfile(quality)
	local kick = if isSonicBoom then FX.Camera.SonicFovKick else profile.FovKick
	local magnitude = if isSonicBoom then FX.Camera.SonicRumbleMagnitude else profile.RumbleMagnitude
	kick *= motionScale()
	magnitude *= motionScale() * (localPlayer:GetAttribute('ThrowShakeEnabled') == false and 0 or math.clamp(localPlayer:GetAttribute('ThrowShakeScale') or .75, 0, 1))
	captureOffset(humanoid)
	if camera then
		tensionCamera = camera
		local baseFov = camera.FieldOfView
		restFov = baseFov
		camera.FieldOfView = baseFov + kick
		cameraTween = TweenService:Create(
			camera,
			TweenInfo.new(FOV_KICK_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{FieldOfView = baseFov}
		)
		cameraTween:Play()
	end

	local baseOffset = restOffset or humanoid.CameraOffset
	local startedAt = os.clock()
	rumbleConnection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startedAt
		if elapsed >= RUMBLE_DURATION or not humanoid.Parent then
			if rumbleConnection then
				rumbleConnection:Disconnect()
				rumbleConnection = nil
			end
			if humanoid.Parent then
				humanoid.CameraOffset = baseOffset
			end
			return
		end
		local strength = magnitude * (1 - elapsed / RUMBLE_DURATION)
		humanoid.CameraOffset = baseOffset + Vector3.new(
			(math.random() - 0.5) * 2 * strength,
			(math.random() - 0.5) * 2 * strength,
			0
		)
	end)
	finishCameraMotionAfter(math.max(FOV_KICK_TIME, RUMBLE_DURATION))
end

--[[
	Lingers on the player, then pans smoothly onto the flying rock and hands
	off to normal CameraSubject following. `isStillMine` lets the caller abort
	the pan if the throw ended or another throw started mid-transition.
]]
-- A critically damped spring preserves lateral framing through every skip.
local function spring(position: Vector3, velocity: Vector3, target: Vector3, frequency: number, dt: number): (Vector3, Vector3)
	local offset = position - target
	local impulse = velocity + offset * frequency
	local decay = math.exp(-frequency * dt)
	return target + (offset + impulse * dt) * decay, (velocity - impulse * frequency * dt) * decay
end

function ThrowFx.followPebble(mainPart: BasePart, isStillMine: () -> boolean, localSteer: (() -> number)?)
 cancelFollow()
 cancelCameraMotion(true)
 local camera = workspace.CurrentCamera
 if not camera then return end
 local character = localPlayer.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 returnView = camera.CFrame
 returnRootPosition = if root and root:IsA("BasePart") then root.Position else nil
 followCamera = camera
 flightRestFov = camera.FieldOfView
 local baseFov = camera.FieldOfView
 local generation = followGeneration
 local startCFrame = camera.CFrame
 local startedAt = os.clock()
 local initialVelocity = mainPart.AssemblyLinearVelocity
 local flat = Vector3.new(initialVelocity.X, 0, initialVelocity.Z)
 local laneHeading = if flat.Magnitude > 1 then flat.Unit else Vector3.new(1,0,0)
 local cameraPosition = mainPart.Position - laneHeading * flightZoomDistance
  + Vector3.new(0, 4.2 + flightZoomDistance * 0.12, 0)
 local cameraVelocity = Vector3.zero
 local focus = mainPart.Position + laneHeading * 4 + Vector3.new(0, -1, 0)
 local focusVelocity = Vector3.zero
 local lastFollowPosition = mainPart.Position
 local model = mainPart.Parent
 local lastCameraKick = 0
 local lookYaw = 0
 local lookPitch = 0
 local lookStick = Vector2.zero
 local steeringLead = 0
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances = {model, character}
 params.RespectCanCollide = true
 params.CollisionGroup = ThrowConfig.PebbleCollisionGroup
 camera.CameraSubject = mainPart
 if motionScale() > 0 then camera.CameraType = Enum.CameraType.Scriptable end
 followBeginConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
  if input.UserInputType == Enum.UserInputType.MouseButton2 then
   followLookHeld = true
   followPriorMouseBehavior = UserInputService.MouseBehavior
   UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
  elseif not gameProcessed and (input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.ButtonR3) then
   lookYaw, lookPitch = 0, 0
  end
 end)
 followEndConnection = UserInputService.InputEnded:Connect(function(input)
  if input.UserInputType == Enum.UserInputType.MouseButton2 and followLookHeld then
   followLookHeld = false
   if followPriorMouseBehavior then UserInputService.MouseBehavior = followPriorMouseBehavior end
   followPriorMouseBehavior = nil
  elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
   lookStick = Vector2.zero
  end
 end)
 followInputConnection = UserInputService.InputChanged:Connect(function(input)
  if input.UserInputType == Enum.UserInputType.MouseWheel then
   flightZoomDistance = math.clamp(flightZoomDistance - input.Position.Z * 2.5, 5.5, 26)
  elseif input.UserInputType == Enum.UserInputType.MouseMovement and followLookHeld then
   lookYaw -= input.Delta.X * 0.0045
   lookPitch = math.clamp(lookPitch + input.Delta.Y * 0.004, math.rad(-55), math.rad(65))
  elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
   local stick = Vector2.new(input.Position.X, input.Position.Y)
   lookStick = if stick.Magnitude > 0.14 then stick else Vector2.zero
  end
 end)
 followConnection = RunService.RenderStepped:Connect(function(dt)
  if generation ~= followGeneration or camera ~= workspace.CurrentCamera or not mainPart.Parent or not isStillMine() then
   cancelFollow(); return
  end
  local scale = motionScale()
  if scale == 0 then
   camera.CameraType = Enum.CameraType.Custom; camera.CameraSubject = mainPart; camera.FieldOfView = baseFov
   return
  end
  camera.CameraType = Enum.CameraType.Scriptable
  dt = math.min(dt, 0.08)
  if lookStick.Magnitude > 0 then
   lookYaw -= lookStick.X * 2.1 * dt
   lookPitch = math.clamp(lookPitch - lookStick.Y * 1.55 * dt, math.rad(-55), math.rad(65))
  end
  local velocity = mainPart.AssemblyLinearVelocity
  local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
  local boostUntil = if model then model:GetAttribute("BoostUntil") else nil
  if model and model:GetAttribute("BoostKind") == "Monkey" and typeof(boostUntil) == "number"
   and boostUntil > lastCameraKick and horizontal.Magnitude > 1 then
   lastCameraKick = boostUntil
   laneHeading = horizontal.Unit
  end
  -- Chase the rock's actual travel direction so a hard left or right bank
  -- never leaves the camera stranded on the original lane.
  if horizontal.Magnitude > 8 then
   laneHeading = laneHeading:Lerp(horizontal.Unit, 1 - math.exp(-7 * dt)).Unit
  end
  local speedRatio = math.clamp(horizontal.Magnitude / 230, 0, 1)
  local waterY = WaterSurface.at(mainPart.Position)
  local height = if waterY then math.max(0, mainPart.Position.Y - waterY) else 0
  local skyPull = math.clamp(height / 85, 0, 1)
  local impactTime = 0
  if waterY then
   local g = math.max(workspace.Gravity, 1)
   impactTime = (velocity.Y + math.sqrt(velocity.Y * velocity.Y + 2 * g * height)) / g
  end
  local steerNow = if localSteer then localSteer() else 0
  steeringLead = ThrowConfig.smoothSteering(steeringLead, steerNow, dt)
  local laneRight = laneHeading:Cross(Vector3.yAxis)
  local aimLead = steeringLead * 3.2 * speedRatio * math.clamp(1 - math.abs(lookYaw) / 0.8, 0, 1)
  local followDistance = flightZoomDistance + speedRatio * 1.5 + skyPull * 1.5
  local orbitHeading = CFrame.fromAxisAngle(Vector3.yAxis, lookYaw):VectorToWorldSpace(laneHeading)
  local desired = mainPart.Position - orbitHeading * (followDistance * math.cos(lookPitch))
   + Vector3.new(0, 4.2 + flightZoomDistance * 0.12 + skyPull * 1.8 + math.sin(lookPitch) * followDistance, 0)
   + laneRight * aimLead * 0.25
  local landingLead = math.clamp(horizontal.Magnitude * impactTime * 0.08, 0, 10)
  local lookAhead = (4 + speedRatio * 2 + landingLead) * math.clamp(1 - math.abs(lookYaw) / 1.25, 0, 1)
  local desiredFocus = mainPart.Position + laneHeading * lookAhead + laneRight * aimLead
   + Vector3.new(0, 1.55 - skyPull * 0.2, 0)
  -- Match forward travel immediately; let the vertical springs absorb
  -- each bounce instead of punching the entire camera upward on contact.
  local displacement = mainPart.Position - lastFollowPosition
  lastFollowPosition = mainPart.Position
  local carry = if displacement.Magnitude > 45 then displacement
   else Vector3.new(displacement.X, 0, displacement.Z)
  cameraPosition += carry
  focus += carry
  cameraPosition, cameraVelocity = spring(cameraPosition, cameraVelocity, desired, 11, dt)
  focus, focusVelocity = spring(focus, focusVelocity, desiredFocus, 12, dt)
  impactPulse *= math.exp(-17 * dt)
  milestoneFov *= math.exp(-5 * dt)
  nearMissWhip *= math.exp(-10 * dt)
  local safePosition = cameraPosition + Vector3.new(0, impactPulse * scale * 0.4, 0)
  local hit = workspace:Raycast(mainPart.Position, safePosition - mainPart.Position, params)
  if hit then safePosition = hit.Position + hit.Normal * 0.7 end
  local target = CFrame.lookAt(safePosition, focus) * CFrame.Angles(0, 0, nearMissWhip * 0.25 * scale)
  local elapsed = os.clock() - startedAt
  local blend = math.clamp(elapsed / 0.22, 0, 1)
  blend = 1 - (1 - blend) ^ 3
  camera.CFrame = startCFrame:Lerp(target, blend)
  camera.Focus = CFrame.new(focus)
  local desiredFov = baseFov + (speedRatio * 2 + milestoneFov * 0.4) * scale
  camera.FieldOfView += (desiredFov - camera.FieldOfView) * (1 - math.exp(-5 * dt))
 end)
end

-- Only the ending is cinematic; the existing flight follow remains unchanged.
function ThrowFx.finishThrowCamera(humanoid: Humanoid?, surface: Vector3, onComplete: (() -> ())?)
	if motionScale() == 0 then
		ThrowFx.restoreCamera(humanoid)
		if onComplete then onComplete() end
		return
	end
	local camera = workspace.CurrentCamera
	local initial = if camera then camera.CFrame else CFrame.identity
	cancelFollow()
	cancelCameraMotion(true)
	local root = if humanoid then humanoid.RootPart else nil
	if not camera or not humanoid or not root or humanoid.Health <= 0 then
		ThrowFx.restoreCamera(humanoid)
		if onComplete then onComplete() end
		return
	end
	endingComplete = onComplete
	local savedView = returnView or initial
	local savedRoot = returnRootPosition or root.Position
	local settings = FX.Camera
	local generation = followGeneration
	followCamera = camera
	camera.CameraType = Enum.CameraType.Scriptable
	local backward = Vector3.new(initial.Position.X - surface.X, 0, initial.Position.Z - surface.Z)
	if backward.Magnitude < 0.01 then backward = Vector3.new(0, 0, 1) end
	local viewPosition = initial.Position
	if (initial.Position - surface).Magnitude > settings.SinkMaxViewDistance
		or initial.Position.Y < surface.Y + settings.SinkViewHeight then
		viewPosition = surface + backward.Unit * settings.SinkViewDistance + Vector3.new(0, settings.SinkViewHeight, 0)
	end
	local holdView = CFrame.lookAt(viewPosition, surface)
	local holdTime = math.max(settings.SinkHoldTime, ThrowConfig.SinkAnimation.Duration)
	local duration = math.clamp((holdView.Position - root.Position).Magnitude / settings.ReturnStudsPerSecond,
		settings.ReturnMinTime, settings.ReturnMaxTime)
	local started = os.clock()
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {humanoid.Parent}
	rayParams.RespectCanCollide = true
	followConnection = RunService.RenderStepped:Connect(function()
		if generation ~= followGeneration then return end
		if camera ~= workspace.CurrentCamera or not root.Parent or humanoid.Health <= 0 then
			ThrowFx.restoreCamera(humanoid)
			if onComplete then onComplete() end
			return
		end
		if motionScale() == 0 then
			ThrowFx.restoreCamera(humanoid)
			if onComplete then onComplete() end
			return
		end
		local elapsed = os.clock() - started
		if elapsed < holdTime then
			local blend = math.clamp(elapsed / settings.SinkFrameBlendTime, 0, 1)
			camera.CFrame = initial:Lerp(holdView, blend * blend * (3 - 2 * blend))
			return
		end
		local alpha = math.clamp((elapsed - holdTime) / duration, 0, 1)
		-- GTA-style return: starts almost at rest, then gathers speed toward
		-- the saved player view after the full sink linger.
		local eased = alpha ^ settings.ReturnAccelerationPower
		local destination = savedView + (root.Position - savedRoot)
		local viewOffset = destination.Position - root.Position
		local obstruction = workspace:Raycast(root.Position, viewOffset, rayParams)
		if obstruction then
			destination = CFrame.new(obstruction.Position + obstruction.Normal * settings.ReturnWallPadding) * destination.Rotation
		end
		local arc = math.sin(math.pi * eased) * math.min(settings.ReturnArcMax,
			(destination.Position - holdView.Position).Magnitude * settings.ReturnArcFraction)
		camera.CFrame = holdView:Lerp(destination, eased) + Vector3.new(0, arc, 0)
		if alpha >= 1 then
			ThrowFx.restoreCamera(humanoid)
			if onComplete then onComplete() end
		end
	end)
end

function ThrowFx.restoreCamera(humanoid: Humanoid?)
	endingComplete = nil
	cancelFollow()
	cancelCameraMotion(true)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		camera.CameraSubject = humanoid
		if humanoid.RootPart then camera.Focus=CFrame.new(humanoid.RootPart.Position) end
	end
end

-- Short wrist ribbon follows the actual authored pose, with no physics effects.
function ThrowFx.beginHandSweep(character: Model?): () -> ()
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	if not hand or not hand:IsA("BasePart") then return function() end end
	local settings = ThrowConfig.Presentation.Input
	local a = Instance.new("Attachment")
	a.Name = "ThrowSweepA"; a.Position = Vector3.new(-settings.HandTrailWidth / 2, -0.25, 0); a.Parent = hand
	local b = Instance.new("Attachment")
	b.Name = "ThrowSweepB"; b.Position = Vector3.new(settings.HandTrailWidth / 2, -0.25, 0); b.Parent = hand
	local ribbon = Instance.new("Trail")
	ribbon.Name = "ThrowHandSweep"; ribbon.Attachment0 = a; ribbon.Attachment1 = b
	ribbon.Lifetime = settings.HandTrailLifetime; ribbon.FaceCamera = true
	ribbon.Color = ColorSequence.new(settings.HandTrailColor)
	ribbon.Transparency = NumberSequence.new(0.5, 1)
	ribbon.LightEmission = 0.65; ribbon.Parent = hand
	local cleaned = false
	return function()
		if cleaned then return end
		cleaned = true
		-- Keep the trail for the quick follow-through, then drain its tail.
		task.delay(settings.FollowThroughDuration, function()
			ribbon.Enabled = false
			task.delay(settings.HandTrailLifetime, function() ribbon:Destroy(); a:Destroy(); b:Destroy() end)
		end)
	end
end

-- Client prediction never owns physics, scoring, or a networked instance.
local prediction: any = nil
local ARC_SEGMENTS = 20
local laneAnchor: BasePart? = nil
local laneContact: BasePart? = nil
local laneHint: BillboardGui? = nil
local laneLabel: TextLabel? = nil
local lanePoints: {Attachment} = {}
local laneSegments: {{outline: Beam, halo: Beam, core: Beam}} = {}
local lastLaneCheck = 0

function ThrowFx.clearAimLane()
	if laneAnchor then laneAnchor:Destroy() end
	if laneContact then laneContact:Destroy() end
	laneAnchor, laneContact, laneHint, laneLabel = nil, nil, nil, nil
	lanePoints, laneSegments = {}, {}
	lastLaneCheck = 0
end

function ThrowFx.updateAimLane(origin: Vector3, direction: Vector3, speed: number, character: Model?)
	if os.clock() - lastLaneCheck < 0.085 then return end
	lastLaneCheck = os.clock()
	local lane = ThrowConfig.launchLane(origin, direction, speed, character)
	if laneAnchor and not laneAnchor.Parent then ThrowFx.clearAimLane() end
	if not laneAnchor then
		laneAnchor = makeAnchor(origin, 40)
		laneAnchor.Name = "ThrowTrajectoryPreview"
		laneContact = makeAnchor(origin, 40)
		laneContact.Name = "FirstContactPreview"
		for i = 0, ARC_SEGMENTS do
			local point = Instance.new("Attachment")
			point.Name = "ArcPoint" .. i
			point.Parent = laneAnchor
			lanePoints[i + 1] = point
		end
		for i = 1, ARC_SEGMENTS do
			local fade = (i - 1) / ARC_SEGMENTS
			local nextFade = i / ARC_SEGMENTS
			local outline = Instance.new("Beam")
			outline.Name = "ArcDarkEdge"
			outline.Attachment0 = lanePoints[i]
			outline.Attachment1 = lanePoints[i + 1]
			outline.Width0 = 0.86 - 0.16 * fade
			outline.Width1 = 0.86 - 0.16 * nextFade
			outline.Transparency = NumberSequence.new(0.06 + 0.08 * fade)
			outline.Color = ColorSequence.new(Color3.fromRGB(11, 31, 58))
			outline.FaceCamera = true
			outline.ZOffset = 0.02
			outline.LightEmission = 0
			outline.Parent = laneAnchor
			local halo = Instance.new("Beam")
			halo.Name = "ArcSoftGlow"
			halo.Attachment0 = lanePoints[i]
			halo.Attachment1 = lanePoints[i + 1]
			halo.Width0 = 1.55 - 0.35 * fade
			halo.Width1 = 1.55 - 0.35 * nextFade
			halo.Transparency = NumberSequence.new(0.77 + 0.08 * fade)
			halo.FaceCamera = true
			halo.ZOffset = 0
			halo.LightEmission = 1
			halo.Parent = laneAnchor
			local core = Instance.new("Beam")
			core.Name = "ArcBrightCore"
			core.Attachment0 = lanePoints[i]
			core.Attachment1 = lanePoints[i + 1]
			core.Width0 = 0.42 - 0.08 * fade
			core.Width1 = 0.42 - 0.08 * nextFade
			core.Transparency = NumberSequence.new(0.03 + 0.10 * fade)
			core.FaceCamera = true
			core.ZOffset = 0.04
			core.LightEmission = 0.25
			core.LightInfluence = 0
			core.Parent = laneAnchor
			laneSegments[i] = {outline = outline, halo = halo, core = core}
		end
		laneHint = Instance.new("BillboardGui")
		laneHint.Name = "LaunchLaneHint"
		laneHint.Size = UDim2.fromOffset(230, 28)
		laneHint.StudsOffsetWorldSpace = Vector3.new(0, 1.5, 0)
		laneHint.AlwaysOnTop = false
		laneHint.MaxDistance = 100
		laneHint.Parent = laneContact
		laneLabel = Instance.new("TextLabel")
		laneLabel.Size = UDim2.fromScale(1, 1)
		laneLabel.BackgroundTransparency = 1
		laneLabel.Font = Enum.Font.GothamMedium
		laneLabel.TextSize = 12
		laneLabel.TextStrokeTransparency = 0.45
		laneLabel.Parent = laneHint
	end
	local endTime = math.max(0.08, lane.time or 0.65)
	local endpoint = lane.obstacle or lane.contact or (origin + ThrowConfig.releaseOffset(direction, speed, endTime, workspace.Gravity))
	local color = if lane.clear then Color3.fromRGB(255, 190, 0) else Color3.fromRGB(255, 102, 65)
	local glowColor = if lane.clear then Color3.fromRGB(255, 230, 91) else Color3.fromRGB(255, 163, 109)
	laneAnchor.Position = origin
	laneContact.Position = endpoint + Vector3.new(0, 0.08, 0)
	for i = 0, ARC_SEGMENTS do
		local t = endTime * i / ARC_SEGMENTS
		local point = if i == ARC_SEGMENTS then endpoint else origin + ThrowConfig.releaseOffset(direction, speed, t, workspace.Gravity)
		lanePoints[i + 1].Position = point - origin
	end
	for _, segment in laneSegments do
		segment.halo.Color = ColorSequence.new(glowColor)
		segment.core.Color = ColorSequence.new(color)
	end
	laneHint.Enabled = not lane.clear
	laneLabel.TextColor3 = color
	laneLabel.Text = lane.reason or "Move closer to open water"
end

function ThrowFx.cancelPrediction(requestId: number?)
	local state = prediction
	if not state or (requestId and state.requestId~=requestId) then return end
	prediction=nil
	if state.connection then state.connection:Disconnect() end
	if state.hidden then
		for part, value in state.hidden do if part.Parent then part.LocalTransparencyModifier=value end end
	end
	if state.model then state.model:Destroy() end
end

function ThrowFx.predictRelease(requestId: number, origin: Vector3, direction: Vector3, fraction: number, rockId: string?, predictedSpeed: number?)
	ThrowFx.cancelPrediction()
	ThrowFx.clearAimLane()
	local rock=RockCatalog.get(rockId)
	local templates=ReplicatedStorage:FindFirstChild("RockModels")
	local template=(templates and templates:FindFirstChild(rock.id)) or ReplicatedStorage:FindFirstChild("Pebble")
	if not template or not template:IsA("Model") then return end
	local stateProfile=require(script.Parent:WaitForChild("ProfileStore")).get()
 local copy=(stateProfile.traitedRocks or {})[stateProfile.rockEquippedInstance]
 local model=RockAppearance.apply(template:Clone(),rock.id,copy and copy.variant or "Normal")
 AbilityVisuals.attach(model,stateProfile.abilityEquipped)
	model.Name="PredictedPebble"
	model:ScaleTo(ThrowConfig.RockVisualScale)
	for _,tag in game:GetService("CollectionService"):GetTags(model) do game:GetService("CollectionService"):RemoveTag(model,tag) end
	for _,v in model:GetDescendants() do
		if v:IsA("LuaSourceContainer") or v:IsA("Constraint") or v:IsA("BodyMover") or v:IsA("Sound") then v:Destroy()
		elseif v:IsA("BasePart") then
			v.Anchored=true; v.CanCollide=false; v.CanTouch=false; v.CanQuery=false
			if not model:GetAttribute("CustomRockAppearance") then v.Color=rock.color; v.Material=rock.material end
		end
	end
	local modifiers = if typeof(stateProfile.modifiers) == "table" then stateProfile.modifiers else {}
	local physics = ThrowConfig.physicsFor(modifiers.effectiveStrength, modifiers.rockStats)
	local validPrediction = typeof(predictedSpeed) == "number" and predictedSpeed == predictedSpeed and math.abs(predictedSpeed) < math.huge
	local speed = if validPrediction then predictedSpeed else ThrowConfig.launchSpeed(fraction, false, physics)
		* AbilityCatalog.speedMultiplier(stateProfile.abilityEquipped)
	model:PivotTo(CFrame.lookAt(origin,origin+direction)); model.Parent=workspace
	local state={requestId=requestId,model=model,started=os.clock(),hidden={},target=nil,reconcileAt=nil}
	prediction=state
	ThrowFx.playReleaseBurst(origin,direction,"normal",false)
	state.connection=RunService.RenderStepped:Connect(function()
		if prediction~=state then return end
		local age=os.clock()-state.started
		if age>1.2 or not model.Parent then ThrowFx.cancelPrediction(requestId); return end
		if state.target then
			if not state.target.Parent then ThrowFx.cancelPrediction(requestId); return end
			local alpha=math.clamp((os.clock()-state.reconcileAt)/0.12,0,1)
			model:PivotTo(state.reconcileFrom:Lerp(state.target.CFrame,1-(1-alpha)^3))
			if alpha>=1 then ThrowFx.cancelPrediction(requestId) end
		else
			-- Integrate the server's initial ramp for a bounded latency preview.
			local t=age -- never freeze the preview while awaiting replication
			local pos=origin+ThrowConfig.releaseOffset(direction,speed,t,workspace.Gravity)
			model:PivotTo(CFrame.lookAt(pos,pos+direction)*CFrame.Angles(0,t*physics.launchSpin,0))
		end
	end)
end

function ThrowFx.reconcilePrediction(mainPart: BasePart, requestId: number?): boolean
	local state=prediction
	if not state or state.requestId~=requestId then return false end
	state.target=mainPart; state.reconcileAt=os.clock(); state.reconcileFrom=state.model:GetPivot()
	for _,part in mainPart.Parent:GetDescendants() do
		if part:IsA("BasePart") then state.hidden[part]=part.LocalTransparencyModifier; part.LocalTransparencyModifier=1 end
	end
	return true
end

localPlayer.CharacterRemoving:Connect(function()
	ThrowFx.cancelPrediction()
	ThrowFx.clearAimLane()
	Spectacle.shutdown()
end)

return ThrowFx




