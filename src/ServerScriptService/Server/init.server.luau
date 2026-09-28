--!strict
--[[
	Server entry point.

	Remotes must be required first: requiring it on the server is what creates
	the RemoteEvent folder, and every client blocks on WaitForChild for it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
require(Shared:WaitForChild("Remotes"))

local Profiles = require(script:WaitForChild("Profiles"))
local Persistence = require(script:WaitForChild("Persistence"))
local WorldSetup = require(script:WaitForChild("WorldSetup"))
local ThrowService = require(script:WaitForChild("ThrowService"))
local MoneyService = require(script:WaitForChild("MoneyService"))
local ShopService = require(script:WaitForChild("ShopService"))
local TrainingService = require(script:WaitForChild("TrainingService"))
local ProgressionService = require(script:WaitForChild("ProgressionService"))
local QuestService = require(script:WaitForChild("QuestService"))
local LeaderboardService = require(script:WaitForChild("LeaderboardService"))
local MonetizationService = require(script:WaitForChild("MonetizationService"))
local SimulatorProgressionService = require(script:WaitForChild("SimulatorProgressionService"))
local TutorialService = require(script:WaitForChild("TutorialService"))

-- Order matters. WorldSetup builds the lake that MoneyService raycasts
-- against, and MoneyService.start() does real work up front (thousands of
-- probe raycasts, then hundreds of placements), so the cheap remote wiring
-- goes first -- otherwise a slow scan delays the shop accepting purchases.
WorldSetup.start()
ThrowService.start()
TrainingService.start()
ShopService.start()
-- Before Persistence, so the tutorial hook sees every freshly loaded profile.
TutorialService.start()
ProgressionService.start()
QuestService.start()
LeaderboardService.start()
-- Persistence connects PlayerAdded before MoneyService's slow scan so a
-- rejoining player's save starts loading immediately.
Persistence.start()
MonetizationService.start()
SimulatorProgressionService.start()
MoneyService.start()

-- Injected rather than required directly, so ThrowService has no dependency
-- on the shop and still works if it is removed.
ThrowService.setRockProvider(function(player)
	return ShopService.getEquippedRock(player)
end)
ThrowService.setModifierProvider(function(player)
	return Profiles.modifiers(player)
end)

-- Pay spin strength as each server-confirmed skip lands. Distance is the
-- furthest displacement measured by ThrowService, never client input.
ThrowService.onSkip(function(player, position, skips, distance, isPerfect, context)
	ProgressionService.recordSkip(player, position, distance, skips, isPerfect, context)
end)

-- XP, lifetime stats and personal bests.
ThrowService.onThrowEnded(function(player, distance, skips, isPerfect, isSonicBoom, context)
	local isRecord = ProgressionService.recordThrow(player, distance, skips, isPerfect, context)

	QuestService.report(player, "throws", 1)
	QuestService.report(player, "distance", distance)
	QuestService.report(player, "skips_single", skips)
	if isPerfect then
		QuestService.report(player, "perfects", 1)
	end
	if isSonicBoom then
		QuestService.report(player, "booms", 1)
	end

	return isRecord
end)

MoneyService.onCollected(function(player, total, _, goldCount)
	QuestService.report(player, "money", total)
	if goldCount > 0 then
		QuestService.report(player, "gold", goldCount)
	end
end)

-- Money reacts through a hook, so ThrowService never has to know pickups
-- exist. Wired to the per-step signal rather than to skips: with the bounce
-- arcs retuned, skips land ~140 studs apart, so skip-only collection sampled
-- a few isolated circles and claimed almost nothing.
ThrowService.onFlightStep(function(player, position, moneyMul, magnetBonus, luckBonus)
	MoneyService.collectAt(player, position, moneyMul, magnetBonus, luckBonus or 0)
end)
