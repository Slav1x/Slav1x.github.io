--!strict
-- Avatar-preserving palm spin with client-only AFK energy choreography.
local VFX = require(script.Parent:WaitForChild("TrainingVFX"))
local Presentation = {}
local State = {}
State.__index = State

local function jointFor(character: Model, name: string, fallback: string?)
	local joint = character:FindFirstChild(name, true) or (fallback and character:FindFirstChild(fallback, true))
	if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then return joint end
	return nil
end

local function pose(state, joint, rotation: CFrame, weight: number)
	if not joint or not joint.Parent then return end
	-- R6 shoulder axes differ from R15. Apply rotations in the parent body axes.
	local basis = joint.C0.Rotation
	local target = basis:Inverse() * rotation * basis
	state.baseTransforms[joint] = joint.Transform
	joint.Transform = joint.Transform:Lerp(target, weight)
end

local function extentUp(part: BasePart): number
	local size = part.Size * .5
	local cf = part.CFrame
	return math.abs(cf.RightVector.Y) * size.X
		+ math.abs(cf.UpVector.Y) * size.Y
		+ math.abs(cf.LookVector.Y) * size.Z
end

function Presentation.bodyBounds(character: Model): (Vector3, Vector3)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") then
			local half = part.Size * .5
			local r, u, b = part.CFrame.RightVector, part.CFrame.UpVector, part.CFrame.LookVector
			local worldHalf = Vector3.new(
				math.abs(r.X)*half.X + math.abs(u.X)*half.Y + math.abs(b.X)*half.Z,
				math.abs(r.Y)*half.X + math.abs(u.Y)*half.Y + math.abs(b.Y)*half.Z,
				math.abs(r.Z)*half.X + math.abs(u.Z)*half.Y + math.abs(b.Z)*half.Z)
			low = low:Min(part.Position - worldHalf)
			high = high:Max(part.Position + worldHalf)
		end
	end
	if low.X == math.huge then
		local p = character:GetPivot().Position
		return p, Vector3.new(4, 6, 3)
	end
	return (low + high) * .5, high - low
end

