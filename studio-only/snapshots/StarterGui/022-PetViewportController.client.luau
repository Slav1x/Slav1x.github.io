-- Binds cameras to the authored BGC pet ViewportFrames in the existing shop.
local shop = script.Parent

local function bind(preview)
    local world = preview:FindFirstChildWhichIsA("WorldModel")
    local model = world and world:FindFirstChildWhichIsA("Model")
    if not model or not model:FindFirstChildWhichIsA("BasePart", true) then return end
    model:PivotTo(CFrame.new())
    local cf, size = model:GetBoundingBox()
    local camera = preview:FindFirstChildWhichIsA("Camera") or Instance.new("Camera")
    camera.Name = "PetCamera"
    camera.FieldOfView = 36
    local radius = math.max(size.X, size.Y, size.Z)
    local factor = preview.Parent.Name == "RewardTile1" and 1.28 or .95
    local distance = radius * .5 / math.tan(math.rad(camera.FieldOfView * .5)) * factor
    local center = cf.Position + Vector3.new(0, size.Y * .02, 0)
    camera.CFrame = CFrame.lookAt(center + Vector3.new(size.X * .05, size.Y * .10, -distance), center)
    camera.Parent = preview
    preview.CurrentCamera = camera
end

for _, descendant in shop:GetDescendants() do
    if descendant:IsA("ViewportFrame") and descendant.Name == "PetPreview" then
        bind(descendant)
    end
end



