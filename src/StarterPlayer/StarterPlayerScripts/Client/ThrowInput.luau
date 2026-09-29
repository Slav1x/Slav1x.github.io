--!strict
--[[
	ThrowInput (client)

	Owns charging, releasing and steering, and exposes them as plain calls so
	keyboard and touch can drive the same code path. Previously this lived
	inline in the client entry point bound directly to key events, which meant
	there was no way to add a touch control without duplicating it -- and the
	game was unplayable on phones, which is most of Roblox.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ThrowConfig = require(Shared:WaitForChild("ThrowConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RockCatalog = require(Shared:WaitForChild("RockCatalog"))
local AbilityCatalog = require(Shared:WaitForChild("AbilityCatalog"))
local AbilityHud = require(script.Parent:WaitForChild("AbilityHud"))
local ProfileStore = require(script.Parent:WaitForChild("ProfileStore"))
local Notify = require(script.Parent:WaitForChild("Notify"))

local ThrowFx = require(script.Parent:WaitForChild("ThrowFx"))
local ThrowHud = require(script.Parent:WaitForChild("ThrowHud"))

local SidearmPose = require(script.Parent:WaitForChild("SidearmPose"))
local sidearmPose: any = nil
local idlePose: any = nil
local inspectPose: any = nil
local inspectGeneration = 0

local Replay = require(script.Parent:WaitForChild("ThrowReplay"))
local ThrowInput = {}

local player = Players.LocalPlayer

local PRESENTATION = ThrowConfig.Presentation.Input
local THROW_ANIMATION_ID = PRESENTATION.AnimationId
local THROW_ANIM_HOLD_FRACTION = PRESENTATION.HoldFraction

local throwAnimation = Instance.new("Animation")
throwAnimation.AnimationId = THROW_ANIMATION_ID

-- Character handles, refreshed on respawn.
local humanoid: Humanoid? = nil
local animator: Animator? = nil
local rootPart: BasePart? = nil

-- Charge state
local hud: ThrowHud.ThrowHud
local isCharging = false
local chargeStartedAt = 0
local serverChargeStartedAt: number? = nil
local requestId = 0
local pendingRequestId: number? = nil
local acceptedRequestId: number? = nil
local flightActive = false
local endingPresentation = false
local bufferedAt: number? = nil
local bufferedReleased = false
local analogSteer = 0
local lastSteerSent = 0
local lastSteerSentAt = 0
local lastFeedbackAt = -math.huge
local lastFeedback = ""
local laneRefreshAt = 0
local controlsLocked = false
local localClockCorrection = 0
local sweetMin = ThrowConfig.SweetZoneMin
local sweetMax = ThrowConfig.SweetZoneMax
local sweetZoneKnown = false

local chargeSound: Sound? = nil
local chargeConn: RBXScriptConnection? = nil
local throwTrack: AnimationTrack? = nil
local animHoldConn: RBXScriptConnection? = nil
local animMarkerConn: RBXScriptConnection? = nil
local releaseTrack: AnimationTrack? = nil
local deathConn: RBXScriptConnection? = nil
local holdPosition: number? = nil
local handSweepCleanup: (() -> ())? = nil

local function releaseSpeed(track: AnimationTrack, multiplier: number): number
	local remaining = math.max(0.01, track.Length - track.TimePosition)
	return if track.Length > 0 then remaining / PRESENTATION.FollowThroughDuration * multiplier / PRESENTATION.ReleaseSpeed else multiplier
end

local jetpackHeld = false
local lastJetpackSentAt = 0
function ThrowInput.setJetpackHeld(held: boolean)
	held = held and flightActive and not endingPresentation and not UserInputService:GetFocusedTextBox()
		and player:GetAttribute("EquippedAbility") == "jetpack_rock"
	if jetpackHeld == held then return end
	jetpackHeld = held
	lastJetpackSentAt = os.clock()
	Remotes.AbilityInput:FireServer(held)
end

local steerLeft = false
local steerRight = false

local function heldRockTool(): Tool?
	local character = player.Character
	if not character then return nil end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("IsRockTool") == true then
			return child
		end
	end
	return nil
end

local function feedback(message: string)
	local now = os.clock()
	if message == lastFeedback and now - lastFeedbackAt < PRESENTATION.FeedbackCooldown then return end
	lastFeedback, lastFeedbackAt = message, now
	Notify.toast(message, "info")
end

function ThrowInput.equipSelectedRock(): boolean
 if heldRockTool() then return true end
 if isCharging or flightActive or pendingRequestId or endingPresentation then return false end
 local character=player.Character
 local alive=character and character:FindFirstChildOfClass("Humanoid")
 local backpack=player:FindFirstChildOfClass("Backpack")
 if not alive or alive.Health<=0 or not backpack then return false end
 local selected=ProfileStore.get().rockEquipped
 local candidate: Tool?=nil
 for _,tool in backpack:GetChildren() do
  if tool:IsA("Tool") and tool:GetAttribute("IsRockTool")==true then
   candidate=candidate or tool
   if tool:GetAttribute("RockId")==selected then candidate=tool;break end
  end
 end
 if candidate then alive:EquipTool(candidate);return heldRockTool()~=nil end
 feedback("Choose a rock in your inventory first")
 return false
end

local function currentAim(): Vector3
	local fallback = if rootPart then rootPart.CFrame.LookVector else Vector3.new(0, 0, -1)
	local camera = workspace.CurrentCamera
	if not camera then return ThrowConfig.cameraAimDirection(fallback, fallback) end
	local input = UserInputService:GetLastInputType()
	local mouseAim = UserInputService.MouseEnabled and input ~= Enum.UserInputType.Touch
		and not string.find(input.Name, "Gamepad") and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter
	if mouseAim then
		local mouse = UserInputService:GetMouseLocation()
		local viewport = camera.ViewportSize
		local y = math.clamp(mouse.Y / math.max(viewport.Y, 1), 0, 1)
		local ray = camera:ViewportPointToRay(math.clamp(mouse.X, 0, viewport.X), math.clamp(mouse.Y, 0, viewport.Y))
		local flat = Vector3.new(ray.Direction.X, 0, ray.Direction.Z)
		if flat.Magnitude < .01 then flat = Vector3.new(fallback.X, 0, fallback.Z) end
		if flat.Magnitude < .01 then flat = Vector3.new(0, 0, -1) end
		local cursorPitch = if y <= .5 then ThrowConfig.AimMaxPitch * (1 - y * 2)
			else ThrowConfig.AimMinPitch * (y * 2 - 1)
		-- The default shore camera looks down about 15 degrees. Keep the cursor
		-- level at screen center, while camera tilt still adds real launch pitch.
		local cameraPitch = math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1))
		local pitch = math.clamp(cursorPitch + cameraPitch + math.rad(15), ThrowConfig.AimMinPitch, ThrowConfig.AimMaxPitch)
		return flat.Unit * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)
	end
	return ThrowConfig.cameraAimDirection(camera.CFrame.LookVector, fallback)
end

local function launchPreview(fraction: number): (Vector3?, Vector3, number, string?)
	local direction = currentAim()
	local root = rootPart
	if not root then return nil, direction, 0, nil end
	local character = player.Character
	local hand = if character then (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) else nil
	local tool = heldRockTool()
	local attribute = tool and tool:GetAttribute("RockId")
	local rock = RockCatalog.get(if typeof(attribute) == "string" then attribute else nil)
	local state = ProfileStore.get()
	local modifiers = if typeof(state.modifiers) == "table" then state.modifiers else {}
	local physics = ThrowConfig.physicsFor(modifiers.effectiveStrength, modifiers.rockStats)
	local grace = math.min(ThrowConfig.ReleaseGraceMaxFraction, 2 * ThrowConfig.ReleaseGraceSeconds / ThrowConfig.NeedlePeriod)
	local perfect = sweetZoneKnown and fraction >= sweetMin-grace and fraction <= sweetMax+grace
	local speed = ThrowConfig.launchSpeed(fraction, perfect, physics)
	speed *= AbilityCatalog.speedMultiplier(state.abilityEquipped)
	return ThrowConfig.launchOrigin(root, if hand and hand:IsA("BasePart") then hand else nil, direction), direction, speed, rock.id
end

-- Consume movement before the default PlayerModule handles it. Steering owns
-- these keys only while the stone is active; E and camera orbit remain usable.
local function setMovementLocked(locked: boolean)
	if controlsLocked == locked then return end
	controlsLocked = locked
	if locked then
		ContextActionService:BindActionAtPriority("StoneFlightMovement", function(_, state, input)
			local down = state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change
			if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
				ThrowInput.setSteerLeft(down)
			elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
				ThrowInput.setSteerRight(down)
			elseif input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
				ThrowInput.setJetpackHeld(down)
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 50,
			Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
			Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
			Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.Thumbstick1)
		if humanoid then humanoid:Move(Vector3.zero, false) end
	else
		ContextActionService:UnbindAction("StoneFlightMovement")
	end
end

local function resumeBufferedThrow()
	if not bufferedAt then return end
	task.defer(function()
		if not bufferedAt or endingPresentation or flightActive then return end
		local fresh = os.clock() - bufferedAt <= PRESENTATION.InputBufferSeconds
		local releaseImmediately = bufferedReleased
		bufferedAt, bufferedReleased = nil, false
		if fresh then
			ThrowInput.beginCharge()
			if releaseImmediately then ThrowInput.endCharge() end
		end
	end)
end

local function stopIdlePose()
	if idlePose then idlePose.cancel(); idlePose = nil end
end

local function stopInspect()
	inspectGeneration += 1
	if inspectPose then inspectPose.cancel(); inspectPose = nil end
end

local function refreshIdlePose()
	stopIdlePose()
	if inspectPose then return end
	local tool = heldRockTool()
	if tool and player.Character and humanoid and humanoid.Health > 0
		and not isCharging and not flightActive and not pendingRequestId
	then
		idlePose = SidearmPose.beginIdle(player.Character, tool)
	end
end

function ThrowInput.inspectRock()
 if (player:GetAttribute("NoobDialogueOpen")==true or player:GetAttribute("RebirthCutscene")==true or player:GetAttribute("RebirthCinematic")==true) then return end
	if isCharging or flightActive or pendingRequestId or endingPresentation or inspectPose then return end
	local tool = heldRockTool()
	local character = player.Character
	if not tool or not character or not humanoid or humanoid.Health <= 0 then return end
	stopIdlePose()
	inspectGeneration += 1
	local generation = inspectGeneration
	local pose = SidearmPose.beginInspect(character, tool, function()
		if generation ~= inspectGeneration then return end
		inspectPose = nil
		refreshIdlePose()
	end)
	if pose then inspectPose = pose else refreshIdlePose() end
end

function ThrowInput.isRockHeld(): boolean
	return heldRockTool() ~= nil
end

function ThrowInput.isCharging(): boolean
	return isCharging
end

function ThrowInput.isBusy(): boolean
	return isCharging or flightActive or pendingRequestId ~= nil or endingPresentation
end

function ThrowInput.humanoid(): Humanoid?
	return humanoid
end

-- ============================================================================
-- Charging
-- ============================================================================

local function chargeElapsed(): number
	return math.max(0, os.clock() - chargeStartedAt + localClockCorrection)
end

local function localNeedleFraction(): number
	return ThrowConfig.needleFraction(chargeElapsed())
end

function ThrowInput.autoThrow(): boolean
	if ThrowInput.isBusy() then return false end
	ThrowInput.beginCharge()
	if not isCharging then return false end
	task.spawn(function()
		local deadline = os.clock() + 3
		while isCharging and os.clock() < deadline do
			local fraction = localNeedleFraction()
			if sweetZoneKnown and fraction >= sweetMin and fraction <= sweetMax then
				ThrowInput.endCharge()
				return
			end
			RunService.Heartbeat:Wait()
		end
		if isCharging then ThrowInput.endCharge() end
	end)
	return true
end

local function stopChargeFeedback(immediate: boolean?)
	ThrowFx.clearAimLane()
	if handSweepCleanup then handSweepCleanup(); handSweepCleanup = nil end
	if chargeConn then
		chargeConn:Disconnect()
		chargeConn = nil
	end
	if chargeSound then
		chargeSound:Stop()
		chargeSound:Destroy()
		chargeSound = nil
	end
	if animHoldConn then
		animHoldConn:Disconnect()
		animHoldConn = nil
	end
	if animMarkerConn then
		animMarkerConn:Disconnect()
		animMarkerConn = nil
	end
	ThrowHud.hideCharge(hud)
	-- Restores FOV and camera-offset shake exactly, whether the charge ended
	-- in a release or was torn down early (respawn, character removal, ...).
	ThrowFx.endChargeTension(humanoid, immediate)
end

function ThrowInput.cancelCharge()
	ThrowInput.setJetpackHeld(false)
	ThrowFx.cancelPrediction(pendingRequestId or requestId)
	bufferedAt, bufferedReleased = nil, false
	steerLeft, steerRight, analogSteer = false, false, 0
	setMovementLocked(false)
	if sidearmPose then sidearmPose.cancel(); sidearmPose = nil end
	stopInspect()
	stopIdlePose()
	isCharging = false
	requestId += 1
	pendingRequestId = nil
	acceptedRequestId = nil
	stopChargeFeedback(true)
	for _, track in {throwTrack, releaseTrack} do
		track:Stop(PRESENTATION.CancelFadeTime)
		track:Destroy()
	end
	throwTrack, releaseTrack = nil, nil
	refreshIdlePose()
end

function ThrowInput.setFlightActive(active: boolean)
	flightActive = active
	if not active then ThrowInput.setJetpackHeld(false) end
	setMovementLocked(active)
	if active then
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) and not UserInputService:GetFocusedTextBox() then
			ThrowInput.setJetpackHeld(true)
		end
		stopInspect()
		stopIdlePose()
	else
		steerLeft, steerRight, analogSteer = false, false, 0
		lastSteerSent = 0
		Remotes.Steer:FireServer(0)
		refreshIdlePose()
		resumeBufferedThrow()
	end
