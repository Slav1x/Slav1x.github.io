--!nonstrict
-- Every pickup, timed catch and hazard is resolved against the server-owned pebble.
local RS=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local C=require(RS.Shared.PebbleEncounters)
local PrimateMotion=require(RS.Shared.PrimateMotion)
local Sign=require(RS.Shared.EncounterSign)
local Water=require(RS.Shared.WaterSurface)
local Pickup=require(script.Parent.WaterPickupService)
local Art=require(RS.Shared.WaterPickupArt)
local Placement=require(RS.Shared.WaterPickupPlacement)
local Money=require(script.Parent:WaitForChild("MoneyService"))
local Remotes=nil
local E={}
local stations={}
local runs={}
local started=false
local function part(parent,name,size,position,color,shape)
	local p=Instance.new("Part");p.Name=name;p.Size=size;p.Position=position;p.Color=color
	p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
	p.Material=Enum.Material.SmoothPlastic;p.Shape=shape or Enum.PartType.Block;p.Parent=parent
	return p
end
local function ball(parent,name,size,position,color)
	local p=part(parent,name,size,position,color)
	local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Sphere;mesh.Parent=p
	return p
end
local function ring(parent,center,radius,color,vertical)
	for i=1,24 do
		local a=(i-1)/24*math.pi*2;local b=i/24*math.pi*2
		local v1=if vertical then Vector3.new(0,math.sin(a)*radius,math.cos(a)*radius) else Vector3.new(math.sin(a)*radius,0,math.cos(a)*radius)
		local v2=if vertical then Vector3.new(0,math.sin(b)*radius,math.cos(b)*radius) else Vector3.new(math.sin(b)*radius,0,math.cos(b)*radius)
		local p=part(parent,"Ring",Vector3.new(0.35,0.35,(v2-v1).Magnitude),center+(v1+v2)/2,color)
		p.CFrame=CFrame.lookAt(p.Position,center+v2);p.Material=Enum.Material.Neon
	end
end
local function animal(model,center,gorilla)
 local folder=game.ServerStorage:FindFirstChild("PebbleEncounterArt")
 local template=folder and folder:FindFirstChild(if gorilla then "Gorilla" else "Monkey")
 if template then
  local art=template:Clone();art.Name="Animal";art.Parent=model
  local at=center+Vector3.new(0,1.5,0)
  art:PivotTo(CFrame.lookAt(at,at+Vector3.xAxis))
  return
 end
	local scale=if gorilla then 1.55 else 1
	local fur=if gorilla then Color3.fromRGB(55,62,75) else Color3.fromRGB(135,75,36)
	local face=Color3.fromRGB(231,184,126)
	local function p(n,size,offset,color) return ball(model,n,size*scale,center+offset*scale,color) end
	p("Body",Vector3.new(5,6,4),Vector3.new(1,5,0),fur)
	p("Belly",Vector3.new(1,3.5,3),Vector3.new(-1.3,4.8,0),face)
	p("Head",Vector3.new(4.7,4.6,4.6),Vector3.new(0,9,0),fur)
	p("Face",Vector3.new(1.8,3.4,3.7),Vector3.new(-2,8.8,0),face)
	for _,side in {-1,1} do
		p("Ear",Vector3.new(2,2,1),Vector3.new(0,9,side*2.4),face)
		p("Eye",Vector3.new(.4,.7,.6),Vector3.new(-2.9,9.5,side*.95),Color3.new(.06,.05,.03))
		p("Arm",Vector3.new(2,5,2),Vector3.new(-.5,5.5,side*3.3),fur)
		p("CatchHand",Vector3.new(2.6,2.1,2.1),Vector3.new(-2,4,side*3),face)
		p(if side==1 then "KickFoot" else "Foot",Vector3.new(3,2,2.3),Vector3.new(-1.8,1.7,side*1.8),fur)
	end
	if not gorilla then
		for i=1,7 do p("Tail",Vector3.new(1.2,1.2,1.2),Vector3.new(2+i*.65,3+math.sin(i*.5)*2,0),fur) end
	end
