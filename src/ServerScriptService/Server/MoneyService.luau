--!strict
--[[
	MoneyService (server)

	Owns the floating pickups: where they may exist, what they are worth, and
	who collected what. Awards straight into player.leaderstats.Money, which
	is what the MainHUD stat chip already watches, so the bottom-left counter
	updates itself.

	Collection is server-side and driven by the flight positions ThrowService
	reports, so a client cannot claim money it did not fly over -- the same
	reason distance and skip count are measured rather than reported.

	Open water is discovered by raycasting a grid downward and keeping the
	cells that land on the lake. The pond is walled and only one heading has a
	long lane, so a hardcoded rectangle would bury money inside geometry.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ThrowConfig = require(Shared:WaitForChild("ThrowConfig"))
local MoneyConfig = require(Shared:WaitForChild("MoneyConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Profiles = require(script.Parent:WaitForChild("Profiles"))

local MoneyService = {}
local ZoneConfig=require(Shared:WaitForChild("ZoneConfig"))
local WaterSurface=require(Shared:WaitForChild("WaterSurface"))
local Shore=require(Shared:WaitForChild("RiverlandsShoreProfile"))
local flightProgress: {[Player]: any}={}
local notifyCollected: any
local function eventMultiplier(): number
 local value=workspace:GetAttribute("GlobalMoneyMultiplier")
 return if typeof(value)=="number" then math.clamp(value,1,2) else 1
end
function MoneyService.beginThrow(player: Player, origin: Vector3)
 flightProgress[player]={progress=ZoneConfig.distanceAt(origin),owed=0,lastPaid=0}
end
function MoneyService.endThrow(player: Player)
 local state=flightProgress[player]
 flightProgress[player]=nil
 if state and state.owed>=1 and state.position and Profiles.get(player).loaded then
  local total=math.floor(state.owed)
  Profiles.addMoney(player,total)
  notifyCollected(player,total,0,0)
  Remotes.MoneyCollected:FireClient(player,player.UserId,{{p=state.position,v=total,g=false,source="distance"}},total)
 end
end
-- Only new forward progress earns distance cash. Steering circles cannot farm it.
local function collectDistance(player: Player,position: Vector3,moneyMul: number?)
 local state=flightProgress[player]
 if not state or not Profiles.get(player).loaded or not WaterSurface.at(position) then return end
 local progress=math.min(ZoneConfig.distanceAt(position),ZoneConfig.List[#ZoneConfig.List].finish)
 if progress<=state.progress then return end
 local previous=state.progress
 state.progress=progress
 state.position=position
 local earned=0
 for _,zone in ipairs(ZoneConfig.List) do
  local span=math.max(0,math.min(progress,zone.finish)-math.max(previous,zone.start))
  earned+=span*(zone.moneyPerStud or .18)
 end
 local multiplier=if type(moneyMul)=="number" and moneyMul==moneyMul then math.clamp(moneyMul,1,100) else 1
 state.owed+=earned*multiplier*eventMultiplier()
 if os.clock()-state.lastPaid<.3 then return end
 local total=math.floor(state.owed)
 if total<=0 then return end
 state.owed-=total
 state.lastPaid=os.clock()
 Profiles.addMoney(player,total)
 notifyCollected(player,total,0,0)
 Remotes.MoneyCollected:FireClient(player,player.UserId,{{p=position,v=total,g=false,source="distance"}},total)
end

-- Fired after a successful collection, so quests and stats can watch money
-- without MoneyService knowing either exists.
type CollectedListener = (player: Player, total: number, count: number, goldCount: number) -> ()
local collectedListeners: {CollectedListener} = {}
notifyCollected=function(player: Player,total: number,count: number,gold: number)
 for _,listener in collectedListeners do
  local ok,err=pcall(listener,player,total,count,gold)
  if not ok then warn("[MoneyService] collected listener failed: "..tostring(err)) end
 end
end

function MoneyService.onCollected(listener: CollectedListener)
	table.insert(collectedListeners, listener)
end

type Pickup = {
	part: BasePart,
	position: Vector3,
	value: number,
	isGold: boolean,
}

local pickups: {[BasePart]: Pickup} = {}
local openSpots: {Vector3} = {}
local folder: Folder
local spawnOrigin = Vector3.zero

--[[
	Spatial grid, so collection can run every frame of every flight instead of
	only at skip touchdowns. A flat scan would be ~500 distance checks per
	rock per frame; bucketing by cell means checking only the 3x3 cells around
	the rock, which is a handful. CELL must be >= CollectRadius so that 3x3
	always fully contains the collect circle.
]]
local CELL = 70
local buckets: {[number]: {[BasePart]: Pickup}} = {}

local function cellKey(x: number, z: number): number
	-- Cantor-ish pack into one number; cheaper to hash than a string key.
	return math.floor(x / CELL) * 100000 + math.floor(z / CELL)
end

local function bucketInsert(pickup: Pickup)
	local key = cellKey(pickup.position.X, pickup.position.Z)
	local bucket = buckets[key]
	if not bucket then
		bucket = {}
		buckets[key] = bucket
	end
	bucket[pickup.part] = pickup
end

-- ============================================================================
-- Finding open water
-- ============================================================================

local function findOpenSpots(): {Vector3}
 local spawn=workspace:FindFirstChildWhichIsA("SpawnLocation",true)
 spawnOrigin=spawn and spawn.Position or Vector3.zero
 local params=RaycastParams.new()
 params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances={folder}
 params.RespectCanCollide=false
 local found: {Vector3}={}
 -- Arc, diagonal, alternating-side and fork patterns cover the real shoreline.
 local rng=Random.new(271927)
 for tier,zone in ipairs(ZoneConfig.List) do
  local step=math.max(24,(zone.finish-zone.start)/70)
  local row=0
  for distance=zone.start+65,zone.finish-65,step do
   row+=1
   local x=ZoneConfig.OriginX+distance
   local left,right=Shore.at(x,-1)+24,Shore.at(x,1)-24
   local mode=(math.floor((row-1)/5)+tier)%5
   local t=((row-1)%5)/4
   local lane=if mode==0 then -.72 elseif mode==1 then .72 elseif mode==2 then -0.8+1.6*t elseif mode==3 then math.sin(t*math.pi)*.72-.36 else (row%2==0 and -.5 or .5)
   for j=1,3 do
    local u=math.clamp(lane+(j-2)*.18+rng:NextNumber(-.05,.05),-.9,.9)
    if mode==4 and j==3 then u=-lane end
    local point=Vector3.new(x+rng:NextNumber(-4,4),0,(left+right)*.5+u*(right-left)*.5)
    local surfaceY,water=WaterSurface.at(point)
    if surfaceY and water then
     local probe=Vector3.new(point.X,surfaceY+MoneyConfig.SampleRayHeight,point.Z)
     local hit=workspace:Raycast(probe,Vector3.new(0,-MoneyConfig.SampleRayHeight*2,0),params)
     if hit and hit.Instance==water then table.insert(found,Vector3.new(point.X,surfaceY+MoneyConfig.HoverHeight,point.Z)) end
    end
   end
   if row%16==0 then task.wait() end
  end
 end
 return found
end

-- ============================================================================
-- Building a pickup
-- ============================================================================

local function buildPickup(position: Vector3, isGold: boolean): BasePart
	local style = if isGold then MoneyConfig.Gold else MoneyConfig.Cash

	local part = Instance.new("Part")
	part.Name = if isGold then "GoldBar" else "Cash"
	part.Size = style.Size
	part.Material = if isGold then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Color = style.FillColor
	part.Transparency = 1 -- invisible authoritative marker; pooled 3D client art
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false -- keeps pickups out of the throw's solid-hit raycast
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = CFrame.new(position)


	-- The client animates around this, so the bob and spin cost the server
	-- nothing and never replicate.
	part:SetAttribute("BasePos", position)
	part:SetAttribute("Phase", math.random() * math.pi * 2)
	part:SetAttribute("IsGold", isGold)

	part.Parent = folder
	CollectionService:AddTag(part, MoneyConfig.Tag)
	return part
end

-- Grid-based, because this runs up to 12 times per spawn and there are
-- hundreds of pickups: a flat scan made startup do well over a million
-- distance checks. MinSpacing is far below CELL, so the 3x3 neighbourhood is
-- more than enough to see every pickup that could be too close.
local function isFarEnough(position: Vector3): boolean
	local minSq = MoneyConfig.MinSpacing * MoneyConfig.MinSpacing
	local baseX = math.floor(position.X / CELL)
	local baseZ = math.floor(position.Z / CELL)
	for dx = -1, 1 do
		for dz = -1, 1 do
			local bucket = buckets[(baseX + dx) * 100000 + (baseZ + dz)]
			if bucket then
				for _, pickup in bucket do
					local dX = pickup.position.X - position.X
					local dZ = pickup.position.Z - position.Z
					if dX * dX + dZ * dZ < minSq then
						return false
					end
				end
			end
		end
	end
	return true
end

-- Cache encounter circles once and index every cell they touch. Runtime spawn
-- candidates query one bucket, never rescan every model/GetExtentsSize.
local obstacleCells: {[number]: {[Instance]: any}}={}
local obstacleRecords: {[Instance]: any}={}
local function removeObstacle(model: Instance)
 local record=obstacleRecords[model]
 if not record then return end
 for _,key in record.keys do
  local bucket=obstacleCells[key]
  if bucket then bucket[model]=nil;if next(bucket)==nil then obstacleCells[key]=nil end end
 end
 for _,connection in record.connections do connection:Disconnect() end
 obstacleRecords[model]=nil
end
local indexObstacle: (Instance)->()
indexObstacle=function(model: Instance)
 removeObstacle(model)
 if not model:IsDescendantOf(workspace) or not (model:IsA("Model") or model:IsA("BasePart")) then return end
 if not CollectionService:HasTag(model,"WaterPickup") and not CollectionService:HasTag(model,"SkipObstacle") then return end
 local cf=model:GetAttribute("PickupBase") or model:GetPivot()
 local size=if model:IsA("Model") then model:GetExtentsSize() else model.Size
 local radius=math.max(size.X,size.Z)*.5+10
 local record={position=cf.Position,radiusSq=radius*radius,keys={},connections={}}
 obstacleRecords[model]=record
 for x=math.floor((cf.Position.X-radius)/CELL),math.floor((cf.Position.X+radius)/CELL) do
  for z=math.floor((cf.Position.Z-radius)/CELL),math.floor((cf.Position.Z+radius)/CELL) do
   local key=x*100000+z
   obstacleCells[key]=obstacleCells[key] or {}
   obstacleCells[key][model]=record;table.insert(record.keys,key)
  end
 end
 table.insert(record.connections,model:GetAttributeChangedSignal("PickupBase"):Connect(function() indexObstacle(model) end))
end
local function prepareObstacleIndex()
 local seen={}
 for _,tag in {"WaterPickup","SkipObstacle"} do
  for _,model in CollectionService:GetTagged(tag) do if not seen[model] then seen[model]=true;indexObstacle(model) end end
  CollectionService:GetInstanceAddedSignal(tag):Connect(indexObstacle)
  CollectionService:GetInstanceRemovedSignal(tag):Connect(indexObstacle)
 end
end
local clearance=OverlapParams.new()
clearance.FilterType=Enum.RaycastFilterType.Exclude
local function spotClear(position: Vector3): boolean
 local d=ZoneConfig.distanceAt(position)
 for _,zone in ipairs(ZoneConfig.List) do
  if math.abs(d-zone.start)<36 or math.abs(d-zone.finish)<36 then return false end
 end
 clearance.FilterDescendantsInstances={folder}
 for _,part in workspace:GetPartBoundsInBox(CFrame.new(position),Vector3.new(12,14,12),clearance) do
  if not CollectionService:HasTag(part,WaterSurface.Tag) and part.Transparency<.95
    and (part.CanCollide or part.Size.Magnitude>10) then return false end
 end
 -- Includes invisible targets and de-duplicates models with both tags.
 local obstacles=obstacleCells[cellKey(position.X,position.Z)]
 if obstacles then
  for model,record in obstacles do
   if model:IsDescendantOf(workspace) then
    local delta=record.position-position
    if delta.X*delta.X+delta.Z*delta.Z<record.radiusSq then return false end
   end
  end
 end
 return true
end

local function spawnOne(): boolean
	if #openSpots == 0 then
		return false
	end
	-- A handful of tries is enough; failing just means the lake is dense here
	-- and we will try again on the next respawn.
	for _ = 1, 12 do
		local candidate = openSpots[math.random(1, #openSpots)]
		if isFarEnough(candidate) and spotClear(candidate) then
			local isGold = math.random() < MoneyConfig.GoldChance
			local distance = ZoneConfig.distanceAt(candidate)
			local part = buildPickup(candidate, isGold)
			local pickup: Pickup = {
				part = part,
				position = candidate,
				value = MoneyConfig.rollValue(isGold, distance),
				isGold = isGold,
			}
			pickups[part] = pickup
			bucketInsert(pickup)
			return true
		end
	end
	return false
end

local function countPickups(): number
	local n = 0
	for _ in pickups do
		n += 1
	end
	return n
end

local function topUp()
	local deficit = MoneyConfig.TargetCount - countPickups()
 local started=os.clock()
 for i = 1, math.max(deficit, 0) do
  spawnOne()
  if i%24==0 then task.wait() end -- bounded work per startup frame
 end
 folder:SetAttribute("InitialFillMs",(os.clock()-started)*1000)
 folder:SetAttribute("InitialCount",countPickups())
end

-- ============================================================================
-- Collection
-- ============================================================================

-- Routed through Profiles rather than poking leaderstats directly, so
-- lifetime money is tracked in one place.
local function awardMoney(player: Player, amount: number)
	Profiles.addMoney(player, amount)
end

-- Called only by server-validated encounter hits. Keep obstacle payouts on the
-- same profile and client feedback path as lake pickups.
function MoneyService.awardObstacle(player: Player, amount: number, position: Vector3, moneyMul: number?): number
	if not player.Parent then return 0 end
	local total = math.clamp(math.floor(amount * (moneyMul or 1) * eventMultiplier()), 0, 100000)
	if total <= 0 then return 0 end
	awardMoney(player, total)
 notifyCollected(player,total,0,0)
	Remotes.MoneyCollected:FireAllClients(player.UserId, {{p = position, v = total, g = false, source = "obstacle"}}, total)
	return total
end

--[[
	Called for every step of every flight, not just at skip touchdowns.

	Collection used to fire only on skips, but once the bounce arcs were
	retuned to be visibly big, skips ended up ~140 studs apart -- so a throw
	sampled a few isolated circles instead of sweeping its path, and claimed
	almost nothing. Running it per-step means the rock vacuums up whatever it
	flies over, which is both what players expect and far more generous.
]]
function MoneyService.collectAt(
	player: Player,
	position: Vector3,
	moneyMul: number?,
	magnetBonus: number?,
	luckBonus: number?
)
 collectDistance(player,position,moneyMul)
	-- Magnet widens the sweep. Clamped so a fully upgraded player cannot
	-- exceed the 3x3 cell neighbourhood the grid lookup checks.
	local radius = math.min(MoneyConfig.CollectRadius + (magnetBonus or 0), CELL)
	local radiusSq = radius * radius
	local collected = nil
	local total = 0

	local baseX = math.floor(position.X / CELL)
	local baseZ = math.floor(position.Z / CELL)

	for dx = -1, 1 do
		for dz = -1, 1 do
			local bucket = buckets[(baseX + dx) * 100000 + (baseZ + dz)]
			if bucket then
				for part, pickup in bucket do
					-- Horizontal distance: pickups hover above the surface, so
					-- including the vertical gap would make them harder to
					-- claim the higher they sit.
					local dX = pickup.position.X - position.X
					local dZ = pickup.position.Z - position.Z
					if dX * dX + dZ * dZ <= radiusSq then
						bucket[part] = nil
						pickups[part] = nil

						--[[
							Luck is applied HERE, not at spawn. Whether a
							pickup is a gold bar is decided when it is placed,
							long before anyone collects it, so a per-player
							luck stat cannot influence it. Instead luck gives
							cash a chance to pay out as gold on pickup -- a
							"lucky strike" -- which is per-player, cannot be
							farmed by waiting, and needs no extra state.
						]]
						local value = pickup.value
						local isGold = pickup.isGold
						if not isGold and luckBonus and luckBonus > 0 and math.random() < luckBonus then
							isGold = true
							value = MoneyConfig.rollValue(true, ZoneConfig.distanceAt(pickup.position))
						end

						total += value
						collected = collected or {}
						table.insert(collected, {
							p = pickup.position,
							v = value,
							g = isGold,
                            source = "pickup",
                            target = position,
						})
						part:Destroy()
					end
				end
			end
		end
	end

	if not collected then
		return
	end

	-- The equipped rock can multiply takings; rounded once on the total so
	-- the number the player sees matches what they are actually paid.
	total = math.floor(total * (moneyMul or 1) * eventMultiplier())

	awardMoney(player, total)
	Remotes.MoneyCollected:FireAllClients(player.UserId, collected, total)

	local goldCount = 0
	for _, entry in collected do
		if entry.g then
			goldCount += 1
		end
	end
	for _, listener in collectedListeners do
		local ok, err = pcall(listener, player, total, #collected, goldCount)
		if not ok then
			warn("[MoneyService] collected listener failed: " .. tostring(err))
		end
	end

	-- Put the same number back elsewhere on the lake after a delay, so the
	-- water does not slowly empty out over a session.
	local count = #collected
	task.delay(MoneyConfig.RespawnDelay, function()
		for _ = 1, count do
			spawnOne()
		end
	end)
end

-- ============================================================================
-- Wiring
-- ============================================================================

function MoneyService.start()
 Players.PlayerRemoving:Connect(function(player) flightProgress[player]=nil end)
	folder = Instance.new("Folder")
	folder.Name = "MoneyPickups"
	folder.Parent = workspace

 prepareObstacleIndex()
	openSpots = findOpenSpots()
	if #openSpots == 0 then
		warn("[MoneyService] found no open water; no money will spawn")
		return
	end
	print(string.format("[MoneyService] %d open water cells found", #openSpots))

	topUp()

	local function ensureStats(player: Player)
		-- Leaderstats is created by a separate script; if a pickup is claimed
		-- before it exists the award would silently vanish.
		task.spawn(function()
			for _ = 1, 50 do
				if player:FindFirstChild("leaderstats") then
					return
				end
				task.wait(0.1)
			end
		end)
	end

	Players.PlayerAdded:Connect(ensureStats)
	for _, player in Players:GetPlayers() do
		ensureStats(player)
	end
end

return MoneyService

