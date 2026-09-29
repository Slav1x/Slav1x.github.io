-- Starts the Golden Meridian finale next to the existing server services, without
-- editing the server entry point. Studio-only dev tools load only inside Studio.
local RunService=game:GetService("RunService")
local Server=script.Parent:WaitForChild("Server")
require(Server:WaitForChild("GoldenMeridianService")).start()
if RunService:IsStudio() then
 local dev=Server:FindFirstChild("GoldenDevTools")
 if dev then require(dev).start() end
end
