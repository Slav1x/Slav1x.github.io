-- Small, local cosmetic motion for the additive woodland art pass.
-- One throttled loop; no gameplay transforms, water heights or station objects.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local player=Players.LocalPlayer
local root=workspace:WaitForChild('WoodlandPolish')
local moving,emitters,lights={},{},{}
local function track(object)
 if object:IsA('Model') and object:GetAttribute('WindSway') and not object:GetAttribute('InteractiveGrass') then
  moving[object]={base=object:GetPivot(),phase=object:GetPivot().Position.X*.13+object:GetPivot().Position.Z*.23,active=false}
 elseif object:IsA('ParticleEmitter') then
  emitters[object]=object:GetAttribute('DistanceLimit') or 150
 elseif object:IsA('PointLight') and object:GetAttribute('GentleFlicker') then
  lights[object]={brightness=object.Brightness,phase=object.Parent.Position.Z*.11}
 end
end
for _,object in root:GetDescendants() do track(object) end
local added=root.DescendantAdded:Connect(track)
local removed=root.DescendantRemoving:Connect(function(object) moving[object]=nil;emitters[object]=nil;lights[object]=nil end)
local elapsed=0
local connection=RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt
 if elapsed<1/20 then return end
 elapsed=0
 local camera=workspace.CurrentCamera
 if not camera then return end
 local position=camera.CFrame.Position
 local reduced=player:GetAttribute('ReducedMotion')==true
 local t=os.clock()
 local gust=.65+.25*math.sin(t*.37)
 for model,item in moving do
  if model.Parent then
   local visible=(position-item.base.Position).Magnitude<125
   if visible and not reduced then
    model:PivotTo(item.base*CFrame.Angles(math.sin(t*1.1+item.phase)*.025*gust,0,math.sin(t*.83+item.phase)*.035*gust))
    item.active=true
   elseif item.active then model:PivotTo(item.base);item.active=false end
  end
 end
 for emitter,distance in emitters do
  if emitter.Parent and emitter.Parent:IsA('BasePart') then
   emitter.Enabled=not reduced and (position-emitter.Parent.Position).Magnitude<distance
  end
 end
 for light,item in lights do
  if light.Parent and light.Parent:IsA('BasePart') then
   light.Enabled=(position-light.Parent.Position).Magnitude<160
   light.Brightness=item.brightness*(reduced and 1 or (1+.035*math.sin(t*2+item.phase)+.02*math.sin(t*3.7)))
  end
 end
end)
script.Destroying:Connect(function()
 connection:Disconnect();added:Disconnect();removed:Disconnect()
 for model,item in moving do if model.Parent then model:PivotTo(item.base) end end
 for light,item in lights do if light.Parent then light.Brightness=item.brightness;light.Enabled=true end end
end)

