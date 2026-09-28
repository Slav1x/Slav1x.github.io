-- Bounded, streamed environment animation; distant geometry remains static.
local Run=game:GetService('RunService')
local Tags=game:GetService('CollectionService')
local player=game.Players.LocalPlayer
local Biomes=require(game.ReplicatedStorage.Shared.BiomePresentation)
local cells,records,active={},{},{}
local connections={}
local folder=Instance.new('Folder');folder.Name='LocalRiverlandsLife';folder.Parent=workspace
local function remove(p)
 local r=records[p];if not r then return end
 if p.Parent and active[p] then p.CFrame=r.base end
 local cell=cells[r.cell];if cell then cell[p]=nil end
 records[p]=nil;active[p]=nil
end
local function add(p)
 if not p:IsA('BasePart') or records[p] then return end
 local base=p.CFrame;local cell=math.floor(base.X/512)
 local r={base=base,cell=cell,phase=base.X*.031+base.Z*.017,landmark=p:GetAttribute('RiverlandsRole')=='landmark'}
 r.foot=Vector3.new(base.X,p:GetAttribute('GroundY') or base.Y-p.Size.Y/2,base.Z)
 cells[cell]=cells[cell] or {};cells[cell][p]=r;records[p]=r
end
for _,p in Tags:GetTagged('RiverlandsLife') do add(p) end
table.insert(connections,Tags:GetInstanceAddedSignal('RiverlandsLife'):Connect(add))
table.insert(connections,Tags:GetInstanceRemovedSignal('RiverlandsLife'):Connect(remove))
local emitters={}
for i=1,6 do
 local a=Instance.new('Part');a.Name='LandmarkAtmosphere';a.Size=Vector3.new(45,9,45);a.Anchored=true;a.CanCollide=false;a.CanTouch=false;a.CanQuery=false;a.Transparency=1;a.Parent=folder
 local e=Instance.new('ParticleEmitter');e.Texture='rbxasset://textures/particles/sparkles_main.dds';e.Enabled=false;e.Rate=2.5;e.Lifetime=NumberRange.new(3,5);e.Speed=NumberRange.new(.5,2);e.SpreadAngle=Vector2.new(180,180);e.Drag=.6;e.LightEmission=.35;e.LightInfluence=.6
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.2,.65),NumberSequenceKeypoint.new(1,0)})
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.2,.25),NumberSequenceKeypoint.new(.8,.7),NumberSequenceKeypoint.new(1,1)})
 e.Parent=a;emitters[i]={anchor=a,effect=e}
end
local elapsed=0;local previous
table.insert(connections,Run.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.1 then return end;elapsed=0
 local camera=workspace.CurrentCamera;if not camera then return end
 local pos=camera.CFrame.Position;local reduced=player:GetAttribute('ReducedMotion')==true
 local now=os.clock();local near={};local landmarks={};local c=math.floor(pos.X/512)
 for key=c-2,c+2 do
  for p,r in cells[key] or {} do
   if not p:IsDescendantOf(workspace) then remove(p);continue end
   local distance=(r.base.Position-pos).Magnitude
   if r.landmark and distance<1200 then table.insert(landmarks,{p=p,r=r,d=distance})
   elseif not r.landmark and distance<650 then table.insert(near,{p=p,r=r,d=distance}) end
  end
 end
 table.sort(near,function(a,b) return a.d<b.d end)
 local nextActive={}
 if not reduced then
  for i=1,math.min(64,#near) do
   local item=near[i];local p,r=item.p,item.r
   local angle=math.sin(now*.85+r.phase)*.015*(.7+.3*math.sin(now*.21))
   p.CFrame=CFrame.new(r.foot)*CFrame.Angles(angle,0,angle*.55)*CFrame.new(-r.foot)*r.base
   nextActive[p]=true
  end
 end
 for p in active do if not nextActive[p] and p.Parent and records[p] then p.CFrame=records[p].base end end
 active=nextActive
 table.sort(landmarks,function(a,b) return a.d<b.d end)
 local teleported=previous and (previous-pos).Magnitude>250;previous=pos
 for i,v in emitters do
  local entry=landmarks[i]
  if reduced or not entry then v.effect.Enabled=false;if teleported then v.effect:Clear() end;continue end
  if v.target~=entry.p or teleported then v.effect:Clear();v.target=entry.p end
  local profile=Biomes.at(entry.r.base.Position)
  v.anchor.Position=entry.r.foot+Vector3.new(0,12,0)
  v.effect.Color=ColorSequence.new(profile.mote)
  v.effect.Acceleration=profile.id=='frozen' and Vector3.new(1,-2,.3) or profile.id=='inferno' and Vector3.new(.5,2,.2) or Vector3.new(1,.2,.5)
  v.effect.Enabled=true
 end
 player:SetAttribute('RiverlandsActiveFoliage',reduced and 0 or math.min(64,#near))
end))
script.Destroying:Connect(function()
 for _,c in connections do c:Disconnect() end
 for p in active do if p.Parent and records[p] then p.CFrame=records[p].base end end
 folder:Destroy()
end)
