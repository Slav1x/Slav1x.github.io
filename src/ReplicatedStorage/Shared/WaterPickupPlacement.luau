--!nonstrict
-- One course-wide placement policy for the existing encounter models.
local Tags=game:GetService("CollectionService")
local Water=require(game.ReplicatedStorage.Shared.WaterSurface)
local Zones=require(game.ReplicatedStorage.Shared.ZoneConfig)
local Shore=require(game.ReplicatedStorage.Shared.RiverlandsShoreProfile)
local P={Version=7,CenterZ=-40.5,RouteHalfWidth=148,MinimumSpacing=42,ShoreMargin=16}
local powerups={Nitro=true,Jet=true,Bomb=true,Whirlpool=true}
-- Allocate by measured length, so inserted biomes cannot index a five-entry table.
local totalLength=Zones.List[#Zones.List].finish
local kindOrder={"Nitro","Jet","Nitro","Jet","Bomb","Jet","Nitro","Whirlpool"}
local function courseSignature()
 local pieces={tostring(P.Version),tostring(Zones.OriginX)}
 for _,zone in Zones.List do table.insert(pieces,zone.id..":"..zone.start..":"..zone.finish) end
 return table.concat(pieces,"|")
end
function P.isPowerup(model)
 return powerups[model:GetAttribute("EncounterKind")]==true
end
local function anchor(instance)
 local base=instance:GetAttribute("PickupBase")
 return if typeof(base)=="CFrame" then base else instance:GetPivot()
end
local function footprint(instance)
 local cf,size
 if instance:IsA("Model") then cf,size=instance:GetBoundingBox() else cf,size=instance.CFrame,instance.Size end
 return cf,size,math.sqrt(size.X*size.X+size.Z*size.Z)*.5
end
local function occupancy(ignorePowerups)
 local result,seen={},{}
 local function add(v)
  if seen[v] or not v:IsDescendantOf(workspace) or not (v:IsA("Model") or v:IsA("BasePart")) then return end
  if ignorePowerups and P.isPowerup(v) then return end
  seen[v]=true
  local _,_,radius=footprint(v)
  table.insert(result,{model=v,position=anchor(v).Position,radius=radius})
 end
 local course=workspace:FindFirstChild("PebbleAdventure")
 if course then for _,v in course:GetChildren() do if v:IsA("Model") then add(v) end end end
 for _,tag in {"WaterPickup","SkipObstacle"} do for _,v in Tags:GetTagged(tag) do add(v) end end
 return result
end
local function overlapParams(model)
 local exclude={model}
 local course=workspace:FindFirstChild("PebbleAdventure")
 if course then table.insert(exclude,course) end
 for _,v in Tags:GetTagged("SkippingWater") do table.insert(exclude,v) end
 for _,v in Tags:GetTagged("SkipObstacle") do table.insert(exclude,v) end
 local params=OverlapParams.new()
 params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances=exclude
 params.RespectCanCollide=false
 return params
end
function P.clear(model,pivot,occupied,params)
 local box,size,radius=footprint(model)
 local cf=pivot*model:GetPivot():ToObjectSpace(box)
 local distance=Zones.distanceAt(pivot.Position)
 if pivot.Position.X<Zones.OriginX+55 or distance>Zones.List[#Zones.List].finish-50 then return false,"course bounds" end
 local left,right=Shore.at(pivot.Position.X,-1)+P.ShoreMargin,Shore.at(pivot.Position.X,1)-P.ShoreMargin
 if pivot.Position.Z<left or pivot.Position.Z>right then return false,"route bounds" end
 for _,zone in Zones.List do
  if math.abs(distance-zone.start)<40+radius or math.abs(distance-zone.finish)<40+radius then return false,"barrier clearance" end
 end
 local y=Water.at(pivot.Position)
 if not y then return false,"no water" end
 -- Nine samples cover edges as well as corners; margin includes surface motion.
 for _,x in {-1,0,1} do for _,z in {-1,0,1} do
  local at=cf:PointToWorldSpace(Vector3.new(x*(size.X*.5+P.ShoreMargin),0,z*(size.Z*.5+P.ShoreMargin)))
  local sampleY=Water.at(at)
  if not sampleY or math.abs(sampleY-y)>1 then return false,"shore clearance" end
 end end
 for _,other in occupied or occupancy(false) do
  if other.model~=model then
   local delta=other.position-pivot.Position
   local minimum=math.max(P.MinimumSpacing,radius+other.radius+10)
   if delta.X*delta.X+delta.Z*delta.Z<minimum*minimum then return false,"encounter spacing" end
  end
 end
 for _,v in workspace:GetPartBoundsInBox(cf,size+Vector3.new(10,4,10),params or overlapParams(model)) do
  if v.Transparency<.95 and v.Position.Y+v.Size.Y*.5>y+.25
    and (v.CanCollide or v.Size.X>15 or v.Size.Z>15) then
   return false,"scenery obstruction: "..v:GetFullName()
  end
 end
 return true
end
local function snap(model,cf)
 local waterY=Water.at(cf.Position)
 if not waterY then return nil end
 local offset=model:GetAttribute("PickupWaterlineOffset") or 0
 return cf+Vector3.new(0,waterY+offset-cf.Position.Y,0)
end
local function setPosition(model,cf)
 model:PivotTo(cf)
 model:SetAttribute("PickupBase",cf)
 local waterY=Water.at(cf.Position)
 if waterY then model:SetAttribute("PickupWaterY",waterY) end
end
local function find(model,desired,occupied,params)
 local x=math.clamp(desired.Position.X,Zones.OriginX+65,Zones.OriginX+Zones.List[#Zones.List].finish-65)
 local z=math.clamp(desired.Position.Z,Shore.at(x,-1)+P.ShoreMargin,Shore.at(x,1)-P.ShoreMargin)
 local base=CFrame.new(x,desired.Position.Y,z)*desired.Rotation
 for _,dx in {0,18,-18,36,-36,60,-60,90,-90} do
  for _,dz in {0,22,-22,44,-44,66,-66,88,-88,110,-110} do
   local cf=snap(model,base+Vector3.new(dx,0,dz))
   if cf and P.clear(model,cf,occupied,params) then return cf end
  end
 end
 return nil
end
function P.place(model)
 local occupied=occupancy(false)
 local desired=model:GetAttribute("PickupRouteBase") or model:GetPivot()
 local cf=find(model,desired,occupied,overlapParams(model))
 if not cf then return false end
 setPosition(model,cf)
 return true
end
function P.arrangeCourse(folder,force)
 local counts,queues={},{}
 local total=0
 for _,m in folder:GetChildren() do
  if m:IsA("Model") and m.PrimaryPart and P.isPowerup(m) then
   local kind=m:GetAttribute("EncounterKind")
   queues[kind]=queues[kind] or {}
   table.insert(queues[kind],m)
   total+=1
  end
 end
 if total==0 then return {placed=0,failed=0,total=0} end
 local signature=courseSignature()
 if folder:GetAttribute("PowerupRouteVersion")==P.Version
  and folder:GetAttribute("PowerupRouteSignature")==signature
  and folder:GetAttribute("PowerupCourseCount")==total and not force then
  return {placed=total,failed=0,total=total,retained=true}
 end
 for _,queue in queues do table.sort(queue,function(a,b) return (a:GetAttribute("EncounterId") or 0)<(b:GetAttribute("EncounterId") or 0) end) end
 local assigned=0
 for i=1,#Zones.List do
  counts[i]=if i==#Zones.List then total-assigned else math.floor((Zones.List[i].finish-Zones.List[i].start)*total/totalLength+.5)
  assigned+=counts[i]
 end
 local slots={}
 for tier,zone in ipairs(Zones.List) do
  local count=counts[tier]
  local rows=math.max(1,math.ceil(count*.78))
  rows=math.min(rows,count)
  local alternatives=count-rows
  for row=1,rows do
   local fraction=if rows>1 then (row-1)/(rows-1) else .5
   local startInset=if tier==1 then 115 else 90
   local d=zone.start+startInset+(zone.finish-zone.start-startInset-85)*fraction
   local x=Zones.OriginX+d
   local left,right=Shore.at(x,-1)+40,Shore.at(x,1)-40
   local midpoint,half=(left+right)*.5,(right-left)*.5
   local mode=(math.floor((row-1)/4)+tier)%4
   local phase=((row-1)%4)/3
   local lane=if mode==0 then (row%2==0 and -.7 or .7) elseif mode==1 then -.72+1.44*phase elseif mode==2 then .75*math.sin(phase*math.pi*2+.4) else (row%3==0 and 0 or (row%2==0 and -.52 or .52))
   lane=math.clamp(lane+math.sin(row*12.989+tier)*.065,-.83,.83)
   if tier==1 and row==1 then lane=-.12 end
   table.insert(slots,{distance=d,z=midpoint+lane*half,tier=tier,row=row,role="Route"})
   if math.floor(row*alternatives/rows)>math.floor((row-1)*alternatives/rows) then
    local branch=if lane>=0 then -.76 else .76
    table.insert(slots,{distance=d+18,z=midpoint+branch*half,tier=tier,row=row,role="Choice"})
   end
  end
 end
 table.sort(slots,function(a,b) return a.distance<b.distance end)
 local occupied=occupancy(true)
 local params=overlapParams(folder)
 local placed,failed=0,{}
 for i,slot in ipairs(slots) do
  local desiredKind=kindOrder[(i-1)%#kindOrder+1]
  local queue=queues[desiredKind]
  if not queue or #queue==0 then
   for _,kind in kindOrder do if queues[kind] and #queues[kind]>0 then queue=queues[kind];break end end
  end
  local model=queue and table.remove(queue,1)
  if not model then break end
  local desired=CFrame.new(Zones.OriginX+slot.distance,15,P.CenterZ+(slot.z-P.CenterZ))
  local cf=find(model,desired,occupied,params)
  if cf then
   setPosition(model,cf)
   model:SetAttribute("PickupRouteBase",cf)
   model:SetAttribute("PickupRouteVersion",P.Version)
   model:SetAttribute("PickupArea",Zones.List[slot.tier].id)
   model:SetAttribute("PickupRouteRow",slot.row)
   model:SetAttribute("PickupRouteRole",slot.role)
   model:SetAttribute("PickupSurfaceMin",18)
   model:SetAttribute("PickupSurfaceMax",24)
   model:SetAttribute("PickupRestMin",10)
   model:SetAttribute("PickupRestMax",16)
   local _,_,radius=footprint(model)
   table.insert(occupied,{model=model,position=cf.Position,radius=radius})
   placed+=1
  else
   table.insert(failed,model.Name)
  end
 end
 if #failed==0 and placed==total then
  folder:SetAttribute("PowerupRouteVersion",P.Version)
  folder:SetAttribute("PowerupRouteSignature",signature)
 end
 folder:SetAttribute("PowerupCourseCount",placed)
 return {placed=placed,failed=#failed,failedNames=failed,total=total,areaCounts=counts}
end
function P.audit(folder)
 local result={total=0,byArea={},outside=0,blocked=0,failures={},minimumSeparation=math.huge}
 local occupied=occupancy(false)
 local params=overlapParams(folder)
 for _,m in folder:GetChildren() do
  if m:IsA("Model") and m.PrimaryPart and P.isPowerup(m) then
   result.total+=1
   local cf=anchor(m)
   local area=Zones.forDistance(Zones.distanceAt(cf.Position)).id
   result.byArea[area]=(result.byArea[area] or 0)+1
   if cf.Position.X<Zones.OriginX or cf.Position.X>Zones.OriginX+Zones.List[#Zones.List].finish then result.outside+=1 end
   local clear,reason=P.clear(m,cf,occupied,params)
   if not clear then result.blocked+=1;table.insert(result.failures,{name=m.Name,reason=reason}) end
   for _,other in occupied do if other.model~=m then
    local delta=cf.Position-other.position
    result.minimumSeparation=math.min(result.minimumSeparation,Vector3.new(delta.X,0,delta.Z).Magnitude)
   end end
  end
 end
 return result
end
return P
