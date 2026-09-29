--!strict
--[[
	Client entry point: throw input and presentation.

	This replaces StarterCharacterScripts.ThrowingScript. The important
	difference is that it no longer creates, owns or scores the pebble -- it
	sends input and reacts to what the server reports back.

	It lives in StarterPlayerScripts rather than StarterCharacterScripts so it
	survives respawns and the HUD does not get rebuilt on every death.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ThrowConfig = require(Shared:WaitForChild("ThrowConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ThrowFx = require(script:WaitForChild("ThrowFx"))
local ThrowHud = require(script:WaitForChild("ThrowHud"))
local ThrowInput = require(script:WaitForChild("ThrowInput"))
local EncounterFx = require(script:WaitForChild("EncounterFx"))
local TouchControls = require(script:WaitForChild("TouchControls"))
local MoneyFx = require(script:WaitForChild("MoneyFx"))
local Notify = require(script:WaitForChild("Notify"))
local ProfileStore = require(script:WaitForChild("ProfileStore"))
local PetFx = require(script:WaitForChild("PetFx"))

local player = Players.LocalPlayer
local hud = ThrowHud.create()

ThrowFx.preload()
MoneyFx.startHovering()

Notify.create()
PetFx.start()
UserInputService.MouseIconEnabled = true
player:GetMouse().Icon = ""

ThrowInput.start(hud)
TouchControls.start()
local Replay = require(script:WaitForChild("ThrowReplay"))
local replayButton = hud.resultHolder:FindFirstChild("StoneCamReplay", true) :: TextButton
replayButton.Activated:Connect(function()
	if ThrowInput.isCharging() then return end
	ThrowFx.dismissEnding()
	if Replay.play() then ThrowHud.dismissResult(hud) end
end)

-- ============================================================================
-- Keyboard and mouse
--
-- ThrowInput locks character movement while the pebble owns the controls.
-- Both arrow keys and A/D steer; analog and touch strength live in ThrowInput.
-- ============================================================================
local chargeSource: string? = nil
local function holdingTrainingTool(): boolean
	local character = player.Character
	if not character then return false end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("IsTrainingTool") == true then return true end
	end
	return false
end
UserInputService.WindowFocusReleased:Connect(function() chargeSource = nil end)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- A clicked Selectable button becomes GuiService.SelectedObject, after
	-- which arrow keys are consumed as UI selection navigation and arrive
	-- here with gameProcessed = true -- which used to kill steering mid-flight.
	-- Steering keys therefore only bail when the player is actually typing;
	-- selection navigation is harmless because HUD buttons are not Selectable.
	local typing = UserInputService:GetFocusedTextBox() ~= nil
	if input.KeyCode == Enum.KeyCode.E or input.UserInputType == Enum.UserInputType.MouseButton1 then
		if not gameProcessed and not typing and not chargeSource and not holdingTrainingTool() and player:GetAttribute("TrainingAFK") ~= true then
			chargeSource = if input.KeyCode == Enum.KeyCode.E then "keyboard" else "mouse"
			ThrowInput.beginCharge()
		end
	elseif input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.A then
		if not typing then
			ThrowInput.setSteerLeft(true)
		end
	elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.D then
		if not typing then
			ThrowInput.setSteerRight(true)
		end
	end
end)

-- InputEnded is deliberately NOT gated on gameProcessed: a release that gets
-- swallowed would leave the player stuck mid-charge.
UserInputService.InputEnded:Connect(function(input)
	if (input.KeyCode == Enum.KeyCode.E and chargeSource == "keyboard")
		or (input.UserInputType == Enum.UserInputType.MouseButton1 and chargeSource == "mouse") then
		chargeSource = nil
		ThrowInput.endCharge()
	elseif input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.A then
		ThrowInput.setSteerLeft(false)
	elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.D then
		ThrowInput.setSteerRight(false)
	end
end)

-- Keep the level bar in step with the profile.
ProfileStore.onChanged(function()
	local state = ProfileStore.get()
	ThrowHud.setLevel(hud, state.level or 1, state.xpInto or 0, state.xpNeed or 0)
end)

-- ============================================================================
-- Flight presentation
-- ============================================================================

local myPebble: Model? = nil
local endingPresentationToken = 0
local bestAtLaunch = 0
local lastTierByThrower: {[number]: number} = {}
local attachedPebbles: {[Instance]: boolean} = {}
local myThrowId: number? = nil
local lastEndedThrowId = 0
local myFlightCleanup: (() -> ())? = nil

local function onPebbleAdded(pebble: Instance)
	if not pebble:IsA("Model") or attachedPebbles[pebble] then
		return
	end

	-- A tagged model can reach the client before its parts or attributes.
	-- Wait briefly rather than discarding the only tag notification.
	local mainPart = pebble.PrimaryPart or pebble:FindFirstChildWhichIsA("BasePart", true)
	local readyBy = os.clock() + 8
	while pebble.Parent and os.clock() < readyBy and (not mainPart
		or typeof(pebble:GetAttribute("ThrowerUserId")) ~= "number"
		or typeof(pebble:GetAttribute("ThrowId")) ~= "number"
		or typeof(pebble:GetAttribute("ChargeRequestId")) ~= "number") do
		task.wait(0.05)
		mainPart = pebble.PrimaryPart or pebble:FindFirstChildWhichIsA("BasePart", true)
	end
	if not pebble.Parent or not mainPart
		or typeof(pebble:GetAttribute("ThrowerUserId")) ~= "number"
		or typeof(pebble:GetAttribute("ThrowId")) ~= "number"
		or typeof(pebble:GetAttribute("ChargeRequestId")) ~= "number" then
		return
	end
	if attachedPebbles[pebble] then return end
	attachedPebbles[pebble] = true

	local throwerUserId = pebble:GetAttribute("ThrowerUserId")
	local isSonicBoom = pebble:GetAttribute("IsSonicBoom") == true
	local isPerfect = pebble:GetAttribute("IsPerfect") == true
	local qualityAttribute = pebble:GetAttribute("Quality")
	local quality = if typeof(qualityAttribute) == "string" then qualityAttribute else if isPerfect then "perfect" else "normal"
	local throwIdAttribute = pebble:GetAttribute("ThrowId")
	local throwId = if typeof(throwIdAttribute) == "number" then throwIdAttribute else nil
	local launchSpeed = pebble:GetAttribute("LaunchSpeed")
	if typeof(launchSpeed) ~= "number" or launchSpeed <= 0 then
		launchSpeed = ThrowConfig.MaxThrowSpeed
	end

	local isMine = throwerUserId == player.UserId
	local requestAttribute = pebble:GetAttribute("ChargeRequestId")
	local chargeRequestId = if typeof(requestAttribute) == "number" then requestAttribute else nil
	local ownsPresentation = isMine and ThrowInput.isCurrentRequest(chargeRequestId)
	-- ThrowEnded can arrive before an instance finishes replicating.
	if isMine and throwId and throwId <= lastEndedThrowId then
		attachedPebbles[pebble] = nil
		return
	end

	-- Find the thrower's root so a sonic boom can linger on them first.
	local throwerRoot: BasePart? = nil
	if typeof(throwerUserId) == "number" then
		local thrower = Players:GetPlayerByUserId(throwerUserId)
		local throwerCharacter = thrower and thrower.Character
		if throwerCharacter then
			throwerRoot = throwerCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
		end
	end

	-- The barrier break fires once, at release, for everyone in earshot --
	-- including players watching someone else's throw.
	if isSonicBoom then
		local velocity = mainPart.AssemblyLinearVelocity
		local heading = if velocity.Magnitude > 1
			then velocity.Unit
			else mainPart.CFrame.LookVector
		ThrowFx.sonicBoomBreak(mainPart.Position, heading)
	end

	local rockId = pebble:GetAttribute("RockId")
	local cleanup = ThrowFx.attachFlight(
		pebble,
		mainPart,
		isSonicBoom,
		launchSpeed,
		throwerRoot,
		if typeof(rockId) == "string" then rockId else nil,
		quality,
		if ownsPresentation then ThrowInput.currentSteer else nil
	)
	local reconciledPrediction = if ownsPresentation then ThrowFx.reconcilePrediction(mainPart, chargeRequestId) else false
	do
		local velocity = mainPart.AssemblyLinearVelocity
		local launchDirection = if velocity.Magnitude > 1 then velocity.Unit else mainPart.CFrame.LookVector
		if not reconciledPrediction then
			ThrowFx.playReleaseBurst(mainPart.Position, launchDirection, quality, isSonicBoom)
		end
	end

	if ownsPresentation then
		if quality == "perfect" then ThrowFx.duckPerfect() end
		endingPresentationToken += 1
		myPebble = pebble
		EncounterFx.attach(pebble, ThrowInput.currentSteer)
		myThrowId = throwId
		myFlightCleanup = cleanup
		bestAtLaunch = ProfileStore.get().bestDistance or 0
		ThrowInput.setEndingPresentation(false)
		ThrowInput.setFlightActive(true)
		ThrowHud.clearFlight(hud)
		ThrowHud.setFlightMode(hud, true)
		ThrowHud.setCombo(hud, 0, 1)
		local releaseFraction = pebble:GetAttribute("ReleaseFraction")
		ThrowInput.confirmRelease(quality, isSonicBoom,
			if typeof(releaseFraction) == "number" then releaseFraction else nil,
			chargeRequestId)
		-- The release meter has served its purpose; leave space for the flight action on phones.
		ThrowHud.hideCharge(hud)
		ThrowHud.showQualityCallout(hud, quality)
		local hum = ThrowInput.humanoid()
		if hum then
			ThrowFx.rumble(hum, quality, isSonicBoom)
		end
		ThrowFx.followPebble(mainPart, function()
			return myPebble == pebble
		end, ThrowInput.currentSteer)

		-- Live distance readout. This is presentation only; the authoritative
		-- number arrives in ThrowEnded.
		local launchOrigin = pebble:GetAttribute("LaunchOrigin")
		local launchPos = if typeof(launchOrigin) == "Vector3" then launchOrigin else mainPart.Position
		local distanceConn: RBXScriptConnection
		distanceConn = RunService.Heartbeat:Connect(function()
			if myPebble ~= pebble or not mainPart.Parent then
				distanceConn:Disconnect()
				return
			end
			local delta = mainPart.Position - launchPos
			ThrowHud.setDistance(hud, Vector3.new(delta.X, 0, delta.Z).Magnitude)
		end)
	end

	-- Instance.Destroying does not fire on the client when the SERVER destroys
	-- the instance -- the client just sees it leave the tree -- so watch
	-- ancestry instead.
	local ancestryConn: RBXScriptConnection
	ancestryConn = pebble.AncestryChanged:Connect(function()
		if pebble:IsDescendantOf(workspace) then
			return
		end
		ancestryConn:Disconnect()
		attachedPebbles[pebble] = nil
		cleanup()
		if myPebble == pebble then
			myPebble = nil
			EncounterFx.finish()
			myThrowId = nil
			myFlightCleanup = nil
			ThrowInput.setEndingPresentation(false)
			ThrowInput.setFlightActive(false)
			ThrowHud.clearFlight(hud)
			ThrowHud.setFlightMode(hud, false)
			ThrowFx.restoreCamera(ThrowInput.humanoid())
		end
	end)
end

CollectionService:GetInstanceAddedSignal(ThrowConfig.PebbleTag):Connect(onPebbleAdded)
for _, pebble in CollectionService:GetTagged(ThrowConfig.PebbleTag) do
	task.spawn(onPebbleAdded, pebble)
end
Players.PlayerRemoving:Connect(function(leaving)
	lastTierByThrower[leaving.UserId] = nil
end)
player.CharacterRemoving:Connect(function()
	endingPresentationToken += 1
	myPebble, myThrowId = nil, nil
	EncounterFx.finish()
	if myFlightCleanup then myFlightCleanup(); myFlightCleanup = nil end
	ThrowInput.setEndingPresentation(false)
	ThrowInput.setFlightActive(false)
	ThrowHud.clearFlight(hud)
	ThrowHud.dismissResult(hud)
	ThrowHud.setFlightMode(hud, false)
	ThrowFx.restoreCamera(ThrowInput.humanoid())
end)

Remotes.Skip.OnClientEvent:Connect(function(
	throwerUserId: number,
	position: Vector3,
	skipIndex: number,
	tier: number,
	impactVelocity: Vector3?,
	quality: string?,
	throwId: number?,
	contactGrade: string?
)
	debug.profilebegin("Skip.ClientDispatch")
	-- The tier stinger belongs to the skip that crosses into a new tier, not
	-- to every skip after it. Tracked per thrower so two people skipping at
	-- once cannot mask each other's tier-ups.
	if skipIndex <= 1 then
		lastTierByThrower[throwerUserId] = 1
	end
	local previousTier = lastTierByThrower[throwerUserId] or 1
	local tierUp = tier > previousTier
	if tierUp then
		lastTierByThrower[throwerUserId] = tier
	end

	debug.profilebegin("Skip.Spectacle")
	-- Recolor only the replicated pebble belonging to this confirmed throw.
	for pebble in attachedPebbles do
		if pebble:IsA("Model") and pebble:GetAttribute("ThrowerUserId") == throwerUserId
			and (not throwId or pebble:GetAttribute("ThrowId") == throwId) then
			ThrowFx.setFlightMilestone(pebble, skipIndex)
			ThrowFx.onSkipSpectacle(pebble, position, skipIndex, impactVelocity, quality,
				throwerUserId == player.UserId and (not throwId or throwId == myThrowId))
		end
	end
	debug.profileend()
	debug.profilebegin("Skip.Splash")
	-- Everyone sees and hears every splash, sized by how hard it hit...
	ThrowFx.playSplash(position, skipIndex, tier, impactVelocity, tierUp, quality,
		throwerUserId == player.UserId and (not throwId or throwId == myThrowId), contactGrade)
	debug.profileend()
	debug.profilebegin("Skip.Hud")
	-- ...but the combo counter only tracks your own rock.
	if throwerUserId == player.UserId and (not throwId or throwId == myThrowId) then
		ThrowHud.setCombo(hud, skipIndex, tier)
	end
	debug.profileend()
	debug.profileend()
end)

Remotes.MoneyCollected.OnClientEvent:Connect(function(
	collectorUserId: number,
	collected: {any},
	total: number
)
 local collectorPebble: Model? = if collectorUserId == player.UserId then myPebble else nil
 if not collectorPebble then
  local newestThrow=-math.huge
  for pebble in attachedPebbles do
   if pebble:IsA("Model") and pebble:IsDescendantOf(workspace)
    and pebble:GetAttribute("ThrowerUserId")==collectorUserId then
    local throwId=pebble:GetAttribute("ThrowId")
    if typeof(throwId)=="number" and throwId>newestThrow then
     newestThrow=throwId;collectorPebble=pebble
    end
   end
  end
 end
 MoneyFx.playClaim(collected,total,collectorUserId==player.UserId,collectorPebble,collectorUserId)
end)

Remotes.ThrowEnded.OnClientEvent:Connect(function(result)
	if typeof(result.throwId) == "number" then
		lastEndedThrowId = math.max(lastEndedThrowId, result.throwId)
		if myThrowId and myThrowId ~= result.throwId then return end
	end
	if not ThrowInput.isCurrentRequest(result.requestId) then return end
	ThrowInput.confirmRelease(result.quality or "normal", false, result.releaseFraction, result.requestId)
	-- The server owns the saved personal best, so it decides what is a
	-- record. The old session-local compare re-announced "NEW BEST" on every
	-- rejoin and never knew about saved progress.
	local isRecord = result.isRecord == true
	if typeof(result.previousBestDistance) ~= "number" then
		result.previousBestDistance = bestAtLaunch
	end
	ThrowFx.finishSpectacle(result)
	if isRecord then ThrowFx.duckRecord() end
	ThrowFx.cancelPrediction(result.requestId)
	ThrowInput.setEndingPresentation(true)

	-- Release the pebble BEFORE clearing the HUD. The live distance loop keys
	-- off myPebble and would otherwise re-show the readout on its next tick --
	-- and since the pebble lingers for 3s while it sinks, the label would then
	-- be stranded on screen permanently.
	myPebble = nil
	EncounterFx.finish()
	myThrowId = nil
	if myFlightCleanup then
		myFlightCleanup()
		myFlightCleanup = nil
	end

	if typeof(result.position) == "Vector3" then
		ThrowFx.playSink(result.position, result.quality, result.skips, result.endReason)
	end

	ThrowHud.clearFlight(hud)
	ThrowHud.setFlightMode(hud, false)
	endingPresentationToken += 1
	local token = endingPresentationToken
	local character = player.Character
	ThrowHud.showResult(hud, result, isRecord)
	local function completePresentation()
		if token ~= endingPresentationToken then return end
		ThrowInput.setEndingPresentation(false)
		ThrowInput.setFlightActive(false)
		local humanoid = ThrowInput.humanoid()
		if player.Character == character and humanoid and humanoid.Health > 0 then
			-- Results are already visible while the camera returns.
		end
	end
	if (result.endReason == "sunk" or result.endReason == "skipLimit") and typeof(result.position) == "Vector3" then
		ThrowInput.setFlightActive(true)
		ThrowFx.finishThrowCamera(ThrowInput.humanoid(), result.position, completePresentation)
	else
		ThrowFx.restoreCamera(ThrowInput.humanoid())
		completePresentation()
	end
end)


