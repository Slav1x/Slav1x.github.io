--!strict
--[[
	TutorialController (client)

	Presentation state machine for the beginner tutorial. The SERVER decides
	the stage (TutorialService, pushed in ProfileState.tutorial); this script
	only decides how to show it, based on what the player is doing right now
	(where they stand, whether a rock is held, which menu is open...).

	Each refresh builds a "view" = {key, card?, apply?}. When the key changes,
	all pointers are cleared and the new ones applied; when it doesn't, only
	the card text refreshes. That keeps every sub-state self-cleaning and
	lets the player do things in any order without the tutorial getting stuck.

	Modules:
	  TutorialTheme         "Skipstone" tokens, art and building blocks
	  TutorialUI            quest card, banners, confirm, confetti
	  TutorialGuidance      PointToGui / HighlightGui / ClearGuidance (+ world facade)
	  TutorialWorldMarkers  PointToWorld / HighlightWorld implementation
	  TutorialFx            sounds, camera breath, world bursts
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("TutorialConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UpgradeCatalog = require(Shared:WaitForChild("UpgradeCatalog"))
local ProgressionConfig = require(Shared:WaitForChild("ProgressionConfig"))
local AbilityCatalog = require(Shared:WaitForChild("AbilityCatalog"))

local Client = script.Parent:WaitForChild("Client")
local ProfileStore = require(Client:WaitForChild("ProfileStore"))
local ThrowInput = require(Client:WaitForChild("ThrowInput")) :: any

local Theme = require(script:WaitForChild("TutorialTheme"))
local TutorialUI = require(script:WaitForChild("TutorialUI"))
local TutorialGuidance = require(script:WaitForChild("TutorialGuidance"))
local TutorialWorldMarkers = require(script:WaitForChild("TutorialWorldMarkers"))
local Fx = require(script:WaitForChild("TutorialFx"))

local S = Theme.Swatches
local Places = Config.Places
local hl = Theme.hl

local ui = TutorialUI.new(playerGui)
local world = TutorialWorldMarkers.new(ui.guidanceLayer)
local guidance = TutorialGuidance.new(ui.guidanceLayer, world)

type View = {key: string, card: TutorialUI.ObjectiveSpec?, apply: (() -> ())?, onEnter: (() -> ())?}
type Token = TutorialUI.InputToken

-- ============================================================================
-- Small helpers
-- ============================================================================

-- Bright highlight for text on the ink banner pill.
local function glow(text: string, swatchName: string): string
	return string.format('<font color="%s">%s</font>', Theme.hex(Theme.swatch(swatchName).top), text)
end

local function compact(value: number): string
	if value >= 1e6 then return (string.format("%.1fM", value / 1e6):gsub("%.0M", "M")) end
	if value >= 1e3 then return (string.format("%.1fK", value / 1e3):gsub("%.0K", "K")) end
	return tostring(math.floor(value))
end

local function device(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then return "touch" end
	if string.find(last.Name, "Gamepad") then return "gamepad" end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then return "touch" end
	return "pc"
end

local function find(root: Instance?, path: {string}): Instance?
	local node = root
	for _, name in path do
		if not node then return nil end
		node = node:FindFirstChild(name)
	end
	return node
end

local function mainHud(): Instance?
	return playerGui:FindFirstChild("MainHUD")
end

local function panelOpen(name: string): boolean
	local panel = find(mainHud(), {name})
	return panel ~= nil and panel:IsA("GuiObject") and panel.Visible
end

local function anyMenuOpen(): boolean
	for _, name in {"shopui", "inventoryui", "upgradesui", "settingsui", "IndexPanel"} do
		if panelOpen(name) then return true end
	end
	for _, name in {"DailyRewardsUI", "PlaytimeGiftsUI", "QuestsUI"} do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("ScreenGui") and gui.Enabled then return true end
	end
	return false
end

local function cash(): number
	local stats = player:FindFirstChild("leaderstats")
	local money = stats and stats:FindFirstChild("Money")
	return if money and money:IsA("IntValue") then money.Value else 0
end

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function flatDistance(position: Vector3): number
	local root = rootPart()
	if not root then return math.huge end
	return Vector3.new(position.X - root.Position.X, 0, position.Z - root.Position.Z).Magnitude
end

local function terrainChild(name: string): Instance?
	return find(workspace, {"terrain", name})
end

local function inFlight(): boolean
	return player:GetAttribute("RockInFlight") == true
end

local function bankingRewards(): boolean
	local hud = mainHud()
	return hud ~= nil and hud:GetAttribute("BankingThrowRewards") == true
end

-- ============================================================================
-- World targets (all fall back to known positions while streamed out)
-- ============================================================================

local function wellPart(): Instance?
	return terrainChild("SpinButton")
end

local function wellPosition(): Vector3
	local well = wellPart()
	return if well and well:IsA("BasePart") then well.Position else Places.SummonWell
end

-- The well's own "Claim free roll" billboard is up (player is at the well).
local function summonPromptShown(): boolean
	local root = find(playerGui, {"SummonWorldUI", "SummonActions", "PromptRoot"})
	return root ~= nil and (root:GetAttribute("PromptActive") == true or (tonumber(root:GetAttribute("PromptOpacity")) or 0) > .3)
end

local function summonKey(): string
	local well = wellPart()
	-- The single-summon prompt keeps the default name; "SummonThreePrompt" is R.
	local found = well and well:FindFirstChild("ProximityPrompt")
	local prompt = if found and found:IsA("ProximityPrompt") then found else nil
	if device() == "gamepad" then
		return if prompt then (prompt.GamepadKeyCode.Name:gsub("^Button", "")) else "X"
	end
	return if prompt then prompt.KeyboardKeyCode.Name else "E"
end

local DECK_FALLBACK_CFRAME = CFrame.new(-534.2, 20, -40.5)
local DECK_FALLBACK_SIZE = Vector3.new(56.6, 18.7, 128.7)

local function deckRegion(): (CFrame, Vector3)
	local region = find(workspace, {"ThrowZone", "ValidRegion"})
	if region and region:IsA("BasePart") then
		return region.CFrame, region.Size
	end
	return DECK_FALLBACK_CFRAME, DECK_FALLBACK_SIZE
end

local function inThrowZone(): boolean
	local root = rootPart()
	if not root then return false end
	local cf, size = deckRegion()
	local p = cf:PointToObjectSpace(root.Position)
	return math.abs(p.X) <= size.X / 2 and math.abs(p.Y) <= size.Y / 2 and math.abs(p.Z) <= size.Z / 2
end

-- Nearest comfortable point on the dock, so the waypoint doesn't send the
-- player to the far end of a 130-stud deck.
local function deckTarget(): Vector3
	local cf, size = deckRegion()
	local root = rootPart()
	local flatCenter = Vector3.new(cf.Position.X, Places.ThrowDeck.Y, cf.Position.Z)
	if not root then return flatCenter end
	local p = cf:PointToObjectSpace(root.Position)
	local inset = 8
	local clamped = Vector3.new(
		math.clamp(p.X, -size.X / 2 + inset, size.X / 2 - inset), 0,
		math.clamp(p.Z, -size.Z / 2 + inset, size.Z / 2 - inset))
	local worldPoint = cf:PointToWorldSpace(clamped)
	return Vector3.new(worldPoint.X, Places.ThrowDeck.Y, worldPoint.Z)
end

-- A point on the water straight out from where the player stands.
local function lakeAim(): Vector3
	local root = rootPart()
	local cf = deckRegion()
	local z = if root then math.clamp(root.Position.Z, cf.Position.Z - 50, cf.Position.Z + 50) else Places.LakeAim.Z
	return Vector3.new(Places.LakeAim.X, Places.LakeAim.Y, z)
end

local function noobModel(): Instance?
	return workspace:FindFirstChild("MagicalRock")
end

local function noobPosition(): Vector3
	local model = noobModel()
	local torso = model and model:FindFirstChild("InteractionAnchor", true)
	return if torso and torso:IsA("BasePart") then torso.Position else Places.Noob
end

-- ============================================================================
-- GUI targets (resolved every frame by the guidance layer)
-- ============================================================================

local function upgradesButton(): Instance? return find(mainHud(), {"LeftNav", "Upgrades"}) end
local function moneyChip(): Instance? return find(mainHud(), {"Money"}) end
local function plazaButton(): Instance? return find(mainHud(), {"SummonGroveQuickButton"}) end
local function upgradeCard(): Instance? return find(mainHud(), {"upgradesui", "Surface", "Cards", Config.RecommendedUpgrade}) end
local function upgradeBuy(): Instance? return find(upgradeCard(), {"Buy"}) end
local function touchThrowButton(): Instance? return find(playerGui, {"TouchControls", "ThrowButton"}) end
local function hotbarSlot(): Instance? return find(playerGui, {"HotbarGui", "Hotbar", "Slot1"}) end
local function sweetZone(): Instance?
	local hud = playerGui:FindFirstChild("ThrowHud")
	return hud and hud:FindFirstChild("SweetZone", true)
end
local function noobChoices(): Instance? return find(playerGui, {"NoobConversation", "Dialogue", "Choices"}) end
local function noobButton(name: string): () -> Instance?
	return function() return find(noobChoices(), {name}) end
end

-- ============================================================================
-- Input hint rows (shown as keycaps / mouse / tap art on the card)
-- ============================================================================

local function key(text: string): Token return {kind = "key", text = text} end
local function words(text: string): Token return {kind = "text", text = text} end
local function pill(text: string, swatchName: string?): Token return {kind = "pill", text = text, swatch = swatchName} end
local ARROW: Token = {kind = "arrow"}
local MOUSE: Token = {kind = "mouse"}
local TAP: Token = {kind = "tap"}

local function pressHint(): Token
	local input = device()
	if input == "touch" then return TAP end
	if input == "gamepad" then return key("R2") end
	return MOUSE
end

-- ============================================================================
-- State
-- ============================================================================

local lastStage: string? = nil
local currentKey: string? = nil
local holdUntil = 0
local pendingBanner: string? = nil
local finishAt: number? = nil
local pendingUpgradeCelebration = false
local rebirthBannerShown = false
local finished = false
local summoning = false
local summoningSince = 0
local lastThrowSkips: number? = nil
local lastThrowAt = -math.huge
local sentAt: {[string]: number} = {}

world:setSuppressor(function()
	return anyMenuOpen() or player:GetAttribute("NoobDialogueOpen") == true
end)
-- Waypoints slide below the quest card instead of hiding under it.
world:setAvoid(function(): (Vector2?, Vector2?)
	if not ui.visible then return nil, nil end
	local holder = ui.holder
	return ui:toLayer(holder.AbsolutePosition), holder.AbsoluteSize
end)

local function sendAction(action: string)
	local now = os.clock()
	if now - (sentAt[action] or -math.huge) < 1.5 then return end
	sentAt[action] = now
	Remotes.TutorialAction:FireServer(action)
end

local function finish()
	finished = true
	pendingBanner = nil
	pendingUpgradeCelebration = false
	guidance:ClearGuidance()
	ui:hideObjective()
	currentKey = "finished"
end

local function requestSkip()
	Fx.click()
	ui:confirm("SKIP TUTORIAL?", "You can still play normally. The tips won't come back.", "SKIP", "KEEP LEARNING", function()
		sendAction("skip")
		finish()
	end)
end

-- The card key carries the input device, so switching between mouse and
-- touch re-renders the input row with the right art.
local function card(stage: string, cardKey: string, title: string, body: string, extra: {[string]: any}?): TutorialUI.ObjectiveSpec
	local spec: any = {
		key = cardKey .. "@" .. device(), step = Config.Step[stage], title = title, body = body, skippable = true,
		onSkip = requestSkip,
	}
	if extra then
		for field, value in extra do spec[field] = value end
	end
	return spec
end

local function present(view: View)
	if view.key ~= currentKey then
		currentKey = view.key
		guidance:ClearGuidance()
		if view.card then
			local wasVisible = ui.visible
			ui:showObjective(view.card)
			if not wasVisible then Fx.appear() end
		else
			ui:hideObjective()
		end
		if view.apply then view.apply() end
		if view.onEnter then view.onEnter() end
	elseif view.card then
		ui:showObjective(view.card)
	end
end

local function screenCenter(): Vector2
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize / 2 else Vector2.new(640, 360)
end

local function guiCenter(target: Instance?): Vector2?
	if not target or not target:IsA("GuiObject") then return nil end
	local position, size = TutorialGuidance.screenRect(target)
	return if position and size then ui:toLayer(position + size / 2) else nil
end

-- Check-stamp the card (showing it first if it was collapsed), with sound,
-- confetti from the medallion and a sparkle ring at the player's feet.
local function celebrateStep(text: string, stage: string)
	guidance:ClearGuidance()
	if not ui.visible then
		ui:showObjective({key = "__celebrate", step = Config.Step[stage], title = text, body = "", icon = "check", skippable = false})
	end
	local at = ui:completeObjective(text)
	Fx.step()
	Fx.worldBurst(S.sun.top, 18)
	task.delay(.05, function()
		ui:confetti(at or ui:cardCenter(), 26, .75)
	end)
	currentKey = "__celebrate"
	holdUntil = os.clock() + 1.6
end

-- ============================================================================
-- Stage transitions (server-confirmed)
-- ============================================================================

local function stageChanged(previous: string?, stage: string, state: {[string]: any})
	if previous == nil then
		-- First snapshot this session: no celebrations for old progress.
		if stage == "Completed" then
			finish()
		elseif stage == "RebirthReady" then
			pendingBanner = "rebirth"
		end
		return
	end

	-- Becoming eligible is the big milestone whichever stage it follows (it
	-- can skip ahead of the guided steps). Announce it once per session so
	-- dipping under the cash cost and back does not replay the banner.
	if stage == "RebirthReady" then
		pendingUpgradeCelebration = false
		guidance:ClearGuidance()
		if not rebirthBannerShown then pendingBanner = "rebirth" end
		return
	end

	if stage == "Completed" then
		if state.tutorial and state.tutorial.skipped then
			finish()
		else
			pendingBanner = "finale"
		end
		return
	end

	if Config.before(previous, "FreePlay") and stage == "FreePlay" then
		-- The purchase itself is the payoff: confetti from the button pressed.
		pendingUpgradeCelebration = true
		local at = guiCenter(upgradeBuy()) or screenCenter()
		ui:confetti(at, 40, 1)
		Fx.milestone()
		Fx.worldBurst(S.lime.top, 22)
		guidance:ClearGuidance()
		currentKey = "__bought"
		return
	end

	if previous == "SummonRock" then
		celebrateStep("ROCK SUMMONED!", previous)
	elseif previous == "FirstThrow" then
		celebrateStep("FIRST SKIP!", previous)
	elseif previous == "LearnRewards" and stage == "OpenUpgrades" then
		Fx.click()
	end
end

-- ============================================================================
-- Views per stage
-- ============================================================================

local function summonView(state: {[string]: any}): View
	local stage = "SummonRock"
	local touch = device() == "touch"
	if summoning or state.hasPendingSummon then
		return {key = "summon_crack", card = card(stage, "summon_crack", "CRACK IT OPEN!",
			"Smash the geode to see which rock you got!",
			{icon = "summon", inputs = if touch then {TAP, words("TAP TAP TAP!")} else {MOUSE, words("CLICK CLICK CLICK!")}})}
	end
	local distance = flatDistance(wellPosition())
	if summonPromptShown() then
		-- The well's own summon card sits at the top of the view; move ours
		-- below it and let that card be the thing the player looks at.
		return {
			key = "summon_prompt",
			card = card(stage, "summon_prompt", "CLAIM YOUR FREE ROCK", "Your first summon is on the house.",
				{icon = "summon", placement = "bottom",
					inputs = if touch then {TAP, pill("CLAIM FREE ROLL", "lime")}
						else {key(summonKey()), words("OR"), MOUSE, pill("CLAIM FREE ROLL", "lime")}}),
		}
	end
	local near = distance <= 16
	local far = distance > 170
	local viewKey = if near then "summon_near" elseif far then "summon_far" else "summon_go"
	local body, inputs
	if near then
		body = "You're at the well. Your first summon is " .. hl("FREE", "lime") .. "!"
		inputs = if touch then {TAP, pill("SUMMON", "grape")} else {key(summonKey()), words("TO SUMMON")}
	elseif far then
		body = "Every great skip starts with a rock. Teleport to the summoning well, the first one is " .. hl("FREE", "lime") .. "!"
	else
		body = "Every great skip starts with a rock. Follow the stones to the summoning well. The first one is " .. hl("FREE", "lime") .. "!"
	end
	return {
		key = viewKey,
		card = card(stage, viewKey, "SUMMON YOUR FIRST ROCK", body, {icon = "summon", inputs = inputs}),
		apply = function()
			guidance:PointToWorld(wellPart, {label = "FREE SUMMON", nearLabel = "SUMMON HERE", fallback = Places.SummonWell,
				arriveRadius = 16, height = 6, trail = not near, swatch = "grape", icon = "summon"})
			-- SpinButton itself is an invisible trigger pad; glow the pool surface.
			guidance:HighlightWorld(function() return workspace:FindFirstChild("SummoningPool") end,
				{depthMode = Enum.HighlightDepthMode.Occluded, swatch = "grape"})
			if far then
				guidance:PointToGui(plazaButton, {label = "TELEPORT", swatch = "grape"})
			end
		end,
	}
end

local function throwView(state: {[string]: any}): View
	local stage = "FirstThrow"
	if summoning or state.hasPendingSummon then
		return {key = "throw_wait", card = card(stage, "throw_wait", "NEW ROCK!", "Nice pull! Next, let's skip it across the lake.",
			{icon = "throw"})}
	end
	if not inThrowZone() then
		return {
			key = "throw_go",
			card = card(stage, "throw_go", "HEAD TO THE DOCK", "Follow the stones to the wooden " .. hl("throw dock", "lagoon") .. " by the lake.",
				{icon = "throw"}),
			apply = function()
				guidance:PointToWorld(deckTarget, {label = "THROW HERE", arriveRadius = 6, height = 3, trail = true, swatch = "lagoon",
					icon = "throw"})
			end,
		}
	end
	if not ThrowInput.isRockHeld() then
		local touch = device() == "touch"
		return {
			key = "throw_equip",
			card = card(stage, "throw_equip", "GRAB YOUR ROCK", "Hold your new rock to get ready.",
				{icon = "throw", inputs = if touch then {TAP, pill("EQUIP ROCK", "lagoon")} else {key("1"), words("OR CLICK YOUR ROCK")}}),
			apply = function()
				if touch then
					guidance:PointToGui(touchThrowButton, {label = "EQUIP", swatch = "lagoon"})
				else
					guidance:PointToGui(hotbarSlot, {label = "YOUR ROCK", swatch = "lagoon"})
					guidance:HighlightGui(hotbarSlot, {swatch = "lagoon"})
				end
			end,
		}
	end
	if ThrowInput.isCharging() then
		return {
			key = "throw_release",
			card = card(stage, "throw_release", "RELEASE IN THE GREEN!", "Let go while the needle is inside the " .. hl("green zone", "lime") .. ".",
				{icon = "splash", accent = "lime", inputs = {words("LET GO IN THE"), pill("GREEN", "lime")}}),
			apply = function()
				guidance:PointToGui(sweetZone, {label = "RELEASE HERE", swatch = "lime"})
			end,
		}
	end
	local retry = lastThrowSkips == 0 and os.clock() - lastThrowAt < 15
	local body = if retry
		then "Almost! Aim at the water and let go in the " .. hl("green zone", "lime") .. ". Try again!"
		else "Charge up, aim at the water and let go at the right moment."
	local viewKey = if retry then "throw_retry" else "throw_charge"
	return {
		key = viewKey,
		card = card(stage, viewKey, if retry then "SO CLOSE!" else "SKIP IT!", body,
			{icon = "throw", inputs = {pressHint(), words("HOLD"), ARROW, words("RELEASE IN"), pill("GREEN", "lime")}}),
		apply = function()
			guidance:PointToWorld(lakeAim, {label = "AIM HERE", arriveRadius = 0, height = 1, showDistance = false, swatch = "lagoon",
				icon = "splash"})
			if device() == "touch" then
				guidance:PointToGui(touchThrowButton, {label = "HOLD", swatch = "lagoon"})
			end
		end,
	}
end

local function rewardsView(state: {[string]: any}): View
	local stage = "LearnRewards"
	if bankingRewards() then
		return {key = "rewards_wait"}
	end
	if (tonumber(state.totalMoney) or 0) <= 0 then
		return {
			key = "rewards_collect",
			card = card(stage, "rewards_collect", "SKIP THROUGH CASH",
				"Floating " .. hl("Cash", "lime") .. " on the lake pays out when your rock skips through it. Throw again!",
				{icon = "cash"}),
			apply = function()
				if inThrowZone() then
					guidance:PointToWorld(lakeAim, {label = "AIM HERE", arriveRadius = 0, height = 1, showDistance = false,
						swatch = "lime", icon = "cash"})
				end
			end,
		}
	end
	local acknowledged = false
	local function acknowledge()
		if acknowledged then return end
		acknowledged = true
		Fx.click()
		sendAction("rewardsSeen")
	end
	return {
		key = "rewards_explain",
		card = card(stage, "rewards_explain", "NICE SKIP!",
			"Skipping rocks earns you " .. hl("Cash", "lime") .. ". Better skips = more rewards.",
			{icon = "cash", loop = true, timer = Config.RewardsAutoAckSeconds,
				button = {text = "GOT IT", callback = acknowledge}}),
		apply = function()
			guidance:HighlightGui(moneyChip, {padding = 4, swatch = "lime"})
			guidance:PointToGui(moneyChip, {label = "YOUR CASH", swatch = "lime"})
		end,
		onEnter = function()
			task.delay(Config.RewardsAutoAckSeconds, function()
				if currentKey == "rewards_explain" then acknowledge() end
			end)
		end,
	}
end

local function openUpgradesView(): View
	local stage = "OpenUpgrades"
	if panelOpen("upgradesui") then
		sendAction("upgradesOpened")
		return {key = "upgrades_opening"}
	end
	return {
		key = "upgrades_open",
		card = card(stage, "upgrades_open", "GET STRONGER",
			"Spend your " .. hl("Cash", "lime") .. " on upgrades to throw farther.",
			{icon = "upgrade", inputs = {if device() == "touch" then TAP else MOUSE, pill("UPGRADES", "sun")}}),
		apply = function()
			guidance:HighlightGui(upgradesButton, {padding = 4, swatch = "sun"})
			guidance:PointToGui(upgradesButton, {label = "UPGRADES", swatch = "sun"})
		end,
	}
end

local function scrollToUpgrade()
	local cards = find(mainHud(), {"upgradesui", "Surface", "Cards"})
	local target = upgradeCard()
	if cards and cards:IsA("ScrollingFrame") and target and target:IsA("GuiObject") then
		local offset = target.AbsolutePosition.Y - cards.AbsolutePosition.Y + cards.CanvasPosition.Y - 8
		TweenService:Create(cards, TweenInfo.new(.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{CanvasPosition = Vector2.new(0, math.max(0, offset))}):Play()
	end
end

local function buyUpgradeView(state: {[string]: any}): View
	local stage = "BuyUpgrade"
	local upgrade = UpgradeCatalog.get(Config.RecommendedUpgrade)
	local level = if type(state.upgrades) == "table" and type(state.upgrades[Config.RecommendedUpgrade]) == "number"
		then state.upgrades[Config.RecommendedUpgrade] else 0
	local cost = if upgrade then UpgradeCatalog.costAt(upgrade, level) else 0
	local have = cash()
	local affordable = have >= cost
	local name = if upgrade then upgrade.name else "Throw Power"

	if panelOpen("upgradesui") then
		local viewKey = if affordable then "buy_menu" else "buy_menu_short"
		return {
			key = viewKey,
			apply = function()
				guidance:HighlightGui(upgradeCard, {padding = 5, spotlight = true, swatch = "sun"})
				-- From the left, so the label sits inside the highlighted card
				-- instead of covering the next upgrade's button.
				if affordable then
					guidance:PointToGui(upgradeBuy, {label = "BUY IT!", swatch = "lime", side = "left"})
				else
					guidance:PointToGui(upgradeBuy, {label = "Need $" .. compact(cost - have) .. " more", swatch = "sun", side = "left"})
				end
			end,
			onEnter = function()
				task.delay(.3, scrollToUpgrade)
			end,
		}
	end
	if affordable then
		return {
			key = "buy_reopen",
			card = card(stage, "buy_reopen", "BUY AN UPGRADE",
				"You can afford " .. hl(name) .. "! Open " .. hl("Upgrades") .. " to buy it.",
				{icon = "upgrade", inputs = {if device() == "touch" then TAP else MOUSE, pill("UPGRADES", "sun")}}),
			apply = function()
				guidance:HighlightGui(upgradesButton, {padding = 4, swatch = "sun"})
				guidance:PointToGui(upgradesButton, {label = "UPGRADES", swatch = "sun"})
			end,
		}
	end
	return {
		key = "buy_earn",
		card = card(stage, "buy_earn", "EARN A LITTLE MORE",
			hl(name) .. " costs " .. hl("$" .. compact(cost), "lime") .. ". Skip again to earn " .. hl("$" .. compact(cost - have), "lime") .. " more!",
			{icon = "cash"}),
		apply = function()
			if inThrowZone() then
				guidance:PointToWorld(lakeAim, {label = "AIM HERE", arriveRadius = 0, height = 1, showDistance = false,
					swatch = "lime", icon = "cash"})
			else
				guidance:PointToWorld(deckTarget, {label = "THROW HERE", arriveRadius = 6, height = 3, trail = true,
					swatch = "lagoon", icon = "throw"})
			end
		end,
	}
end

local function rebirthChips(): {TutorialUI.Chip}
	return {
		{label = "RESETS", value = "Cash, upgrades, strength", swatch = "coral"},
		{label = "KEEPS", value = "Rocks, pets, abilities", swatch = "lagoon"},
		{label = "GAINS", value = string.format("+%d%% Cash forever, higher cap", math.floor(ProgressionConfig.RebirthMoneyBonus * 100 + .5)),
			swatch = "lime"},
	}
end

local function rebirthView(): View
 if player:GetAttribute("NoobDialogueOpen")==true then return {key="awakening_review"} end
 local near=flatDistance(noobPosition())<=10
 return {
  key=near and "awakening_near" or "awakening_go",
  card=card("RebirthReady", "awakening", "THE STONE IS CALLING",
   near and "Touch the "..hl("Magical Rock", "lagoon").." to review your awakening."
    or "A quiet light waits at the shrine above the stairs. Find the "..hl("Magical Rock", "lagoon")..".",
   {icon="rebirth", inputs=near and {device()=="touch" and TAP or key("E"),words("TO APPROACH")} or nil}),
  apply=function()
   guidance:PointToWorld(noobModel,{label="MAGICAL ROCK",nearLabel="APPROACH",fallback=Places.Noob,
    arriveRadius=10,height=2,trail=not near,swatch="lagoon",icon="rebirth"})
  end,
 }
end

local function buildView(stage: string, state: {[string]: any}): View
	if not Config.isGuided(stage) then
		return {key = "idle"}
	end
	if inFlight() then
		return {key = "flight"}
	end
	if stage == "SummonRock" then return summonView(state) end
	if stage == "FirstThrow" then return throwView(state) end
	if stage == "LearnRewards" then return rewardsView(state) end
	if stage == "OpenUpgrades" then return openUpgradesView() end
	if stage == "BuyUpgrade" then return buyUpgradeView(state) end
	if stage == "RebirthReady" then return rebirthView() end
	return {key = "idle"}
end

-- ============================================================================
-- Main loop
-- ============================================================================

local ABILITY_SWATCHES = {"lagoon", "grape", "coral", "sun"}

local function abilityChips(): {TutorialUI.Chip}
	local chips = {}
	for _, ability in AbilityCatalog.Abilities do
		table.insert(chips, {label = string.upper(ability.name), value = "$" .. compact(ability.price) .. " in the Shop",
			swatch = ABILITY_SWATCHES[(#chips % #ABILITY_SWATCHES) + 1]})
	end
	return chips
end

local function step()
	if finished then return end
 if player:GetAttribute("RebirthCutscene")==true or player:GetAttribute("RebirthCinematic")==true then
  guidance:ClearGuidance();ui:hideObjective();return
 end
	local state = ProfileStore.get()
	local tutorial = state.tutorial
	if not ProfileStore.hasLoaded() or state.loaded ~= true or type(tutorial) ~= "table" or type(tutorial.stage) ~= "string" then
		present({key = "loading"})
		return
	end
	local stage: string = tutorial.stage
	if stage ~= lastStage then
		local previous = lastStage
		lastStage = stage
		stageChanged(previous, stage, state)
		if finished then return end
	end

	-- Opening Upgrades early still counts.
	if Config.before(stage, "FreePlay") and panelOpen("upgradesui")
		and not (type(tutorial.flags) == "table" and tutorial.flags.upgradesOpened) then
		sendAction("upgradesOpened")
	end

	local now = os.clock()
	if summoning and now - summoningSince > 90 and not state.hasPendingSummon then
		summoning = false -- never trust a lost "Closed" event forever
	end

	if finishAt and now >= finishAt then
		finish()
		return
	end

	if pendingBanner == "finale" then
		pendingBanner = nil
		guidance:ClearGuidance()
		ui:hideObjective()
		currentKey = "__finale"
		ui:banner("FIRST REBIRTH!", "You're on your own now. Skip farther, unlock " .. glow("abilities", "sun") .. " and climb the "
			.. glow("leaderboard", "sun") .. "!", "sun", 4.4)
		Fx.milestone()
		-- Cinematic already supplied the milestone camera move.
		Fx.worldBurst(S.sun.top, 34)
		ui:confetti(screenCenter() - Vector2.new(0, 60), 70, 1.25)
		task.delay(.5, function() ui:confetti(screenCenter() + Vector2.new(-260, 0), 30, .9) end)
		task.delay(.8, function() ui:confetti(screenCenter() + Vector2.new(260, 0), 30, .9) end)
		holdUntil = now + 4.8
		finishAt = now + 4.8
		return
	end

	if pendingBanner == "rebirth" and stage == "RebirthReady" and not inFlight() and not bankingRewards() then
		pendingBanner = nil
		rebirthBannerShown = true
		guidance:ClearGuidance()
		ui:hideObjective()
		currentKey = "__banner"
		ui:banner("THE STONE IS CALLING", "Your next awakening waits at the " .. glow("Magical Rock", "lagoon") .. ".",
			"grape", 3.4)
		Fx.milestone()
		-- Let the quiet name call lead this moment.
		Fx.worldBurst(S.grape.top, 30)
		ui:confetti(screenCenter() - Vector2.new(0, 60), 60, 1.1)
		holdUntil = now + 3.5
		return
	elseif pendingBanner == "rebirth" and stage ~= "RebirthReady" then
		pendingBanner = nil
	end

	if now < holdUntil then return end

	if pendingUpgradeCelebration then
		if anyMenuOpen() or inFlight() then
			if currentKey ~= "__bought" then present({key = "__bought"}) end
			return
		end
		pendingUpgradeCelebration = false
		present({
			key = "upgrade_done",
			card = card("BuyUpgrade", "upgrade_done", "UPGRADE COMPLETE!",
				"Each upgrade makes your throws stronger. Keep going to unlock " .. hl("abilities", "grape") .. "!",
				{icon = "upgrade", accent = "lime", chips = abilityChips(), timer = Config.UpgradeCelebrationSeconds,
					skippable = false}),
		})
		Fx.step()
		holdUntil = now + Config.UpgradeCelebrationSeconds
		return
	end

	present(buildView(stage, state))
end

-- ============================================================================
-- Signals
-- ============================================================================

Remotes.ThrowEnded.OnClientEvent:Connect(function(result)
	if type(result) == "table" and type(result.skips) == "number" then
		lastThrowSkips = result.skips
		lastThrowAt = os.clock()
	end
end)

task.spawn(function()
	local feedback = ReplicatedStorage:WaitForChild("SummonFeedback", 60)
	if not feedback or not feedback:IsA("RemoteEvent") then return end
	feedback.OnClientEvent:Connect(function(kind)
		if kind == "Rolling" then
			summoning = true
			summoningSince = os.clock()
		elseif kind == "Closed" or kind == "Stored" then
			summoning = false
		end
	end)
end)

ProfileStore.onChanged(function()
	task.defer(step)
end)
player:GetAttributeChangedSignal("RockInFlight"):Connect(function() task.defer(step) end)
player:GetAttributeChangedSignal("NoobDialogueOpen"):Connect(function() task.defer(step) end)

local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	if finished then return end
	accumulator += dt
	if accumulator < .12 then return end
	accumulator = 0
	local ok, err = pcall(step)
	if not ok then warn("[TutorialController] " .. tostring(err)) end
end)

