-- Client-side cubic Bezier motes. One bounded pool per geode; no per-mote connections.
local Curves={}
Curves.__index=Curves
local LIMIT=32
local K=.5522847498
function Curves.point(a,b,c,d,t)
 local u=1-t
 return a*(u*u*u)+b*(3*u*u*t)+c*(3*u*t*t)+d*(t*t*t)
end
function Curves.tangent(a,b,c,d,t)
 local u=1-t
 return (b-a)*(3*u*u)+(c-b)*(6*u*t)+(d-c)*(3*t*t)
end
local segments={
  {Vector3.new(1,0,0),Vector3.new(1,0,K),Vector3.new(K,0,1),Vector3.new(0,0,1)},
  {Vector3.new(0,0,1),Vector3.new(-K,0,1),Vector3.new(-1,0,K),Vector3.new(-1,0,0)},
  {Vector3.new(-1,0,0),Vector3.new(-1,0,-K),Vector3.new(-K,0,-1),Vector3.new(0,0,-1)},
  {Vector3.new(0,0,-1),Vector3.new(K,0,-1),Vector3.new(1,0,-K),Vector3.new(1,0,0)},
 }

function Curves.orbit(t,radius)
 local phase=(t%1)*4
 local p=segments[math.floor(phase)+1]
 return Curves.point(p[1],p[2],p[3],p[4],phase%1)*radius
end
function Curves.new(parent,center,color,seed)
 return setmetatable({parent=parent,center=center,color=color,pool={},cursor=0,clock=0,
  random=Random.new(seed),accepting=true,destroyed=false},Curves)
end
function Curves:_slot()
 self.cursor=self.cursor%LIMIT+1
 local item=self.pool[self.cursor]
 if not item then
  local head=Instance.new("Part")
  head.Name="BezierSpark";head.Shape=Enum.PartType.Ball;head.Material=Enum.Material.Neon
  head.Anchored=true;head.CanCollide=false;head.CanTouch=false;head.CanQuery=false
  head.CastShadow=false;head.Size=Vector3.one*.12;head.Transparency=1;head.Parent=self.parent
  local a=Instance.new("Attachment");a.Position=Vector3.new(-.045,0,0);a.Parent=head
  local b=Instance.new("Attachment");b.Position=Vector3.new(.045,0,0);b.Parent=head
  local trail=Instance.new("Trail")
  trail.Name="CurvedEnergyTrail";trail.Attachment0=a;trail.Attachment1=b
  trail.FaceCamera=true;trail.Lifetime=.22;trail.MinLength=.015
  trail.LightEmission=1;trail.LightInfluence=0
  trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.08),NumberSequenceKeypoint.new(.65,.45),NumberSequenceKeypoint.new(1,1)})
  trail.WidthScale=NumberSequence.new(1,0);trail.Enabled=false;trail.Parent=head
  item={head=head,trail=trail}
  if self.cursor<=2 then
   local light=Instance.new("PointLight")
   light.Name="MovingEnergyLight";light.Range=4;light.Shadows=false;light.Brightness=0;light.Parent=head
   item.light=light
  end
  self.pool[self.cursor]=item
 end
 item.trail.Enabled=false;item.trail:Clear()
 return item
end
function Curves:emit(kind,count,radius,duration)
 if self.destroyed or not self.accepting then return end
 radius=math.clamp(radius or 3,1.8,4.8)
 for i=1,math.min(count,LIMIT) do
  local r=self.random
  local angle=r:NextNumber(0,math.pi*2)
  local radial=Vector3.new(math.cos(angle),r:NextNumber(-.25,.55),math.sin(angle))
  local side=Vector3.new(-radial.Z,0,radial.X)*(r:NextInteger(0,1)==0 and -1 or 1)
  local a=radial*r:NextNumber(.9,1.4)
  local d=radial*radius+side*r:NextNumber(.3,1.1)+Vector3.new(0,r:NextNumber(.2,1.2),0)
  local b=a+side*r:NextNumber(.8,1.6)+Vector3.new(0,.5,0)
  local c=d-side*r:NextNumber(.7,1.5)+Vector3.new(0,r:NextNumber(.6,1.4),0)
  if kind=="inward" then a,b,c,d=d,c,b,a end
  if kind=="ribbon" then
   b=a+side*radius*.75+Vector3.new(0,.35,0)
   c=d+side*radius*.5+Vector3.new(0,.8,0)
  end
  local item=self:_slot()
  item.a=a;item.b=b;item.c=c;item.d=d
  item.started=self.clock;item.duration=(duration or .75)*r:NextNumber(.85,1.15)
  item.size=r:NextNumber(.07,.15);item.active=true
  item.head.Color=self.color:Lerp(Color3.new(1,1,1),.45)
  item.head.CFrame=CFrame.new(self.center+a);item.head.Transparency=0
  item.trail.Color=ColorSequence.new(self.color:Lerp(Color3.new(1,1,1),.6),self.color)
  item.trail.Enabled=true
  if item.light then item.light.Color=self.color;item.light.Brightness=.65 end
 end
end
function Curves:step(dt)
 if self.destroyed then return end
 self.clock+=dt
 for _,item in self.pool do
  if item.active then
   local t=math.clamp((self.clock-item.started)/item.duration,0,1)
   local position=self.center+Curves.point(item.a,item.b,item.c,item.d,t)
   local tangent=Curves.tangent(item.a,item.b,item.c,item.d,t)
   item.head.CFrame=tangent.Magnitude>.001 and CFrame.lookAt(position,position+tangent) or CFrame.new(position)
   local envelope=math.sin(math.pi*t)^.5
   item.head.Size=Vector3.one*math.max(.02,item.size*(.4+envelope*.6))
   item.head.Transparency=1-envelope*.95
   if item.light then item.light.Brightness=envelope*.65 end
   if t>=1 then item.active=false;item.trail.Enabled=false end
  end
 end
end
function Curves:fade()
 self.accepting=false
end
function Curves:destroy()
 if self.destroyed then return end
 self.destroyed=true
 for _,item in self.pool do item.head:Destroy() end
 table.clear(self.pool)
end
return Curves