end
local function signDetail(kind,def)
 if kind=="Whirlpool" then return "WARP + BOOST" end
 if def.cash then return "BREAK  +$"..def.cash end
 if kind=="Nitro" then return "+1 NITRO CHARGE" end
 if kind=="Monkey" then return "TIME YOUR KICK" end
 if kind=="Gorilla" then return "TIME YOUR THROW" end
 return "FLY THROUGH FOR BOOST"
end
local function buildStation(folder,id,kind,center)
	local def=C.Types[kind]
	local m=Instance.new("Model");m.Name=string.format("%02d_%s",id,kind);m.ModelStreamingMode=Enum.ModelStreamingMode.PersistentPerPlayer
	m:SetAttribute("EncounterKind",kind);m:SetAttribute("EncounterId",id)
	local root=part(m,"Target",Vector3.one,center,def.color);root.Transparency=1;m.PrimaryPart=root
	if kind=="Monkey" or kind=="Gorilla" then
		ball(m,"SandIsland",Vector3.new(def.radius*2,5,def.radius*1.6),center-Vector3.new(0,1.7,0),Color3.fromRGB(226,198,130))
		ball(m,"Grass",Vector3.new(def.radius*1.7,1.5,def.radius*1.3),center+Vector3.new(0,.7,0),Color3.fromRGB(92,174,85))
		animal(m,center,kind=="Gorilla")
		local trunk=part(m,"PalmTrunk",Vector3.new(1.5,18,1.5),center+Vector3.new(7,9,-8),Color3.fromRGB(133,89,54));trunk.Orientation=Vector3.new(0,0,-12)
		for i=1,5 do local leaf=ball(m,"PalmLeaf",Vector3.new(15,1.5,3),center+Vector3.new(8,18,-8),Color3.fromRGB(51,146,82));leaf.Orientation=Vector3.new(0,i*72,14) end
	elseif kind=="Jet" then
		ring(m,center+Vector3.new(0,9,0),10,def.color,true)
		for _,z in {-11,11} do
			local engine=part(m,"JetEngine",Vector3.new(8,4,4),center+Vector3.new(0,5,z),Color3.fromRGB(70,92,111),Enum.PartType.Cylinder)
			local flame=ball(m,"Exhaust",Vector3.new(7,2.8,2.8),engine.Position+Vector3.new(-6,0,0),def.color);flame.Material=Enum.Material.Neon
		end
	elseif kind=="Nitro" then
		local can=part(m,"NitroCanister",Vector3.new(8,5,5),center+Vector3.new(0,6,0),def.color,Enum.PartType.Cylinder);can.Orientation=Vector3.new(0,0,90)
		part(m,"Cap",Vector3.new(2,1,2),center+Vector3.new(0,10.5,0),Color3.fromRGB(210,221,238))
		ring(m,center+Vector3.new(0,.6,0),10,def.color,false)
	elseif kind=="Bomb" then
		ball(m,"Bomb",Vector3.new(8,8,8),center+Vector3.new(0,4,0),Color3.fromRGB(45,49,59))
		part(m,"Fuse",Vector3.new(.7,3,.7),center+Vector3.new(0,9,0),Color3.fromRGB(220,183,105))
		local spark=ball(m,"FuseSpark",Vector3.one*1.8,center+Vector3.new(0,11,0),def.color);spark.Material=Enum.Material.Neon
		ring(m,center+Vector3.new(0,.5,0),10,def.color,false)
	elseif kind=="Log" then
		local log=part(m,"Driftwood",Vector3.new(25,4,4),center+Vector3.new(0,1,0),Color3.fromRGB(117,76,47),Enum.PartType.Cylinder);log.Orientation=Vector3.new(0,90,0);log.Material=Enum.Material.Wood
		part(m,"Branch",Vector3.new(2,6,2),center+Vector3.new(0,3,5),log.Color)
	elseif kind=="Rocks" then
		for i=-1,1 do local rock=ball(m,"ReefRock",Vector3.new(10,9+3*(i%2),9),center+Vector3.new(i*3,2,i*6),Color3.fromRGB(101,118,130));rock.Material=Enum.Material.Slate end
	else
		for i=1,4 do ring(m,center+Vector3.new(0,.15+i*.05,0),i*4,Color3.fromRGB(40+i*10,100+i*17,180+i*12),false) end
		ball(m,"Vortex",Vector3.new(8,.5,8),center+Vector3.new(0,.1,0),Color3.fromRGB(17,43,86))
	end
	Art.upgrade(m)
 if not Placement.place(m) then m:Destroy();return end
 Art.upgrade(m)
 center=m.PrimaryPart.Position
	Sign.attach(m,root,def.label,signDetail(kind,def),def.color,def.height+2)
	m.Parent=folder
	if Art.supports(kind) then Pickup.register(m) end
	table.insert(stations,{id=id,kind=kind,center=center,model=m})