function Presentation.new(character: Model, tool: Tool, parent: Instance, owner: Player)
	local root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
		or character:FindFirstChild("RightLowerArm")
	local original = tool:FindFirstChild("RockVisual")
	if not root or not root:IsA("BasePart") or not original or not original:IsA("Model") then return nil end
	if hand and not hand:IsA("BasePart") then hand = nil end
	local _, bodySize = Presentation.bodyBounds(character)
	local scale = math.clamp(bodySize.Y / 5.5, .3, 3)
	local folder = Instance.new("Folder")
	folder.Name = character.Name .. "_PalmSpin"
	folder.Parent = parent
	local rock = original:Clone()
	local parts = {}
	for _, child in rock:GetDescendants() do
		if child:IsA("JointInstance") or child:IsA("WeldConstraint") then
			child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored = true
			child.CanCollide = false
			child.CanQuery = false
			child.CanTouch = false
			child.LocalTransparencyModifier = 0
			table.insert(parts, child)
		elseif child:IsA("BaseScript") then
			child:Destroy()
		end
	end
	rock:PivotTo(CFrame.identity)
	local _, originalSize = rock:GetBoundingBox()
	local palmWidth = if hand then math.max(hand.Size.X, hand.Size.Z) else scale
	local width = math.clamp(palmWidth * 1.25, .8 * scale, 1.5 * scale)
	rock:ScaleTo(rock:GetScale() * width / math.max(originalSize.X, originalSize.Z, .01))
	local box, size = rock:GetBoundingBox()
	local centerOffset = rock:GetPivot():ToObjectSpace(box)
	rock.Parent = folder
	local hidden = {}
	local effects = {}
	for _, child in original:GetDescendants() do
		if child:IsA("BasePart") then
			table.insert(hidden, {part=child, transparency=child.LocalTransparencyModifier})
		elseif child:IsA("ParticleEmitter") or child:IsA("Trail") or child:IsA("Beam") then
			table.insert(effects, {effect=child, enabled=child.Enabled})
			child.Enabled = false
		end
	end
	local trails = {}
	for index = 1, 2 do
		local anchor = Instance.new("Part")
		anchor.Name = "AirRibbon" .. index
		anchor.Size = Vector3.new(.05, .05, .05)
		anchor.Transparency = 1
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanTouch = false
		anchor.CanQuery = false
		anchor.Parent = folder
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(0, .015 * scale, 0)
		a.Parent = anchor
		local b = Instance.new("Attachment")
		b.Position = Vector3.new(0, -.015 * scale, 0)
		b.Parent = anchor
		local trail = Instance.new("Trail")
		trail.Name = "SpinningAir"
		trail.Attachment0 = a
		trail.Attachment1 = b
		trail.Lifetime = .2
		trail.MinLength = .01
		trail.FaceCamera = true
		trail.LightEmission = .85
		trail.Color = if index == 1
			then ColorSequence.new(Color3.fromRGB(25, 185, 255), Color3.fromRGB(10, 92, 255))
			else ColorSequence.new(Color3.fromRGB(70, 255, 100), Color3.fromRGB(15, 190, 120))
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, .12),
			NumberSequenceKeypoint.new(.55, .3),
			NumberSequenceKeypoint.new(1, 1)})
		trail.WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, .45),
			NumberSequenceKeypoint.new(.18, 1),
			NumberSequenceKeypoint.new(1, 0)})
		trail.Enabled = false
		trail.Parent = anchor
		table.insert(trails, {anchor=anchor, trail=trail, a=a, b=b})
	end
	return setmetatable({
		character=character, tool=tool, original=original, hand=hand, root=root, owner=owner,
		vfx=VFX.new(folder,character,root,scale,size), afkWeight=0,
		folder=folder, rock=rock, parts=parts, centerOffset=centerOffset,
		rockSize=size, scale=scale, hidden=hidden, effects=effects, trails=trails,
		alpha=0, angle=0, speed=0, pulse=0, destroyed=false, baseTransforms={},
		shoulder=jointFor(character, "RightShoulder", "Right Shoulder"),
		elbow=jointFor(character, "RightElbow", nil),
		wrist=jointFor(character, "RightWrist", nil),
		leftShoulder=jointFor(character, "LeftShoulder", "Left Shoulder"),
		leftElbow=jointFor(character, "LeftElbow", nil),
		neck=jointFor(character, "Neck", nil),
	}, State)
end

-- Remove our previous pose before Animator evaluates the next frame. This also
-- prevents accumulated rotations on custom rigs with no active animation tracks.
function State:prepare()
	for joint, transform in self.baseTransforms do
		if joint.Parent then joint.Transform = transform end
	end
	table.clear(self.baseTransforms)
end

function State:reward()
	self.pulse = 1
	self.vfx:reward()
end

function State:step(dt: number, active: boolean, reducedMotion: boolean): boolean
	if self.destroyed then return true end
	self.alpha += ((active and 1 or 0) - self.alpha) * (1 - math.exp(-dt * 10))
	self.speed += ((active and 18.5 or 0) - self.speed) * (1 - math.exp(-dt * (active and 7 or 10)))
	self.angle = (self.angle + self.speed * dt) % (math.pi * 2)
	self.pulse *= math.exp(-dt * 5)
	local time = workspace:GetServerTimeNow()
	local breath = if reducedMotion then 0 else math.sin(time * 2) * .014
	if self.elbow then
		pose(self, self.shoulder, CFrame.Angles(math.rad(32) + breath, math.rad(-22), math.rad(10)), self.alpha)
		pose(self, self.elbow, CFrame.Angles(math.rad(78), 0, 0), self.alpha)
		pose(self, self.wrist, CFrame.Angles(math.rad(-10), 0, math.rad(-12)), self.alpha)
	else
		pose(self, self.shoulder, CFrame.Angles(math.rad(78) + breath, math.rad(-12), math.rad(12)), self.alpha)
	end
	local afk = self.owner:GetAttribute("TrainingAFK") == true
	self.afkWeight += ((afk and active and 1 or 0) - self.afkWeight) * (1 - math.exp(-dt * 4))
	local focus = self.alpha * self.afkWeight
	pose(self, self.neck, CFrame.Angles(math.rad(-5), math.rad(-10), math.rad(-3)), focus * .75)
	pose(self, self.leftShoulder, CFrame.Angles(math.rad(12), math.rad(15), math.rad(-12)), focus)
	if self.leftElbow then pose(self, self.leftElbow, CFrame.Angles(math.rad(35), 0, 0), focus) end
	self.vfx:step(dt, active, afk, reducedMotion)
	self.reducedMotion = reducedMotion
	return not active and self.alpha < .008
