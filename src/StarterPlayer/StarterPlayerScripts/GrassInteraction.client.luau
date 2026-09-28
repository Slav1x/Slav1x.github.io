-- Client-only flower-style sway and walk-through response for tagged grass clumps.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local CollectionService=game:GetService("CollectionService")
local player=Players.LocalPlayer
local TAG="InteractiveGrass"
local items={}
local connections={}
local previousPositions={}
local WIND_SPEED=1.5
local WIND_STRENGTH=.09
local PUSH_STRENGTH=.4
local PUSH_DURATION=1.5

local function track(object)
 if items[object] or not object:IsDescendantOf(workspace) then return end
 if not object:IsA("Model") and not object:IsA("BasePart") then return end
 local base=object:GetPivot()
 local cf,size
 if object:IsA("Model") then cf,size=object:GetBoundingBox() else cf,size=object.CFrame,object.Size end
 local foot=object:IsA("Model") and base.Position or (base*CFrame.new(0,-size.Y*.5,0)).Position
 items[object]={
  base=base,foot=foot,height=size.Y,
  radius=math.clamp(math.max(size.X,size.Z)*.5+.9,1.2,3),
  phase=foot.X*.13+foot.Z*.23,
  pushTime=-100,pushDirection=Vector3.zAxis,lastPush=-100,active=false,
 }
end
local function untrack(object)
 local item=items[object]
 if item and object:IsDescendantOf(workspace) then object:PivotTo(item.base) end
 items[object]=nil
end
for _,object in CollectionService:GetTagged(TAG) do track(object) end
table.insert(connections,CollectionService:GetInstanceAddedSignal(TAG):Connect(track))
table.insert(connections,CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack))
table.insert(connections,workspace.DescendantAdded:Connect(function(object)
 if CollectionService:HasTag(object,TAG) then task.defer(track,object) end
end))
table.insert(connections,workspace.DescendantRemoving:Connect(function(object) items[object]=nil end))
local accumulator=0
table.insert(connections,RunService.Heartbeat:Connect(function(dt)
 accumulator+=dt
 if accumulator<1/30 then return end
 accumulator=0
 local camera=workspace.CurrentCamera
 if not camera then return end
 local now=os.clock()
 local reduced=player:GetAttribute("ReducedMotion")==true
 local actors={}
 local nextPositions={}
 for _,actor in Players:GetPlayers() do
  local character=actor.Character
  local root=character and character:FindFirstChild("HumanoidRootPart")
  local humanoid=character and character:FindFirstChildOfClass("Humanoid")
  if root and humanoid and humanoid.Health>0 then
   local pos=root.Position
   local previous=previousPositions[actor]
   local valid=previous and previous.root==root and (pos-previous.position).Magnitude<24
   local old=valid and previous.position or pos
   local movement=Vector3.new(pos.X-old.X,0,pos.Z-old.Z)
   local velocity=root.AssemblyLinearVelocity
   table.insert(actors,{position=pos,old=old,movement=movement,
    moving=movement.Magnitude>.02 or Vector3.new(velocity.X,0,velocity.Z).Magnitude>1.5})
   nextPositions[actor]={root=root,position=pos}
  end
 end
 previousPositions=nextPositions
 for object,item in items do
  if not object:IsDescendantOf(workspace) then items[object]=nil;continue end
  local nearby=(camera.CFrame.Position-item.foot).Magnitude<130
  if reduced or not nearby then
   if item.active then object:PivotTo(item.base);item.active=false end
   item.pushTime=-100
   continue
  end
  if now-item.lastPush>=1 then
   for _,actor in actors do
    -- Proximity rather than Touched keeps decorative foliage non-colliding.
    -- Test a short swept segment so a quick walk does not skip thin reeds.
    if actor.moving and actor.position.Y>item.foot.Y-1 and actor.position.Y<item.foot.Y+item.height+4 then
     local origin=Vector3.new(actor.old.X,0,actor.old.Z)
     local target=Vector3.new(item.foot.X,0,item.foot.Z)
     local segment=actor.movement
     local t=segment:Dot(segment)>.0001 and math.clamp((target-origin):Dot(segment)/segment:Dot(segment),0,1) or 1
     local closest=origin+segment*t
     local away=target-closest
     if away.Magnitude<item.radius then
      local direction=away.Magnitude>.12 and away.Unit or (segment.Magnitude>.02 and segment.Unit or Vector3.zAxis)
      item.pushDirection=direction;item.pushTime=now;item.lastPush=now
      break
     end
    end
   end
  end
  local t=now*WIND_SPEED+item.phase
  local gust=.65+.35*math.sin(now*.32)
  local angleX=math.sin(t)*WIND_STRENGTH+WIND_STRENGTH*.2*gust
  local angleZ=math.cos(t*.7)*WIND_STRENGTH*.6-WIND_STRENGTH*.45*gust
  local progress=(now-item.pushTime)/PUSH_DURATION
  if progress>=0 and progress<1 then
   local push
   if progress<.15 then push=progress/.15
   else push=(1-(progress-.15)/.85)*(1+math.sin((progress-.15)*15)*.15) end
   push=math.max(0,push)*PUSH_STRENGTH
   angleX+=item.pushDirection.Z*push
   angleZ-=item.pushDirection.X*push
  end
  object:PivotTo(CFrame.new(item.foot)*CFrame.Angles(angleX,0,angleZ)*CFrame.new(-item.foot)*item.base)
  item.active=true
 end
end))
script.Destroying:Connect(function()
 for _,connection in connections do connection:Disconnect() end
 for object,item in items do if object:IsDescendantOf(workspace) then object:PivotTo(item.base) end end
 table.clear(items);table.clear(previousPositions)
end)
