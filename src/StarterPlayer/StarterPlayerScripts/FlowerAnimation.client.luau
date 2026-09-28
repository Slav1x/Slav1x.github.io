-- Flower Wind & Touch Animation
-- Makes flowers sway in the wind and bend when players walk through them

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- Configuration
local WIND_SPEED = 1.5       -- How fast the wind oscillates
local WIND_STRENGTH = 0.09   -- How much the flowers sway (radians)
local PUSH_STRENGTH = 0.4    -- How much flowers bend when touched (radians)
local PUSH_DURATION = 1.5    -- How long the push effect lasts (seconds)

-- Collect all flower models
local flowers = {}
local setupModels = {}
local connections = {}
local pending = {}

local function isFlowerModel(model)
	if not model:IsA("Model") then return false end
	if model:GetAttribute("StudFlowerReactive") then return false end
	if not string.lower(model.Name):find("flower") then return false end
	-- Check if it has parts (it's a flower, not a container)
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			return true
		end
	end
	return false
end

local function setupFlower(model)
	if setupModels[model] then return end

	-- Find the stem (the part with the largest Y size)
	local stem = nil
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			if not stem or child.Size.Y > stem.Size.Y then
				stem = child
			end
		end
	end

	if not stem then return end
	setupModels[model] = true

	local baseCFrame = model:GetPivot()

	-- The pivot point for rotation is at the base of the stem
	local stemBottomPos = (stem.CFrame * CFrame.new(0, -stem.Size.Y / 2, 0)).Position

	local flowerData = {
		model = model,
		baseCFrame = baseCFrame,
		pivotPoint = stemBottomPos,
		phase = math.random() * math.pi * 2,
		swaySpeed = WIND_SPEED * (0.8 + math.random() * 0.4),
		swayAmount = WIND_STRENGTH * (0.7 + math.random() * 0.6),
		pushTime = -100,
		pushDirection = Vector3.new(0, 0, 1),
		touchDebounce = 0,
	}

	table.insert(flowers, flowerData)


end

-- Find all flower models in workspace
local function findFlowers()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if isFlowerModel(descendant) then
			setupFlower(descendant)
		end
	end
end

-- One initial scan, then model/part events as geometry streams in.
findFlowers()
local function consider(descendant)
 local model=descendant:IsA("Model") and descendant or descendant.Parent
 if not model or not model:IsA("Model") or setupModels[model] or pending[model] then return end
 if not string.lower(model.Name):find("flower") or model:GetAttribute("StudFlowerReactive") then return end
 pending[model]=true
 task.defer(function()
  pending[model]=nil
  if model:IsDescendantOf(workspace) and isFlowerModel(model) then setupFlower(model) end
 end)
end
table.insert(connections,workspace.DescendantAdded:Connect(consider))
table.insert(connections,workspace.DescendantRemoving:Connect(function(descendant)
 if not setupModels[descendant] then return end
 setupModels[descendant]=nil
 for i=#flowers,1,-1 do
  if flowers[i].model==descendant then
   local fd=table.remove(flowers,i)
   if fd.moved then descendant:PivotTo(fd.baseCFrame) end
   break
  end
 end
end))

-- Animation loop
local elapsed=0
local frameConnection=RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<1/30 then return end;elapsed=0
 local camera=workspace.CurrentCamera;if not camera then return end
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local reduced=player:GetAttribute("ReducedMotion")==true
 local active=0
 local now = os.clock()

	for _, fd in ipairs(flowers) do
        if not fd.model:IsDescendantOf(workspace) then continue end
        if (fd.pivotPoint-camera.CFrame.Position).Magnitude>160 or active>=72 then
            if fd.moved then fd.model:PivotTo(fd.baseCFrame);fd.moved=false end
            continue
        end
        active+=1
        if root and now-fd.touchDebounce>=1 then
            local delta=fd.pivotPoint-root.Position
            local flat=Vector3.new(delta.X,0,delta.Z)
            if flat.Magnitude<3 and math.abs(delta.Y)<6 then
                fd.touchDebounce=now;fd.pushTime=now
                fd.pushDirection=flat.Magnitude>.01 and flat.Unit or Vector3.new(0,0,1)
            end
        end
        if fd.model.Parent then
            -- Wind sway using sine waves with per-flower phase offset
			local t = now * fd.swaySpeed + fd.phase
			local swayAngleX = math.sin(t) * fd.swayAmount
			local swayAngleZ = math.cos(t * 0.7) * fd.swayAmount * 0.6
			-- Shared gentle gust direction matches the lake's drifting pollen.
			local gust = 0.65 + 0.35 * math.sin(now * 0.32)
			swayAngleX += fd.swayAmount * 0.2 * gust
			swayAngleZ -= fd.swayAmount * 0.45 * gust

			-- Touch push effect with quick bend and gradual recovery
			local pushAngleX = 0
			local pushAngleZ = 0
			local timeSincePush = now - fd.pushTime
			if timeSincePush < PUSH_DURATION then
				local progress = timeSincePush / PUSH_DURATION
				local pushAmount
				if progress < 0.15 then
					-- Quick initial bend
					pushAmount = progress / 0.15
				else
					-- Gradual recovery with slight oscillation
					pushAmount = (1 - ((progress - 0.15) / 0.85))
					pushAmount = pushAmount * (1 + math.sin((progress - 0.15) * 15) * 0.15)
				end
				pushAmount = math.max(0, pushAmount) * PUSH_STRENGTH

				-- Convert push direction to rotation angles
				pushAngleX = fd.pushDirection.Z * pushAmount
				pushAngleZ = -fd.pushDirection.X * pushAmount
			end

			-- Combine wind and push
			local totalAngleX = (reduced and 0 or swayAngleX) + pushAngleX*(reduced and .45 or 1)
			local totalAngleZ = (reduced and 0 or swayAngleZ) + pushAngleZ*(reduced and .45 or 1)

			-- Apply rotation around the base of the flower stem
			local pivot = fd.pivotPoint
			local rotCFrame = CFrame.new(pivot) * CFrame.Angles(totalAngleX, 0, totalAngleZ) * CFrame.new(-pivot)
			local newCFrame = rotCFrame * fd.baseCFrame

			fd.model:PivotTo(newCFrame)
            fd.moved=true
		end
	end
end)

script.Destroying:Connect(function()
 frameConnection:Disconnect()
 for _,connection in connections do connection:Disconnect() end
 for _,fd in flowers do if fd.moved and fd.model.Parent then fd.model:PivotTo(fd.baseCFrame) end end
 table.clear(flowers);table.clear(setupModels);table.clear(pending)
end)
