--!strict
-- Resize/move this script's parent Water part. No generated terrain or deletion.
local part = script.Parent :: BasePart
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("ThrowConfig"))
local WaterSurface = require(Shared:WaitForChild("WaterSurface"))
local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
for _, name in {Config.PebbleCollisionGroup, Config.WaterCollisionGroup} do
	if not PhysicsService:IsCollisionGroupRegistered(name) then PhysicsService:RegisterCollisionGroup(name) end
end
PhysicsService:CollisionGroupSetCollidable(Config.PebbleCollisionGroup, Config.WaterCollisionGroup, false)
part.Anchored = true
part.CanCollide = false
part.CanTouch = false
part.CanQuery = true
part.CollisionGroup = Config.WaterCollisionGroup
CollectionService:AddTag(part, WaterSurface.Tag)
local applying = false
local function sync()
	if applying then return end
	applying = true
	local heading = part.CFrame.LookVector
	local horizontal = Vector3.new(heading.X, 0, heading.Z)
	if horizontal.Magnitude < 0.001 then horizontal = Vector3.new(0, 0, -1) end
	part.CFrame = CFrame.lookAt(part.Position, part.Position + horizontal.Unit)
	part:SetAttribute("SurfaceY", WaterSurface.getLevel(part))
	part:SetAttribute("WaterWidth", part.Size.X)
	part:SetAttribute("WaterLength", part.Size.Z)
	applying = false
end
part:GetPropertyChangedSignal("CFrame"):Connect(sync)
part:GetPropertyChangedSignal("Size"):Connect(sync)
sync()

