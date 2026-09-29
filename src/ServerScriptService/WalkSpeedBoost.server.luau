local Players = game:GetService("Players")

local DEFAULT_WALKSPEED = 16
local MULTIPLIER = 3

local function onCharacterAdded(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = DEFAULT_WALKSPEED * MULTIPLIER
    else
        -- If the Humanoid hasn't replicated yet, wait for it
        local hr = character:WaitForChild("Humanoid", 5)
        if hr then
            hr.WalkSpeed = DEFAULT_WALKSPEED * MULTIPLIER
        end
    end
end

local function onPlayerAdded(player)
    player.CharacterAdded:Connect(onCharacterAdded)
    if player.Character then
        onCharacterAdded(player.Character)
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Handle players already in the game
for _, player in Players:GetPlayers() do
    onPlayerAdded(player)
end