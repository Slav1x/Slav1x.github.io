--!nonstrict
-- Client-only motion for the existing tagged water parts. Their size, height and collision stay server-owned.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local player = Players.LocalPlayer
local Water=require(game.ReplicatedStorage.Shared.WaterSurface)
local Shore=require(game.ReplicatedStorage.Shared.RiverlandsShoreProfile)
local spawn = workspace:WaitForChild("SpawnLocation")
local widenedLake = workspace:WaitForChild("terrain"):FindFirstChild("LakeWidening_20260925")

local function bankShiftAt(x)
 if not widenedLake then return 0 end
 local startX = widenedLake:GetAttribute("TransitionStartX") or -307
 local endX = widenedLake:GetAttribute("TransitionEndX") or -107
 local amount = widenedLake:GetAttribute("BankShiftPerSide") or 0
 local t = math.clamp((x - startX) / math.max(endX - startX, 1), 0, 1)
 return amount * t * t * (3 - 2 * t)
end

local WATER_TAG = "SkippingWater"
local TICK = 0.10
local FOAM_COLOR = Color3.fromRGB(226, 247, 249)

local folder = Instance.new("Folder")
folder.Name = "LocalWaterMotion"
folder.Parent = workspace

local waterParts = {}
local firstEdge = math.huge
local lastEdge = -math.huge
local surfaceY = 15.09

local function addWater(p)
 if not p:IsA("BasePart") or waterParts[p] then return end
 waterParts[p] = true
 firstEdge = math.min(firstEdge, p.Position.X - p.Size.X * 0.5)
 lastEdge = math.max(lastEdge, p.Position.X + p.Size.X * 0.5)
 surfaceY = p:GetAttribute("SurfaceY") or (p.Position.Y + p.Size.Y * 0.5)
end

for _, p in CollectionService:GetTagged(WATER_TAG) do addWater(p) end
local added = CollectionService:GetInstanceAddedSignal(WATER_TAG):Connect(addWater)
local removed = CollectionService:GetInstanceRemovedSignal(WATER_TAG):Connect(function(p)
 waterParts[p] = nil
end)

local function makeFoam(name, size)
 local p = Instance.new("Part")
 p.Name = name
 p.Size = size
 p.Anchored = true
 p.CanCollide = false
 p.CanTouch = false
 p.CanQuery = false
 p.CastShadow = false
 p.Material = Enum.Material.SmoothPlastic
 p.Color = FOAM_COLOR
 p.Transparency = 1
 p.Parent = folder
 return p
end

-- These crests cross the near shore where players stand, then dissolve before restarting.
local front = {}
for row = 1, 3 do
 for i = 1, 8 do
  local length = 12 + ((i * 5 + row * 3) % 5) * 2.1
  local z = spawn.Position.Z + (i - 4.5) * 19 + math.sin(i * 1.7 + row) * 1.6
  front[#front + 1] = {
   part = makeFoam("ShoreCrest", Vector3.new(0.55 + (i % 3) * 0.13, 0.035, length)),
   row = row, i = i, z = z,
   angle = math.rad(math.sin(i * 1.4 + row) * 7),
  }
 end
end

-- Side-bank foam follows the camera in a small fixed pool as a long throw travels down the lake.
local banks = {}
for _, side in {-1, 1} do
 for row = 1, 2 do
  for i = 1, 6 do
   banks[#banks + 1] = {
    part = makeFoam("BankCrest", Vector3.new(14 + ((i + row) % 4) * 2.5, 0.035, 0.45 + (i % 3) * 0.15)),
    side = side, row = row, i = i,
    angle = math.rad(math.sin(i * 1.8 + side) * 5),
   }
  end
 end
end

-- Short translucent streaks drift over the lake near the active camera.
local wavelets = {}
for i = 1, 72 do
 local p = makeFoam("SurfaceWave", Vector3.new(7 + ((i * 3) % 5) * 2.1, 0.025, 0.13 + (i % 3) * 0.045))
 p.Color = Color3.fromRGB(171, 221, 231)
 wavelets[i] = p
end

-- Area colors share the existing biome palette; particles belong to LakeAmbience.
local Zones=require(game.ReplicatedStorage.Shared.ZoneConfig)
local Biomes=require(game.ReplicatedStorage.Shared.BiomePresentation)
local function styleSurface(p,x)
 local profile=Biomes.sample(math.max(0,x-Zones.OriginX))
 local event=Biomes.event()
 local color=event and profile.water:Lerp(event.color,.22) or profile.water
 p.Color=p.Color:Lerp(color,.22)
 p.Material=(profile.id=='inferno' or profile.id=='cosmic') and Enum.Material.Neon or Enum.Material.SmoothPlastic
 return profile.id
