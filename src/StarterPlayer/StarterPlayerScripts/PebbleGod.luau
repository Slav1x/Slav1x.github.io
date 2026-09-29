-- The Pebble God. Ancient, calm, restrained: he never hurries and never flails. Every pose
-- change eases in slowly, so even a raised hand reads as effortless; the spectacle belongs
-- to the water, the stones and the sky around him.
--
-- Built from Roblox parts (no uploaded assets): a tall robed figure about 2.3x the player,
-- a smooth pebble face with three skip marks on the brow, a halo of small orbiting stones,
-- and larger stones drifting around him. His front faces local -Z.
local RS=game:GetService("ReplicatedStorage")
local Golden=require(RS.Shared.GoldenMeridianConfig)
local VFX=require(script.Parent.AwakeningVFX)
local make,seq=VFX.make,VFX.seq
local God={}
God.__index=God
local S=.72 -- overall scale; the design below is authored at 1.0
local ROBE=Color3.fromRGB(46,48,58)
local ROBE_UPPER=Color3.fromRGB(64,66,78)
local MANTLE=Color3.fromRGB(80,82,94)
local HOOD=Color3.fromRGB(38,40,50)
local CREAM=Color3.fromRGB(226,210,168)
local TRIM=Color3.fromRGB(212,168,86)
local STONE=Color3.fromRGB(208,202,190)
local POSES={
 rest={lean=0,headPitch=0,right={pitch=.12,roll=.1,elbow=.35,wrist=0,fingers=.7},left={pitch=.12,roll=.1,elbow=.35,wrist=0,fingers=.7}},
 lift={lean=0,headPitch=.12,right={pitch=.12,roll=.1,elbow=.35,wrist=0,fingers=.7},left={pitch=.12,roll=.1,elbow=.35,wrist=0,fingers=.7}},
 palm={lean=.03,headPitch=-.05,right={pitch=.5,roll=.16,elbow=.85,wrist=-.45,fingers=0},left={pitch=.12,roll=.1,elbow=.35,wrist=0,fingers=.7}},
 twoFingers={lean=0,headPitch=0,right={pitch=.34,roll=.12,elbow=1.35,wrist=-.3,fingers=0},left={pitch=.12,roll=.1,elbow=.35,wrist=0,fingers=.7}},
 twoFingersUp={lean=0,headPitch=.04,right={pitch=.38,roll=.12,elbow=1.5,wrist=-.55,fingers=0},left={pitch=.12,roll=.1,elbow=.35,wrist=0,fingers=.7}},
 send={lean=0,headPitch=.02,right={pitch=.95,roll=.14,elbow=.45,wrist=-.9,fingers=0},left={pitch=.12,roll=.1,elbow=.35,wrist=0,fingers=.7}},
}
local function copyPose(p)
 return {lean=p.lean,headPitch=p.headPitch,right=table.clone(p.right),left=table.clone(p.left)}
