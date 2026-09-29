--!strict
-- Server-owned throw stance: blocks horizontal movement but leaves gravity and
-- vertical velocity untouched, so an airborne thrower lands naturally.
local RunService = game:GetService("RunService")
local ThrowMovementLock = {}
function ThrowMovementLock.acquire(character: Model, maxSeconds: number): () -> ()
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then return function() end end
	local walkSpeed = humanoid.WalkSpeed
	local autoRotate = humanoid.AutoRotate
	local jumpingEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
	local released = false
	local heartbeat: RBXScriptConnection? = nil
	local deathConnection: RBXScriptConnection? = nil
	local removalConnection: RBXScriptConnection? = nil
	local function release()
		if released then return end
		released = true
		if heartbeat then heartbeat:Disconnect() end
		if deathConnection then deathConnection:Disconnect() end
		if removalConnection then removalConnection:Disconnect() end
		if humanoid.Parent then
			humanoid.WalkSpeed = walkSpeed
			humanoid.AutoRotate = autoRotate
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, jumpingEnabled)
		end
	end
	-- Keep the current Y velocity: this is what lets a pre-throw jump fall.
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	heartbeat = RunService.Heartbeat:Connect(function()
		if not root.Parent or not humanoid.Parent then release() return end
		local current = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(0, current.Y, 0)
		root.AssemblyAngularVelocity = Vector3.zero
	end)
	deathConnection = humanoid.HealthChanged:Connect(function(health)
		if health <= 0 then release() end
	end)
	removalConnection = character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(workspace) then release() end
	end)
	task.delay(maxSeconds, release)
	return release
end
return ThrowMovementLock