end
function E.build()
	table.clear(stations)
	local existing=workspace:FindFirstChild("PebbleAdventure")
	if existing and #existing:GetChildren()>0 then
  Placement.arrangeCourse(existing)
  local BiomeArt=require(game.ReplicatedStorage.Shared.WorldArt)
  for _,model in existing:GetChildren() do
   if model:IsA("Model") and model.PrimaryPart and Placement.isPowerup(model) then
    for _,part in model:GetChildren() do if part.Name=="BiomeCasing" then part:Destroy() end end
    BiomeArt.trimPickup(model)
   end
  end
		for _,m in existing:GetChildren() do
			if m:IsA("Model") and m.PrimaryPart and C.Types[m:GetAttribute("EncounterKind")] then
				local kind=m:GetAttribute("EncounterKind")
				local def=C.Types[kind]
				Art.upgrade(m)
                if not Placement.place(m) then warn("No clear water position for "..m.Name);m.Parent=game.ServerStorage;continue end
                Art.upgrade(m)
				Sign.attach(m,m.PrimaryPart,def.label,signDetail(kind,def),def.color,def.height+2)
				if Art.supports(kind) then Pickup.register(m) end
				table.insert(stations,{id=m:GetAttribute("EncounterId"),kind=kind,center=m.PrimaryPart.Position,model=m})
			end
		end
		return
	end
	if existing then existing:Destroy() end
	local spawn=workspace:FindFirstChildWhichIsA("SpawnLocation");if not spawn then return end
	local folder=Instance.new("Folder");folder.Name="PebbleAdventure";folder:SetAttribute("CourseVersion",5);folder.Parent=workspace
	-- Authored choices, not a conveyor belt: rewards alternate well off center.
 -- Each row gives a steering decision followed by recovery space for the landing.
 local layout={
  {250,0,"Log"},{600,-25,"Nitro"},
  {980,-36,"Jet"},{980,36,"Rocks"},
  {1450,-32,"Monkey"},{1900,38,"Bomb"},{1900,-38,"Whirlpool"},
  {2380,-42,"Gorilla"},
  {2500,40,"Log"},{2880,20,"Nitro"},{3180,-40,"Jet"},
  {3290,34,"Rocks"},{3680,38,"Monkey"},{3800,-25,"Whirlpool"},
  {4210,-30,"Nitro"},{4460,40,"Bomb"},{4580,-40,"Log"},
  {5020,-42,"Gorilla"},{5170,30,"Rocks"},{5580,20,"Nitro"},
  {5800,-35,"Jet"},
 }
 for id,row in layout do
  local p=spawn.Position+Vector3.new(row[1],0,row[2])
  local y=Water.at(p)
  if y then buildStation(folder,id,row[3],Vector3.new(p.X,y,p.Z)) end
 end
end
local function state(t)
	local s=runs[t.pebble]
	if not s then s={seen={},nitro=1,lastAction=-math.huge,chain=0,hits=0,boosts=0};runs[t.pebble]=s;t.pebble:SetAttribute("NitroCharges",1);t.pebble:SetAttribute("NitroMaxCharges",C.nitroCapacity(t.physics and t.physics.traitPowerupMultiplier)) end
	return s
end
local function signal(t,kind,position,label,station,perfect,cash,extra)
 local data={userId=t.player.UserId,throwId=t.throwId,kind=kind,position=position,label=label,stationId=station,perfect=perfect,cash=cash,velocity=t.mainPart.AssemblyLinearVelocity}
 if extra then for key,value in extra do data[key]=value end end
 Remotes.Encounter:FireAllClients(data)
