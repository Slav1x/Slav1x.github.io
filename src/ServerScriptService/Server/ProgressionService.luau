--!strict
-- Records server-confirmed throws and resets only the current progression journey.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionConfig = require(Shared:WaitForChild("ProgressionConfig"))
local RockCatalog = require(Shared:WaitForChild("RockCatalog"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Profiles = require(script.Parent:WaitForChild("Profiles"))

local ProgressionService = {}
local Persistence=require(script.Parent.Persistence)

-- ============================================================================
-- Throw results
-- ============================================================================

-- Bank only the increase in the server-calculated reward. The same throw
-- uses its launch strength for pacing, so later skips cannot compound it.
local function awardThrowSpin(player: Player, distance: number, skips: number, isPerfect: boolean, context: {[string]: any}?, position: Vector3?): number
	if not context then return 0 end
	local profile = Profiles.get(player)
	if not profile.loaded or not ProgressionConfig.isFinite(distance) or not ProgressionConfig.isFinite(skips) then return 0 end
	local strength = math.min(ProgressionConfig.normalizeSpinStrength(profile.spinStrength), ProgressionConfig.normalizeSpinStrength(context.spinStrengthAtLaunch))
	local rebirths = profile.rebirths
	if ProgressionConfig.isFinite(context.rebirthsAtLaunch) then
		rebirths = math.min(rebirths, math.max(0, context.rebirthsAtLaunch))
	end
	local earned = ProgressionConfig.throwSpinGain(strength, rebirths, math.clamp(distance, 0, ProgressionConfig.MaxRewardDistance), math.clamp(math.floor(skips), 0, ProgressionConfig.MaxRewardSkips), isPerfect)
	local alreadyRewarded = context.spinStrengthRewarded or 0
	local increase = math.max(0, earned - alreadyRewarded)
	context.spinStrengthRewarded = math.max(alreadyRewarded, earned)
	local gained = Profiles.addSpinStrength(player, increase)
	context.spinStrengthGain = (context.spinStrengthGain or 0) + gained
	if gained > 0 then
		Profiles.fireChanged(player)
		Remotes.RewardPopup:FireClient(player, "spin", gained, position)
	end
	return gained
end

function ProgressionService.recordSkip(player: Player, position: Vector3, distance: number, skips: number, isPerfect: boolean, context: {[string]: any})
	awardThrowSpin(player, distance, skips, isPerfect, context, position)
end

--[[
	Called when a throw finishes. Returns whether it set a personal best, so
	the caller can tell the client to celebrate.
]]
function ProgressionService.recordThrow(
	player: Player,
	distance: number,
	skips: number,
	isPerfect: boolean,
 context: {[string]: any}?
): boolean
	local profile = Profiles.get(player)
 if not profile.loaded or not ProgressionConfig.isFinite(distance) or not ProgressionConfig.isFinite(skips) then return false end
 distance=math.clamp(distance,0,ProgressionConfig.MaxRewardDistance)
 skips=math.clamp(math.floor(skips),0,ProgressionConfig.MaxRewardSkips)
 -- Context is supplied only by ThrowService, never by a remote.
 -- Settle distance traveled after the last skip; previous skip rewards are
 -- tracked in context and cannot be paid again.
 awardThrowSpin(player, distance, skips, isPerfect, context, context and context.rewardPosition)
	profile.totalThrows += 1
 if skips>=1 and distance>=20 then
  profile.cycleBestDistance=math.max(profile.cycleBestDistance or 0,distance)
 end
	if profile.starterRockClaimed and not profile.tutorialComplete then profile.tutorialComplete=true end
	profile.totalSkips += skips

	local isRecord = distance > profile.bestDistance
	if isRecord then
		profile.bestDistance = distance
	end

	-- Area discovery is recorded live by ZoneProgression at world boundaries.

	local xp = distance * ProgressionConfig.XpPerStud
		+ skips * ProgressionConfig.XpPerSkip
		+ (if isPerfect then ProgressionConfig.XpPerfectBonus else 0)

	local before, after = Profiles.addXp(player, xp)
	if after > before then
		Remotes.LevelUp:FireClient(player, after)
	end

	Profiles.fireChanged(player)
	return isRecord
end

-- ============================================================================
-- Rebirth
-- ============================================================================

function ProgressionService.rebirthRequirements(player: Player): (number, number)
	local rebirths = Profiles.get(player).rebirths
	return ProgressionConfig.rebirthCost(rebirths), ProgressionConfig.rebirthDistance(rebirths)
end

local function completeRebirth(player: Player)
	local profile = Profiles.get(player)
	if not profile.loaded then
		Remotes.Toast:FireClient(player, "Still loading your save", "bad")
		return
	end

 if Persistence.isWriting(player) then
  Remotes.Toast:FireClient(player,"Please wait for your save to finish","bad") return
 end
 if player:GetAttribute("RockInFlight")==true or profile.pendingSummon then
  Remotes.Toast:FireClient(player,"Finish your throw or summon before rebirthing","bad") return
 end
 if profile.rebirths>=ProgressionConfig.MaxRebirths then return end
	local cost=ProgressionConfig.rebirthCost(profile.rebirths)
 local money=Profiles.moneyValue(player)
 local eligible,reason=ProgressionConfig.canRebirth(profile,money and money.Value or 0)
 if not eligible then Remotes.Toast:FireClient(player,reason,"bad") return end
 if not Profiles.trySpend(player,cost) then return false, "Insufficient cash" end

 -- Rocks, copies, enchanted variants, traits, pets, shards, mastery, cosmetics,
 -- discoveries, area first-completion rewards and abilities are permanent.
profile.upgrades = {}
 profile.cycleBestDistance=0
 profile.cycleCompletedAreas={}
	profile.rebirths += 1
 profile.spinStrength=ProgressionConfig.StartingSpinStrength
 player:SetAttribute("Rebirths",profile.rebirths)
 player:SetAttribute("RebirthReady",false)

	local money = Profiles.moneyValue(player)
	if money then
		money.Value = 0
	end

	Profiles.fireChanged(player)
	task.defer(Persistence.saveNow,player)
	Remotes.Rebirthed:FireAllClients(player.UserId, profile.rebirths)
 return true, profile.rebirths
end

-- ============================================================================
-- Wiring
-- ============================================================================

function ProgressionService.start()
 require(script.Parent.AwakeningService).start(completeRebirth)

	-- Surface rebirth count on the leaderboard next to money.
	local function onPlayerAdded(player: Player)
		task.spawn(function()
			local stats = player:WaitForChild("leaderstats", 10)
			if not stats then
				return
			end
			if not stats:FindFirstChild("Rebirths") then
				local value = Instance.new("IntValue")
				value.Name = "Rebirths"
				value.Value = Profiles.get(player).rebirths
				value.Parent = stats
			end
		end)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	-- Keep the leaderboard value in step with the profile.
	Profiles.onChanged(function(player)
  local profile=Profiles.get(player)
  local cash=Profiles.moneyValue(player)
  local ready=ProgressionConfig.canRebirth(profile,cash and cash.Value or 0)
  player:SetAttribute("RebirthReady",ready)
  player:SetAttribute("Rebirths",profile.rebirths)
		local stats = player:FindFirstChild("leaderstats")
		local value = stats and stats:FindFirstChild("Rebirths")
		if value and value:IsA("IntValue") then
			value.Value = Profiles.get(player).rebirths
		end
	end)
end

-- Server-only entry point used by integration checks and future shrine interactions.
ProgressionService.performRebirth=function(player, receipt)
 return require(script.Parent.AwakeningService).begin(player, receipt)
end

return ProgressionService



