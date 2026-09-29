-- The one place that decides what happens after the Golden Meridian ending.
-- Today World 2 does not exist yet, so the ending shows "To Be Continued" and the
-- player returns to the Magical Rock. When World 2 ships:
--   1. set GoldenMeridianConfig.World2.Enabled = true
--   2. implement W.send below (TeleportService, a reserved server, or an in-place world)
-- GoldenMeridianService and the client ending already route through this module.
local RS=game:GetService("ReplicatedStorage")
local Config=require(RS.Shared.GoldenMeridianConfig)
local W={}
-- Whether this player should leave for World 2 instead of seeing "To Be Continued".
function W.available(player,path)
 return Config.World2.Enabled==true and type(path)=="table" and path.world2==true
end
-- Return true only if the player was actually sent. Returning false keeps them here.
function W.send(player)
 return false
end
return W
