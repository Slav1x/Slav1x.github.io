-- One distance-budgeted scheduler for authored movement and landmark VFX.
local Run=game:GetService('RunService');local Tags=game:GetService('CollectionService')
local player=game.Players.LocalPlayer
local motion={};local effects={};local tick=0
local function add(p)
 if p:IsA('BasePart') then motion[p]={base=p.CFrame,seed=p:GetAttribute('MotionSeed') or 0,kind=p:GetAttribute('MotionKind') or 'Float'} end
end
for _,p in Tags:GetTagged('WorldAmbientMotion') do add(p) end
Tags:GetInstanceAddedSignal('WorldAmbientMotion'):Connect(add)
Tags:GetInstanceRemovedSignal('WorldAmbientMotion'):Connect(function(p) motion[p]=nil end)
local function effect(e) if e:IsA('ParticleEmitter') then effects[e]=e.Rate;e.Enabled=false end end
for _,e in Tags:GetTagged('WorldLandmarkVFX') do effect(e) end
Tags:GetInstanceAddedSignal('WorldLandmarkVFX'):Connect(effect)
Tags:GetInstanceRemovedSignal('WorldLandmarkVFX'):Connect(function(e) effects[e]=nil end)
local connection=Run.Heartbeat:Connect(function(dt)
 tick+=dt;if tick<1/20 then return end;tick=0
 local camera=workspace.CurrentCamera;if not camera then return end
 local pos=camera.CFrame.Position;local now=workspace:GetServerTimeNow();local reduced=player:GetAttribute('ReducedMotion')==true
 local active=0
 for p,r in motion do
  if not p:IsDescendantOf(workspace) then motion[p]=nil;continue end
  local near=(r.base.Position-pos).Magnitude<800
  if near and not reduced and active<24 then
   active+=1
   if r.kind=='Sway' then p.CFrame=r.base*CFrame.Angles(0,0,math.sin(now*.5+r.seed)*.018)
   elseif r.kind=='Rotor' then p.CFrame=r.base*CFrame.Angles(now*.25,0,0)
   else p.CFrame=r.base*CFrame.new(0,math.sin(now*.65+r.seed)*1.3,0)*CFrame.Angles(0,math.sin(now*.13+r.seed)*.035,0) end
  elseif reduced then p.CFrame=r.base end
 end
 local vfx=0
 for e,rate in effects do
  if not e:IsDescendantOf(workspace) then effects[e]=nil;continue end
  local parent=e.Parent;local p=parent:IsA('Attachment') and parent.WorldPosition or parent.Position
  local enabled=not reduced and (p-pos).Magnitude<900 and vfx<12
  e.Enabled=enabled;if enabled then vfx+=1 end
 end
end)
script.Destroying:Connect(function() connection:Disconnect() end)