end
local liquidStyles={
 driftwood={pace=1,length=22,width=.28,strength=.26,color=Color3.fromRGB(197,247,247),shape=Enum.PartType.Ball},
 blossom={pace=.65,length=14,width=.32,strength=.24,color=Color3.fromRGB(255,204,223),shape=Enum.PartType.Block},
 candy={pace=.8,length=13,width=.8,strength=.33,color=Color3.fromRGB(255,230,250),shape=Enum.PartType.Ball},
 sunscorch={pace=.55,length=30,width=.16,strength=.3,color=Color3.fromRGB(255,242,179),shape=Enum.PartType.Block},
 frozen={pace=.18,length=15,width=.5,strength=.38,color=Color3.fromRGB(219,249,255),shape=Enum.PartType.Block},
 crystal={pace=.42,length=9,width=.4,strength=.42,color=Color3.fromRGB(183,232,255),shape=Enum.PartType.Block},
 toxic={pace=.48,length=13,width=.65,strength=.38,color=Color3.fromRGB(205,255,109),shape=Enum.PartType.Ball},
 inferno={pace=.22,length=30,width=.8,strength=.5,color=Color3.fromRGB(255,180,53),shape=Enum.PartType.Ball},
 cosmic={pace=.34,length=9,width=.22,strength=.48,color=Color3.fromRGB(207,193,255),shape=Enum.PartType.Ball},
}
local accents={}
for i=1,24 do accents[i]=makeFoam("LiquidAccent",Vector3.one) end
local function nearBoundary(x)
 local d=x-Zones.OriginX
 for _,zone in Zones.List do if math.abs(d-zone.start)<30 or math.abs(d-zone.finish)<30 then return true end end
 return false
end
local startedAt = os.clock()

