local SoundService = game:GetService("SoundService")

local group = SoundService:WaitForChild("SFX")
local names = {
	Hover = "UI_Hover_01",
	Click = "UI_Click_01",
	Open = "UI_Menu_Open",
	Close = "UI_Menu_Close",
	Tab = "UI_Click_01",
	Claim = "SFX_Reward_Claimed",
	Success = "SFX_Reward_Claimed",
}

local UISounds = {}
local lastHover = 0
local lastPlayed = {}

function UISounds.play(kind)
	if kind == "Hover" then
		local now = os.clock()
		if now - lastHover < 0.055 then return end
		lastHover = now
	end
	local sound = group:FindFirstChild(names[kind] or kind)
	if not sound or not sound:IsA("Sound") then return end
	local now=os.clock()
 local key=sound.Name
 if now-(lastPlayed[key] or -math.huge)<.09 then return end
 lastPlayed[key]=now
 sound:Stop()
	sound.TimePosition = 0
	sound:Play()
end

return UISounds
