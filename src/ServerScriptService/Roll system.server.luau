-- Legacy roller disabled; RollVfxController owns the prompt.
if true then return end
local active = game.Workspace.SpinButton.ProximityPrompt
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local PebbleModel = ServerStorage:WaitForChild("Pebble")

local current_Pebble
local rolling = false
local idleConnection
local new_Pebblecolors = {
	[1] = Color3.fromRGB(255, 0, 0),
	[2] = Color3.fromRGB(0, 255, 0),
	[3] = Color3.fromRGB(0, 0, 255),
	[4] = Color3.fromRGB(255, 255, 0),
	[5] = Color3.fromRGB(255, 0, 255),
	[6] = Color3.fromRGB(0, 255, 255),
	[7] = Color3.fromRGB(255, 255, 255),
	[8] = Color3.fromRGB(128, 0, 128),
	[9] = Color3.fromRGB(255, 105, 180),
	[10] = Color3.fromRGB(255, 165, 0),
}

local PebbleLuck = {
	[1] = 1,
	[2] = 500,
	[3] = 1000,
	[4] = 100,
	[5] = 50,
	[6] = 250,
	[7] = 25,
	[8] = 10,
	[9] = 5,
	[10] = 100,
}


------------------------------------------------
-- WEIGHTED RANDOM
------------------------------------------------

local function GetLuckyPebble()

	local totalWeight = 0

	for number, weight in PebbleLuck do
		totalWeight += weight
	end

	local randomWeight = math.random(1, totalWeight)
	local currentWeight = 0

	for number, weight in PebbleLuck do

		currentWeight += weight

		if randomWeight <= currentWeight then
			return number
		end

	end

end


------------------------------------------------
-- RARITY
------------------------------------------------

local function GetRarity(weight)

	if weight >= 250 then
		return "Common"

	elseif weight >= 100 then
		return "Uncommon"

	elseif weight >= 50 then
		return "Rare"

	elseif weight >= 10 then
		return "Epic"

	else
		return "Legendary"
	end

end


------------------------------------------------
-- RARITY FLASH
------------------------------------------------

local function RarityFlash(pebble, rarity)

	local flashColor
	local particleAmount
	local flashCount

	if rarity == "Common" then

		flashColor = Color3.fromRGB(255, 255, 255)
		particleAmount = 10
		flashCount = 1

	elseif rarity == "Uncommon" then

		flashColor = Color3.fromRGB(0, 255, 0)
		particleAmount = 15
		flashCount = 1

	elseif rarity == "Rare" then

		flashColor = Color3.fromRGB(0, 150, 255)
		particleAmount = 20
		flashCount = 1

	elseif rarity == "Epic" then

		flashColor = Color3.fromRGB(170, 0, 255)
		particleAmount = 30
		flashCount = 2

	elseif rarity == "Legendary" then

		flashColor = Color3.fromRGB(255, 200, 0)
		particleAmount = 40
		flashCount = 3

	end


	local basePart = pebble:FindFirstChildWhichIsA("BasePart", true)

	if not basePart then
		return
	end


	local attachment = Instance.new("Attachment")
	attachment.Parent = basePart


	local particles = Instance.new("ParticleEmitter")

	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Color = ColorSequence.new(flashColor)

	particles.LightEmission = 0.7
	particles.LightInfluence = 0

	particles.Lifetime = NumberRange.new(0.8, 1.3)
	particles.Speed = NumberRange.new(5, 12)

	particles.SpreadAngle = Vector2.new(360, 360)

	particles.Rate = 0

	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0)
	})

	particles.Parent = attachment


	local light = Instance.new("PointLight")

	light.Color = flashColor
	light.Brightness = 0
	light.Range = 0

	light.Parent = basePart


	for i = 1, flashCount do

		particles:Emit(particleAmount)

		light.Brightness = 4
		light.Range = 12

		task.wait(0.12)

		light.Brightness = 1
		light.Range = 6

		task.wait(0.25)

	end


	task.wait(0.5)

	particles:Destroy()
	attachment:Destroy()
	light:Destroy()

end


------------------------------------------------
-- SPIN ANIMATION
------------------------------------------------

local function StartIdleAnimation(pebble)

	if idleConnection then
		idleConnection:Disconnect()
	end


	idleConnection = RunService.Heartbeat:Connect(function(deltaTime)

		if not pebble or not pebble.Parent then

			idleConnection:Disconnect()
			idleConnection = nil

			return
		end


		local currentPivot = pebble:GetPivot()

		pebble:PivotTo(
			currentPivot *
				CFrame.Angles(
					0,
					math.rad(45) * deltaTime,
					0
				)
		)

	end)

end


------------------------------------------------
-- START ROLL
------------------------------------------------