end
function God.new(realm,rootCF)
 local self=setmetatable({realm=realm,root=rootCF,parts={},groups={},stones={},halo={},t=0,
  pose=copyPose(POSES.rest),target=copyPose(POSES.rest),rate=1.6,headYaw=0,lookAt=nil,eyes=0,eyesTarget=0,
  stonesRise=0,stonesRiseTarget=0,frozen=false,glow=.35,glowTarget=.35},God)
 local model=make("Model",realm.folder,{Name="PebbleGod"})
 self.model=model
 local function add(group,name,shape,size,offset,color,material,props)
  local p=Instance.new("Part")
  p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=true
  if shape=="Cylinder" then p.Shape=Enum.PartType.Cylinder elseif shape=="Ball" then p.Shape=Enum.PartType.Ball end
  p.Size=size*S;p.Color=color;p.Material=material or Enum.Material.SmoothPlastic
  if shape=="Ellipsoid" then make("SpecialMesh",p,{MeshType=Enum.MeshType.Sphere}) end
  for k,v in props or {} do p[k]=v end
  p.Parent=model
  local entry={part=p,group=group,offset=offset}
  table.insert(self.parts,entry)
  return p
 end
 local up=CFrame.Angles(0,0,math.pi/2) -- cylinders stand upright
 local function scaled(x,y,z) return CFrame.new(x*S,y*S,z*S) end
 -- Robe: a long tapering cone, gold at the hem.
 for _,r in {{1.2,7.6,.6},{1.7,7.0,1.95},{1.8,6.3,3.7},{1.8,5.6,5.45},{1.6,5.0,7.1},{1.0,4.6,8.4}} do
  add("base","Robe","Cylinder",Vector3.new(r[1],r[2],r[2]),scaled(0,r[3],0)*up,ROBE,Enum.Material.Fabric)
 end
 add("base","Hem","Cylinder",Vector3.new(.28,7.75,7.75),scaled(0,1.0,0)*up,TRIM,Enum.Material.Metal)
 add("base","Sash","Cylinder",Vector3.new(.18,5.12,5.12),scaled(0,7.25,0)*up,TRIM,Enum.Material.Metal)
 for _,side in {-1,1} do
  local a=Vector3.new(side*.7,.9,-3.72)*S;local b=Vector3.new(side*.6,8.6,-2.32)*S
  local cf=CFrame.lookAt((a+b)/2,b,Vector3.new(0,0,-1))
  add("base","Stole","Block",Vector3.new(.9,.12,(b-a).Magnitude/S),cf,CREAM,Enum.Material.Fabric)
 end
 -- Upper body (moves with the waist: breathing, the slightest lean).
 add("upper","Chest","Cylinder",Vector3.new(3.2,4.8,4.8),scaled(0,1.5,0)*up,ROBE_UPPER,Enum.Material.Fabric)
 for _,side in {-1,1} do
  local a=Vector3.new(side*1.5,4.1,-1.55)*S;local b=Vector3.new(-side*.55,.35,-2.35)*S
  add("upper","Fold","Block",Vector3.new(.7,.1,(b-a).Magnitude/S),CFrame.lookAt((a+b)/2,b,Vector3.new(0,0,-1)),CREAM,Enum.Material.Fabric)
 end
 add("upper","Mantle","Ellipsoid",Vector3.new(6.6,1.5,3.9),scaled(0,3.55,0),MANTLE,Enum.Material.Fabric)
 for i=1,10 do
  local a=(i-1)/10*math.pi*2
  add("upper","Bead","Ball",Vector3.one*.34,scaled(math.cos(a)*1.15,4.35,math.sin(a)*1.15),TRIM,Enum.Material.Metal)
 end
 add("upper","Hood","Ellipsoid",Vector3.new(3.5,3.9,3.3),scaled(0,5.2,.55),HOOD,Enum.Material.Fabric)
 self.chestLight=make("PointLight",nil,{Color=Golden.Gold,Range=22*S,Brightness=.6,Shadows=false})
 -- Head: a smooth pebble mask. Closed eyes are fine lines; open, they are two soft lights.
 add("head","Face","Ellipsoid",Vector3.new(1.8,2.4,1.6),scaled(0,1.15,-.25),STONE,Enum.Material.Marble)
 self.eyesClosed={};self.eyesOpen={}
 for _,side in {-1,1} do
  table.insert(self.eyesClosed,add("head","EyeLine","Block",Vector3.new(.52,.06,.05),scaled(side*.38,1.25,-.96)*CFrame.Angles(0,0,-side*.1),Color3.fromRGB(70,64,58)))
  table.insert(self.eyesOpen,add("head","EyeLight","Ellipsoid",Vector3.new(.34,.14,.05),scaled(side*.38,1.26,-.97),Golden.WhiteGold,Enum.Material.Neon,{Transparency=1}))
 end
 -- Three skip marks on the brow: a pebble's path across the water.
 self.marks={}
 for i,m in {{-.32,1.88,-.8},{0,2.02,-.78},{.32,1.88,-.8}} do
  self.marks[i]=add("head","SkipMark","Ball",Vector3.one*.13,scaled(m[1],m[2],m[3]),Golden.Gold,Enum.Material.Neon)
 end
 -- Arms: sleeves, hands, and two fingers on the right hand for the smallest gestures.
 for _,sideName in {"left","right"} do
  local g=sideName
  add(g.."Upper","Sleeve","Cylinder",Vector3.new(2.8,1.55,1.55),scaled(0,-1.3,0)*up,ROBE_UPPER,Enum.Material.Fabric)
  add(g.."Lower","Cuff","Cylinder",Vector3.new(1.2,2.0,2.0),scaled(0,-.55,0)*up,ROBE_UPPER,Enum.Material.Fabric)
  add(g.."Lower","Cuff","Cylinder",Vector3.new(1.1,2.5,2.5),scaled(0,-1.5,0)*up,ROBE,Enum.Material.Fabric)
  add(g.."Lower","CuffTrim","Cylinder",Vector3.new(.14,2.56,2.56),scaled(0,-2.02,0)*up,TRIM,Enum.Material.Metal)
  add(g.."Hand","Hand","Ellipsoid",Vector3.new(.72,.95,.42),scaled(0,-.3,0),STONE,Enum.Material.Marble)
  add(g.."Hand","Thumb","Ellipsoid",Vector3.new(.2,.42,.2),scaled(-.34,-.4,-.1)*CFrame.Angles(0,0,.5),STONE,Enum.Material.Marble)
  add(g.."Finger1","Finger","Ellipsoid",Vector3.new(.17,.62,.17),scaled(0,-.3,0),STONE,Enum.Material.Marble)
  add(g.."Finger2","Finger","Ellipsoid",Vector3.new(.17,.58,.17),scaled(0,-.28,0),STONE,Enum.Material.Marble)
 end
 -- Halo: small stones orbiting behind his head, and a thread of gold.
 local haloColors={Color3.fromRGB(196,188,172),Color3.fromRGB(120,122,130),Color3.fromRGB(226,214,190),Color3.fromRGB(92,96,104)}
 for i=1,9 do
  local p=add("halo","HaloStone","Ellipsoid",Vector3.new(.46,.26,.36),CFrame.identity,haloColors[(i-1)%4+1],Enum.Material.Slate)
  table.insert(self.halo,{part=p,angle=(i-1)/9*math.pi*2})
 end
 self.haloRing=VFX.ring(model,"HaloThread",30,Golden.Gold,.05*S,.55,rootCF)
 -- Larger stones drift around him.
 local rng=Random.new(9)
 for i=1,6 do
  local size=rng:NextNumber(1.2,2.6)
  local p=add("stones","DriftStone","Ellipsoid",Vector3.new(size,size*.55,size*.8),CFrame.identity,haloColors[(i-1)%4+1],Enum.Material.Slate)
  table.insert(self.stones,{part=p,angle=(i-1)/6*math.pi*2+rng:NextNumber(-.3,.3),radius=rng:NextNumber(7,9.5),height=rng:NextNumber(4,9.5),bob=rng:NextNumber(.2,.45),phase=rng:NextNumber(0,6.28),spin=rng:NextNumber(-.4,.4),rise=rng:NextNumber(8,16)})
 end
 -- Presence: a warm light, sparse motes, and a faint glow on the water beneath him.
 local chest
 for _,e in self.parts do if e.part.Name=="Chest" then chest=e.part end end
 self.chestLight.Parent=chest
 self.motes=make("ParticleEmitter",chest,{Name="Presence",Texture=VFX.Sparkle,Rate=3,Lifetime=NumberRange.new(3,5),Speed=NumberRange.new(.2,.6),SpreadAngle=Vector2.new(180,180),
  Acceleration=Vector3.new(0,.4,0),LightEmission=1,LightInfluence=0,Color=ColorSequence.new(Golden.WhiteGold,Golden.Gold),Size=seq(0,0,.3,.1,1,0),Transparency=seq(0,1,.3,.3,1,1)})
 self.nextRipple=0
 self:update(0)
 return self
