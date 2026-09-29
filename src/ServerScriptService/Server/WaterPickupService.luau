--!nonstrict
-- Availability and collection are server-owned; only phase changes replicate.
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Tags=game:GetService("CollectionService")
local M=require(RS.Shared.WaterPickupMotion)
local Water=require(RS.Shared.WaterSurface)
local Hit=require(RS.Shared.WaterObstacleHit)
local ObstacleArt=require(RS.Shared.WaterObstacleArt)
local S={}
local tracked={}
local rng=Random.new()
local elapsed=0
local function duration(model,name,fallback)
 local value=model:GetAttribute(name)
 if type(value)~="number" or value~=value or value==math.huge or value==-math.huge then return fallback end
 return math.clamp(value,2,120)
end
local function phase(record,code,at,duration)
 record.timeline={X=code,Y=at,Z=duration}
 local available=code==M.Active
 if code==M.Rising then record.model:SetAttribute("PickupClaimed",false);record.model:SetAttribute("PickupClaimedAt",nil);record.model:SetAttribute("Broken",false);record.model:SetAttribute("BreakTime",nil) end
 for part,query in record.query do
  if part.Parent then part.CanQuery=false end -- Analytic sweeps use the shared pose.
 end
 record.model:SetAttribute("PickupTimeline",M.encode(code,at,duration))
end
local function advance(record,now)
 -- Use scheduled boundaries, so scheduler jitter cannot stretch or snap a transition.
 local count=0
 while now>=record.timeline.Y+record.timeline.Z and count<32 do
  count+=1
  local boundary=record.timeline.Y+record.timeline.Z
  local code=record.timeline.X
  if code==M.Active then phase(record,M.Sinking,boundary,M.SinkSeconds)
  elseif code==M.Sinking then phase(record,M.Submerged,boundary,rng:NextNumber(record.restMin,record.restMax))
  elseif code==M.Submerged then phase(record,M.Rising,boundary,M.RiseSeconds)
  else phase(record,M.Active,boundary,rng:NextNumber(record.surfaceMin,record.surfaceMax)) end
 end
end
function S.register(model)
 if tracked[model] then return tracked[model] end
 if not model:IsA("Model") or not model.PrimaryPart then return nil end
 local base=model:GetPivot()
 local waterY=Water.at(base.Position)
 if not waterY then return nil end
 local breakable=ObstacleArt.configure(model)
 local offset=model:GetAttribute("PickupWaterlineOffset") or 0
 base=base+Vector3.new(0,waterY+offset-base.Position.Y,0)
 model:PivotTo(base)
 local height=0
 local query={}
 for _,p in model:GetDescendants() do
  if p:IsA("BasePart") then
   query[p]=p.CanQuery
   height=math.max(height,p.Position.Y+p.Size.Magnitude*.5-waterY)
   p.Anchored=true;p.CanCollide=false;p.CanTouch=false
  end
 end
 local visuals={}
 local low=Vector3.new(math.huge,math.huge,math.huge)
 local high=-low
 for _,p in model:GetDescendants() do
  if p:IsA("BasePart") and p.Transparency<1 and p.Name~="SurfaceRipple" then
   local cf=base:ToObjectSpace(p.CFrame)
   p:SetAttribute("PickupLocalCFrame",cf)
   local orbit=p.Name=="VortexArc" or p.Name=="OrbitPearl"
   table.insert(visuals,{part=p,cf=cf,size=p.Size,orbit=orbit})
   for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
    local point=cf:PointToWorldSpace(p.Size*Vector3.new(x,y,z)*.5)
    low=low:Min(point);high=high:Max(point)
   end end end
  end
 end
 if #visuals==0 then return nil end
 local bounds,size=model:GetBoundingBox()
 local r={model=model,query=query,visuals=visuals,bounds=base:ToObjectSpace(bounds),size=size}
 -- A complete fully-surfaced phase lasts exactly 15 seconds for every water object.
 r.surfaceMin=M.SurfaceMin
 r.surfaceMax=M.SurfaceMax
 model:SetAttribute("PickupSurfaceMin",M.SurfaceMin)
 model:SetAttribute("PickupSurfaceMax",M.SurfaceMax)
 r.restMin=duration(model,"PickupRestMin",if breakable then 16 else M.RestMin)
 r.restMax=math.max(r.restMin,duration(model,"PickupRestMax",if breakable then 16 else M.RestMax))
 tracked[model]=r
 model:SetAttribute("PickupBase",base)
 model:SetAttribute("PickupVisualBounds",CFrame.new((low+high)*.5))
 model:SetAttribute("PickupVisualSize",high-low)
 model:SetAttribute("PickupSweepPadding",size.Magnitude*.75+4)
 model:SetAttribute("PickupClaimed",false)
 model:SetAttribute("PickupClaimedAt",nil)
 model:SetAttribute("PickupWaterY",waterY)
 model:SetAttribute("PickupDepth",math.max(4,high.Y+offset+1.5))
 model:SetAttribute("PickupSeed",rng:NextNumber(0,math.pi*2))
 model:SetAttribute("Broken",false)
 -- Start at a different point in the entire cycle, not all on the surface.
 local now=workspace:GetServerTimeNow()
 local cycle=r.surfaceMax+M.SinkSeconds+r.restMax+M.RiseSeconds
 local offset=if Run:IsRunning() then rng:NextNumber(0,cycle) else 0
 phase(r,M.Active,now-offset,r.surfaceMax)
 advance(r,now)
 Tags:AddTag(model,"WaterPickup")
 return r
