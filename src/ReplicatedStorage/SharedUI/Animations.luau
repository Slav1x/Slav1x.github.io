--!strict
--[[
	Animations
	All shared TweenService effects: button hover/press, panel open/close,
	and element pop-in. Keep tweens short and responsive.
--]]

local TweenService = game:GetService("TweenService")

local Animations = {}

-- Generic tween helper
function Animations.tween(instance: Instance, properties: {[string]: any}, duration: number?, easingStyle: Enum.EasingStyle?, easingDirection: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration or 0.15, easingStyle or Enum.EasingStyle.Quad, easingDirection or Enum.EasingDirection.Out),
		properties
	)
	tween:Play()
	return tween
end

--[[
	Applies hover-grow / press-shrink behavior to any GuiButton.
	Works on PC (MouseEnter) and mobile (Touch input).
--]]
function Animations.applyButtonEffects(button: GuiButton, hoverScale: number?, pressScale: number?)
	hoverScale = hoverScale or 1.06
	pressScale = pressScale or 0.94

	local scale = button:FindFirstChild("ButtonScale")
	if not scale or not scale:IsA("UIScale") then
		scale = Instance.new("UIScale")
		scale.Name = "ButtonScale"
		scale.Parent = button
	end

	local hovered = false
	local pressed = false

	local function update()
		local target = 1
		if pressed then
			target = pressScale
		elseif hovered then
			target = hoverScale
		end
		Animations.tween(scale, {Scale = target}, 0.1)
	end

	button.MouseEnter:Connect(function()
		hovered = true
		update()
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		pressed = false
		update()
	end)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pressed = true
			update()
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pressed = false
			update()
		end
	end)
end

--[[
	Generic frame open/close animations for panels that are NOT CanvasGroups
	(plain Frames / ImageLabels). Uses a UIScale so it works on any GuiObject.
--]]
local function getOrCreateScale(panel: GuiObject): UIScale
	local scale = panel:FindFirstChild("PanelScale")
	if not scale or not scale:IsA("UIScale") then
		scale = Instance.new("UIScale")
		scale.Name = "PanelScale"
		scale.Parent = panel
	end
	return scale
end

-- Opens any GuiObject panel with a quick scale-up pop.
function Animations.showFrame(panel: GuiObject)
	local scale = getOrCreateScale(panel)
	panel.Visible = true
	scale.Scale = 0.9
	Animations.tween(scale, {Scale = 1}, 0.22, Enum.EasingStyle.Back)
end

-- Closes any GuiObject panel with a quick scale-down, then hides it.
-- The panel's AnchorPoint should be centered (0.5, 0.5) so it shrinks toward the middle.
function Animations.hideFrame(panel: GuiObject, callback: (() -> ())?)
	local scale = getOrCreateScale(panel)
	Animations.tween(scale, {Scale = 0.85}, 0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.14, function()
		panel.Visible = false
		scale.Scale = 1
		if callback then
			callback()
		end
	end)
end

-- Smoothly opens a panel (fade + scale up). Optionally fades in an overlay behind it.
function Animations.showPanel(panel: CanvasGroup, overlay: Frame?)
	local scale = panel:FindFirstChild("PanelScale")
	if not scale or not scale:IsA("UIScale") then
		scale = Instance.new("UIScale")
		scale.Name = "PanelScale"
		scale.Parent = panel
	end

	if overlay then
		overlay.Visible = true
		overlay.BackgroundTransparency = 1
		Animations.tween(overlay, {BackgroundTransparency = 0.45}, 0.18)
	end

	panel.Visible = true
	panel.GroupTransparency = 1
	scale.Scale = 0.9
	Animations.tween(panel, {GroupTransparency = 0}, 0.18, Enum.EasingStyle.Quint)
	Animations.tween(scale, {Scale = 1}, 0.25, Enum.EasingStyle.Back)
end

-- Smoothly closes a panel (fade + scale down), then hides it.
function Animations.hidePanel(panel: CanvasGroup, overlay: Frame?, callback: (() -> ())?)
	local scale = panel:FindFirstChild("PanelScale")
	if overlay then
		Animations.tween(overlay, {BackgroundTransparency = 1}, 0.15)
	end
	Animations.tween(panel, {GroupTransparency = 1}, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	if scale and scale:IsA("UIScale") then
		Animations.tween(scale, {Scale = 0.92}, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	task.delay(0.16, function()
		panel.Visible = false
		if overlay then
			overlay.Visible = false
		end
		if callback then
			callback()
		end
	end)
end

-- Names of the top-level MainHUD panels that should never be open together.
local MAIN_PANEL_NAMES = {"shopui", "inventoryui", "settingsui", "upgradesui"}

function Animations.getMainPanels(mainHUD: Instance): {GuiObject}
	local panels = {}
	for _, name in MAIN_PANEL_NAMES do
		local p = mainHUD:FindFirstChild(name)
		if p then
			table.insert(panels, p)
		end
	end
	return panels
end

function Animations.openExclusive(panel: GuiObject, mainHUD: Instance, callback: (() -> ())?)
	if panel.Visible then
		Animations.hideFrame(panel, callback)
		return
	end
	for _, other in Animations.getMainPanels(mainHUD) do
		if other ~= panel and other.Visible then
			other.Visible = false
		end
	end
	Animations.showFrame(panel)
end

-- Small pop-in used when grid items appear (scale 0 -> 1 with overshoot)
function Animations.popIn(element: GuiObject)
	local existing = element:FindFirstChild("PopScale")
	if existing and existing:IsA("UIScale") then
		existing:Destroy()
	end
	local scale = Instance.new("UIScale")
	scale.Name = "PopScale"
	scale.Scale = 0
	scale.Parent = element
	Animations.tween(scale, {Scale = 1}, 0.25, Enum.EasingStyle.Back)
end

return Animations
