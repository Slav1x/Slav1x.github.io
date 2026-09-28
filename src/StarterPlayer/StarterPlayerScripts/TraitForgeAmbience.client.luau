-- Restrained local ambience for the open woodland trait workshop.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local decor=workspace:WaitForChild("TraitForge"):WaitForChild("MythicalForge")
local energy=decor:WaitForChild("ForgeEnergy")
local light=energy:WaitForChild("ForgeLight")
local emitter=energy:WaitForChild("EmberOrigin"):WaitForChild("ForgeEmbers")
local elapsed=0
local connection=RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt
 if elapsed<.15 then return end
 elapsed=0
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local nearby=root~=nil and (root.Position-energy.Position).Magnitude<65
 light.Enabled=nearby
 emitter.Enabled=nearby and player:GetAttribute("ReducedMotion")~=true
end)
script.Destroying:Connect(function() connection:Disconnect() end)