end

function ThrowInput.setEndingPresentation(active: boolean)
	endingPresentation = active
	if active then ThrowInput.setJetpackHeld(false) end
	if not active then resumeBufferedThrow() end
end

function ThrowInput.isCurrentRequest(confirmedRequestId: number?): boolean
	return confirmedRequestId == nil or confirmedRequestId == requestId
end

-- Correlate the server's result with the release that produced this pose/HUD.
function ThrowInput.confirmRelease(quality: string, isSonicBoom: boolean?, fraction: number?, confirmedRequestId: number?): boolean
	if isCharging or not pendingRequestId or (confirmedRequestId and confirmedRequestId ~= pendingRequestId) then
		return false
	end
	pendingRequestId = nil
	acceptedRequestId = nil
	ThrowHud.confirmRelease(hud, fraction, quality)
	if releaseTrack and releaseTrack.IsPlaying then
		local speed = PRESENTATION.ReleaseSpeedByQuality[quality] or PRESENTATION.ReleaseSpeed
		releaseTrack:AdjustSpeed(releaseSpeed(releaseTrack, if isSonicBoom then PRESENTATION.SonicReleaseSpeed else speed))
	end
	return true
end

-- Noob's prompt shares E/ButtonX with throwing. Check the real prompt and held
-- key before PromptTriggered is delivered, so callback ordering cannot charge.
local function noobOwnsThrowInput(): boolean
 if (player:GetAttribute("NoobDialogueOpen")==true or player:GetAttribute("RebirthCutscene")==true or player:GetAttribute("RebirthCinematic")==true) then return true end
 local npc=workspace:FindFirstChild("MagicalRock")
 local anchor=npc and npc:FindFirstChild("InteractionAnchor")
 local prompt=anchor and anchor:FindFirstChild("RebirthPrompt")
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 if not anchor or not anchor:IsA("BasePart") or not prompt or not prompt:IsA("ProximityPrompt")
  or not prompt.Enabled or not root or not root:IsA("BasePart")
  or (root.Position-anchor.Position).Magnitude>prompt.MaxActivationDistance then return false end
 if UserInputService:IsKeyDown(prompt.KeyboardKeyCode) then return true end
 for _,gamepad in UserInputService:GetConnectedGamepads() do
  if UserInputService:IsGamepadButtonDown(gamepad,prompt.GamepadKeyCode) then return true end
 end
 return false
