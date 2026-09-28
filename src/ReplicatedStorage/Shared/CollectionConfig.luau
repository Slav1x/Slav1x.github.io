--!strict
-- Central balance/collection configuration for simulator HUD progression.
local CollectionConfig = {}

CollectionConfig.FriendBoost = {
	PerFriend = 0.05,
	Maximum = 0.25,
}

CollectionConfig.RockMilestones = {
	{Key = "rocks_6", Required = 6, CashBonus = 0.20},
}

CollectionConfig.Variants = {"STANDARD", "ENCHANTED"}
CollectionConfig.SummonTeleportCooldown = 1.5
CollectionConfig.SummonArrivalOffset = Vector3.new(0, 4, 0)

function CollectionConfig.friendBonus(friendCount: number): number
	return math.min(math.max(friendCount, 0) * CollectionConfig.FriendBoost.PerFriend, CollectionConfig.FriendBoost.Maximum)
end

function CollectionConfig.rockBonus(discoveredCount: number): number
	local bonus = 0
	for _, milestone in CollectionConfig.RockMilestones do
		if discoveredCount >= milestone.Required then
			bonus += milestone.CashBonus
		end
	end
	return bonus
end

function CollectionConfig.nextRockMilestone(discoveredCount: number)
	for _, milestone in CollectionConfig.RockMilestones do
		if discoveredCount < milestone.Required then
			return milestone
		end
	end
	return nil
end

return CollectionConfig
