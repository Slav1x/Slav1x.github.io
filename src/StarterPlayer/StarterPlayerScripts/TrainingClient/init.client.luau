--!strict
-- Toggle palm-spin training, avatar-aware presentation, and AFK portrait.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local player = Players.LocalPlayer
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local gui = Instance.new("ScreenGui")
gui.Name = "SpinTrainingGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 35
gui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.Name = "AFKSpinButton"
button.AnchorPoint = Vector2.new(1, .5)
button.Position = UDim2.new(1, -18, .59, 0)
button.Size = UDim2.fromOffset(150, 66)
button.BackgroundColor3 = Color3.fromRGB(4, 26, 56)
button.AutoButtonColor = false
button.Text = ""
button.Parent = gui
local outerCorner = Instance.new("UICorner")
outerCorner.CornerRadius = UDim.new(0, 14)
outerCorner.Parent = button
local outerStroke = Instance.new("UIStroke")
outerStroke.Color = Color3.fromRGB(0, 0, 0)
outerStroke.Thickness = 3
outerStroke.Parent = button
local inner = Instance.new("Frame")
inner.Name = "StuddedPanel"
inner.Position = UDim2.fromOffset(4, 4)
inner.Size = UDim2.new(1, -8, 1, -8)
inner.BackgroundColor3 = Color3.fromRGB(0, 91, 208)
inner.ClipsDescendants = true
inner.Parent = button
local innerCorner = Instance.new("UICorner")
innerCorner.CornerRadius = UDim.new(0, 10)
innerCorner.Parent = inner
local blueLine = Instance.new("UIStroke")
blueLine.Color = Color3.fromRGB(0, 196, 255)
blueLine.Thickness = 2
blueLine.Parent = inner
local studs = Instance.new("ImageLabel")
studs.Name = "Studs"
studs.Size = UDim2.fromScale(1, 1)
studs.BackgroundTransparency = 1
studs.Image = "rbxassetid://6927295847"
studs.ImageColor3 = Color3.fromRGB(14, 112, 239)
studs.ImageTransparency = .2
studs.ScaleType = Enum.ScaleType.Tile
studs.TileSize = UDim2.fromOffset(32, 32)
studs.Parent = inner
local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 5, 0, 5)
title.Size = UDim2.new(1, -10, 0, 30)
title.Font = Enum.Font.FredokaOne
title.Text = "AFK SPIN"
title.TextScaled = true
title.TextColor3 = Color3.new(1, 1, 1)
title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
title.TextStrokeTransparency = 0
title.ZIndex = 3
title.Parent = button
local subtitle = Instance.new("TextLabel")
subtitle.Name = "Bonus"
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.new(0, 5, 0, 37)
subtitle.Size = UDim2.new(1, -10, 0, 19)
subtitle.Font = Enum.Font.FredokaOne
subtitle.Text = "+35% TRAINING"
subtitle.TextScaled = true
subtitle.TextColor3 = Color3.fromRGB(153, 255, 177)
subtitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
subtitle.TextStrokeTransparency = 0
subtitle.ZIndex = 3
subtitle.Parent = button

local tip = Instance.new("TextLabel")
tip.Name = "SpinTip"
tip.AnchorPoint = Vector2.new(1, .5)
tip.Position = UDim2.new(1, -20, .59, 51)
tip.Size = UDim2.fromOffset(180, 28)
tip.BackgroundColor3 = Color3.fromRGB(5, 22, 43)
tip.BackgroundTransparency = .1
tip.Font = Enum.Font.FredokaOne
tip.Text = "CLICK / E TO TRAIN"
tip.TextSize = 14
tip.TextColor3 = Color3.new(1, 1, 1)
tip.TextStrokeTransparency = 0
tip.Visible = false
tip.Parent = gui
local tipCorner = Instance.new("UICorner")
tipCorner.CornerRadius = UDim.new(0, 8)
tipCorner.Parent = tip
local tipStroke = Instance.new("UIStroke")
tipStroke.Color = Color3.fromRGB(62, 183, 255)
tipStroke.Thickness = 2
tipStroke.Parent = tip

local watchedTool: Tool? = nil
local activatedConnection: RBXScriptConnection? = nil
local lastManual = -math.huge
-- Training state is replicated by the server.
local cameraStart = 0
local cameraFrom = CFrame.identity
local cameraActive = false
local restoreOnRespawn = false

local function heldTrainingTool(character: Model?): Tool?
	if not character then return nil end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("IsTrainingTool") == true then return child end
	end
	return nil
end

-- Presentation-only soundscape; rewards still come from ShopResult.
local soundscape = require(script:WaitForChild("TrainingSoundscape")).new(player, Remotes, heldTrainingTool)
script.Destroying:Connect(function() soundscape:destroy() end)

local function manualTrain()
	if player:GetAttribute("RockInFlight") == true then return end
	if not heldTrainingTool(player.Character) then return end
	local now = os.clock()
	if now - lastManual < .3 then return end
	lastManual = now
	Remotes.TrainingMode:FireServer(if player:GetAttribute("TrainingSpinning") == true then "off" else "spin")