end

function ThrowInput.beginCharge()
 if noobOwnsThrowInput() then return end
	local character = player.Character
	if player:GetAttribute("TrainingAFK") == true then return end
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("IsTrainingTool") == true then return end
		end
	end
	Replay.stop()
	ThrowHud.dismissResult(hud)
	if endingPresentation then
		bufferedAt = os.clock()
		bufferedReleased = false
		if ThrowFx.dismissEnding() then
			endingPresentation = false
			ThrowInput.setFlightActive(false)
		end
		resumeBufferedThrow()
		return
	end
	if isCharging then return end
	if flightActive or pendingRequestId then feedback("Rock already in flight"); return end
	if not heldRockTool() then feedback("Equip a rock from your hotbar first"); return end
	local currentRoot = rootPart
	local currentAnimator = animator
	if not currentRoot or not currentAnimator or not humanoid or humanoid.Health <= 0 then
		return
	end

	stopInspect()
	stopIdlePose()
	isCharging = true
	chargeStartedAt = os.clock()
	serverChargeStartedAt = nil
	localClockCorrection = 0
	laneRefreshAt = 0
	requestId += 1
	acceptedRequestId = nil
	sweetZoneKnown = false

	Remotes.ChargeStart:FireServer(requestId)
	ThrowHud.showCharge(hud)
	ThrowFx.beginChargeTension(humanoid)

	local sound = Instance.new("Sound")
	sound.Name = "ChargeSound"
	sound.SoundGroup = game:GetService("SoundService"):FindFirstChild("SFX") :: SoundGroup?
	sound.SoundId = ThrowFx.ChargeSoundId
	sound.Looped = true
	sound.Volume = PRESENTATION.ChargeMinVolume
	sound.PlaybackSpeed = ThrowFx.ChargeSoundMinPitch
	sound.Parent = currentRoot
	sound:Play()
	chargeSound = sound

	if PRESENTATION.UseSidearmPose then
		if sidearmPose then sidearmPose.cancel() end
		sidearmPose = SidearmPose.begin(player.Character :: Model)
		handSweepCleanup = ThrowFx.beginHandSweep(player.Character)
	else
	-- Play the throw animation and freeze it at the hold mark until release.
	if releaseTrack then
		releaseTrack:Stop(PRESENTATION.CancelFadeTime)
		releaseTrack:Destroy()
		releaseTrack = nil
	end
	local track = currentAnimator:LoadAnimation(throwAnimation)
	track.Priority = Enum.AnimationPriority.Action4 -- outranks movement anims
	track.Looped = false
	track:Play(PRESENTATION.WindupFadeTime, 1, 0)
	handSweepCleanup = ThrowFx.beginHandSweep(player.Character)
	throwTrack = track
	holdPosition = nil
	-- Artists can add a Hold marker; existing assets retain the fraction fallback.
	animMarkerConn = track:GetMarkerReachedSignal(PRESENTATION.HoldMarker):Connect(function()
		if isCharging and throwTrack == track then
			holdPosition = track.TimePosition
			track:AdjustSpeed(0)
		end
	end)

	animHoldConn = RunService.Heartbeat:Connect(function()
		if not isCharging or throwTrack ~= track then
			if animHoldConn then
				animHoldConn:Disconnect()
				animHoldConn = nil
			end
			return
		end
		-- Normalize the authored wind-up to a short, smooth real-time duration.
		if track.Length > 0 then
			local target = holdPosition or track.Length * THROW_ANIM_HOLD_FRACTION
			local alpha = math.clamp((os.clock() - chargeStartedAt) / PRESENTATION.WindupDuration, 0, 1)
			local eased = alpha * alpha * (3 - 2 * alpha)
			track.TimePosition = target * eased
			if alpha >= 1 then
				holdPosition = target
				track:AdjustSpeed(0)
				if animHoldConn then animHoldConn:Disconnect(); animHoldConn = nil end
			end
		end
	end)

	end -- authored-animation fallback

	local wasInZone = false
	chargeConn = RunService.Heartbeat:Connect(function(dt)
		if serverChargeStartedAt then
			local wanted = workspace:GetServerTimeNow() - serverChargeStartedAt - (os.clock() - chargeStartedAt)
			localClockCorrection += (wanted - localClockCorrection) * (1 - math.exp(-16 * dt))
		end
		local elapsed = chargeElapsed()
		local fraction = localNeedleFraction()
		local inZone = sweetZoneKnown and fraction >= sweetMin and fraction <= sweetMax
		local strain = ThrowConfig.strainFraction(elapsed)
		if inZone and not wasInZone then ThrowFx.playZoneCue() end
		wasInZone = inZone

		ThrowHud.updateCharge(hud, fraction, inZone, strain)
		ThrowFx.updateChargeTension(humanoid, fraction, inZone, strain)
		if os.clock() - laneRefreshAt >= 1 / 20 then
			laneRefreshAt = os.clock()
			local origin, direction, speed = launchPreview(fraction)
			if origin then ThrowFx.updateAimLane(origin, direction, speed, player.Character) end
		end

		if chargeSound then
			local minPitch = ThrowFx.ChargeSoundMinPitch
			local maxPitch = ThrowFx.ChargeSoundMaxPitch
			local pitch = minPitch + (maxPitch - minPitch) * fraction
			if strain > 0 then
				-- A little instability in the pitch reads as fatigue -- the
				-- audio equivalent of the camera's arm-shake.
				pitch += math.sin(os.clock() * PRESENTATION.StrainPitchFrequency) * PRESENTATION.StrainPitchAmount * strain
			end
			chargeSound.PlaybackSpeed = pitch
			chargeSound.Volume = PRESENTATION.ChargeMinVolume + PRESENTATION.ChargeVolumeRange * fraction
		end
	end)
