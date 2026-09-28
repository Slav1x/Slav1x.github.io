--!strict
-- Server-authoritative, persistent code redemption.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Shared=RS:WaitForChild("Shared")
local RockCatalog=require(Shared:WaitForChild("RockCatalog"))
local PetCatalog=require(Shared:WaitForChild("PetCatalog"))
local Persistence=require(game.ServerScriptService.Server.Persistence)

-- Live access is deliberately explicit. Studio playtests are allowed so local
-- test players can exercise the package without weakening authorization live.
local DEVELOPER_USER_IDS: {[number]: boolean} = {
	[90065445] = true,
}
local DEV_RECEIPT_ID="DEV_V3_CURRENT" -- lets authorized developers redeem the upgraded package once
local function isDeveloper(player: Player): boolean
	return RunService:IsStudio() or DEVELOPER_USER_IDS[player.UserId] == true
end

local CODES: {[string]: {reward: {[string]: number}, label: string}} = {
	WELCOME = {reward = {Money = 500}, label = "500 Coins"},
	STUDS = {reward = {Money = 1000}, label = "1,000 Coins"},
	POWER = {reward = {Strength = 25}, label = "25 Spin Strength"},
	BIGBAG = {reward = {Money = 2500, Strength = 10}, label = "2,500 Coins + 10 Spin Strength"},
}
local last: {[Player]: number}={}
Players.PlayerRemoving:Connect(function(player) last[player]=nil end)

local function devInventory()
	local rocks={}
	for _,rock in RockCatalog.Rocks do table.insert(rocks,rock.id) end
	local pets={}
	for _,pet in PetCatalog.Pets do table.insert(pets,pet.id) end
	return {rocks=rocks,pets=pets},#rocks,#pets
end

RS:WaitForChild("RedeemCode").OnServerInvoke=function(player,code)
	if type(code)~="string" or #code>64 then return {success=false,message="Invalid code."} end
	code=code:match("^%s*(.-)%s*$"):upper()
	if last[player] and os.clock()-last[player]<1 then return {success=false,message="Please wait a moment."} end
	last[player]=os.clock()
	if code=="DEV" then
		if not isDeveloper(player) then
			warn(string.format("[CodeRedemption] Unauthorized DEV attempt by %s (%d)",player.Name,player.UserId))
			return {success=false,message="This code is restricted to authorized developers."}
		end
		local inventory,rockCount,petCount=devInventory()
		local ok,message=Persistence.redeemCode(player,DEV_RECEIPT_ID,{Money=1000000000},inventory)
		return {success=ok,message=ok and string.format("Developer package granted: 1,000,000,000 Cash, %d rocks, and %d pets.",rockCount,petCount) or message}
	end
	if code=="SHINY1234" then
		if not Persistence.supportsEnchantedCodeGrants then return {success=false,message="This reward is not available yet."} end
		local ids={}
		for _,rock in RockCatalog.Rocks do
			if rock.id~="hermes_rock" and rock.id~="jetpack_rock" then table.insert(ids,rock.id) end
		end
		local ok,message=Persistence.redeemCode(player,"SHINY1234",{},{enchantedRocks=ids})
		return {success=ok,message=ok and string.format("Redeemed! All %d Enchanted rocks are now in your collection.",#ids) or message}
	end
	local entry=CODES[code]
	if not entry then return {success=false,message="Unknown code! Check the spelling."} end
	local ok,message=Persistence.redeemCode(player,code,entry.reward)
	return {success=ok,message=ok and ("Redeemed! You got "..entry.label..".") or message}
end

