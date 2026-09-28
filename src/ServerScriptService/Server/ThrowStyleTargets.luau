--!strict
-- Optional lane challenges. Swept server crossings award run score once per
-- gate, without changing distance records, skips, currency or progression.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WaterSurface = require(ReplicatedStorage.Shared.WaterSurface)

local Players=game:GetService("Players")
local MoneyService=require(script.Parent.MoneyService)
local Profiles=require(script.Parent.Profiles)local Targets = {}
local gates: {[BasePart]: boolean} = {}
local visited: {[Model]: {[BasePart]: boolean}} = {}
local started = false
local TAG = "PebbleStyleGate"

local function track(instance: Instance)
	if instance:IsA("BasePart") then gates[instance] = true end
end

function Targets.start()
	if started then return end
	started = true
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
		if instance:IsA("BasePart") then gates[instance] = nil end
	end)
	for _, item in CollectionService:GetTagged(TAG) do track(item) end
	if workspace:FindFirstChild("PebbleStyleGates") then return end
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation")
	if not spawn then return end
	local folder = Instance.new("Folder")
	folder.Name = "PebbleStyleGates"
	folder.Parent = workspace
	-- This lake's long axis runs east from the starting platform.
	for index, distance in {160,300,480} do
		local at = spawn.Position+Vector3.new(distance,0,0)
		local waterY = WaterSurface.at(at)
		if not waterY then continue end
		local center = Vector3.new(at.X,waterY+3.5,at.Z)
		local gate = Instance.new("Part")
		gate.Name = "StyleGate"..index
		gate.Anchored=true; gate.CanCollide=false; gate.CanTouch=false; gate.CanQuery=false
		gate.Transparency=1; gate.CastShadow=false; gate.Size=Vector3.new(13,8,0.3)
		gate.CFrame=CFrame.lookAt(center,center+Vector3.xAxis)
		gate:SetAttribute("StylePoints",index*75)
		gate.Parent=folder
		local last: Attachment? = nil
		for i=0,24 do
			local angle=i/24*math.pi*2
			local point=Instance.new("Attachment")
			point.Position=Vector3.new(math.cos(angle)*6.5,math.sin(angle)*4,0)
			point.Parent=gate
			if last then
				local beam=Instance.new("Beam")
				beam.Attachment0=last;beam.Attachment1=point
				beam.Width0=0.13;beam.Width1=0.13;beam.FaceCamera=true
				beam.Color=ColorSequence.new(Color3.fromRGB(120,235,222))
				beam.LightEmission=0.5;beam.Transparency=NumberSequence.new(0.4);beam.Parent=gate
			end
			last=point
		end
		local gui=Instance.new("BillboardGui")
		gui.Name="StyleGateLabel";gui.Size=UDim2.fromOffset(160,24)
		gui.StudsOffsetWorldSpace=Vector3.new(0,5.2,0);gui.MaxDistance=150;gui.Parent=gate
		local label=Instance.new("TextLabel")
		label.Size=UDim2.fromScale(1,1);label.BackgroundTransparency=1
		label.Font=Enum.Font.GothamBold;label.TextSize=12
		label.TextColor3=Color3.fromRGB(180,255,238);label.TextStrokeTransparency=0.45
		label.Text="STYLE +"..index*75;label.Parent=gui
		CollectionService:AddTag(gate,TAG)
	end
end

function Targets.step(pebble: Model, from: Vector3, to: Vector3)
	local seen=visited[pebble]
	if not seen then seen={};visited[pebble]=seen end
	local delta=to-from
	if delta.Magnitude<0.001 then return end
	for gate in gates do
		if seen[gate] or not gate:IsDescendantOf(workspace) then continue end
		if (gate.Position-from).Magnitude>delta.Magnitude+gate.Size.Magnitude then continue end
		local a,b=gate.CFrame:PointToObjectSpace(from),gate.CFrame:PointToObjectSpace(to)
		if a.Z*b.Z>0 or math.abs(b.Z-a.Z)<0.0001 then continue end
		local alpha=-a.Z/(b.Z-a.Z)
		if alpha<0 or alpha>1 then continue end
		local contact=a:Lerp(b,alpha)
		-- The visible ellipse and scoring aperture agree.
		if (contact.X/(gate.Size.X*0.5))^2+(contact.Y/(gate.Size.Y*0.5))^2>1 then continue end
		seen[gate]=true
		local raw=gate:GetAttribute("StylePoints")
		local points=if typeof(raw)=="number" and raw==raw then math.clamp(math.floor(raw),0,500) else 75
		pebble:SetAttribute("StyleScore",(pebble:GetAttribute("StyleScore") or 0)+points)
		pebble:SetAttribute("LastStyleGate",gate.Name)

		local reward=gate:GetAttribute("CashReward")
		if typeof(reward)=="number" and reward>0 then
			local player=Players:GetPlayerByUserId(pebble:GetAttribute("ThrowerUserId") or 0)
			if player then
				MoneyService.awardObstacle(player,math.clamp(reward,0,10000),gate.Position,1+Profiles.modifiers(player).moneyMul)
			end
		end
		local boost=gate:GetAttribute("BoostFactor")
		if typeof(boost)=="number" and boost>1 then
			local part=pebble.PrimaryPart
			if part then
				local v=part.AssemblyLinearVelocity
				part.AssemblyLinearVelocity=Vector3.new(v.X*math.clamp(boost,1,1.18),v.Y,v.Z*math.clamp(boost,1,1.18))
			end
		end
	end
end

function Targets.finish(pebble: Model)
	visited[pebble]=nil
end
return Targets