end

function ThrowInput.endCharge()
 if (player:GetAttribute("NoobDialogueOpen")==true or player:GetAttribute("RebirthCutscene")==true or player:GetAttribute("RebirthCinematic")==true) then
  bufferedAt,bufferedReleased=nil,false
  if isCharging then ThrowInput.cancelCharge() end
  return
 end
	if bufferedAt then bufferedReleased = true; return end
	if not isCharging then
		return
	end
	isCharging = false

	local releasedAt = workspace:GetServerTimeNow()
	local fraction = localNeedleFraction()
	local origin, aimDirection, speed, rockId = launchPreview(fraction)
	-- The server validates the corridor. Do not rescan the whole trajectory
	-- synchronously in the release input callback.
	stopChargeFeedback()
	ThrowHud.showRelease(hud, fraction)
	pendingRequestId = requestId
	local releasedRequestId = requestId
	task.delay(PRESENTATION.AcceptanceTimeout, function()
		if pendingRequestId == releasedRequestId and acceptedRequestId ~= releasedRequestId then
			pendingRequestId = nil
			ThrowFx.cancelPrediction(releasedRequestId)
			setMovementLocked(false)
			feedback("Throw didn't connect — try again")
			refreshIdlePose()
		end
	end)

	if sidearmPose then sidearmPose.release() end

	-- Let the held animation run out to the end.
	local track = throwTrack
	throwTrack = nil
	if track then
		-- A tap must reach follow-through now rather than finish winding up
		-- after the server has already launched its pebble.
		if track.Length > 0 then
			track.TimePosition = math.max(track.TimePosition, holdPosition or track.Length * THROW_ANIM_HOLD_FRACTION)
		end
		releaseTrack = track
		track.Stopped:Once(function()
			if releaseTrack == track then releaseTrack = nil end
			track:Destroy()
		end)
		track:AdjustSpeed(releaseSpeed(track, PRESENTATION.ReleaseSpeed))
	end

	Remotes.ChargeRelease:FireServer(fraction, aimDirection, releasedAt, requestId)

	-- Cosmetic only: server-owned replication will replace this immediately.
	if origin then ThrowFx.predictRelease(requestId, origin, aimDirection, fraction, rockId, speed) end
	setMovementLocked(true)
