--!strict
-- Tagged physical water remains authoritative. Only nearby, live surfaces are queried.
local CollectionService = game:GetService("CollectionService")
local WaterSurface = {}
WaterSurface.Tag = "SkippingWater"
local changed = Instance.new("BindableEvent")
WaterSurface.Changed = changed.Event
local CELL = 512
type Surface = {part: BasePart, cf: CFrame, half: Vector3, level: number, cells: {{number}}, live: boolean, connections: {RBXScriptConnection}}
local surfaces: {[BasePart]: Surface} = {}
local live: {[BasePart]: Surface} = {}
local buckets: {[number]: {[number]: {[BasePart]: Surface}}} = {}

local function removeCells(record: Surface)
 for _, cell in record.cells do
  local column = buckets[cell[1]]
  local bucket = column and column[cell[2]]
  if bucket then
   bucket[record.part] = nil
   if next(bucket) == nil then
    column[cell[2]] = nil
    if next(column) == nil then buckets[cell[1]] = nil end
   end
  end
 end
 table.clear(record.cells)
 live[record.part] = nil
end

local function update(record: Surface)
 removeCells(record)
 local part = record.part
 record.live = part:IsDescendantOf(workspace)
 record.cf, record.half = part.CFrame, part.Size * .5
 record.level = part.Position.Y + record.half.Y
 if record.live then
  live[part] = record
  local cf, half = record.cf, record.half
  local extentX = math.abs(cf.RightVector.X) * half.X + math.abs(cf.LookVector.X) * half.Z
  local extentZ = math.abs(cf.RightVector.Z) * half.X + math.abs(cf.LookVector.Z) * half.Z
  for x = math.floor((cf.X-extentX)/CELL), math.floor((cf.X+extentX)/CELL) do
   local column = buckets[x] or {}; buckets[x] = column
   for z = math.floor((cf.Z-extentZ)/CELL), math.floor((cf.Z+extentZ)/CELL) do
    local bucket = column[z] or {}; column[z] = bucket
    bucket[part] = record
    table.insert(record.cells, {x,z})
   end
  end
 end
 changed:Fire()
end

local function track(instance: Instance)
 if not instance:IsA("BasePart") or surfaces[instance] then return end
 local record: Surface = {part=instance,cf=instance.CFrame,half=instance.Size*.5,level=0,cells={},live=false,connections={}}
 surfaces[instance] = record
 local function refresh() update(record) end
 record.connections = {
  instance:GetPropertyChangedSignal("Size"):Connect(refresh),
  instance:GetPropertyChangedSignal("CFrame"):Connect(refresh),
  instance.AncestryChanged:Connect(refresh),
 }
 update(record)
end
CollectionService:GetInstanceAddedSignal(WaterSurface.Tag):Connect(track)
CollectionService:GetInstanceRemovedSignal(WaterSurface.Tag):Connect(function(instance)
 local record = surfaces[instance :: BasePart]
 if not record then return end
 for _, connection in record.connections do connection:Disconnect() end
 removeCells(record)
 surfaces[instance :: BasePart] = nil
 changed:Fire()
end)
for _, instance in CollectionService:GetTagged(WaterSurface.Tag) do track(instance) end

local function contains(record: Surface, position: Vector3): boolean
 local point = record.cf:PointToObjectSpace(Vector3.new(position.X, record.cf.Y, position.Z))
 return math.abs(point.X) <= record.half.X and math.abs(point.Z) <= record.half.Z
end
function WaterSurface.getPrimary(): BasePart?
 return next(live)
end
function WaterSurface.getLevel(part: BasePart): number
 return part.Position.Y + part.Size.Y*.5
end
function WaterSurface.contains(part: BasePart, position: Vector3): boolean
 local record = surfaces[part]
 if record then return record.live and contains(record,position) end
 if not part:IsDescendantOf(workspace) then return false end
 local point=part.CFrame:PointToObjectSpace(Vector3.new(position.X,part.Position.Y,position.Z))
 return math.abs(point.X)<=part.Size.X*.5 and math.abs(point.Z)<=part.Size.Z*.5
end
function WaterSurface.at(position: Vector3): (number?, BasePart?)
 local column = buckets[math.floor(position.X/CELL)]
 local bucket = column and column[math.floor(position.Z/CELL)]
 local highest: number? = nil
 local selected: BasePart? = nil
 if bucket then
  for part, record in bucket do
   if contains(record,position) and (not highest or record.level>highest) then
    highest, selected = record.level,part
   end
  end
 end
 return highest,selected
end
function WaterSurface.crossing(from: Vector3, to: Vector3): (Vector3?, BasePart?)
 if to.Y>=from.Y then return nil,nil end
 local bestAlpha=math.huge
 local hit: Vector3?=nil
 local selected: BasePart?=nil
 local seen: {[BasePart]: boolean}={}
 local function check(record: Surface)
  if seen[record.part] then return end
  seen[record.part]=true
  if from.Y>record.level and to.Y<=record.level then
   local alpha=(from.Y-record.level)/(from.Y-to.Y)
   if alpha<bestAlpha then
    local point=from:Lerp(to,alpha)
    if contains(record,point) then bestAlpha,hit,selected=alpha,point,record.part end
   end
  end
 end
 local x0,x1=math.floor(math.min(from.X,to.X)/CELL),math.floor(math.max(from.X,to.X)/CELL)
 local z0,z1=math.floor(math.min(from.Z,to.Z)/CELL),math.floor(math.max(from.Z,to.Z)/CELL)
 if (x1-x0+1)*(z1-z0+1)>512 then
  for _,record in live do check(record) end
 else
  for x=x0,x1 do
   local column=buckets[x]
   if column then for z=z0,z1 do
    local bucket=column[z]
    if bucket then for _,record in bucket do check(record) end end
   end end
  end
 end
 return hit,selected
end
return WaterSurface
