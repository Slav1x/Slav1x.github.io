--!nonstrict
-- Sparse breakables follow the current playable biome surfaces, never retired lake tiles.
local RS=game:GetService("ReplicatedStorage")
local Tags=game:GetService("CollectionService")
local Sign=require(RS.Shared.EncounterSign)
local Pickup=require(script.Parent.Server.WaterPickupService)
local Art=require(RS.Shared.WaterObstacleArt)
local Placement=require(RS.Shared.WaterPickupPlacement)
local Water=require(RS.Shared.WaterSurface)
local Zones=require(RS.Shared.ZoneConfig)
local Builder={}
local connections={}
local pending={}
local kinds={"MossyOutcrop","Driftwood","ChannelBuoys"}
local titles={"MOSSY OUTCROP","DRIFTWOOD","CHANNEL BUOYS"}
local biomeTitles={
 blossom={"SAKURA ISLET","PETAL STONES","SPIRIT GARDEN"},
 candy={"GUMDROP CLUSTER","SUGAR BOULDERS","CANDY CRAGS"},
 sunscorch={"AMBER FOSSIL","OASIS STONES","CANYON RELIC"},
 frozen={"ICE CRYSTALS","GLACIER SHARD","FROZEN DEBRIS"},
 crystal={"QUARTZ GEODE","PRISM DEPOSIT","CAVERN CRYSTALS"},
 toxic={"SPORE ISLET","TWISTED ROOTS","FUNGAL REEF"},
 inferno={"OBSIDIAN CLUSTER","VOLCANIC SHARDS","CINDER DEBRIS"},
 cosmic={"STAR CRYSTALS","ASTRAL FRAGMENTS","MOON RELIC"},
}
local values={275,325,250}
local lanes={-66,82,-94,58,-78}
local function isCourseSurface(water)
 local world=workspace:FindFirstChild("ZoneWorld")
 local surfaces=world and world:FindFirstChild("AreaSurfaces")
 return surfaces and water:IsDescendantOf(surfaces)
end
function Builder.build(water)
 if not water:IsA("BasePart") or not water:IsDescendantOf(workspace) then return end
 local old=water:FindFirstChild("SkipObstacles")
 if old then old:Destroy() end
 if water:GetAttribute("ObstaclesEnabled")==false or not isCourseSurface(water) then return end
 local length,width=water.Size.X,water.Size.Z
 if length<160 or width<90 then return end
 local folder=Instance.new("Folder");folder.Name="SkipObstacles";folder.Parent=water
 local count=math.clamp(math.floor(length/360),1,5)
 for i=1,count do
  local x=-length/2+length*i/(count+1)
  local lane=lanes[(i-1)%#lanes+1]
  local point=water.CFrame:PointToWorldSpace(Vector3.new(x,0,math.clamp(lane,-width*.28,width*.28)))
  local distance=Zones.distanceAt(point)
  if distance<120 or distance>Zones.List[#Zones.List].finish-90 then continue end
  local y=Water.at(point)
  if not y then continue end
  local zone=Zones.forDistance(distance)
  local index=(i+math.floor(zone.start/600)-1)%3+1
  local model=Instance.new("Model")
  local kind,cash=kinds[index],values[index]
  model.Name=zone.id.."_"..kind.."_"..i
  model:SetAttribute("SkipObstacle",true)
  model:SetAttribute("ObstacleKind",kind)
  model:SetAttribute("ObstacleCash",cash)
  model:SetAttribute("AreaId",zone.id)
  model:SetAttribute("EnvironmentObstacleVersion",2)
  model:SetAttribute("PickupWaterlineOffset",0)
  model.Parent=folder
  local base=CFrame.new(point.X,y,point.Z)
  Art.build(model,base,kind,false)
  local marker=Instance.new("Part")
  marker.Name="SignAnchor";marker.Size=Vector3.one;marker.CFrame=base;marker.Transparency=1
  marker.Anchored=true;marker.CanCollide=false;marker.CanTouch=false;marker.CanQuery=false;marker.Parent=model
  model.PrimaryPart=marker
  model.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
  Art.configure(model)
  if not Placement.place(model) then model:Destroy();continue end
  Sign.attach(model,marker,(biomeTitles[zone.id] or titles)[index],"BREAK  +$"..cash,zone.color,17)
  Tags:AddTag(model,"SkipObstacle")
  Pickup.register(model)
 end
end
function Builder.start()
 local function track(water)
  if not water:IsA("BasePart") or connections[water] then return end
  local function schedule()
   if pending[water] then return end
   pending[water]=true
   task.delay(.3,function()
    pending[water]=nil
    if connections[water] then Builder.build(water) end
   end)
  end
  connections[water]={water:GetPropertyChangedSignal("Size"):Connect(schedule),water:GetPropertyChangedSignal("CFrame"):Connect(schedule),water:GetAttributeChangedSignal("ObstaclesEnabled"):Connect(schedule)}
  Builder.build(water)
 end
 local waters=Tags:GetTagged("SkippingWater")
 table.sort(waters,function(a,b) return a:IsA("BasePart") and b:IsA("BasePart") and a.Position.X<b.Position.X end)
 for _,water in waters do track(water) end
 Tags:GetInstanceAddedSignal("SkippingWater"):Connect(track)
 Tags:GetInstanceRemovedSignal("SkippingWater"):Connect(function(water)
  for _,c in connections[water] or {} do c:Disconnect() end
  connections[water]=nil
  local folder=water:FindFirstChild("SkipObstacles")
  if folder then folder:Destroy() end
 end)
end
return Builder

