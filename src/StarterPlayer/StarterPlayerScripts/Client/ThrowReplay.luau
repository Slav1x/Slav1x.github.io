--!strict
-- Replays a bounded cosmetic recording; never replays remotes or awards.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spectacle = require(script.Parent:WaitForChild("ThrowSpectacle"))
local player = Players.LocalPlayer
local Replay = {}
local active: any = nil

function Replay.stop()
	local state = active
	if not state then return end
	active = nil
	state.connection:Disconnect()
	state.model:Destroy()
	state.gui:Destroy()
	if workspace.CurrentCamera == state.camera then
		state.camera.CameraType = state.cameraType
		state.camera.CameraSubject = state.subject
		state.camera.CFrame = state.view
		state.camera.FieldOfView = state.fov
	end
end

function Replay.play(): boolean
	Replay.stop()
	if player:GetAttribute("ReducedMotion") == true or player:GetAttribute("ThrowMotionScale") == 0 then return false end
	local recording = Spectacle.getReplay()
	local camera = workspace.CurrentCamera
	if not recording or not camera then return false end
	local templates = ReplicatedStorage:FindFirstChild("RockModels")
	local template = (templates and recording.rockId and templates:FindFirstChild(recording.rockId)) or ReplicatedStorage:FindFirstChild("Pebble")
	if not template or not template:IsA("Model") then return false end
	local model = require(ReplicatedStorage.Shared.RockAppearance).apply(template:Clone(), recording.rockId or "pebble", recording.variant)
	require(ReplicatedStorage.Shared.AbilityVisuals).attach(model, recording.abilityId)
	model.Name = "RecordReplayPebble"
	local collection = game:GetService("CollectionService")
	for _, tag in collection:GetTags(model) do collection:RemoveTag(model,tag) end
	for _, item in model:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("Constraint") or item:IsA("BodyMover") or item:IsA("Sound") then item:Destroy()
		elseif item:IsA("BasePart") then item.Anchored = true; item.CanCollide = false; item.CanTouch = false; item.CanQuery = false end
	end
	local samples = recording.samples
	local endTime = samples[#samples].time
	local startTime = math.max(samples[1].time, endTime-4)
	local gui = Instance.new("ScreenGui")
	gui.Name = "StoneCamReplay"; gui.ResetOnSpawn = false; gui.DisplayOrder = 80
	gui:SetAttribute("Skipstone", true)
	-- Skipstone pill: STONE CAM badge + "tap to return" on a white sticker.
	local Theme = require(ReplicatedStorage:WaitForChild("SharedUI"):WaitForChild("SkipstoneTheme"))
	local exit = Theme.button(gui, "", "stone", UDim2.fromOffset(300, 50), 2)
	exit.Name = "ExitReplay"; exit.AnchorPoint = Vector2.new(0.5, 0); exit.Position = UDim2.new(0.5, 0, 0, 20)
	local face = exit:FindFirstChild("Face") :: Frame
	local faceGradient = face:FindFirstChildOfClass("UIGradient") :: UIGradient
	faceGradient.Color = ColorSequence.new(Theme.Paper, Theme.PaperShade)
	local tag = Theme.new("Frame", {Name = "Tag", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(128, 30), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 6, Parent = face},
		{Theme.corner(), Theme.stroke(Theme.Ink, 2.5), Theme.gradient(Theme.Swatches.sun.top, Theme.Swatches.sun.bottom)})
	local tagText = Theme.label({Size = UDim2.fromScale(1, 1), FontFace = Theme.Display, TextSize = 17, Text = "STONE CAM",
		TextColor3 = Color3.new(1, 1, 1), ZIndex = 7, Parent = tag})
	Theme.textStroke(Theme.Ink, 1.8).Parent = tagText
	Theme.label({Position = UDim2.fromOffset(142, 0), Size = UDim2.new(1, -152, 1, 0), FontFace = Theme.Display, TextSize = 16,
		Text = "TAP TO RETURN", TextColor3 = Theme.Ink, ZIndex = 7, Parent = face})
	exit.Activated:Connect(Replay.stop)
	gui.Parent = player:WaitForChild("PlayerGui")
	local state = {model=model,gui=gui,camera=camera,cameraType=camera.CameraType,subject=camera.CameraSubject,view=camera.CFrame,fov=camera.FieldOfView}
	active=state
	model.Parent=workspace
	camera.CameraType=Enum.CameraType.Scriptable
	local started=os.clock()
	local cursor=1
	local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances={model,player.Character or model}; params.RespectCanCollide=true
	params.CollisionGroup="SkipPebble"
	state.connection=RunService.RenderStepped:Connect(function()
		if active~=state then return end
		if workspace.CurrentCamera~=camera or player:GetAttribute("ReducedMotion")==true then Replay.stop(); return end
		local time=startTime+(os.clock()-started)*0.8
		if time>=endTime then Replay.stop(); return end
		while cursor<#samples-1 and samples[cursor+1].time<time do cursor+=1 end
		local a,b=samples[cursor],samples[cursor+1]
		local alpha=math.clamp((time-a.time)/math.max(b.time-a.time,0.001),0,1)
		local p=a.position:Lerp(b.position,alpha)
		local delta=b.position-a.position
		local flat=Vector3.new(delta.X,0,delta.Z)
		local heading=if flat.Magnitude>0.01 then flat.Unit else Vector3.new(0,0,-1)
		model:PivotTo(CFrame.lookAt(p,p+heading)*CFrame.Angles(0,time*45,0))
		local view=p+heading:Cross(Vector3.yAxis)*13-heading*4+Vector3.new(0,5,0)
		local obstruction=workspace:Raycast(p,view-p,params)
		if obstruction then view=obstruction.Position+obstruction.Normal*0.7 end
		camera.CFrame=CFrame.lookAt(view,p+heading*2)
		camera.Focus=CFrame.new(p)
		camera.FieldOfView=65
	end)
	return true
end

player.CharacterRemoving:Connect(Replay.stop)
player:GetAttributeChangedSignal("ReducedMotion"):Connect(function()
	if player:GetAttribute("ReducedMotion")==true then Replay.stop() end
end)
player:GetAttributeChangedSignal("ThrowMotionScale"):Connect(function()
	if player:GetAttribute("ThrowMotionScale")==0 then Replay.stop() end
end)
return Replay