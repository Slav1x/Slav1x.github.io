--!strict
-- generationId: dbb19cde-a304-4be5-af1d-30159ee27e36
local CSG = require(script.Dependencies.ConstructiveSolidGeometry)
local GP = require(script.Dependencies.GeometryPrimitives)
local SO = require(script.Dependencies.SmartObject)
local MU = require(script.Dependencies.MathUtils)


local MonkeyAndGorilla = {}

type Parameters = {
	Size: Vector3,
	Attributes: {
		SandColor: Color3?,
		TrunkColor: Color3?,
		LeafColor: Color3?,
		RockColor: Color3?,
		MonkeyFurColor: Color3?,
		MonkeySkinColor: Color3?,
		MonkeyEyeColor: Color3?,
		GorillaFurColor: Color3?,
		GorillaSkinColor: Color3?,
	},
}
local startTime = 0
local timerThread : thread = task.spawn(function()
while true do
	if not script:IsDescendantOf(game) then
		startTime = 0
		return
	end
	if startTime > 0 then
		local elapsed = tick() - startTime
		print("[ProceduralModel] " .. script:GetFullName() .. " rendering... " .. string.format("%.0f", elapsed) .. " seconds")
	end
	task.wait(3)
end
end)
script.Destroying:Connect(function()
	task.cancel(timerThread)
end)

