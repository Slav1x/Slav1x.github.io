-- Sun Phoenix v3: shared pose evaluator, no per-pet connections or asset animation dependency.
local Flight={}
local FinishedHover=require(script.Parent:WaitForChild('SunPhoenixHover'))
local sin,cos,pi=math.sin,math.cos,math.pi
local function rotation(x,y,z) return CFrame.Angles(x,y,z) end
function Flight.bind(model)
 local state={model=model,bones={},phase=0,blend=0,time=0,orbits={},emitters={},finishedHover=model:GetAttribute('VisualRevision')==4}
 for _,v in model:GetDescendants() do
  if v:IsA('Bone') then
   state.bones[v.Name]=state.bones[v.Name] or {};table.insert(state.bones[v.Name],v)
  elseif v:IsA('Attachment') and v:GetAttribute('OrbitIndex') then table.insert(state.orbits,v)
  elseif v:IsA('ParticleEmitter') then table.insert(state.emitters,{v,v.Rate}) end
 end
 state.light=model:FindFirstChild('SolarLight',true)
 return state
end
function Flight.pose(phase,moving,t)
 local u=(phase/(2*pi))%1;local down=.42
 local stroke,recovery
 if u<down then stroke=cos(pi*u/down);recovery=0
 else stroke=-cos(pi*(u-down)/(1-down));recovery=sin(pi*(u-down)/(1-down)) end
 local bodyPitch=.055*sin(phase-.5)+.16*moving
 local p={Root=CFrame.new(0,.075*sin(phase-.55),0),Body=rotation(bodyPitch,0,.018*sin(t*.8)),Head=rotation(-bodyPitch*.82,.045*sin(t*.72),-.015*sin(t*.8)),Crest=rotation(.09*sin(phase-.75),0,.025*sin(t))}
 for _,side in {'L','R'} do
  local s=if side=='L' then -1 else 1
  -- Shorter open power stroke. Elbow/wrist fold and sweep back during recovery.
  p['Shoulder_'..side]=rotation(.035*sin(phase),s*.07*recovery,s*(.55*stroke-.09))
  p['Elbow_'..side]=rotation(.035*recovery,s*.15*recovery,s*(.15*stroke-.39*recovery))
  p['Wrist_'..side]=rotation(.025*sin(phase-.5),s*.15*recovery,s*(.12*cos(phase-.40)-.30*recovery))
  for n=0,2 do p['Fan'..n..'_'..side]=rotation(.04*sin(phase-.35-n*.15),s*(n-1)*.06*recovery,s*.10*sin(phase-.55-n*.2)) end
  p['Foot_'..side]=rotation(.07*sin(phase-.8)-.13*moving,0,s*.025*sin(phase))
 end
 for n=0,4 do
  p['Tail'..n]=rotation(-.13*sin(phase-.8-n*.09)-.14*moving,.035*sin(t*1.6+n*.35),0)
  p['TailTip'..n]=rotation(-.19*sin(phase-1.25-n*.13),.055*sin(t*1.6+n*.35-.5),0)
 end
 return p
end
function Flight.update(state,dt,speed,distance)
 state.time+=dt
 state.blend+=(math.clamp(speed/20,0,1)-state.blend)*(1-math.exp(-5*dt))
 state.phase+=(2*pi/(1.33-.30*state.blend))*dt
 if state.finishedHover then
  FinishedHover.apply(state.bones,state.time)
 else
  local p=Flight.pose(state.phase,state.blend,state.time)
  for name,list in state.bones do local cf=p[name] or CFrame.identity;for _,bone in list do bone.Transform=cf end end
 end
 for _,attachment in state.orbits do
  local n=attachment:GetAttribute('OrbitIndex');local a=state.time*.90+n*2*pi/3
  attachment.Position=Vector3.new(1.16*cos(a),.48+.72*sin(a*.85+n),.58*sin(a))
 end
 if state.light then state.light.Brightness=.55+.10*sin(state.time*2.4) end
 local near=distance<90
 for _,item in state.emitters do
  local emitter,base=item[1],item[2]
  emitter.Enabled=near
  if emitter.Name=='MotionSparks' then emitter.Rate=if speed>8 then 3+4*state.blend else 0 end
 end
end
return Flight

