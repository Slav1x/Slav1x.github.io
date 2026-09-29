local Scene={}
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Tween=game:GetService("TweenService")
local player=Players.LocalPlayer
local Catalog=require(game.ReplicatedStorage.Shared.RockCatalog)
local CAS=game:GetService("ContextActionService")
local Registry=require(game.ReplicatedStorage.Shared.SummonSceneRegistry)
local active
local binding="SummonHideLocalAvatar"
local function alignLabel(entry)
 if not entry.model.Parent or not entry.anchor.Parent then
  entry.board.Enabled=false
  return
 end
 local bounds,size=entry.model:GetBoundingBox()
 -- Convert the oriented bounds to a world-space top, including tilt and scale.
 local halfHeight=(math.abs(bounds.RightVector.Y)*size.X
  +math.abs(bounds.UpVector.Y)*size.Y
  +math.abs(bounds.LookVector.Y)*size.Z)*.5
 entry.anchor.WorldPosition=bounds.Position+Vector3.new(0,halfHeight+.35,0)
end
function Scene.stop()
 local s=active
 if not s then return end
 active=nil
 CAS:UnbindAction("SummonMovementLock")
 Run:UnbindFromRenderStep(binding)
 if s.added then s.added:Disconnect() end
 for object,entry in s.saved do
  if object.Parent then object[entry.property]=entry.value end
 end
 for _,board in s.boards do board:Destroy() end
 for _,entry in s.labels do entry.anchor:Destroy() end
end
function Scene.begin(token,continueCinematic)
 if continueCinematic and active then
  -- Keep the avatar, attached effects, and movement hidden across auto-rolls.
  for _,board in active.boards do board:Destroy() end
  for _,entry in active.labels do if entry.anchor.Parent then entry.anchor:Destroy() end end
  active.boards={};active.labels={};active.token=token
  return
 end
 Scene.stop()
 local s={token=token,saved={},boards={},labels={},started=os.clock()}
 active=s
 CAS:BindActionAtPriority("SummonMovementLock",function() return Enum.ContextActionResult.Sink end,false,Enum.ContextActionPriority.High.Value+100,unpack(Enum.PlayerActions:GetEnumItems()))
 local character=player.Character
 local function hide(object)
  local property
  if object:IsA("BasePart") then property="LocalTransparencyModifier"
  elseif object:IsA("Decal") then property="Transparency"
  elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") or object:IsA("BillboardGui") then property="Enabled"
  elseif object:IsA("Humanoid") then property="DisplayDistanceType" end
  if property and not s.saved[object] then
   local value=object[property]
   local hidden
   if property=="Enabled" then hidden=false
   elseif property=="DisplayDistanceType" then hidden=Enum.HumanoidDisplayDistanceType.None
   else hidden=1 end
   s.saved[object]={property=property,value=value,hidden=hidden}
   if type(hidden)~="number" then object[property]=hidden end
  end
 end
 if character then
  for _,object in character:GetDescendants() do hide(object) end
  s.added=character.DescendantAdded:Connect(hide)
 end
 Run:BindToRenderStep(binding,Enum.RenderPriority.Last.Value,function()
  for _,entry in s.labels do alignLabel(entry) end
  local t=math.clamp((os.clock()-s.started)/.65,0,1)
  local fade=t*t*(3-2*t)
  for object,entry in s.saved do
   if object.Parent then
    if type(entry.hidden)=="number" then
     object[entry.property]=entry.value+(entry.hidden-entry.value)*fade
    else
     object[entry.property]=entry.hidden
    end
   end
  end
 end)
end
function Scene.fadeOut(slot)
 local s=active
 local board=s and s.boards[slot or 1]
 if not board then return end
 for _,object in board:GetChildren() do
  if object:IsA("TextLabel") then
   Tween:Create(object,TweenInfo.new(require(game.ReplicatedStorage.Shared.SummonConfig).ExitSeconds),{TextTransparency=1,TextStrokeTransparency=1}):Play()
  end
 end
end
function Scene.showResult(data)
 local s=active
 if not s or s.token~=data.token then return end
 task.spawn(function()
  local model=data.model
  local deadline=os.clock()+2
  while active==s and (not model or not model.Parent) and os.clock()<deadline do
   model=Registry.find(data.token,data.slot or 1,true)
   if not model or not model.Parent then Run.Heartbeat:Wait() end
  end
  if active~=s or not model or not model.Parent then return end
  local part=model:FindFirstChildWhichIsA("BasePart",true)
  if not part then return end
  local slot=data.slot or 1
  if s.boards[slot] then s.boards[slot]:Destroy() end
  if s.labels[slot] then s.labels[slot].anchor:Destroy() end
  local rock=Catalog.get(data.id)
  local color=Catalog.RarityColors[rock.rarity] or Color3.new(1,1,1)
  if data.variant=="Enchanted" then local _,accent=require(game.ReplicatedStorage.Shared.RockAppearance).palette(rock.id);color=accent end
  local board=Instance.new("BillboardGui")
  board.Name="SummonRockDetails"
  local anchor=Instance.new("Attachment")
  anchor.Name="SummonLabelCenter";anchor.Parent=part
  board.Adornee=anchor
  board.Size=UDim2.fromOffset(data.batchSize and data.batchSize>1 and 210 or 300,108)
  board.StudsOffsetWorldSpace=Vector3.zero
  -- The bottom of the label stack sits above the item, independent of camera distance.
  board.SizeOffset=Vector2.new(0,.5)
  board.AlwaysOnTop=true
  board.LightInfluence=0
  board.MaxDistance=80
  local entry={model=model,anchor=anchor,board=board}
  alignLabel(entry)
  s.labels[slot]=entry
  board.Parent=player.PlayerGui
  s.boards[slot]=board
  local function text(name,value,y,height,size,tint)
   local label=Instance.new("TextLabel")
   label.Name=name
   label.BackgroundTransparency=1
   label.Position=UDim2.fromOffset(0,y)
   label.Size=UDim2.new(1,0,0,height)
   label.Text=value
   label.TextXAlignment=Enum.TextXAlignment.Center
   label.Font=Enum.Font.FredokaOne
   label.TextSize=size
   label.TextColor3=tint
   label.TextStrokeColor3=Color3.fromRGB(9,14,24)
   label.TextTransparency=1
   label.TextStrokeTransparency=1
   label.Parent=board
   Tween:Create(label,TweenInfo.new(.25),{TextTransparency=0,TextStrokeTransparency=.2}):Play()
  end
  text("Discovery",data.isNew and "NEW DISCOVERY" or "COLLECTION EXPANDED",0,18,11,color)
  text("RockName",(data.variant=="Enchanted" and "Enchanted " or "")..rock.name,20,28,23,Color3.new(1,1,1))
  text("Rarity",(data.variant=="Enchanted" and "✦ ENCHANTED • " or "")..string.upper(rock.rarity),49,18,13,color)
  text("Details",(data.variant=="Enchanted" and ("1.3x "..Catalog.specialtyLabel(rock.id).." specialty") or string.format("%.2fx strength  •  %s owned",Catalog.resolveStats(rock.id,nil,data.variant).strengthMultiplier,tostring(data.count or 1))),69,18,12,Color3.fromRGB(226,237,248))
  text("Stored","ADDED TO YOUR COLLECTION",90,16,10,color)
 end)
end
player.CharacterRemoving:Connect(Scene.stop)
return Scene

