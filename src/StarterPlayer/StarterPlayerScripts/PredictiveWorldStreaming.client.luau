-- Bounded predictive prefetch for the detached pebble camera.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local ContentProvider=game:GetService('ContentProvider')
local player=Players.LocalPlayer
local Zones=require(RS.Shared.ZoneConfig)
local W=require(RS.Shared.CriticalWorldWindow)
local Lib=RS:WaitForChild('WorldAssetLibrary')
local alive=true;local busy=false;local lastRequest=-math.huge;local previous;local clock=0
local warm={};local queue={};local queued={};local worker=false
local attempts={};local retryAt={}
local requestCount=0;local failureCount=0
local function enqueue(instance)
 local key=instance:IsA('MeshPart') and (instance.MeshId..'|'..instance.TextureID) or instance
 if queued[key] or warm[key] or (attempts[key] or 0)>=3 or os.clock()<(retryAt[key] or 0) then return end
 queued[key]=true;table.insert(queue,{instance=instance,key=key})
end
local function work()
 if worker or #queue==0 then return end
 worker=true
 task.spawn(function()
  while alive and #queue>0 do
   local batch={};local keys={}
   for i=1,math.min(4,#queue) do local r=table.remove(queue,1);table.insert(batch,r.instance);table.insert(keys,r.key) end
   local fetched=true
   local ok=pcall(function() ContentProvider:PreloadAsync(batch,function(_,status) if status~=Enum.AssetFetchStatus.Success then failureCount+=1;fetched=false end end) end)
   for _,key in keys do
    queued[key]=nil;attempts[key]=(attempts[key] or 0)+1
    if ok and fetched then warm[key]=true else retryAt[key]=os.clock()+5 end
   end
   player:SetAttribute('WorldAssetFailures',failureCount)
   task.wait(.05)
  end
  worker=false
 end)
end
local function prepare(distance,lookahead)
 -- Only current and approaching families; shared palette downloads once.
 local current=1
 for i,zone in Zones.List do if distance>=zone.start then current=i end end
 for i=math.max(1,current-1),math.min(#Zones.List,current+2) do
  local zone=Zones.List[i]
  if i<=current+1 or zone.start<=distance+lookahead then
   local ready=true
   for _,asset in Lib:GetChildren() do
    if asset:GetAttribute('Biome')==zone.id then
     enqueue(asset)
     local key=asset:IsA('MeshPart') and (asset.MeshId..'|'..asset.TextureID) or asset
     if not warm[key] then ready=false end
    end
   end
   player:SetAttribute('WorldBiomeReady_'..zone.id,ready)
  end
 end
 work()
end
prepare(0,1500)
local connection=Run.Heartbeat:Connect(function(dt)
 clock+=dt;if clock<.12 then return end
 local step=clock;clock=0;local camera=workspace.CurrentCamera;if not camera then return end
 local pos=camera.CFrame.Position;local delta=previous and pos-previous or Vector3.zero;previous=pos
 local speed=math.min(2200,Vector3.new(delta.X,0,delta.Z).Magnitude/math.max(step,.01))
 local direction=Vector3.new(delta.X,0,delta.Z)
 if direction.Magnitude>.5 then direction=direction.Unit else direction=Vector3.new(camera.CFrame.LookVector.X,0,camera.CFrame.LookVector.Z);direction=direction.Magnitude>.01 and direction.Unit or Vector3.xAxis end
 local flight=player:GetAttribute('RockInFlight')==true
 local lead=W.lead(speed)
 prepare(Zones.distanceAt(pos),flight and lead or 1500)
 if not workspace.StreamingEnabled or busy or os.clock()-lastRequest<(flight and .75 or 2) then return end
 busy=true;lastRequest=os.clock()
 -- One in-flight batch; server look-ahead foci maintain the route between requests.
 task.spawn(function()
  -- Advance the request origin each time; never queue requests behind a fast camera.
  for _,offset in {lead*.65} do
   if not alive then break end
   local current=workspace.CurrentCamera;if not current then break end
   if (current.CFrame.Position-pos).Magnitude>lead+500 then break end
   local sample=current.CFrame.Position+direction*offset
   sample=Vector3.new(math.clamp(sample.X,Zones.OriginX,Zones.OriginX+Zones.List[#Zones.List].finish),math.clamp(sample.Y,15,150),math.clamp(sample.Z,-320,240))
   local ok=pcall(function() player:RequestStreamAroundAsync(sample,.35) end)
   requestCount+=1;if not ok then failureCount+=1 end
  end
  busy=false;player:SetAttribute('WorldStreamRequests',requestCount);player:SetAttribute('WorldStreamLead',lead)
 end)
end)
script.Destroying:Connect(function() alive=false;connection:Disconnect();table.clear(queue) end)