end
-- Ease toward a named pose (or a table). Restraint is the default: slow, settled motion.
function God:setPose(name,rate)
 local p=POSES[name]
 if p then self.target=copyPose(p) end
 self.rate=rate or 1.6
end
-- Reach the right hand to a world point (the blessing). Solves the arm in the leaning body.
function God:reachTo(point,lean)
 self.target=copyPose(POSES.rest)
 self.target.lean=lean or .38
 self.target.headPitch=-.42
 self.reach=point
 self.rate=1.1
end
function God:setEyes(open) self.eyesTarget=open end
function God:setGlow(level) self.glowTarget=level end
function God:setLook(position) self.lookAt=position end
function God:riseStones(amount) self.stonesRiseTarget=amount end
function God:freezeStones(frozen) self.frozen=frozen end
local function approach(a,b,k) return a+(b-a)*k end
local function approachArm(a,b,k)
 for key,value in b do a[key]=approach(a[key],value,k) end
end
function God:joints()
 local p=self.pose
 local breathe=math.sin(self.t*.9)*.05*S
 local waist=self.root*CFrame.new(0,8.6*S+breathe,0)*CFrame.Angles(-p.lean,0,0)
 local neck=waist*CFrame.new(0,4.5*S,0)*CFrame.Angles(0,self.headYaw,0)*CFrame.Angles(p.headPitch,0,0)
 local arms={}
 for _,sideName in {"left","right"} do
  local side=sideName=="right" and 1 or -1
  local a=p[sideName]
  local shoulder=waist*CFrame.new(side*2.75*S,3.3*S,0)*CFrame.Angles(a.pitch,0,side*a.roll)
  local elbow=shoulder*CFrame.new(0,-2.6*S,0)*CFrame.Angles(a.elbow,0,0)
  local hand=elbow*CFrame.new(0,-2.35*S,-.1*S)*CFrame.Angles(a.wrist,0,0)
  local curl=a.fingers
  arms[sideName]={upper=shoulder,lower=elbow,hand=hand,
   finger1=hand*CFrame.new(.12*S,-.72*S,-.02*S)*CFrame.Angles(curl*1.2,0,0),
   finger2=hand*CFrame.new(-.1*S,-.7*S,-.02*S)*CFrame.Angles(curl*1.3,0,0)}
 end
 return waist,neck,arms
