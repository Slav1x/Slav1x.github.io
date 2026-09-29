-- Reuses exact authored water tiles. Local ownership removes network-streaming gaps.
-- Server-tagged water remains the authority for skip physics.
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Tags=game:GetService('CollectionService')
local player=game:GetService('Players').LocalPlayer
local W=require(RS.Shared.CriticalWorldWindow)
local Zones=require(RS.Shared.ZoneConfig)
local Biomes=require(RS.Shared.BiomePresentation)
local templates=RS:WaitForChild('CriticalWaterTemplates')
local folder=Instance.new('Folder');folder.Name='LocalCriticalWater';folder.Parent=workspace
local bins={};local active={};local hidden={};local clock=0;local previous;local pebble
for _,p in templates:GetChildren() do
 local half=math.abs(p.CFrame.RightVector.X)*p.Size.X*.5+math.abs(p.CFrame.LookVector.X)*p.Size.Z*.5
 for i=math.floor((p.Position.X-half)/512),math.floor((p.Position.X+half)/512) do bins[i]=bins[i] or {};table.insert(bins[i],p) end
end
local function hide(p)
 if p:IsA('BasePart') and p:GetAttribute('CriticalWaterSource') then hidden[p]=p.LocalTransparencyModifier;p.LocalTransparencyModifier=1 end
end
for _,p in Tags:GetTagged('SkippingWater') do hide(p) end
local added=Tags:GetInstanceAddedSignal('SkippingWater'):Connect(hide)
local removed=Tags:GetInstanceRemovedSignal('SkippingWater'):Connect(function(p) hidden[p]=nil end)
local function selectPebble(m)
 if m:GetAttribute('ThrowerUserId')==player.UserId then pebble=m end
end
for _,m in Tags:GetTagged('SkippingPebble') do selectPebble(m) end
local pa=Tags:GetInstanceAddedSignal('SkippingPebble'):Connect(selectPebble)
local function update(dt)
 local camera=workspace.CurrentCamera;if not camera then return end
 local pos=camera.CFrame.Position
 local main=pebble and pebble.Parent and not pebble:GetAttribute('ThrowFinished') and pebble.PrimaryPart
 local speed=0
 if main then pos=main.Position;local v=main.AssemblyLinearVelocity;speed=math.max(Vector3.new(v.X,0,v.Z).Magnitude,pebble:GetAttribute('LaunchSpeed') or 0)
 elseif previous then speed=math.min(1800,math.abs(pos.X-previous)/math.max(dt,.01)) end
 previous=pos.X
 local lo=math.min(pos.X,camera.CFrame.Position.X)-650
 local hi=math.max(pos.X,camera.CFrame.Position.X)+W.lead(speed)
 local candidates={};local seen={}
 for i=math.floor(lo/512),math.floor(hi/512) do for _,p in bins[i] or {} do if not seen[p] then seen[p]=true;table.insert(candidates,p) end end end
 table.sort(candidates,function(a,b) return math.abs(a.Position.X-pos.X)<math.abs(b.Position.X-pos.X) end)
 local wanted={};local event=Biomes.event()
 for i=1,math.min(#candidates,W.MaxWaterParts) do
  local source=candidates[i];wanted[source]=true
  local p=active[source]
  if not p then p=source:Clone();p.LocalTransparencyModifier=0;p.Parent=folder;active[source]=p end
  local profile=Biomes.sample(math.max(0,source.Position.X-Zones.OriginX))
  p.Color=event and source.Color:Lerp(event.color,.22) or source.Color
 end
 for source,p in active do if not wanted[source] then p:Destroy();active[source]=nil end end
 player:SetAttribute('CriticalWaterParts',math.min(#candidates,W.MaxWaterParts))
 player:SetAttribute('CriticalWaterBudgetExceeded',#candidates>W.MaxWaterParts)
end
update(.15)
local connection=Run.Heartbeat:Connect(function(dt) clock+=dt;if clock<W.UpdateSeconds then return end;local step=clock;clock=0;update(step) end)
script.Destroying:Connect(function()
 connection:Disconnect();added:Disconnect();removed:Disconnect();pa:Disconnect();folder:Destroy()
 for p,old in hidden do if p.Parent then p.LocalTransparencyModifier=old end end
end)