end
local function breakChain(t,s)
 s.chain=0;s.lastReward=nil;t.pebble:SetAttribute("EncounterChain",0);t.pebble:SetAttribute("ChainExpires",nil)
end
local function reward(t,s,points)
 local now=workspace:GetServerTimeNow()
 if not s.lastReward or now-s.lastReward>C.ChainWindow then s.chain=0 end
 s.chain+=1;s.lastReward=now
 t.pebble:SetAttribute("EncounterChain",s.chain)
 t.pebble:SetAttribute("ChainExpires",now+C.ChainWindow)
 t.pebble:SetAttribute("StyleScore",(t.pebble:GetAttribute("StyleScore") or 0)+points*math.min(s.chain,5))
end
local function launch(t,s,mul,add,lift,kind)
	local v=t.mainPart.AssemblyLinearVelocity
	local h=Vector3.new(v.X,0,v.Z)
	local dir=if h.Magnitude>1 then h.Unit else Vector3.xAxis
	local waterBoost=kind=="Jet" or kind=="Bomb" or kind=="Whirlpool" or kind=="Nitro"
	local multiplier=if waterBoost and t.physics then t.physics.traitPowerupMultiplier else 1
	local boostedSpeed,boostLift,boostDuration=C.boostValues(h.Magnitude,mul,add,lift,multiplier)
	t.laneForward=dir
	t.lateralSpeed=0
	t.pebble:SetAttribute("LaunchDirection",dir)
	t.mainPart.AssemblyLinearVelocity=dir*boostedSpeed+Vector3.new(0,boostLift,0)
	t.pebble:SetAttribute("TerminalArc",false)
	t.pebble:SetAttribute("BoostUntil",workspace:GetServerTimeNow()+boostDuration)
	t.pebble:SetAttribute("BoostKind",kind)
	s.boosts+=1;t.pebble:SetAttribute("EncounterBoosts",s.boosts)
end
local function beginWarp(t,s,st,def)
 local main=t.mainPart
 local velocity=main.AssemblyLinearVelocity
 local horizontal=Vector3.new(velocity.X,0,velocity.Z)
 local forward=if horizontal.Magnitude>1 then horizontal.Unit else t.laneForward
 local exitPosition=nil
 for distance=72,36,-12 do
  local candidate=st.center+forward*distance
  local waterY=Water.at(candidate)
  if waterY then exitPosition=Vector3.new(candidate.X,waterY+18,candidate.Z);break end
 end
 if not exitPosition then exitPosition=st.center+forward*36+Vector3.new(0,18,0) end
 local now=workspace:GetServerTimeNow()
 local entry=main.Position
 s.warp={started=now,entry=entry,center=st.center+Vector3.new(0,0.5,0),exit=exitPosition,velocity=velocity,rotation=t.pebble:GetPivot().Rotation,station=st}
 reward(t,s,def.points)
 signal(t,"Whirlpool",entry,"WORMHOLE OPEN!",st.id,nil,nil,{phase="enter",exitPosition=exitPosition,velocity=velocity})
 main.Anchored=true
 t.pebble:SetAttribute("WarpUntil",now+0.24)