end
function God:update(dt)
 self.t+=dt
 local t=self.t
 local k=1-math.exp(-dt*self.rate)
 local p,target=self.pose,self.target
 p.lean=approach(p.lean,target.lean,k);p.headPitch=approach(p.headPitch,target.headPitch,k)
 -- The blessing solves the arm toward the player's head inside the leaning body.
 if self.reach then
  local waist=self.root*CFrame.new(0,8.6*S,0)*CFrame.Angles(-p.lean,0,0)
  local shoulder=waist*CFrame.new(2.75*S,3.3*S,0)
  local dir=waist:VectorToObjectSpace(self.reach-shoulder.Position).Unit
  local roll=math.asin(math.clamp(dir.X,-1,1))
  local c=math.max(.05,math.cos(roll))
  target.right.pitch=math.atan2(-dir.Z/c,-dir.Y/c);target.right.roll=roll
  target.right.elbow=.08;target.right.wrist=-.55;target.right.fingers=.15
 end
 approachArm(p.right,target.right,k);approachArm(p.left,target.left,k)
 -- He turns his head toward what he is attending to, slowly and not far.
 if self.lookAt then
  local flat=self.root:PointToObjectSpace(self.lookAt)
  local yaw=math.clamp(math.atan2(-flat.X,-flat.Z),-.45,.45)
  self.headYaw=approach(self.headYaw,yaw,1-math.exp(-dt*1.2))
 end
 self.eyes=approach(self.eyes,self.eyesTarget,1-math.exp(-dt*2))
 self.glow=approach(self.glow,self.glowTarget,1-math.exp(-dt*1.5))
 self.stonesRise=approach(self.stonesRise,self.stonesRiseTarget,1-math.exp(-dt*.9))
 local waist,neck,arms=self:joints()
 local frames={}
 local list={}
 for _,e in self.parts do
  local g=e.group
  local base
  if g=="base" then base=self.root
  elseif g=="upper" then base=waist
  elseif g=="head" then base=neck
  elseif g=="leftUpper" then base=arms.left.upper elseif g=="leftLower" then base=arms.left.lower elseif g=="leftHand" then base=arms.left.hand
  elseif g=="leftFinger1" then base=arms.left.finger1 elseif g=="leftFinger2" then base=arms.left.finger2
  elseif g=="rightUpper" then base=arms.right.upper elseif g=="rightLower" then base=arms.right.lower elseif g=="rightHand" then base=arms.right.hand
  elseif g=="rightFinger1" then base=arms.right.finger1 elseif g=="rightFinger2" then base=arms.right.finger2 end
  if base then table.insert(list,e.part);table.insert(frames,base*e.offset) end
 end
 -- Halo stones: a slow wheel behind the head.
 local haloCenter=neck*CFrame.new(0,1.35*S,.95*S)
 for _,h in self.halo do
  local a=h.angle+t*.1
  table.insert(list,h.part);table.insert(frames,haloCenter*CFrame.new(math.cos(a)*1.9*S,math.sin(a)*1.9*S,0)*CFrame.Angles(a,a*.7,0))
 end
 self.haloRing:place(haloCenter*CFrame.Angles(math.pi/2,0,0),1.55*S,t*.05)
 -- Drifting stones. Frozen, they hang perfectly still.
 local drift=self.frozen and 0 or 1
 self.driftT=(self.driftT or 0)+dt*drift
 for _,s in self.stones do
  local a=s.angle+self.driftT*.08
  local y=s.height+math.sin(self.driftT*.7+s.phase)*s.bob+self.stonesRise*s.rise
  table.insert(list,s.part)
  table.insert(frames,self.root*CFrame.new(math.cos(a)*s.radius*S,y*S,math.sin(a)*s.radius*S)*CFrame.Angles(self.driftT*s.spin,a,0))
 end
 workspace:BulkMoveTo(list,frames,Enum.BulkMoveMode.FireCFrameChanged)
 for _,e in self.eyesClosed do e.Transparency=self.eyes end
 for _,e in self.eyesOpen do e.Transparency=1-self.eyes*.9 end
 for i,m in self.marks do m.Color=Golden.DeepGold:Lerp(Golden.WhiteGold,self.glow*(.7+.3*math.sin(t*1.3+i))) end
 self.chestLight.Brightness=.4+self.glow*1.2
 -- The water barely moves beneath him: one slow ring every few seconds.
 if t>=self.nextRipple then
  self.nextRipple=t+4.5
  self.realm:ripple(self.root.Position,14*S,4.2,Golden.WhiteGold,.35)
 end