local elapsed = 0
local connection = RunService.Heartbeat:Connect(function(dt)
 elapsed += dt
 if elapsed < TICK then return end
 elapsed = 0
 local camera = workspace.CurrentCamera
 if not camera then return end
 local cameraX = camera.CFrame.Position.X
 local now = os.clock() - startedAt
 local reduced = player:GetAttribute("ReducedMotion") == true
 local shoreX = firstEdge < math.huge and firstEdge or spawn.Position.X + 101

 local rippleStart = math.max(shoreX + 25, math.floor(cameraX / 48) * 48 + 24)
 for i, p in wavelets do
  local row = math.floor((i - 1) / 9)
  local column = (i - 1) % 9
  local x = rippleStart + row * 52 + math.sin(i * 1.7) * 10
  if x > lastEdge - 15 then
   p.Transparency = 1
  else
   local left,right=Shore.at(x,-1)+18,Shore.at(x,1)-18
   local baseZ=left+(right-left)*(column+.5)/9+math.sin(i*2.3)*6
   local localY=Water.at(Vector3.new(x,0,baseZ))
   if not localY then p.Transparency=1;continue end
   local side = baseZ < spawn.Position.Z and -1 or 1
   local identity=Zones.forDistance(math.max(0,x-Zones.OriginX)).id
   local pace=(liquidStyles[identity] or liquidStyles.driftwood).pace
   local alpha = reduced and 0.5 or (now*pace / 5.6 + i * 0.19) % 1
   local strength = math.sin(alpha * math.pi)
   p.CFrame = CFrame.new(x+(reduced and 0 or alpha*12), localY + 0.07+(reduced and 0 or math.sin(now+i)*.035), baseZ + side * alpha * 3)*CFrame.Angles(0,math.sin(i*2.1)*.12,0)
   local theme=styleSurface(p,x)
   local style=liquidStyles[theme] or liquidStyles.driftwood
   p.Color=p.Color:Lerp(style.color,.35)
   p.Size=Vector3.new(style.length+(i%4)*2,.035,style.width+(i%3)*.045)
   p.Transparency=nearBoundary(x) and 1 or 1-style.strength*strength
   if theme=='inferno' then
    p.CFrame*=CFrame.Angles(0,math.sin(i*1.7)*.3,0)
   elseif theme=='cosmic' then
    p.CFrame*=CFrame.Angles(0,reduced and i*.7 or now*.025+i*.7,0)
   elseif theme=='frozen' or theme=='crystal' then
    p.CFrame=CFrame.new(x,localY+.08,baseZ)*CFrame.Angles(0,i*1.618,0)
   end
  end
 end

 -- A bounded camera-local pool gives each liquid its own three-dimensional detail.
 for i,p in accents do
  local x=math.max(shoreX+35,math.floor(cameraX/60)*60)+math.floor((i-1)/4)*60
  local left,right=Shore.at(x,-1)+30,Shore.at(x,1)-30
  local z=left+(right-left)*(((i-1)%4+.5)/4)
  local y=Water.at(Vector3.new(x,0,z))
  if not y or x>lastEdge-30 or nearBoundary(x) then p.Transparency=1;continue end
  local id=Zones.forDistance(math.max(0,x-Zones.OriginX)).id
  local style=liquidStyles[id] or liquidStyles.driftwood
  local alpha=reduced and .4 or (now*style.pace*.23+i*.173)%1
  local visible=math.sin(alpha*math.pi)
  p.Shape=style.shape;p.Color=style.color
  p.Material=(id=='inferno' or id=='cosmic' or id=='crystal') and Enum.Material.Neon or Enum.Material.SmoothPlastic
  local size,height,drift=1,0,0
  if id=='toxic' then size=1+visible*1.9;height=visible*.6;drift=alpha*2
  elseif id=='inferno' then size=.35+visible*.5;height=alpha*3
  elseif id=='cosmic' then size=.3+visible*.3;height=.5+visible*1.1;drift=math.sin(now*.2+i)*2
  elseif id=='frozen' then size=3+(i%3);height=.04
  elseif id=='crystal' then size=.7+visible*.3;height=.2
  elseif id=='blossom' then size=.6;height=.05;drift=alpha*5
  elseif id=='candy' then size=1.2+visible;height=.05
  else size=.3+visible*.5;height=.08;drift=alpha*4 end
  p.Size=(id=='frozen') and Vector3.new(size,.13,size*.55)
   or ((id=='blossom' or id=='crystal') and Vector3.new(size,.12,size*.55))
   or ((id=='candy') and Vector3.new(size,.12,size))
   or Vector3.new(size,math.max(.08,height*.6),size)
  p.CFrame=CFrame.new(x+drift,y+height,z)*CFrame.Angles(0,i*1.7+(reduced and 0 or now*style.pace*.12),0)
  p.Transparency=1-visible*((id=='inferno' or id=='cosmic') and .65 or .4)
 end

 local frontVisible = math.abs(cameraX - shoreX) < 320
 for _, item in front do
  local p = item.part
  if not frontVisible then
   p.Transparency = 1
  else
   local alpha = reduced and 0.78 or (now / 4.8 + item.row / 3 + (item.i % 3) * 0.025) % 1
   local strength = math.sin(alpha * math.pi) ^ 1.35
   local x = shoreX + 1.4 + (1 - alpha) * 16
   local wobble = reduced and 0 or math.sin(now * 1.05 + item.i * 1.9) * 0.6
   p.CFrame = CFrame.new(x + wobble, surfaceY + 0.085, item.z) * CFrame.Angles(0, item.angle, 0)
   p.Transparency = 1 - 0.55 * strength
  end
 end

 local gridX = math.floor(cameraX / 42) * 42
 local bankStart = math.max(shoreX + 28, gridX - 34)
 for _, item in banks do
  local p = item.part
  local x = bankStart + item.i * 42
  if x > lastEdge - 20 then
   p.Transparency = 1
  else
   local alpha = reduced and 0.72 or (now / 4.3 + item.row * 0.46 + (item.i % 3) * 0.045) % 1
   local strength = math.sin(alpha * math.pi) ^ 1.3
   local shoreZ = Shore.at(x,item.side)
   local z = shoreZ - item.side * (1.4 + (1 - alpha) * 8)
   local y=Water.at(Vector3.new(x,0,z))
   if not y then p.Transparency=1;continue end
   local tangent=math.atan2(Shore.at(x+8,item.side)-Shore.at(x-8,item.side),16)
   p.CFrame = CFrame.new(x, y + 0.09, z) * CFrame.Angles(0, -tangent+item.angle, 0)
   local theme=styleSurface(p,x)
   p.Transparency=1-((theme=='inferno' or theme=='cosmic') and .38 or .42)*strength
  end
 end
end)

script.Destroying:Connect(function()
 connection:Disconnect()
 added:Disconnect()
 removed:Disconnect()
 folder:Destroy()
end)

