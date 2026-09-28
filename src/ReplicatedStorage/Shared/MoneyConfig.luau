--!strict
--[[
	MoneyConfig

	Floating pickups scattered over the lake. A skip collects anything within
	CollectRadius of where the rock touched down, so aiming through a cluster
	is worth more than a blind long throw.
]]

local MoneyConfig = {}

MoneyConfig.Tag = "MoneyPickup"

-- ============================================================================
-- Population
-- ============================================================================
MoneyConfig.TargetCount = 940    -- pickups live on the lake at once
MoneyConfig.MinSpacing = 14      -- studs; stops them clumping on top of each other
MoneyConfig.RespawnDelay = 24    -- seconds before a collected pickup returns elsewhere

-- ============================================================================
-- Where they are allowed to spawn
--
-- The open water is found at runtime by raycasting a grid downward and keeping
-- only the cells that land on the lake, so this adapts to the map's walls
-- instead of hardcoding a rectangle that would drop money inside geometry.
-- Offsets are relative to the SpawnLocation.
-- ============================================================================
MoneyConfig.SampleStep = 16      -- finer grid = more candidate cells to fill
MoneyConfig.SampleMinX = -220
MoneyConfig.SampleMaxX = 1500
-- Narrowed from +/-420. Throws travel in a straight line, so money spread
-- across the full width of the lake is mostly unreachable; concentrating it
-- near the lane raises density where throws actually go. The near pond is
-- only ~200 studs wide anyway, so this still covers it.
MoneyConfig.SampleMinZ = -300
MoneyConfig.SampleMaxZ = 300
MoneyConfig.SampleRayHeight = 70 -- how far above the surface each probe starts

-- ============================================================================
-- Hover motion (animated on the client; the server never touches these
-- per-frame, it only places them once)
-- ============================================================================
MoneyConfig.HoverHeight = 2.8    -- studs above the water surface
MoneyConfig.BobAmplitude = 0.55
MoneyConfig.BobSpeed = 1.7       -- radians/sec
MoneyConfig.SpinSpeed = 1.15     -- radians/sec

-- ============================================================================
-- Collection
-- ============================================================================
-- A skip sweeps a corridor 2x this wide. At 17 that was 34 studs out of an
-- 832-stud spread -- about 4% of the money was reachable by any one throw,
-- so raising the pickup count alone changed almost nothing per throw.
MoneyConfig.CollectRadius = 30   -- studs from a skip's touchdown point

-- ============================================================================
-- Client animation budget
--
-- At this density most pickups are far off down the lane and invisible, so
-- bob/spin is only applied near the camera. Without this every pickup costs a
-- CFrame write every frame whether or not anyone can see it.
-- ============================================================================
MoneyConfig.AnimateRadius = 320  -- studs from the camera

-- ============================================================================
-- Value and rarity
-- ============================================================================
MoneyConfig.GoldChance = 0.025   -- fraction of pickups that are gold bars
MoneyConfig.CashValueMin = 3
MoneyConfig.CashValueMax = 7
MoneyConfig.GoldValueMin = 25
MoneyConfig.GoldValueMax = 45
MoneyConfig.RampEndStuds = 1400
MoneyConfig.RampStartMultiplier = 0.55
MoneyConfig.RampEndMultiplier = 2.35

-- ============================================================================
-- Look. Fill is Neon so the whole pickup glows; the border is a SelectionBox,
-- which draws the box edges as bright lines -- a real neon rim for one extra
-- instance and no per-frame cost.
-- ============================================================================
MoneyConfig.Cash = {
	Size = Vector3.new(0.18, 1.5, 3.0),
	FillColor = Color3.fromRGB(34, 150, 76),
	EdgeColor = Color3.fromRGB(130, 255, 175),
	EdgeThickness = 0.045,
	Transparency = 0.12,
}

MoneyConfig.Gold = {
	Size = Vector3.new(0.85, 0.95, 2.3),
	FillColor = Color3.fromRGB(196, 145, 26),
	EdgeColor = Color3.fromRGB(255, 235, 130),
	EdgeThickness = 0.06,
	Transparency = 0,
	LightColor = Color3.fromRGB(255, 205, 90),
	LightBrightness = 2.2,
	LightRange = 15,
}

function MoneyConfig.rollValue(isGold: boolean, distance: number?): number
 local ZoneConfig=require(script.Parent.ZoneConfig)
 local zone=ZoneConfig.forDistance(distance or 0)
 local base=if isGold then math.random(MoneyConfig.GoldValueMin,MoneyConfig.GoldValueMax) else math.random(MoneyConfig.CashValueMin,MoneyConfig.CashValueMax)
 local tier=math.max(1,(zone.moneyPerStud or .18)/.18)
 return math.max(1,math.floor(base*tier+.5))
end

return MoneyConfig