end

local function refreshTool()
	local tool = heldTrainingTool(player.Character)
	if tool == watchedTool then return end
	if activatedConnection then activatedConnection:Disconnect(); activatedConnection = nil end
	watchedTool = tool
	if tool then activatedConnection = tool.Activated:Connect(manualTrain) end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.E then manualTrain() end
end)

local function lockControls(_, _, _)
	return Enum.ContextActionResult.Sink
end
local function setCamera(active: boolean)
	if cameraActive == active then return end
	cameraActive = active
	local camera = workspace.CurrentCamera
	if active then
		if camera then
			cameraFrom = camera.CFrame
			cameraStart = os.clock()
			camera.CameraType = Enum.CameraType.Scriptable
		end
		ContextActionService:BindActionAtPriority("AFKSpinFreeze", lockControls, false,
			Enum.ContextActionPriority.High.Value + 75,
			Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
			Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
			Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.Thumbstick1)
	else
		ContextActionService:UnbindAction("AFKSpinFreeze")
		if camera then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				camera.CameraSubject = humanoid
				if humanoid.Health <= 0 then restoreOnRespawn = true end
			end
			camera.CameraType = Enum.CameraType.Custom
		end
	end
end

local removingConnection = player.CharacterRemoving:Connect(function()
	if cameraActive then restoreOnRespawn = true; setCamera(false) end
end)
local respawnConnection = player.CharacterAdded:Connect(function(character)
	if not restoreOnRespawn then return end
	local humanoid = character:WaitForChild("Humanoid", 8)
	if humanoid and not cameraActive and player:GetAttribute("RebirthCutscene") ~= true then
		local camera = workspace.CurrentCamera
		if camera then camera.CameraSubject = humanoid; camera.CameraType = Enum.CameraType.Custom end
	end
	restoreOnRespawn = false
end)

local function refreshMode()
	local active = player:GetAttribute("TrainingAFK") == true
	inner.BackgroundColor3 = if active then Color3.fromRGB(17, 128, 41) else Color3.fromRGB(0, 91, 208)
	blueLine.Color = if active then Color3.fromRGB(87, 255, 101) else Color3.fromRGB(0, 196, 255)
	studs.ImageColor3 = if active then Color3.fromRGB(57, 190, 64) else Color3.fromRGB(14, 112, 239)
	title.Text = if active then "EXIT AFK" else "AFK SPIN"
	subtitle.Text = if active then "WATCH YOUR SPIN" else "+35% TRAINING"
	setCamera(active)
end
player:GetAttributeChangedSignal("TrainingAFK"):Connect(refreshMode)
button.Activated:Connect(function()
	Remotes.TrainingMode:FireServer(if player:GetAttribute("TrainingAFK") == true then "spin" else "afk")
end)

-- Each client presents the trick on the actual avatar, including nearby players.
local Presentation = require(script:WaitForChild("TrainingPresentation"))
local Progression = require(ReplicatedStorage.Shared.ProgressionConfig)
local presentations: {[Player]: any} = {}
local presentationFolder = Instance.new("Folder")
presentationFolder.Name = "TrainingSpinPresentation"
presentationFolder.Parent = workspace
local progress = Instance.new("Frame")
progress.Name = "TrainingProgress"
progress.AnchorPoint = Vector2.new(0, 1)
progress.Position = UDim2.new(0, 4, 1, -1)
progress.Size = UDim2.new(0, 0, 0, 3)
progress.BackgroundColor3 = Color3.fromRGB(118, 255, 174)
progress.BorderSizePixel = 0
progress.Parent = tip
local progressCorner = Instance.new("UICorner")
progressCorner.CornerRadius = UDim.new(1, 0)
progressCorner.Parent = progress
local lastRewardCount = soundscape.count
local lastRewardAt = os.clock()
local animationConnection = RunService.PreAnimation:Connect(function()
	for _, state in presentations do state:prepare() end
end)
local poseConnection = RunService.PreSimulation:Connect(function(dt)
	local reduced = player:GetAttribute("ReducedMotion") == true
	local remoteCount = 0
	local remoteLimit = player:GetAttribute("GraphicsQualityPreset") == "LOW" and 2 or 4
	for _, owner in Players:GetPlayers() do
		local character = owner.Character
		local tool = heldTrainingTool(character)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local active = tool ~= nil and owner:GetAttribute("TrainingSpinning") == true
			and humanoid ~= nil and humanoid.Health > 0
		local camera = workspace.CurrentCamera
		local root = character and character.PrimaryPart
		local near = owner == player or (root and camera and (root.Position - camera.CFrame.Position).Magnitude < 95)
		active = active and near == true
		if active and owner ~= player then
			remoteCount += 1
			active = remoteCount <= remoteLimit
		end
		local state = presentations[owner]
		if state and (state.tool ~= tool or state.character ~= character or not state.original.Parent) then
			state:destroy()
			presentations[owner] = nil
			state = nil
		end
		if active and not state and character and tool then
			state = Presentation.new(character, tool, presentationFolder, owner)
			presentations[owner] = state
		end
		if state and state:step(dt, active, reduced) then
			state:destroy()
			presentations[owner] = nil
		end
	end
	for owner, state in presentations do
		if not owner.Parent then state:destroy(); presentations[owner] = nil end
	end
	if soundscape.count ~= lastRewardCount then
		lastRewardAt = os.clock()
		lastRewardCount = soundscape.count
		if presentations[player] then presentations[player]:reward() end
	end
	refreshTool()
	local spinning = player:GetAttribute("TrainingSpinning") == true
	local alive = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	button.Visible = alive ~= nil and alive.Health > 0
		and player:GetAttribute("StarterRockClaimed") == true
		and player:GetAttribute("RockInFlight") ~= true
	tip.Visible = watchedTool ~= nil
	tip.Text = if UserInputService.TouchEnabled then (if spinning then "TAP TO STOP" else "TAP TO TRAIN") else (if spinning then "CLICK / E TO STOP" else "CLICK / E TO START")
	tip.TextColor3 = if spinning then Color3.fromRGB(154,255,178) else Color3.new(1,1,1)
	progress.Visible = spinning
	local fraction = math.clamp((os.clock() - lastRewardAt) / Progression.TrainingCooldown, 0, 1)
	progress.Size = UDim2.fromOffset(math.max(0, tip.AbsoluteSize.X - 8) * fraction, 3)
end)

