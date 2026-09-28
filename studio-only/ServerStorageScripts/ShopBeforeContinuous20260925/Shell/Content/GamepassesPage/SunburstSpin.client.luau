--// Spinning sunburst rays behind each gamepass card

local RunService = game:GetService("RunService")

local page = script.Parent
local SPEED = 35 -- degrees per second; one full revolution = 360 / SPEED seconds

local bursts = {}

local function addBurst(instance)
	if instance:IsA("ImageLabel") and instance.Name == "Sunburst" and not table.find(bursts, instance) then
		table.insert(bursts, instance)
		instance.Destroying:Connect(function()
			local i = table.find(bursts, instance)
			if i then table.remove(bursts, i) end
		end)
	end
end

-- Track existing sunbursts (including any cards added later)
for _, descendant in page:GetDescendants() do
	addBurst(descendant)
end
page.DescendantAdded:Connect(addBurst)

RunService.Heartbeat:Connect(function(dt)
	for _, burst in bursts do
		-- Only spin while the shop page is actually on screen
		if burst.AbsoluteSize.Magnitude > 0 then
			burst.Rotation = (burst.Rotation + SPEED * dt) % 360
		end
	end
end)
