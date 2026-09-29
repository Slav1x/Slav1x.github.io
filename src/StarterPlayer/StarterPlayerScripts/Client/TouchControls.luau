--!strict
--[[
	TouchControls (client)

	Phone and tablet controls. Most of Roblox plays on touch, and the game was
	keyboard-only -- there was literally no way to throw a rock without a
	physical E key.

	A big hold-to-charge button bottom-right, and steer arrows that only
	appear while a rock is actually in the air so they are not permanent
	clutter. Built only when the device has touch and no keyboard, so it never
	covers a PC player's screen.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ThrowConfig = require(Shared:WaitForChild("ThrowConfig"))

local PanelKit = require(script.Parent:WaitForChild("PanelKit"))
local ThrowInput = require(script.Parent:WaitForChild("ThrowInput"))

local UiStyle = require(script.Parent:WaitForChild("ThrowUiStyle"))
local TouchControls = {}

local player = Players.LocalPlayer

function TouchControls.shouldShow(): boolean
	-- A laptop with a touchscreen still has a keyboard, and would rather use
	-- it; only devices with no keyboard get the on-screen pad.
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function TouchControls.start()
	if not TouchControls.shouldShow() then
		return
	end

	local gui = PanelKit.new("ScreenGui", {
		Name = "TouchControls",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 55,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local throwSize = 150
	local theme = ThrowConfig.Presentation.Hud.Theme

	-- ------------------------------------------------------------------
	-- Throw button
	-- ------------------------------------------------------------------
	local throwButton = PanelKit.new("TextButton", {
		Name = "ThrowButton",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -40, 1, -48),
		Size = UDim2.fromOffset(150, 150),
		BackgroundColor3 = Color3.fromRGB(255, 170, 60),
		AutoButtonColor = false,
		Text = "",
		ZIndex = 56,
		Parent = gui,
	}, {
		PanelKit.new("UICorner", {CornerRadius = UDim.new(1, 0)}),
		PanelKit.stroke(Color3.new(0, 0, 0), 4, 0.3),
	})

	local throwLabel = PanelKit.new("TextLabel", {
		Position = UDim2.fromScale(0, 0.58),
		Size = UDim2.fromScale(1, 0.34),
		BackgroundTransparency = 1,
		Text = "THROW",
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.35,
		Font = PanelKit.FontHeavy,
		TextSize = 20,
		ZIndex = 57,
		Parent = throwButton,
	})

	local holdHint = PanelKit.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 4),
		Size = UDim2.fromOffset(200, 18),
		BackgroundTransparency = 1,
		Text = "hold to charge",
		TextColor3 = Color3.fromRGB(235, 243, 255),
		TextStrokeTransparency = 0.5,
		Font = PanelKit.Font,
		TextSize = 13,
		ZIndex = 57,
		Parent = throwButton,
	})

	UiStyle.button(throwButton, true)
	local pebbleIcon = PanelKit.new("ImageLabel", {
		Name = "PebbleIcon", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(0.38, 0.38),
		BackgroundTransparency = 1, Image = theme.PebbleImage,
		ScaleType = Enum.ScaleType.Fit, Rotation = 0,
        ImageRectOffset = Vector2.new(80,48), ImageRectSize = Vector2.new(416,280),
		ZIndex = 59, Parent = throwButton,
	})
	local throwGradient = throwButton:FindFirstChildOfClass("UIGradient") :: UIGradient
	local throwStroke = throwButton:FindFirstChildOfClass("UIStroke") :: UIStroke
	local function refreshThrowButton()
		local enabled = ThrowInput.isRockHeld()
		throwGradient.Color = if enabled
			then ColorSequence.new(theme.GoldLight, theme.Gold)
			else ColorSequence.new(Color3.fromRGB(138, 155, 166), Color3.fromRGB(73, 89, 102))
		pebbleIcon.Visible = enabled
		throwLabel.Position = if enabled then UDim2.fromScale(0, 0.58) else UDim2.fromScale(0, 0.25)
		throwLabel.Size = if enabled then UDim2.fromScale(1, 0.34) else UDim2.fromScale(1, 0.5)
		throwLabel.Text = if enabled then "HOLD TO\nTHROW" else "EQUIP\nROCK"
	end
	local function watchCharacter(character: Model)
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then task.defer(refreshThrowButton) end
		end)
		character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then task.defer(refreshThrowButton) end
		end)
		task.defer(refreshThrowButton)
	end
	if player.Character then watchCharacter(player.Character) end
	player.CharacterAdded:Connect(watchCharacter)

	--[[
		InputBegan/InputEnded on the button rather than MouseButton1Down/Up:
		the Up variants do not fire reliably if the finger slides off a button
		before lifting, which on a charge-and-release control would leave the
		player stuck mid-charge forever.
	]]
	local throwTouch: InputObject? = nil
 throwButton.Activated:Connect(function()
  if not ThrowInput.isRockHeld() then
   ThrowInput.equipSelectedRock()
   refreshThrowButton()
  end
 end)
	throwButton.InputBegan:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) and not throwTouch and ThrowInput.isRockHeld() then
			throwTouch = input
			ThrowInput.beginCharge()
			if ThrowInput.isCharging() then
				throwLabel.Text = "RELEASE"
				TweenService:Create(throwStroke, TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Thickness = 5, Color = theme.GoldLight,
				}):Play()
				TweenService:Create(pebbleIcon, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Rotation = 10,
				}):Play()
			end
		end
	end)

	local function release()
		throwTouch = nil
		ThrowInput.endCharge()
		refreshThrowButton()
		TweenService:Create(throwStroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Thickness = 1.5, Color = theme.Gold,
		}):Play()
		TweenService:Create(pebbleIcon, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Rotation = 0,
		}):Play()
	end

	throwButton.InputEnded:Connect(function(input)
		if input == throwTouch then
			release()
		end
	end)

	-- Belt and braces: if the touch ends anywhere at all, stop charging.
	UserInputService.InputEnded:Connect(function(input)
		if input == throwTouch then
			release()
		end
	end)

	-- ------------------------------------------------------------------
	-- Steer arrows, only while a rock is in flight
	-- ------------------------------------------------------------------
	local steerBar = PanelKit.new("Frame", {
		Name = "SteerBar",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 40, 1, -48),
		Size = UDim2.fromOffset(210, 96),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 56,
		Parent = gui,
	})

	local function steerButton(label: string, x: number, setter: (boolean) -> ())
		local button = PanelKit.new("TextButton", {
			Name = label,
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(96, 96),
			BackgroundColor3 = Color3.fromRGB(90, 200, 255),
			AutoButtonColor = false,
			Text = label,
			TextColor3 = Color3.fromRGB(10, 16, 24),
			Font = PanelKit.FontHeavy,
			TextSize = 34,
			ZIndex = 57,
			Parent = steerBar,
		}, {
			PanelKit.new("UICorner", {CornerRadius = UDim.new(1, 0)}),
			PanelKit.stroke(Color3.new(0, 0, 0), 4, 0.3),
		})

		UiStyle.button(button)
		button.TextColor3 = ThrowConfig.Presentation.Hud.Theme.Text
		local steeringTouch: InputObject? = nil
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				steeringTouch = input
				setter(true)
			end
		end)
		button.InputEnded:Connect(function(input)
			if input == steeringTouch then
				steeringTouch = nil
				setter(false)
			end
		end)
		-- A finger sliding off the arrow must not leave the rock turning
		-- forever, which would look exactly like the old wall-ricochet bug.
		UserInputService.TouchEnded:Connect(function(input)
			if input == steeringTouch then steeringTouch = nil; setter(false) end
		end)
		return button
	end

	local leftButton = steerButton("◀", 0, ThrowInput.setSteerLeft)
	local rightButton = steerButton("▶", 114, ThrowInput.setSteerRight)
	local function fitControls()
		local viewport = workspace.CurrentCamera.ViewportSize
		local compact = viewport.X < 600 or viewport.Y < 500
		throwSize = if compact then 96 else 130
		throwButton.Size = UDim2.fromOffset(throwSize, throwSize)
		-- On phones the button sits between the level bar, jump control and quests.
		throwButton.Position = UDim2.new(1, if compact then -130 else -20, 1, if compact then -95 else -48)
		holdHint.Visible = not compact
		local arrowSize = if compact then 64 else 80
		steerBar.Position = UDim2.new(0, 16, 1, -48)
		steerBar.Size = UDim2.fromOffset(arrowSize * 2 + 12, arrowSize)
		leftButton.Size = UDim2.fromOffset(arrowSize, arrowSize)
		rightButton.Size = UDim2.fromOffset(arrowSize, arrowSize)
		rightButton.Position = UDim2.fromOffset(arrowSize + 12, 0)
	end
	fitControls()
	local viewportConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitControls)
	gui.Destroying:Once(function() viewportConnection:Disconnect() end)

	-- Show the arrows exactly while this player has a rock airborne.
	local function refreshSteer()
		local mine = false
		for _, pebble in CollectionService:GetTagged(ThrowConfig.PebbleTag) do
			if pebble:GetAttribute("ThrowerUserId") == player.UserId and pebble:GetAttribute("Sinking") ~= true then
				mine = true
				break
			end
		end
		throwButton.Visible = not mine
		if steerBar.Visible ~= mine then
			steerBar.Visible = mine
			if not mine then
				ThrowInput.setSteerLeft(false)
				ThrowInput.setSteerRight(false)
			end
		end
	end

	local function watchPebble(pebble: Instance)
		local connection: RBXScriptConnection
		connection = pebble:GetAttributeChangedSignal("Sinking"):Connect(refreshSteer)
		pebble:GetAttributeChangedSignal("ThrowerUserId"):Connect(refreshSteer)
		task.delay(.1, refreshSteer)
		pebble.AncestryChanged:Connect(function()
			if not pebble:IsDescendantOf(workspace) then connection:Disconnect(); refreshSteer() end
		end)
		refreshSteer()
	end
	CollectionService:GetInstanceAddedSignal(ThrowConfig.PebbleTag):Connect(watchPebble)
	for _, pebble in CollectionService:GetTagged(ThrowConfig.PebbleTag) do watchPebble(pebble) end
	CollectionService:GetInstanceRemovedSignal(ThrowConfig.PebbleTag):Connect(function()
		task.defer(refreshSteer)
	end)
	refreshSteer()
end

return TouchControls