end

-- ============================================================================
-- Steering
-- ============================================================================

function ThrowInput.currentSteer(): number
	if not flightActive or endingPresentation then return 0 end
	local digital = (if steerRight then 1 else 0) - (if steerLeft then 1 else 0)
	if digital ~= 0 then
		return digital * (if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then PRESENTATION.TouchSteerStrength else 1)
	end
	return analogSteer
end

local function pushSteer(force: boolean?)
	if not flightActive or endingPresentation then return end
	local direction = ThrowInput.currentSteer()
	local now = os.clock()
	-- Digital press/release/reversal is immediate; analog updates are bounded.
	if not force and now - lastSteerSentAt < PRESENTATION.SteerSendInterval then return end
	if force or math.abs(direction - lastSteerSent) > 0.01 or now - lastSteerSentAt >= 0.2 then
		lastSteerSent, lastSteerSentAt = direction, now
		Remotes.Steer:FireServer(direction)
	end
end

function ThrowInput.setAnalogSteer(value: number)
	local previous = analogSteer
	local magnitude = math.abs(value)
	local deadZone = PRESENTATION.GamepadDeadZone
	analogSteer = if magnitude <= deadZone then 0 else math.sign(value) * ((math.clamp(magnitude, 0, 1) - deadZone) / (1 - deadZone)) ^ 1.05 * PRESENTATION.GamepadSteerStrength
	pushSteer((analogSteer == 0 and previous ~= 0) or analogSteer * previous < 0)
