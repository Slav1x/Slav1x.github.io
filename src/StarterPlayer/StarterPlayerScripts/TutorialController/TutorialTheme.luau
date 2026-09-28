--!strict
-- The Skipstone theme now lives in ReplicatedStorage.SharedUI.SkipstoneTheme
-- (shared with the gameplay HUD). This shim keeps the tutorial's requires working.
return require(game:GetService("ReplicatedStorage"):WaitForChild("SharedUI"):WaitForChild("SkipstoneTheme"))
