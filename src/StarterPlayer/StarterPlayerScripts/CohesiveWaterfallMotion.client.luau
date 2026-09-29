-- Small, distance-budgeted impact effects; tagged instances handle streaming.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local emitters = {}
local function add(instance)
    if instance:IsA("ParticleEmitter") then emitters[instance] = true end
end
for _, instance in CollectionService:GetTagged("CohesiveWaterfallFX") do add(instance) end
CollectionService:GetInstanceAddedSignal("CohesiveWaterfallFX"):Connect(add)
CollectionService:GetInstanceRemovedSignal("CohesiveWaterfallFX"):Connect(function(instance)
    emitters[instance] = nil
end)
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed < 0.2 then return end
    elapsed = 0
    local camera = workspace.CurrentCamera
    if not camera then return end
    local reduced = player:GetAttribute("ReducedMotion") == true
    local candidates = {}
    for emitter in emitters do
        local parent = emitter.Parent
        if not parent or not emitter:IsDescendantOf(workspace) then
            emitter.Enabled = false
            continue
        end
        local position = parent:IsA("Attachment") and parent.WorldPosition or parent.Position
        local distance = (camera.CFrame.Position - position).Magnitude
        emitter.Enabled = false
        if not reduced and distance < 850 then
            table.insert(candidates, {emitter = emitter, distance = distance})
        end
    end
    table.sort(candidates, function(a, b) return a.distance < b.distance end)
    for i = 1, math.min(12, #candidates) do
        local item = candidates[i]
        local emitter = item.emitter
        emitter.Rate = (emitter:GetAttribute("BaseRate") or 5) * ({LOW=0.4,MEDIUM=0.7,HIGH=1,ULTRA=1.15})[player:GetAttribute("GraphicsQualityPreset") or "MEDIUM"] * math.clamp((850-item.distance)/400, 0.2, 1)
        emitter.Enabled = true
    end
end)