MonkeyAndGorilla.OnGenerate = function(parameters: Parameters, targetContainer: Instance)
	-- Timer setup
	startTime = tick()

	local topModel = GP.model("MonkeyAndGorilla", nil)-- Fix orientation of the model
	topModel.WorldPivot = CFrame.identity
	
	
	-- == Attributes ==
	local smartWidth  = parameters.Size.X
	local smartHeight = parameters.Size.Y
	local smartDepth  = parameters.Size.Z
	
	-- Uniform scale derived from smart attributes
	local scale = math.min(smartWidth, smartHeight, smartDepth) / 10
	
	-- Colors
	local sandColor = parameters.Attributes.SandColor or Color3.fromRGB(245, 220, 160)
	local trunkColor = parameters.Attributes.TrunkColor or Color3.fromRGB(180, 120, 70)
	local leafColor = parameters.Attributes.LeafColor or Color3.fromRGB(110, 200, 100)
	local rockColor = parameters.Attributes.RockColor or Color3.fromRGB(150, 145, 155)
	
	local monkeyFurColor = parameters.Attributes.MonkeyFurColor or Color3.fromRGB(160, 90, 50)
	local monkeySkinColor = parameters.Attributes.MonkeySkinColor or Color3.fromRGB(255, 200, 160)
	local monkeyEyeColor = parameters.Attributes.MonkeyEyeColor or Color3.fromRGB(30, 30, 30)
	
	local gorillaFurColor = parameters.Attributes.GorillaFurColor or Color3.fromRGB(60, 55, 65)
	local gorillaSkinColor = parameters.Attributes.GorillaSkinColor or Color3.fromRGB(40, 35, 45)
	
	-- == Top-Level Models ==
	local islandModel = GP.model("island", topModel)
	local monkeyModel = GP.model("monkey", topModel)
	local gorillaModel = GP.model("gorilla", topModel)
	
	-- Helper function to build an island
	local function buildIsland(parent, centerPos, r)
		local islandHeight = 1.0 * scale
		
		-- Base
		GP.regularPrism("SandBase", 
			centerPos - Vector3.new(0, islandHeight, 0), 
			centerPos, 
			r, 12, sandColor, "SmoothPlastic", parent)
			
		-- Palm Tree
		local treePos = centerPos + Vector3.new(-r * 0.2, 0, r * 0.2)
		local trunkH = 6.0 * scale
		GP.taperedCylinder("PalmTrunk", 
			treePos, 
			treePos + Vector3.new(0, trunkH, 0), 
			0.6 * scale, 0.3 * scale, 
			trunkColor, "Wood", parent)
			
		-- Leaves
		local leavesTop = treePos + Vector3.new(0, trunkH + 0.2*scale, 0)
		local leafCount = 6
		MU.radialArray(leavesTop, 0.1, leafCount, Vector3.yAxis, function(pos, i)
			local dir = (pos - leavesTop).Unit
			local leafEnd = pos + dir * (3.5 * scale) - Vector3.new(0, 1.0 * scale, 0)
			
			local right = dir:Cross(Vector3.yAxis).Unit * (1.5 * scale)
			local baseC1 = pos - right
			local baseC2 = pos + right
			
			GP.pyramid("Leaf_"..i, baseC1, baseC2, leafEnd, leafColor, "SmoothPlastic", parent)
		end)
		
		-- Rocks
		GP.sphere("Rock1", centerPos + Vector3.new(r*0.4, 0.3*scale, r*0.4), 0.5 * scale, rockColor, "SmoothPlastic", parent)
		GP.sphere("Rock2", centerPos + Vector3.new(r*0.6, 0.2*scale, r*0.2), 0.3 * scale, rockColor, "SmoothPlastic", parent)
	end
	
	-- Helper function to build a primate
	local function buildPrimate(parent, basePos, s, furColor, skinColor, isGorilla)
		local bodyH = (isGorilla and 3.0 or 2.0) * s
		local bodyW = (isGorilla and 1.8 or 1.2) * s
		
		-- Body
		local bodyBase = basePos + Vector3.new(0, bodyW, 0)
		local bodyTop = bodyBase + Vector3.new(0, bodyH, 0)
		GP.capsule("Body", bodyBase, bodyW, bodyTop, bodyW * 0.8, furColor, "SmoothPlastic", parent)
		
		-- Belly Patch
		GP.sphere("Belly", bodyBase + Vector3.new(0, bodyH*0.4, -bodyW*0.6), bodyW * 0.85, skinColor, "SmoothPlastic", parent)
		
		-- Head
		local headR = (isGorilla and 1.6 or 1.5) * s
		local headPos = bodyTop + Vector3.new(0, headR * 0.8, -0.2 * s)
		GP.sphere("Head", headPos, headR, furColor, "SmoothPlastic", parent)
		
		-- Face Mask
		local maskR = headR * 0.85
		local maskPos = headPos + Vector3.new(0, -headR*0.1, -headR*0.4)
		GP.sphere("Face", maskPos, maskR, skinColor, "SmoothPlastic", parent)
		if isGorilla then
			-- Gorilla brow
			GP.capsule("Brow", maskPos + Vector3.new(-maskR*0.6, maskR*0.5, -maskR*0.5), maskR*0.3, maskPos + Vector3.new(maskR*0.6, maskR*0.5, -maskR*0.5), maskR*0.3, furColor, "SmoothPlastic", parent)
		end
		
		-- Muzzle
		local muzzleR = headR * 0.6
		local muzzlePos = maskPos + Vector3.new(0, -headR*0.3, -headR*0.5)
		GP.sphere("Muzzle", muzzlePos, muzzleR, skinColor, "SmoothPlastic", parent)
		
		-- Eyes
		local eyeR = headR * 0.15
		GP.sphere("EyeLeft", maskPos + Vector3.new(maskR*0.4, maskR*0.2, -maskR*0.8), eyeR, monkeyEyeColor, "SmoothPlastic", parent)
		GP.sphere("EyeRight", maskPos + Vector3.new(-maskR*0.4, maskR*0.2, -maskR*0.8), eyeR, monkeyEyeColor, "SmoothPlastic", parent)
		
		-- Ears
		local earR = headR * 0.35
		GP.sphere("EarLeft", headPos + Vector3.new(headR*0.9, 0, 0), earR, skinColor, "SmoothPlastic", parent)
		GP.sphere("EarRight", headPos + Vector3.new(-headR*0.9, 0, 0), earR, skinColor, "SmoothPlastic", parent)
		
		-- Limbs
		local armW = (isGorilla and 0.8 or 0.4) * s
		local legW = (isGorilla and 0.7 or 0.5) * s
		
		-- Legs (sitting posture)
		local legLStart = bodyBase + Vector3.new(bodyW*0.6, 0, -bodyW*0.2)
		local legLEnd = legLStart + Vector3.new(bodyW*0.5, 0, -bodyW)
		GP.capsule("LegLeft", legLStart, legW, legLEnd, legW*0.8, furColor, "SmoothPlastic", parent)
		GP.sphere("FootLeft", legLEnd + Vector3.new(0,0,-legW*0.2), legW, skinColor, "SmoothPlastic", parent)
		
		local legRStart = bodyBase + Vector3.new(-bodyW*0.6, 0, -bodyW*0.2)
		local legREnd = legRStart + Vector3.new(-bodyW*0.5, 0, -bodyW)
		GP.capsule("LegRight", legRStart, legW, legREnd, legW*0.8, furColor, "SmoothPlastic", parent)
		GP.sphere("FootRight", legREnd + Vector3.new(0,0,-legW*0.2), legW, skinColor, "SmoothPlastic", parent)
		
		-- Arms
		local armLStart = bodyTop + Vector3.new(bodyW*0.9, -bodyW*0.2, 0)
		local armLEnd = (isGorilla) and (legLStart + Vector3.new(armW, 0, -armW)) or (legLStart + Vector3.new(0, bodyW*0.5, -bodyW*0.5))
		GP.capsule("ArmLeft", armLStart, armW, armLEnd, armW*0.8, furColor, "SmoothPlastic", parent)
		GP.sphere("HandLeft", armLEnd, armW, skinColor, "SmoothPlastic", parent)
		
		local armRStart = bodyTop + Vector3.new(-bodyW*0.9, -bodyW*0.2, 0)
		local armREnd = (isGorilla) and (legRStart + Vector3.new(-armW, 0, -armW)) or (legRStart + Vector3.new(0, bodyW*0.5, -bodyW*0.5))
		GP.capsule("ArmRight", armRStart, armW, armREnd, armW*0.8, furColor, "SmoothPlastic", parent)
		GP.sphere("HandRight", armREnd, armW, skinColor, "SmoothPlastic", parent)
		
		-- Tail (only monkey)
		if not isGorilla then
			local tailPoints = MU.sampleBezierPoints(
				bodyBase + Vector3.new(0, 0, bodyW*0.8),
				bodyBase + Vector3.new(0, 0, bodyW*2.5),
				bodyBase + Vector3.new(bodyW*2.0, bodyW*1.5, bodyW*2.0),
				bodyBase + Vector3.new(bodyW*1.5, bodyW*0.5, bodyW*1.0),
				8
			)
			GP.tube("Tail", tailPoints, armW*0.7, furColor, "SmoothPlastic", parent)
		end
	end
	
	-- 1. Build Monkey's Island
	local monkeyIslandCenter = Vector3.new(5 * scale, 0, 0)
	buildIsland(islandModel, monkeyIslandCenter, 6.0 * scale)
	
	-- 2. Build Monkey
	local monkeyPos = monkeyIslandCenter + Vector3.new(1.0 * scale, 0, -1.0 * scale)
	buildPrimate(monkeyModel, monkeyPos, scale * 1.0, monkeyFurColor, monkeySkinColor, false)
	
	-- 3. Build Gorilla and its Island
	local gorillaIslandCenter = Vector3.new(-12 * scale, 0, 0)
	local gorillaIslandSubModel = GP.model("GorillaIsland", gorillaModel)
	buildIsland(gorillaIslandSubModel, gorillaIslandCenter, 8.0 * scale)
	
	local gorillaPos = gorillaIslandCenter + Vector3.new(1.5 * scale, 0, -1.5 * scale)
	buildPrimate(gorillaModel, gorillaPos, scale * 1.5, gorillaFurColor, gorillaSkinColor, true)
	
	topModel.Parent = targetContainer
	-- reposition
	for _, part in targetContainer:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame -= Vector3.yAxis * parameters.Size.Y / 2
		end
	end
	for _, model in targetContainer:GetDescendants() do
		if model:IsA("Model") then
			model.WorldPivot -= Vector3.yAxis * parameters.Size.Y / 2
		end
	end

	-- Stop timer when generation completes
	local timeElapsed = tick() - startTime
	startTime = 0
	if timeElapsed > 3 and script:IsDescendantOf(game) then
		print("[ProceduralModel] " .. script:GetFullName() .. " rendering completed")
	end

end

return MonkeyAndGorilla

