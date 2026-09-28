-- services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- config module 
local DAILY_REWARD_CONFIG = require(ReplicatedStorage:FindFirstChild("DAILY_REWARD_CONFIG", true))

-- economy
local Profiles = require(ServerScriptService.Server.Profiles)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

-- remotes
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local functionsFolder = remotesFolder:WaitForChild("Functions")
local promptDailyRewardFunction = functionsFolder:WaitForChild("PromptDailyReward")

-- modules
local DailyReward = require(script.DailyReward)

-- values
local AUTOSAVE_DELAY = 60

-- functions
function GetRewardStatus(player, playerRewardData)
	-- Cheat Sheet: (0 = IGNORE, 1 = REDEEM, 2 = RESET)
	if playerRewardData.NextDailyRewardTime == 0 then
		-- player has no data (reset and start them off at day 1)
		print("Daily rewards started for: ", player.Name)
		return 2
	else	
		if os.time() > playerRewardData.NextDailyRewardTime then			
			if playerRewardData.RewardRedeemable and DAILY_REWARD_CONFIG.RESET_STREAK_IF_MISSED then
				-- player is outside the redeem period (reset)
				print("Daily reward redeem period expired: ", player.Name)
				return 2 
			else		
				-- player has redeemed reward already, and cooldown has expired and we increment to the next day		
				if playerRewardData.CurrentDay < DAILY_REWARD_CONFIG.MAX_DAYS then
					DailyReward.AddToPlayerData(player, "CurrentDay", 1)
				else
					DailyReward.SetPlayerData(player, "CurrentDay", 1)
				end
				DailyReward.SetPlayerData(player, "NextDailyRewardTime", os.time()+DAILY_REWARD_CONFIG.COOLDOWN_SECONDS)	
				DailyReward.SetPlayerData(player, "RewardRedeemable", true)
				print("Next day's reward unlocked: ", player.Name)
				return 1
			end
		else	
			if playerRewardData.RewardRedeemable then
				-- player is within redeem period and yet to do so (redeemable)
				print("Reward is still eligible to redeem: ", player.Name)
				return 1
			end
		end	
	end
	
	-- player has no reward to claim yet
	print("Not eligible to claim any rewards yet: ", player.Name)
	return 0 
end

local function scheduleBoostRefresh(player, kind, expiry)
 task.delay(math.max(0, expiry - os.time()) + .1, function()
  if player.Parent and Profiles.get(player).dailyBoostExpires[kind] == expiry then
   Profiles.fireChanged(player)
  end
 end)
end

function GivePlayerReward(player, dayID)
	local preset = DAILY_REWARD_CONFIG.DAY_PRESETS["Day "..tostring(dayID)]
	if not preset then
		warn("[DailyRewardController] No DAY_PRESETS entry for day "..tostring(dayID))
		return
	end

	local profile = Profiles.get(player)
 local now = os.time()
 for _,kind in {"cash","spin","summon"} do
  local duration = preset.boosts and preset.boosts[kind]
  if type(duration) == "number" and duration > 0 and duration <= 3600 then
   local expiry = math.max(now, profile.dailyBoostExpires[kind] or 0) + duration
   profile.dailyBoostExpires[kind] = expiry
   scheduleBoostRefresh(player, kind, expiry)
  end
 end
 Profiles.fireChanged(player)
 Remotes.Toast:FireClient(player, "Daily Reward: "..preset.reward_text, "good")
end

-- Reuses the existing daily datastore/schema. Claims now have an explicit server endpoint.
local ready={}
local busy={}
local function add(player)
 local data,session=DailyReward.AddPlayer(player)
 if session.DataStatus~=1 or not player.Parent then return end
 local status=GetRewardStatus(player,data)
 if status==2 then
  DailyReward.SetPlayerData(player,"CurrentDay",1)
  DailyReward.SetPlayerData(player,"NextDailyRewardTime",os.time()+DAILY_REWARD_CONFIG.COOLDOWN_SECONDS)
  DailyReward.SetPlayerData(player,"CurrentDailyRewardStreak",0)
  DailyReward.SetPlayerData(player,"RewardRedeemable",true)
 end
 ready[player]=true
 task.spawn(function()
  for _=1,100 do
   if not player.Parent then return end
   if Profiles.get(player).loaded then break end
   task.wait(.1)
  end
  if not Profiles.get(player).loaded then return end
  for kind,expiry in Profiles.get(player).dailyBoostExpires do
   if expiry > os.time() then scheduleBoostRefresh(player,kind,expiry) end
  end
 end)
end
Players.PlayerAdded:Connect(add)
for _,player in Players:GetPlayers() do task.spawn(add,player) end
local function snapshot(player)
 local t={}
 for _,k in {"CurrentDay","RewardRedeemable","NextDailyRewardTime","TotalDailyRewardsClaimed","LongestDailyRewardStreak","CurrentDailyRewardStreak"} do t[k]=DailyReward.GetPlayerData(player,k) end
 t.BoostExpires = table.clone(Profiles.get(player).dailyBoostExpires)
 return t
end
ReplicatedStorage.DailyRewards.OnServerInvoke=function(player,claim)
 if not ready[player] then return {error="Loading daily rewards..."} end
 if busy[player] then return {error="Please wait a moment."} end
 local data=snapshot(player)
 if os.time()>data.NextDailyRewardTime then
  local status=GetRewardStatus(player,data)
  if status==2 then
   DailyReward.SetPlayerData(player,"CurrentDay",1)
   DailyReward.SetPlayerData(player,"CurrentDailyRewardStreak",0)
   DailyReward.SetPlayerData(player,"NextDailyRewardTime",os.time()+DAILY_REWARD_CONFIG.COOLDOWN_SECONDS)
   DailyReward.SetPlayerData(player,"RewardRedeemable",true)
  end
  data=snapshot(player)
 end
 if claim==true and data.RewardRedeemable then
  if not Profiles.get(player).loaded or not Profiles.moneyValue(player) then return {error="Your profile is still loading."} end
  busy[player]=true
  DailyReward.SetPlayerData(player,"RewardRedeemable",false)
  DailyReward.AddToPlayerData(player,"TotalDailyRewardsClaimed",1)
  DailyReward.AddToPlayerData(player,"CurrentDailyRewardStreak",1)
  local streak=DailyReward.GetPlayerData(player,"CurrentDailyRewardStreak")
  if streak>data.LongestDailyRewardStreak then DailyReward.SetPlayerData(player,"LongestDailyRewardStreak",streak) end
  GivePlayerReward(player,data.CurrentDay)
  task.spawn(function()
   DailyReward.SavePlayerData(player)
   require(game.ServerScriptService.Server.Persistence).saveNow(player)
   busy[player]=nil
  end)
 end
 return snapshot(player)
end
Players.PlayerRemoving:Connect(function(player)
 ready[player]=nil DailyReward.RemovePlayer(player) busy[player]=nil
end)
game:BindToClose(function()
 for _,player in Players:GetPlayers() do DailyReward.SavePlayerData(player) end
end)
task.spawn(function()
 while task.wait(AUTOSAVE_DELAY) do
  for _,player in Players:GetPlayers() do if ready[player] and not busy[player] then DailyReward.SavePlayerData(player) end end
 end
end)