end

function State:render()
	if self.destroyed or not self.root.Parent or not self.original.Parent then return end
	for _, entry in self.hidden do
		if entry.part.Parent then entry.part.LocalTransparencyModifier = 1 end
	end
	local time = workspace:GetServerTimeNow()
	local palm: Vector3
	if self.hand and self.hand.Parent then
		if self.hand.Name == "Right Arm" then
			-- R6 has a single arm part. The supporting point is at its distal end.
			palm = (self.hand.CFrame * CFrame.new(0, -self.hand.Size.Y * .39, 0)).Position
			local half = math.min(self.hand.Size.X, self.hand.Size.Z) * .5
			palm += Vector3.new(0, half * .75, 0)
		else
			palm = self.hand.Position + Vector3.new(0, extentUp(self.hand), 0)
		end
	else
		-- Unusual custom rigs remain functional without assuming a hand or joint.
		palm = self.root.Position + self.root.CFrame.LookVector * 1.4 * self.scale
			+ Vector3.new(0, .4 * self.scale, 0)
	end
	local hover = (.09 + (self.reducedMotion and 0 or .012 * math.sin(time * 3))) * self.scale
	local rockPosition = palm + Vector3.new(0, self.rockSize.Y * .5 + hover, 0)
	local wobble = if self.reducedMotion then 0 else math.sin(self.angle * 1.25) * .018
	local goal = CFrame.new(rockPosition) * self.root.CFrame.Rotation * CFrame.Angles(wobble, self.angle, 0)
	local held = self.original:GetBoundingBox()
	local weight = self.alpha * self.alpha * (3 - 2 * self.alpha)
	local frame = held:Lerp(goal, weight)
	self.rock:PivotTo(frame * self.centerOffset:Inverse())
	self.focusPosition = frame.Position
	self.vfx:render(frame,self.alpha)
	local radius = math.max(self.rockSize.X, self.rockSize.Z) * (.65 + self.pulse * .09)
	for index, entry in self.trails do
		local phase = (index - 1) * math.pi
		-- Follow the rock's actual rotation, so the wind cannot orbit backward.
		local height = math.sin(self.angle * 2 + phase) * .085 * self.scale
			+ (index == 1 and .045 or -.045) * self.scale
		local offset = frame.Rotation:VectorToWorldSpace(Vector3.new(math.cos(phase) * radius, 0, math.sin(phase) * radius))
		entry.anchor.CFrame = CFrame.new(frame.Position + offset + Vector3.new(0, height, 0))
		local thickness = .045 * self.scale * (1 + self.pulse * .8)
		entry.a.Position = Vector3.new(0, thickness, 0)
		entry.b.Position = Vector3.new(0, -thickness, 0)
		entry.trail.Enabled = self.alpha > .35 and self.speed > 2 and not self.reducedMotion
	end
end

function State:destroy()
	if self.destroyed then return end
	self.destroyed = true
	self:prepare()
	for _, entry in self.hidden do
		if entry.part.Parent then entry.part.LocalTransparencyModifier = entry.transparency end
	end
	for _, entry in self.effects do
		if entry.effect.Parent then entry.effect.Enabled = entry.enabled end
	end
	self.vfx:destroy()
	self.folder:Destroy()
end

return Presentation