end
local function releaseCatch(t,s,grade)
 local caught=s.catch;if not caught then return end
 local now=workspace:GetServerTimeNow()
 local animal=caught.station.model:FindFirstChild("Animal")
 if animal and caught.releasing then
  local contact=PrimateMotion.contact(animal,caught.releaseAt)
  if contact then t.pebble:PivotTo(CFrame.new(contact)*caught.entry.Rotation) end
 elseif animal and grade=="miss" then PrimateMotion.begin(animal,"Miss",now) end
 caught.station.busyUntil=now+.55
 s.catch=nil
 t.pebble:SetAttribute("CatchReleasing",nil);t.pebble:SetAttribute("CatchInputTime",nil)
 local main=t.mainPart;main.Anchored=false;pcall(function() main:SetNetworkOwner(nil) end)
 main.AssemblyLinearVelocity=caught.velocity
 local big=caught.station.kind=="Gorilla"
 local perfect=grade=="perfect"
 if not big and grade~="miss" and math.abs(t.steer)>0.1 then
  local v=main.AssemblyLinearVelocity
  local h=Vector3.new(v.X,0,v.Z)
  if h.Magnitude>1 then
   local curve=CFrame.Angles(0,-math.rad(17)*t.steer,0):VectorToWorldSpace(h.Unit)
   main.AssemblyLinearVelocity=curve*h.Magnitude+Vector3.new(0,v.Y,0)
   t.laneForward=curve;t.lateralSpeed=0
   t.pebble:SetAttribute("LaunchDirection",curve)
  end
 end
 if grade=="miss" then
  local v=caught.velocity
  main.AssemblyLinearVelocity=Vector3.new(v.X*.58,24,v.Z*.58)
  breakChain(t,s)
  t.pebble:SetAttribute("BoostUntil",0)
 else
  launch(t,s,if perfect then 1.04 else 1,if perfect then (if big then 24 else 20) else 0,
   if perfect then (if big then 185 else 155) else (if big then 135 else 112),caught.station.kind)
  reward(t,s,C.Types[caught.station.kind].points+(if perfect then 150 else 0))
 end
 t.pebble:SetAttribute("CatchUntil",nil);t.pebble:SetAttribute("CatchStart",nil);t.pebble:SetAttribute("CatchKind",nil)
 t.lastPos=main.Position

 signal(t,if grade=="miss" then "Miss" else caught.station.kind,main.Position,
  if grade=="miss" then (if big then "MISSED THROW! SPEED LOST" else "MISSED KICK! SPEED LOST") elseif perfect and not big then "PERFECT CURVE KICK!" elseif perfect then "PERFECT SKY THROW!" else (if big then "GOOD THROW!" else "GOOD KICK!"),caught.station.id,perfect)
end
function E.action(t,throwId,mode)
 if not t or t.ending or throwId~=t.throwId or not t.mainPart.Parent then return true end
 local s=state(t);local now=workspace:GetServerTimeNow()
 if s.catch and mode~="nitro" then
  if now-s.lastAction<.2 then return true end;s.lastAction=now
  if s.catch.releasing then return true end
  local elapsed=now-s.catch.started
  local kind=s.catch.station.kind
  local timing=C.CatchTiming[kind]
  local grade=if elapsed>=timing.perfectStart and elapsed<=timing.perfectEnd then "perfect" elseif elapsed>=timing.goodStart and elapsed<=timing.goodEnd then "good" else "miss"
  if grade=="miss" then releaseCatch(t,s,grade)
  else
   -- Grade is locked at input time; contact occurs at the authored strike marker.
   s.catch.releasing=true;s.catch.grade=grade;s.catch.releaseAt=now+PrimateMotion.ReleaseDelay[kind]
   local animal=s.catch.station.model:FindFirstChild("Animal")
   if animal then animal:SetAttribute("PrimateCatchAge",elapsed);PrimateMotion.begin(animal,if kind=="Monkey" then "Kick" else "Throw",now) end
   t.pebble:SetAttribute("CatchInputTime",elapsed);t.pebble:SetAttribute("CatchReleasing",true)
  end
  return true
 end
 if mode=="nitro" then
  if s.catch or now-s.lastAction<.2 then return true end;s.lastAction=now
  if s.nitro>0 and (not s.nextNitro or now>=s.nextNitro) then
   s.nitro-=1;s.nextNitro=now+1.4;t.pebble:SetAttribute("NitroCharges",s.nitro);t.pebble:SetAttribute("NitroReadyAt",s.nextNitro)
   launch(t,s,1.28,35,34,"Nitro");signal(t,"Nitro",t.mainPart.Position,"NITRO ACTIVATED",nil)
  end
  return true
 end
 return false
