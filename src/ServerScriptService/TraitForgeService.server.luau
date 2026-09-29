--!strict
-- Server owns the result, shard payment and per-copy identity.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Traits = require(Shared:WaitForChild("TraitCatalog"))
local Rocks = require(Shared:WaitForChild("RockCatalog"))
local Profiles = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Profiles"))
local forge = workspace:WaitForChild("TraitForge")
local crystal = forge:WaitForChild("TraitCrystal")

local rng = Random.new()
local lastRoll: {[Player]: number} = {}
local confirmations: {[Player]: {token: string, copyId: string, traitId: string, expires: number}} = {}
local MAX_DISTANCE = 13
-- Below the fastest supported reveal (.75s); retain a server-side spam guard.
local COOLDOWN = .65

local function reject(player: Player, message: string, requestId: any)
	Remotes.TraitRollResult:FireClient(player, {ok = false, message = message, requestId = requestId})
end

Remotes.TraitRollRequest.OnServerEvent:Connect(function(player: Player, rockId: any, selectedCopy: any, requestId: any, confirmationToken: any)
	local profile = Profiles.get(player)
	if not profile.loaded then
		reject(player, "Your rocks are still loading.", requestId)
		return
	end
	if typeof(rockId) ~= "string" or not Rocks.exists(rockId) or not profile.rocksOwned[rockId] then
		reject(player, "Choose a rock you own first.", requestId)
		return
	end
	if typeof(selectedCopy) ~= "string" then
		reject(player, "Select a rock copy from your inventory.", requestId)
		return
	end
	if selectedCopy == "untraited" then
		if Profiles.untraitedCount(profile, rockId) < 1 then
			reject(player, "That untraited rock is no longer available.", requestId)
			return
		end
	else
		local copy = profile.traitedRocks[selectedCopy]
		if not copy or copy.rockId ~= rockId then
			reject(player, "That rock copy is no longer available.", requestId)
			return
		end
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0
		or (root.Position - crystal.Position).Magnitude > MAX_DISTANCE then
		reject(player, "Move closer to the Trait Forge.", requestId)
		return
	end
	if (profile.traitShards or 0) < Traits.RollCost then
		reject(player, "You need "..Traits.RollCost.." Trait Shards. Find them while skipping or completing areas.", requestId)
		return
	end
	-- Always inspect the authoritative copy; client profile updates may arrive late.
	local existing = profile.traitedRocks[selectedCopy]
	local previousTrait = existing and Traits.get(existing.traitId)
	local now = os.clock()
	if previousTrait and previousTrait.rarity == "Legendary" then
		local pending = confirmations[player]
		local valid = typeof(confirmationToken) == "string" and pending ~= nil
			and pending.token == confirmationToken and pending.copyId == selectedCopy
			and pending.traitId == existing.traitId and now < pending.expires
		if not valid then
			local token = HttpService:GenerateGUID(false)
			confirmations[player] = {token=token, copyId=selectedCopy, traitId=existing.traitId, expires=now+30}
			Remotes.TraitRollResult:FireClient(player, {
				ok=false, requiresConfirmation=true, confirmationToken=token,
				rockId=rockId, instanceId=selectedCopy, traitId=existing.traitId, requestId=requestId,
			})
			return
		end
	end
	if now - (lastRoll[player] or -math.huge) < COOLDOWN then
		reject(player, "Wait for this spin to finish.", requestId)
		return
	end
	confirmations[player] = nil -- A confirmation can authorize only this one roll.
	lastRoll[player] = now

 local processingAt=os.clock()
 debug.profilebegin("TraitForge.AuthoritativeRoll")
 local result = Traits.roll(rng, workspace:GetAttribute("GlobalTraitLuckMultiplier") or 1)
	-- No yields between payment and the authoritative copy mutation.
	profile.traitShards -= Traits.RollCost
	local instanceId = selectedCopy
	if selectedCopy == "untraited" then
		instanceId = HttpService:GenerateGUID(false)
		profile.traitedRocks[instanceId] = {rockId = rockId, traitId = result.id}
		if profile.rockEquipped == rockId and profile.rockEquippedInstance == nil then
			profile.rockEquippedInstance = instanceId
		end
	else
		profile.traitedRocks[instanceId].traitId = result.id
	end
 debug.profileend()
 forge:SetAttribute("LastRollMutationMs",(os.clock()-processingAt)*1000)
 local syncAt=os.clock()
 debug.profilebegin("TraitForge.ProfileSync")
 Profiles.fireChanged(player)
 debug.profileend()
 forge:SetAttribute("LastRollProfileSyncMs",(os.clock()-syncAt)*1000)
	Remotes.TraitRollResult:FireClient(player, {ok = true, rockId = rockId, instanceId = instanceId, traitId = result.id, requestId = requestId})
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastRoll[player] = nil
	confirmations[player] = nil
end)