end

function ThrowInput.setSteerLeft(held: boolean)
	if steerLeft == held then
		return
	end
	steerLeft = held
	pushSteer(true)
end

function ThrowInput.setSteerRight(held: boolean)
	if steerRight == held then
		return
	end
	steerRight = held
	pushSteer(true)
end

-- ============================================================================
-- Wiring
-- ============================================================================

function ThrowInput.start(sharedHud: ThrowHud.ThrowHud)
	hud = sharedHud
 local function noobModalChanged()
  if (player:GetAttribute("NoobDialogueOpen")==true or player:GetAttribute("RebirthCutscene")==true or player:GetAttribute("RebirthCinematic")==true) then
   bufferedAt,bufferedReleased=nil,false
   -- Do not discard an already released server-authoritative flight.
   if isCharging then ThrowInput.cancelCharge() end
  end
 end
 player:GetAttributeChangedSignal("NoobDialogueOpen"):Connect(noobModalChanged)
 player:GetAttributeChangedSignal("RebirthCutscene"):Connect(noobModalChanged)
 player:GetAttributeChangedSignal("RebirthCinematic"):Connect(noobModalChanged)
 noobModalChanged()
	AbilityHud.start(sharedHud.gui, ThrowInput.setJetpackHeld)
	player:GetAttributeChangedSignal("EquippedAbility"):Connect(function() ThrowInput.setJetpackHeld(false) end)

	local function onCharacterAdded(character: Model)
		ThrowInput.cancelCharge()
		flightActive, endingPresentation = false, false
		humanoid = character:WaitForChild("Humanoid") :: Humanoid
		animator = (humanoid :: Humanoid):WaitForChild("Animator") :: Animator
		rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then task.defer(refreshIdlePose) end
		end)
		character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") and child:GetAttribute("IsRockTool") == true then
				stopInspect()
				if isCharging then ThrowInput.cancelCharge() end
				task.defer(refreshIdlePose)
			end
		end)
		task.defer(refreshIdlePose)

		if deathConn then deathConn:Disconnect() end
		deathConn = (humanoid :: Humanoid).Died:Connect(ThrowInput.cancelCharge)
		task.spawn(function()
			pcall(function() ContentProvider:PreloadAsync({throwAnimation}) end)
		end)
	end

	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
	player.CharacterRemoving:Connect(function()
		ThrowInput.cancelCharge()
		stopIdlePose()
		flightActive, endingPresentation = false, false
		humanoid, animator, rootPart = nil, nil, nil
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		ThrowInput.setJetpackHeld(false)
		steerLeft, steerRight, analogSteer = false, false, 0
		pushSteer(true)
		if isCharging then ThrowInput.cancelCharge() end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then ThrowInput.setAnalogSteer(input.Position.X) end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.R then ThrowInput.inspectRock()
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.ButtonX then ThrowInput.beginCharge() end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then ThrowInput.setJetpackHeld(false) end
		if input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.ButtonX then ThrowInput.endCharge() end
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then ThrowInput.setAnalogSteer(0) end
	end)
	local steerAccumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		if jetpackHeld and os.clock()-lastJetpackSentAt >= .2 then
			lastJetpackSentAt = os.clock()
			Remotes.AbilityInput:FireServer(true)
		end
		if controlsLocked and humanoid then humanoid:Move(Vector3.zero, false) end
		steerAccumulator += dt
		if steerAccumulator >= PRESENTATION.SteerSendInterval then
			steerAccumulator = 0
			pushSteer()
		end
	end)

	-- The server rolls the sweet zone and tells us where to draw it. We never
	-- decide whether a release was perfect; we only preview it.
	Remotes.ThrowAccepted.OnClientEvent:Connect(function(confirmedRequestId: number?, _throwId: number?)
		if confirmedRequestId ~= nil and confirmedRequestId == pendingRequestId then
			acceptedRequestId = confirmedRequestId
			-- Let steering work immediately while the persistent rock streams in.
			ThrowInput.setFlightActive(true)
		end
	end)
	Remotes.ChargeInfo.OnClientEvent:Connect(function(minBound: number?, maxBound: number?, startedAt: number?, confirmedRequestId: number?, reason: string?)
		if confirmedRequestId and confirmedRequestId ~= requestId then return end
		if reason then
			ThrowFx.cancelPrediction(pendingRequestId or requestId)
			if isCharging then ThrowInput.cancelCharge() end
			pendingRequestId = nil
			acceptedRequestId = nil
			setMovementLocked(flightActive)
			feedback(reason)
			refreshIdlePose()
			return
		end
		if not minBound or not maxBound then return end
		if not isCharging or (confirmedRequestId and confirmedRequestId ~= requestId) then
			return
		end
		sweetMin, sweetMax = minBound, maxBound
		sweetZoneKnown = true
		serverChargeStartedAt = startedAt
		ThrowHud.setSweetZone(hud, minBound, maxBound)
	end)
end

return ThrowInput




