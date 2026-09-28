-- Only gameplay encounters get per-player residency. Decoration remains streamed.
local Players=game:GetService('Players')
local Tags=game:GetService('CollectionService')
local Run=game:GetService('RunService')
local RS=game:GetService('ReplicatedStorage')
local W=require(RS.Shared.CriticalWorldWindow)
local Config=require(RS.Shared.ThrowConfig)
local Zones=require(RS.Shared.ZoneConfig)
local active={};local encounters={};local clock=0
local folder=Instance.new('Folder');folder.Name='FlightStreamingFoci';folder.Parent=workspace
local function track(m)
 if not m:IsA('Model') then return end
 m.ModelStreamingMode=Enum.ModelStreamingMode.PersistentPerPlayer
 encounters[m]=true
end
local function release(r)
 for m in r.held do if m.Parent then m:RemovePersistentPlayer(r.player) end end
 table.clear(r.held)
end
local function remove(pebble)
 local r=active[pebble];if not r then return end;active[pebble]=nil
 release(r)
 for _,p in r.parts do
  if r.player.Parent then pcall(function() r.player:RemoveReplicationFocus(p) end) end
  p:Destroy()
 end
 if r.player.Parent then r.player:SetAttribute('CriticalResidentModels',0) end
end
local function add(pebble)
 if active[pebble] or not pebble:IsA('Model') or not pebble.PrimaryPart then return end
 local p=Players:GetPlayerByUserId(pebble:GetAttribute('ThrowerUserId') or 0);if not p then return end
 local parts={}
 for i=1,2 do
  local part=Instance.new('Part');part.Name='Ahead_'..p.UserId..'_'..i;part.Size=Vector3.one
  part.Transparency=1;part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false;part.CastShadow=false
  part.Position=pebble.PrimaryPart.Position;part.Parent=folder;p:AddReplicationFocus(part);parts[i]=part
 end
 active[pebble]={player=p,parts=parts,held={}}
end
task.spawn(function()
 local f=workspace:WaitForChild('PebbleAdventure',30)
 if f then for _,m in f:GetChildren() do track(m) end;f.ChildAdded:Connect(track) end
end)
Tags:GetInstanceAddedSignal('WaterPickup'):Connect(track)
for _,m in Tags:GetTagged('WaterPickup') do track(m) end
Tags:GetInstanceRemovedSignal('WaterPickup'):Connect(function(m)
 encounters[m]=nil
 for _,r in active do if r.held[m] then if m.Parent then m:RemovePersistentPlayer(r.player) end;r.held[m]=nil end end
end)
Tags:GetInstanceAddedSignal(Config.PebbleTag):Connect(add)
Tags:GetInstanceRemovedSignal(Config.PebbleTag):Connect(remove)
for _,p in Tags:GetTagged(Config.PebbleTag) do add(p) end
Players.PlayerRemoving:Connect(function(p) for pebble,r in active do if r.player==p then remove(pebble) end end end)
Run.Heartbeat:Connect(function(dt)
 clock+=dt;if clock<W.UpdateSeconds then return end;clock=0
 for pebble,r in active do
  local main=pebble.PrimaryPart
  if not pebble:IsDescendantOf(workspace) or not main or not r.player.Parent or pebble:GetAttribute('ThrowFinished') then remove(pebble);continue end
  local v=main.AssemblyLinearVelocity;local flat=Vector3.new(v.X,0,v.Z)
  local direction=flat.Magnitude>1 and flat.Unit or Vector3.xAxis
  local speed=math.max(flat.Magnitude,pebble:GetAttribute('LaunchSpeed') or 0)
  local lead=W.lead(speed);local candidates={}
  for m in encounters do
   local base=m:GetAttribute('PickupBase') or (m.PrimaryPart and m:GetPivot())
   if m.Parent and typeof(base)=='CFrame' then
    local delta=base.Position-main.Position
    -- Full river width allows steering. Hysteresis holds the previous corridor briefly.
    if delta.X>=-650 and delta.X<=lead+(r.held[m] and 500 or 0) then
     table.insert(candidates,{m=m,d=math.abs(delta.X)+(delta.X<0 and 1000 or 0)})
    end
   end
  end
  table.sort(candidates,function(a,b) return a.d<b.d end)
  local wanted={}
  for i=1,math.min(#candidates,W.MaxModels) do local m=candidates[i].m;wanted[m]=true;if not r.held[m] then m:AddPersistentPlayer(r.player) end end
  for m in r.held do if not wanted[m] and m.Parent then m:RemovePersistentPlayer(r.player) end end
  r.held=wanted
  for i,p in r.parts do
   local target=main.Position+direction*lead*(i==1 and .35 or .8)
   p.Position=Vector3.new(math.clamp(target.X,Zones.OriginX,Zones.OriginX+Zones.List[#Zones.List].finish),60,math.clamp(target.Z,-350,270))
  end
  r.player:SetAttribute('CriticalResidentModels',math.min(#candidates,W.MaxModels))
  r.player:SetAttribute('CriticalWorldLead',lead)
 end
end)
script.Destroying:Connect(function() for p in active do remove(p) end;folder:Destroy() end)
