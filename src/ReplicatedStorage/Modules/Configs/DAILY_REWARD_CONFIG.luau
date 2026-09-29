local DAILY_REWARD_CONFIG  = {
	
	-- This key will store all players streak data (once you input your own don't change it.)
	DATASTORE_KEY = "RockGame_DailyRewards_v1", 	
	
	-- Total number of days for redeemable rewards (default = 7)
	MAX_DAYS = 7, 												
	
	-- Total number of seconds in-between when each daily reward is redeemable (86400 = 1 Day)
	COOLDOWN_SECONDS = 86400, 						
	
	-- if true, will reset the streak if player does not redeem reward in time for the next day
	RESET_STREAK_IF_MISSED = true,
	
	-- Reward GUI colors (CLAIMED = Green, SELECTED = White, UNCLAIMED = Dark Grey)
	STATE_COLORS = {								
		
		CLAIMED = Color3.fromRGB(87, 255, 78),
		SELECTED = Color3.fromRGB(255, 255, 255),
		UNCLAIMED = Color3.fromRGB(50, 50, 50),
		
		
	},
	
	-- Reward GUI colors (CLAIMED = Bold, SELECTED = ExtraBold, UNCLAIMED = Regular)
	STATE_FONTS = {									

		CLAIMED = Font.fromName("BuilderSans", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
		SELECTED = Font.fromName("BuilderSans", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal),
		UNCLAIMED = Font.fromName("BuilderSans", Enum.FontWeight.Regular, Enum.FontStyle.Normal),


	},
	
	-- What each day will show on the frames
	-- Timed rewards stay useful at every stage of progression.
	DAY_PRESETS = {
		["Day 1"] = {reward_text = "2x CASH • 15 MIN", boosts = {cash = 900}, icon = "cash"},
		["Day 2"] = {reward_text = "2x SPIN • 30 MIN", boosts = {spin = 1800}, icon = "spin"},
		["Day 3"] = {reward_text = "2x SUMMON LUCK • 30 MIN", boosts = {summon = 1800}, icon = "summon"},
		["Day 4"] = {reward_text = "2x CASH • 45 MIN", boosts = {cash = 2700}, icon = "cash"},
		["Day 5"] = {reward_text = "2x SPIN • 45 MIN", boosts = {spin = 2700}, icon = "spin"},
		["Day 6"] = {reward_text = "2x SUMMON LUCK • 45 MIN", boosts = {summon = 2700}, icon = "summon"},
		["Day 7"] = {reward_text = "ALL 3 BOOSTS • 60 MIN", card_text = "3 BOOSTS • 1h", boosts = {cash = 3600, spin = 3600, summon = 3600}, icon = "all"},
	}
	
	
}

return DAILY_REWARD_CONFIG 
