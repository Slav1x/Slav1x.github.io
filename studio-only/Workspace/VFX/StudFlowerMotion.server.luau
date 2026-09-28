
-- Nearby flowers bend away from characters and recover with a damped spring.
-- Cosmetic client motion: anchored/non-colliding geometry never pushes players.
local root=script.Parent.Parent
local garden=root:WaitForChild("Decorations"):WaitForChild("StudFlowers")
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local player=Players.LocalPlayer
local flowers,characters,connections={},{},{}
local active={};local refresh=.2;local elapsed=0;local tick=0
local pendingFlowers={}
local function addFlower(m)
 if not m:IsA("Model") or flowers[m] then return end
 local rest=m:GetAttribute("RestPivot");local base=m:GetAttribute("StemBase")
 if not m:GetAttribute("StudFlowerReactive") or typeof(rest)~="CFrame" or typeof(base)~="Vector3" then
  if not pendingFlowers[m] then
   pendingFlowers[m]=m.AttributeChanged:Connect(function() addFlower(m) end)
  end
  return
 end
 if pendingFlowers[m] then pendingFlowers[m]:Disconnect();pendingFlowers[m]=nil end
 flowers[m]={model=m,rest=rest,base=base,phase=m:GetAttribute("WindPhase") or 0,bend=Vector2.zero,velocity=Vector2.zero,offset=CFrame.new(base):ToObjectSpace(rest)}
end
for _,m in garden:GetChildren() do addFlower(m) end
table.insert(connections,garden.ChildAdded:Connect(addFlower))
table.insert(connections,garden.ChildRemoved:Connect(function(m) flowers[m]=nil;if pendingFlowers[m] then pendingFlowers[m]:Disconnect();pendingFlowers[m]=nil end end))
local function watch(p)
 local function character(c)
  task.spawn(function()
   local hrp=c:WaitForChild("HumanoidRootPart",10)
   local hum=c:WaitForChild("Humanoid",10)
   if hrp and hum and p.Character==c then characters[p]={root=hrp,humanoid=hum} end
  end)
 end
 if p.Character then character(p.Character) end
 table.insert(connections,p.CharacterAdded:Connect(character))
 table.insert(connections,p.CharacterRemoving:Connect(function()characters[p]=nil end))
end
for _,p in Players:GetPlayers() do watch(p) end
table.insert(connections,Players.PlayerAdded:Connect(watch))
table.insert(connections,Players.PlayerRemoving:Connect(function(p)characters[p]=nil end))
local function reset(fd)
 if fd.moved and fd.model.Parent then fd.model:PivotTo(fd.rest) end
 fd.moved=false
 fd.bend=Vector2.zero;fd.velocity=Vector2.zero
end
local frame
frame=Run.Heartbeat:Connect(function(dt)
 if root ~= workspace and not root:IsDescendantOf(workspace) then
  for _,fd in flowers do reset(fd) end
  return
 end
 elapsed+=dt;refresh+=dt;tick+=dt
 if tick<1/30 then return end
 local step=math.min(tick,.05);tick=0
 local camera=workspace.CurrentCamera;if not camera then return end
 if refresh>=.2 then
  refresh=0
  local candidates={}
  for m,fd in flowers do
   if m:IsDescendantOf(workspace) then
    local distance=(fd.base-camera.CFrame.Position).Magnitude
    if distance<100 then table.insert(candidates,{fd=fd,d=distance}) else reset(fd) end
   end
  end
  table.sort(candidates,function(a,b)return a.d<b.d end)
  active={}
  for i,v in candidates do if i<=72 then table.insert(active,v.fd) else reset(v.fd) end end
 end
 local reduced=player:GetAttribute("ReducedMotion")==true
 local maxBend=0;local touching=0
 for _,fd in active do
  if not fd.model:IsDescendantOf(workspace) then continue end
  local target=Vector2.zero
  for _,c in characters do
   if c.root.Parent and c.humanoid.Health>0 then
    local delta=fd.base-c.root.Position
    local flat=Vector3.new(delta.X,0,delta.Z);local distance=flat.Magnitude
    if distance<3.6 and math.abs(delta.Y)<6 then
     local speed=c.root.AssemblyLinearVelocity
     local dir=distance>.08 and flat.Unit or Vector3.new(0,0,1)
     local amount=(1-distance/3.6)*math.clamp(.50+Vector3.new(speed.X,0,speed.Z).Magnitude*.012,.50,.8)
     target+=Vector2.new(dir.Z,-dir.X)*amount;touching+=1
    end
   end
  end
  if target.Magnitude>.75 then target=target.Unit*.75 end
  if reduced then target*=.45 end
  -- Two substeps keep the spring stable on low frame-rate clients.
  for _=1,2 do
   local h=step/2
   fd.velocity+=(target-fd.bend)*150*h-fd.velocity*16*h
   fd.bend+=fd.velocity*h
  end
  local wind=reduced and Vector2.zero or Vector2.new(math.sin(elapsed*1.35+fd.phase)*.045,math.cos(elapsed*.95+fd.phase)*.025)
  local angle=fd.bend+wind
  fd.model:PivotTo(CFrame.new(fd.base)*CFrame.Angles(angle.X,0,angle.Y)*fd.offset)
  fd.moved=true
  maxBend=math.max(maxBend,fd.bend.Magnitude)
 end
 if script:GetAttribute("DebugMetrics") then
  script:SetAttribute("ActiveFlowers",#active)
  script:SetAttribute("ContactCount",touching)
  script:SetAttribute("MaxContactBend",maxBend)
 end
end)
script.Destroying:Connect(function()
 frame:Disconnect()
 for _,c in pendingFlowers do c:Disconnect() end
 for _,c in connections do c:Disconnect() end
 for _,fd in flowers do reset(fd) end
end)


