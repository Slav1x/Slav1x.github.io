--!strict
-- End-of-throw presentation only: the server has already stopped scoring.
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.ThrowConfig)
local ThrowSink = {}
function ThrowSink.play(pebble: Model, mainPart: BasePart, surface: Vector3)
	local tuning = Config.SinkAnimation
	local velocity = mainPart.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local glide = if horizontal.Magnitude > 0.001 then horizontal.Unit * math.min(horizontal.Magnitude * tuning.GlideTime, tuning.MaxGlide) else Vector3.zero
	local startPivot = pebble:GetPivot()
	local depth = math.max(tuning.Depth, pebble:GetExtentsSize().Y)
	local drop = math.min(-depth, surface.Y - mainPart.Position.Y - depth)
	local startRotation = startPivot.Rotation
	local parts: {[BasePart]: number} = {}
	pebble:SetAttribute("Sinking", true)
	for _, item in pebble:GetDescendants() do
		if item:IsA("BasePart") then
			parts[item] = item.Transparency
			item.Anchored = true
			item.CanCollide = false
			item.CanTouch = false
			item.AssemblyLinearVelocity = Vector3.zero
			item.AssemblyAngularVelocity = Vector3.zero
		end
	end
	local elapsed = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function(dt)
		if not pebble.Parent then
			if connection then connection:Disconnect() end
			return
		end
		elapsed += dt
		local alpha = math.clamp(elapsed / tuning.Duration, 0, 1)
		-- Water drag arrests forward travel while the stone tips and drops.
		local travel = 1 - (1 - alpha) ^ 3
		local fall = 0.35 * alpha + 0.65 * alpha * alpha
		local tilt = alpha * alpha * (3 - 2 * alpha)
		local wobble = math.sin(alpha * math.pi * 4) * (1 - alpha) * tuning.WobbleDegrees
		pebble:PivotTo(CFrame.new(startPivot.Position + glide * travel + Vector3.new(0, drop * fall, 0))
			* startRotation * CFrame.Angles(math.rad(tuning.PitchDegrees * tilt), 0, math.rad(tuning.RollDegrees * tilt + wobble)))
		local submerged = surface.Y - mainPart.Position.Y
		local fade = if submerged > tuning.SubmergedFadeDepth
			then math.clamp((alpha - tuning.FadeStart) / (1 - tuning.FadeStart), 0, 1) else 0
		for part, transparency in parts do
			if part.Parent then part.Transparency = transparency + (1 - transparency) * fade end
		end
		if alpha >= 1 then
			if connection then connection:Disconnect() end
			pebble:Destroy()
		end
	end)
end
return ThrowSink
