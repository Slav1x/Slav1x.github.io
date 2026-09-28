--!nonstrict
-- Small local movements only. Static art and gameplay collisions stay in the saved place.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local root = workspace:WaitForChild("EnvironmentalLife")
local swayFolder = root:WaitForChild("SwayGroups")
local terrain = workspace:WaitForChild("terrain")

local localArt = Instance.new("Folder")
localArt.Name = "LocalEnvironmentalLife"
localArt.Parent = workspace

local function artPart(name, size, color, shape)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Shape = shape or Enum.PartType.Block
    p.Material = Enum.Material.SmoothPlastic
    p.Color = color
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    p.Parent = localArt
    return p
end

local swaying = {}
for index, model in ipairs(swayFolder:GetChildren()) do
    if model:IsA("Model") then
        table.insert(swaying, {
            model = model,
            base = model:GetPivot(),
            position = model:GetPivot().Position,
            phase = index * 1.37,
            amplitude = model.Name:find("Canopy") and 0.026 or (model.Name:find("Reeds") and 0.073 or 0.10),
            active = false,
        })
    end
end

-- Existing non-colliding reeds get the same breeze as the new shore beds.
local reeds = {}
local seenReeds = {}
local function trackReed(p)
    if p:IsA("BasePart") and p.Name == "Reed" and not seenReeds[p] and not p.CanCollide and not p:GetAttribute("InteractiveGrass") then
        seenReeds[p] = true
        table.insert(reeds, {
            part = p,
            base = p.CFrame,
            foot = (p.CFrame * CFrame.new(0, -p.Size.Y * 0.5, 0)).Position,
            phase = #reeds * 1.41,
            active = false,
        })
    end
end
for _, p in ipairs(terrain:GetDescendants()) do trackReed(p) end
local added = terrain.DescendantAdded:Connect(trackReed)

-- Leaves stay at the outside edges of the skipping lane.
local leaves = {}
local leafSites = {
    {-495, -123}, {-478, -139}, {-446, -132},
    {-493, 47}, {-471, 68}, {-434, 81},
}
for i, site in ipairs(leafSites) do
    local leaf = artPart("FloatingLeaf", Vector3.new(1.1 + (i % 3) * 0.2, 0.08, 0.62),
        i % 2 == 0 and Color3.fromRGB(127, 147, 85) or Color3.fromRGB(153, 149, 88), Enum.PartType.Ball)
    table.insert(leaves, {part = leaf, x = site[1], z = site[2], phase = i * 0.157})
end

-- Three butterflies visit existing flower pockets intermittently.
local butterflies = {}
local flowerSites = {
    {Vector3.new(-579, 18.2, 21), Color3.fromRGB(245, 220, 135)},
    {Vector3.new(-607, 18.0, -82), Color3.fromRGB(151, 222, 229)},
    {Vector3.new(-575, 18.1, -111), Color3.fromRGB(222, 176, 221)},
}
for i, site in ipairs(flowerSites) do
    local body = artPart("ButterflyBody", Vector3.new(0.14, 0.58, 0.15), Color3.fromRGB(57, 68, 65), Enum.PartType.Ball)
    local left = artPart("ButterflyWing", Vector3.new(0.79, 0.12, 0.56), site[2], Enum.PartType.Ball)
    local right = artPart("ButterflyWing", Vector3.new(0.79, 0.12, 0.56), site[2], Enum.PartType.Ball)
    table.insert(butterflies, {body = body, left = left, right = right, center = site[1], phase = i * 4.7})
end

local elapsed = 0
local connection = RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed < 0.1 then return end
    elapsed = 0
    local camera = workspace.CurrentCamera
    if not camera then return end
    local cameraPosition = camera.CFrame.Position
    local now = os.clock()
    local reduced = player:GetAttribute("ReducedMotion") == true
    local gust = 0.7 + 0.3 * math.sin(now * 0.32)

    for _, item in ipairs(swaying) do
        if not item.model.Parent then continue end
        local near = (cameraPosition - item.position).Magnitude < 175
        if near and not reduced then
            local angle = item.amplitude * gust
            item.model:PivotTo(item.base * CFrame.Angles(
                math.sin(now * 1.18 + item.phase) * angle,
                0,
                math.cos(now * 0.92 + item.phase) * angle * 0.7
            ))
            item.active = true
        elseif item.active then
            item.model:PivotTo(item.base)
            item.active = false
        end
    end

    for _, item in ipairs(reeds) do
        local p = item.part
        if not p.Parent then continue end
        local near = (cameraPosition - item.foot).Magnitude < 135
        if near and not reduced then
            local angle = math.sin(now * 1.15 + item.phase) * 0.055 * gust
            p.CFrame = CFrame.new(item.foot) * CFrame.Angles(angle, 0, angle * 0.48)
                * CFrame.new(-item.foot) * item.base
            item.active = true
        elseif item.active then
            p.CFrame = item.base
            item.active = false
        end
    end

    for _, item in ipairs(leaves) do
        local p = item.part
        local near = (cameraPosition - Vector3.new(item.x, 15.2, item.z)).Magnitude < 210
        if near then
            local travel = reduced and 0.35 or (now * 0.024 + item.phase) % 1
            local fade = math.min(1, travel * 7, (1 - travel) * 7)
            p.Transparency = 0.22 + (1 - fade) * 0.78
            p.CFrame = CFrame.new(item.x + travel * 8, 15.18 + (reduced and 0 or math.sin(now * 1.3 + item.phase) * 0.045),
                item.z + math.sin(travel * 5 + item.phase) * 1.1)
                * CFrame.Angles(0, now * 0.1 + item.phase * 7, 0)
        else
            p.Transparency = 1
        end
    end

    for _, b in ipairs(butterflies) do
        local near = (cameraPosition - b.center).Magnitude < 130
        local active = near and not reduced and ((now + b.phase) % 18 < 11)
        local transparency = active and 0 or 1
        b.body.Transparency = transparency
        b.left.Transparency = transparency
        b.right.Transparency = transparency
        if active then
            local pos = b.center + Vector3.new(
                math.sin(now * 0.75 + b.phase) * 2.2,
                math.sin(now * 1.5 + b.phase) * 0.65,
                math.cos(now * 0.58 + b.phase) * 2.0
            )
            local facing = CFrame.new(pos) * CFrame.Angles(0, now * 0.34 + b.phase, 0)
            local flap = math.sin(now * 12 + b.phase) * 0.35
            b.body.CFrame = facing
            b.left.CFrame = facing * CFrame.new(-0.43, 0.13, 0) * CFrame.Angles(0, 0, flap)
            b.right.CFrame = facing * CFrame.new(0.43, 0.13, 0) * CFrame.Angles(0, 0, -flap)
        end
    end
end)

script.Destroying:Connect(function()
    connection:Disconnect()
    added:Disconnect()
    for _, item in ipairs(swaying) do
        if item.model.Parent then item.model:PivotTo(item.base) end
    end
    for _, item in ipairs(reeds) do
        if item.part.Parent then item.part.CFrame = item.base end
    end
    localArt:Destroy()
end)