end
function God:palm()
 local _,_,arms=self:joints()
 return arms.right.hand*CFrame.new(0,-.45*S,-.2*S)
end
function God:head() local _,neck=self:joints();return neck*CFrame.new(0,1.15*S,-.25*S) end
-- A few unhurried steps; each one sends an enormous, silent ring across the water.
function God:walkTo(D,targetCF,seconds,steps)
 steps=steps or 3
 local from=self.root
 local per=seconds/steps
 for i=1,steps do
  local a0,a1=(i-1)/steps,i/steps
  local stepFrom=from:Lerp(targetCF,a0);local stepTo=from:Lerp(targetCF,a1)
  self.realm:ripple(stepFrom.Position,48*S,3.2,Golden.WhiteGold,.55)
  if self.realm.audio then self.realm.audio:splash(.55,.12) end
  if not D:animate(per,function(a) local e=a*a*(3-2*a);self.root=stepFrom:Lerp(stepTo,e)*CFrame.new(0,math.sin(a*math.pi)*.12,0) end) then return false end
 end
 self.root=targetCF
 self.realm:ripple(targetCF.Position,36*S,3,Golden.WhiteGold,.4)
 return true
end
function God:parts()
 local list={}
 for _,e in self.parts do table.insert(list,e.part) end
 for _,p in self.haloRing.parts do table.insert(list,p) end
 return list
end
return God