end
function E.hold(t)
	local s=state(t)
	if s.lastReward and workspace:GetServerTimeNow()-s.lastReward>C.ChainWindow then breakChain(t,s) end
	if s.warp then
  local warp=s.warp
  local elapsed=workspace:GetServerTimeNow()-warp.started
  if elapsed<0.24 then
   local pull=math.clamp(elapsed/0.2,0,1)
   pull=pull*pull*(3-2*pull)
   t.pebble:PivotTo(CFrame.new(warp.entry:Lerp(warp.center,pull))*warp.rotation)
   t.lastPos=t.mainPart.Position
  else
   t.pebble:PivotTo(CFrame.new(warp.exit)*warp.rotation)
   t.mainPart.Anchored=false
   pcall(function() t.mainPart:SetNetworkOwner(nil) end)
   t.mainPart.AssemblyLinearVelocity=warp.velocity
   launch(t,s,1.18,28,40,"Whirlpool")
   t.lastPos=t.mainPart.Position
   t.pebble:SetAttribute("WarpUntil",nil)
   s.warp=nil
   signal(t,"Whirlpool",warp.exit,"WORMHOLE BOOST!",warp.station.id,nil,nil,{phase="exit"})
  end
  return true
 end
	if not s.catch then return false end
 local caught=s.catch;local now=workspace:GetServerTimeNow()
 local animal=caught.station.model:FindFirstChild("Animal")
 local contact=animal and PrimateMotion.contact(animal,now)
 local target=if contact then CFrame.new(contact)*caught.entry.Rotation else caught.target
 local pull=math.clamp((now-caught.started)/.18,0,1);pull=pull*pull*(3-2*pull)
 t.pebble:PivotTo(caught.entry:Lerp(target,pull));t.lastPos=t.mainPart.Position
 if caught.releasing then
  if now>=caught.releaseAt then releaseCatch(t,s,caught.grade) end
 elseif now>=caught.started+C.CatchDuration then releaseCatch(t,s,"miss") end
	return true
end
function E.smashPhysical(t,hitPart,position)
 local model=hitPart and hitPart:FindFirstAncestorWhichIsA("Model")
 if not model or model:GetAttribute("SkipObstacle")~=true then return false end
 if not Pickup.collect(model) then return false end
 local s=state(t)
 s.hits+=1;t.pebble:SetAttribute("ObstacleHits",s.hits)
 reward(t,s,55)
 local cash=model:GetAttribute("ObstacleCash")
 cash=if typeof(cash)=="number" then math.clamp(cash,0,1000) else 250
 local paid=Money.awardObstacle(t.player,cash,position,t.moneyMul)
 local title=model.Name:gsub("_%d+$",""):gsub("(%l)(%u)","%1 %2")
 signal(t,"Obstacle",position,"BROKE "..string.upper(title),nil,nil,paid,{target=model,obstacleKind=model:GetAttribute("ObstacleKind")})
 return true
end
function E.sweepPhysical(t,from,to)
 local radius=math.max(.35,math.max(t.mainPart.Size.X,t.mainPart.Size.Y,t.mainPart.Size.Z)*.5)
 for _,hit in Pickup.sweepPhysical(from,to,radius) do E.smashPhysical(t,hit.part,hit.position) end