end
function S.isAvailable(model)
 local r=tracked[model] or S.register(model)
 if not r or not model.Parent then return false end
 local now=workspace:GetServerTimeNow()
 advance(r,now)
 return M.availableForModel(model,now)
end
function S.collect(model)
 local r=tracked[model] or S.register(model)
 if not r or not model.Parent then return false end
 local now=workspace:GetServerTimeNow()
 advance(r,now)
 if not M.availableForModel(model,now) then return false end
 -- No yields between checking and claiming: two pebbles cannot collect the same surface cycle.
 model:SetAttribute("PickupClaimed",true)
 model:SetAttribute("PickupClaimedAt",now)
 -- Do not restart a natural sink, which would snap the object back to the surface.
 if r.timeline.X==M.Active then phase(r,M.Sinking,now,M.SinkSeconds) end
 if model:GetAttribute("WaterBreakable")==true or model:GetAttribute("SkipObstacle")==true then
  model:SetAttribute("Broken",true)
  model:SetAttribute("BreakTime",now)
 end
 return true
end
function S.hitModel(model,from,to,radius)
 local r=tracked[model]
 if not r or not S.isAvailable(model) then return nil end
 local now=workspace:GetServerTimeNow()
 local motion=M.sample(r.timeline,now,model:GetAttribute("PickupSeed") or 0,model:GetAttribute("PickupDepth") or 26,false)
 local cf=model:GetAttribute("PickupBase")*motion
 if not Hit.box(from,to,cf*r.bounds,r.size*1.5,radius+.1) then return nil end
 local first,part
 for _,v in r.visuals do if v.part.Parent then
  local partCF=M.partFrame(model:GetAttribute("PickupBase"),motion,v.cf,v.orbit,now)
  local alpha=Hit.box(from,to,partCF,v.size,radius+.1)
  if alpha and from:Lerp(to,alpha).Y+radius<model:GetAttribute("PickupWaterY") then alpha=nil end
  if alpha and (not first or alpha<first) then first=alpha;part=v.part end
 end end
 return first,part
end
function S.sweepPhysical(from,to,radius)
 local hits={}
 for model,r in tracked do
  local base=model:GetAttribute("PickupBase")
  local pad=model:GetAttribute("PickupSweepPadding") or 90
  if model.Parent and model:GetAttribute("SkipObstacle")==true and typeof(base)=="CFrame"
   and base.X>=math.min(from.X,to.X)-pad and base.X<=math.max(from.X,to.X)+pad
   and base.Z>=math.min(from.Z,to.Z)-pad and base.Z<=math.max(from.Z,to.Z)+pad then
   local alpha,part=S.hitModel(model,from,to,radius)
   if alpha then table.insert(hits,{part=part,alpha=alpha,position=from:Lerp(to,alpha)}) end
  end
 end
 table.sort(hits,function(a,b) return a.alpha<b.alpha end)
 return hits
end
Run.Heartbeat:Connect(function(dt)
 if not Run:IsRunning() then return end
 elapsed+=dt
 if elapsed<.1 then return end
 elapsed=0
 local now=workspace:GetServerTimeNow()
 for model,r in tracked do
  if not model:IsDescendantOf(workspace) then tracked[model]=nil
  else advance(r,now) end
 end
end)
return S