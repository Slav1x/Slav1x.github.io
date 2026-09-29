--!nonstrict
-- Authored skeletal poses. Server and clients sample the same clock for exact contact.
local M={Version=1,ReleaseDelay={Monkey=.16,Gorilla=.24},Recovery={Monkey=.72,Gorilla=.9}}
local ID=CFrame.identity
local FLIP=CFrame.Angles(0,math.pi,0)
local cache=setmetatable({},{__mode='k'})
local function r(x,y,z,dy)
 return CFrame.new(0,dy or 0,0)*CFrame.Angles(math.rad(x or 0),math.rad(y or 0),math.rad(z or 0))
end
local function mix(a,b,t)
 local out={};t=math.clamp(t,0,1);t=t*t*(3-2*t)
 for name,value in a do out[name]=value:Lerp(b[name] or ID,t) end
 for name,value in b do if not out[name] then out[name]=ID:Lerp(value,t) end end
 return out
end
local monkeyTrap={Spine=r(-6,0,-7),Chest=r(5,-10,5),Head=r(14,15,0),RThigh=r(53,0,-9),RShin=r(-80),RFoot=r(30),LUpperArm=r(30,0,-24),RUpperArm=r(20,0,20),LForearm=r(30),RForearm=r(48),Tail1=r(0,-20,12),Tail2=r(-12)}
local monkeyWind={Root=r(0,0,0,.12),Spine=r(9,-17,-7),Chest=r(0,13,5),Head=r(-7,4,3),RThigh=r(-38,0,-8),RShin=r(-57),RFoot=r(30),LThigh=r(7),LShin=r(-9),LUpperArm=r(58,0,-32),RUpperArm=r(-27,0,26),LForearm=r(20),RForearm=r(46),Tail1=r(-10,-28,13),Tail2=r(15,8),Tail3=r(8,-8)}
local monkeyContact={Root=r(0,0,0,.32),Spine=r(-14,20,-9),Chest=r(-5,-8,5),Head=r(8,-12,4),RThigh=r(100,0,-10),RShin=r(-12),RFoot=r(-13),LThigh=r(-4),LUpperArm=r(-28,0,-45),RUpperArm=r(65,0,32),LForearm=r(25),RForearm=r(18),Tail1=r(12,34,-15),Tail2=r(-18,-12),Tail3=r(-10,12)}
local monkeyFollow={Root=r(0,0,0,.20),Spine=r(-8,30,-5),Chest=r(5,-10,6),Head=r(-5,-18,0),RThigh=r(113,0,-16),RShin=r(-35),RFoot=r(-18),LUpperArm=r(-35,0,-30),RUpperArm=r(82,0,20),LForearm=r(28),RForearm=r(42),Tail1=r(12,43,-9),Tail2=r(-12,-20)}
local gorillaTrap={Root=r(0,0,0,-.1),Spine=r(12,8,0),Chest=r(7,-13,0),Head=r(12,8,0),RUpperArm=r(80,0,-18),RForearm=r(52,0,-12),RHand=r(-15),LUpperArm=r(35,0,16),LForearm=r(45),RThigh=r(8),RShin=r(-12),LThigh=r(8),LShin=r(-12)}
local gorillaWind={Root=r(0,0,0,-.2),Spine=r(-9,-14,0),Chest=r(-7,-15,5),Head=r(12,27,-5),RUpperArm=r(190,0,-16),RForearm=r(80,0,-12),RHand=r(-20),LUpperArm=r(63,0,24),LForearm=r(30),RThigh=r(12),RShin=r(-20),LThigh=r(8),LShin=r(-14)}
local gorillaContact={Root=r(0,0,0,.18),Spine=r(12,17,-3),Chest=r(12,15,-4),Head=r(-12,-18,3),RUpperArm=r(108,0,-17),RForearm=r(-4,0,-5),RHand=r(18),LUpperArm=r(-20,0,35),LForearm=r(40),RThigh=r(-4),LThigh=r(5),LShin=r(-8)}
local gorillaFollow={Root=r(0,0,0,.02),Spine=r(20,27,-4),Chest=r(13,15,-7),Head=r(-17,-25,7),RUpperArm=r(56,0,-26),RForearm=r(28,0,-8),RHand=r(27),LUpperArm=r(-27,0,35),LForearm=r(55),RThigh=r(8),RShin=r(-12),LThigh=r(13),LShin=r(-16)}
function M.idle(kind,time,reduced)
 local sway=math.sin(time*1.8);local breath=math.sin(time*2.5)
 if reduced then return {} end
 return {Spine=r(0,0,sway*(kind=='Monkey' and 1.7 or .8)),Chest=r(breath*.8),Head=r(math.sin(time*.8)*2,math.sin(time*.55)*7,-sway),LUpperArm=r(breath*1.6),RUpperArm=r(-breath*1.6),LForearm=r(6),RForearm=r(8),Tail1=r(math.sin(time*1.4)*4,sway*9,0),Tail2=r(0,math.sin(time*1.8-.5)*12),Tail3=r(0,math.sin(time*1.8-1)*14)}
