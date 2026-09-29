--!strict
--[[
	MonetizationService (server)

	Pass ownership and product receipts.

	Ownership is checked once on join and refreshed when a purchase prompt
	closes, then cached on the profile -- UserOwnsGamePassAsync is a web call
	and must not be in the path of anything per-throw.

	ProcessReceipt is written to be idempotent-safe: it only returns
	PurchaseGranted after the grant has actually been applied, so a receipt
	that fails mid-way is retried by Roblox rather than silently swallowed.
	That is the difference between a player losing Robux and not.

	While every id in MonetizationConfig is 0, passes count as owned so the
	perks can be exercised, and no product can be bought.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared:WaitForChild("MonetizationConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Profiles = require(script.Parent:WaitForChild("Profiles"))

local MonetizationService = {}

local function ownsPass(player: Player, pass: MonetizationConfig.Pass): boolean
	if MonetizationConfig.isUngated(pass) then
		return true
	end
	local ok, owned = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
	end)
	if not ok then
		warn("[Monetization] pass check failed for " .. pass.key .. ": " .. tostring(owned))
		return false
	end
	return owned == true
end

local function refreshPasses(player: Player)
	local profile = Profiles.get(player)
	local owned: {[string]: boolean} = {}
	for _, pass in MonetizationConfig.Passes do
		owned[pass.key] = ownsPass(player, pass)
	end
	;(profile :: any).passes = owned
	Profiles.fireChanged(player)
end

function MonetizationService.hasAutoThrow(player: Player): boolean
	local passes = (Profiles.get(player) :: any).passes
	if typeof(passes) ~= "table" then
		return false
	end
	for _, pass in MonetizationConfig.Passes do
		if pass.grantsAutoThrow and passes[pass.key] then
			return true
		end
	end
	return false
end

-- ============================================================================
-- Purchase entry points
-- ============================================================================

local function onPromptPass(player: Player, key: unknown)
	if typeof(key) ~= "string" then
		return
	end
	local pass = MonetizationConfig.pass(key)
	if not pass then
		return
	end
	if pass.id == 0 then
		Remotes.Toast:FireClient(player, pass.name .. " is not set up yet", "bad")
		return
	end
	local ok, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, pass.id)
	end)
	if not ok then
		warn("[Monetization] prompt failed: " .. tostring(err))
	end
end

local function onPromptProduct(player: Player, key: unknown)
	if typeof(key) ~= "string" then
		return
	end
	for _, product in MonetizationConfig.Products do
		if product.key == key then
			if product.id == 0 then
				Remotes.Toast:FireClient(player, product.name .. " is not set up yet", "bad")
				return
			end
			pcall(function()
				MarketplaceService:PromptProductPurchase(player, product.id)
			end)
			return
		end
	end
end

-- ============================================================================
-- Receipts
-- ============================================================================

local function processReceipt(info: {[string]: any}): Enum.ProductPurchaseDecision
	local product = MonetizationConfig.productFor(info.ProductId)
	if not product then
		-- Unknown product: do NOT grant, and do NOT consume the receipt --
		-- another script (or a later version of this one) may own it.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		-- They left before it resolved. Roblox will retry when they return.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local profile = Profiles.get(player)
	if not profile.loaded then
		-- Granting into an unloaded profile risks the grant being wiped by
		-- the load that is still in flight. Let Roblox retry.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, err = pcall(function()
		Profiles.addMoney(player, product.grantMoney)
	end)
	if not ok then
		warn("[Monetization] grant failed: " .. tostring(err))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	Profiles.fireChanged(player)
	Remotes.Toast:FireClient(player, product.name .. " -- thank you!", "epic")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ============================================================================
-- Wiring
-- ============================================================================

function MonetizationService.start()
	Remotes.RequestPromptPass.OnServerEvent:Connect(onPromptPass)
	Remotes.RequestPromptProduct.OnServerEvent:Connect(onPromptProduct)

	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _, wasPurchased)
		if wasPurchased then
			refreshPasses(player)
		end
	end)

	local function onPlayerAdded(player: Player)
		task.spawn(function()
			-- Wait for leaderstats so the profile-changed push carries a real
			-- balance alongside the pass flags.
			for _ = 1, 120 do
				if player:FindFirstChild("leaderstats") and Profiles.get(player).loaded then
					break
				end
				task.wait(0.1)
			end
			if player.Parent and Profiles.get(player).loaded then
				refreshPasses(player)
			end
		end)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return MonetizationService
