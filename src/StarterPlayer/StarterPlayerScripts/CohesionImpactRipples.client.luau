local Tags=game:GetService('CollectionService')
local Run=game:GetService('RunService')
local player=game:GetService('Players').LocalPlayer
local rigs={}
local function remove(foam)
 local rig=rigs[foam]
 if rig then rig.anchor:Destroy();rigs[foam]=nil end
end
local function add(foam)
 if not foam:IsA('BasePart') or not foam:IsDescendantOf(workspace) or rigs[foam] then return end
 local anchor=Instance.new('Part')
 anchor.Name='LocalWaterfallRipple';anchor.Size=Vector3.one;anchor.Transparency=1
 anchor.Anchored=true;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false
 anchor.CFrame=CFrame.new(foam.Position+Vector3.new(0,.06,0));anchor.Parent=workspace
 local points={};local beams={}
 for i=1,12 do local a=Instance.new('Attachment');a.Parent=anchor;points[i]=a end
 for i=1,12 do
  local b=Instance.new('Beam');b.Attachment0=points[i];b.Attachment1=points[i%12+1]
  b.Width0=.32;b.Width1=.32;b.FaceCamera=true;b.Segments=1;b.LightEmission=.1
  b.Color=ColorSequence.new(Color3.fromRGB(211,246,245));b.Transparency=NumberSequence.new(1)
  b.Enabled=false;b.Parent=anchor;beams[i]=b
 end
 rigs[foam]={anchor=anchor,points=points,beams=beams,phase=(foam.Position.X%19)/19}
end
for _,p in Tags:GetTagged('CohesionRipple') do add(p) end
Tags:GetInstanceAddedSignal('CohesionRipple'):Connect(add)
Tags:GetInstanceRemovedSignal('CohesionRipple'):Connect(remove)
local elapsed=0
Run.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.1 then return end;elapsed=0
 local camera=workspace.CurrentCamera;if not camera then return end
 local nearest={}
 for foam,rig in rigs do
  for _,b in rig.beams do b.Enabled=false end
  if not foam:IsDescendantOf(workspace) then remove(foam);continue end
  local d=(camera.CFrame.Position-foam.Position).Magnitude
  if d<650 and player:GetAttribute('ReducedMotion')~=true then table.insert(nearest,{rig=rig,d=d}) end
 end
 table.sort(nearest,function(a,b)return a.d<b.d end)
 for i=1,math.min(4,#nearest) do
  local rig=nearest[i].rig;local t=(os.clock()/3.2+rig.phase)%1;local radius=6+t*17
  for j,a in rig.points do local angle=j/12*math.pi*2;a.Position=Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius*.65) end
  local alpha=NumberSequence.new(1-.32*math.sin(t*math.pi))
  for _,b in rig.beams do b.Enabled=true;b.Transparency=alpha end
 end
end)
script.Destroying:Connect(function() for foam in rigs do remove(foam) end end)