end
function M.sample(kind,state,elapsed,time,reduced,initial)
 local big=kind=='Gorilla';local trap=big and gorillaTrap or monkeyTrap;local wind=big and gorillaWind or monkeyWind
 local contact=big and gorillaContact or monkeyContact;local follow=big and gorillaFollow or monkeyFollow
 local idle=M.idle(kind,time or 0,reduced)
 if state=='Catch' then
  if elapsed<.14 then return mix(idle,trap,elapsed/.14) end
  if elapsed<.38 then return mix(trap,wind,(elapsed-.14)/.24) end
  return wind
 elseif state=='Kick' or state=='Throw' then
  local release=M.ReleaseDelay[kind]
  if elapsed<release then return mix(initial or wind,contact,elapsed/release) end
  if elapsed<release+.16 then return mix(contact,follow,(elapsed-release)/.16) end
  return mix(follow,idle,(elapsed-release-.16)/M.Recovery[kind])
 elseif state=='Miss' then
  local droop={Spine=r(9),Chest=r(7),Head=r(22,0,-5),LUpperArm=r(0,0,-8),RUpperArm=r(0,0,8),Tail1=r(14)}
  if elapsed<.22 then return mix(wind,droop,elapsed/.22) end
  return mix(droop,idle,(elapsed-.22)/.65)
 end
 return idle
end
function M.getRig(model)
 if cache[model] then return cache[model] end
 local mesh=model:FindFirstChild('CharacterMesh');if not mesh then return nil end
 local rig={model=model,mesh=mesh,bones={},ordered={}}
 local function walk(parent)
  for _,b in parent:GetChildren() do if b:IsA('Bone') then
   local item={bone=b,name=b.Name,bind=b.CFrame,parent=if b.Parent:IsA('Bone') then b.Parent.Name else nil}
   rig.bones[b.Name]=item;table.insert(rig.ordered,item);walk(b)
  end end
 end
 walk(mesh);cache[model]=rig;return rig
end
function M.poseAt(model,now,reduced)
 local kind=model:GetAttribute('PrimateKind') or 'Monkey'
 local state=model:GetAttribute('PrimateState') or 'Idle';local started=model:GetAttribute('PrimateStarted') or 0
 if state=='Catch' and now-started>1.5 then state='Idle' end
 local initial
 if state=='Kick' or state=='Throw' then initial=M.sample(kind,'Catch',model:GetAttribute('PrimateCatchAge') or .4,now,reduced) end
 return M.sample(kind,state,math.max(0,now-started),now,reduced,initial)
end
function M.apply(model,pose)
 local rig=M.getRig(model);if not rig then return end
 for _,item in rig.ordered do item.bone.Transform=FLIP*(pose[item.name] or ID)*FLIP:Inverse() end
end
function M.contact(model,now,pose)
 local rig=M.getRig(model);if not rig then return nil end
 pose=pose or M.poseAt(model,now)
 local world={}
 for _,item in rig.ordered do world[item.name]=(if item.parent then world[item.parent] else rig.mesh.CFrame)*item.bind*(FLIP*(pose[item.name] or ID)*FLIP:Inverse()) end
 local big=model:GetAttribute('PrimateKind')=='Gorilla'
 local cf=world[if big then 'RHand' else 'RFoot']
 -- Importer's local axes face +Z; the pad/hand offset follows the deforming bone.
 return cf and cf:PointToWorldSpace(if big then Vector3.new(0,-.3,1.05) else Vector3.new(0,.28,1.45))
end
function M.begin(model,state,now)
 if not model then return end
 model:SetAttribute('PrimateStarted',now);model:SetAttribute('PrimateState',state)
end
return M

