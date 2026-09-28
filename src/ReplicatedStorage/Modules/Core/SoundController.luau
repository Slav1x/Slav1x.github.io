-- services
local SoundService = game:GetService("SoundService")
local sfxGroup = SoundService:WaitForChild("SFX")

local SoundController = {}

function SoundController.Play(category, sound_ID, audio_properties)
	if category == "SFX" then
		local sound = sfxGroup:FindFirstChild(sound_ID)
		if sound then	
			sound.PlaybackSpeed = audio_properties ~= nil and audio_properties.audio_randomize_pitch == true and math.random(100, 130)/100 or 1
			sound:Play()
		else
			warn("SFX not found: " .. sound_ID)
		end	
	end
end

return SoundController
