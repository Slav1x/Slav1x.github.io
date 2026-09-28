--!strict
--[[
	Notify (client)

	Stacked toasts and the level-up banner. Every server action that can
	succeed or fail quietly (a purchase, a rebirth, an equip) reports through
	here, because a button that does nothing visible reads as broken even when
	the server did exactly the right thing.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local PanelKit = require(script.Parent:WaitForChild("PanelKit"))

local Notify = {}

local KIND_COLORS: {[string]: Color3} = {
	good = PanelKit.Colors.Good,
	bad = PanelKit.Colors.Bad,
	epic = PanelKit.Colors.Gold,
	info = PanelKit.Colors.Accent,
}

local gui: ScreenGui
local stack: Frame
local banner: Frame
local bannerLabel: TextLabel

function Notify.create()
	gui = PanelKit.new("ScreenGui", {
		Name = "Notify",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 80,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})

	-- Bottom-centre, growing upward, so toasts never cover the money chips
	-- (bottom-left) or the combo readout (top-centre).
	stack = PanelKit.new("Frame", {
		Name = "Stack",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(420, 300),
		BackgroundTransparency = 1,
		ZIndex = 81,
		Parent = gui,
	}, {
		PanelKit.new("UIListLayout", {
			Padding = UDim.new(0, 6),
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	banner = PanelKit.new("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.26),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = PanelKit.Colors.Backdrop,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 82,
		Parent = gui,
	}, {
		PanelKit.corner(16),
		PanelKit.padding(18),
		PanelKit.stroke(PanelKit.Colors.Gold, 3, 0.35),
	})

	bannerLabel = PanelKit.new("TextLabel", {
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = PanelKit.Colors.Gold,
		Font = PanelKit.FontHeavy,
		TextSize = 40,
		TextStrokeTransparency = 0.5,
		ZIndex = 83,
		Parent = banner,
	})

	Remotes.ShopResult.OnClientEvent:Connect(function(id, ok, message)
		if id == "spin" and ok then return end -- The reward number appears at the trainer instead.
		if typeof(message) == "string" and message ~= "" then
			Notify.toast(message, if ok then "good" else "bad")
		end
	end)

	Remotes.Toast.OnClientEvent:Connect(function(message, kind)
		if typeof(message) == "string" then
			Notify.toast(message, if typeof(kind) == "string" then kind else "info")
		end
	end)

	Remotes.LevelUp.OnClientEvent:Connect(function(level)
		Notify.banner(string.format("LEVEL %d", level))
	end)
end

local nextOrder = 0
local pendingDiscoveries: {string} = {}
local discoveryWorker = false

local function discoveryBlocked(): boolean
 local player = Players.LocalPlayer
 if player:GetAttribute("RockInFlight") == true or player:GetAttribute("NoobDialogueOpen") == true or not gui.Enabled then return true end
 local progression = player.PlayerGui:FindFirstChild("ProgressionFeedback")
 if progression and (progression:GetAttribute("RewardNotificationsPending") or 0) > 0 then return true end
 local milestone = progression and progression:FindFirstChild("Milestone")
 if progression and progression:IsA("ScreenGui") and progression.Enabled and milestone and milestone:IsA("GuiObject") and milestone.Visible then return true end
 local throwHud = player.PlayerGui:FindFirstChild("ThrowHud")
 local result = throwHud and throwHud:FindFirstChild("ResultHolder")
 return result ~= nil and result:IsA("GuiObject") and result.Visible
end

local function deferDiscovery(message: string)
 table.insert(pendingDiscoveries, message)
 if discoveryWorker then return end
 discoveryWorker = true
 task.spawn(function()
  while gui.Parent and #pendingDiscoveries > 0 do
   while gui.Parent and discoveryBlocked() do task.wait(.1) end
   if not gui.Parent then break end
   local shown = Notify.toast(table.remove(pendingDiscoveries, 1), "epic")
   if shown then while gui.Parent and shown.Parent do task.wait(.1) end end
   task.wait(.15)
  end
  discoveryWorker = false
 end)
end

function Notify.toast(message: string, kind: string?)
 if not stack then return end
 -- Only replace a discovery notification when its matching arrival is visible.
 -- Unmatched discoveries (including multi-zone skips) are retained after flight.
 local discoveryName = string.match(message, "^(.+) DISCOVERED • NEW ROCK COLLECTION UNLOCKED$")
 local player = Players.LocalPlayer
 if discoveryName and discoveryBlocked() then
  local feedback = player.PlayerGui:FindFirstChild("ProgressionFeedback")
  local arrival = feedback and feedback:FindFirstChild("AreaArrival")
  local title = arrival and arrival:FindFirstChild("AreaName")
  if feedback and feedback:IsA("ScreenGui") and feedback.Enabled and arrival and arrival:IsA("CanvasGroup") and arrival.Visible and arrival.GroupTransparency < .5 and (arrival:GetAttribute("ShownUntil") or 0) - os.clock() >= 1.2 and title and title:IsA("TextLabel") and title.Text == discoveryName then
   feedback:SetAttribute("ArrivalDiscoveryName", discoveryName)
   feedback:SetAttribute("ArrivalDiscoveryAt", os.clock())
   local detail = arrival:FindFirstChild("AreaDetail")
   if detail and detail:IsA("TextLabel") then detail.Text = "New rock collection unlocked" end
   return
  end
  deferDiscovery(message)
  return
 end
	if not stack then
		return
	end
	nextOrder += 1

	local card = PanelKit.new("Frame", {
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = PanelKit.Colors.Backdrop,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder,
		ZIndex = 81,
		Parent = stack,
	}, {
		PanelKit.corner(10),
		PanelKit.padding(10),
		PanelKit.stroke(KIND_COLORS[kind or "info"] or PanelKit.Colors.Accent, 2, 0.3),
	})

	local label = PanelKit.new("TextLabel", {
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Text = message,
		TextColor3 = KIND_COLORS[kind or "info"] or PanelKit.Colors.Text,
		Font = PanelKit.FontHeavy,
		TextSize = 18,
		ZIndex = 82,
		Parent = card,
	})

 -- Discovery notices yield to every new flight/dialogue and to reward cards.
 -- Their readable lifetime resumes afterwards instead of expiring unseen.
 if discoveryName then
  card:SetAttribute("TransitionDiscovery",true)
  card.Visible=not discoveryBlocked()
  task.spawn(function()
   local remaining = 2.6
   while card.Parent and remaining > 0 do
    local dt = task.wait(.1)
    local blocked = discoveryBlocked()
    card.Visible = not blocked
    if not blocked then remaining -= dt end
   end
   if card.Parent then card:Destroy() end
  end)
  return card
 end

	-- Fade the card AND the label: transparency does not inherit in Roblox UI,
	-- so tweening only the frame leaves the text hanging in mid-air.
	task.delay(2.6, function()
		if not card.Parent then
			return
		end
		TweenService:Create(card, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
		local fade = TweenService:Create(label, TweenInfo.new(0.35), {TextTransparency = 1})
		fade.Completed:Once(function()
			card:Destroy()
		end)
		fade:Play()
	end)
end

local bannerToken = 0

function Notify.banner(text: string)
	if not banner then
		return
	end
	bannerToken += 1
	local token = bannerToken

	bannerLabel.Text = text
	banner.Visible = true
	banner.Size = UDim2.fromOffset(0, 0)

	task.delay(1.9, function()
		if bannerToken == token then
			banner.Visible = false
		end
	end)
end

return Notify