end
function E.step(t,from,to)
	local s=state(t)
	local hits={}
	for _,st in stations do
  local padding=st.model:GetAttribute("PickupSweepPadding") or 90
  if st.center.X<math.min(from.X,to.X)-padding or st.center.X>math.max(from.X,to.X)+padding
   or st.center.Z<math.min(from.Z,to.Z)-padding or st.center.Z>math.max(from.Z,to.Z)+padding then continue end
		if s.seen[st.id] then continue end
  if (st.busyUntil or 0)>workspace:GetServerTimeNow() then continue end
		if Art.supports(st.kind) and not Pickup.isAvailable(st.model) then continue end
		local def=C.Types[st.kind]
		local alpha
        if Art.supports(st.kind) then
         local radius=math.max(.35,math.max(t.mainPart.Size.X,t.mainPart.Size.Y,t.mainPart.Size.Z)*.5)
         alpha=Pickup.hitModel(st.model,from,to,radius)
        else alpha=C.hit(from,to,st.center,def.hitRadius or def.radius,def.height) end
		if alpha then table.insert(hits,{station=st,alpha=alpha}) end
	end
	table.sort(hits,function(a,b) return a.alpha<b.alpha end)
	local entry=hits[1];if not entry then return false end
	local st=entry.station;local kind=st.kind;local def=C.Types[kind]
	if Art.supports(kind) and not Pickup.collect(st.model) then return false end
	s.seen[st.id]=true
	t.pebble:SetAttribute("LastEncounterId",st.id)
	if def.cash then s.hits+=1;t.pebble:SetAttribute("ObstacleHits",s.hits) end
	if kind=="Monkey" or kind=="Gorilla" then
		local now=workspace:GetServerTimeNow()
		local entry=t.pebble:GetPivot()
		s.catch={station=st,started=now,velocity=t.mainPart.AssemblyLinearVelocity,
			entry=entry,target=CFrame.new(st.center+Vector3.new(-5,if kind=="Gorilla" then 8 else 5,0))*entry.Rotation}
		t.mainPart.Anchored=true
  st.busyUntil=now+C.CatchDuration+.35
  local animal=st.model:FindFirstChild("Animal")
  if animal then
   -- Turn toward the actual launch heading; catch/throw remains server-owned.
   local v=s.catch.velocity;local dir=Vector3.new(v.X,0,v.Z)
   if dir.Magnitude>1 then local at=animal:GetPivot().Position;animal:PivotTo(CFrame.lookAt(at,at+dir.Unit)) end
   PrimateMotion.begin(animal,"Catch",now)
  end
		t.lastPos=t.mainPart.Position
		t.pebble:SetAttribute("CatchStart",now);t.pebble:SetAttribute("CatchUntil",now+C.CatchDuration)
		t.pebble:SetAttribute("CatchKind",kind)
		signal(t,"Catch",t.mainPart.Position,if kind=="Gorilla" then "CAUGHT! TIME YOUR THROW" else "CAUGHT! TIME YOUR KICK",st.id)
	elseif kind=="Jet" then
		reward(t,s,def.points);launch(t,s,1.2,25,48,kind);signal(t,kind,to,"JET BOOST",st.id)
	elseif kind=="Nitro" then
		local multiplier=t.physics and t.physics.traitPowerupMultiplier or 1
		local before=s.nitro;s.nitro=C.nitroRefill(s.nitro,multiplier);t.pebble:SetAttribute("NitroCharges",s.nitro)
		reward(t,s,def.points);signal(t,kind,to,"NITRO CHARGE +"..(s.nitro-before),st.id)
	elseif kind=="Bomb" then
		reward(t,s,def.points);launch(t,s,1.22,30,62,kind);signal(t,kind,to,"BLAST BOOST",st.id)
 elseif kind=="Whirlpool" then
  beginWarp(t,s,st,def)
	elseif def.cash then
		-- The surface cycle was claimed above, before awarding anything.
  do
   reward(t,s,def.smashPoints or 0)
   local chainBonus=1+math.min(s.chain-1,4)*.12
   local base=math.floor((def.cash+st.id*.16)*chainBonus)
   local paid=Money.awardObstacle(t.player,base,to,t.moneyMul)
   signal(t,kind,to,"BROKE "..def.label,st.id,nil,paid,{target=st.model})
  end
	end
	return kind~="Nitro" and not def.cash -- money hits also allow a simultaneous water bounce
end
function E.finish(pebble)
	local s=runs[pebble]
 if s and s.catch then
  s.catch.station.busyUntil=0
  PrimateMotion.begin(s.catch.station.model:FindFirstChild("Animal"),"Idle",workspace:GetServerTimeNow())
 end
 pebble:SetAttribute("CatchReleasing",nil);pebble:SetAttribute("CatchInputTime",nil)
	if s and (s.catch or s.warp) and pebble.PrimaryPart then pebble.PrimaryPart.Anchored=false end
	pebble:SetAttribute("CatchStart",nil);pebble:SetAttribute("CatchUntil",nil);pebble:SetAttribute("CatchKind",nil);pebble:SetAttribute("WarpUntil",nil);pebble:SetAttribute("BoostUntil",0)
	runs[pebble]=nil
end
function E.start()
	if started then return end;started=true;Remotes=require(RS.Shared.Remotes);E.build()
end
return E