active.Triggered:Connect(function(player)

	------------------------------------------------
	-- CHECK IF ALREADY ROLLING
	------------------------------------------------

	if rolling then
		return
	end


	------------------------------------------------
	-- GET PLAYER MONEY
	------------------------------------------------

	local money = player.leaderstats.Money


	------------------------------------------------
	-- CHECK MONEY
	------------------------------------------------

	if money.Value < 500 then

		print("Not enough money")

		return
	end


	------------------------------------------------
	-- TAKE MONEY
	------------------------------------------------

	money.Value -= 500

	print("Money remaining: " .. money.Value)


	------------------------------------------------
	-- LOCK ROLL
	------------------------------------------------

	rolling = true


	------------------------------------------------
	-- CREATE PEBBLE
	------------------------------------------------

	local new_Pebble = PebbleModel:Clone()

	current_Pebble = new_Pebble


	local startPosition = active.Parent.Position

	local finalPosition = Vector3.new(
		-649.803894,
		20,
		77.782669
	)


	------------------------------------------------
	-- PUT PEBBLE AT BUTTON
	------------------------------------------------

	new_Pebble:PivotTo(
		CFrame.new(startPosition)
	)


	------------------------------------------------
	-- MAKE BLACK
	------------------------------------------------

	for _, part in new_Pebble:GetDescendants() do

		if part:IsA("BasePart") then

			part.Color = Color3.fromRGB(0, 0, 0)
			part.Anchored = true

		end

	end


	------------------------------------------------
	-- WHITE OUTLINE
	------------------------------------------------

	local highlight = Instance.new("Highlight")

	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineTransparency = 0

	highlight.Parent = new_Pebble


	------------------------------------------------
	-- PUT INTO WORKSPACE
	------------------------------------------------

	new_Pebble.Parent = game.Workspace


	------------------------------------------------
	-- RISE ONCE
	------------------------------------------------

	local startCFrame = new_Pebble:GetPivot()

	local startRotation =
		startCFrame - startCFrame.Position


	local riseTime = 0.7
	local startTime = tick()


	while tick() - startTime < riseTime do

		if not new_Pebble or not new_Pebble.Parent then
			return
		end


		local progress =
			(tick() - startTime) / riseTime


		progress =
			1 - (1 - progress) ^ 3


		local position =
			startCFrame.Position:Lerp(
				finalPosition,
				progress
			)


		new_Pebble:PivotTo(
			CFrame.new(position) *
				startRotation
		)


		RunService.Heartbeat:Wait()

	end


	------------------------------------------------
	-- FINISH RISE
	------------------------------------------------

	new_Pebble:PivotTo(
		CFrame.new(finalPosition) *
			startRotation
	)


	------------------------------------------------
	-- START SPINNING
	------------------------------------------------

	StartIdleAnimation(new_Pebble)


	------------------------------------------------
	-- 10 ROLL SEQUENCE
	------------------------------------------------

	for p = 1, 10 do

		local random_number


		if p < 10 then

			random_number =
				math.random(1, 10)

		else

			random_number =
				GetLuckyPebble()

		end


		------------------------------------------------
		-- KEEP BLACK
		------------------------------------------------

		for _, part in new_Pebble:GetDescendants() do

			if part:IsA("BasePart") then

				part.Color =
					Color3.fromRGB(0, 0, 0)

			end

		end


		------------------------------------------------
		-- WAIT
		------------------------------------------------

		task.wait(0.5)


		------------------------------------------------
		-- FINAL RESULT
		------------------------------------------------

		if p == 10 then

			------------------------------------------------
			-- REVEAL COLOR
			------------------------------------------------

			for _, part in new_Pebble:GetDescendants() do

				if part:IsA("BasePart") then

					part.Color =
						new_Pebblecolors[random_number]

				end

			end


			------------------------------------------------
			-- REMOVE OUTLINE
			------------------------------------------------

			highlight:Destroy()


			------------------------------------------------
			-- GET RARITY
			------------------------------------------------

			local rarity =
				GetRarity(
					PebbleLuck[random_number]
				)


			print("You got: " .. rarity)


			------------------------------------------------
			-- FLASH
			------------------------------------------------

			RarityFlash(
				new_Pebble,
				rarity
			)


			------------------------------------------------
			-- CLAIM PROMPT
			------------------------------------------------

			active.Enabled = false


			local prompt =
				Instance.new("ProximityPrompt")


			prompt.ActionText = "Claim"
			prompt.ObjectText = "Reward"

			prompt.RequiresLineOfSight = false
			prompt.MaxActivationDistance = 20


			for _, part in new_Pebble:GetDescendants() do

				if part:IsA("BasePart") then

					prompt.Parent = part

					break

				end

			end


			------------------------------------------------
			-- CLAIM
			------------------------------------------------

			prompt.Triggered:Connect(function()

				if current_Pebble then

					print("claimed")


					if idleConnection then

						idleConnection:Disconnect()
						idleConnection = nil

					end


					current_Pebble:Destroy()

					current_Pebble = nil

					rolling = false

					active.Enabled = true

				end

			end)

		end

	end

end)