RunService:BindToRenderStep("TrainingPalmSpin", Enum.RenderPriority.Camera.Value + 6, function()
	for _, state in presentations do state:render() end
end)

local cameraRay = RaycastParams.new()
cameraRay.FilterType = Enum.RaycastFilterType.Exclude
cameraRay.IgnoreWater = true
RunService:BindToRenderStep("AFKSpinCamera", Enum.RenderPriority.Camera.Value + 5, function(dt)
	if not cameraActive then return end
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
	if not camera or not character or not root or not root:IsA("BasePart") then return end
	local center, size = Presentation.bodyBounds(character)
	local target = center + Vector3.new(0, -size.Y * .025, 0)
	local state = presentations[player]
	if state and state.focusPosition then target = target:Lerp(state.focusPosition, .18) end
	local aspect = camera.ViewportSize.X / math.max(camera.ViewportSize.Y, 1)
	local tanFov = math.tan(math.rad(camera.FieldOfView * .5))
	local distance = math.max(size.Y * .84 / tanFov, size.X * .84 / (tanFov * aspect), 2)
	local drift = player:GetAttribute("ReducedMotion") == true and 0 or math.sin((os.clock() - cameraStart) * .22) * .065
	if aspect < 1 then
		distance = math.max(distance, math.max(size.X, size.Z, size.Y * .98) * .67 / (tanFov * aspect))
	end
	local direction = (root.CFrame.LookVector + root.CFrame.RightVector * (.32 + drift) + Vector3.new(0, .2, 0)).Unit
	local offset = direction * distance
	cameraRay.FilterDescendantsInstances = {character, presentationFolder}
	local hit = workspace:Raycast(target, offset, cameraRay)
	if hit then offset = direction * math.max(.6, hit.Distance - .3) end
	local wanted = CFrame.lookAt(target + offset, target)
	local alpha = math.clamp((os.clock() - cameraStart) / .8, 0, 1)
	if alpha < 1 then
		camera.CFrame = cameraFrom:Lerp(wanted, 1 - (1 - alpha)^3)
	else
		camera.CFrame = camera.CFrame:Lerp(wanted, 1 - math.exp(-dt * 7))
	end
end)

script.Destroying:Connect(function()
	animationConnection:Disconnect()
	poseConnection:Disconnect()
	removingConnection:Disconnect()
	respawnConnection:Disconnect()
	RunService:UnbindFromRenderStep("TrainingPalmSpin")
	RunService:UnbindFromRenderStep("AFKSpinCamera")
	for _, state in presentations do state:destroy() end
	presentationFolder:Destroy()
	setCamera(false)
	gui:Destroy()
end)

refreshMode()
local function fitTraining()
 local v=workspace.CurrentCamera.ViewportSize
 local compact=v.X<600 or v.Y<500
 button.AnchorPoint=compact and Vector2.new(.5,.5) or Vector2.new(1,.5)
 button.Position=compact and UDim2.fromScale(.76,v.X<v.Y and .70 or .49) or UDim2.new(1,-18,.59,0)
 local scale=button:FindFirstChild("MobileScale") or Instance.new("UIScale",button)
 scale.Name="MobileScale";scale.Scale=compact and .7 or 1
 tip.Position=compact and UDim2.new(.76,0,v.X<v.Y and .70 or .49,30) or UDim2.new(1,-20,.59,51)
 tip.AnchorPoint=compact and Vector2.new(.5,0) or Vector2.new(1,.5)
 tip.Size=compact and UDim2.fromOffset(130,24) or UDim2.fromOffset(180,28)
 tip.TextSize=compact and 11 or 14
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitTraining)
fitTraining()
